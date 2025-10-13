
@tool
extends ColorRect
class_name BlockComponent

enum ButtonType { CONTEXT_MENU, BLOCK_BUTTON, DROPOUT_MENU,  }

var _instance_uniforms = []
var is_blocking: bool = false
var is_frozen: bool = false

func freeze_input() -> void: is_frozen = true
func unfreeze_input() -> void: is_frozen = false
func block_input() -> void: is_blocking = true
func unblock_input() -> void: is_blocking = false

@export var button_type: ButtonType = ButtonType.CONTEXT_MENU
@export var area_padding: float = 0.0
@export var placeholder: bool = false
@export var top: bool = false

@export_tool_button("Editor Refresh") var _editor_refresh = func():
	notify_property_list_changed()


@export_group("Meta")
@export var metadata: Dictionary = {}
@export var hint: StringName = &""

@export_group("Text")
@export var auto_trim_text: bool = false
@export var base_scale_x: float = 0.643:
	set(v):
		base_scale_x = v
		if not is_node_ready(): await ready
		label.scale = Vector2(v, v)
@export var resize_after: int = 0:
	set(v):
		resize_after = v
		if not Engine.is_editor_hint():
			text = text
@onready var label = $Label


@export var text: String = "":
	set(value):
		text = value
		if not is_node_ready():
			await ready
		label.text = _wrap_text(value)
		_align_label()
@export var text_color: Color = Color.WHITE:
	set(v):
		if not is_node_ready():
			await ready
		text_color = v; label.modulate = text_color
@export var text_alignment: Vector2 = Vector2()
@export var text_offset: Vector2 = Vector2()

@export_group("Marquee")
var _scroll_index: int = 0
var _scroll_timer: float = 0.0
@export var _scroll_delay: float = 0.2   # seconds between shifts
@export var _scroll_pause: float = 0.7   # pause at full cycle
@export var scroll_padding_spaces: int = 3
var _scrolling: bool = false
var _scroll_original: String = ""


@export_group("Rect")
@export var base_size: Vector2 = size
@export var alignment: Vector2 = Vector2(0,0):
	set(v):
		alignment = v
		if Engine.is_editor_hint():
			pivot_offset = alignment * size
		else:
			pivot_offset = Vector2()

@export_group("Context Menu")
@export var static_mode: bool = false
@export var left_activate: bool = false
@export var size_add: float = 0.0
@export var _scroll_container = null:
	set(v):
		if !Engine.is_editor_hint():
			if button_type == ButtonType.BLOCK_BUTTON: return
			if not v:
				v = glob.scroll_container.instantiate()
				add_child(v)
			scroll = v
			vbox = v.get_child(0)
		_scroll_container = v

func default_scroll():
	var v = glob.scroll_container.instantiate()
	add_child(v)
	scroll = v
	vbox = v.get_child(0)
	_scroll_container = v

func _init() -> void:
	pass
	#if button_type == ButtonType.CONTEXT_MENU:
	#	_scroll_container = _scroll_container

@export var secondary: bool = false


@export var expanded_size: int = 190
@onready var _unclamped_expanded_size: int = 0

@export var scale_anim: bool = false
@export var expand_anim: bool = true
@export var arrangement_padding: Vector2 = Vector2(10, 5)
@export var mouse_open: bool = true
@export var menu_name: StringName = &""
@export var dynamic_size: bool = false
@export var max_size: int = 0
@export var expand_upwards: bool = false:
	set(v):
		if v != expand_upwards:
			expand_upwards = v
			if not Engine.is_editor_hint():
				arrange()

@export_group("Button")
@export var config: ButtonConfig
@export var graph: Control
@export var graph_root: Graph

signal hovered
signal hovering
signal pressed
signal pressing
signal released

@onready var default_modulate: Color = modulate
@onready var base_modulate: Color = modulate
@onready var base_scale: Vector2 = scale

const EPSILON: float = 0.0002

# State and anchor
var state = {
	"expanding": false,
	"holding": false,
	"tween_hide": false,
	"tween_progress": 0.0,
	"pressing": false,
	"hovering": false,
	"expanded": false
}
var last_mouse_pos: Vector2 = Vector2()
var anchor_position: Vector2 = Vector2()  # For upward expansion

signal child_button_hover(button: BlockComponent)
signal child_button_hovering(button: BlockComponent)
signal child_button_press(button: BlockComponent)
signal child_button_pressing(button: BlockComponent)
signal child_button_release(button: BlockComponent)

func _menu_handle_hover(button: BlockComponent):
	child_button_hover.emit(button)

func _menu_handle_hovering(button: BlockComponent):
	child_button_hovering.emit(button)

func _menu_handle_press(button: BlockComponent):
	child_button_press.emit(button)

func _menu_handle_pressing(button: BlockComponent):
	child_button_pressing.emit(button)

func _menu_handle_release(button: BlockComponent):
	child_button_release.emit(button)

var vbox: VBoxContainer
var scroll: ScrollContainer
var button_by_hint: Dictionary[StringName, BlockComponent] = {}
func contain(child: BlockComponent):
	if child.placeholder: return
	if child in _contained: return

	child.reparent(vbox)
	#child.modulate.a = 0.0
	#child.hide()
	
	if child.button_type == ButtonType.BLOCK_BUTTON:
		button_by_hint[child.hint] = child
		child.hovered.connect(_menu_handle_hover.bind(child))
		child.hovering.connect(_menu_handle_hovering.bind(child))
		child.pressed.connect(_menu_handle_press.bind(child))
		child.pressing.connect(_menu_handle_pressing.bind(child))
		child.released.connect(_menu_handle_release.bind(child))
	
	if add_to_size:
		expanded_size += child.size.y + arrangement_padding.y
	
	_contained.append(child); child.is_contained = self

var add_to_size: bool = false

@export_group("Scrollbar")
@export var scrollbar_padding: int = 21
@export var bar_scale_x: float = 1.2

func initialize() -> void:
	if Engine.is_editor_hint(): return
	
	if button_type == ButtonType.CONTEXT_MENU or button_type == ButtonType.DROPOUT_MENU:
		if not scroll:
			default_scroll()
		bar = scroll.get_v_scroll_bar()
		bar.scrolling.connect(update_children_reveal)
		bar.scale.x = bar_scale_x
		bar.z_index = 2

		if expanded_size == 0 and !dynamic_size:
			expanded_size = base_size.y
			add_to_size = true
	
	if button_type == ButtonType.CONTEXT_MENU or button_type == ButtonType.DROPOUT_MENU:
		scroll.size = Vector2(base_size.x - scrollbar_padding, expanded_size if not max_size else max_size - base_size.y - 10)
		if not dynamic_size:
			for child in get_children():
				if not child is BlockComponent:
					continue
				contain(child)
			arrange()
			_unclamped_expanded_size = expanded_size
		
		if button_type == ButtonType.CONTEXT_MENU:
			if not static_mode:
				hide()

		if dynamic_size:
			expanded_size = 4.0 + base_size.y
			for child in _contained:
				expanded_size += child.size.y + arrangement_padding.y
			_unclamped_expanded_size = expanded_size




func dynamic_child_exit(child: BlockComponent):
	if child in _contained:
		_unclamped_expanded_size -= floor(child.base_size.y + arrangement_padding.y)
		expanded_size = _unclamped_expanded_size#min(_unclamped_expanded_size, max_size if max_size else _unclamped_expanded_size)
		scroll.size.y = max_size-base_size.y-10
		_contained.erase(child)
		if button_by_hint[child.hint] == child:
			button_by_hint.erase(child.hint)
	
		

func dynamic_child_enter(child: BlockComponent):
	#if not c is Wrapper: return
	#var child = c.wrapping_target
	_unclamped_expanded_size += floor(child.base_size.y + arrangement_padding.y)
	expanded_size = _unclamped_expanded_size#min(_unclamped_expanded_size, max_size if max_size else _unclamped_expanded_size)
	scroll.size.y = max_size-base_size.y-10

	contain(child)

func set_menu_size(x: float, y: float):
	base_size.x = x
	size.x = x
	scroll.size.x = base_size.x - scroll.position.x * 2
	size.y = y
	if max_size:
		max_size = y
	else:
		expanded_size = y
	scroll.size.y = expanded_size if not max_size else max_size - base_size.y - 10
	arrange()
	base_size.x = x
	size.x = x
	scroll.size.x = base_size.x - scroll.position.x * 2
	size.y = y
	if max_size:
		max_size = y
	else:
		expanded_size = y
	scroll.size.y = expanded_size if not max_size else max_size - base_size.y - 10
	update_children_reveal.call_deferred()


var trimmed: bool = false
func _wrap_text(txt: String) -> String:
	if !auto_trim_text: 
		trimmed = false
		return txt
	label.text = txt
	var size_x = glob.get_label_text_size(label, label.scale.x).x + 50
	if size_x > size.x:
		var one = float(size_x) / len(txt)
		var right = (size_x - size.x) / one
		txt = txt.left(len(txt)-ceil(right)-2) + ".."
		trimmed = true
	else:
		trimmed = false
	return txt

func resize(_size: Vector2) -> void:
	_size = _size.floor()
	base_size = _size; size = _size; text = text
	alignment = alignment
	#if is_contained:
	_wrapped_in.size = _size
	scaler.size = size
	text = text
	_wrapped_in.custom_minimum_size = _size
	if button_type == ButtonType.BLOCK_BUTTON or button_type == ButtonType.DROPOUT_MENU:
		scaler.position = alignment*size
		position = -alignment*size


var wrapped: bool = false


func arrange():
	# Arrange children above or below based on expand_upwards
	vbox.add_theme_constant_override("separation", arrangement_padding.y)
	var maxsize: int = 0
	
	var y = base_size.y * 0.9 if !expand_upwards else expanded_size / 2 - base_size.y * 1.45
	scroll.position = Vector2(arrangement_padding.x, y)
	var is_shrinked: bool = max_size < expanded_size and max_size
	var b_size = base_size.x - 2.2 * arrangement_padding.x
	if is_shrinked:
		b_size -= 14
	#print(_contained)
	for node:BlockComponent in _contained:
		#node._wrapped_in.position = Vector2(arrangement_padding.x, y)
		var size_y = node.size.y
		node.resize(Vector2(b_size/node.scale.x, round(size_y)))
		node.text = node.text
		y += (size_y + arrangement_padding.y)
		maxsize += (size_y + arrangement_padding.y)
		#print(maxsize)

func _enter_tree() -> void:
	if !Engine.is_editor_hint() and (button_type == ButtonType.CONTEXT_MENU):
		assert(not glob.menus.get(menu_name), "Menu %s already regged"%menu_name)
		glob.menus[menu_name] = self
	if !Engine.is_editor_hint():
		pivot_offset = Vector2()


func _create_scaler_wrapper() -> void:
	var wrapper = Wrapper.new()
	wrapper.position = self.position
	wrapped = true
	wrapper.size = self.base_size * scale
	wrapper.custom_minimum_size = self.base_size * scale

	# Decide if we should copy anchors or raw position
	var uses_anchors = not (is_equal_approx(anchor_left, 0.0)
		and is_equal_approx(anchor_top, 0.0)
		and is_equal_approx(anchor_right, 0.0)
		and is_equal_approx(anchor_bottom, 0.0))

	if uses_anchors:
		# Transfer anchors & margins to wrapper
		wrapper.anchor_left = anchor_left
		wrapper.anchor_top = anchor_top
		wrapper.anchor_right = anchor_right
		wrapper.anchor_bottom = anchor_bottom
		wrapper.offset_left = offset_left
		wrapper.offset_top = offset_top
		wrapper.offset_right = offset_right
		wrapper.offset_bottom = offset_bottom

		# Reset this node’s anchors to neutral
		anchor_left = 0
		anchor_top = 0
		anchor_right = 0
		anchor_bottom = 0
		offset_left = 0
		offset_top = 0
		offset_right = 0
		offset_bottom = 0
		#print(name, alignment)
		size = base_size
		custom_minimum_size = base_size
		
	else:
		# Pure position mode: just keep wrapper in same parent space
		wrapper.position = position
		# Reset local position so child sits at (0,0) in wrapper
		position = Vector2.ZERO

	var secondary_wrapper = Wrapper.new()
	secondary_wrapper.position += alignment * base_size * scale if is_contained else alignment * base_size
	wrapper.add_child(secondary_wrapper)

	reparent(secondary_wrapper)
	position = -alignment * base_size

	scaler = secondary_wrapper
	scaler.scale = scale
	scale = Vector2.ONE
	_wrapped_in = wrapper

	wrapper.wrapping_target = self
	secondary_wrapper.wrapping_target = self

	if parent is BlockComponent:
		parent.vbox.add_child(wrapper)
	else:
		parent.add_child(wrapper)


	

	
var _wrapped_in = self

var _contained = []
var scaler: Control = self
@export var auto_ready: bool = true
var auto_wrap: bool = true

func _ready() -> void:
	if not auto_ready: return
	#if graph == null and get_parent() is Control and button_type in [ButtonType.CONTEXT_MENU, ButtonType.DROPOUT_MENU]: 
		#graph = get_parent()
	initialize()
	size = base_size
	text = text  # Trigger setter
	if !Engine.is_editor_hint() and button_type == ButtonType.BLOCK_BUTTON and not placeholder and auto_wrap:
		_create_scaler_wrapper.call_deferred()
	if button_type == ButtonType.DROPOUT_MENU:
		update_children_reveal()


	

func _sub_process(delta: float):
	pass


var current_type: int = ButtonType.BLOCK_BUTTON
@onready var base_pos: Vector2 = global_position - graph.global_position if graph else global_position
func _process_dropout_menu(delta: float) -> void:
	var was_expanded = (state.expanding or state.expanded or state.tween_hide) and visible
	if graph and ButtonType.CONTEXT_MENU == current_type:
		if graph is Graph:
			graph.hold_for_frame()
	if graph_root and ButtonType.CONTEXT_MENU == current_type and graph_root is Graph:
		graph_root.hold_for_frame()
	var inside = is_mouse_inside()
	if inside:
		glob.occupy(self, "dropout_inside")
		#print(global_position)
	else:
		glob.un_occupy(self, "dropout_inside")
	var ab : bool = false
	if ButtonType.BLOCK_BUTTON == current_type:
		if graph:
			base_pos = position
		_process_block_button(delta)
		#print(glob.opened_menu)
		var graph = graph if graph and graph is Graph else graph_root
		if glob.mouse_just_pressed and (!graph or not graph.dragging) and state.pressing and not state.tween_hide and ButtonType.BLOCK_BUTTON == current_type:
			current_type = ButtonType.CONTEXT_MENU
			left_activate = true
			mouse_open = true
			var anchor = global_position
			anchor.y += base_size.y * mult.y
			modulate = config.hover_color * config.hover_mult
			prev_z_index = z_index
			z_index = RenderingServer.CANVAS_ITEM_Z_MAX
			ab = true
			menu_show(anchor)
			reparent(glob.follow_menus)
			
			glob.opened_menu = self
			state.holding = true
			state.expanding = true

	if state.tween_hide or state.expanding:
		if graph:
			global_position = base_pos + graph.global_position
		var a = modulate.a
		modulate = config.hover_color * config.hover_mult
		modulate.a = a
		if !static_mode and get_local_mouse_position().y < base_size.y and glob.mouse_just_pressed and not ab:
			glob.consume_input(self, "mouse_press")
			menu_hide()
		_process_context_menu(delta)



var mult: Vector2 = Vector2.ONE
func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		_align_label()
		base_size = size
		return
	
	
	mult = scaler.scale * parent.scale
	match button_type:
		ButtonType.CONTEXT_MENU:
			_process_context_menu(delta)
		ButtonType.BLOCK_BUTTON:
			_process_block_button(delta)
		ButtonType.DROPOUT_MENU:
			_process_dropout_menu(delta)
	_sub_process(delta)

func is_mouse_inside() -> bool:
	var graph = graph if graph and graph is Graph else graph_root
	if graph:
		var cons = glob.get_consumed("mouse")
		if cons and graph != cons: return false
	if !top and (glob.get_display_mouse_position().y < glob.space_begin.y\
	or glob.get_display_mouse_position().x > glob.space_end.x): return false
	var height = base_size.y if (
		button_type == ButtonType.BLOCK_BUTTON or (button_type == ButtonType.DROPOUT_MENU and current_type == ButtonType.BLOCK_BUTTON)) else expanded_size
	var bounds = Rect2(0, 0, base_size.x + 2*area_padding, height + 2*area_padding)
	bounds.size *= mult
	bounds.position += global_position - Vector2.ONE*area_padding*mult
	if bounds.size.x < 0 or bounds.size.y < 0: return false
	#if name == "list":
		#print(last_mouse_pos)
	return bounds.has_point(last_mouse_pos)

signal children_revealed

func _align_label() -> void:
	var text_size = glob.get_label_text_size(label) * label.scale
	label.position = (base_size - text_size) / 2 * (text_alignment + Vector2.ONE) + text_offset
	var base_scale = base_scale_x
	var txt = label.text
	var n = txt.length()
	var font = label.get_theme_font("font")
	var fs = label.get_theme_font_size("font_size")

	var full_sz: Vector2 = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs)
	var keep_txt = txt.substr(0, min(n, max(0, resize_after)))
	var keep_sz: Vector2 = font.get_string_size(keep_txt, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs)

	var base_full = full_sz * base_scale
	var base_pos_full = (base_size - base_full) / 2.0 * (text_alignment + Vector2.ONE) + text_offset

	if resize_after > 0 and n > resize_after and full_sz.x > 0.0:
		var target_w = keep_sz.x * base_scale
		var mult = clamp(target_w / base_full.x, 0.1, 1.0)
		label.scale = Vector2.ONE * (base_scale * mult)

		var new_sz = full_sz * label.scale
		var base_keep = keep_sz * base_scale
		var base_pos_keep = (base_size - base_keep) / 2.0 * (text_alignment + Vector2.ONE) + text_offset
		var right_x = base_pos_keep.x + base_keep.x

		var pos = Vector2()
		pos.x = right_x - new_sz.x
		pos.y = (base_size.y - new_sz.y) / 2.0 * (text_alignment.y + 1.0) + text_offset.y
		label.position = pos
	else:
		label.scale = Vector2.ONE * base_scale
		label.position = base_pos_full


var bounce_scale = Vector2.ONE
@onready var hover_scale: Vector2 = scale

@onready var parent = get_parent()
var is_contained: BlockComponent = null
var inside: bool = false
var mouse_pressed: bool = false

var press_request: bool = false
var imm_unpress: bool = false
func press(press_time: float = 0.0):
	if press_request: return
	press_request = true
	if !press_time: imm_unpress = true
	else: 
		imm_unpress = false
		await glob.wait(press_time)
		press_request = false
		ins_request = true


func _update_scroll_text(delta: float) -> void:
	if not trimmed or not _scrolling:
		return

	_scroll_timer -= delta
	if _scroll_timer > 0.0:
		return

	var visible_len = label.text.length()
	var full_text = _scroll_original
	if visible_len >= full_text.length():
		return

	# Padded text with user-controlled spaces
	var padded = full_text + " ".repeat(scroll_padding_spaces)
	var cycle_len = padded.length()

	# Advance index
	_scroll_index = (_scroll_index + 1) % cycle_len

	# Always build a full window of length `visible_len`
	var next = ""
	for i in range(visible_len):
		var idx = (_scroll_index + i) % cycle_len
		next += padded[idx]

	label.text = next
	_align_label()

	# Pause when we complete a full loop
	if _scroll_index == 0:
		_scroll_timer = _scroll_pause
	else:
		_scroll_timer = _scroll_delay



@export var in_splash: bool = false
@export var still_hover_in_block: bool = false

var ins_request: bool = false
func _process_block_button(delta: float) -> void:
	if not visible or not parent.visible or (graph and !graph.visible) or not freedom: 
		return
	
	var ins = (glob.get_occupied("menu_inside") and (not is_contained or glob.get_occupied("menu_inside") != is_contained))
	#if is_contained:
		#print(glob.get_occupied("menu_inside"))
	var blocked = (is_contained and (parent.is_blocking or parent.state.tween_hide or parent.scrolling)) or is_blocking \
	or ins
	var frozen = is_contained and parent.is_frozen or is_frozen
	blocked = blocked or (ui.splashed and not in_splash)
	
	if not frozen:
		inside = is_mouse_inside() and not (blocked and (not still_hover_in_block or ins or (is_contained and is_contained.scrolling)))
		mouse_pressed = glob.mouse_pressed and not blocked
	if (not blocked or still_hover_in_block) and (not mouse_pressed or (inside and mouse_pressed)):
		last_mouse_pos = get_global_mouse_position()
	if press_request:
		inside = true; mouse_pressed = true
		if imm_unpress:
			press_request = false
	mouse_pressed = mouse_pressed# and not glob.is_overlapped(self)
	#print(inside)
	if in_splash:
		if inside:
			glob.occupy(self, "block_button_inside")
		else:
			glob.un_occupy(self, "block_button_inside")
	if ins_request:
		ins_request = false; inside = true

	if inside:
		if mouse_pressed:
			hover_scale = hover_scale.lerp(base_scale * config._press_scale, delta * 30)
			if config.as_mult: 
				modulate = modulate.lerp(config.press_color * config.press_mult * base_modulate, delta * 50)
			else:
				modulate = modulate.lerp(config.press_color * config.press_mult, delta * 50)
			state.hovering = false
			if not state.pressing:
				pressed.emit()
				state.pressing = true
				state.tween_progress = 0.0
			pressing.emit()
		else:
			if trimmed:
				if not _scrolling:
					_scrolling = true
					_scroll_original = text  # full text
					_scroll_index = 0
					_scroll_timer = _scroll_pause
			else:
				if _scrolling:
					# restore original text when hover stops
					_scrolling = false
					label.text = _wrap_text(text)
					_align_label()
			hovering.emit()
			if not state.hovering:
				hovered.emit()
			state.hovering = true
			if config.as_mult: 
				modulate = modulate.lerp(config.hover_color * config.hover_mult * base_modulate, delta * 15)
			else:
				modulate = modulate.lerp(config.hover_color * config.hover_mult, delta * 15)

			if state.pressing:
				if not (is_contained and is_contained.scrolling):
					released.emit()
				state.pressing = false
				hover_scale = base_scale if config.animation_scale else base_scale * config._press_scale
				state.tween_progress = delta
			hover_scale = hover_scale.lerp(base_scale * config._hover_scale, delta * 30)
	else:
		if _scrolling:
			_scrolling = false
			label.text = _wrap_text(text)   # restore trimmed text
			_align_label()
		state.hovering = false
		hover_scale = hover_scale.lerp(base_scale, delta * 15)
		modulate = modulate.lerp(base_modulate, delta * 17)
		state.pressing = false

	if state.tween_progress > 0 and config.animation_scale:
		state.tween_progress = min(state.tween_progress + delta, config.animation_duration)
		bounce_scale = glob.spring(
			Vector2.ONE * config._press_scale,
			Vector2.ONE,
			state.tween_progress,
			config.animation_speed, config.animation_decay, config.animation_scale)
		if state.tween_progress == config.animation_duration:
			state.tween_progress = 0.0
	else:
		bounce_scale = bounce_scale.lerp(Vector2.ONE, delta * 10.0)

	scaler.scale = hover_scale * bounce_scale
	#if button_type == ButtonType.BLOCK_BUTTON:
	#	print(scaler.scale)
	if (!is_equal_approx(scaler.scale.x, base_scale.x) or !base_modulate.is_equal_approx(modulate)):
		if graph and graph is Graph:
			graph.hold_for_frame()
		if graph_root and graph_root is Graph:
			graph_root.hold_for_frame()
	_update_scroll_text(delta)

var freedom: bool = true
var bar: VScrollBar

var _last_extents: Vector4 = Vector4.ZERO
var _last_has_shrink: bool = false


func update_children_reveal() -> void:
	if _contained.is_empty():
		_reveal_dirty = false
		return
	if not is_visible_in_tree() or scroll == null or bar == null:
		_reveal_dirty = false
		return

	var has_shrink: bool = (max_size != 0 and max_size < expanded_size)
	var size_diff_ok: bool = (size.y - base_size.y) > 5.0
	var max_y = size.y + 15.0
	var base_y: float = base_size.y
	var s_pos_y: float = scroll.position.y
	var s_glob_y: float = scroll.global_position.y
	var bar_value: float = bar.value
	var bar_max: float = bar.max_value
	var bar_page: float = bar.page
	var mul_y: float = mult.y

	var extents = Vector4.ZERO
	if has_shrink:
		var top_edge = s_glob_y if (bar_value > 10.0) else -20.0
		var bottom_edge = (s_glob_y + scroll.size.y * scroll.scale.y * mul_y) if (bar_value < (bar_max - bar_page)) else 0.0
		extents = Vector4(top_edge, bottom_edge, 0.0, 0.0)

	var n = _contained.size()
	var stay_hot = false
	var changed_extents = has_shrink != _last_has_shrink or extents != _last_extents
	var a = 0

	for i in n:
		var c: BlockComponent = _contained[i]
		var pos = c._wrapped_in.position.y + s_pos_y
		var new_visible = has_shrink or (pos + c.base_size.y  < max_y)
		var new_free = size_diff_ok and (pos - bar_value < max_y) and (pos - bar_value + c.base_size.y > base_y)

		if c.visible != new_visible or c.freedom != new_free or changed_extents:
			if c.visible != new_visible:
				c.visible = new_visible
				stay_hot = true

			if c.freedom != new_free:
				c.freedom = new_free
				stay_hot = true

			if not new_free:
				if c.modulate.a > _A0:
					var m = c.modulate
					m.a = 0.0
					c.modulate = m
					stay_hot = true
			else:
				if c.modulate.a < _A1:
					stay_hot = true
				var e = extents if has_shrink else Vector4.ZERO
				a += 1
				c.set_instance_shader_parameter("extents", e)
				c.label.set_instance_shader_parameter("extents", e)
	_last_extents = extents
	_last_has_shrink = has_shrink
	_reveal_dirty = stay_hot
	children_revealed.emit()



var _reveal_dirty: bool = false
const _A0 = 0.001
const _A1 = 0.95

var show_request:bool = false

func _proceed_show(at_position: Vector2) -> bool: # virtual
	return true

func menu_show(at_position: Vector2) -> void:
	if static_mode:
		unroll()
		await get_tree().process_frame
		update_children_reveal()
		return
	if graphs.conns_active: return
	if not _proceed_show(at_position): return
	if glob.get_display_mouse_position().y < glob.space_begin.y: return
	if button_type == ButtonType.CONTEXT_MENU and _is_not_menu(): return
	_arm_menu_hit_tests()
	bar.self_modulate.a = 0.0
	state.expanded = false
	show()
	scrolling = false

	last_mouse_pos = at_position
	show_request = true
	scaler.scale = base_scale
	state.tween_hide = false
	state.holding = true
	state.expanding = false
	anchor_position = at_position
	if expand_upwards:
		position = at_position - Vector2(0, base_size.y)
	else:
		position = at_position
	size.y = base_size.y if expand_anim else expanded_size
	modulate = default_modulate
	update_children_reveal()
	await get_tree().process_frame
	update_children_reveal()

func menu_hide() -> void:
	if static_mode:
		return
	state.expanded = false
	if state.tween_hide or not visible: return
	if glob.opened_menu == self:
		glob.opened_menu = null
	if button_type == ButtonType.DROPOUT_MENU:
		
		z_index -= 1
	#if name == "detatch":
		#print(get_stack())

	state.tween_hide = true
	state.tween_progress = 0.0
	state.expanding = false
	state.holding = false

func menu_expand() -> void:
	state.holding = false
	state.expanding = true

func _is_not_menu():
	#if name == "delete_project":
		#print(glob.is_my_menu(self))
	return (not glob.is_my_menu(self))

func pos_clamp(pos: Vector2):
	last_mouse_pos = pos
	pos.x = clamp(pos.x, 0.0, glob.window_size.x - size.x * mult.x)
	if not expand_upwards:
		var max = min(max_size, expanded_size) if max_size else expanded_size
		pos.y = clamp(pos.y, 0.0, glob.window_size.y - max * mult.y)
	return pos

var timer: glob._Timer = null
var scrolling: bool = false
var scroll_anchor: Vector2 = Vector2()
var scroll_checking: bool = false
var target_scroll: float = 0.0
var scroll_value_anchor: float = 0.0
var is_in_bar: bool = false

var prev_z_index: int = 0
func reparent_hide():
	if button_type != ButtonType.DROPOUT_MENU: return
	z_index = prev_z_index
	reparent(graph)


func _arm_menu_hit_tests() -> void:
	if scroll:
		scroll.visible = true
		scroll.mouse_filter = Control.MOUSE_FILTER_STOP
		bar.mouse_filter = Control.MOUSE_FILTER_STOP
		vbox.mouse_filter = Control.MOUSE_FILTER_PASS

func _disarm_menu_hit_tests() -> void:
	if scroll:
		scroll.visible = false
		scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c: BlockComponent in _contained:
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE


@onready var base_tuning = RenderingServer.canvas_item_get_instance_shader_parameter(get_canvas_item(), &"tuning")

func set_tuning(color_: Color):
	RenderingServer.canvas_item_set_instance_shader_parameter(get_canvas_item(), &"tuning", color_)

func reset_tuning():
	RenderingServer.canvas_item_set_instance_shader_parameter(get_canvas_item(), &"tuning", base_tuning)


func unroll():
	show()
	_arm_menu_hit_tests()
	state.expanded = true
	state.holding = false
	state.tween_hide = false
	state.expanding = false
	var target = (min(max_size, expanded_size) if max_size else expanded_size) + size_add
	size.y = target
	bar.self_modulate.a = 1.0
	update_children_reveal()
	glob.occupy(self, &"menu")
	if !static_mode:
		if is_mouse_inside():
			glob.occupy(self, "menu_inside")
		else:
			glob.un_occupy(self, "menu_inside")


@onready var viewport_rect = get_viewport_rect()
func _process_context_menu(delta: float) -> void:
	var reset_menu = not static_mode and _is_not_menu()
	if not is_visible_in_tree() and reset_menu:
		if !static_mode:
			glob.un_occupy(self, &"menu")
			glob.un_occupy(self, "menu_inside")
		return
	
	# mouse state
	var left_pressed = glob.mouse_pressed if !left_activate else glob.mouse_alt_pressed
	var right_pressed = glob.mouse_alt_pressed if !left_activate else glob.mouse_pressed
	var left_click = glob.mouse_just_pressed if !left_activate else glob.mouse_alt_just_pressed
	var right_click = glob.mouse_alt_just_pressed if !left_activate else glob.mouse_just_pressed
	
	var non_splashed = in_splash or !ui.splashed
	left_click = left_click and non_splashed
	right_click = right_click and non_splashed
	right_pressed = right_pressed and non_splashed
	left_pressed = left_pressed and non_splashed
	if graphs.conns_active and button_type == ButtonType.DROPOUT_MENU:
		left_click = false
		right_click = false
	
	if not mouse_open and not reset_menu:
		right_pressed = false
		right_click = false

	if left_click or right_click or ((mouse_open or static_mode or still_hover_in_block) and not left_pressed and not right_pressed):
		last_mouse_pos = get_global_mouse_position()
	#if name == "delete_project":
	#	print(still_hover_in_block)



	if !static_mode and glob.hide_menus and not state.holding and button_type == ButtonType.CONTEXT_MENU:
		left_pressed = false; right_pressed = false
		left_click = false; right_click = false
		menu_hide()
		
	var i_occupied: bool = false
	var inside: bool = is_mouse_inside()
	
	if scroll and visible and (max_size and max_size < expanded_size):
		scroll.size.x = base_size.x - scrollbar_padding

	if inside and visible and not state.tween_hide and (max_size and max_size < expanded_size):
		bar.scale.x = bar_scale_x
		var _bar = ui.is_focus(bar) or get_global_mouse_position().x > global_position.x + (size.x-40) * scale.x * parent.scale.x
		if glob.mouse_just_pressed:
			is_in_bar = _bar
		if _bar:
			block_input()
		else:
			unblock_input()
		glob.occupy(self, &"scroll")
		if is_in_bar:
			scrolling = false; scroll_checking = false
		if glob.mouse_pressed and !is_in_bar:
			if !scrolling and !scroll_checking: 
				scroll_anchor = get_global_mouse_position()
				scroll_value_anchor = scroll.scroll_vertical
				scrolling = false
				scroll_checking = true
			elif scroll_checking:
				if abs(scroll_anchor.y - get_global_mouse_position().y) > 30:
					scroll_anchor = get_global_mouse_position()
					scroll_value_anchor = scroll.scroll_vertical
					scrolling = true
					scroll_checking = false
			elif !is_in_bar: 
				update_children_reveal()
				scroll.scroll_vertical = (-get_global_mouse_position().y  / scale.y + scroll_anchor.y  / scale.y + scroll_value_anchor)
		else:
			scroll_checking = false
			scrolling = false
	else:
		scroll_checking = false
		glob.un_occupy(self, &"scroll")

	if (is_in_bar and glob.mouse_pressed) or scrolling or _reveal_dirty:
		update_children_reveal()

	if static_mode:
		#if inside and not state.tween_hide and visible:
			#glob.occupy(self, "menu_inside")
		#else:
			#glob.un_occupy(self, "menu_inside")
		return

	var do_reset: bool = (reset_menu and (right_click or (left_click and left_activate)) )
	if left_activate and not mouse_open and do_reset:
		state.holding = false
	if show_request or right_click or left_click or is_instance_valid(timer) or do_reset:
		var inside_self_click = glob.mouse_pressed and inside and state.expanding and not state.tween_hide
		if inside_self_click and visible and not state.tween_hide:
			i_occupied = true
			glob.occupy(self, &"menu")
		if not state.holding and (not visible or not inside_self_click):
			# small delay before opening
			if scale_anim and (show_request or right_click):
				timer = glob.timer(0.065)
			# clamp menu position to viewport
			var pos = pos_clamp(last_mouse_pos)
			if (show_request or right_click) and not do_reset and not left_click:
				scrolling = false
				menu_show(pos)
			elif visible and !static_mode:
				scrolling = false
				menu_hide()
	else:
		# while holding LMB expand gradually
		if state.holding and not state.tween_hide:
			menu_expand()
	if not i_occupied:
		glob.un_occupy(self, &"menu")
	
	if inside and not state.tween_hide and visible:
		glob.occupy(self, "menu_inside")
		##if name == "delete_project":
		#	print(last_mouse_pos)
	else:
		glob.un_occupy(self, "menu_inside")

	var target_scale = Vector2(0.94, 0.94) if (scale_anim and (state.holding or state.tween_hide)) else Vector2.ONE
	scaler.scale = scaler.scale.lerp(target_scale * base_scale, 20.0 * delta)

	if state.expanding:
		var target = expanded_size if not max_size else min(max_size, expanded_size)
		target += size_add
		size.y = lerpf(size.y, target, 30.0 * delta) if expand_anim else target
		if expand_upwards:
			position.y = anchor_position.y - size.y * mult.y
		if not is_equal_approx(size.y, target):
			update_children_reveal()
		elif not state.expanded:
			state.expanded = true
			glob.wait(3, true).connect(update_children_reveal)
		bar.self_modulate.a = lerpf(bar.self_modulate.a, 1.0, delta * 10.0)
	elif state.tween_hide:
		state.tween_progress = lerpf(state.tween_progress, 1.0, delta * 5.0)
		# hide once tween almost done
		if state.tween_progress > 0.8 or (button_type == ButtonType.DROPOUT_MENU and state.tween_progress > 0.6):
			if button_type == ButtonType.CONTEXT_MENU:
				hide()
			else:
				reparent_hide()
				current_type = ButtonType.BLOCK_BUTTON
			_disarm_menu_hit_tests()
			scaler.scale = base_scale
			state.tween_hide = false
			state.holding = false
		
		size.y = lerpf(size.y, base_size.y, state.tween_progress)
		if expand_upwards:
			position.y = anchor_position.y - size.y * mult.y
		if button_type == ButtonType.CONTEXT_MENU:
			modulate.a = lerpf(modulate.a, 0.0, state.tween_progress)
		bar.self_modulate.a = 0.0
		update_children_reveal()
	
	show_request = false

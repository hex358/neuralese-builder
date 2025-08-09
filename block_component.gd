@tool
extends ColorRect
class_name BlockComponent

enum ButtonType { CONTEXT_MENU, BLOCK_BUTTON, PANEL, GRAPH_CONTAINER }

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

@export_tool_button("Editor Refresh") var _editor_refresh = func():
	notify_property_list_changed()


@export_group("Meta")
@export var metadata: Dictionary = {}
@export var hint: StringName = &""

@export_group("Text")
@onready var label = $Label
@export var text: String = "":
	set(value):
		text = value
		if not is_node_ready():
			await ready
		label.text = value
		_align_label()
@export var text_color: Color = Color.WHITE:
	set(v):
		if not is_node_ready():
			await ready
		text_color = v; label.modulate = text_color
@export var text_alignment: Vector2 = Vector2()
@export var text_offset: Vector2 = Vector2()


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
@export var _scroll_container = null:
	set(v):
		if !Engine.is_editor_hint():
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
	"hovering": false
}
var last_mouse_pos: Vector2 = Vector2()
var anchor_position: Vector2 = Vector2()  # For upward expansion

func _menu_handle_hover(button: BlockComponent):
	pass

func _menu_handle_hovering(button: BlockComponent):
	pass

func _menu_handle_press(button: BlockComponent):
	pass

func _menu_handle_pressing(button: BlockComponent):
	pass

func _menu_handle_release(button: BlockComponent):
	pass

var vbox: VBoxContainer
var scroll: ScrollContainer
func contain(child: BlockComponent):
	if child.placeholder: return
	if child in _contained: return

	child.reparent(vbox)
	#child.modulate.a = 0.0
	#child.hide()
	
	if child.button_type == ButtonType.BLOCK_BUTTON:
		child.hovered.connect(_menu_handle_hover.bind(child))
		child.hovering.connect(_menu_handle_hovering.bind(child))
		child.pressed.connect(_menu_handle_press.bind(child))
		child.pressing.connect(_menu_handle_pressing.bind(child))
		child.released.connect(_menu_handle_release.bind(child))
	
	if add_to_size:
		expanded_size += child.size.y + arrangement_padding.y
	
	_contained.append(child); child.is_contained = self

var add_to_size: bool = false

func initialize() -> void:
	if Engine.is_editor_hint(): return
	if button_type == ButtonType.CONTEXT_MENU:
		if not scroll:
			default_scroll()
		bar = scroll.get_v_scroll_bar()
		if expanded_size == 0 and !dynamic_size:
			expanded_size = base_size.y
			add_to_size = true
	if button_type == ButtonType.CONTEXT_MENU:
		scroll.size = Vector2(base_size.x - 21, expanded_size if not max_size else max_size-base_size.y-10)
		if not dynamic_size:
			for child in get_children():
				if not child is BlockComponent:
					continue
				contain(child)
			arrange()
			_unclamped_expanded_size = expanded_size
			
		hide()

		if dynamic_size:
			expanded_size = 4.0 + base_size.y
			for child in _contained:
				expanded_size += child.size.y + arrangement_padding.y
			_unclamped_expanded_size = expanded_size
			#vbox.child_exiting_tree.connect(dynamic_child_exit)
			#vbox.child_entered_tree.connect(dynamic_child_enter)

func dynamic_child_exit(child: BlockComponent):
	if child in _contained:
		_unclamped_expanded_size -= floor(child.base_size.y + arrangement_padding.y)
		expanded_size = _unclamped_expanded_size#min(_unclamped_expanded_size, max_size if max_size else _unclamped_expanded_size)
		scroll.size.y = max_size-base_size.y-10
		_contained.erase(child)
	
		

func dynamic_child_enter(child: BlockComponent):
	#if not c is Wrapper: return
	#var child = c.wrapping_target
	_unclamped_expanded_size += floor(child.base_size.y + arrangement_padding.y)
	expanded_size = _unclamped_expanded_size#min(_unclamped_expanded_size, max_size if max_size else _unclamped_expanded_size)
	scroll.size.y = max_size-base_size.y-10
	contain(child)

func resize(_size: Vector2) -> void:
	_size = _size.floor()
	base_size = _size; size = _size; text = text
	alignment = alignment
	#if is_contained:
	_wrapped_in.size = _size
	scaler.size = size
	text = text
	_wrapped_in.custom_minimum_size = _size

var wrapped: bool = false
func arrange():
	# Arrange children above or below based on expand_upwards
	var maxsize: int = 0
	var y = base_size.y * 0.9 if !expand_upwards else expanded_size / 2 - base_size.y * 1.45
	scroll.position = Vector2(arrangement_padding.x, y)
	var is_shrinked: bool = max_size < expanded_size and max_size
	var b_size = base_size.x - 2.2 * arrangement_padding.x
	if is_shrinked:
		b_size -= 14
	#print(_contained)
	for node:BlockComponent in _contained:
		node._wrapped_in.position = Vector2(arrangement_padding.x, y)
		node.resize(Vector2(b_size, round(node.size.y)))
		node.text = node.text
		y += (node.size.y + arrangement_padding.y)
		maxsize += (node.size.y + arrangement_padding.y)
		#print(maxsize)

func _enter_tree() -> void:
	if !Engine.is_editor_hint() and button_type == ButtonType.CONTEXT_MENU:
		assert(not glob.menus.get(menu_name), "Menu %s already regged"%menu_name)
		glob.menus[menu_name] = self
	if !Engine.is_editor_hint():
		pivot_offset = Vector2()


func _create_scaler_wrapper() -> void:
	#parent.remove_child(self)
	var wrapper = Wrapper.new()
	wrapper.position = self.position
	
	wrapped = true
	wrapper.size = self.base_size
	wrapper.custom_minimum_size = self.base_size

	var secondary_wrapper = Wrapper.new()
	secondary_wrapper.position += alignment*size
	wrapper.add_child(secondary_wrapper)
	
	reparent(secondary_wrapper)
	position = -alignment*size
	
	scaler = secondary_wrapper
	scaler.scale = self.scale
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
var auto_ready: bool = true
var auto_wrap: bool = true

func _ready() -> void:
	if not auto_ready: return
	
	initialize()
	size = base_size
	text = text  # Trigger setter
	if !Engine.is_editor_hint() and button_type == ButtonType.BLOCK_BUTTON and not placeholder and auto_wrap:
		_create_scaler_wrapper.call_deferred()

	

func _sub_process(delta: float):
	pass

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
	_sub_process(delta)

func is_mouse_inside() -> bool:
	var height = base_size.y if button_type == ButtonType.BLOCK_BUTTON else expanded_size
	var bounds = Rect2(0, 0, base_size.x + 2*area_padding, height + 2*area_padding)
	bounds.size *= mult
	bounds.position += global_position - Vector2.ONE*area_padding*mult
	return bounds.has_point(last_mouse_pos)

func _align_label() -> void:
	var text_size = glob.get_label_text_size(label) * label.scale
	label.position = (base_size - text_size) / 2 * (text_alignment + Vector2.ONE) + text_offset


var bounce_scale = Vector2.ONE
var hover_scale: Vector2 = Vector2.ONE

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

func _process_block_button(delta: float) -> void:

	if not is_visible_in_tree() or not freedom: 
		return

	var blocked = is_contained and (parent.is_blocking or parent.state.tween_hide or parent.scrolling) or is_blocking
	var frozen = is_contained and parent.is_frozen or is_frozen

	#if parent.name == "add_graph" and text == "Condition":
	#	print(parent.scrolling)

	if not frozen:
		inside = is_mouse_inside() and not blocked
		mouse_pressed = glob.mouse_pressed and not blocked
	if not blocked and (not mouse_pressed or (inside and mouse_pressed)):
		last_mouse_pos = get_global_mouse_position()
	if press_request:
		inside = true; mouse_pressed = true
		if imm_unpress:
			press_request = false

	if inside:
		if mouse_pressed:
			hover_scale = hover_scale.lerp(base_scale * config._press_scale, delta * 30)
			modulate = modulate.lerp(config.press_color, delta * 50)
			state.hovering = false
			if not state.pressing:
				pressed.emit()
				state.pressing = true
				state.tween_progress = 0.0
		else:
			hovering.emit()
			if not state.hovering:
				hovered.emit()
			state.hovering = true
			modulate = modulate.lerp(config.hover_color, delta * 15)
			if state.pressing:
				released.emit()
				state.pressing = false
				hover_scale = base_scale if config.animation_scale else base_scale * config._press_scale
				state.tween_progress = delta
			hover_scale = hover_scale.lerp(base_scale * config._hover_scale, delta * 30)
	else:
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

var freedom: bool = true
var bar: VScrollBar

func update_children_reveal() -> void:
	if not _contained: return
	if not visible: return
	var idx: int = 0
	
	for c in _contained:
		idx += 1
		var max = size.y + 20
		if idx == len(_contained) and len(_contained) > 1: max += 40
		var pos = c._wrapped_in.position.y + scroll.position.y + c.base_size.y
		c.visible = pos < max or (max_size and max_size < expanded_size)
		c.freedom = pos - bar.value < max and pos - bar.value > base_size.y and size.y - base_size.y > 5
		if not c.freedom:
			c.modulate.a = 0.0
		if (max_size and max_size < expanded_size):
			var vec = Vector2(scroll.global_position.y if bar.value > 10.0 else -20.0, 
		scroll.global_position.y+scroll.size.y*scroll.scale.y*mult.y if bar.value < bar.max_value-bar.page else 0.0)
			c.set_instance_shader_parameter("extents", vec)
			c.label.set_instance_shader_parameter("extents", vec)

var show_request:bool = false

func _proceed_show(at_position: Vector2) -> bool: # virtual
	return true

func menu_show(at_position: Vector2) -> void:
	if not _proceed_show(at_position): return
	if _is_not_menu(): return
	bar.self_modulate.a = 0.0
	show()
	scrolling = false
	if not secondary:
		#if glob.opened_menu:
		#	glob.opened_menu.menu_hide()
		glob.opened_menu = self
		

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
	if glob.opened_menu == self:
		glob.opened_menu = null
	if state.tween_hide or not visible: return
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
	return (glob.mouse_alt_pressed and not glob.is_my_menu(self))

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

@onready var viewport_rect = get_viewport_rect()
func _process_context_menu(delta: float) -> void:
	# click belongs to another menu
	var reset_menu = _is_not_menu()
	if not is_visible_in_tree() and reset_menu:
		return
	
	# mouse state
	var left_pressed = glob.mouse_pressed
	var right_pressed = glob.mouse_alt_pressed
	var left_click = glob.mouse_just_pressed
	var right_click = glob.mouse_alt_just_pressed
	
	if not mouse_open and not reset_menu:
		right_pressed = false
		right_click = false

	if left_click or right_click or (mouse_open and not left_pressed and not right_pressed):
		last_mouse_pos = get_global_mouse_position()

	if glob.hide_menus and not state.holding:
		left_pressed = false; right_pressed = false
		left_click = false; right_click = false
		menu_hide()
		
	var i_occupied: bool = false
	var inside: bool = is_mouse_inside()
	
	if inside and visible and not state.tween_hide and (max_size and max_size < expanded_size):
		bar.scale.x = 1.2
		var _bar = ui.is_focus(bar) or get_global_mouse_position().x > global_position.x + (size.x-40) * scale.x * parent.scale.x
		if glob.mouse_just_pressed:
			is_in_bar = _bar
		if _bar:
			block_input()
		else:
			unblock_input()
		glob.occupy(self, &"scroll")
		target_scroll += glob.mouse_scroll * delta * 10.0
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
				scroll.scroll_vertical = -get_global_mouse_position().y + scroll_anchor.y + scroll_value_anchor
		else:
			scroll_checking = false
			scrolling = false
	else:
		scroll_checking = false
		glob.un_occupy(self, &"scroll")
	
	if show_request or right_click or left_click or is_instance_valid(timer) or (reset_menu and right_click):
		var inside_self_click = left_click and inside
		if inside_self_click and visible and not state.tween_hide:
			i_occupied = true
			glob.occupy(self, &"menu")
		if not state.holding and (not visible or not inside_self_click):
			# small delay before opening
			if scale_anim and (show_request or right_click):
				timer = glob.timer(0.065)
			# clamp menu position to viewport
			var pos = pos_clamp(last_mouse_pos)
			
			if (show_request or right_click) and not reset_menu and not left_click:
				scrolling = false
				menu_show(pos)
			elif visible:
				scrolling = false
				menu_hide()
	else:
		# while holding LMB expand gradually
		if state.holding and not state.tween_hide:
			menu_expand()
	if not i_occupied:
		glob.un_occupy(self, &"menu")
	
	var target_scale = Vector2(0.94, 0.94) if (scale_anim and (state.holding or state.tween_hide)) else Vector2.ONE
	scaler.scale = scaler.scale.lerp(target_scale * base_scale, 20.0 * delta)

	if state.expanding:
		var target = expanded_size if not max_size else min(max_size, expanded_size)
		size.y = lerpf(size.y, target, 30.0 * delta) if expand_anim else target
		if expand_upwards:
			position.y = anchor_position.y - size.y * mult.y
		if not is_equal_approx(size.y, target):
			update_children_reveal()
		bar.self_modulate.a = lerpf(bar.self_modulate.a, 1.0, delta * 10.0)
	elif state.tween_hide:
		state.tween_progress = lerpf(state.tween_progress, 1.0, delta * 5.0)
		# hide once tween almost done
		if state.tween_progress > 0.8:
			hide()
			scaler.scale = base_scale
			state.tween_hide = false
			state.holding = false
		
		size.y = lerpf(size.y, base_size.y, state.tween_progress)
		if expand_upwards:
			position.y = anchor_position.y - size.y * mult.y
		
		modulate = modulate.lerp(Color.TRANSPARENT, state.tween_progress)
		update_children_reveal()
	
	show_request = false

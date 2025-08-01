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
@export var size_arrangement_allowed: bool = true

@export_tool_button("Editor Refresh") var _editor_refresh = func():
	notify_property_list_changed()


@export_group("Meta")
@export var metadata: Dictionary = {}
@export var hint: StringName = &""

@export_group("Text")
@onready var label = $Label
@export var icon: String = ""
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
		pivot_offset = floor(alignment * size)

@export_group("Context Menu")
@export var expanded_size: float = 190.0
@export var expand_delay: bool = false
@export var arrangement_padding: Vector2 = Vector2(10, 5)
@export var mouse_open: bool = true
@export var menu_type: StringName = &""
@export var dynamic_size: bool = false
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
	"pressing": false
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

func contain(child: BlockComponent):
	if child.button_type == ButtonType.BLOCK_BUTTON:
		child.hovered.connect(_menu_handle_hover.bind(child))
		child.hovering.connect(_menu_handle_hovering.bind(child))
		child.pressed.connect(_menu_handle_press.bind(child))
		child.pressing.connect(_menu_handle_pressing.bind(child))
		child.released.connect(_menu_handle_release.bind(child))
	_contained.append(child); child.is_contained = true

func initialize() -> void:
	if not Engine.is_editor_hint():
		match button_type:
			ButtonType.CONTEXT_MENU:
				for child in get_children():
					if not child is BlockComponent:
						continue
					contain(child)
				arrange()
				hide()
			ButtonType.BLOCK_BUTTON:
				pass
		if dynamic_size:
			expanded_size = 6.0 + base_size.y
			for child in _contained:
				expanded_size += child.size.y + arrangement_padding.y
			child_exiting_tree.connect(dynamic_child_exit)
			child_entered_tree.connect(dynamic_child_enter)

func dynamic_child_exit(child):
	if child is BlockComponent and child in _contained:
		expanded_size -= child.size.y + arrangement_padding.y
		_contained.erase(child)

func dynamic_child_enter(child):
	if child is BlockComponent:
		expanded_size += child.size.y + arrangement_padding.y
		contain(child)

func resize(_size: Vector2) -> void:
	base_size = _size; size = _size; text = text
	alignment = alignment

func arrange():
	# Arrange children above or below based on expand_upwards
	var y = base_size.y * 0.9 if !expand_upwards else expanded_size / 2 - base_size.y * 1.45

	for node:BlockComponent in _contained:
		var xo = arrangement_padding.x
		node.position = Vector2(xo, y)
		if node.size_arrangement_allowed:
			var b_size = base_size.x - 2.2 * xo
			node.resize(Vector2(b_size, node.size.y))
			node.text = node.text
		y += (node.size.y + arrangement_padding.y)

func _enter_tree() -> void:
	if !Engine.is_editor_hint() and button_type == ButtonType.CONTEXT_MENU:
		assert(not glob.menus.get(menu_type), "Menu %s already regged"%menu_type)
		glob.menus[menu_type] = self

var _contained = []
func _ready() -> void:
	initialize()
	size = base_size
	text = text  # Trigger setter

func _sub_process(delta: float):
	pass

var mult: Vector2 = Vector2.ONE
func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		_align_label()
		base_size = size
		return
	
	mult = scale * parent.scale
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
var is_contained: bool = false
var inside: bool = false
var mouse_pressed: bool = false


func _process_block_button(delta: float) -> void:
	if not is_visible_in_tree(): return
	var blocked = is_contained and parent.is_blocking
	var frozen = is_contained and parent.is_frozen
	
	if not frozen:
		inside = is_mouse_inside() and not blocked
		mouse_pressed = glob.mouse_pressed and not blocked
	if not blocked and (not mouse_pressed or glob.mouse_just_pressed):
		last_mouse_pos = get_global_mouse_position()

	if inside:
		if mouse_pressed:
			hover_scale = hover_scale.lerp(base_scale * config._press_scale, delta * 30)
			modulate = modulate.lerp(config.press_color, delta * 50)
			if not state.pressing:
				pressed.emit()
				state.pressing = true
				state.tween_progress = 0.0
		else:
			hovering.emit()
			modulate = modulate.lerp(config.hover_color, delta * 15)
			if state.pressing:
				released.emit()
				state.pressing = false
				hover_scale = base_scale if config.animation_scale else base_scale * config._press_scale
				state.tween_progress = delta
			hover_scale = hover_scale.lerp(base_scale * config._hover_scale, delta * 30)
	else:
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

	scale = hover_scale * bounce_scale

func _update_children_reveal() -> void:
	if not _contained: return
	for c in _contained:
		if expand_upwards:
			c.visible = c.position.y + c.size.y < size.y + 20
		else:
			c.visible = c.position.y + c.size.y < size.y + 20
		if not c.visible:
			c.modulate = Color(c.base_modulate.r, c.base_modulate.g, c.base_modulate.b, 0.0)

var show_request:bool = false
func menu_show(at_position: Vector2) -> void:
	show()
	show_request = true
	scale = base_scale
	state.tween_hide = false
	state.holding = true
	state.expanding = false
	anchor_position = at_position
	if expand_upwards:
		position = at_position - Vector2(0, base_size.y)
	else:
		position = at_position
	size.y = base_size.y
	modulate = default_modulate
	_update_children_reveal()

func menu_hide() -> void:
	if state.tween_hide or not visible: return
	state.tween_hide = true
	state.tween_progress = 0.0
	state.expanding = false
	state.holding = false

func menu_expand() -> void:
	state.holding = false
	state.expanding = true

func _is_not_menu():
	return (not glob.is_my_menu(self) and glob.mouse_alt_pressed)

func pos_clamp(pos: Vector2):
	last_mouse_pos = pos
	pos.x = clamp(pos.x, 0.0, viewport_rect.size.x - size.x * mult.x)
	if not expand_upwards:
		pos.y = clamp(pos.y, 0.0, viewport_rect.size.y - expanded_size * mult.y)
	return pos

var timer: glob._Timer = null
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

	if left_click or right_click or (not left_pressed and not right_pressed):
		last_mouse_pos = get_global_mouse_position()

	if glob.hide_menus and not state.holding:
		left_pressed = false; right_pressed = false
		left_click = false; right_click = false
		
		menu_hide()

	var i_occupied: bool = false
	if show_request or right_click or left_click or is_instance_valid(timer) or (reset_menu and right_click):
		var inside_self_click = left_click and is_mouse_inside()
		if inside_self_click and visible and not state.tween_hide:
			i_occupied = true
			glob.occupy(self, &"menu")
		if not state.holding and (not visible or not inside_self_click):
			# small delay before opening
			if expand_delay and (show_request or right_click):
				timer = glob.timer(0.065)
			# clamp menu position to viewport
			var pos = pos_clamp(last_mouse_pos)
			
			if (show_request or right_pressed) and not reset_menu and not left_click:
				menu_show(pos)
			elif visible:
				menu_hide()
	else:
		# while holding LMB expand gradually
		if state.holding and not state.tween_hide:
			menu_expand()
	if not i_occupied:
		glob.un_occupy(self, &"menu")
	
	var target_scale = Vector2(0.94, 0.94) if (state.holding or state.tween_hide) else Vector2.ONE
	scale = scale.lerp(target_scale * base_scale, 20.0 * delta)

	if state.expanding:
		size.y = lerpf(size.y, expanded_size, 30.0 * delta)
		if expand_upwards:
			position.y = anchor_position.y - size.y * mult.y
		_update_children_reveal()
	elif state.tween_hide:
		state.tween_progress = lerpf(state.tween_progress, 1.0, delta * 5.0)
		
		# hide once tween almost done
		if state.tween_progress > 0.8:
			hide()
			scale = base_scale
			state.tween_hide = false
			state.holding = false
		
		size.y = lerpf(size.y, base_size.y, state.tween_progress)
		if expand_upwards:
			position.y = anchor_position.y - size.y * mult.y
		
		modulate = modulate.lerp(Color.TRANSPARENT, state.tween_progress)
		_update_children_reveal()
	
	show_request = false

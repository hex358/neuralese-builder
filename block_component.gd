@tool
extends Control
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
	_update_instance_uniforms()

func _update_instance_uniforms() -> void:
	# Retrieve and apply per-instance shader uniforms
	var canvas_id = get_canvas_item()
	_instance_uniforms = RenderingServer.canvas_item_get_instance_shader_parameter_list(canvas_id)
	if _instance_uniforms.size() > 0:
		for uniform in _instance_uniforms:
			var name = uniform.name
			var value = get_instance_shader_parameter(name) if name != "disabled" else false
			rect.set_instance_shader_parameter(name, value)

@export_group("Meta")
@export var metadata: Dictionary = {}
@export var hint: StringName = &""

@export_group("Text")
@onready var label = $ColorRect/root/Label
@onready var children_root = $ColorRect/root
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
@export var rect_center: Vector2 = Vector2(1, 1):
	set(value):
		rect_center = value
		if not is_node_ready(): 
			await ready
		_align_rect(); _align_label()
@onready var rect = $ColorRect

@export_group("Context Menu")
@export var expanded_size: float = 190.0
@export var arrangement_padding: Vector2 = Vector2(10, 5)
@export var expand_upwards: bool = false:
	set(v):
		if v != expand_upwards:
			expand_upwards = v
			if not Engine.is_editor_hint():
				arrange()

@export_group("Button")
@export var config: ButtonConfig

signal pressed
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

func _menu_handle_press(button: BlockComponent):
	pass

func _menu_handle_release(button: BlockComponent):
	pass

func initialize() -> void:
	if not Engine.is_editor_hint():
		match button_type:
			ButtonType.CONTEXT_MENU:
				for child in get_children():
					if not child is BlockComponent:
						continue
					elif child.button_type == ButtonType.BLOCK_BUTTON:
						child.pressed.connect(_menu_handle_press.bind(child))
						child.released.connect(_menu_handle_release.bind(child))
					_contained.append(child); child.is_contained = true
				arrange()
				hide()
			ButtonType.BLOCK_BUTTON:
				pass

func resize(_size: Vector2) -> void:
	rect.size = _size
	base_size = _size; size = _size; text = text

func arrange():
	# Arrange children above or below based on expand_upwards
	var y = base_size.y * 0.9 if !expand_upwards else expanded_size / 2 - base_size.y * 1.45

	for node:BlockComponent in _contained:
		var xo = arrangement_padding.x
		node._align_rect()
		node.position = -node.rect_offset + Vector2(xo, y)
		if node.size_arrangement_allowed:
			var b_size = base_size.x - 2.3 * xo
			node.resize(Vector2(b_size, node.size.y))
			node.text = node.text
		y += (node.size.y + arrangement_padding.y)

var _contained = []
func _ready() -> void:
	initialize()
	_update_instance_uniforms()
	rect.size = base_size
	text = text  # Trigger setter

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		rect.size = size
		if rect.size != base_size:
			_align_label()
			base_size = rect.size
		return

	match button_type:
		ButtonType.CONTEXT_MENU:
			_process_context_menu(delta)
		ButtonType.BLOCK_BUTTON:
			_process_block_button(delta)

func _is_mouse_inside() -> bool:
	var height = base_size.y if button_type == ButtonType.BLOCK_BUTTON else expanded_size
	var bounds = Rect2(-area_padding, -area_padding, base_size.x + area_padding, height + area_padding)
	bounds.position += global_position + rect_offset
	return bounds.has_point(last_mouse_pos)

func _align_label() -> void:
	var text_size = glob.get_label_text_size(label) * label.scale
	label.position = (base_size - text_size) / 2 * (text_alignment + Vector2.ONE) + text_offset

var rect_offset: Vector2 = Vector2()
func _align_rect() -> void:
	rect.position = base_size * (rect_center - Vector2(0.5, 0.5))
	rect_offset = rect.position

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
		inside = _is_mouse_inside()
		mouse_pressed = Input.is_action_pressed("ui_mouse") and not blocked
	if not blocked and (not mouse_pressed or Input.is_action_just_pressed("ui_mouse")):
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
			c.visible = c.position.y + c.rect.size.y < rect.size.y + 20
		else:
			c.visible = c.position.y + c.rect.size.y < rect.size.y + 20
		if not c.visible:
			c.modulate = Color(c.base_modulate.r, c.base_modulate.g, c.base_modulate.b, 0.0)

func menu_show(at_position: Vector2) -> void:
	show()
	scale = base_scale
	state.tween_hide = false
	state.holding = true
	state.expanding = false
	anchor_position = at_position
	if expand_upwards:
		position = at_position - Vector2(0, base_size.y)
	else:
		position = at_position
	rect.size.y = base_size.y
	modulate = default_modulate
	_update_children_reveal()

func menu_hide() -> void:
	if state.tween_hide: return
	state.tween_hide = true
	state.tween_progress = 0.0
	state.expanding = false
	state.holding = false

func menu_expand() -> void:
	state.holding = false
	state.expanding = true

@onready var viewport_rect = get_viewport_rect()
func _process_context_menu(delta: float) -> void:
	var left = Input.is_action_pressed("ui_mouse")
	var right = Input.is_action_pressed("ui_mouse_alt")
	var just_left = Input.is_action_just_pressed("ui_mouse")
	var just_right = Input.is_action_just_pressed("ui_mouse_alt")

	if just_left or just_right or (not left and not right):
		last_mouse_pos = get_global_mouse_position()
		if just_right:
			expand_upwards = last_mouse_pos.y > viewport_rect.size.y - 70
	
	if glob.hide_menus:
		left = false; right = false; just_left = false; just_right = false
		menu_hide()

	if left or right:
		if not state.holding and (not visible or not _is_mouse_inside()):
			var pos = last_mouse_pos
			pos.x = clamp(pos.x, 0, viewport_rect.size.x - size.x)
			if not expand_upwards:
				pos.y = clamp(pos.y, 0, viewport_rect.size.y - expanded_size)
			if right:
				menu_show(pos)
			else:
				menu_hide()
	elif state.holding and not state.tween_hide:
		menu_expand()

	var target = Vector2(0.94, 0.94) if (state.holding or state.tween_hide) else Vector2.ONE
	scale = scale.lerp(target, 20.0 * delta)

	if state.expanding:
		rect.size.y = lerpf(rect.size.y, expanded_size, 30.0 * delta)
		if expand_upwards:
			position.y = anchor_position.y - rect.size.y
		_update_children_reveal()
	elif state.tween_hide:
		state.tween_progress = lerpf(state.tween_progress, 1.0, delta * 5.0)
		if state.tween_progress > 0.8:
			hide(); scale = base_scale
			state.tween_hide = false; state.holding = false
		rect.size.y = lerpf(rect.size.y, base_size.y, state.tween_progress)
		if expand_upwards:
			position.y = anchor_position.y - rect.size.y
		modulate = modulate.lerp(Color.TRANSPARENT, state.tween_progress)
		_update_children_reveal()

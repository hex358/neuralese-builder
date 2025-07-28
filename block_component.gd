## A customizable block component supporting context menu and button behaviors.

@tool
extends Control
class_name BlockComponent

enum ButtonType { CONTEXT_MENU, BLOCK_BUTTON }
enum ActivateOn { ON_RELEASE, ON_PRESS }

var _instance_uniforms = []

@export var button_type: ButtonType = ButtonType.CONTEXT_MENU
@export var area_padding: float = 0.0
@export_tool_button("Editor Refresh") var _editor_refresh = func():
	# Refresh property list and update shader parameters
	notify_property_list_changed()
	_update_instance_uniforms()

func _update_instance_uniforms() -> void:
	# Retrieve and apply per-instance shader uniforms
	var canvas_id = get_canvas_item()
	_instance_uniforms = RenderingServer.canvas_item_get_instance_shader_parameter_list(canvas_id)
	if _instance_uniforms.size() > 0:
		for uniform in _instance_uniforms:
			var name = uniform.name
			var value = get_instance_shader_parameter(name) if (name != "disabled") else false
			rect.set_instance_shader_parameter(name, value)

@export_group("Text")
@export var label: Control
@export var children_root: CanvasItem
@export var icon: String = ""
@export var text: String = "":
	set(value):
		text = value
		if is_node_ready():
			label.text = value
			_align_label()

@export_group("Rect")
@export var base_size: Vector2 = size
@export var alignment: Vector2 = Vector2(1, 1):
	set(value):
		alignment = value
		_align_rect()
@export var rect: ColorRect

@export_group("Context Menu")
@export var expanded_size: float = 190.0

@export_group("Button")
@export var activate_on = ActivateOn.ON_RELEASE
@export var hover_color: Color = Color.BLUE
@export var press_color: Color = Color.RED

signal pressed(args: Dictionary)

@onready var default_modulate: Color = modulate
@onready var base_modulate: Color = modulate

const EPSILON: float = 0.0002

var state = {
	"expanding": false,
	"holding": false,
	"tween_hide": false,
	"tween_progress": 0.0,
	"hovering": false
}
var last_mouse_pos: Vector2 = Vector2()

func _ready() -> void:
	# Initialize shader uniforms and size
	_update_instance_uniforms()
	rect.size = base_size
	text = text  # Triggers setter
	if not Engine.is_editor_hint():
		# Reparent children under children_root
		for child in get_children():
			if child != children_root and child != rect:
				child.reparent(children_root)
		match button_type:
			ButtonType.CONTEXT_MENU:
				hide()
			ButtonType.BLOCK_BUTTON:
				pass

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		# Editor: sync size changes
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
	# Define interaction bounds
	var height = base_size.y if (button_type == ButtonType.BLOCK_BUTTON) else expanded_size
	var bounds = Rect2(-area_padding, -area_padding, base_size.x + area_padding, height + area_padding)
	bounds.position += position + base_rect_pos
	return bounds.has_point(last_mouse_pos)

func get_label_text_size(lbl: Label) -> Vector2:
	# Measure label text size
	var font = lbl.get_theme_font("font")
	var size = lbl.get_theme_font_size("font_size")
	return font.get_string_size(lbl.text, lbl.horizontal_alignment, -1, size)

func _align_label() -> void:
	# Center label within base_size
	var text_size = get_label_text_size(label) * label.scale
	label.position = (base_size - text_size) / 2

var base_rect_pos: Vector2 = Vector2()
func _align_rect() -> void:
	# Position rect based on alignment
	rect.position = base_size * (alignment - Vector2(0.5, 0.5))
	base_rect_pos = rect.position

func _process_block_button(delta: float) -> void:
	var inside = _is_mouse_inside()
	# Hover spring animation
	if state.tween_progress > 0 and (1.0 - state.tween_progress) > EPSILON:
		state.tween_progress += delta
		scale = glob.spring(Vector2(0.9, 0.9), Vector2.ONE, state.tween_progress, 3, 6)

	var pressed = Input.is_action_pressed("ui_mouse")
	if not pressed or Input.is_action_just_pressed("ui_mouse"):
		last_mouse_pos = get_global_mouse_position()

	if inside:
		if pressed:
			# Press down effect
			state.hovering = true
			scale = scale.lerp(Vector2(0.9, 0.9), delta * 30)
			modulate = modulate.lerp(press_color, delta * 50)
			state.tween_progress = 0.0
		else:
			# Hover release effect
			modulate = modulate.lerp(hover_color, delta * 15)
			if state.hovering:
				state.tween_progress += delta
				state.hovering = false
			else:
				scale = scale.lerp(Vector2.ONE, delta * 30)
	else:
		# Reset when outside
		if not state.hovering:
			scale = scale.lerp(Vector2.ONE, delta * 15)
		modulate = modulate.lerp(base_modulate, delta * 17)

func _process_context_menu(delta: float) -> void:
	var left = Input.is_action_pressed("ui_mouse")
	var right = Input.is_action_pressed("ui_mouse_alt")
	var just_left = Input.is_action_just_pressed("ui_mouse")
	var just_right = Input.is_action_just_pressed("ui_mouse_alt")

	if just_left or just_right or (not left and not right):
		last_mouse_pos = get_global_mouse_position()

	if left or right:
		if not state.holding and (not visible or not _is_mouse_inside()):
			if right:
				# Show context menu at mouse
				show()
				state.tween_hide = false
				state.holding = true
				position = get_global_mouse_position()
				rect.size.y = base_size.y
				modulate = default_modulate
			else:
				# Start hiding animation
				state.tween_hide = true
				state.tween_progress = 0.0
			state.expanding = false
	elif state.holding and not state.tween_hide:
		# Start expanding if released
		state.holding = false
		state.expanding = true

	# Scale animation
	var target = Vector2(0.94, 0.94) if (state.holding or state.tween_hide) else Vector2.ONE
	scale = scale.lerp(target, 20.0 * delta)

	if state.expanding:
		# Expand menu height
		rect.size.y = lerpf(rect.size.y, expanded_size, 30.0 * delta)
	elif state.tween_hide:
		# Shrink and fade out
		state.tween_progress = lerpf(state.tween_progress, 1.0, delta * 20)
		if 1.0 - state.tween_progress < EPSILON:
			hide()
			state.tween_hide = false
		rect.size.y = lerpf(rect.size.y, base_size.y, state.tween_progress)
		modulate = modulate.lerp(Color.TRANSPARENT, state.tween_progress)

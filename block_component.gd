## A customizable block component supporting context menu and button behaviors.

@tool
extends Control
class_name BlockComponent

enum ButtonType { CONTEXT_MENU, BLOCK_BUTTON }

var _instance_uniforms = []

@export var button_type: ButtonType = ButtonType.CONTEXT_MENU
@export var area_padding: float = 0.0
@export var size_arrangement_allowed: bool = true
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
@export var text_alignment: Vector2 = Vector2()
@export var text_offset: Vector2 = Vector2()

@export_group("Rect")
@export var base_size: Vector2 = size
@export var rect_center: Vector2 = Vector2(1, 1):
	set(value):
		rect_center = value
		_align_rect()
@export var rect: ColorRect

@export_group("Context Menu")
@export var expanded_size: float = 190.0
@export var arrangement_padding: Vector2 = Vector2(10, 5)

@export_group("Button")
@export var config: ButtonConfig

signal pressed
signal released

@onready var default_modulate: Color = modulate
@onready var base_modulate: Color = modulate
@onready var base_scale: Vector2 = scale

const EPSILON: float = 0.0002

var state = {
	"expanding": false,
	"holding": false,
	"tween_hide": false,
	"tween_progress": 0.0,
	"pressing": false
}
var last_mouse_pos: Vector2 = Vector2()

func _enter_tree() -> void:
	if not Engine.is_editor_hint():
		# Identify children in containment
		match button_type:
			ButtonType.CONTEXT_MENU:
				for child in get_children():
					if child is BlockComponent:
						_contained.append(child)
				arrange()
				hide()
			ButtonType.BLOCK_BUTTON:
				pass

func arrange():
	var y: int = base_size.y * 0.9
	for node in _contained:
		var xo: int = arrangement_padding.x
		node.position = -node.rect_offset + Vector2(xo, y)
		var b_size: int = base_size.x - 2.3*xo
		if node.size_arrangement_allowed:
			node.base_size.x = b_size; node.size.x = b_size
			node.text = node.text
		y += node.size.y + arrangement_padding.y

var _contained = []
func _ready() -> void:
	# Initialize shader uniforms and size
	_update_instance_uniforms()
	rect.size = base_size
	text = text  # Triggers setter

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
	bounds.position += global_position + rect_offset
	return bounds.has_point(last_mouse_pos)

func get_label_text_size(lbl: Label) -> Vector2:
	# Measure label text size
	var font = lbl.get_theme_font("font")
	var size = lbl.get_theme_font_size("font_size")
	return font.get_string_size(lbl.text, lbl.horizontal_alignment, -1, size)

func _align_label() -> void:
	# Center label within base_size
	var text_size = get_label_text_size(label) * label.scale
	label.position = (base_size - text_size) / 2 * (text_alignment+Vector2.ONE) + text_offset

var rect_offset: Vector2 = Vector2()
func _align_rect() -> void:
	# Position rect based on rect_center
	rect.position = base_size * (rect_center - Vector2(1, 1)) * 0.5
	rect_offset = rect.position

var bounce_scale = Vector2.ONE
var hover_scale:Vector2 = Vector2.ONE
func _process_block_button(delta: float) -> void:
	var inside = _is_mouse_inside()
	var mouse_pressed = Input.is_action_pressed("ui_mouse")
	if not mouse_pressed or Input.is_action_just_pressed("ui_mouse"):
		last_mouse_pos = get_global_mouse_position()

	if inside:
		if mouse_pressed:
			# press-down
			hover_scale = hover_scale.lerp(base_scale*config._press_scale, delta * 30)
			modulate = modulate.lerp(config.press_color, delta * 50)
			# begin a bounce when the press is released:
			if not state.pressing:
				pressed.emit()
				state.pressing = true
				state.tween_progress = 0.0
		else:
			# hovering
			modulate = modulate.lerp(config.hover_color, delta * 15)
			# if we just let go, kick off the bounce
			if state.pressing:
				released.emit()
				state.pressing = false
				if config.animation_scale:
					hover_scale = base_scale
				else:
					hover_scale = base_scale*config._press_scale
				state.tween_progress = delta
			hover_scale = hover_scale.lerp(base_scale*config._hover_scale, delta * 30)
	else:
		# outside
		hover_scale = hover_scale.lerp(base_scale, delta * 15)
		modulate = modulate.lerp(base_modulate, delta * 17)
		state.pressing = false

	if state.tween_progress > 0 and config.animation_scale:
		state.tween_progress = min(state.tween_progress + delta, config.animation_duration)
		bounce_scale = glob.spring(
			Vector2.ONE*config._press_scale,
			Vector2.ONE,
			state.tween_progress,
			config.animation_speed, config.animation_decay, config.animation_scale)
		# end bounce once progress completes:
		if state.tween_progress == config.animation_duration:
			state.tween_progress = 0.0
	else:
		bounce_scale = bounce_scale.lerp(Vector2.ONE, delta*10.0)

	# addictive
	scale = hover_scale * bounce_scale

func _update_children_reveal() -> void:
	var count = _contained.size()
	if count == 0: return
	var segment = expanded_size / count
	for i in range(count):
		var c = _contained[i]
		var start = base_size.y + segment * i
		c.visible = c.position.y < rect.size.y - 10

var t = 0
func _process_context_menu(delta: float) -> void:
	t += 1
	
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
				_update_children_reveal()
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
		_update_children_reveal()
		rect.size.y = lerpf(rect.size.y, expanded_size, 30.0 * delta)
	elif state.tween_hide:
		# Shrink and fade out
		state.tween_progress = lerpf(state.tween_progress, 1.0, delta * 22.0)
		if 1.0 - state.tween_progress < EPSILON:
			hide()
			state.tween_hide = false
		rect.size.y = lerpf(rect.size.y, base_size.y, state.tween_progress)
		modulate = modulate.lerp(Color.TRANSPARENT, state.tween_progress)
		_update_children_reveal()
		

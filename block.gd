@tool
extends ColorRect
class_name ButtonComponent
enum ButtonTypes {ContextMenu, BlockButton}
enum ActivateOn {OnRelease, OnPress}

@export var type = ButtonTypes.ContextMenu
@export var area_padding: float = 0.0
@export_tool_button("Editor Refresh") var _editor_refresh = func():
	notify_property_list_changed()

@export_group("Text")
@export var label: Control
@export var children_root: CanvasItem
@export var icon: String = ""
@export var text: String = "":
	set(v):
		text = v
		if is_instance_valid(label):
			label.text = v
		label_align()

@export_group("Style")

@export_group("Context Menu")
@export var expanded_size: float = 190.0

@export_group("Button")
@export var activate_on = ActivateOn.OnRelease
@export var hover_color: Color = Color.BLUE
@export var press_color: Color = Color.RED

@onready var default_modulate: Color = modulate
@onready var base_size: Vector2 = size

signal pressed(args: Dictionary)

var state = {"expanding": false, 
"holding": false, 
"tween_hide": false,
"tween_progress": 0.0, 
"hovering": false}

func mouse_in_bounds() -> bool:
	return Rect2(-area_padding,
	-area_padding,
	self.size.x + area_padding,
	self.expanded_size + area_padding).has_point(get_local_mouse_position())

func _ready():
	size = base_size
	text = text
	if not Engine.is_editor_hint() and type == ButtonTypes.ContextMenu: 
		for child in get_children():
			if child != children_root: child.reparent(children_root)
		hide()

func get_label_text_size(label: Label) -> Vector2:
	var font: Font = label.get_theme_font("font")
	var size: int = label.get_theme_font_size("font_size")
	return font.get_string_size(
		label.text,
		label.horizontal_alignment,
		-1,
		size
	)

func label_align() -> void:
	label.position = size / 2 - get_label_text_size(label) / 2 * label.scale

func spring(from:, to, t: float, frequency: float = 4.5, damping: float = 5.0):
	t = clamp(t, 0.0, 1.0)
	var omega = frequency * PI * 2.0
	var decay = exp(-damping * t)
	var factor = 1.0 - decay * (cos(omega * t) + (damping / omega) * sin(omega * t))
	return from + (to-from) * factor

func _process(delta: float):
	if Engine.is_editor_hint(): 
		if size != base_size: label_align(); base_size = size
		return
	match self.type:
		ButtonTypes.ContextMenu: _process_context_menu(delta)
		ButtonTypes.BlockButton: _process_block_button(delta)

var prog = 0.0
func _process_block_button(delta: float) -> void:
	var mouse:bool = Input.is_action_pressed("ui_mouse")
	var in_bounds:bool = mouse_in_bounds()
	if state.hovering != in_bounds: prog = 0.0
	state.hovering = in_bounds
	if in_bounds:
		prog += delta
		self.scale = spring(Vector2.ONE, Vector2(0.9, 0.9), prog)
	else:
		prog += delta
		self.scale = spring(Vector2(0.9, 0.9), Vector2.ONE, prog)

func _process_context_menu(delta: float) -> void:
	var mouse:bool = Input.is_action_pressed("ui_mouse")
	var mouse_alt:bool = Input.is_action_pressed("ui_mouse_alt")

	if mouse or mouse_alt:
		if not state.holding and (!visible or !mouse_in_bounds()):
						  # only when mouse is just pressed and mouse is not inside menu
			if mouse_alt: # Context menus are shown on right mouse button
				show(); state.tween_hide = false; state.holding = true
				self.position = get_global_mouse_position(); self.size.y = base_size.y
				modulate = default_modulate

			elif mouse: 
				state.tween_hide = true
				state.tween_progress = 0.0
				
			state.expanding = false

	elif state.holding and not state.tween_hide:
		state.holding = false; state.expanding = true

	if state.holding or state.tween_hide: # becomes a little bit smaller
		self.scale = self.scale.lerp(Vector2(0.94, 0.94), 20.0 * delta)
	else:
		self.scale = self.scale.lerp(Vector2.ONE, 20.0 * delta)

	if state.expanding:
		self.size.y = lerpf(self.size.y, expanded_size, 30.0 * delta)

	elif state.tween_hide:
		state.tween_progress = lerpf(state.tween_progress, 1.0, delta * 20.0)
		if is_equal_approx(state.tween_progress, 1.0): hide(); state.tween_hide = false
		self.size.y = lerpf(self.size.y, base_size.y, state.tween_progress)
		self.modulate = self.modulate.lerp(Color.TRANSPARENT, state.tween_progress)



extends LineEdit
class_name ValidInput

@export var accept_button: BlockComponent

@export var resize_after: int = 0
func _ready() -> void:
	
	text_changed.connect(_input_changed)
	text_submitted.connect(_input_submit)

func set_valid(valid: bool):
	is_valid = valid



func _process(delta: float) -> void:
	pass

@onready var base_text_color = get_theme_color(&"font_color")
func set_text_color(color: Color):
	add_theme_color_override(&"font_color", color)

func reset_text_color():
	add_theme_color_override(&"font_color", base_text_color)


func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and
		event.button_index == 2 and
		event.pressed):
		get_viewport().set_input_as_handled()
		return

	#super(event)

var is_valid: bool = false

func _is_valid(input: String) -> bool:
	return len(input) > 0

@export var change_always_accepted: bool = true
func _can_change_to() -> String:
	return text

func _text_changed() -> void:
	pass

var prev_input: String = ""
func _input_changed(input: String):
	set_line(input, true)
	
var prev_pos: int = 0
func set_line(input: String, emit: bool = false):
	if text != input:
		text = input
		caret_column = prev_pos
	if !change_always_accepted:
		text = _can_change_to()
	is_valid = _is_valid(input)
	if !change_always_accepted:
		prev_input = input
	_text_changed()
	_resize_label()
	if emit:
		changed.emit(text)

@onready var _font = get_theme_font("font")

func _string_width_px(s: String, fs: int) -> float:
	# Godot 4: measure using Font.get_string_size
	# HORIZONTAL_ALIGNMENT_LEFT, width=-1 to avoid wrapping
	return _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs).x

@onready var base_font_size = get_theme_font_size("font_size")
@onready var k = base_font_size/float(get_theme_font_size("font"))
func _resize_label():
	var s = text
	var _base_fs = get_theme_font_size("font") * k
	var n = s.length()
	if n == 0 or resize_after <= 0 or n <= resize_after:
		add_theme_font_size_override("font_size", base_font_size)
		return
	var full_w = _string_width_px(s, _base_fs)
	if full_w <= 0.0:
		add_theme_font_size_override("font_size", base_font_size)
		return

	var keep_txt = s.substr(0, resize_after)
	var keep_w = _string_width_px(keep_txt, base_font_size)
	var scale = clamp(keep_w / full_w, 0, 1.0)
	var new_fs = int(round(_base_fs * scale))
	add_theme_font_size_override("font_size", new_fs)

func _input_submit(input: String):
	pass

signal changed
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_ENTER and ui.is_focus(self):
		if accept_button:
			accept_button.press(0.1)
		ui.click_screen(global_position + Vector2(10,10))

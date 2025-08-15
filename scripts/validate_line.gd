extends LineEdit
class_name ValidInput

@export var accept_button: BlockComponent

func _ready() -> void:
	text_changed.connect(_input_changed)
	text_submitted.connect(_input_submit)

func set_valid(valid: bool):
	is_valid = valid

func _process(delta: float) -> void:
	pass

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
	if !change_always_accepted:
		text = _can_change_to()
	is_valid = _is_valid(input)
	if !change_always_accepted:
		prev_input = input
	_text_changed()

func _input_submit(input: String):
	pass

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_ENTER and ui.is_focus(self):
		if accept_button:
			accept_button.press(0.1)
		ui.click_screen(global_position + Vector2(10,10))

extends LineEdit
class_name ValidInput

@export var accept_button: BlockComponent

func _ready() -> void:
	text_changed.connect(_input_changed)
	text_submitted.connect(_input_submit)

var prev_input: StringName

func set_valid(valid: bool):
	is_valid = valid

func _gui_input(event: InputEvent) -> void:
	# If the user just pressed Right-Click, eat the event
	if (event is InputEventMouseButton and
		event.button_index == 2 and
		event.pressed):
		get_viewport().set_input_as_handled()
		return

	# Otherwise let LineEdit do its normal thing
	#super(event)

var is_valid: bool = false

func _is_valid(input: String) -> bool:
	return len(input) > 0

func _input_changed(input: String):
	set_valid(_is_valid(input))

func _input_submit(input: String):
	pass

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_ENTER:
		accept_button.press(0.5)
		release_focus()

extends LineEdit
class_name InputString

func _ready() -> void:
	text_changed.connect(_input_changed)
	text_submitted.connect(_input_submit)

var prev_input: StringName
func _input_changed(input: String):
	pass

func _input_submit(input: String):
	pass

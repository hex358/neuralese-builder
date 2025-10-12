extends TextEdit

@export var max_length: int = 256

func _on_text_changed() -> void:
	if text.length() > max_length:
		text = text.substr(0, max_length)
		set_caret_column(max_length)

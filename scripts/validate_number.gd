extends ValidInput

var prev_pos: int = 0
func _can_change_to() -> String:
	prev_pos = caret_column
	if text.begins_with("0") and text.length() > 1: return text.trim_prefix("0")
	if text.is_valid_int(): return text
	if !text: return ""
	return prev_input

func _text_changed() -> void:
	caret_column = prev_pos+sign(len(text)-len(prev_input))
	

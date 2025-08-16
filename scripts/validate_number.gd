extends ValidInput

var prev_pos: int = 0
func _can_change_to() -> String:
	prev_pos = caret_column
	if text.begins_with("0") and text.length() > 1: return text.trim_prefix("0")
	if text.is_valid_int(): 
		#if int(text) > 127: return prev_input
		return text
	if !text: return ""
	var new = ""
	for i in text:
		if i.is_valid_int(): new += i
	return new

func _text_changed() -> void:
	caret_column = prev_pos+sign(len(text)-len(prev_input))
	

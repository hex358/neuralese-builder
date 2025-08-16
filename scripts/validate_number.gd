
extends ValidInput


var prev_pos: int = 0
var prev: int = 0
func _can_change_to() -> String:
	prev_pos = caret_column
	if text.begins_with("0") and text.length() > 1: 
		
		text = text.trim_prefix("0")
	if text.is_valid_int(): 
		prev = int(text);
		#if int(text) > 127: return prev_input
		return text
	if !text: prev = 0; return ""
	var new = ""
	var num: int = prev
	for i in text:
		if i.is_valid_int(): new += i
		if i == "+": 
			#print("gfj")
			new = str(num+1); break
		if i == "-" and num > 0: new = str(num-1) if num-1 else ""; break
	prev = int(new)
	return new

func _text_changed() -> void:
	caret_column = prev_pos+sign(len(text)-len(prev_input))
	

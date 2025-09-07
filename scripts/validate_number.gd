extends ValidInput
class_name ValidNumber

@export var min_value: int = 0
@export var max_value: int = 2**16

var prev: int = 0

func _can_change_to() -> String:
	var before = prev
	var o = inte()
	if int(text) < min_value and before > min_value and len(text) > 1:
		o = ""; prev = min_value
	return o

func _get_value():
	return prev

func _ready():
	super()
	text_submitted.connect(submit)
	focus_exited.connect(submit.bind(""))

func submit(new: String):
	if int(text) < min_value: 
		prev = min_value; text = ""

func inte():
	prev_pos = caret_column
	if text.begins_with("0") and text.length() > 1: 
		text = text.trim_prefix("0")
	if text.is_valid_int(): 
		prev = clamp(int(text), 0, max_value if max_value > 0 else int(text))
		return str(prev)
	if !text: 
		prev = 0
		return ""
	var new = ""
	var num: int = prev
	for i in text:
		if i.is_valid_int(): 
			new += i
		if i == "+": 
			new = str(num+1); break
		if i == "-" and num > 0: 
			new = str(num-1) if num-1 else ""; break
	if new != "":
		prev = clamp(int(new), 0, max_value if max_value > 0 else int(new))
		new = str(prev)
	else:
		prev = min_value
	return new

func _text_changed() -> void:
	caret_column = prev_pos+sign(len(text)-len(prev_input))

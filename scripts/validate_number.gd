extends ValidInput
class_name ValidNumber

@export var min_value: int = 0
@export var max_value: int = 2**16

var prev: int = min_value

@onready var bef = text
func _can_change_to(emit: bool) -> String:
	var before = prev; 
	var prev_text = text
	var o = inte()
	if int(text) < min_value and before > min_value and len(text) > 1:
		o = str(min_value); prev = min_value
	if min_value == 0 and o == str(min_value):
		o = ""
	#if prev == 0: prev = min_value
	if prev < min_value or prev > max_value:
		set_text_color(Color(1.0,0.5,0.5,1.0))
	else:
		reset_text_color()
	if emit:
		bef = o
	return o

func _get_value():
	return prev if prev else min_value

func is_valid_input() -> bool:
	return prev >= min_value and prev <= max_value

func _ready():
	super()
	text_submitted.connect(submit)
	focus_exited.connect(submit.bind(""))

signal submitted(new_text: String)
func submit(new: String):
	if int(text) < min_value: 
		prev = min_value
		if text:
			text = str(min_value)
	if int(text) > max_value: 
		prev = max_value; text = str(max_value)
	submitted.emit(text)
	_resize_label()
	reset_text_color()

func inte():
	prev_pos = caret_column
	if text.begins_with("0") and text.length() > 1: 
		text = text.trim_prefix("0")
	if text.is_valid_int(): 
		prev = clamp(int(text), 0, int(text))
		return str(prev)
	if !text: 
		prev = 0
		return ""
	var new = ""
	var num: int = clamp(prev, min_value-1, max_value+1)
	for i in text:
		if i.is_valid_int(): 
			new += i
		if i == "+" and num < max_value: 
			new = str(num+1); break
		if i == "-" and num > min_value: 
			new = str(num-1) if num-1 else ""; break
	if int(new) < min_value: new = str(min_value)
	if int(new) > max_value: new = str(max_value)
	if new != "":
		prev = clamp(int(new), 0, int(new))
		new = str(prev)
	else:
		prev = min_value
	return new

func _text_changed() -> void:
	caret_column = prev_pos+sign(len(text)-len(prev_input))

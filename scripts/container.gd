extends Control
class_name BubbleUnit

enum UnitType {Radio, Text, Checkbox, Next}

@export var unit_type = UnitType.Text
@export var abstract: bool = false

var passed_data = {}

signal toggled(a: bool)

func _ready() -> void:
	if not passed_data: return
	match unit_type:
		UnitType.Radio:
			$text.text = passed_data.text
			$CheckBox.toggled.connect(func(a): toggled.emit(a))
		UnitType.Text:
			$text.text = passed_data.text
		UnitType.Next:
			$next.released.connect(func(): toggled.emit(true))
		UnitType.Checkbox:
			$text.text = passed_data.text
			$CheckBox.toggled.connect(func(a): toggled.emit(a))
	for child in get_children():
		indexed.append(child)
		if not child is BlockComponent:
			child.material = get_parent().material
		else:
			indexed.append(child.label)
			child.label.material = get_parent().material
	size.y += 1
	count_size()
var indexed = []

func count_size() -> float:
	var max_y := size.y-1
	for c in get_children():
		if not c is Control:
			continue
		var bottom = c.position.y + c.size.y
		max_y = max(max_y, bottom)
	size.y = max_y

	
	return max_y

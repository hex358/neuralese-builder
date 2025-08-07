extends Graph
class_name DynamicGraph

@export var unit: Control
@export var add_button: BlockComponent
@export var input: Control
@export var padding: float = 0.0

@onready var _unit = unit.duplicate()

var connection_paths = []
func _enter_tree():
	for i in unit.get_children():
		if i is Connection:
			connection_paths.append(NodePath(i.name))

var total_size: float = 0.0
var hint_counter: int = 5
var unit_script = null
func _after_ready():
	#total_size += input.size.y
	unit.queue_free()
	unit_script = unit.get_script()

func _can_drag() -> bool:
	return not ui.is_focus($input/LineEdit) and not add_button.state.hovering

var units = []
var appear_units = []
func _get_unit(kw: Dictionary) -> Control:
	var dup = _unit.duplicate()
	dup.get_node("Label").text = kw["text"]
	dup.show()
	dup.modulate.a = 0.0
	appear_units.append(dup)
	return dup

var target_y: float = 0.0
func add_unit(kw: Dictionary = {}):
	var new_unit = _get_unit(kw)
	new_unit.set_script(unit_script)
	units.append(new_unit)
	new_unit.position.y = total_size + padding - input.size.y
	total_size += new_unit.size.y + padding
	target_y = total_size
	#input.position.y = total_size
	$ColorRect.size.y += new_unit.size.y + padding
	for path in connection_paths:
		var conn = new_unit.get_node(path)
		hint_counter += 1
		conn.hint = hint_counter
		conn.parent_graph = self
		#add_connection(conn)
	add_child(new_unit)

func _after_process(delta: float):
	var to_del = []
	for i in appear_units:
		i.modulate.a = lerpf(i.modulate.a, 1.0, 5.0*delta)
		if i.modulate.a > 0.9:
			i.modulate.a = 1.0
			to_del.append(i)
	for i in len(to_del):
		appear_units.remove_at(i)
	input.position.y = lerpf(input.position.y, target_y, delta*10.0)


func _on_color_rect_2_pressed() -> void:
	if $input/LineEdit.is_valid:
		add_unit({"text": $input/LineEdit.text})
		$input/LineEdit.clear()

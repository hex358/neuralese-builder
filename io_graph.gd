extends Graph
class_name DynamicGraph

@export var unit: Control
@export var add_button: BlockComponent
@export var input: Control
@export var padding: float = 0.0

@onready var _unit = unit.duplicate(DUPLICATE_USE_INSTANTIATION)

var connection_paths = []
func _enter_tree():
	for i in unit.get_children():
		if i is Connection:
			connection_paths.append(NodePath(i.name))

var total_size: float = 0.0
var hint_counter: int = 5
func _after_ready():
	#total_size += input.size.y
	unit.queue_free()

func _get_unit(kw: Dictionary) -> Control:
	var dup = _unit.duplicate()
	dup.get_node("Label").text = kw["text"]
	dup.show()
	return dup

func add_unit(kw: Dictionary = {}):
	var new_unit = _get_unit(kw)
	new_unit.position.y = total_size + padding - input.size.y
	total_size += new_unit.size.y + padding
	input.position.y = total_size
	$ColorRect.size.y += new_unit.size.y + padding
	for path in connection_paths:
		var conn = new_unit.get_node(path)
		hint_counter += 1
		conn.hint = hint_counter
		conn.parent_graph = self
		#add_connection(conn)
	add_child(new_unit)

func _after_process(delta: float):
	pass


func _on_color_rect_2_pressed() -> void:
	add_unit({"text": $input/LineEdit.text})

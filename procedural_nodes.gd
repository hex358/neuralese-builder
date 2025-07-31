extends Node
class_name ProceduralNodes

@export var instance: Node = null

func _get_nodes(args: Array = []) -> Array[Node]:
	var output: Array[Node] = []
	return output

var prev_unrolled = []
@onready var parent = get_parent()
func unroll(args: Array = []):
	if instance.is_inside_tree():
		parent.remove_child(instance)
	if self.is_inside_tree():
		parent.remove_child(self)
	for i in prev_unrolled:
		i.queue_free()
	prev_unrolled = _get_nodes(args)
	for i in prev_unrolled:
		parent.add_child(i)
	parent.arrange()

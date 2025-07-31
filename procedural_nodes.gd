extends Node
class_name ProceduralNodes

@export var instance: Node = null

func _get_nodes(args: Array = []) -> Array[Node]:
	var output: Array[Node] = []
	return output

@onready var parent = get_parent()
func unroll(args: Array):
	unroll_deferred.call_deferred(args)

func unroll_deferred(args):
	if instance.is_inside_tree():
		parent.remove_child(instance)
	if self.is_inside_tree():
		parent.remove_child(self)
	for child in parent.get_children():
		child.free()
	for i in _get_nodes(args):
		parent.add_child(i)

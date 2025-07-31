extends Node
class_name ProceduralNodes

@export var instance: Node = null

func _get_nodes(args) -> Array[Node]:
	var output: Array[Node] = []
	return output

@onready var frozen_duplicate = instance.duplicate(DuplicateFlags.DUPLICATE_USE_INSTANTIATION)
func initialize():
	if not parent.is_node_ready():
		await parent.ready
	parent.remove_child(instance)

var prev_unrolled = []
@onready var parent = get_parent()
func unroll(args = []):
	_unroll_deferred.call_deferred(args)

func _unroll_deferred(args = []):
	for i in prev_unrolled:
		i.free()
	prev_unrolled = _get_nodes(args)
	for i in prev_unrolled:
		#var new = frozen_duplicate.duplicate()
		i.hide()
		parent.add_child(i)
		#print(new)
	parent.arrange()
	

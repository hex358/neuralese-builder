extends Node
class_name ProceduralNodes

@export var instance: Node = null

func _get_nodes(args, kwargs = {}) -> Array[Node]:
	var output: Array[Node] = []
	return output

@onready var frozen_duplicate = instance.duplicate(DuplicateFlags.DUPLICATE_USE_INSTANTIATION)
func initialize():
	if not parent.is_node_ready():
		await parent.ready
	parent.remove_child(instance)

var prev_unrolled = []
@onready var parent: BlockComponent = get_parent()
func unroll(args = [], kwargs = {}):
	_unroll_deferred.call_deferred(args, kwargs)

func _unroll_deferred(args = [], kwargs = {}):
	for i in prev_unrolled:
		
		#print(i)
		i.free()
	prev_unrolled = _get_nodes(args, kwargs)
	parent._contained.clear()
	for i in prev_unrolled:
		#var new = frozen_duplicate.duplicate()
		#print(i)
		i.placeholder = false
		i.hide()
		parent.vbox.add_child(i)
		i.parent = parent
		#print(new)
	parent.arrange()
	
	

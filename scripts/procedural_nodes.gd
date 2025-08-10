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
	#print(instance.get_parent())

var prev_unrolled = []
@onready var parent: BlockComponent = get_parent()
func unroll(args = [], kwargs = {}):
	_unroll_deferred.call_deferred(args, kwargs)

func _unroll_deferred(args = [], kwargs = {}):
	for i in prev_unrolled:
		
		#print(i)
		var wrapper = i._wrapped_in
		parent.dynamic_child_exit(i)
		i.free()
		wrapper.free()
	prev_unrolled = _get_nodes(args, kwargs)
	parent._contained.clear()
	for child in prev_unrolled:
		#var new = frozen_duplicate.duplicate()
		#print(i)

		child.placeholder = false
		child.auto_wrap = false
		child.hide()
		
		
		parent.add_child(child)
		#child.parent = parent
		parent.dynamic_child_enter(child)
		child._create_scaler_wrapper()
		#child.reparent(child.scaler)
		#(func(): parent.dynamic_child_enter(child._wrapped_in)).call_deferred()
		
		child.parent = parent
		
		
		#print(new)
	parent.arrange()
	
	

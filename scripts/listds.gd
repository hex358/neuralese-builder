extends ProceduralNodes

func _ready():
	initialize()
	glob.ref(self, "datasets")

func _get_nodes(args, kwargs = {}) -> Array[Node]:
	var output: Array[Node] = []
	var i: int = 0
	for _i in args:
		i += 1
		var new: BlockComponent = frozen_duplicate.duplicate()
		new.placeholder = false
		new.metadata["ds_data"] = args[_i]
		new.text = _i
		#if not new.text: 
		#	(func():
		#		new.text = "Untitled"; new.label.self_modulate = Color(0.6,0.6,0.6,1)).call_deferred()
		new.hint = str(_i)
		#new.metadata["project_id"] = int(_i)
		output.append(new)
	
	return output

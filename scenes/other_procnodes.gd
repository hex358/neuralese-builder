extends ProceduralNodes

func _ready():
	initialize()
	glob.ref(self, "list_unroll")

func _get_nodes(args, kwargs = {}) -> Array[Node]:
	var output: Array[Node] = []
	var i: int = 0
	for _i in args:
		i += 1
		var new: BlockComponent = frozen_duplicate.duplicate()
		new.placeholder = false
		new.text = "Scene_test_%s"%i
		new.hint = "Scene_test_%s"%i
		output.append(new)
	
	return output

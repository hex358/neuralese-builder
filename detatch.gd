extends ProceduralNodes

func _ready():
	initialize()
	glob.ref(self, "detatch_unroll")

func _get_nodes(args, kwargs = {}) -> Array[Node]:
	var output: Array[Node] = []
	var lines = []
	var i: int = 0
	for _i in args:
		i += 1
		for j in 5:
			var new: BlockComponent = frozen_duplicate.duplicate()
			new.placeholder = false
			new.text = "Spline %s"%i
			var line = _i if _i is Spline else args[_i]
			new.metadata["inst"] = line
			new.metadata["all"] = false
			lines.append(line)
			output.append(new)
	if len(args) >= 3:
		var new: BlockComponent = frozen_duplicate.duplicate()
		new.placeholder = false
		new.text = "All"
		new.metadata["all"] = true
		new.metadata["inst"] = lines
		output.insert(0, new)
	
	return output

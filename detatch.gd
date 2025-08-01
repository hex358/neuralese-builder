extends ProceduralNodes

func _ready():
	initialize()
	glob.ref(self, "detatch_unroll")

func _get_nodes(args, kwargs = {}) -> Array[Node]:
	var output: Array[Node] = []
	var i: int = -1
	for _i in args:
		i += 1
		var new: BlockComponent = frozen_duplicate.duplicate()
		new.text = "Connection #%s"%i
		var line = _i if _i is Spline else args[_i][0]
		new.metadata["id"] = line.get_instance_id()
		new.metadata["node"] = kwargs["node"]
		output.append(new)
	return output

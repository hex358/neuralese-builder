extends ProceduralNodes

func _ready():
	glob.ref(self, "detatch_unroll")

func _get_nodes(args: Array = []) -> Array[Node]:
	var out: Array[Node] = []
	for i in 5:
		var dup: BlockComponent = instance.duplicate()
		dup.show()
		out.append(dup)
	return out

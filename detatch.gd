extends ProceduralNodes

func _ready():
	glob.ref(self, "detatch_unroll")

func _get_nodes(args: Array = []) -> Array[Node]:
	return []

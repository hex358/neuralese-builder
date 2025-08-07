extends Node

var propagation_q = {}
func next_frame_propagate(tied_to: Connection, key: int, value: Variant):
	propagation_q.get_or_add(tied_to, {}).get_or_add(key, []).append(value)

var gather_q = {}
var gather_tree = {}
func next_frame_gather(tied_to: Connection, key: int):
	pass
	#print(propagation_q)

func gather_cycle():
	pass
	
	#tree

func propagate_cycle():
	if not propagation_q: return
	var dup = propagation_q
	propagation_q = {}
	#tree = {}
	for conn: Connection in dup:
		conn.parent_graph.propagate(dup[conn])

func _process(delta: float) -> void:
	propagate_cycle()
	gather_cycle()

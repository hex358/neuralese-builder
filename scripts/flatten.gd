extends Graph

var display_count: int = 0
func _just_attached(other_conn: Connection, my_conn: Connection):
	match other_conn.parent_graph.server_typename:
		"Flatten":
			set_count(other_conn.parent_graph.display_count)
		"InputNode":
			set_count(28*28)
		"NeuronLayer":
			if other_conn.parent_graph.layer_name == "Dense":
				set_count(other_conn.parent_graph.cfg.neuron_count)
	count_reach = display_count
	graphs.reach(self, call_count)

func _just_connected(who: Connection, to: Connection):
	if to.parent_graph.server_typename == "NeuronLayer":
		to.parent_graph.neurons_fixed = true
		to.parent_graph.push_neuron_count(neuron_count)

func _just_disconnected(who: Connection, from: Connection):
	if from.parent_graph.server_typename == "NeuronLayer":
		from.parent_graph.neurons_fixed = false

var neuron_count: int = 0
func set_count(count: int):
	display_count = count; neuron_count = count
	$display_count.text = str(count)

var block_types: Dictionary[StringName, bool] = {"NeuronLayer": 1, "Reshape2D": 1}
var count_reach: int = 0
func call_count(from: Connection, to: Connection, branch_cache: Dictionary):
	var chain = branch_cache.get_or_add("chain", [])
	if  (chain and chain[-1].server_typename in block_types): return
	chain.append(from.parent_graph)
	
	if to.parent_graph.server_typename == "Flatten":
		to.parent_graph.set_count(count_reach)

func _just_deattached(other_conn: Connection, my_conn: Connection):
	set_count(0)
	graphs.update_dependencies(self)
	count_reach = 0
	graphs.reach(self, call_count)

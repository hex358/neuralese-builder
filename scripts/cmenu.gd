@tool
extends BlockComponent

func _menu_handle_release(button: BlockComponent):
	#freeze_input()
	var type = null
	match button.hint:
		"layer":
			type = graphs.graph_types.layer
		"act":
			type = graphs.graph_types.neuron
		"input":
			type = graphs.graph_types.input
		"train_input":
			type = graphs.graph_types.train_input
		"softmax":
			type = graphs.graph_types.softmax

	var graph = graphs.get_graph(type, Graph.Flags.NEW)
	var world_pos = graphs.get_global_mouse_position()
	graph.global_position = world_pos
	#await glob.wait(0.1)
	menu_hide()
	#unfreeze_input()

func _sub_process(delta):
	pass
	#print(pos_clamp(get_global_mouse_position()))
	#print(DisplayServer.window_get_size())
	
	#print(global_position.y)
	#print(expanded_size)

var menu = null

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
		"reshape2d":
			type = graphs.graph_types.reshape2d
		"flatten":
			type = graphs.graph_types.flatten
		"conv2d":
			type = graphs.graph_types.conv2d
		"maxpool":
			type = graphs.graph_types.maxpool
		"classifier":
			type = graphs.graph_types.classifier
		"train_begin":
			type = graphs.graph_types.train_begin
		"augmenter":
			type = graphs.graph_types.augmenter
		"run_model":
			type = graphs.graph_types.run_model
		"model_name":
			type = graphs.graph_types.model_name
		"dataset":
			type = graphs.graph_types.dataset

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

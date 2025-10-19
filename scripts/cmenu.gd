@tool
extends BlockComponent

func _menu_handle_release(button: BlockComponent):
	#freeze_input()
	var type = null
	match button.hint:
		"layer":
			type = "layer"
		"act":
			type = "neuron"
		"input":
			type = "input"
		"train_input":
			type = "train_input"
		"softmax":
			type = "softmax"
		"reshape2d":
			type = "reshape2d"
		"flatten":
			type = "flatten"
		"conv2d":
			type = "conv2d"
		"maxpool":
			type = "maxpool"
		"classifier":
			type = "classifier"
		"train_begin":
			type = "train_begin"
		"augmenter":
			type = "augmenter"
		"run_model":
			type = "run_model"
		"model_name":
			type = "model_name"
		"dataset":
			type = "dataset"
		"augment_tf":
			type = "augment_tf"
		"output_map":
			type = "output_map"
		"augment_tune":
			type = "augment_tune"
		"augment_clean":
			type = "augment_clean"
		"augment_fit":
			type = "augment_fit"

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

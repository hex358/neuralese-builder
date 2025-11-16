@tool
extends BlockComponent


func _menu_handle_release(button: BlockComponent):
	#freeze_input()
	#glob.menus["subctx"].pos = Vector2(position.x - glob.menus["subctx"].base_size.x * 0.75, get_global_mouse_position().y)
	#glob.menus["subctx"].show_up(["hi", "hello"], null)
	
	
	#return
	var type = null
	match button.hint:
		"layer":
			type = "layer"
		"act":
			type = "neuron"
		"input1d":
			type = "input_1d"
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
		"lua_env":
			type = "lua_env"
		"train_rl":
			type = "train_rl"
		"dropout":
			type = "dropout"
		"concat":
			type = "concat"

	var graph = graphs.get_graph(type, Graph.Flags.NEW)
	var world_pos = graphs.get_global_mouse_position()
	graph.global_position = world_pos - graph.rect.position - graph.rect.size / 2
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

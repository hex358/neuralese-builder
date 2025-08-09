@tool
extends BlockComponent

func _menu_handle_release(button: BlockComponent):
	#freeze_input()
	var type = null
	match button.hint:
		"neuron":
			type = glob.graph_types.neuron
		_:
			type = glob.graph_types.io
	var graph = glob.get_graph(type, Graph.Flags.NEW)
	var cam = get_viewport().get_camera_2d()
	var world_pos = cam.get_canvas_transform().affine_inverse() * position
	graph.position = world_pos
	get_parent().get_parent().add_child(graph)
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

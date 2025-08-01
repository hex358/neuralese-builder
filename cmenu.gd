@tool
extends BlockComponent

func _menu_handle_press(button: BlockComponent):
	freeze_input()
	var graph = glob.get_graph(Graph.Flags.NEW)
	var cam = get_viewport().get_camera_2d()
	var world_pos = cam.get_canvas_transform().affine_inverse() * position
	graph.position = world_pos
	get_parent().get_parent().add_child(graph)
	await glob.wait(0.1)
	menu_hide()
	unfreeze_input()

func _menu_handle_release(button: BlockComponent):
	pass

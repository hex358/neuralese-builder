@tool
extends BlockComponent

func _menu_handle_press(button: BlockComponent):
	pass

func _menu_handle_release(button: BlockComponent):
	menu_hide()
	var graph = glob.get_graph()
	var cam = get_viewport().get_camera_2d()
	var world_pos = cam.get_canvas_transform().affine_inverse() * position
	graph.position = world_pos - graph.rect_offset
	get_parent().get_parent().add_child(graph)

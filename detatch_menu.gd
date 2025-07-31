@tool

extends BlockComponent

func show_up(iter, node):
	#if visible: return=
	#menu_hide()
	#if is_instance_valid(timer):
	#	await timer.timeout
	glob.getref("detatch_unroll").unroll(iter)
	if not mouse_open:
		menu_show(get_global_mouse_position())
	state.holding = false
	
	
	#menu_expand()
func _menu_handle_hovering(button: BlockComponent):
	instance_from_id(button.metadata["id"]).modulate = Color.RED

func _menu_handle_release(button: BlockComponent):
	menu_hide()
	

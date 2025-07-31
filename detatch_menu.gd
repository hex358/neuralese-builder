@tool

extends BlockComponent

func show_up():
	if visible: return
	menu_show(get_global_mouse_position())
	#menu_expand()

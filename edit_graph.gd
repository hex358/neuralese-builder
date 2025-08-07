@tool
extends BlockComponent

func show_up(input: String):
	text = input if len(input) <= 10 else input.substr(0, 10) + ".."
	menu_show(pos_clamp(get_global_mouse_position()))

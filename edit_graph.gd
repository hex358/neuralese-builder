@tool
extends BlockComponent

var menu_call: Callable
func show_up(input: String, call: Callable):
	text = input if len(input) <= 10 else input.substr(0, 10) + ".."
	menu_call = call
	menu_show(pos_clamp(get_global_mouse_position()))

func _menu_handle_release(button: BlockComponent):
	menu_call.call()
	menu_hide()

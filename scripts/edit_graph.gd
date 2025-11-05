@tool
extends BlockComponent

var menu_call: Callable
var menu_call_alt: Callable
func show_up(input: String, call: Callable):
	text = input if len(input) <= 9 else input.substr(0, 9) + ".."
	menu_call = call
	menu_show(pos_clamp(get_global_mouse_position()))
	state.holding = false

func _process(delta: float) -> void:
	super(delta)

func _menu_handle_release(button: BlockComponent):
	if button.hint == "copy":
		menu_call_alt.call()
		menu_hide()
	else:
		menu_call.call()
		menu_hide()

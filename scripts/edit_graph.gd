@tool
extends BlockComponent

@export var implement: bool = true

var menu_call: Callable
var menu_call_alt: Callable
func show_up(input: String, call: Callable):
	text = input if len(input) <= 9 else input.substr(0, 9) + ".."
	menu_call = call
	menu_show(pos_clamp(get_global_mouse_position()))
	state.holding = false

func set_txt(txt: String):
	match glob.get_lang():
		"en":
			txt = "Row " + txt
		"ru":
			txt = "Строка " + txt
		"kz":
			txt = "Сызық " + txt
	#print(max(10 - len(text), 0))
	text = txt + " ".repeat(max(10 - len(txt), 0)) + " *"

func _process(delta: float) -> void:
	super(delta)

func _menu_handle_release(button: BlockComponent):
	if implement:
		if button.hint == "copy":
			menu_call_alt.call()
			menu_hide()
		else:
			menu_call.call()
			menu_hide()

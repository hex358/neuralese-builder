extends ColorRect
class_name SubMenu

@export var top: TopBar = null

var attachement_x: int = 0
var state: int = 0 #1 - expand, 2 - hide
func _process(delta: float) -> void:
	if visible:
		size.y = glob.window_size.y - position.y
		match state:
			1:
				position.x = lerpf(position.x, attachement_x, delta * 10.0)
			2:
				position.x = lerpf(position.x, glob.window_size.x, delta * 10.0)
				if abs(position.x-glob.window_size.x)<2:
					hide()

signal fully_closed
var expanded: bool = false
var expand_request: bool = false

func expand():
	if expand_request or expanded: return
	expand_request = true
	state = 0
	if ui.expanded_menu:
		ui.expanded_menu.close()
		await ui.expanded_menu.fully_closed
	expanded = true
	expand_request = false
	show()
	state = 1

func close():
	expanded = false
	expand_request = false
	state = 2

extends Control

func is_focus(control: Control):
	return get_viewport().gui_get_focus_owner() == control

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index in [1,2, 3] and event.pressed:
		var focused = get_viewport().gui_get_focus_owner()
		if focused and focused is LineEdit:
			var rect = focused.get_global_rect()
			if not rect.has_point(event.position):
				focused.release_focus()

var expanded_menu: SubMenu = null
var _buttons = []
#var _parent_graphs = {}
func reg_button(b: BlockComponent):
	pass
	#_parent_graphs[b] = [b.graph, b.graph.z_index if b.graph else 0]

func unreg_button(b: BlockComponent):
	pass

func _process(delta: float):
	pass
			

func click_screen(pos: Vector2, button = MOUSE_BUTTON_LEFT, double_click = false) -> void:
	var vp = get_viewport()

	var down = InputEventMouseButton.new()
	down.button_index = button
	down.pressed = true
	down.double_click = double_click
	down.position = pos
	down.global_position = pos
	vp.push_input(down)

	var up = InputEventMouseButton.new()
	up.button_index = button
	up.pressed = false
	up.double_click = false
	up.position = pos
	up.global_position = pos
	vp.push_input(up)

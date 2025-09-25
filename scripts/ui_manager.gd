extends Control

func is_focus(control: Control):
	return control and get_viewport().gui_get_focus_owner() == control
	
func get_focus():
	return get_viewport().gui_get_focus_owner()

var mouse_buttons: Dictionary = {1: true, 2: true, 3: true}
var wheel_buttons: Dictionary = {
	MOUSE_BUTTON_WHEEL_UP: true,
	MOUSE_BUTTON_WHEEL_DOWN: true,
	MOUSE_BUTTON_WHEEL_LEFT: true,
	MOUSE_BUTTON_WHEEL_RIGHT: true,
}

func line_block(line: LineEdit):
	line.editable = false
	line.selecting_enabled = false
	line.release_focus()
	line.mouse_filter = MOUSE_FILTER_IGNORE

func line_unblock(line: LineEdit):
	line.editable = true
	line.selecting_enabled = true
	line.mouse_filter = MOUSE_FILTER_STOP

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index in wheel_buttons:
		var hovered = get_viewport().gui_get_hovered_control()
		if hovered and hovered is Slider:
			accept_event()
			return

	if event is InputEventMouse:
		var focused = get_viewport().gui_get_focus_owner()
		#var occ = glob.is_occupied(focused, "menu_inside")
		#print(occ)
		if event is InputEventMouseButton and event.pressed:
			#print(glob.is_occupied(focused, "menu_inside"))
			if event.button_index in mouse_buttons:
				if focused and (focused is LineEdit or focused is Slider):
					var rect = focused.get_global_rect()
					if not rect.has_point(get_global_mouse_position()) and not event.has_meta("_emulated"):
						focused.release_focus()
						#if focused is ValidInput:
						focused.focus_exited.emit()
		elif not glob.mouse_pressed:
			if focused is Slider and not event.has_meta("_emulated"):
				#print("fj")
				focused.release_focus()
				focused.focus_exited.emit()

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
#	print(get_viewport().gui_get_focus_owner())
			

var selecting_box: bool = false
func click_screen(pos: Vector2, button = MOUSE_BUTTON_LEFT, double_click = false) -> void:
	var vp = get_viewport()

	var down = InputEventMouseButton.new()
	down.button_index = button
	down.pressed = true
	down.double_click = double_click
	down.position = pos
	down.global_position = pos
	down.set_meta("_emulated", true)
	vp.push_input(down)

	var up = InputEventMouseButton.new()
	up.button_index = button
	up.pressed = false
	up.double_click = false
	up.position = pos
	up.global_position = pos
	up.set_meta("_emulated", true)
	vp.push_input(up)

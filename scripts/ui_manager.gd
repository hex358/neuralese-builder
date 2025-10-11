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

func move_mouse(pos: Vector2) -> void:
	var vp = get_viewport()
	var motion = InputEventMouseMotion.new()
	motion.global_position = pos
	motion.position = pos
	motion.relative = Vector2.ZERO
	motion.set_meta("_emulated", true)

	vp.push_input(motion)


#var _parent_graphs = {}
func reg_button(b: BlockComponent):
	pass
	#_parent_graphs[b] = [b.graph, b.graph.z_index if b.graph else 0]

func unreg_button(b: BlockComponent):
	pass

func _process(delta: float):
	pass
#	print(get_viewport().gui_get_focus_owner())
			

var blur = preload("res://scenes/blur.tscn").instantiate()
var splash_menus = {
	"login": preload("res://scenes/splash.tscn"),
	"signup": preload("res://scenes/signup.tscn"),
	"scene_create": preload("res://scenes/scene_create.tscn"),
	"works": preload("res://scenes/works.tscn"),
	"project_create": preload("res://scenes/project_create.tscn"),
}


var cl = CanvasLayer.new()
func _ready():
	cl.layer = 128
	add_child(cl)
	blur.modulate.a = 0
	cl.add_child(blur)

var splashed = {}

func add_splashed(who: SplashMenu):
	splashed[who] = true

func rem_splashed(who: SplashMenu):
	splashed.erase(who)

func is_splashed(who: String) -> bool:
	for i in splashed:
		if i.typename == who: return true
	return false

func get_splash(who: String) -> SplashMenu:
	for i in splashed:
		if i.typename == who: return i
	return null

func splash(menu: String, splashed_from = null, emitter_ = null, inner = false) -> SplashMenu:
	if splashed_from:
		if !is_splashed(menu):
			splashed_from.in_splash = true
		else:
			splashed_from.in_splash = false
			get_splash(menu).go_away()
			return null
	var m: SplashMenu = splash_menus[menu].instantiate()
	m.inner = inner
	cl.add_child(m)
	m.splashed_from = splashed_from
	var emitter = ResultEmitter.new() if !emitter_ else emitter_
	m.emitter = emitter
	return m

func error(text: String):
	print(text)

class ResultEmitter:
	signal res(data: Dictionary, who: String)

signal result_emit(data: Dictionary)
func splash_and_get_result(menu: String, splashed_from = null, emitter_ = null, inner = false) -> Dictionary:
	if splashed_from:
		if !is_splashed(menu):
			splashed_from.in_splash = true
		else:
			splashed_from.in_splash = false
			get_splash(menu).go_away()
			return {}
	var m: SplashMenu = splash_menus[menu].instantiate()
	m.inner = inner
	cl.add_child(m)
	m.splashed_from = splashed_from
	var emitter = ResultEmitter.new() if !emitter_ else emitter_
	m.emitter = emitter
	var a = await emitter.res
	return a



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

extends Control
class_name SplashMenu

var splashed: bool = false
var indexed = []
@export var typename: String = "login"
@export var accept: BlockComponent = null
@export var first_line: Control = null
@export var persistent: bool = false
@export var show_on_ready: bool = true

var t: float = 0.0
var target_mod: float = 0.0
var from_scale: Vector2
var to_scale: Vector2

func _ready() -> void:
	if show_on_ready:
		readys()

func readys():
	RenderingServer.global_shader_parameter_set("_view_scale", 1.0)
	if first_line:
		first_line.grab_focus()
		first_line.grab_click_focus()
	if inner:
		ui.blur.self_modulate.a = 1.0
	else:
		ui.blur.self_modulate.a = 0.0
	show()
	
	$ColorRect.scale = Vector2.ZERO
	tick()
	#indexed = glob.rget_children(self)
	#await get_tree().process_frame
	splash()

var emitter: ui.ResultEmitter = null
signal quitting

func quit(data: Dictionary = {}):
	quitting.emit()
	if can_go:
		hide()
		ui.blur.self_modulate.a = 0
		emitter.res.emit(data)
		queue_free()

var res: Callable
func resultate(data: Dictionary):
	_resultate(data)

var passed_data: Dictionary = {}

var splashed_from: BlockComponent
var can_go: bool = true
func _resultate(data: Dictionary):
	if "go_signup" in data:
		can_go = false
		go_away()
		await quitting
		queue_free()
		ui.splash_and_get_result("signup", splashed_from, emitter, true)
	else:
		ui.hourglass_on()
		var answer = await glob.login_req(data["user"], data["pass"])
		if answer.ok:
			var parsed = JSON.parse_string(answer.body.get_string_from_utf8())
			if parsed.answer == "ok":
				var prev = glob.logged_in()
				glob.set_logged_in(data["user"], data["pass"])
				emitter.res.emit(data)
				go_away()

			else:
				ui.error("Username or password is wrong. :(")
		else:
			ui.error("Either your internet or the server itself is down. Sorry!")
		
		ui.hourglass_off()

func tick():
	$ColorRect.position = glob.window_size / 2.0 - ($ColorRect.size * $ColorRect.scale) / 2.0
	ui.blur.size = glob.window_size + Vector2(50, 50)

func _quit_request():
	pass

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		ui.splashed_in.erase(self)

var inner: bool = false
func _process(delta: float) -> void:
	
	var has = $ColorRect.get_global_rect().has_point(get_global_mouse_position())
	if has and visible:
		ui.splashed_in[self] = true
	else:
		ui.splashed_in.erase(self)
	if Input.is_action_just_pressed("ui_esc"):
		go_away()
		_quit_request()
	if Input.is_action_just_pressed("ui_enter"):
		if accept:
			accept.press(0.02)
	elif splashed and glob.mouse_just_pressed and \
	!has and\
	!glob.is_occupied(self, "block_button_inside"):
		go_away()
		_quit_request()
	#print(glob.get_occupied("block_button_inside"))

	# Update visibility and alpha
	if $ColorRect.modulate.a <= 0.05 and not splashed:
		if visible:
			quit({})
	else:
		show()
		var k = 1.0 if ui.blur.self_modulate.a < target_mod else 2
		$ColorRect.modulate.a = lerp($ColorRect.modulate.a, target_mod, delta * 20.0*k)
		if can_go:
			if not inner or !splashed:
				ui.blur.self_modulate.a = lerp(ui.blur.self_modulate.a, target_mod, delta * 20.0)
			else:
				ui.blur.self_modulate.a = 1.0
		else:
			ui.blur.self_modulate.a = 1.0

		# Scale animation via spring
		t += delta * 2.0  if splashed else delta * 6.0# time factor for spring curve
		if t < 0.5:
			var spring_scale: Vector2 = (glob.spring(from_scale, to_scale, clamp(t, 0.0, 1.0), 2, 5.0, 1.0) 
			if splashed else lerp(from_scale, to_scale, t))
			$ColorRect.scale = lerp(spring_scale, Vector2.ONE, 0.8)
		elif not ticked and splashed:
			#$ColorRect.scale = to_scale
			ticked = true
			stable.emit()
		elif ticked:
			var spring_scale: Vector2 = (glob.spring(from_scale, to_scale, clamp(t, 0.0, 1.0), 2, 5.0, 1.0) 
			if splashed else lerp(from_scale, to_scale, t))
			$ColorRect.scale = lerp(spring_scale, Vector2.ONE, 0.8)
	tick()
var ticked: bool = false
signal stable

func _just_splash():
	ui.blur.set_tuning(ui.blur.base_tuning)

func _just_go_away():
	pass

func _splash():
	pass

@onready var base_size = $ColorRect.size

func splash() -> void:
	ticked = false
	_splash()
	accept_event()
	from_scale = $ColorRect.scale
	to_scale = Vector2.ONE
	t = 0.0
	target_mod = 1.0
	splashed = true
	show()
	ui.add_splashed(self)
	
	if glob.cam is GraphViewport:
		glob.cam.stop()
	glob.tree_windows["env"].get_node("Control").process_mode = Node.PROCESS_MODE_DISABLED
	_just_splash()

func go_away() -> void:
	from_scale = $ColorRect.scale
	to_scale = Vector2.ZERO
	t = 0.0
	target_mod = 0.0
	splashed = false
	ui.rem_splashed(self)


	if glob.cam is GraphViewport:
		glob.cam.resume()
	glob.tree_windows["env"].get_node("Control").process_mode = Node.PROCESS_MODE_ALWAYS

	_just_go_away()

func _on_train_2_released() -> void:
	resultate({"go_signup": true})


func _on_train_released() -> void:
	$ColorRect/Label2.update_valid()
	$ColorRect/Label.update_valid()
	if $ColorRect/Label2.is_valid and $ColorRect/Label.is_valid:
		resultate({"user": $ColorRect/Label.text, "pass": $ColorRect/Label2.text})

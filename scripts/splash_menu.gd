extends Control
class_name SplashMenu

var splashed: bool = false
var indexed = []
@export var typename: String = "login"

var t: float = 0.0
var target_mod: float = 0.0
var from_scale: Vector2
var to_scale: Vector2

func _ready() -> void:
	$bg.modulate.a = 0.0
	$ColorRect.scale = Vector2.ZERO
	indexed = glob.rget_children(self)
	await get_tree().process_frame
	splash()

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_esc"):
		go_away()
	elif glob.mouse_just_pressed and \
	!$ColorRect.get_global_rect().has_point(get_global_mouse_position()) and\
	!glob.is_occupied(self, "block_button_inside"):
		go_away()


	# Update visibility and alpha
	if $ColorRect.modulate.a <= 0.01 and not splashed:
		hide()
		queue_free()
	else:
		show()
		$ColorRect.modulate.a = lerp($ColorRect.modulate.a, target_mod, delta * 20.0)
		$bg.modulate.a = lerp($bg.modulate.a, target_mod, delta * 20.0)

	# Scale animation via spring
	t += delta * 2.0  # time factor for spring curve
	var spring_scale: Vector2 = glob.spring(from_scale, to_scale, clamp(t, 0.0, 1.0), 2, 5.0, 1.0) 
	$ColorRect.scale = 0.5 * (spring_scale + Vector2.ONE)
	$ColorRect.position = glob.window_size / 2.0 - ($ColorRect.size * $ColorRect.scale) / 2.0
	$bg.size = glob.window_size + Vector2(50, 50)


func splash() -> void:
	accept_event()
	from_scale = $ColorRect.scale
	to_scale = Vector2.ONE
	t = 0.0
	target_mod = 1.0
	splashed = true
	show()
	ui.add_splashed(self)

	glob.cam.process_mode = Node.PROCESS_MODE_DISABLED
	glob.tree_windows["env"].process_mode = Node.PROCESS_MODE_DISABLED
	RenderingServer.global_shader_parameter_set("_view_scale", 1.0)

func go_away() -> void:
	from_scale = $ColorRect.scale
	to_scale = Vector2.ZERO
	t = 0.0
	target_mod = 0.0
	splashed = false
	ui.rem_splashed(self)

	glob.cam.process_mode = Node.PROCESS_MODE_ALWAYS
	glob.tree_windows["env"].process_mode = Node.PROCESS_MODE_ALWAYS

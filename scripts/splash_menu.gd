extends Control
class_name SplashMenu

var splashed: bool = false

var target_y: float = 0.0



func _process(delta: float) -> void:
	if splashed:
		glob.mouse_pressed = false
		glob.mouse_just_pressed = false
		glob.mouse_alt_pressed = false
		if ui.get_focus():
			ui.get_focus().release_focus()
		glob.mouse_alt_just_pressed = false
	#if glob.space_just_pressed:
		#if !splashed:
			#splash()
		#else:
			#go_away()
	if splashed:
		target_y = glob.window_size.y / 2 - $ColorRect.size.y / 2
	else:
		target_y = glob.window_size.y
	var a = $ColorRect.position.y
	t += delta * 8.0
	if a > glob.window_size.y-1.0:
		hide()
	else:
		show()
		$ColorRect.modulate.a = lerp($ColorRect.modulate.a, target_mod, delta * 20.0)
		#print($ColorRect.position.y)
		$bg.modulate.a = $ColorRect.modulate.a
	$bg.size = glob.window_size + Vector2(50,50)
	$ColorRect.position.x = glob.window_size.x / 2.0 - $ColorRect.size.x / 2.0
	$ColorRect.position.y = lerp(from_val, target_y, glob.in_out_quad(clamp(t, 0, 1)))

func _ready() -> void:
	hide()

var from_val = 0.0
var t = 0.0
var target_mod = 0.0
func splash():
	accept_event()
	from_val = $ColorRect.position.y
	t = 0.0
	target_mod = 1.0
	splashed = true
	show()
	ui.add_splashed(self)
	glob.cam.process_mode = Node.PROCESS_MODE_DISABLED
	glob.tree_windows["env"].process_mode = Node.PROCESS_MODE_DISABLED
	#glob.menu_canvas.process_mode = Node.PROCESS_MODE_DISABLED
	#graphs.storage.process_mode = Node.PROCESS_MODE_DISABLED


func go_away():
	from_val = $ColorRect.position.y
	t = 0.0
	target_mod = 0.0
	splashed = false
	ui.rem_splashed(self)
	glob.cam.process_mode = Node.PROCESS_MODE_ALWAYS
	glob.tree_windows["env"].process_mode = Node.PROCESS_MODE_ALWAYS
	#glob.menu_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	#graphs.storage.process_mode = Node.PROCESS_MODE_ALWAYS

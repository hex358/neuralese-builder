extends Camera2D
class_name GraphViewport

@export var zoom_speed: float = 300.0
@export var drag_button: int = 1
@export var drag_speed: float = 1.0
@export var zoom_interpolation_speed: float = 10.0

var paused: bool = false

func stop():
	paused = true
	drag_move_vec = Vector2()

func resume():
	paused = false

var dragging: bool = false

func _enter_tree() -> void:
	glob.cam = self
	glob.viewport = get_viewport()

var _ignore_next_motion: int = 0

func _handle_mouse_wrap(pos: Vector2) -> void:
	var sz = Vector2(glob.space_end)
	var new_pos = pos
	var wrapped := false

	if pos.x <= glob.space_begin.x:
		new_pos.x = sz.x - 2
		wrapped = true
	elif pos.x >= sz.x - 1:
		new_pos.x = 1 + glob.space_begin.x
		wrapped = true

	if pos.y <= glob.space_begin.y:
		new_pos.y = sz.y - 2
		wrapped = true
	elif pos.y >= sz.y - 1:
		new_pos.y = 1 + glob.space_begin.y
		wrapped = true

	if wrapped:
		_ignore_next_motion = 2  # skip next few motion events
		get_viewport().warp_mouse(new_pos)


var target_zoom: float = zoom.x

var target_position: Vector2 = Vector2()
var acc: bool = false
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == drag_button:
			dragging = event.pressed

		elif not ui.splashed and not paused and event.pressed and not glob.is_occupied(self, &"scroll"):
			var factor = zoom_speed * event.factor * zoom.x
			var prev_zoom = target_zoom
			
			match event.button_index:
				MOUSE_BUTTON_WHEEL_DOWN:
					target_zoom = max(0.5, zoom.x - factor)
				MOUSE_BUTTON_WHEEL_UP:
					target_zoom = min(2, zoom.x + factor)
			if target_zoom != prev_zoom:
				move_intensity = 1.0
				glob.hide_all_menus()

	elif event is InputEventMouseMotion and not paused and dragging and not glob.mouse_pressed and acc and not ui.splashed:
		if _ignore_next_motion > 0:
			_ignore_next_motion -= 1
			return
		target_position -= event.relative * drag_speed / zoom
		glob.hide_all_menus()
		_handle_mouse_wrap(event.position)


var move_intensity: float = 1.0
var zoom_move_vec: Vector2 = Vector2()
var drag_move_vec: Vector2 = Vector2()

func mouse_range(pos: float, edge_start: float, edge_end: float, axis: int):
	var edge_min: float = -edge_start 
	var edge_max: float = -edge_end
	match axis:
		glob.UP: edge_min = glob.space_begin.y-edge_min; edge_max = glob.space_begin.y-edge_max
		glob.LEFT: edge_min = glob.space_begin.x-edge_min; edge_max = glob.space_begin.x-edge_max
		glob.DOWN: edge_min += glob.space_end.y; edge_max += glob.space_end.y
		glob.RIGHT: edge_min += glob.space_end.x; edge_max += glob.space_end.x
	var t = inverse_lerp(edge_min, edge_max, pos)
	return clamp(t, 0.0, 1.0)

var rise_mult: float = 0.0
func _process(delta: float) -> void:
	if glob.mouse_middle_just_pressed and not paused:
		acc = glob.get_display_mouse_position().x < glob.space_end.x
	var mouse: Vector2 = get_global_mouse_position()
	if not ui.splashed:
		RenderingServer.global_shader_parameter_set("_view_scale", pow(zoom.x, 0.25))
	zoom = Vector2.ONE * lerp(zoom.x, target_zoom, delta * zoom_interpolation_speed)
	move_intensity = lerp(move_intensity, 0.0, delta * zoom_interpolation_speed)
	if glob.mouse_scroll and not ui.splashed:
		zoom_move_vec = (mouse - get_global_mouse_position())
	if not paused:
		var display_mouse = glob.get_display_mouse_position()

		rise_mult = min(mouse_range(display_mouse.x, 110, 50, glob.RIGHT)+
								mouse_range(display_mouse.x, 110, 50, glob.LEFT)+
								mouse_range(display_mouse.y, 30, -30, glob.UP)+
								mouse_range(display_mouse.y, 30, -30, glob.DOWN), 1.0) if !glob.is_occupied(self,&"scroll") else 0.0
		if (graphs.dragged or graphs.conns_active) and glob.mouse_pressed and rise_mult:
			var dir = glob.window_middle.direction_to(display_mouse)
			drag_move_vec = drag_move_vec.lerp(
			1000 * delta * dir * rise_mult / min(1.5, zoom.x * 1.5), 
			delta * 10.0)
			glob.hide_all_menus.call_deferred()
		else:
			drag_move_vec = drag_move_vec.lerp(Vector2(), delta * 10.0)
		target_position += drag_move_vec
	target_position += zoom_move_vec * move_intensity
	position = position.lerp(target_position, 20.0*delta)

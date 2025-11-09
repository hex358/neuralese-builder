extends Camera2D
class_name GraphViewport

@export var zoom_speed: float = 300.0
@export var drag_button: int = 1
@export var drag_speed: float = 1.0
@export var zoom_interpolation_speed: float = 10.0

var paused := false
var dragging := false
var target_zoom: float = zoom.x
var target_position := Vector2()
var acc := false
var move_intensity := 1.0
var zoom_move_vec := Vector2()
var drag_move_vec := Vector2()

var _last_disp := Vector2.ZERO

func _enter_tree() -> void:
	glob.cam = self
	glob.viewport = get_viewport()


func reset():
	target_position = position
	target_zoom = zoom.x
	dragging = false
	acc = false
	zoom_move_vec = Vector2()
	drag_move_vec = Vector2()
	move_intensity = 1.0

func _on_selector_pan(direction: Vector2):
	if paused or ui.active_splashed():
		return
	var pan_speed := 200.0 * get_process_delta_time() / zoom.x
	target_position += direction * pan_speed



func _ready() -> void:

	glob.selector_box.request_pan.connect(_on_selector_pan)
	_last_disp = glob.get_display_mouse_position()

func stop():
	paused = true
	drag_move_vec = Vector2()

func resume():
	paused = false

func _handle_mouse_wrap(pos: Vector2) -> void:
	var begin := glob.space_begin
	var end := glob.space_end
	var new_pos := pos
	var wrapped := false

	if pos.x <= begin.x:
		new_pos.x = end.x - 2; wrapped = true
	elif pos.x >= end.x - 1:
		new_pos.x = begin.x + 1; wrapped = true

	if pos.y <= begin.y:
		new_pos.y = end.y - 2; wrapped = true
	elif pos.y >= end.y - 1:
		new_pos.y = begin.y + 1; wrapped = true

	if wrapped:
		get_viewport().warp_mouse(new_pos)
		_last_disp = new_pos

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == drag_button:
			dragging = event.pressed
		elif not ui.active_splashed() and not ui.topr_inside and not paused and event.pressed and not glob.is_occupied(self, &"scroll") and glob.is_scroll_possible():
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


func _toroidal_delta(prev: Vector2, curr: Vector2) -> Vector2:
	var begin := glob.space_begin
	var end := glob.space_end
	var size := Vector2(end.x - begin.x, end.y - begin.y)

	var d := curr - prev
	if d.x > 0.5 * size.x:
		d.x -= size.x
	elif d.x < -0.5 * size.x:
		d.x += size.x

	if d.y > 0.5 * size.y:
		d.y -= size.y
	elif d.y < -0.5 * size.y:
		d.y += size.y

	return d


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

func change_cam(zoom, center):
	target_position = center
	target_zoom = zoom

var rise_mult := 0.0
func _process(delta: float) -> void:
	if not glob.is_scroll_possible():
		target_zoom = zoom.x
	if glob.mouse_middle_just_pressed and not paused:
		acc = glob.get_display_mouse_position().x < glob.space_end.x

	var mouse := get_global_mouse_position()
	if not ui.active_splashed():
		RenderingServer.global_shader_parameter_set("_view_scale", pow(zoom.x, 0.25))

	zoom = Vector2.ONE * lerp(zoom.x, target_zoom, delta * zoom_interpolation_speed)
	move_intensity = lerp(move_intensity, 0.0, delta * zoom_interpolation_speed)

	if glob.mouse_scroll and not ui.active_splashed():
		zoom_move_vec = (mouse - get_global_mouse_position())

	##if dragging:
	#	print("Ff")
	if not paused:
		var display_mouse = glob.get_display_mouse_position()
		if dragging:
		#	print("F")
			glob.hide_all_menus.call_deferred()
		if dragging and not glob.mouse_pressed and acc and not ui.active_splashed():
			var d = _toroidal_delta(_last_disp, display_mouse)
			if d != Vector2.ZERO:
				target_position -= d * drag_speed / zoom
			#glob.hide_all_menus()
			_handle_mouse_wrap(display_mouse)
			_last_disp = glob.get_display_mouse_position()
		else:
			_last_disp = display_mouse

		rise_mult = min(
			mouse_range(display_mouse.x, 110, 50, glob.RIGHT) +
			mouse_range(display_mouse.x, 110, 50, glob.LEFT) +
			mouse_range(display_mouse.y, 30, -30, glob.UP) +
			mouse_range(display_mouse.y, 30, -30, glob.DOWN),
			1.0
		) if !glob.is_occupied(self,&"scroll") else 0.0

		if (graphs.dragged or graphs.conning()) and glob.mouse_pressed and rise_mult and not ui.topr_inside:
			var dir = glob.window_middle.direction_to(display_mouse)
			drag_move_vec = drag_move_vec.lerp(
				1000 * delta * dir * rise_mult / min(1.5, zoom.x * 1.5),
				delta * 10.0
			)
			glob.hide_all_menus.call_deferred()
		else:
			drag_move_vec = drag_move_vec.lerp(Vector2(), delta * 10.0)

		target_position += drag_move_vec




	target_position += zoom_move_vec * move_intensity
	position = position.lerp(target_position, 20.0 * delta)

extends Camera2D
class_name GraphViewport

@export var zoom_speed: float = 300.0
@export var drag_button: int = 1
@export var drag_speed: float = 1.0
@export var zoom_interpolation_speed: float = 10.0

var dragging: bool = false

func _handle_mouse_wrap(pos: Vector2) -> void:
	var vp = get_viewport()
	var sz = vp.size
	var new_pos = pos

	if pos.x <= 0:
		new_pos.x = sz.x - 2
	elif pos.x >= sz.x - 1:
		new_pos.x = 1

	if pos.y <= 0:
		new_pos.y = sz.y - 2
	elif pos.y >= sz.y - 1:
		new_pos.y = 1

	if new_pos != pos:
		_ignore_next_motion = true
		vp.warp_mouse(new_pos)

var _ignore_next_motion: bool = false
var target_zoom: float = zoom.x

var target_position: Vector2 = Vector2()
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == drag_button:
			dragging = event.pressed

		elif event.pressed and not glob.is_occupied(self, &"scroll"):
			var factor = zoom_speed * event.factor * zoom.x
			var prev_zoom = target_zoom
			
			match event.button_index:
				MOUSE_BUTTON_WHEEL_DOWN:
					target_zoom = max(0.4, zoom.x - factor)
				MOUSE_BUTTON_WHEEL_UP:
					target_zoom = min(2, zoom.x + factor)
			if target_zoom != prev_zoom:
				move_intensity = 1.0
				glob.hide_all_menus()

	
	elif event is InputEventMouseMotion and dragging:
		if _ignore_next_motion:
			_ignore_next_motion = false
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
		glob.UP: edge_min *= -1; edge_max *= -1
		glob.LEFT: edge_min *= -1; edge_max *= -1
		glob.DOWN: edge_min += glob.window_size.y; edge_max += glob.window_size.y
		glob.RIGHT: edge_min += glob.window_size.x; edge_max += glob.window_size.x
	var t = inverse_lerp(edge_min, edge_max, pos)
	return clamp(t, 0.0, 1.0)

func _process(delta: float) -> void:
	var mouse: Vector2 = get_global_mouse_position()
	zoom = Vector2.ONE * lerp(zoom.x, target_zoom, delta * zoom_interpolation_speed)
	move_intensity = lerp(move_intensity, 0.0, delta * zoom_interpolation_speed)
	if glob.mouse_scroll:
		zoom_move_vec = (mouse - get_global_mouse_position())
	var display_mouse = glob.get_display_mouse_position()
	
	var rise_mult: float = min(mouse_range(display_mouse.x, 100, 50, glob.RIGHT)+
							mouse_range(display_mouse.x, 100, 50, glob.LEFT)+
							mouse_range(display_mouse.y, 30, 10, glob.UP)+
							mouse_range(display_mouse.y, 30, 10, glob.DOWN), 1.0)
	if glob.mouse_pressed and rise_mult:
		var dir = glob.window_middle.direction_to(display_mouse)
		drag_move_vec = drag_move_vec.lerp(
		800 * delta * dir * rise_mult / min(1.5, zoom.x * 1.5), 
		delta * 10.0)
	else:
		drag_move_vec = drag_move_vec.lerp(Vector2(), delta * 10.0)
	target_position += drag_move_vec
	target_position += zoom_move_vec * move_intensity
	position = position.lerp(target_position, 30.0*delta)

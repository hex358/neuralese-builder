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

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == drag_button:
			dragging = event.pressed

		elif event.pressed:
			var factor = zoom_speed * event.factor * zoom.x
			match event.button_index:
				MOUSE_BUTTON_WHEEL_DOWN:
					target_zoom = max(0.8, zoom.x - factor)
					glob.reset_menus()
				MOUSE_BUTTON_WHEEL_UP:
					target_zoom = min(2, zoom.x + factor)
					glob.reset_menus()
	
	elif event is InputEventMouseMotion and dragging:
		if _ignore_next_motion:
			_ignore_next_motion = false
			return

		position -= event.relative * drag_speed / zoom
		glob.reset_menus()
		_handle_mouse_wrap(event.position)

func _process(delta: float) -> void:
	zoom = Vector2.ONE * lerp(zoom.x, target_zoom, delta * zoom_interpolation_speed)

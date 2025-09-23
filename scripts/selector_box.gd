extends ColorRect

var selecting: bool = false
var select_origin: Vector2 = Vector2()

var target_pos: Vector2
var target_size: Vector2
@export var lerp_speed: float = 15.0  # higher = snappier

func _ready() -> void:
	hide()
	target_pos = position
	target_size = size

func _process(delta: float) -> void:
	if glob.mouse_just_pressed and not graphs.dragged and not graphs.conns_active and not ui.get_focus():
		select_origin = get_global_mouse_position()
		selecting = true
		show()
		position = select_origin
		size = Vector2.ZERO

	if selecting:
		if not glob.mouse_pressed:
			selecting = false
			hide()
			return

		var curr = get_global_mouse_position()
		var diff = curr - select_origin

		# update target_size and target_pos
		if diff.x >= 0:
			target_size.x = diff.x
			target_pos.x = select_origin.x
		else:
			target_size.x = -diff.x
			target_pos.x = curr.x

		if diff.y >= 0:
			target_size.y = diff.y
			target_pos.y = select_origin.y
		else:
			target_size.y = -diff.y
			target_pos.y = curr.y

	# lerp position & size toward targets every frame
	position = position.lerp(target_pos, lerp_speed * delta)
	size = size.lerp(target_size, lerp_speed * delta)

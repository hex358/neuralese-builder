@tool
extends Node2D
class_name Spline

@export var keyword: StringName = &""
@export var start: Vector2 = Vector2():
	set(v):
		start = v
		update_points(start, end, start_vector)

@export var end: Vector2 = Vector2():
	set(v):
		end = v
		update_points(start, end, start_vector)
@export var start_vector: Vector2 = Vector2():
	set(v):
		start_vector = v
		update_points(start, end, start_vector)


var origin: Connection
var tied_to: Connection

var curve = Curve2D.new()

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		end = $Marker2D.position

func appear():
	pass

var doomed: bool = false
func disappear():
	doomed = true
	queue_free()

func update_points(start: Vector2, end: Vector2, start_dir: Vector2) -> void:
	curve.bake_interval = 20
	curve.clear_points()

	var delta = end - start
	var dir_norm = start_dir
	var angle_to_x = dir_norm.angle()
	var local = delta.rotated(-angle_to_x)
	var local_handle = Vector2()
	if local.x > 0:
		local_handle.x = local.x * 0.5
	else:
		local_handle.y = local.y * 0.5
	var handle_out = local_handle.rotated(angle_to_x)
	curve.add_point(start, Vector2.ZERO, handle_out)
	curve.add_point(end,   Vector2.ZERO, Vector2.ZERO)
	queue_redraw()


	
func _draw() -> void:
	draw_polyline(curve.get_baked_points(), Color.WHITE, 10.0)

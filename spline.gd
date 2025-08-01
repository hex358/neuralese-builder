@tool
extends Node2D
class_name Spline

@export var start: Vector2 = Vector2():
	set(v):
		start = v
		update_points(start, end)

@export var end: Vector2 = Vector2():
	set(v):
		end = v
		update_points(start, end)

@export var origin_dir: Vector2 = Vector2.RIGHT

var origin: Connection
var tied_to: Connection

var curve = Curve2D.new()

func _ready() -> void:
	curve.add_point(Vector2(), Vector2(), Vector2())
	curve.add_point(Vector2(), Vector2(), Vector2())

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		end = $Marker2D.position

func appear():
	pass

var doomed: bool = false
func disappear():
	doomed = true
	queue_free()

func update_points(start: Vector2, end: Vector2) -> void:
	curve.clear_points()
	var dot = (end - start).normalized().dot(origin_dir)
	curve.add_point(start, Vector2(), Vector2())
	curve.add_point(end, (end-start).normalized().orthogonal()*50, Vector2())
	queue_redraw()
	
func _draw() -> void:
	draw_polyline(curve.get_baked_points(), Color.WHITE, 10.0)

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

@export var keyword: StringName = &""
@export var origin_dir: Vector2 = Vector2.RIGHT

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



func update_points(start: Vector2, end: Vector2) -> void:
	curve.bake_interval = 20
	curve.clear_points()
	if end.x > start.x:
		curve.add_point(start, Vector2(), abs(end.x-start.x)*Vector2(sign(end.x-start.x)/2.0, 0))
	else:
		curve.add_point(start, Vector2(), abs(end.y-start.y)*Vector2(0, sign(end.y-start.y)/2.0))
	curve.add_point(end, Vector2(), Vector2())
	queue_redraw()
	
func _draw() -> void:
	draw_polyline(curve.get_baked_points(), Color.WHITE, 10.0)

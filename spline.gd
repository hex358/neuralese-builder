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

func appear():
	pass
	
func disappear():
	queue_free()

func update_points(p_start: Vector2, p_end: Vector2) -> void:
	if p_start == p_end:
		return				# nothing to draw

	curve.clear_points()

	# 1 — segment vector & length
	var dir = p_end - p_start
	var seg_len = dir.length()

	# 2 — alignment with preferred launch direction
	var alignment = dir.normalized().dot(origin_dir.normalized())
	#   (+1 = same way, –1 = opposite)

	# 3 — curve factor in [0,1]
	var curve_factor = clamp((1.0 - alignment) * 0.5, 0.0, 1.0)

	# 4 — handle magnitude
	var x_diff = abs(p_start.x - p_end.x)
	var handle_len = seg_len * 0.7 / (max(x_diff, 10) / 1000.0)* curve_factor

	# 5 — perpendicular normal (-y, x)
	var normal = Vector2(-dir.y, dir.x).normalized()

	var handle_out = normal * handle_len
	
	#print((end.y-start.y)/20.0)
	curve.add_point(p_start, Vector2.ZERO, handle_out * clamp((p_end.y-p_start.y)/100.0, -1, 1))
	curve.add_point(p_end,    Vector2.ZERO,    Vector2.ZERO)

	queue_redraw()

func _draw() -> void:
	draw_polyline(curve.get_baked_points(), Color.WHITE, 10.0)

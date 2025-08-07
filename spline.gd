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
	return
	if Engine.is_editor_hint() and glob.ticks % 10 == 0:
		end = $Marker2D.position

func appear():
	pass

var doomed: bool = false
func disappear():
	doomed = true
	queue_free()

var end_dir_vec: Vector2
var baked: PackedVector2Array = [Vector2(), Vector2()]
func update_points(start: Vector2, end: Vector2, start_dir: Vector2, end_dir = null) -> void:
	if keyword == &"weight":
		baked = PackedVector2Array([start, end])
		#print(baked)
		queue_redraw()
		return
	
	if end_dir == null:
		if !end_dir_vec:
			end_dir_vec = -start_dir
		end_dir = end_dir_vec
	else:
		end_dir_vec = end_dir
		#print(end_dir_vec)
	
	var length: float = (end-start).length()
	var size: float = clamp(length*0.1, 2, 8)-2 # the initial "crusty" part of curve will become smaller
	curve.bake_interval = 10#clamp(length*0.05, 1, 2) # so the small curves looked better
	#print(curve.bake_interval)
	curve.clear_points()

	var second_point = start + start_dir * size
	var end_second_point = end + end_dir * size
	curve.add_point(start, Vector2(),Vector2())
	curve.add_point(second_point, Vector2(), size * (second_point-start))
	curve.add_point(end_second_point, -size * (end-end_second_point), Vector2())
	curve.add_point(end, Vector2(), Vector2())
	baked = curve.get_baked_points()
	queue_redraw()
	


	
func _draw() -> void:
	draw_polyline(baked, Color.WHITE, 10.0)

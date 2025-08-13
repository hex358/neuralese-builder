@tool
extends Node2D
class_name Spline

@export var line_2d: Line2D
@export var keyword: StringName = "default"
@export var color: Color


var origin: Connection
var tied_to: Connection

var curve = Curve2D.new()

func _ready() -> void:
	
	if !Engine.is_editor_hint():
		$Marker2D.queue_free()

func _process(delta: float) -> void:
	if Engine.is_editor_hint() and glob.ticks % 10 == 0:
		update_points(Vector2(), $Marker2D.position, Vector2.RIGHT)

func appear():
	pass

var doomed: bool = false
func disappear():
	doomed = true
	queue_free()

var end_dir_vec: Vector2
var baked: PackedVector2Array = [Vector2(), Vector2()]

func turn_into(word: StringName, other_word: StringName = &"default"):
	match other_word:
		"router":
			color = Color(1,1,0.5)
			keyword = "default"
		_:
			color = Color.WHITE
			keyword = "default"

var space = PackedVector2Array([Vector2(), Vector2()])
func weight_points(a:Vector2, b:Vector2, dir_a:Vector2, dir_b):
	space[0] = a; space[1] = b
	baked = space

func other_default_points(start: Vector2, end: Vector2, start_dir: Vector2, end_dir):
	var delta = end - start
	curve.bake_interval = clamp(delta.length()*0.1, 2, 30)
	var angle_to_x = start_dir.angle()
	var local = delta.rotated(-angle_to_x)
	var local_handle = Vector2()
	if local.x > 0:
		local_handle.x = local.x * 0.5
	else:
		local_handle.y = local.y * 0.5
	var handle_out = local_handle.rotated(angle_to_x)
	curve.add_point(start, Vector2.ZERO, handle_out)
	curve.add_point(end, Vector2.ZERO, Vector2.ZERO)
	baked = curve.get_baked_points()

var mapping = {"weight": weight_points}
var colors_array: PackedColorArray = PackedColorArray([Color.WHITE, Color.WHITE])
@export var color_a: Color = Color.WHITE:
	set(v):
		color_a = v; colors_array[0] = v
@export var color_b: Color = Color.WHITE:
	set(v):
		color_b = v; colors_array[1] = v
func update_points(start: Vector2, end: Vector2, start_dir: Vector2, end_dir = null) -> void:
	curve.clear_points()
	mapping.get(keyword, default_points).call(start, end, start_dir, end_dir)
	#line_2d.default_color = color
	line_2d.gradient.colors = colors_array
	line_2d.points = baked

func default_points(start: Vector2, end: Vector2, start_dir: Vector2, end_dir = null) -> void:
	#if keyword == &"weight":
		#baked = PackedVector2Array([start, end])
		##print(baked)
		#queue_redraw()
		#return
	
	if end_dir == null:
		if !end_dir_vec:
			end_dir_vec = -start_dir
		end_dir = end_dir_vec
	else:
		end_dir_vec = end_dir
		#print(end_dir_vec)
	
	var length: float = (end-start).length()
	var size: float = clamp(length*0.1, 2, 10)-2 # the initial "crusty" part of curve will become smaller
	curve.bake_interval = clamp(length*0.01, 1, 30) # so the small curves looked better
	#print(curve.bake_interval)
	curve.clear_points()

	var second_point = start + start_dir * size
	var end_second_point = end + end_dir * size
	curve.add_point(start, Vector2(),Vector2())
	curve.add_point(second_point, Vector2(), size * (second_point-start))
	curve.add_point(end_second_point, -size * (end-end_second_point), Vector2())
	curve.add_point(end, Vector2(), Vector2())
	baked = curve.get_baked_points()

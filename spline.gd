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

var keyword_mapping = {&"router": &"weight"}
func turn_into(word: StringName, other_word: StringName = &"default"):
	if other_word == "router":
		color = Color.YELLOW
	else:
		color = Color.WHITE

var space = PackedVector2Array([Vector2(), Vector2()])
func weight_points(a:Vector2, b:Vector2, dir_a:Vector2, dir_b:Vector2):
	space[0] = a; space[1] = b
	baked = space

func default_points(start: Vector2, end: Vector2, start_dir: Vector2, end_dir: Vector2):
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
func update_points(start: Vector2, end: Vector2, start_dir: Vector2, end_dir: Vector2 = Vector2()) -> void:
	curve.clear_points()
	mapping.get(keyword, default_points).call(start, end, start_dir, end_dir)
	line_2d.default_color = color
	line_2d.points = baked



	
func _draw() -> void:
	pass

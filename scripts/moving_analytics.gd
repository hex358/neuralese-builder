extends Control
class_name MovingAnalytics

@export var dot_represents: float = 0.1
@onready var circle: Control = $Circle
@onready var plot: ColorRect = $ColorRect


func _ready() -> void:
	circle.hide()
	for i in window_size:
		points[i] = 0.0
	#push_input(0.0, 0.8)
	#push_input(5.0, 0.1)


func push_input(time: float, value: float, last: bool = false) -> void:
	points_q[int(time / dot_represents) if not last else _window_end+1] = value

var points: Dictionary = {}
var points_q: Dictionary = {}
var t_last_frame: float = 0.0
var sliding_origin: int = 0
@export var window_size: int = 20
@export var snapshot_every: float = 0.1
var _window_end: int = window_size
func _process(delta: float) -> void:
	if Input.is_action_pressed("ui_up"):
		push_input(0, randf_range(0,1), true)
	t_last_frame += delta
	$Drawer.position.x = lerp(0.0, -$Drawer.spacing, t_last_frame / snapshot_every)
	if t_last_frame > snapshot_every: t_last_frame = 0.0
	else: return
	$Drawer.position.x = 0.0
	var new_points = points.duplicate()
	new_points.erase(sliding_origin)
	sliding_origin += 1
	_window_end = sliding_origin + window_size
	new_points[_window_end-1] = 0
	for i in points_q.keys():
		if i in new_points:
			new_points[i] = points_q[i]
			points_q.erase(i)
	points = new_points
	$Drawer._points = points
	$Drawer.reline()
	

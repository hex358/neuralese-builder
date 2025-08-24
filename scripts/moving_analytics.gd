extends Control
class_name MovingAnalytics

@export var move_speed: float = 0.1
@export var catchup_speed: float = 4.0

@export var y_min: float = 0.0
@export var y_max: float = 1.0
@export var y_padding: int = 6

@onready var circle: Control = $Circle
@onready var plot: ColorRect = $ColorRect

var _points: Dictionary = {}

var _right_time: float = 0.0
var _right_target: float = 0.0
var _time_initialized: bool = false

func _ready() -> void:
	circle.hide()
	push_input(0.0, 0.8)
	#push_input(5.0, 0.1)

func push_input(time: float, value: float) -> void:
	if not _time_initialized:
		_right_time = time
		_right_target = time
		_time_initialized = true
	else:
		if time > _right_target:
			_right_target = time

	var p: Control = circle.duplicate() as Control
	p.show()
	add_child(p)

	_points[p] = Vector2(time, value)
	_position_point(p, time, value)

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_accept"):
		push_input(snappedf(_right_target, 1.0), 0.5)
	
	if not _time_initialized:
		return

	_right_target += delta
	var alpha: float = clamp(delta * catchup_speed, 0.0, 1.0)
	_right_time = lerpf(_right_time, _right_target, alpha)

	var w: float = plot.size.x
	var h: float = plot.size.y
	var px_per_sec: float = _px_per_sec(w)

	var to_free: Array = []
	for p in _points:
		var tv: Vector2 = _points[p]
		var x: float = _time_to_x(tv.x, w, px_per_sec)
		var y: float = _value_to_y(tv.y, h)
		p.position = plot.position + Vector2(x, y)
		if x < -$Circle.size.x / 2:
			to_free.append(p)
		if x > $ColorRect.size.x + $ColorRect.position.x + $Circle.size.x / 2:
			p.hide()
		else:
			p.show()

	for p in to_free:
		_points.erase(p)
		p.queue_free()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _points.size() > 0:
		var w: float = plot.size.x
		var h: float = plot.size.y
		var px_per_sec: float = _px_per_sec(w)
		for p in _points.keys():
			var tv: Vector2 = _points[p]
			p.position = plot.position + Vector2(_time_to_x(tv.x, w, px_per_sec), _value_to_y(tv.y, h))

func _px_per_sec(width_px: float) -> float:
	return width_px * move_speed

func _time_to_x(sample_time: float, width_px: float, px_per_sec: float) -> float:
	var dt: float = _right_time - sample_time
	return width_px - dt * px_per_sec

func _value_to_y(value: float, height_px: float) -> float:
	var lo: float = min(y_min, y_max)
	var hi: float = max(y_min, y_max)
	var t: float = 0.0
	if hi != lo:
		t = clamp((value - lo) / (hi - lo), 0.0, 1.0)
	var top: float = float(y_padding)
	var bottom: float = max(0.0, height_px - float(y_padding))
	return lerp(bottom, top, t)

func _position_point(p: Control, time: float, value: float) -> void:
	var w: float = plot.size.x
	var h: float = plot.size.y
	p.position = plot.position + Vector2(_time_to_x(time, w, _px_per_sec(w)), _value_to_y(value, h))

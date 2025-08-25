extends Control

@export var origin_y: float = 0.0
@export var y_mult: float = 70.0
@export var spacing: float = 5.0
@export var width: float = 0.0
@export var offset_x: float = 0.0

@onready var line = $Line2D.duplicate()

func _ready() -> void:
	$Line2D.queue_free()

var lines = {}
var _points = []

func reline() -> void:
	var id: int = -1
	for point in _points:
		id += 1
		if not id in lines:
			lines[id] = [line.duplicate(), line.duplicate()]
			add_child(lines[id][0]);add_child(lines[id][1])
		var x = spacing * id + spacing / 2.0 + offset_x
		var point_diff = origin_y-_points[point]*y_mult
		lines[id][0].points = PackedVector2Array([
			Vector2(x,origin_y), Vector2(x,origin_y-y_mult)
		])
		lines[id][0].width = width
		lines[id][0].default_color = Color(0.2,0.2,0.2,1.0)

		lines[id][1].points = PackedVector2Array([
			Vector2(x,origin_y), Vector2(x,point_diff)
		])
		lines[id][1].width = width
		lines[id][1].default_color = Color.GREEN_YELLOW
		#draw_line(Vector2(x,origin_y), Vector2(x,origin_y-y_mult), Color(0.2,0.2,0.2,1.0), width, true)
		#draw_line(Vector2(x,origin_y), Vector2(x,point_diff), Color.GREEN_YELLOW, width, true)

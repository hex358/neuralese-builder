extends Line2D
class_name Spline

var tied_to: Connection
var origin: Connection

var arr = [Vector2(), Vector2()]
func update_points(start: Vector2, end: Vector2):
	arr[0] = start; arr[1] = end
	points = PackedVector2Array(arr)

func appear():
	pass

func disappear():
	queue_free()

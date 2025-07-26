extends ColorRect
class_name Block
@export var expanded_size: float = 190.0


var expanding = false
var pressed = false

func in_bounds() -> bool:
	return Rect2(0, 0, self.size.x, self.expanded_size).has_point(get_local_mouse_position())

func _ready():
	pass

func _process(delta: float) -> void:
	var mouse_in = in_bounds()
	if not mouse_in and Input.is_action_just_pressed("ui_mouse"):
		self.size.y = 54.0
		self.expanding = false
		show()
		pressed = true
		self.position = get_global_mouse_position()
	if Input.is_action_pressed("ui_mouse"):
		self.scale = self.scale.lerp(Vector2(0.95,0.95), delta*20.0)
	else:
		self.scale = self.scale.lerp(Vector2(1,1), delta*20.0)
		if pressed:
			self.expanding = true
	if self.expanding:
		self.size.y = lerpf(self.size.y, expanded_size, 30.0 * delta)

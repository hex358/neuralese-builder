extends Label
class_name LabelAutoResize

@onready var base_scale: float = scale.x
@export var padding: Vector2 = Vector2(4, 4) # optional extra spacing
@export var min_scale: float = 0.1

func _ready() -> void:
	resize()

func resize() -> void:
	var parent_ctrl := get_parent()
	if not (parent_ctrl is Control):
		return
	var parent_size: Vector2 = parent_ctrl.size
	var available: Vector2 = parent_size - position
	var text_size: Vector2 = glob.get_label_text_size(self, base_scale) + padding
	
	if text_size.x <= 0.0 or text_size.y <= 0.0:
		return

	var kx: float = available.x / text_size.x
	var ky: float = available.y / text_size.y
	var k: float = min(kx, ky)
	
	scale = Vector2.ONE * min(base_scale, max(min_scale, base_scale * k))

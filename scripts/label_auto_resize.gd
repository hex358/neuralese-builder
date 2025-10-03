extends Label
class_name LabelAutoResize

@onready var base_scale: float = scale.x
@export var padding: Vector2 = Vector2(4, 4) # optional extra spacing
@export var min_scale: float = 0.1
@export var parent_indep: bool = false
@export var base_size: Vector2

func _ready() -> void:
	resize.call_deferred()

func resize() -> void:
	var available: Vector2
	
	if parent_indep:
		available = base_size
	else:
		var parent_ctrl := get_parent()
		if not (parent_ctrl is Control):
			return
		available = parent_ctrl.size - position
	
	padding = Vector2.ZERO
	var text_size: Vector2 = glob.get_label_text_size(self, base_scale if !parent_indep else 1.0)
	if !parent_indep:
		text_size += padding / scale
	else:
		text_size += padding
	
	if text_size.x <= 0.0 or text_size.y <= 0.0:
		return
	
	var kx: float = available.x / text_size.x
	var ky: float = available.y / text_size.y
	var k: float = min(kx, ky)
	var new_scale: float = clamp(base_scale * k, min_scale, base_scale)
	scale = Vector2.ONE * new_scale

extends ColorRect

@export var offset_mult: float = 1.0

func _process(delta: float) -> void:
	var cam = get_viewport().get_camera_2d()
	position = cam.position - get_viewport_rect().size/2/cam.zoom*offset_mult

extends Control

var id: int = 0

func set_extents(vec: Vector2):
	$ColorRect5.set_instance_shader_parameter("extents", vec)
	$ColorRect5/Label.set_instance_shader_parameter("extents", vec)

func set_text(text: int):
	$ColorRect5/Label.text = str(text)

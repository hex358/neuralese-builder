extends TextureRect

func _ready() -> void:
	#RenderingServer.global_shader_parameter_add("bg", RenderingServer.GLOBAL_VAR_TYPE_SAMPLER2D, null)
	RenderingServer.global_shader_parameter_set("bg", texture)

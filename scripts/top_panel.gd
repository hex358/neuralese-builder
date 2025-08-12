extends ColorRect

func _ready() -> void:
	glob.space_begin.y = size.y + position.y

func _process(delta: float) -> void:
	if size.x != glob.window_size.x-position.x*2:
		size.x = glob.window_size.x-position.x*2

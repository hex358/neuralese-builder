extends Control

func is_focus(control: Control):
	return get_viewport().gui_get_focus_owner() == control

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == 1 and event.pressed:
		var focused = get_viewport().gui_get_focus_owner()
		if focused and focused is LineEdit:
			var rect = Rect2(focused.get_global_position(), focused.size)
			if not rect.has_point(event.position):
				focused.release_focus()

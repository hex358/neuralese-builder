extends DynamicGraph

func _get_unit(kw: Dictionary) -> Control: #virtual
	var dup = _unit.duplicate()
	dup.modulate.a = 0.0
	dup.show()
	return dup

func _unit_modulate_updated(of: Control):
	of.get_node("ColorRect5").set_instance_shader_parameter("extents", 
	Vector2(rect.global_position.y, rect.global_position.y + rect.size.y + 20))

func _on_line_edit_text_changed(new_text: String) -> void:
	return
	var amount = int(new_text)
	var length = len(units)
	if length > amount:
		for i in range(length-amount):
			remove_unit(length-i-1)
	else:
		for i in range(amount-length):
			add_unit()

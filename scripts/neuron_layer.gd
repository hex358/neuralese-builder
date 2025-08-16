extends DynamicGraph

func _get_unit(kw: Dictionary) -> Control: #virtual
	var dup = _unit.duplicate()
	dup.modulate.a = 0.0
	dup.show()
	return dup

func _unit_modulate_updated(of: Control, fin: bool = false):
	var extents 
	if !fin:
		extents = Vector2(rect.global_position.y, rect.global_position.y + rect.size.y + 5)
	else:
		extents = Vector2()
	of.get_node("ColorRect5").set_instance_shader_parameter("extents", extents)

var _real_amount = 0
func _on_line_edit_text_changed(new_text: String) -> void:
	var amount = int(new_text)
	_real_amount = amount
	amount = min(_real_amount, 10)
	var length = len(units)
	if length > amount:
		for i in range(length-amount):
			remove_unit(length-i-1)
	else:
		for i in range(amount-length):
			add_unit()

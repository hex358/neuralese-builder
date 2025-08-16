extends DynamicGraph

func _get_unit(kw: Dictionary) -> Control: #virtual
	var dup = _unit.duplicate()
	dup.modulate.a = 0.0
	dup.show()
	return dup

func _get_info() -> Dictionary:
	return {}

func _size_changed():
	$ni.position.y = (rect.size.y) / 2 + rect.position.y
	$o.position.y = (rect.size.y) / 2 + rect.position.y
	reposition_splines()

func _dragged():
	var extents = Vector2(rect.global_position.y, rect.global_position.y + rect.size.y + 5 - 4)
	if len(units) > 10:
		units[-1].get_node("ColorRect5").set_instance_shader_parameter("extents", extents)
		units[0].get_node("ColorRect5").set_instance_shader_parameter("extents", extents)
	elif units:
#units[-1].get_node("ColorRect5").set_instance_shader_parameter("extents", extents)
		units[0].get_node("ColorRect5").set_instance_shader_parameter("extents", Vector2())
func _unit_modulate_updated(of: Control, fin: bool = false, diss: bool = false):
	
	var extents 
	#print(key_by_unit[of])
	var key = key_by_unit[of]
	if key == len(units)-1:
		pass
	if not (fin and (key != len(units)-1 and len(units) > 1)):
		extents = Vector2(rect.global_position.y, rect.global_position.y + rect.size.y + 5)
	else:
		extents = Vector2()
	of.get_node("ColorRect5").set_instance_shader_parameter("extents", extents)

var _real_amount = 0
@onready var base_size_add: float = size_add


func _on_line_edit_changed(new_text) -> void:
	await get_tree().process_frame
	var amount = int(new_text)
	_real_amount = amount
	amount = min(_real_amount, 11)
	if _real_amount > 10:
		size_add = base_size_add - 15
	else:
		size_add = base_size_add
	var length = len(units)
	if length > amount:
		for i in range(length-amount):
			remove_unit(length-i-1)
	else:
		for i in range(amount-length):
			add_unit()

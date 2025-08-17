extends DynamicGraph

@export var group_size: int = 1:
	set(value):
		group_size = max(1, value)
		_apply_grouping() # re-group at runtime

var _real_amount = 0 # total neuron_count (from LineEdit)
@onready var base_size_add: float = size_add

func _get_unit(kw: Dictionary) -> Control: # virtual
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
		units[-1].set_extents(extents)
		units[0].set_extents(extents)
	elif units:
		units[0].set_extents(Vector2())

func _unit_modulate_updated(of: Control, fin: bool = false, diss: bool = false):
	var extents
	var key = key_by_unit[of]
	if not fin or (len(units) > 9 and key == 10):
		extents = Vector2(rect.global_position.y, rect.global_position.y + rect.size.y + 5 - 3)
	else:
		extents = Vector2()
	of.set_extents(extents)
	_dragged()

func _apply_grouping() -> void:
	var MAX_UNITS = 11
	
	var gs = max(1, group_size)
	var full_groups = int(_real_amount / gs)
	var remainder = int(_real_amount % gs)
	var needed_units = full_groups + (1 if remainder > 0 else 0)

	var visible_units = min(needed_units, MAX_UNITS)

	if needed_units > 10:
		size_add = base_size_add - 15
	else:
		size_add = base_size_add

	var length = len(units)
	if length > visible_units:
		for i in range(length - visible_units):
			remove_unit(length - i - 1)
	elif length < visible_units:
		for i in range(visible_units - length):
			add_unit({}, true)

	if needed_units <= MAX_UNITS:
		for i in range(visible_units):
			var count_in_group = gs if (i < full_groups) else remainder
			if count_in_group == 0: count_in_group = gs
			units[i].set_text(count_in_group)
	else:
		for i in range(MAX_UNITS - 1):
			units[i].set_text(gs)
		var covered = gs * (MAX_UNITS - 1)
		var tail = max(0, _real_amount - covered)
		units[MAX_UNITS - 1].set_text(tail)

func _on_line_edit_changed(new_text) -> void:
	await get_tree().process_frame
	var parsed = int(new_text)
	_real_amount = max(0, parsed)
	_apply_grouping()

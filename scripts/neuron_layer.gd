extends BaseNeuronLayer
class_name NeuronLayer


func _useful_properties() -> Dictionary:
	#assert (input_keys[0].inputs, "no config. TODO: implement error handling")
	var conf = {"activation": "none"}
	if input_keys[0].inputs:
		conf["activation"] = input_keys[0].inputs.keys()[0].origin.parent_graph.selected_activation
	return {
	"neuron_count": _real_amount,
	"config": conf,
	"cache_tag": str(graph_id)
	}

func _neurons_fix_set(v: bool):
	if v:
		ui.line_block(line_edit)
	else:
		ui.line_unblock(line_edit)


func push_neuron_count(parsed: int):
	update_config({"neuron_count": parsed})

@export var group_size: int = 1:
	set(value):
		group_size = max(1, value)
		_apply_grouping()

var _real_amount = 0
@onready var base_size_add: float = size_add

func _get_unit(kw: Dictionary) -> Control:
	var dup = _unit.duplicate()
	dup.modulate.a = 0.0
	dup.show()
	return dup

func _get_info() -> Dictionary:
	return {}

var last_resized: int = 0
func _size_changed():
	$ni.position.y = (rect.size.y) / 2 + rect.position.y
	$o.position.y = (rect.size.y) / 2 + rect.position.y
	reposition_splines()
	last_resized = 0
	hold_for_frame()

func _dragged():
	last_resized = 0

func _after_process(delta:float):
	super(delta)
	last_resized += 1
	if last_resized < 20:
		if len(units) > max_units:
			var extents = Vector2(rect.global_position.y, rect.global_position.y + rect.size.y)
			units[-1].set_extents(extents)
			units[0].set_extents(extents)
		elif units:
			units[0].set_extents(Vector2())

func _just_connected(who: Connection, to: Connection):
	pass

func _just_disconnected(who: Connection, from: Connection):
	pass

func _unit_modulate_updated(of: Control, fin: bool = false, diss: bool = false):
	var extents
	var key = key_by_unit[of]
	if not fin or (len(units) > max_units-1 and key == max_units):
		extents = Vector2(rect.global_position.y, rect.global_position.y + rect.size.y)
	else:
		extents = Vector2()
	of.set_extents(extents)
	#if len(units) > 10:
		#extents = Vector2(rect.global_position.y, rect.global_position.y + rect.size.y)
		#units[-1].set_extents(extents)
		#units[0].set_extents(extents)
	#elif units:
		#units[0].set_extents(Vector2())

@export var max_units = 20

func _apply_grouping() -> void:
	var MAX_UNITS = max_units + 1
	
	var gs = max(1, group_size)
	var full_groups = int(_real_amount / gs)
	var remainder = int(_real_amount % gs)
	var needed_units = full_groups + (1 if remainder > 0 else 0)

	var visible_units = min(needed_units, MAX_UNITS)

	if needed_units > max_units:
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
		units[MAX_UNITS - 1].set_text(tail, true)

var neuron_count: int = 0
func _config_field(field: StringName, val: Variant):
	match field:
		"neuron_count":
			neuron_count = val
			line_edit.set_line(str(val))
			_real_amount = max(0, val)
			_apply_grouping()
			for i in get_first_descendants():
				if i.server_typename == "Reshape2D":
					i.update_config({"rows": i.cfg.rows, "columns": i.cfg.columns})
			hold_for_frame()
			

func _on_line_edit_changed(new_text) -> void:
	await get_tree().process_frame
	update_config({"neuron_count": int(new_text)})
	#_apply_grouping()

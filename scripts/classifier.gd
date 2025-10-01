extends DynamicGraph


var value_cache: Array = []
func unit_set(unit, value, text):
	units[unit].set_weight(value, text)

func push_values(values: Array, percent: bool = false):
	var minimal = values.min()
	var maximal = values.max()
	var add = "%" if percent else ""
	for unit in len(values):
		var value = (values[unit] - minimal) / float(maximal - minimal)
		var capped = glob.cap(values[unit], 2) if !percent else round(values[unit]*100.0)
		if percent:
			unit_set(unit, value, str(capped)+"%")
		else:
			unit_set(unit, value, str(capped))
	for unit in range(len(values), len(units)):
		if percent:
			unit_set(unit, 0.0, "0%")
		else:
			unit_set(unit, 0.0, "0.0")

func _unit_just_added() -> void:
	var ancestor = get_first_ancestors()
	if ancestor: 
		if ancestor[0].server_typename == "SoftmaxNode":
			push_values(value_cache, true)
		else:
			push_values(value_cache, false)
	else:
		push_values(value_cache, false)
	
func _deattaching(other_conn: Connection, my_conn: Connection):
	var ancestor = get_first_ancestors()
	if ancestor: 
		if ancestor[0].server_typename == "SoftmaxNode":
			push_values(value_cache, false)


func _just_attached(other_conn: Connection, my_conn: Connection):
	if other_conn.parent_graph.server_typename == "SoftmaxNode":
		push_values(value_cache, true)
	else:
		push_values(value_cache, false)


func _after_process(delta: float):
	super(delta)
	#push_values(range(len(units)), true)

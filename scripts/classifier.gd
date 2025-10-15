extends DynamicGraph

var value_cache: Array = []
var manually: bool = false
func unit_set(unit, value, text):
	units[unit].set_weight(value, text)

func _config_field(field: StringName, value: Variant):
	if not manually and field == "units":
		for i in len(value):
			add_unit({"text": value[i]})
		#	units[i].get_node("Label").text = value[i]
		push_values(value_cache, per)
		

var per: bool = false
func push_values(values: Array, percent: bool = false):
	per = percent
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
	var res = []
	for i in units: 
		res.append(i.get_node("Label").text)
	manually = true
	update_config({"units": res})
	manually = false

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

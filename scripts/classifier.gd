extends DynamicGraph
class_name OutputGraph

var value_cache: Array = []
var manually: bool = false
func unit_set(unit, value, text):
	units[unit].set_weight(value, text)

func _config_field(field: StringName, value: Variant):
	if not manually and field == "label_names":
		for i in len(value):
			add_unit({"text": value[i]})
		#	units[i].get_node("Label").text = value[i]
		push_values(value_cache, per)
	if not upd and field == "title":
		$ColorRect/root/Label.set_line(value)
		ch()

func _can_drag() -> bool:
	return super() and not ui.is_focus($ColorRect/root/Label)

func _proceed_hold() -> bool:
	return ui.is_focus($ColorRect/root/Label)
	

func get_title() -> String:
	return $ColorRect/root/Label.text if $ColorRect/root/Label.text else "LabelGroup"

var per: bool = false
func push_values(values: Array, percent: bool = false):
	per = percent
	var minimal = values.min() if !percent else 0.0
	var maximal = values.max() if !percent else 1.0
	var add = "%" if percent else ""
	for unit in len(values):
		var value = (values[unit] - minimal) / float(maximal - minimal)
		var capped = glob.cap(values[unit], 2) if !percent else round(values[unit]*100.0)
		if unit >= len(units): continue
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
	update_config({"label_names": res})
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
	graphs.push_1d(other_conn.parent_graph.get_x(), other_conn.parent_graph)
	if other_conn.parent_graph.server_typename == "SoftmaxNode":
		push_values(value_cache, true)
	else:
		push_values(value_cache, false)

var res_meta: Dictionary = {}
func push_result_meta(meta: Dictionary):
	res_meta = meta
	ch()


func _after_process(delta: float):
	super(delta)
	#push_values(range(len(units)), true)

func ch():
	var target = graphs._reach_input(self)
	if !target: return
	var got = graphs.get_input_name_by_graph(target)
	if got:
		graphs.model_updated.emit(got)

var upd = false
signal label_changed(text: String)
func _on_label_changed() -> void:
	ch()
	upd = true
	update_config({"title": $ColorRect/root/Label.text})
	upd = false
	#var netname = target.get_netname()
	#if netname:
	#	netname.reload()
	#label_changed.emit($ColorRect/root/Label.text)

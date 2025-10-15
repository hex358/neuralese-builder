extends DynamicGraph

var name_graph: String = ""

func _useful_properties() -> Dictionary:
	var body = {}
	for u in units:
		body[u.get_meta("points_to").graph_id] = "cross_entropy"
	return {
		"config": {"branch_losses": body}
	}

func _request_save():
	set_name_graph(name_graph)

func dis():
	$Label2.hide()

func edit_unit(node: Graph, u: Control):
	u.get_node("Control/Label").text = node.get_title()
	u.get_node("Control/Label").resize()
	u.set_meta("points_to", node)



func _process(delta: float) -> void:
	super(delta)
	#if glob.space_just_pressed:
		#print(_useful_properties())

func _just_attached(other_conn: Connection, my_conn: Connection):
	pass


func set_name_graph(st: String, remove = null):
	hold_for_frame()
	var old_len = len(units)
	var branch_ends = {}
	var cachify = func (from: Connection, to: Connection, branch_cache: Dictionary):
		if to.parent_graph == remove: return
		if to.parent_graph.server_typename == "ClassifierNode": return
		var desc = to.parent_graph.get_first_descendants()
		if remove in desc:
			desc.erase(remove)
		if desc.is_empty() or (len(desc) == 1 and desc[0].server_typename == "ClassifierNode"):
			branch_ends[to.parent_graph] = true
	name_graph = st
	var input_graph = graphs.get_input_graph_by_name(name_graph)
	#print(graphs.graph_map)
	#print(input_graph)
	if !is_instance_valid(input_graph): 
		for unit in len(units):
			remove_unit(len(units)-1)
		dis()
		return
	graphs.reach(input_graph, cachify)
	var new_len = len(branch_ends)
	for unitt in range(new_len, old_len):
		remove_unit(len(units)-1)
	if !new_len:
		dis()
	else:
		$Label2.show()
	var ct: int = -1
	for j in (branch_ends):
		ct += 1
		#print(j.get_title())
		if ct >= old_len:
			add_unit({"text": j.get_title()}, true)
		edit_unit(j, units[ct])

func _get_unit(kw: Dictionary) -> Control: #virtual
	var dup = _unit.duplicate()
	dup.get_node("loss").graph = dup
	dup.get_node("loss").auto_ready = true
	for child in dup.get_node("loss").get_children():
		if child is BlockComponent:
			child.auto_ready = true
	dup.get_node("imp").graph = dup
	dup.get_node("imp").auto_ready = true
	for child in dup.get_node("imp").get_children():
		if child is BlockComponent:
			child.auto_ready = true

	dup.get_node("Control/Label").text = kw["text"]
	dup.show()
	dup.modulate.a = 0.0
	appear_units[dup] = true
	return dup




func _ready() -> void:
	super()



	set_name_graph("")

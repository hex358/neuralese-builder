extends DynamicGraph

var name_graph: String = ""

func _useful_properties() -> Dictionary:
	return {}

func _request_save():
	set_name_graph(name_graph)

func dis():
	$Label2.hide()

func edit_unit(node: Graph, u: Control):
	u.get_node("Control/Label").text = node.server_typename
	u.get_node("Control/Label").resize()

func _process(delta: float) -> void:
	super(delta)

func _just_attached(other_conn: Connection, my_conn: Connection):
	pass

func set_name_graph(st: String, remove = null):
	hold_for_frame()
	var old_len = len(units)
	var branch_ends = {}
	var cachify = func (from: Connection, to: Connection, branch_cache: Dictionary):
		if to.parent_graph == remove: return
		var desc = to.parent_graph.get_first_descendants()
		if remove in desc:
			desc.erase(remove)
		if desc.is_empty():
			branch_ends[to.parent_graph] = true
	name_graph = st
	var input_graph = graphs.graph_by_name(name_graph)
	#print(graphs.graph_map)
	#print(input_graph)
	if !is_instance_valid(input_graph): 
		for unit in len(units):
			remove_unit(len(units)-1)
		dis()
		return
	graphs.reach(input_graph, cachify)
	var new_len = len(branch_ends)
	for unit in range(new_len, old_len):
		remove_unit(len(units)-1)
	if !new_len:
		dis()
	else:
		$Label2.show()
	var ct: int = -1
	for j in (branch_ends):
		ct += 1
		if ct >= old_len:
			add_unit({"text": j.server_typename}, true)
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
				
	graphs.spline_connected.connect(
	func(x: Connection, y: Connection):
		var reached = graphs._reach_input(x.parent_graph)
		#if x.parent_graph.server_typename != "ModelName": return
		#print(reached)
		print(name_graph)
		if reached and reached == graphs.graph_by_name(name_graph) :
			set_name_graph(name_graph)
		if x.parent_graph.server_typename == "ModelName":
			var desc = x.parent_graph.get_first_descendants()
			var conds = [false, false]
			for i in desc:
				if i.server_typename == "InputNode":
					conds[0] = true
				if i == self:
					conds[1] = true
			#print(x.parent_graph.cfg["name"])
			if conds[0] and conds[1]:
				set_name_graph(x.parent_graph.cfg["name"])
	)
	graphs.spline_disconnected.connect(
	func(x: Connection, y: Connection):
		var reached = graphs._reach_input(x.parent_graph)
		if reached and reached == graphs.graph_by_name(name_graph):
			set_name_graph(name_graph, y.parent_graph)
		if x.parent_graph.server_typename == "ModelName":
			if y.parent_graph.server_typename == "InputNode" and name_graph == x.parent_graph.cfg.get("name", ""):
				set_name_graph("")
	)

	set_name_graph("")

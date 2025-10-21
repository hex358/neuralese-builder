extends DynamicGraph

var name_graph: String = ""

var unit_keys = {}
func _useful_properties() -> Dictionary:
	var body = {}
	#print(cfg)
	for u in units:
		var who = (u.get_meta("points_to").graph_id)
		var real = u.get_meta("points_to").get_ancestor().graph_id
		#print(real)
		body[real] = cfg["branches"].get(str(who), "mse")
	#print(body)
	return {
		"config": {"branch_losses": body}
	}

func get_mapped(targets: bool = true) -> Array:
	var res = []
	for i in virtual_outputs.values():
		var got = i.get_target()
		if not got: continue
		var slice = {"got_label": got.parent_graph.get_label(got.get_parent()), 
		"out_labels_title": unit_titles[i.get_parent()]}
		res.append(slice)
		if targets:
			slice["conn"] = got
	return res

func _llm_map(pack: Dictionary):
	await get_tree().process_frame
	await get_tree().process_frame
	#cfg["branches"].clear()
	for i in pack["loss_heads"]:
		#i = cfg[""]
		#var node = glob.tags_1d.get(i)
		#print(node)
		for branch_str in cfg["branches"]:
			#print(pack["loss_heads"][i])
			if not int(branch_str) in graphs._graphs: continue
			if graphs._graphs[int(branch_str)].get_title() == i:
				set_loss_type(branch_str, pack["loss_heads"][i])
		#else:
		#	print("Skipping one...")


func _request_save():
	set_name_graph(name_graph)

func dis():
	$Label2.hide()

func loss_button(bt: BlockComponent):
	#print("AA")
	#print(bt.is_contained.get_parent().name)
	var got = str(bt.is_contained.graph.get_meta("points_to", {"graph_id": ""}).graph_id)
	
	set_loss_type(got, bt.hint)
	bt.is_contained.text = bt.text
	bt.is_contained.menu_hide()

var manually: bool = false
func set_loss_type(of_id, loss: String, inner=false):
	#if not has_config_subfield("branches/" + str(node.graph_id)):
	if of_id == "": 
		return
	if not inner:
		manually = true
		update_config_subfield({"branches": {str(of_id): loss}})
	#print(of_id, unit_keys)
	
	if of_id in unit_keys:
		var ls = unit_keys[of_id].get_node("loss")
		if ls:
			ls.text = ls.button_by_hint[loss].text
	if not inner:
		manually = false

func _map_properties(pack: Dictionary):
	pass

func _config_field(field: StringName, value: Variant):
	if field.begins_with("branches/"):
		if not manually:
			var trimmed = field.trim_prefix("branches/")
			set_loss_type(trimmed, value, true)


func edit_unit(node: Graph, u: Control):
	u.get_node("Control/Label").text = node.get_title()
	u.get_node("Control/Label").resize()
	u.set_meta("points_to", node)
	unit_keys[str(node.graph_id)] = u
	unit_titles[u] = node.get_title()
	#set_loss_type(str(node.graph_id), "mse")
	#print("A!")




func _process(delta: float) -> void:
	super(delta)
	if glob.space_just_pressed:
		print(get_mapped())
		#print(_useful_properties())

func _just_attached(other_conn: Connection, my_conn: Connection):
	pass


func set_name_graph(st: String, remove = null):
	if st:
		$ColorRect/root/Label.position.y = 3
	else:
		$ColorRect/root/Label.position.y = 9
		
	hold_for_frame()
	
	var old_len = len(units)
	var branch_ends = {}
	var cachify = func (from: Connection, to: Connection, branch_cache: Dictionary):
		if to.parent_graph == remove: return
		if to.parent_graph.is_head: 
			branch_ends[to.parent_graph] = true; return
		#if desc[0].is_head:
		#	branch_ends[to.parent_graph] = true
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
	var prev_by_title := {}
	for id in cfg["branches"]:
		#var u = unit_keys.get(id)
		#if u:
		#	#var title = u.get_node("Control/Label").text
		if not int(id) in graphs._graphs: continue
		prev_by_title[graphs._graphs[int(id)].get_title()] = cfg["branches"][id]
	var new_len = len(branch_ends)
	for unitt in range(new_len, old_len):
		remove_unit(len(units)-1)
	if !new_len:
		dis()
	else:
		$Label2.show()
	var ct: int = -1
	for j: OutputGraph in (branch_ends):
		ct += 1
		#print(j.get_title())
		if ct >= old_len:
			add_unit({"text": j.get_title()}, true)
		edit_unit(j, units[ct])
		#if ct >= old_len:
		set_loss_type(str(j.graph_id), "mse")
		unit_set_meta(units[ct], j.res_meta)
	#print(prev_branches)
	#print(old_units)
	#print(prev_branches)
	#print(unit_keys)
	for j in branch_ends:
		var title = j.get_title()
		var loss = prev_by_title.get(title, "mse")
		set_loss_type(str(j.graph_id), loss)

func _unit_removal(id: int):
	units[id].get_node("i").queue_free()

func revise_datatypes(dt_1: Dictionary, dt_2: Dictionary) -> bool:
	if dt_1.datatype != dt_2.datatype:
		return false
	if dt_1.datatype == "1d": return dt_1.x == dt_2.x
	if dt_1.datatype == "2d": return dt_1.x == dt_2.x and dt_1.y == dt_2.y
	return false

func _is_suitable_conn(who: Connection, other: Connection) -> bool:
	if who.virtual:
		if not revise_datatypes(who.get_meta("kw"), other.get_meta("kw")): return false
	return true

func unit_set_meta(unit: Control, kw: Dictionary):
	var vec = str(kw["x"]) if kw["datatype"] == "1d" else str(kw["x"]) + "," + str(kw["y"])
	var res_text = kw["datatype"] + "(" + vec + ")"
	unit.get_node("ColorRect/Label2").text = res_text
	if unit.get_node("i").get_meta("kw"):
		if not revise_datatypes(unit.get_node("i").get_meta("kw"), kw):
			unit.get_node("i").disconnect_all()
	#print("fjfj")
	unit.get_node("i").set_meta("kw", kw)

var unit_titles = {}
func _get_unit(kw: Dictionary) -> Control: #virtual
	var dup = _unit.duplicate()
	dup.get_node("i").hint = randf_range(0,999999)
	dup.get_node("i").dynamic = false
	#dup.get_node("i").set_meta("kw", kw)
	dup.get_node("loss").graph = dup
	dup.get_node("loss").auto_ready = true
	unit_titles[dup] = kw["text"]
	for child in dup.get_node("loss").get_children():
		if child is BlockComponent:
			child.auto_ready = true
	dup.get_node("imp").graph = dup
	dup.get_node("imp").auto_ready = true
	for child in dup.get_node("imp").get_children():
		if child is BlockComponent:
			child.auto_ready = true
	dup.get_node("loss").child_button_release.connect(loss_button)
	dup.get_node("Control/Label").text = kw["text"]
	dup.show()
	dup.modulate.a = 0.0
	appear_units[dup] = true
	#unit_set_meta(dup, kw["end_node"])
	#update_config_subfield({"branches/%s"%})
	#print(outputs)
	return dup





func _ready() -> void:
	super()



	set_name_graph("")

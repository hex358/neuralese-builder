extends Graph

func _can_drag() -> bool:
	return not ui.is_focus($LineEdit)

func _proceed_hold() -> bool:
	return ui.is_focus($LineEdit)

func _just_connected(who: Connection, to: Connection):
	if to.parent_graph.server_typename == "InputNode":
		graphs.set_graph_name(graphs._reach_input(to.parent_graph), cfg["name"])
	if to.parent_graph.server_typename == "RunModel":
		to.parent_graph.set_name_graph(cfg["name"])

func _disconnecting(who: Connection, to: Connection):
	if to.parent_graph.server_typename == "InputNode":
		graphs.reset_graph_name(graphs._reach_input(to.parent_graph))
	if to.parent_graph.server_typename == "RunModel":
		to.parent_graph.set_name_graph("")

func _config_field(field: StringName, value: Variant):
	if field == "name":
		if not upd:
			$LineEdit.text = value
		var desc = get_first_descendants()
		for dess in desc: #deltarune
			if dess.server_typename == "InputNode":
				graphs.set_graph_name(graphs._reach_input(dess), cfg["name"])
			else:
				dess.set_name_graph(cfg["name"])

var upd: bool = false
func _on_line_edit_changed() -> void:
	upd = true
	update_config({"name": $LineEdit.text})
	upd = false

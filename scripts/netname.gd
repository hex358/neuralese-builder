extends Graph

func _can_drag() -> bool:
	return not ui.is_focus($LineEdit)

func _proceed_hold() -> bool:
	return ui.is_focus($LineEdit)

func _just_connected(who: Connection, to: Connection):
	if to.parent_graph.server_typename == "InputNode":
		graphs.set_graph_name(graphs._reach_input(to.parent_graph), cfg["name"])

func _disconnecting(who: Connection, to: Connection):
	if to.parent_graph.server_typename == "InputNode":
		graphs.reset_graph_name(graphs._reach_input(to.parent_graph))

func _config_field(field: StringName, value: Variant):
	if field == "name":
		if not upd:
			$LineEdit.text = value
		var desc = get_first_descendants()
		if desc:
			graphs.set_graph_name(graphs._reach_input(desc[0]), cfg["name"])

var upd: bool = false
func _on_line_edit_changed() -> void:
	upd = true
	update_config({"name": $LineEdit.text})
	upd = false

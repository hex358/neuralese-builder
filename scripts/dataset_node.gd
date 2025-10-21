extends Graph

func _can_drag() -> bool:
#	print(run)
	return not run.is_mouse_inside()

func _config_field(field: StringName, value: Variant):
	if field == "name":
		if not upd:
			$LabelAutoResize.text = value
			$LabelAutoResize.resize()

var upd: bool = false


func _on_line_edit_changed() -> void:
	upd = true
	update_config({"name": $LineEdit.text})
	upd = false

func _just_connected(who: Connection, to: Connection):
	to.parent_graph.set_dataset_meta({"name": "mnist", "outputs": [
	{"label": "digit", "x": 10, "datatype": "1d"},
	]})

func _just_disconnected(who: Connection, to: Connection):
	to.parent_graph.set_dataset_meta({"name": "", "outputs": []})

@onready var run = $run
func _on_run_released() -> void:
	var res = await ui.splash_and_get_result("select_dataset", run, null, false, {"with_who": cfg["name"]})
	hold_for_frame()
	if res:
		update_config({"name": res["ds"]})

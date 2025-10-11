extends Graph

func _can_drag() -> bool:
	return not ui.is_focus($LineEdit)

func _config_field(field: StringName, value: Variant):
	if field == "name":
		if not upd:
			$LineEdit.text = value

var upd: bool = false
func _on_line_edit_text_submitted(new_text: String) -> void:
	upd = true
	update_config({"name": new_text})
	upd = false

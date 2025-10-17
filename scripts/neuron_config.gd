extends Graph

@onready var dropout = $ColorRect2

func _config_field(field: StringName, value: Variant):
	if field == "activ":
		selected_activation = value
		if value in dropout.button_by_hint:
			dropout.text = dropout.button_by_hint[value].text

var selected_activation: StringName = &"none"
func _on_color_rect_2_child_button_release(button: BlockComponent) -> void:
	#button.is_contained.text = button.text
	update_config({"activ": button.hint})
	#selected_activation = button.hint
	button.is_contained.menu_hide()

@onready var list = $ColorRect2
func _proceed_hold() -> bool:
	return list.current_type == BlockComponent.ButtonType.CONTEXT_MENU

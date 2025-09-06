extends Graph

var selected_activation: StringName = &"none"
func _on_color_rect_2_child_button_release(button: BlockComponent) -> void:
	button.is_contained.text = button.text
	selected_activation = button.hint
	button.is_contained.menu_hide()

@onready var list = $ColorRect2
func _proceed_hold() -> bool:
	return list.current_type == BlockComponent.ButtonType.CONTEXT_MENU

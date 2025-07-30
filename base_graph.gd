@tool

extends Control
class_name Graph

@onready var label = $ColorRect/root/Label

enum Flags {NONE, NEW}
@export_flags("none", "new") var graph_flags = 0

@export_tool_button("Editor Refresh") var _editor_refresh = func():
	# Refresh property list and update shader parameters
	notify_property_list_changed()




func _editor_process(delta: float) -> void:
	pass

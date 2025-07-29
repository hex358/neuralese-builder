@tool

extends Control
class_name Graph

@onready var rect = $ColorRect
@onready var label = $ColorRect/root/Label

enum Flags {NONE, NEW}
@export_flags("none", "new") var graph_flags = 0

@export_tool_button("Editor Refresh") var _editor_refresh = func():
	# Refresh property list and update shader parameters
	notify_property_list_changed()

@export_group("Rect")
@export var base_size: Vector2 = size
@export var rect_center: Vector2 = Vector2(1, 1):
	set(v):
		if not is_node_ready(): 
			await ready
		rect_center = v; _align_rect(); _align_label()

@export_group("Text")
@export var text_alignment: Vector2 = Vector2()
@export var text_offset: Vector2 = Vector2():
	set(v):
		if not is_node_ready(): 
			await ready
		text_offset = v; _align_label()

func _align_label() -> void:
	# Center label within base_size
	var text_size = glob.get_label_text_size(label) * label.scale
	label.position = (base_size - text_size) / 2 * (text_alignment+Vector2.ONE) + text_offset

var rect_offset: Vector2 = Vector2()
func _init():
	rect_offset = base_size * (rect_center - Vector2(0.5, 0.5))

func _align_rect() -> void:
	# Position rect based on rect_center
	rect.position = rect_offset

func _editor_process(delta: float) -> void:
	if Engine.is_editor_hint():
		# Editor: sync size changes
		rect.size = size
		if rect.size != base_size:
			_align_label()
			base_size = rect.size
		return

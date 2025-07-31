@tool

extends Control
class_name Graph

@onready var label = $ColorRect/root/Label
@onready var rect = $ColorRect

enum Flags {NONE, NEW}
@export_flags("none", "new") var graph_flags = 0
@export var area_padding: float = 10.0

@export_tool_button("Editor Refresh") var _editor_refresh = func():
	# Refresh property list and update shader parameters
	notify_property_list_changed()

var inputs: Array[Connection] = []
var outputs: Array[Connection] = []
func _ready() -> void:
	position -= rect.position
	for child in get_children():
		if child is Connection: 
			match child.connection_type:
				Connection.INPUT: inputs.append(child)
				Connection.OUTPUT: outputs.append(child)

func is_mouse_inside() -> bool:
	# padded hit area
	var top_left = rect.global_position - Vector2.ONE*area_padding
	var padded_size = rect.size + Vector2(area_padding, area_padding)*2
	var bounds = Rect2(top_left, padded_size)
	return bounds.has_point(get_global_mouse_position())

var dragging: bool = false
var attachement_position: Vector2 = Vector2()
func _process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	
	var inside = is_mouse_inside()
	#if inside:
		#glob.occupy(self)
	#else:
		#glob.un_occupy(self)
	
	if inside and glob.mouse_just_pressed and not glob.is_occupied(self):
		dragging = true; attachement_position = global_position - get_global_mouse_position()
	if dragging:
		if not glob.mouse_pressed:
			dragging = false
			global_position.y += 10
		else:
			global_position = get_global_mouse_position() + attachement_position + Vector2(0,-10)
		for input in inputs:
			input.reposition_splines()
		for output in outputs:
			output.reposition_splines()

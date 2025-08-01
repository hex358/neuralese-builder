extends Control
class_name Graph

@onready var label = $ColorRect/root/Label
@onready var rect = $ColorRect

enum Flags {NONE=0, NEW=2}
@export_flags("none", "new") var graph_flags = 0
@export var area_padding: float = 10.0

var _inputs: Array[Connection] = []
var outputs: Array[Connection] = []
var output_keys: Dictionary[int, Connection] = {}
var input_keys: Dictionary[int, Connection] = {}
var input_key_by_conn: Dictionary[Connection, int] = {}

func _new_anim(): # virtual
	pass

func init_flags():
	if graph_flags & Flags.NEW:
		_new_anim()

func _ready() -> void:
	init_flags()
	position -= rect.position
	for c in get_children():
		if c is Connection: 
			var child:Connection = c
			match child.connection_type:
				Connection.INPUT: 
					_inputs.append(child)
					assert(not child.hint in input_keys, "Occupied")
					input_keys[child.hint] = child
					input_key_by_conn[child] = child.hint
				Connection.OUTPUT: 
					outputs.append(child)
					assert(not child.hint in output_keys, "Occupied")
					output_keys[child.hint] = child

func is_mouse_inside() -> bool:
	# padded hit area
	var top_left = rect.global_position - Vector2.ONE*area_padding
	var padded_size = rect.size + Vector2(area_padding, area_padding)*2
	var bounds = Rect2(top_left, padded_size)
	return bounds.has_point(get_global_mouse_position())

var dragging: bool = false
var attachement_position: Vector2 = Vector2()
var exist_time: float = 0.0

func _io(inputs: Dictionary) -> Variant:
	return inputs[0] + 1

var pushed_inputs = {}
func push_input(conn: Connection, val: Variant):
	var key:int = input_key_by_conn[conn]
	pushed_inputs[key] = val
	if len(pushed_inputs) >= len(_inputs):
		propagate(pushed_inputs)
		pushed_inputs.clear()


func propagate(input_vals: Dictionary):
	var out = _io(input_vals)
	var output_vals = {}
	if out is Array:
		for i in len(out):
			output_vals[i] = out[i]
	elif out is Dictionary:
		for i in out:
			output_vals[i] = out[i]
	else:
		for i in len(outputs):
			output_vals[i] = out
	#if not output_vals:
	#await glob.wait(0.3)
	for conn_key in output_vals:
		var conn:Connection = output_keys[conn_key]
		for key:int in conn.outputs:
			var spline:Spline = conn.outputs[key]
			spline.modulate = Color.YELLOW
			spline.tied_to.parent_graph.push_input(spline.tied_to, output_vals[conn_key])
			spline.modulate = Color.WHITE


func _process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	var inside = is_mouse_inside()
	if inside:
		if Input.is_action_just_pressed('ui_accept'):
			propagate({0: 2})
		glob.occupy(self, &"graph")
		glob.set_menu_type(self, &"edit_graph")
		if glob.mouse_alt_just_pressed:
			glob.show_menu("edit_graph")
	else:
		glob.reset_menu_type(self, &"edit_graph")
		glob.un_occupy(self, &"graph")
	if inside and glob.mouse_just_pressed and not glob.is_occupied(self, &"menu") and not glob.is_occupied(self, &"graph"):
		dragging = true; attachement_position = global_position - get_global_mouse_position()
	if dragging:
		if not glob.mouse_pressed:
			dragging = false
			global_position.y += 10
		else:
			global_position = get_global_mouse_position() + attachement_position + Vector2(0,-10)
		for input in _inputs:
			input.reposition_splines()
		for output in outputs:
			output.reposition_splines()

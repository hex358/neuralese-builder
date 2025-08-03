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

func _animate(delta: float): # virtual
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
	$ColorRect/root/Label.text = str(inputs[0][0]*2)
	return inputs[0][0] + 1

func _do_propagate(input_vals: Dictionary, gather: bool = false) -> void:
	var out = _io(input_vals)
	if gather:
		glob.gather(self, {})
	var output_vals = {}

	match typeof(out):
		TYPE_ARRAY:
			for i in out.size():
				output_vals[i] = out[i]
		TYPE_DICTIONARY:
			for i in out.keys():
				output_vals[i] = out[i]
		_:
			for i in outputs.size():
				output_vals[i] = out

	for out_key in output_vals.keys():
		var next_conn = output_keys[out_key]
		for branch_key in next_conn.outputs.keys():
			var spline = next_conn.outputs[branch_key]
			if not spline.tied_to: continue
			var other = spline.tied_to.parent_graph
			glob.next_frame_propagate(spline.tied_to, other.input_key_by_conn[spline.tied_to], output_vals[out_key])
	
	#print(out)

func _process(delta: float) -> void:
	_animate(delta)
	
	if Engine.is_editor_hint(): return
	var inside = is_mouse_inside()
	if inside:
		if Input.is_action_just_pressed('ui_accept'):
			_do_propagate({0: [1]})
		glob.occupy(self, &"graph")
		glob.set_menu_type(self, &"edit_graph")
		if glob.mouse_alt_just_pressed:
			glob.show_menu("edit_graph")
	else:
		glob.reset_menu_type(self, &"edit_graph")
		glob.un_occupy(self, &"graph")
	if inside and glob.mouse_just_pressed and (
		not glob.is_occupied(self, &"menu") and 
		not glob.is_occupied(self, &"graph") and 
		not glob.is_occupied(self, &"conn_active")):
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

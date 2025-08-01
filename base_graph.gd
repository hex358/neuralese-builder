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

# in your Graph (or wherever makes sense):
var propagation_queue: Array = []  # each entry is a Dictionary of inputs

func push_input(conn: Connection, val: Variant) -> void:
	var key = input_key_by_conn[conn]
	# collect inputs until node is ready
	if not pushed_inputs.has(conn): pushed_inputs[conn] = {}
	pushed_inputs[conn][key] = val

	if pushed_inputs[conn].size() >= _inputs.size():
		for i in pushed_inputs[conn]:
			glob.next_frame_propagate(conn, i, pushed_inputs[conn][i])
		#propagation_queue.append({
			#"connection": conn,
			#"inputs": pushed_inputs[conn]
		#})
		pushed_inputs.erase(conn)

func q():
	# process one propagation event per frame (or change to more)
	#if propagation_queue:
	#if propagation_queue:
	#	print(propagation_queue)
	for ev in propagation_queue:
		#print(ev)
		await _do_propagate(ev.connection, ev.inputs)
	propagation_queue.clear()

func _do_propagate(conn: Connection, input_vals: Dictionary) -> void:
	#print(input_vals)
	var out = _io(input_vals)
	var output_vals = {}

	match out:
		1:
			for i in out.size():
				output_vals[i] = out[i]
		0:
			for i in out.keys():
				output_vals[i] = out[i]
		_:
			for i in outputs.size():
				output_vals[i] = out
	
	#print(out)
	# ENQUEUE all of this node’s outgoing events:
	for out_key in output_vals.keys():
		var next_conn = output_keys[out_key]
		for branch_key in next_conn.outputs.keys():
			var spline = next_conn.outputs[branch_key]
			#print(spline)
			if spline.modulate == Color.WHITE: spline.modulate = Color(0.99, 0.1, 0.99, 1.0)
			spline.modulate = Color(1 / spline.modulate.r, 1 / spline.modulate.g, 1 / spline.modulate.b)
			# schedule the actual push_input for later (in _process)
			#print(input_key_by_conn)
			var other = spline.tied_to.parent_graph
			#print(other.input_key_by_conn[spline.tied_to])
			glob.next_frame_propagate(spline.tied_to, other.input_key_by_conn[spline.tied_to], output_vals[out_key])
			#other.propagation_queue.append({
				#"connection": spline.tied_to,
				#"inputs": {other.input_key_by_conn[spline.tied_to]: output_vals[out_key] }
			#})
			
	
	print(out)



func _process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	await q()
	var inside = is_mouse_inside()
	if inside:
		if Input.is_action_just_pressed('ui_accept'):
			push_input(input_keys[0], 2)
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

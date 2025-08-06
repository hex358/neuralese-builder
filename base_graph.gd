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

@onready var base_scale = scale
func _new_animate(delta: float): # virtual
	scale = glob.spring(base_scale * 0.5, base_scale, exist_time, 3.5, 16, 0.5)

func animate(delta: float):
	if graph_flags & Flags.NEW:
		_new_animate(delta)

func _sub_ready():
	pass

func add_connection(conn: Connection):
	match conn.connection_type:
		Connection.INPUT: 
			_inputs.append(conn)
			assert(not conn.hint in input_keys, "Occupied")
			input_keys[conn.hint] = conn
			input_key_by_conn[conn] = conn.hint
		Connection.OUTPUT: 
			outputs.append(conn)
			assert(not conn.hint in output_keys, "Occupied")
			output_keys[conn.hint] = conn

func _ready() -> void:
	position -= rect.position
	animate(0)
	_sub_ready()

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
	$ColorRect/root/Label.text = str(inputs[0][0]+1)
	return inputs[0][0]+1

var pushed_inputs = {}
func _seq_push_input(connection_key: int, value) -> void:
	pushed_inputs.get_or_add(connection_key, []).append(value)
	if len(pushed_inputs) >= len(input_keys):
		propagate(pushed_inputs)
		pushed_inputs.clear()

func propagate(input_vals: Dictionary, sequential_branching: bool = false) -> void:
	var out = _io(input_vals)
	var output_vals = {}
	modulate = Color(randf_range(0,1),randf_range(0,1),randf_range(0,1))

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

	for out_key in output_vals:
		var next_conn = output_keys[out_key]
		for branch_key in next_conn.outputs:
			var spline = next_conn.outputs[branch_key]
			if not spline.tied_to: continue
			var other_node: Graph = spline.tied_to.parent_graph
			var connection_key: int = other_node.input_key_by_conn[spline.tied_to]
			other_node._seq_push_input(connection_key, output_vals[out_key])
			#glob.next_frame_propagate(spline.tied_to, connection_key, output_vals[out_key])
			

func gather():
	pass

	#print(out)

func _process(delta: float) -> void:
	animate(delta)
	exist_time += delta
	
	if Engine.is_editor_hint(): return
	var inside = is_mouse_inside()
	if inside:
		if Input.is_action_just_pressed('ui_accept'):
			await propagate({0: [0]})
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
		else:
			global_position = get_global_mouse_position() + attachement_position
		for input in _inputs:
			input.reposition_splines()
		for output in outputs:
			output.reposition_splines()

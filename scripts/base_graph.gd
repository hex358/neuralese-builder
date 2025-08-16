extends Control
class_name Graph

@onready var label = $ColorRect/root/Label
@onready var rect = $ColorRect
@export var z_space: int = 2
@export var is_input: bool = false

enum Flags {NONE=0, NEW=2}
@export_flags("none", "new") var graph_flags = 0
@export var area_padding: float = 10.0

var _inputs: Array[Connection] = []
var outputs: Array[Connection] = []

var output_keys: Dictionary[int, Connection] = {}
var input_keys: Dictionary[int, Connection] = {}
var input_key_by_conn: Dictionary[Connection, int] = {}
var output_key_by_conn: Dictionary[Connection, int] = {}

var hold_process: bool = false

@onready var base_scale = scale
func _new_animate(delta: float): # virtual
	scale = glob.spring(base_scale * 0.5, base_scale, exist_time, 3.5, 16, 0.5)

func hold_for_frame(): hold_process = true

func animate(delta: float):
	if graph_flags & Flags.NEW:
		if exist_time < 2.0: hold_for_frame()
		_new_animate(delta)

func _after_ready():
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
			output_key_by_conn[conn] = conn.hint

var active_output_connections = {}
func get_inputs_set() -> Dictionary[Connection, int]: return input_key_by_conn
func get_outputs_set() -> Dictionary[Connection, int]: return output_key_by_conn

func conn_exit(conn: Connection):
	match conn.connection_type:
		Connection.INPUT: 
			_inputs.erase(conn)
			input_keys.erase(conn.hint)
			input_key_by_conn.erase(conn)
		Connection.OUTPUT: 
			output_keys.erase(conn.hint)
			outputs.erase(conn)
			output_key_by_conn.erase(conn)

func _exit_tree() -> void:
	graphs.remove(self)

func _ready() -> void:
	position -= rect.position
	animate(0)
	graphs.add(self)
	_after_ready()
	graphs.mark_rect(self)
	#graphs.collider(rect)


func is_mouse_inside() -> bool:
	# padded hit area
	#if glob.is_consumed(self, "mouse"): return false
	if glob.get_display_mouse_position().y < glob.space_begin.y\
	or glob.get_display_mouse_position().x > glob.space_end.x: return false
	var top_left = rect.global_position - Vector2.ONE*area_padding
	var padded_size = rect.size + Vector2(area_padding, area_padding)*2
	var bounds = Rect2(top_left, padded_size)
	var has: bool = bounds.has_point(get_global_mouse_position())
	if has:
		glob.consume_input(self, "mouse")
	return has

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

func get_info() -> Dictionary:
	var output = {
	"position": Vector2(),
	"arr": [position, rotation, scale, output_keys.keys()]
	}
	#print(input_keys)
	output.merge(_get_info())
	#var fields = graphs.FieldPack.new(output, 0<len(info_nested_fields), info_nested_fields)
	return output

var info_nested_fields: Array = []
func _get_info() -> Dictionary:
	return {}

func propagate(input_vals: Dictionary, sequential_branching: bool = false, gather_call: Callable = graphs.next_frame_propagate) -> void:
	var out = _io(input_vals) if not gather else null
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

	for out_key in output_vals:
		var next_conn = output_keys[out_key]
		for branch_key in next_conn.outputs:
			var spline = next_conn.outputs[branch_key]
			if not spline.tied_to: continue
			var other_node: Graph = spline.tied_to.parent_graph
			var connection_key: int = other_node.input_key_by_conn[spline.tied_to]
			#other_node._seq_push_input(connection_key, output_vals[out_key])
			gather_call.call(spline.tied_to, connection_key, output_vals[out_key])
			

func gather():
	pass

	#print(out)

func _can_drag() -> bool:
	return true

func _default_info() -> void: # virtual
	pass

var _info = {}
func set_info(name: String, value: Variant):
	pass

@onready var prev_size_: Vector2 = rect.size
var inside: bool = false
func _stopped_processing():
	if glob.hovered_connection in input_key_by_conn:
		glob.hovered_connection = null
	glob.reset_menu_type(self, &"edit_graph")
	glob.un_occupy(self, &"graph")
	graphs.stop_drag(self)
	if glob._menu_type_occupator in output_key_by_conn:
		glob.reset_menu_type(glob._menu_type_occupator, "detatch")
	if glob.is_occupied(self, "conn_active"):
		glob.un_occupy(glob.occ_layers["conn_active"], "conn_active")
		#hold_for_frame()
	#for i in graphs.conns_active:
		#if i in output_key_by_conn:
		#	glob.un_occupy(i, "conn_active")

func delete():
	_stopped_processing()
	queue_free()

var graph_id: int = 0

func _init() -> void:
	graph_id = randi_range(0,99999999)

func _dragged():
	pass

func _process(delta: float) -> void:
	if Engine.is_editor_hint(): return

	animate(delta)
#	graphs.store_delta(self)
	if prev_size_ != rect.size:
		prev_size_ = rect.size
		#graphs.collider(rect)
	exist_time += delta
	
	inside = is_mouse_inside()
	var conn_free = (not glob.hovered_connection or glob.hovered_connection.connection_type == 0 or z_index >= glob.hovered_connection.parent_graph.z_index)
	
	if inside and conn_free:
		glob.occupy(self, &"graph")
		glob.set_menu_type(self, &"edit_graph")
		if glob.mouse_alt_just_pressed and not dragging:
			glob.menus["edit_graph"].menu_call = delete
			glob.show_menu("edit_graph")
	else:
		glob.reset_menu_type(self, &"edit_graph")
		glob.un_occupy(self, &"graph")
	
	# TODO: remove this crutch
	var conn_active_layer = glob.occ_layers.get("conn_active")
	if conn_active_layer:
		if !conn_active_layer.active_outputs:
			glob.un_occupy(conn_active_layer, "conn_active")
		
	if inside and glob.mouse_just_pressed and _can_drag() and (
		not glob.is_occupied(self, &"menu") and 
		not glob.is_occupied(self, &"graph") and 
		not glob.is_occupied(self, &"menu_inside") and 
		not glob.is_occupied(self, &"conn_active") and
		conn_free) and not dragging:
		graphs.drag(self)
		dragging = true; attachement_position = global_position - get_global_mouse_position()

	if dragging:
		hold_for_frame()
		if not glob.mouse_pressed:
			dragging = false
			graphs.stop_drag(self)
		else:
			_dragged()
			var vec = get_global_mouse_position() + attachement_position - global_position
			#graphs.mark_rect(self)
			#vec = graphs.can_move(self, vec)
			global_position += vec
			#graphs.collider(rect)
		for input in _inputs:
			input.reposition_splines()
		for output in outputs:
			output.reposition_splines()
	
	_after_process(delta)

func _after_process(delta: float):
	pass

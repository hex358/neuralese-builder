extends Control
class_name Graph

@export var server_typename: StringName = ""
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

func hold_for_frame(): 
	#print_stack()
	hold_process = true

@export_group("Base Config")
@export var base_config: Dictionary[StringName, Variant] = {}
@export_group("")

func get_first_descendants() -> Array:
	var res: Dictionary = {}
	for i in outputs:
		for j:int in i.outputs:
			if is_instance_valid(i.outputs[j].tied_to.parent_graph):
				res[i.outputs[j].tied_to.parent_graph] = true
	return res.keys()

func get_first_ancestors() -> Array:
	var res: Dictionary = {}
	for i in input_keys:
		for j in input_keys[i].inputs:
			if is_instance_valid(j.origin.parent_graph):
				res[j.origin.parent_graph] = true
	return res.keys()

@onready var cfg: Dictionary[StringName, Variant] = base_config.duplicate()
func update_config(update: Dictionary):
	cfg.merge(update, true)
	check_valid(update)
	for field in update:
		_config_field(field, update[field])

func get_config_dict() -> Dictionary:
	return cfg.duplicate()

func _config_field(field: StringName, value: Variant):
	pass

func animate(delta: float):
	if graph_flags & Flags.NEW:
		if exist_time < 2.0: hold_for_frame()
		_new_animate(delta)

func _after_ready():
	pass


func is_branch_merge_allowed(who: Connection, to: Connection) -> bool:
	return true

func just_connected(who: Connection, to: Connection):
	graphs.update_dependencies()
	_just_connected(who, to)

func _is_valid() -> bool:
	return true

var invalid_fields: Dictionary = {}
var cfg_snapshot: Dictionary = {}
func check_valid(changed_fields: Dictionary) -> void:
	var ok: bool = _is_valid()
	if ok:
		_visualise_valid(true)
		invalid_fields.clear()
		#cfg_snapshot = cfg.duplicate(true)
		return
	#for field in changed_fields.keys():
	invalid_fields = changed_fields
	#if not cfg_snapshot.is_empty():
		#var to_remove: Array[StringName] = []
		#for field in invalid_fields.keys():
			#if cfg_snapshot.has(field) and cfg.get(field) == cfg_snapshot.get(field):
				#to_remove.append(field)
		#for f in to_remove:
			#invalid_fields.erase(f)
	_visualise_valid(false)

func _visualise_valid(ok: bool):
	pass

func just_deattached(other_conn: Connection, my_conn: Connection):
	_just_deattached(other_conn, my_conn)



func _just_deattached(other_conn: Connection, my_conn: Connection):
	pass


func just_attached(other_conn: Connection, my_conn: Connection):
	_just_attached(other_conn, my_conn)


func _just_attached(other_conn: Connection, my_conn: Connection):
	pass

func deattaching(other_conn: Connection, my_conn: Connection):
	_deattaching(other_conn, my_conn)

func connecting(my_conn: Connection, other_conn: Connection):
	_connecting(my_conn, other_conn)




func _deattaching(other_conn: Connection, my_conn: Connection):
	pass

func just_disconnected(who: Connection, from: Connection):
	#graphs.update_dependencies(who.parent_graph)
	from.parent_graph.just_deattached(who, from)
	_just_disconnected(who, from)

func disconnecting(who: Connection, from: Connection):
	#graphs.update_dependencies(who.parent_graph)
	from.parent_graph.deattaching(who, from)
	_disconnecting(who, from)

func _just_connected(who: Connection, to: Connection):pass
func _disconnecting(who: Connection, to: Connection):pass
func _connecting(who: Connection, to: Connection):pass
func _just_disconnected(who: Connection, from: Connection):pass

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

func reach(call: Callable):
	pass

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


func _chain_incoming(cache: Dictionary):
	pass

func useful_properties() -> Dictionary:
	return _useful_properties()

func _useful_properties() -> Dictionary:
	return {}

func _ready() -> void:
	position -= rect.position
	animate(0)
	graphs.add(self)
	_after_ready()
	graphs.mark_rect(self)
	#graphs.collider(rect)


func is_mouse_inside(rectangle: float = area_padding) -> bool:
	# padded hit area
	#if glob.is_consumed(self, "mouse"): return false
	if glob.get_display_mouse_position().y < glob.space_begin.y\
	or glob.get_display_mouse_position().x > glob.space_end.x: return false
	var top_left = rect.global_position - Vector2.ONE*rectangle
	var padded_size = rect.size + Vector2(rectangle, rectangle)*2
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
	output.merge(_get_info(), true)
	#var fields = graphs.FieldPack.new(output, 0<len(info_nested_fields), info_nested_fields)
	return output

func map_properties(pack: Dictionary):
	pass
	#for i in pack:
		

func map_property():
	pass

func _map_property():
	pass

var info_nested_fields: Array = []
func _get_info() -> Dictionary:
	return {}

func propagate(input_vals: Dictionary, sequential_branching: bool = false) -> void:
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
			graphs.next_frame_from(spline.origin, spline.tied_to)
			graphs.next_frame_propagate(spline.tied_to, connection_key, output_vals[out_key] if not graphs.reach_mode else spline.origin)
			

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

var take_offset_y: float = 0.0
var shadow: GraphShadow = null
func drag_start():
	if shadow:
		put_back()
	putting_back = 0.0
	take_offset_y = 0.0
	graphs.drag(self)
	shadow = graphs.shadow_rect.instantiate()
	add_child(shadow)
	shadow.position = rect.position + Vector2(0,12)
	shadow.outline = true
	shadow.extents = rect.size
	shadow.modulate.a = 0.0
	move_child(shadow, 0)

func drag_ended():
	putting_back_anchor = global_position.y
	if shadow:
		putting_back = 1.0
		hold_for_frame()
	graphs.stop_drag(self)
	#shadow_rect


func _stopped_processing():
	if glob.hovered_connection in input_key_by_conn:
		glob.hovered_connection = null
	glob.reset_menu_type(self, &"edit_graph")
	glob.un_occupy(self, &"graph")
	drag_ended()
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
	for conn in output_key_by_conn:
		for i in conn.outputs.duplicate():
			conn.outputs[i].tied_to.detatch_spline(conn.outputs[i])
			conn.end_spline(i)
	for conn in input_key_by_conn:
		var dup =  conn.inputs.duplicate()
		for i in dup:
			conn.detatch_spline(i)
			i.origin.end_spline(dup[i])
	queue_free()



func _size_changed(): # virtual
	pass

var changed_size_frame: bool = true
func size_changed():
	changed_size_frame = true
	_size_changed()

var graph_id: int = 0

func _init() -> void:
	graph_id = randi_range(0,99999999)

func _dragged():
	pass

func _proceed_hold() -> bool:
	return false

var exist_ticks: int = 0
var putting_back: float = 0.0
var putting_back_anchor: float = 0.0
func put_back():
	if is_instance_valid(shadow):
		shadow.queue_free()
	putting_back = 0.0; global_position.y = putting_back_anchor - take_offset_y


func _process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	exist_ticks += 1
	if position != prev_graph_pos:
		reposition_conns()
	
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
	if putting_back > 0.1: 
		hold_for_frame()
		putting_back = lerp(putting_back, 0.0, delta * 15.0)
		shadow.modulate.a = putting_back
		reposition_splines()
		if putting_back < 0.1: 
			put_back()
			reposition_splines()
		else:
			global_position.y = lerp(putting_back_anchor - take_offset_y, putting_back_anchor, putting_back)
	
	var unp_inside = is_mouse_inside(0)
	#print( glob.get_occupied(&"menu"))
	if inside and glob.mouse_just_pressed and _can_drag() and (
		not glob.is_occupied(self, &"menu") and 
		not glob.is_occupied(self, &"graph") and 
		not glob.is_occupied(self, &"menu_inside") and 
		not glob.is_occupied(self, &"conn_active") and
		(not glob.splines_active or unp_inside) and
		not glob.is_occupied(self, &"dropout_inside") and
		conn_free) and not dragging:
		drag_start()
		dragging = true; attachement_position = global_position - get_global_mouse_position()
	
	if dragging:
		hold_for_frame()
		if not glob.mouse_pressed or (not unp_inside and glob.splines_active) or not _can_drag():
			dragging = false
			drag_ended()
		else:
			var vec = get_global_mouse_position() + attachement_position + Vector2(0, take_offset_y)
			take_offset_y = lerpf(take_offset_y, -4.0, delta*15.0)
			shadow.modulate.a = take_offset_y/ -4
			#graphs.mark_rect(self)
			#vec = graphs.can_move(self, vec)
			global_position = global_position.lerp(vec, delta*40.0)
			#graphs.collider(rect)
		reposition_splines()
		_dragged()
	
	_after_process(delta)
	if changed_size_frame:
		hold_for_frame()
	changed_size_frame = false
	prev_graph_pos = position
	if _proceed_hold():
		hold_for_frame()

func is_valid() -> bool:
	return false if invalid_fields else true

var prev_graph_pos: Vector2 = position

func reposition_conns():
	pass

func reposition_splines():
	for input in _inputs:
		input.reposition_splines()
	for output in outputs:
		output.reposition_splines()

func _after_process(delta: float):
	pass

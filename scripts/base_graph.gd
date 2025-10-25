extends Control
class_name Graph

@export var base_dt: String = "1d"
@export var server_typename: StringName = ""
@onready var label = $ColorRect/root/Label
@onready var rect = $ColorRect
@export var z_space: int = 2
@export var is_input: bool = false
@export var is_head: bool = false

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

func get_first_descendants() -> Array[Graph]:
	var res: Dictionary[Graph, Variant] = {}
	for i in outputs:
		for j:int in i.outputs:
			if i.outputs[j].tied_to and is_instance_valid(i.outputs[j].tied_to.parent_graph):
				res[i.outputs[j].tied_to.parent_graph] = true
	var a: Array[Graph] = res.keys()
	return a

func get_first_ancestors() -> Array[Graph]:
	var res: Dictionary[Graph, Variant] = {}
	for i in input_keys:
		for j in input_keys[i].inputs:
			if is_instance_valid(j.origin.parent_graph):
				res[j.origin.parent_graph] = true
	var a: Array[Graph] = res.keys()
	return a

func get_descendant() -> Graph:
	var dess = get_first_descendants()
	return dess[0] if dess else null

func get_ancestor() -> Graph:
	var dess = get_first_ancestors()
	return dess[0] if dess else null

func request_save():
	_request_save()

func _request_save(): # virtual
	pass

@onready var cfg: Dictionary[StringName, Variant] = base_config.duplicate()
func update_config(update: Dictionary):
	cfg.merge(update, true)
	for field in update:
		_config_field(field, update[field])
	check_valid(update)

func has_config_subfield(query: String) -> bool:
	var splt = query.split("/")
	return cfg.has(splt[0]) and cfg[splt[0]].has(splt[1])

func update_config_subfield(update: Dictionary):
	for field in update:
		if !cfg.has(field): continue
		cfg[field].merge(update[field], true)
		for subfield in update[field]:
			_config_field(field + "/" + subfield, update[field][subfield])
	check_valid(update)

func get_config_dict() -> Dictionary:
	return cfg.duplicate()

func _config_field(field: StringName, value: Variant):
	pass

func _layout_size() -> Vector2:
	return rect.size

func llm_map(pack: Dictionary):
	_llm_map(pack)

#func llm_property(name: String) -> :
	#pass

func _llm_map(pack: Dictionary):
	if not pack: return
	if len(base_config) == 1:
		update_config({base_config.keys()[0]: pack.values()[0]})
		if pack.values()[0] is Dictionary:
			update_config_subfield({base_config.keys()[0]: pack.values()[0]})
	else:
		update_config(pack)
		for f in pack:
			if pack[f] is Dictionary:
				update_config_subfield({f: pack[f]})

func animate(delta: float):
	if graph_flags & Flags.NEW:
		if exist_time < 1.0: hold_for_frame(); reposition_splines()
		_new_animate(delta)

func _after_ready():
	pass




func ensure_input_has_context(n: Graph) -> void:
	if not is_instance_valid(n) or not n.is_input:
		return
	if n.root_context_id == 0:
		n.root_context_id = _new_context_id()
	if n.context_id == 0:
		n.context_id = n.root_context_id



func _set_subgraph_context(sub_id: int, ctx: int) -> void:
	if ctx == 0 or not _subgraph_registry.has(sub_id): return
	for node in _subgraph_registry[sub_id]:
		if is_instance_valid(node):
			node.context_id = ctx


func collect_component_nodes(root: Graph) -> Array:
	var res: Array = []
	var sid = root.subgraph_id
	if sid != 0 and _subgraph_registry.has(sid) and not _subgraph_registry[sid].is_empty():
		collect_branch_nodes(root, res, sid)
	else:
		res.append(root)
	return res



func just_connected(who: Connection, to: Connection):
	var a: Graph = who.parent_graph
	var b: Graph = to.parent_graph

	ensure_input_has_context(a)
	ensure_input_has_context(b)
	var nodes_a: Array = collect_component_nodes(a)
	var nodes_b: Array = collect_component_nodes(b)

	var ctx_a: int = 0
	var ctx_b: int = 0
	if not nodes_a.is_empty() and is_instance_valid(nodes_a[0]):
		ctx_a = nodes_a[0].context_id
	if not nodes_b.is_empty() and is_instance_valid(nodes_b[0]):
		ctx_b = nodes_b[0].context_id

	var winning_ctx: int = 0

	if ctx_a != 0 and ctx_b == 0:
		winning_ctx = ctx_a
	elif ctx_b != 0 and ctx_a == 0:
		winning_ctx = ctx_b
	elif ctx_a != 0 and ctx_b != 0:
		var dominant_input: Graph = null
		if a.is_input:
			dominant_input = a
		elif b.is_input:
			dominant_input = b
		winning_ctx = _pick_context_for_merge(nodes_a, nodes_b, dominant_input)
	else:
		if a.is_input:
			ensure_input_has_context(a)
			winning_ctx = a.context_id
		elif b.is_input:
			ensure_input_has_context(b)
			winning_ctx = b.context_id
		else:
			winning_ctx = _new_context_id()

	if not a.subgraph_occupied and not b.subgraph_occupied:
		var new_id = _new_subgraph_id()
		a.propagate_subgraph(new_id)
		b.propagate_subgraph(new_id)
	elif a.subgraph_occupied and not b.subgraph_occupied:
		b.propagate_subgraph(a.subgraph_id)
	elif b.subgraph_occupied and not a.subgraph_occupied:
		a.propagate_subgraph(b.subgraph_id)
	elif a.subgraph_id != b.subgraph_id:
		_merge_subgraphs(a.subgraph_id, b.subgraph_id)

	var merged_sub: int = a.subgraph_id
	_set_subgraph_context(merged_sub, winning_ctx)

	graphs.update_dependencies()
	_just_connected(who, to)
	graphs.spline_connected.emit(who, to)



func _count_connected_nodes(start: Graph, visited = {}) -> int:
	if start in visited:
		return 0
	visited[start] = true
	var total = 1
	for n in start.get_first_ancestors() + start.get_first_descendants():
		if n.subgraph_id == start.subgraph_id:
			total += _count_connected_nodes(n, visited)
	return total



func _choose_context_owner(left: Graph, right: Graph) -> Graph:
	var left_count = _count_connected_nodes(left)
	var right_count = _count_connected_nodes(right)
	if left_count > right_count:
		return left
	elif right_count > left_count:
		return right
	return right



func _is_valid() -> bool:
	return true

func get_title() -> String:
	return $ColorRect/root/Label.text if $ColorRect/root/Label else server_typename

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


var subgraph_id: int = 0
var context_id: int = 0
var subgraph_occupied: bool = false

func just_attached(other_conn: Connection, my_conn: Connection):
	_just_attached(other_conn, my_conn)

func reload_config():
	update_config(cfg.duplicate())

func get_x():
	return _get_x()

func _get_x() -> Variant:
	return 0

func _is_suitable_conn(who: Connection, other: Connection) -> bool:
	return true

func _just_attached(other_conn: Connection, my_conn: Connection):
	pass

func deattaching(other_conn: Connection, my_conn: Connection):
	_deattaching(other_conn, my_conn)

func connecting(my_conn: Connection, other_conn: Connection):
	_connecting(my_conn, other_conn)




func _deattaching(other_conn: Connection, my_conn: Connection):
	pass

func just_disconnected(who: Connection, from: Connection):
	from.parent_graph.just_deattached(who, from)
	_just_disconnected(who, from)

	var a: Graph = who.parent_graph
	var b: Graph = from.parent_graph
	if is_instance_valid(a): a.mark_new_subgraph()
	if is_instance_valid(b): b.mark_new_subgraph()




func disconnecting(who: Connection, from: Connection):
	graphs.spline_disconnected.emit(who, from)
	#graphs.update_dependencies(who.parent_graph)
	from.parent_graph.deattaching(who, from)
	_disconnecting(who, from)

func _just_connected(who: Connection, to: Connection):pass
func _disconnecting(who: Connection, to: Connection):pass
func _connecting(who: Connection, to: Connection):pass
func _just_disconnected(who: Connection, from: Connection):pass

var virtual_inputs = {}

var virtual_outputs = {}

func add_connection(conn: Connection):
	#var input_nm = 
	if conn.dynamic: return
	if conn.virtual: 
		if conn.connection_type == Connection.INPUT:
			virtual_inputs[conn.hint] = conn
		else:
			virtual_outputs[conn.hint] = conn
		return
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
	if conn.dynamic:
		return
	if conn.virtual:
		if conn.connection_type == Connection.INPUT:
			virtual_inputs.erase(conn.hint)
		else:
			virtual_outputs.erase(conn.hint)
		return
			
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
	if _subgraph_registry.has(subgraph_id):
		var arr: Array = _subgraph_registry[subgraph_id]
		if self in arr:
			arr.erase(self)
			if arr.is_empty():
				Graph._subgraph_registry.erase(subgraph_id)
	graphs.remove(self)
	for i in graphs.where_am_i(self):
		graphs.uncache(self, i)
	glob.tags_1d.erase(llm_tag)



static var _subgraph_registry: Dictionary = {}

func register_in_subgraph(id: int) -> void:
	if not _subgraph_registry.has(id):
		_subgraph_registry[id] = []
	if not self in _subgraph_registry[id]:
		_subgraph_registry[id].append(self)

	subgraph_id = id
	subgraph_occupied = true

	if context_id == 0:
		context_id = id




func mark_new_subgraph() -> void:
	if any_input_upstream():
		return

	var old_sub = subgraph_id
	if not _subgraph_registry.has(old_sub):
		return

	var pre_nodes: Array = _subgraph_registry[old_sub].duplicate()
	if pre_nodes.is_empty():
		return
	var pre_context: int = pre_nodes[0].context_id

	var branch_a: Array = []
	collect_branch_nodes(self, branch_a, old_sub)

	if branch_a.is_empty() or branch_a.size() == pre_nodes.size():
		return

	var branch_b: Array = pre_nodes.duplicate()
	for n in branch_a:
		branch_b.erase(n)
	if branch_b.is_empty():
		return

	var root_a: Graph = branch_a[0]
	var root_b: Graph = branch_b[0]
	var winner: Graph = _context_policy(root_a, root_b, branch_a, branch_b)
	var winner_is_a = branch_a.has(winner)

	var new_sub = _new_subgraph_id()

	var new_context = _new_context_id()

	if winner_is_a:
		for n in branch_a:
			if not is_instance_valid(n): continue
			_subgraph_registry[old_sub].erase(n)
			n.register_in_subgraph(new_sub)
			n.context_id = pre_context
		for n in branch_b:
			if is_instance_valid(n):
				n.context_id = new_context
	else:
		for n in branch_a:
			if not is_instance_valid(n): continue
			_subgraph_registry[old_sub].erase(n)
			n.register_in_subgraph(new_sub)
			n.context_id = new_context

	_subgraph_registry[new_sub] = branch_a
	_subgraph_registry[old_sub] = branch_b




func _count_contexts(nodes: Array) -> Dictionary:
	var hist = {}
	for n in nodes:
		if not is_instance_valid(n): continue
		var c: int = n.context_id
		hist[c] = (hist.get(c, 0) + 1)
	return hist

func _pick_context_for_merge(nodes_a: Array, nodes_b: Array, dominant_input: Graph) -> int:
	var all = nodes_a.duplicate()
	all.append_array(nodes_b)
	var hist = _count_contexts(all)

	var winner_ctx = 0
	var winner_cnt = -1
	for c in hist.keys():
		var cnt: int = hist[c]
		if cnt > winner_cnt:
			winner_cnt = cnt
			winner_ctx = c

	if dominant_input and hist.has(dominant_input.root_context_id) and hist[dominant_input.root_context_id] == winner_cnt:
		winner_ctx = dominant_input.root_context_id

	return winner_ctx






func _reassign_subgraph_recursive(old_id: int, new_id: int, visited = {}):
	if self in visited:
		return
	visited[self] = true

	if _subgraph_registry.has(old_id):
		_subgraph_registry[old_id].erase(self)

	register_in_subgraph(new_id)
	subgraph_id = new_id

	for desc in get_first_descendants():
		if desc.subgraph_id == old_id:
			desc._reassign_subgraph_recursive(old_id, new_id, visited)
	for anc in get_first_ancestors():
		if anc.subgraph_id == old_id and not anc.is_input:
			anc._reassign_subgraph_recursive(old_id, new_id, visited)




func any_input_upstream(visited = {}) -> bool:
	if self in visited:
		return false
	visited[self] = true

	if is_input:
		return true

	for anc in get_first_ancestors():
		if anc.any_input_upstream(visited):
			return true

	return false


func propagate_subgraph(id: int, visited = {}):
	if self in visited:
		return
	visited[self] = true
	register_in_subgraph(id)

	if is_input:
		for desc in get_first_descendants():
			if desc.subgraph_id != id:
				desc.propagate_subgraph(id, visited)
	else:
		for anc in get_first_ancestors():
			if anc.subgraph_id != id:
				anc.propagate_subgraph(id, visited)
		for desc in get_first_descendants():
			if desc.subgraph_id != id:
				desc.propagate_subgraph(id, visited)


func _merge_subgraphs(a_id: int, b_id: int) -> void:
	if a_id == b_id: return
	if not _subgraph_registry.has(a_id) or not _subgraph_registry.has(b_id): return

	var a_nodes = _subgraph_registry[a_id]
	var b_nodes = _subgraph_registry[b_id]

	var a_ctx = a_nodes[0].context_id if not a_nodes.is_empty() else a_id

	for n in b_nodes:
		n.subgraph_id = a_id
		n.subgraph_occupied = true
		n.context_id = a_ctx
		if n not in a_nodes:
			a_nodes.append(n)

	_subgraph_registry[a_id] = a_nodes
	_subgraph_registry.erase(b_id)

	if not a_nodes.is_empty():
		a_nodes[0].propagate_subgraph(a_id)


var root_context_id: int = 0

func _new_subgraph_id() -> int:
	return randi_range(100000, 999999)

func _new_context_id() -> int:
	return randi_range(100000, 999999)


func _chain_incoming(cache: Dictionary):
	pass

func useful_properties() -> Dictionary:
	return _useful_properties()

func _useful_properties() -> Dictionary:
	return {}

func _ready() -> void:
	if not llm_tag:
		llm_tag = glob.get_llm_tag(self)
	position -= rect.position
	animate(0)
	#graphs.add(self)
	_after_ready()
	#graphs.mark_rect(self)
	if is_input and root_context_id == 0:
		root_context_id = _new_context_id()
		context_id = root_context_id

	#graphs.collider(rect)

func all_connections() -> Array[Connection]:
	var a: Array[Connection] = []
	for i in input_key_by_conn:
		a.append(i)
	for i in output_key_by_conn:
		a.append(i)
	return a



func _collect_inputs_in_subgraph(sub_id: int) -> Array:
	var res: Array = []
	if _subgraph_registry.has(sub_id):
		for n in _subgraph_registry[sub_id]:
			if is_instance_valid(n) and n.is_input:
				res.append(n)
	return res


func collect_branch_nodes(root: Graph, out: Array, old_id: int, visited = {}):
	if root in visited:
		return
	visited[root] = true
	out.append(root)
	for d in root.get_first_descendants():
		if d.subgraph_id == old_id:
			collect_branch_nodes(d, out, old_id, visited)
	for a in root.get_first_ancestors():
		if a.subgraph_id == old_id:
			collect_branch_nodes(a, out, old_id, visited)



func _recompute_context_for_subgraph(sub_id: int, dominant_input: Graph = null) -> void:
	if not _subgraph_registry.has(sub_id):
		return

	var winner: Graph = null
	if dominant_input and dominant_input.is_input and dominant_input.subgraph_id == sub_id:
		winner = dominant_input
	else:
		var inputs = _collect_inputs_in_subgraph(sub_id)
		if inputs.is_empty():
			return
		inputs.sort_custom(func(a, b): return a.root_context_id < b.root_context_id)
		winner = inputs[0]

	var ctx = winner.root_context_id
	for n in _subgraph_registry[sub_id]:
		if is_instance_valid(n):
			n.context_id = ctx


func _context_policy(a: Graph, b: Graph, a_nodes: Array, b_nodes: Array) -> Graph:
	if a_nodes.size() > b_nodes.size():
		return a
	if b_nodes.size() > a_nodes.size():
		return b
	var a_inputs = a_nodes.any(func(n): return n.is_input)
	var b_inputs = b_nodes.any(func(n): return n.is_input)
	if a_inputs and not b_inputs:
		return a
	if b_inputs and not a_inputs:
		return b
	return a






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
	var inputs = {}
	var outputs_ = {}
	for i in input_keys:
		inputs[input_keys[i].conn_id] = i
	for i in output_keys:
		var port = []
		for o in output_keys[i].outputs:
			port.append(output_keys[i].outputs[o].tied_to.conn_id)
		port.append(output_keys[i].conn_id)
		outputs_[i] = port
			#input_spline.
	var base = {
		"position": position,
		"cfg": cfg,
		"inputs": inputs,
		"outputs": outputs_,
		"created_with": get_meta("created_with"),
		"subgraph_id": subgraph_id,
		"context_id": context_id,
		"root_context_id": root_context_id,
		"subgraph_occupied": subgraph_occupied,
		"llm_tag": llm_tag,
	}
	base.merge(_get_info(), true)
	return base

var llm_tag: String = ""

func map_properties(pack: Dictionary, careful: bool = false):
	#for i in pack:
	#	if not i in 
	position = pack.position
	subgraph_id = pack.subgraph_id
	context_id = pack.context_id
	root_context_id = pack.root_context_id
	subgraph_occupied = pack.subgraph_occupied
	if not Graph._subgraph_registry.has(subgraph_id):
		Graph._subgraph_registry[subgraph_id] = []
	if not self in Graph._subgraph_registry[subgraph_id]:
		Graph._subgraph_registry[subgraph_id].append(self)
	if "llm_tag" in pack:
		glob.set_llm_tag(self, pack.llm_tag)
	update_config(pack.cfg)
	for f in pack.cfg:
		if pack.cfg[f] is Dictionary:
			update_config_subfield({f: pack.cfg[f]})
	_map_properties(pack)

static func get_ctx_groups() -> Dictionary:
	var ctx_groups: Dictionary = {}
	for sub_id in _subgraph_registry:
		for n in _subgraph_registry[sub_id]:
			if not is_instance_valid(n):
				continue
			var ctx = n.context_id
			if not ctx_groups.has(ctx):
				ctx_groups[ctx] = []
			ctx_groups[ctx].append(n)
	return ctx_groups

static func debug_print_contexts() -> void:
	var ctx_groups = get_ctx_groups()

	for ctx_id in ctx_groups.keys():
		var nodes = ctx_groups[ctx_id]
		print("Context %s (%d nodes):" % [str(ctx_id), nodes.size()])
		for n in nodes:
			var t = n.server_typename if n.server_typename != "" else n.get_class()
			var info = "%-12s  subgraph=%d  graph_id=%d  input=%s" % [
				t, n.subgraph_id, n.graph_id, str(n.is_input)
			]
			print(info)




func _map_properties(pack: Dictionary):
	pass
	#for i in pack:
		


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
	if glob.get_occupator() is Connection and glob.get_occupator() in output_key_by_conn:
		glob.reset_menu_type(glob.get_occupator(), "detatch")
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
	subgraph_id = randi_range(0,99999999)
	context_id = subgraph_id
	subgraph_occupied = false

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
		if not glob.mouse_pressed or (not unp_inside and glob.splines_active):
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
	for i in virtual_inputs:
		virtual_inputs[i].reposition_splines()
	for o in virtual_outputs:
		virtual_outputs[o].reposition_splines()

func _after_process(delta: float):
	pass

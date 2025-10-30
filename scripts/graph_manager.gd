extends Node2D


var storage: GraphStorage

var propagation_q = {}
var _propagated_from = {}
func next_frame_propagate(tied_to: Connection, key: int, value: Variant):
	propagation_q.get_or_add(tied_to, {}).get_or_add(key, []).append(value)

func next_frame_from(from: Connection, tied_to: Connection):
	_propagated_from.get_or_add(from, []).append(tied_to)

var gather_q = {}
var gather_tree = {}
func next_frame_gather(tied_to: Connection, key: int):
	pass
	#print(propagation_q)

func gather_cycle():
	pass


const csize: int = 10
var chunks: Dictionary[int, Dictionary] = {}
var colliders: Dictionary[ColorRect, Collider] = {}

class Collider:
	var size: Vector2
	var used_chunks: Dictionary
	var position: Vector2
	func _init(_size: Vector2):
		size = _size; used_chunks = {}; position = Vector2()

var dragged: Dictionary[Graph, Array] = {}

func drag(graph: Graph) -> void:
	var from = graph.get_index()
	var last = storage.get_child_count() - 1
	dragged[graph] = [graph.z_index, from]
	if from == last:
		return
	var kids = storage.get_children()
	var carry = graph.z_index
	for i in range(from + 1, kids.size()):
		var k = kids[i]
		if k is CanvasItem:
			var z = k.z_index
			k.z_index = carry
			carry = z
	graph.z_index = carry
	storage.move_child(graph, -1)

var shadow_rect = preload("res://scenes/graph_shadow.tscn")

func stop_drag(graph: Graph) -> void:
	dragged.erase(graph)

func pack64(x: int, y: int) -> int:
	return ((x & 0xFFFFFFFF) << 32) | (y & 0xFFFFFFFF)

func mark_rect(graph: Graph):
	var rect: ColorRect = graph.rect
	var chunk_dims = Vector2i(ceil(float(rect.size.x) / csize), ceil(float(rect.size.y) / csize))
	var init_chunk = Vector2i(rect.global_position / csize)
	if not colliders.has(rect): colliders[rect] = Collider.new(rect.size)
	var collider = colliders[rect]
	collider.position = graph.global_position
	
	var prev_used = collider.used_chunks
	var new_used = {}
	var overlapped_something: bool = false
	for i: int in chunk_dims.x*chunk_dims.y:
		var y: int = i / chunk_dims.x; var x: int = i % chunk_dims.x
		var index: int = pack64(x + init_chunk.x, y + init_chunk.y)
		chunks.get_or_add(index, {})[collider] = true
		prev_used.erase(index)
		new_used[index] = true
	for i in prev_used:
		chunks[i].erase(collider)
	collider.used_chunks = new_used
	
func can_move(graph: Graph, vec: Vector2) -> Vector2:
	return Vector2()
	
# deltas. Changes/adds/deletes of different types of things
const DELETE: int = 0; const ADD: int = 2


var conns_active = {}

class Deltas:
	var snapshot = null
	var iterable = null
	var dtype_snapshot: int
	func _init(_iterable, default):
		iterable = _iterable
		snapshot = default
		dtype_snapshot = -30

var delta_paths = {}
var delta_objects = {}
var owners_deltas = null
var deltas_between_owners = null

var prev_graphs: Dictionary[int, bool] = {}
func get_deltas() -> Dictionary:
	var object_adds = {}
	var object_deletes = {}
	var graph_adds = []
	var graph_deletes = []
	for g:int in _graphs:
		var graph = _graphs[g]
		var res = store_delta(graph)
		if res[0]:object_adds[g] = res[0]
		if res[1]:object_deletes[g] = res[1]
		if not g in prev_graphs:
			graph_adds.append(g)
		prev_graphs.erase(g)
	for prev_graph in prev_graphs:
		graph_deletes.append(prev_graph)
	prev_graphs = _graphs_ids.duplicate()
	return {"graph_adds": graph_adds, 
	"graph_deletes": graph_deletes, 
	"object_adds": object_adds,
	"object_deletes": object_deletes}

func store_delta(graph: Graph):
	var new_info: Dictionary = graph.get_info()
	var delta_paths = delta_paths.get_or_add(graph, {})
	var delta_objects = delta_objects.get_or_add(graph, {})
	var delta_roots = owners_deltas if typeof(owners_deltas) == TYPE_DICTIONARY else {}
	if typeof(delta_roots) != TYPE_DICTIONARY:
		delta_roots = {}
	owners_deltas = delta_roots

	var q = [[new_info, TYPE_DICTIONARY, ["origin"], false]]
	var globdelta = delta_roots.get(graph)
	if globdelta == null:
		var root_deltas = Deltas.new(new_info, {})
		q[0][3] = root_deltas
		delta_roots[graph] = root_deltas
	else:
		q[0][3] = globdelta

	var result_adds = {}
	var result_deletes = {}

	while q.size() > 0:
		var popped = q.pop_back()
		var cur_iterable = popped[0]
		var parent_dtype: int = popped[1]
		var path = popped[2]
		var deltas = popped[3]

		delta_objects[cur_iterable] = path

		if not delta_paths.has(path):
			delta_paths[path] = Deltas.new(cur_iterable, glob.list(parent_dtype))
			deltas = delta_paths[path]
		else:
			deltas = delta_paths[path]

		if deltas.dtype_snapshot != parent_dtype:
			result_adds.get_or_add(path, {})["__type__"] = parent_dtype
			deltas.dtype_snapshot = parent_dtype

		for key in cur_iterable if not (parent_dtype in glob.arrays) else len(cur_iterable):
			var value = cur_iterable[key]
			var dtype: int = typeof(value)
			if dtype in glob.iterables:
				var next_path = path.duplicate()
				next_path.append(key)
				q.append([value, dtype, next_path, false])
			else:
				var dict: bool = parent_dtype == TYPE_DICTIONARY
				if ((dict and (not deltas.snapshot.has(key) or deltas.snapshot[key] != value))
					or (!dict and (key >= len(deltas.snapshot) or deltas.snapshot[key] != value))):
					result_adds.get_or_add((path), {})[key] = value

		if deltas.snapshot:
			if parent_dtype == TYPE_DICTIONARY:
				for k in deltas.snapshot:
					if not cur_iterable.has(k):
						result_deletes.get_or_add((path), {})[k] = deltas.snapshot[k]
			else:
				var old_len = len(deltas.snapshot)
				var cur_len = len(cur_iterable)
				if old_len > cur_len:
					for i in range(cur_len, old_len):
						result_deletes.get_or_add((path), {})[i] = deltas.snapshot[i]

		deltas.snapshot = cur_iterable.duplicate()
	
	var pathed_adds = {}; var pathed_deletes = {}
	for i in result_adds:
		pathed_adds["/".join(i)] = result_adds[i]
	for i in result_deletes:
		pathed_deletes["/".join(i)] = result_deletes[i]
	
	return [pathed_adds, pathed_deletes]

var _graphs_ids: Dictionary[int, bool] = {}
var _graphs: Dictionary[int, Graph] = {}

var _graph_names = {}

func nodes_of_type(type: String) -> Dictionary:
	return _graph_names.get(type, {})

func add(graph: Graph):
	_graph_names.get_or_add(graph.server_typename, {})[graph] = true
	_graphs[graph.graph_id] = graph
	_graphs_ids[graph.graph_id] = true

func remove(graph: Graph):
	_graph_names.get(graph.server_typename, {}).erase(graph)
	_graphs.erase(graph.graph_id)
	_graphs_ids.erase(graph.graph_id)
	stop_drag(graph)

func get_by_id(graph_id: int) -> Graph:
	return _graphs.get(graph_id)

func attach_edge(from_conn: Connection, to_conn: Connection):
	pass

func remove_edge(from_conn: Connection, to_conn: Connection):
	pass

func validate_acyclic_edge(from_conn: Connection, to_conn: Connection) -> bool:
	if from_conn.parent_graph == to_conn.parent_graph:
		return false
	var reached: Array = [false]
	var _cycle_check = func(fc: Connection, tc: Connection, _branch_cache: Dictionary) -> void:
		#print(tc.parent_graph.graph_id, " ", from_conn.parent_graph.graph_id)
		if tc.parent_graph.graph_id == from_conn.parent_graph.graph_id:
			reached[0] = true
			#print(reached)
	reach(to_conn.parent_graph, _cycle_check)
	#print(reached)
	return not reached[0]


func _reach_input(from: Graph, custom: String = "InputNode"):
	if from.server_typename == custom: return from
	var next_frame = {from: true}
	while true:
		var new_frame = {}
		for i: Graph in next_frame:
			if i.server_typename == custom: return i
			for conn in i._inputs:
				for spline in conn.inputs:
					new_frame[spline.origin.parent_graph] = true
		if new_frame.is_empty(): break
		next_frame = new_frame
	return null

var _conn_spaces: Dictionary[StringName, Dictionary] = {}

func _ensure_conn_space(ns: StringName) -> Dictionary:
	return _conn_spaces.get_or_add(ns, {
		"candidates": [],    # Array[Connection]
		"chosen": null,      # Connection (this frame)
		"next_chosen": null, # Connection (exposed next frame)
	})

func register_conn_candidate(conn: Connection, ns: StringName = "activate") -> void:
	# Skip invalids early
	if not is_instance_valid(conn):
		return
	_ensure_conn_space(ns)["candidates"].append(conn)

func _distance_key(c: Connection, mouse_pos: Vector2) -> Array:
	# Prefer actual plug point for distance
	var p = c.get_origin()
	var d2 = mouse_pos.distance_squared_to(p)
	# Tiebreakers: higher z on top (CanvasItem); then smaller rect
	var zi := (c as CanvasItem).z_index if c is CanvasItem else 0
	var rect := c.get_global_rect()
	var area := rect.size.x * rect.size.y
	# Sort ascending by d2, then descending by z, then ascending by area
	return [d2, -zi, area]

func choose_conn_under_mouse(ns: StringName = "activate") -> Connection:
	var space = _ensure_conn_space(ns)
	var candidates: Array = space["candidates"]
	var n := candidates.size()
	if n == 0:
		space["chosen"] = null
		return null

	var mouse_pos = get_global_mouse_position()

	# Deduplicate candidates that may have been added twice in the same frame
	var uniq := {}
	for c in candidates:
		if is_instance_valid(c):
			uniq[c] = true

	var best: Connection = null
	var best_key: Array = []
	for c in uniq.keys():
		# Optional namespace filtering: only INPUTs are hover targets
		if ns == "hover" and c.connection_type != Connection.INPUT:
			continue
		var key = _distance_key(c, mouse_pos)
		if best == null or key < best_key:
			best = c
			best_key = key

	space["chosen"] = best
	return best

func clear_conn_candidates(ns: StringName = "activate") -> void:
	var space = _ensure_conn_space(ns)
	space["candidates"].clear()
	space["chosen"] = null

func chosen_conn(ns: StringName = "activate") -> Connection:
	return _ensure_conn_space(ns)["next_chosen"]

func advance_conn_frame(ns: StringName = "activate") -> void:
	var space = _ensure_conn_space(ns)
	space["next_chosen"] = space["chosen"]
	clear_conn_candidates(ns)



var key_to_graph: Dictionary[int, Graph] = {}
var graph_to_key: Dictionary[Graph, int] = {}


var connection_ids: Dictionary[int, Connection] = {}

func reg_conn(who: Connection):
	connection_ids[who.conn_id] = who

func del_conn(who: Connection):
	connection_ids.erase(who.conn_id)

#func get_info() -> Dictionary:
	#var inputs = {}
	#var outputs_ = {}
	#for i in input_keys:
		#inputs[input_keys[i].conn_id] = i
	#for i in output_keys:
		#var port = [output_keys[i].conn_id]
		#for o in output_keys[i].outputs:
			#port.append(output_keys[i].outputs[o].tied_to.conn_id)
		#outputs_[i] = port
			##input_spline.
	#var base = {
		#"position": position,
		#"inputs": inputs,
		#"outputs": outputs_,
		#"created_with": get_meta("created_with")
	#}

var caches = {}
var bound = {}

func bind_cache(who: Graph, name: String, whose: Graph = null):
	if whose: name = str(whose.graph_id) + name
	bound.get_or_add(who, {})[name] = true
	caches.get_or_add(name, {})[who] = true

func where_am_i(who: Graph):
	return bound.get(who, {}).keys()

func uncache(who: Graph, name: String, whose: Graph = null):
	if whose: name = str(whose.graph_id) + name
	bound.get_or_add(who, {}).erase(name)
	caches.get_or_add(name, {}).erase(who)

func get_cache(name: String, whose: Graph = null):
	if whose: name = str(whose.graph_id) + name
	return caches.get(name, {})

func load_graph(state: Dictionary, reg: Dictionary):
	z_count = RenderingServer.CANVAS_ITEM_Z_MIN
	var chain = glob.base_node.importance_chain
	var type_layers = {}
	var sequence = {}
	for i in len(chain):
		type_layers[chain[i]] = i
		sequence[i] = []

		
	for id in state:
		var pack = state[id]
		pack.id = id
		sequence[type_layers[pack.created_with]].append(pack)
	
	var edges = {} # from: [to1, to2, ...]
	for layer in sequence:
		for pack in sequence[layer]:
			var graph: Graph = get_graph(pack.created_with, Graph.Flags.NONE, pack.id)
			graph.position = pack.position
			graph.set_meta("pack", pack)
			for port_key in pack.outputs:
				var id = pack.outputs[port_key][-1]
				graph.output_keys[port_key].update_conn_id(id)
				pack.outputs[port_key].remove_at(-1)
				edges[id] = pack.outputs[port_key]
			for port_id in pack.inputs:
				graph.input_keys[pack.inputs[port_id]].update_conn_id(port_id)
	await get_tree().process_frame
	for conn_id in edges:
		for other_conn_id in edges[conn_id]:
			connection_ids[conn_id].connect_to(connection_ids[other_conn_id], true)
	
	Graph._subgraph_registry.clear()
	for g in _graphs:
		_graphs[g].map_properties(_graphs[g].get_meta("pack", {}))
		_graphs[g].hold_for_frame.call_deferred()
	
	for sub_id in reg:
		Graph._subgraph_registry[int(sub_id)] = []
		for gid in reg[sub_id]:
			for node_id in graphs._graphs:
				if graphs._graphs[node_id].graph_id == gid:
					Graph._subgraph_registry[int(sub_id)].append(graphs._graphs[node_id])
	#Graph.debug_print_contexts()



func delete_all():
	Graph._subgraph_registry.clear()
	for graph in _graphs.keys():
		_graphs[graph].delete()
	await get_tree().process_frame
	return true
	

func get_project_data() -> Dictionary:
	var data = {"graphs": {}, "lua": {}}
	for i in _graphs:
		data["graphs"][i] = _graphs[i].get_info()
	for i in glob.tree_windows["env"].get_texts():
		pass
	return data


func save():
	pass
	#var bytes = JSON.stringify(get_project_data()).to_utf8_buffer()
	#var compressed = bytes.compress(FileAccess.CompressionMode.COMPRESSION_ZSTD)
	#print(len(compressed), " ", len(bytes))
	
	# TODO: make actual delta transfer

	#var deltas = get_deltas()
	#var pull_nodes = deltas["graph_adds"]
	#deltas.erase("graph_adds")
	#var dict = {
		#"pull_nodes": pull_nodes,
		#"deltas": Marshalls.raw_to_base64(var_to_bytes(deltas))
	#}
	#var bytes = JSON.stringify(dict).to_utf8_buffer()
	#web.POST("save", bytes.compress(FileAccess.CompressionMode.COMPRESSION_ZSTD), true)

var _training_head: Graph = null
var _train_origin_graph: Graph = null
var _input_origin_graph: Graph = null

func get_abstract(graph: Graph, emit = {}) -> Dictionary:
	return {
		"type": graph.server_typename,
		"props": graph.useful_properties(),
		"emit": emit
	}

func reg_gather(gather_into, expect: Dictionary) -> Dictionary:
	var result = {}
	for conn: Connection in gather_into:
		if !conn.outputs:
			continue
		var emit = {}
		for node_conn: Connection in conn.parent_graph.outputs:
			emit[node_conn.server_name] = {}
		for i in conn.outputs:
			var tgt_conn: Connection = conn.outputs[i].tied_to
			var tgt_name = tgt_conn.server_name
			var tgt_id = tgt_conn.parent_graph.graph_id
			for node_conn: Connection in conn.parent_graph.outputs:
				emit[node_conn.server_name].get_or_add(tgt_id, []).append(tgt_name)
			expect.get_or_add(tgt_id, {}).get_or_add(tgt_name, 0)
			expect[tgt_id][tgt_name] += 1
		result[conn.parent_graph.graph_id] = get_abstract(conn.parent_graph, emit)
	return result

func propagate_cycle(gather: Variant=null) -> void:
	if not propagation_q:
		return
	var dup = propagation_q
	propagation_q = {}
	for conn: Connection in dup:
		if gather != null:
			if gather in glob.arrays:
				gather.append(conn)
			else:
				gather[conn] = true
		conn.parent_graph.propagate(dup[conn])



func _relationship():
	pass


func _chain(from: Connection, to: Connection, branch_cache: Dictionary):
	var chain = branch_cache.get_or_add("chain", [])
	chain.append(from.parent_graph)
	to.parent_graph._chain_incoming(branch_cache)
	#if type.server_typename == "NeuronLayer": type = type.layer_name
	#else: type = type.server_typename
	#var starts_input: bool = chain[0].server_typename == "InputNode"
	#if type == "Conv2D":
		#var broke: bool = false
		#if len(chain) <= 1 or !starts_input:
			#broke = true
		#else:
			#for i: Graph in chain:
				#if not i.server_typename in types_2d:
					#broke = true; break
		#if not broke:
			#to.parent_graph.neurons_fixed = true
			#to.parent_graph.push_neuron_count(
			#chain[0].image_dims.x * chain[0].image_dims.y)
		#else:
			#to.parent_graph.neurons_fixed = false



func update_dependencies(from: Graph = null):
	if is_instance_valid(from):
		reach(from, _chain)
	elif is_instance_valid(_input_origin_graph):
		reach(_input_origin_graph, _chain)


func def_call(from: Connection, to: Connection, branch_cache: Dictionary):
	pass
	#branch_cache.get_or_add("a", []).append(from.parent_graph.server_typename)
	#print(branch_cache)
	#print(from.parent_graph.server_typename, " ", to.parent_graph.server_typename)

var reach_mode: bool = false



var input_graph_names: Dictionary[String, Graph] = {}
var input_graphs: Dictionary[Graph, String] = {}
func add_input_graph_name(who: Graph, name_: String):
	input_graph_names[name_] = who
	input_graphs[who] = name_

func has_named_input_graph(who: Graph) -> bool:
	return who in input_graphs

func input_graph_name_exists(strr: String) -> bool:
	return strr in input_graph_names

func rename_input_graph(who: Graph, name_: String):
	if not who in input_graphs: return
	input_graph_names.erase(input_graphs[who])
	input_graphs[who] = name_
	input_graph_names[name_] = who

func get_input_graph_by_name(name_: String):
	return input_graph_names.get(name_)

signal model_updated(who: String)

func get_input_name_by_graph(input: Graph):
	return input_graphs.get(input)

func forget_input_graph_name(name_: String):
	if name_ in input_graph_names:
		input_graphs.erase(input_graph_names[name_])
		input_graph_names.erase(name_)

func forget_input_graph(who: Graph):
	if who in input_graphs:
		input_graph_names.erase(input_graphs[who])
		input_graphs.erase(who)




signal spline_connected(from_conn: Connection, to_conn: Connection)
signal spline_disconnected(from_conn: Connection, to_conn: Connection)


func simple_reach(from_graph: Graph) -> Dictionary:
	var gathered = {}
	var callable = func(from: Connection, to: Connection, branch_cache: Dictionary):
		gathered[to.parent_graph] = true
		gathered[from.parent_graph] = true
	reach(from_graph, callable)
	return gathered



func reach(from_graph: Graph, call: Callable = def_call):
	reach_mode = true
	
	var node_caches = {}
	node_caches[from_graph] = {}
	from_graph._chain_incoming(node_caches[from_graph])
	
	var visited_graphs = {}

	var gather = func(iter):
		var page = {}
		for me: Connection in iter:
			var parent = me.parent_graph
			if visited_graphs.has(parent):
				continue
			visited_graphs[parent] = true

			if me.connection_type == Connection.OUTPUT:
				var from_cache = node_caches.get(parent, {})
				for other in iter[me]:
					var branch_cache = from_cache.duplicate(true)
					node_caches[other.parent_graph] = branch_cache
					call.call(me, other, branch_cache)
			page[parent] = true
		return page

	from_graph.propagate({})
	var gathered = []
	var prev_q = {}
	gathered.append(gather.call(_propagated_from))
	while _propagated_from:
		_propagated_from.clear()
		prev_q = propagation_q
		propagate_cycle()
		gathered.append(gather.call(_propagated_from))
	gathered[-1] = gather.call(prev_q)
	reach_mode = false


func is_node(who: Graph, typename: String) -> bool:
	return who.server_typename == typename

func is_nodes(who: Graph, ...typenames: Array) -> bool:
	for typename in typenames:
		if who.server_typename == typename:
			return true
	return false

func get_syntax_tree(input) -> Dictionary:
	var gathered = {}
	var expect = {}
	var index_counter: int = 0
	if not input: return {}
	
	input.propagate({})
	gathered[str(index_counter)] = reg_gather(input.outputs, expect)

	var prev_q = {}
	while _propagated_from:
		index_counter += 1
		_propagated_from.clear()
		prev_q = propagation_q
		propagate_cycle()
		gathered[str(index_counter)] = reg_gather(_propagated_from, expect)
		for conn in prev_q:
			var g: Graph = conn.parent_graph
			if not gathered[str(index_counter)].has(g.graph_id):
				gathered[str(index_counter)][g.graph_id] = get_abstract(g)
	return {
		"pages": gathered,
		"expect": expect,
		"train": 1
	}

func get_llm_summary():
	#var summary = {}
	var summary = {"nodes": {}, "edges": []}
	for i in _graphs:
		var node: Graph = _graphs[i]
		var outputs = {}
		for j in node.outputs:
			var output_splines = []
			for o in j.outputs:
				output_splines.append({"to": j.outputs[o].tied_to.parent_graph.llm_tag, "port": j.outputs[o].tied_to.hint})
				summary["edges"].append({"from": 
					{"port": j.outputs[o].origin.hint, "tag": j.outputs[o].origin.parent_graph.llm_tag},
					"to":
					{"port": j.outputs[o].tied_to.hint, "tag": j.outputs[o].tied_to.parent_graph.llm_tag}})
			outputs[j.hint] = output_splines
		summary["nodes"][node.llm_tag] = {"type": glob.llm_name_unmapping[node.get_meta("created_with")],
		"config": node.cfg, "outputs": outputs}
	return summary
	#print(JSON.stringify(summary, "\t"))

#func run_request():
	#save()
	#var syntax_tree = get_syntax_tree(_input_origin_graph)
	#await web.POST("train", compress_dict_gzip({"train": 0, 
	#"session": "neriqward", 
	#"graph": syntax_tree}), true)


func gload(path: String):
	var loaded = load(path)
	loaded.set_meta("_loaded_with", path)
	return loaded

var graph_types = {
	"io": gload("res://scenes/io_graph.tscn"),
	"neuron": gload("res://scenes/neuron.tscn"),
	"loop": gload("res://scenes/loop.tscn"),
	"base": gload("res://scenes/base_graph.tscn"),
	"input": gload("res://scenes/input_graph.tscn"),
	"layer": gload("res://scenes/layer.tscn"),
	"train_input": gload("res://scenes/train_input.tscn"),
	"softmax": gload("res://scenes/softmax.tscn"),
	"reshape2d": gload("res://scenes/reshape.tscn"),
	"flatten": gload("res://scenes/flatten.tscn"),
	"conv2d": gload("res://scenes/conv2d.tscn"),
	"maxpool": gload("res://scenes/maxpool.tscn"),
	"classifier": gload("res://scenes/classifier_graph.tscn"),
	"train_begin": gload("res://scenes/train_begin.tscn"),
	"model_name": gload("res://scenes/netname.tscn"),
	"dataset": gload("res://scenes/dataset.tscn"),
	"run_model": gload("res://scenes/run_model.tscn"),
	"augment_tf": gload("res://scenes/augment_transform.tscn"),
	"output_map": gload("res://scenes/branch_mapping.tscn"),
	"input_1d": gload("res://scenes/input_1d.tscn"),
	"lua_env": gload("res://scenes/env_tag.tscn"),
	"train_rl": gload("res://scenes/train_rl.tscn"),
}

var z_count: int = RenderingServer.CANVAS_ITEM_Z_MIN
func get_graph(typename = "base", flags = Graph.Flags.NONE, id: int = 0, tag: String = "") -> Graph:
	var type = graph_types[typename]
	var new = type.instantiate()
	new.set_meta("created_with", typename)
	if id:
		new.graph_id = id
	new.graph_flags = flags
	var last = storage.get_child(-1) if storage.get_child_count() else null
	z_count += last.z_space if last else 0
	new.z_index = z_count
	storage.add_child(new)
	add(new)
	if tag:
		glob.set_llm_tag(new, tag)
	return new

var graph_layers: Dictionary[int, CanvasLayer] = {}
func _ready():
	pass
	#print(await web.send_get("test"))


func is_layer(g: Graph, layer: StringName):
	return g.server_typename == "NeuronLayer" and g.layer_name == layer

func push_1d(columns: int, who: Graph):
	var target = who.get_first_descendants()
	#print(columns)
	#print(target)
	for i in target:
		#print(i.server_typename)
		if is_node(i, "Reshape2D"):
			i.reload_config()
		if is_node(i, "SoftmaxNode"):
			#print("Ff")
			i.upd(columns)
		if is_node(i, "Flatten"):
			push_1d(columns, i)
		if is_node(i, "ClassifierNode"):
			i.push_result_meta({"datatype": "1d", "x": columns})

func push_2d(columns: int, rows: int, target):
	#print("repush..")
	if !glob.is_iterable(target): target = [target]
	for i in target:
		if is_layer(i, "Conv2D"):
			i.update_grid(columns, rows)
		if is_layer(i, "MaxPool2D"):
			i.update_grid(columns, rows)
		if i.server_typename == "Flatten":
			i.set_count(rows * columns)

func unpush_2d(target):
	if !glob.is_iterable(target): target = [target]
	for i in target:
		if is_layer(i, "Conv2D"):
			i.update_grid(0, 0)
		if is_layer(i, "MaxPool2D"):
			i.update_grid(0, 0)

var pos_cache: Dictionary = {}
var last_frame_visible: bool = true
func _process(delta: float) -> void:
	#if glob.space_just_pressed:
		#print(get_llm_summary())
	# 1) Pick winners for both namespaces from last frame's candidates
	choose_conn_under_mouse("activate")
	choose_conn_under_mouse("hover")

	# 2) Publish hover winner globally (single source of truth)
	var prev := glob.hovered_connection
	var now  := chosen_conn("hover")
	if prev != now:
		glob.hovered_connection_changed = true
		# Make sure the previously hovered connection's graph keeps processing
		if is_instance_valid(prev) and is_instance_valid(prev.parent_graph):
			prev.parent_graph.hold_for_frame()
	glob.hovered_connection = now
	# Also keep the *current* hovered graph alive while it lerps brighter
	if is_instance_valid(now) and is_instance_valid(now.parent_graph):
		now.parent_graph.hold_for_frame()

	# 3) Expose winners and clear candidate arrays
	advance_conn_frame("activate")
	advance_conn_frame("hover")
	
	if not last_frame_visible: 
		last_frame_visible = visible; return
	last_frame_visible = visible
	
	var vp = Rect2(Vector2.ZERO, glob.window_size)
	var dc = 0

	for graph: Graph in storage.get_children():
		#print("F")
		var r = graph.rect
		
		var vis: bool = visible
		graph.hold_process = graph.hold_process or graph.exist_time < 1.0
		if not graph.dragging and visible:
			if graph.hold_process:
				vis = true
			else:
				var rect = r.get_global_rect()
				var gp = rect.position - Vector2(10,10)
				var s  = rect.size + Vector2(20,20)

				var p0 = glob.world_to_screen(gp)
				var p1 = glob.world_to_screen(gp + Vector2(s.x, 0.0))
				var p2 = glob.world_to_screen(gp + Vector2(0.0, s.y))
				var p3 = glob.world_to_screen(gp + s)

				var minx = min(p0.x, p1.x, p2.x, p3.x)
				var maxx = max(p0.x, p1.x, p2.x, p3.x)
				var miny = min(p0.y, p1.y, p2.y, p3.y)
				var maxy = max(p0.y, p1.y, p2.y, p3.y)
				var rect_screen = Rect2(Vector2(minx, miny), Vector2(maxx - minx, maxy - miny))

				vis = rect_screen.intersects(vp)
			#print(graph.get_title())
		#elif graph.hold_process:
		#	print("..")
		
		var force_held: bool = false
		if !visible and last_frame_visible: force_held = true
		if visible and (vis or graph.hold_process or graph.dragging or graph.active_output_connections or graph.hold_process):
			var inside = graph.is_mouse_inside()
			var padded_inside = (Rect2(graph.rect.global_position-Vector2(50,50), 
			graph.rect.size * graph.rect.scale * graph.scale + 2*Vector2(50,50)).has_point(get_global_mouse_position()))
			if not ui.active_splashed() and (graph.hold_process or padded_inside or graph.active_output_connections):
				graph.process_mode = PROCESS_MODE_INHERIT
				#print(graph.hold_process)
				if inside:
					force_held = true
					graph.hold_for_frame()
			else:
				if graph.process_mode != PROCESS_MODE_DISABLED:
					#print("GJKGJ")
		#			print(graph.get_title())
					graph.stopped_processing()
				graph.process_mode = PROCESS_MODE_DISABLED
			graph.show()
		elif not graph.hold_process:
			#print("h..")
			graph.hide()
			if graph.process_mode != PROCESS_MODE_DISABLED:
			#	print("GJKGJ")
				graph.stopped_processing()
			graph.process_mode = PROCESS_MODE_DISABLED

		if graph.hold_process and !force_held:
			graph.hold_process = false
		
		dc += int(graph.process_mode != PROCESS_MODE_DISABLED)
	#print(dc)

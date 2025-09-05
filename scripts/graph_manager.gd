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
	
	return [result_adds, result_deletes]

var _graphs_ids: Dictionary[int, bool] = {}
var _graphs: Dictionary[int, Graph] = {}
func add(graph: Graph):
	_graphs[graph.graph_id] = graph
	_graphs_ids[graph.graph_id] = true

func remove(graph: Graph):
	_graphs.erase(graph.graph_id)
	_graphs_ids.erase(graph.graph_id)

func attach_edge(from_conn: Connection, to_conn: Connection):
	pass

func remove_edge(from_conn: Connection, to_conn: Connection):
	pass

func validate_acyclic_edge(from_conn: Connection, to_conn: Connection):
	return true

func compress_dict_gzip(dict: Dictionary):
	var jsonified = JSON.new().stringify(dict)
	var bytes = jsonified.to_ascii_buffer()
	return bytes.compress(FileAccess.CompressionMode.COMPRESSION_GZIP)

func save():
	var compressed = compress_dict_gzip(get_deltas())

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

func reach(from_graph: Graph, call: Callable = def_call):
	reach_mode = true
	
	var node_caches = {}
	node_caches[from_graph] = {}
	from_graph._chain_incoming(node_caches[from_graph])
	
	var gather = func(iter):
		var page = {}
		for me: Connection in iter:
			if me.connection_type == Connection.OUTPUT:
				var from_cache = node_caches.get(me.parent_graph, {})
				for other in iter[me]:
					var branch_cache = from_cache.duplicate(true)
					node_caches[other.parent_graph] = branch_cache
					call.call(me, other, branch_cache)
			page[me.parent_graph] = true
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

func run_request():
	save()
	var syntax_tree = get_syntax_tree(_input_origin_graph)
	await web.POST("train", compress_dict_gzip({"train": 0, "session": "neriqward", "graph": syntax_tree}), true)


var graph_types = {
	"io": preload("res://scenes/io_graph.tscn"),
	"neuron": preload("res://scenes/neuron.tscn"),
	"loop": preload("res://scenes/loop.tscn"),
	"base": preload("res://scenes/base_graph.tscn"),
	"input": preload("res://scenes/input_graph.tscn"),
	"layer": preload("res://scenes/layer.tscn"),
	"train_input": preload("res://scenes/train_input.tscn"),
	"softmax": preload("res://scenes/softmax.tscn"),
	"reshape2d": preload("res://scenes/reshape.tscn"),
	"flatten": preload("res://scenes/flatten.tscn"),
	"conv2d": preload("res://scenes/conv2d.tscn"),
}

var z_count: int = RenderingServer.CANVAS_ITEM_Z_MIN
func get_graph(type = graph_types.base, flags = Graph.Flags.NONE) -> Graph:
	var new = type.instantiate()
	new.graph_flags = flags
	var last = storage.get_child(-1)
	z_count += last.z_space if last else 0
	new.z_index = z_count
	storage.add_child(new)
	add(new)
	return new

var graph_layers: Dictionary[int, CanvasLayer] = {}
func _ready():
	pass
	#print(await web.send_get("test"))


func is_layer(g: Graph, layer: StringName):
	return g.server_typename == "NeuronLayer" and g.layer_name == layer


func push_2d(columns: int, rows: int, target):
	if !glob.is_iterable(target): target = [target]
	for i in target:
		if is_layer(i, "Conv2D"):
			i.update_grid(columns, rows)
		if i.server_typename == "Flatten":
			i.set_count(rows * columns)

var pos_cache: Dictionary = {}
func _process(delta: float) -> void:
	var vp = Rect2(Vector2.ZERO, glob.window_size)
	var dc = 0
	if Input.is_action_just_pressed("ui_accept"):
		#update_dependencies()
		run_request()

	for graph: Graph in storage.get_children():
		var r = graph.rect
		
		var vis: bool = false
		if not graph.dragging:
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
		
		var force_held: bool = false
		if vis or graph.hold_process or graph.dragging or graph.active_output_connections:
			var inside = graph.is_mouse_inside()
			var padded_inside = (Rect2(graph.rect.global_position-Vector2(50,50), 
			graph.rect.size * graph.rect.scale * graph.scale + 2*Vector2(50,50)).has_point(get_global_mouse_position()))
			if graph.hold_process or padded_inside or graph.active_output_connections:
				graph.process_mode = PROCESS_MODE_ALWAYS
				
				if inside:
					force_held = true
					graph.hold_for_frame()
			else:
				if graph.process_mode != PROCESS_MODE_DISABLED:
					#print("GJKGJ")
					graph._stopped_processing()
				graph.process_mode = PROCESS_MODE_DISABLED
			graph.show()
		else:
			graph.hide()
			if graph.process_mode != PROCESS_MODE_DISABLED:
			#	print("GJKGJ")
				graph._stopped_processing()
			graph.process_mode = PROCESS_MODE_DISABLED

		if graph.hold_process and !force_held:
			graph.hold_process = false
		
		dc += int(graph.process_mode != PROCESS_MODE_DISABLED)

extends Node2D


var storage: GraphStorage

var propagation_q = {}
func next_frame_propagate(tied_to: Connection, key: int, value: Variant):
	propagation_q.get_or_add(tied_to, {}).get_or_add(key, []).append(value)

var gather_q = {}
var gather_tree = {}
func next_frame_gather(tied_to: Connection, key: int):
	pass
	#print(propagation_q)

func gather_cycle():
	pass

func propagate_cycle():
	if not propagation_q: return
	var dup = propagation_q
	propagation_q = {}
	#tree = {}
	for conn: Connection in dup:
		conn.parent_graph.propagate(dup[conn])

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
	func _init(_iterable, default):
		iterable = _iterable
		snapshot = default

var _graph_delta_paths = {}
var _graph_delta_objects = {}
var _graph_deltas = null

func store_delta(graph: Graph):
	var new_info: Dictionary = graph.get_info()
	var delta_paths = _graph_delta_paths.get_or_add(graph, {})
	var delta_objects = _graph_delta_objects.get_or_add(graph, {})
	var graph_deltas = _graph_deltas if typeof(_graph_deltas) == TYPE_DICTIONARY else {}
	if typeof(graph_deltas) != TYPE_DICTIONARY:
		graph_deltas = {}
	_graph_deltas = graph_deltas

	var q = [[new_info, TYPE_DICTIONARY, ["origin"], false]]

	var globdelta = graph_deltas.get(graph)
	if globdelta == null:
		var root_deltas = Deltas.new(new_info, {})
		q[0][3] = root_deltas
		graph_deltas[graph] = root_deltas
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

		for key in cur_iterable if not (parent_dtype in glob.arrays) else len(cur_iterable):
			var value = cur_iterable[key]
			var dtype: int = typeof(value)

			if dtype in glob.iterables:
				var next_path = path.duplicate()
				next_path.append(key)
				q.append([value, dtype, next_path, false])
			else:
				var dict: bool = parent_dtype == TYPE_DICTIONARY
				if (dict and (not deltas.snapshot.has(key) or deltas.snapshot[key] != value)) \
				or (!dict and (key >= len(deltas.snapshot) or deltas.snapshot[key] != value)):
					result_adds.get_or_add(path, {})[key] = value

		if deltas.snapshot:
			if parent_dtype == TYPE_DICTIONARY:
				for k in deltas.snapshot.keys():
					if not cur_iterable.has(k):
						result_deletes.get_or_add(path, {})[k] = deltas.snapshot[k]
			else:
				var old_len = len(deltas.snapshot)
				var cur_len = len(cur_iterable)
				if old_len > cur_len:
					for i in range(cur_len, old_len):
						result_deletes.get_or_add(path, {})[i] = deltas.snapshot[i]

		deltas.snapshot = cur_iterable.duplicate()

var graph_types = {
	"io": preload("res://scenes/io_graph.tscn"),
	"neuron": preload("res://scenes/neuron.tscn"),
	"loop": preload("res://scenes/loop.tscn"),
	"base": preload("res://scenes/base_graph.tscn")
}

var z_count: int = RenderingServer.CANVAS_ITEM_Z_MIN
func get_graph(type = graph_types.base, flags = Graph.Flags.NONE) -> Graph:
	var new = type.instantiate()
	new.graph_flags = flags
	var last = storage.get_child(-1)
	z_count += last.z_space if last else 0
	new.z_index = z_count
	storage.add_child(new)
	return new

var graph_layers: Dictionary[int, CanvasLayer] = {}
func _ready():
	pass

var pos_cache: Dictionary = {}
func _process(delta: float) -> void:
	propagate_cycle()
	gather_cycle()

	var vp = Rect2(Vector2.ZERO, glob.window_size)

	for graph: Graph in storage.get_children():
		var r = graph.rect
		
		var vis: bool = false
		if not graph.dragging:
			var gp = r.global_position
			var s  = r.size

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
		vis = vis or graph.dragging or graph.hold_process
		if graph.hold_process:
			graph.hold_process = false
		
		#vis = vis and 

		if vis:
			graph.process_mode = Node.PROCESS_MODE_ALWAYS
			graph.show()
			graph.is_mouse_inside()
		else:
			graph.hide()
			graph.process_mode = Node.PROCESS_MODE_DISABLED
		
		

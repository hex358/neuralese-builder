extends Node2D

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
	var last = get_child_count() - 1
	if from == last:
		return
	dragged[graph] = [graph.z_index, from]
	var kids = get_children()
	var carry = graph.z_index
	for i in range(from + 1, kids.size()):
		var k = kids[i]
		if k is CanvasItem:
			var z = k.z_index
			k.z_index = carry
			carry = z
	graph.z_index = carry
	move_child(graph, -1)


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
const DELETE: int = 0; const CHANGE: int = 1; const ADD: int = 2
var deltas = {}

func store_delta(graph: Graph):
	var new_info = graph.get_info()


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
	z_count += get_child(-1).z_space if get_child(-1) else 0
	new.z_index = z_count
	add_child(new)
	return new

var graph_layers: Dictionary[int, CanvasLayer] = {}
func _ready():
	pass

func _process(delta: float) -> void:
	propagate_cycle()
	gather_cycle()

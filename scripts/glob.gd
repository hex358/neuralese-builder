@tool
extends Node2D

var default_spline = preload("res://scenes/default_spline.tscn")
var scroll_container = preload("res://scenes/vbox.tscn")


var hide_menus: bool = false
var hovered_connection: Connection = null
var spline_connection: Connection = null
#var splines = {}

var menus: Dictionary[StringName, BlockComponent] = {}

var refs = {}
func ref(inst, name):
	refs[name] = inst



func getref(name):
	if name in refs:
		if is_instance_valid(refs[name]):
			return refs[name]
		else:
			refs.erase(name)
	return null


func get_spline(for_connection: Connection, keyword: StringName = &"default") -> Spline:
	var new = default_spline.instantiate()
	new.keyword = keyword
	splines_layer.add_child(new); new.z_index = 9
	return new

var splines_active = {}
func activate_spline(spline: Spline):
	splines_active[spline] = true
	if spline.get_parent() == top_splines_layer: return
	spline.reparent(top_splines_layer)

func deactivate_spline(spline: Spline):
	splines_active.erase(spline)
	if spline.get_parent() == splines_layer: return
	spline.reparent(splines_layer)

# Occupation (some node blocks input of others)
var occ_layers: Dictionary[StringName, Control] = {}


class GenArray:
	var _iterable = null; var _wrapper: Callable = Callable()
	func _init(iterable, wrapper: Callable):
		iterable = _iterable; _wrapper = wrapper

	func _iter_init(iter):
		iter[0] = 0
		return iter[0] < len(_iterable)

	func _iter_next(iter):
		iter[0] += 1
		return iter[0] < len(_iterable)

	func _iter_get(iter):
		return _wrapper.call(iter[0])


func gen(iterable, wrapper: Callable) -> GenArray:
	return GenArray.new(iterable, wrapper)

func is_occupied(node: Node, layer: StringName) -> bool: 
	var occupied = occ_layers.get(layer, null)
	return is_instance_valid(occupied) and occupied != node

func get_occupied(layer: StringName):
	var got = occ_layers.get(layer, null)
	return got if is_instance_valid(got) else null

var sib: Node
func loaded(string: String) -> int:
	if not sib: 
		sib = Node.new(); get_tree().get_root().add_child(sib)
		sib.get_parent().move_child(sib, base_node.get_index()+1)
		
	var inst = load(string).instantiate()
	inst.window_hide()
	sib.add_child(inst); return 0

var fg: ColorRect = null
var tree_windows: Dictionary[String, TabWindow] = {}
@onready var _load_window_scenes = {}
var curr_window = ""
func go_window(window_name: String):
	if curr_window == window_name: return
	if curr_window in tree_windows:
		tree_windows[curr_window].window_hide()
	if window_name in tree_windows:
		tree_windows[window_name].window_show()
		curr_window = window_name
	



var base_node: Node2D = null

func cap(value: float, decimals: int) -> float:
	var factor = pow(10.0, decimals)
	return floor(value * factor) / factor

func is_occupator(node: Node, layer: StringName) -> bool:
	var occupied = occ_layers.get(layer, null)
	return is_instance_valid(occupied) and occupied == node

func occupy(node: Control, layer: StringName):
	var occupied = occ_layers.get_or_add(layer, null)
	if not is_instance_valid(occupied):
		occ_layers[layer] = node
func un_occupy(node: Control, layer: StringName):
	var occupied = occ_layers.get_or_add(layer, null)
	
	if is_instance_valid(occupied) and occupied == node:
		occ_layers[layer] = null

# Select menu type (add graph / edit graph / edit connection etc.)
var menu_type: StringName = &""
var _menu_type_occupator: Node = null
func is_my_menu(node: BlockComponent) -> bool:
	return menu_type == node.menu_name if menu_type else node.menu_name == &"add_graph"
var default = []
func set_menu_type(occ: Node, type: StringName, low_priority_types=null ):
	if !is_instance_valid(_menu_type_occupator) or (low_priority_types and menu_type in low_priority_types): 
		_menu_type_occupator = occ
		menu_type = type
func reset_menu_type(occ, type: StringName):
	if is_instance_valid(_menu_type_occupator) and _menu_type_occupator == occ: 
		_menu_type_occupator = null
		menu_type = &""

func get_occupator():
	if not is_instance_valid(_menu_type_occupator):
		_menu_type_occupator = null
	return _menu_type_occupator

# Unique slot
var id: int = 0
func free_slot():
	id += 1; return id


func show_menu(name: StringName, at_pos: Vector2 = Vector2()):
	var menu = menus[name]
	menu.size.y = menu.base_size.y
	menu.menu_show(menu.pos_clamp(at_pos if at_pos else menu.get_global_mouse_position()))
	menu.state.holding = false

func hide_all_menus() -> void: hide_menus = true

func get_global_z_index(init_node: CanvasItem) -> int:
	var z: int = 0; var node: Node = init_node
	while node is CanvasItem:
		z += node.z_index
		if !node.z_as_relative: break
		node = node.get_parent()
	return z

func get_label_text_size(lbl: Control, use_scale: float = 1.0) -> Vector2:
	# Measure label text size
	var font = lbl.get_theme_font("font")
	var size = lbl.get_theme_font_size("font_size") * use_scale
	return font.get_string_size(lbl.text, 0, -1, size)

func layer_to_global(layer: CanvasLayer, point: Vector2):
	return layer.transform * point

func global_to_layer(layer: CanvasLayer, point: Vector2):
	return layer.transform.affine_inverse() * point

func spring(from, to, t: float,
			frequency: float = 4.5,
			damping: float = 4.0,
			amplitude: float = 2.0
) -> Vector2:
	var w = frequency * PI * 2.0
	var decay = exp(-damping * t)
	var osc = cos(w * t) + (damping / w) * sin(w * t)
	var amp_factor = lerp(1.0, amplitude, t)
	var factor = 1.0 - decay * osc * amp_factor
	return from + (to - from) * factor


class _Timer extends Object:
	var wait_time: float; var progress: float; var frames: bool 
	signal timeout
	func _init(wait_time: float, _frames: bool):
		self.wait_time = wait_time; self.progress = 0.0; frames = _frames

var timers: Dictionary[_Timer, bool] = {}

func timer(wait_time: float, frames: bool = false):
	var timer = _Timer.new(wait_time, frames)
	timers[timer] = true; return timer

func wait(wait_time: float, frames: bool = false):
	var timer = _Timer.new(wait_time, frames)
	timers[timer] = true; return timer.timeout

var project_id: int = 0

func get_project_id() -> int:
	return project_id

func set_var(n: String, val: Variant):
	var got = get_stored()
	got[n] = val
	var op = cookies.open_or_create("memory.bin")
	op.store_var(got)

func get_var(n: String) -> Variant:
	return get_stored().get(n, null)

func get_stored() -> Dictionary:
	var op = cookies.open_or_create("memory.bin")
	if not op: return {}
	var res = op.get_var()
	return res if res else {}


func open_last_project():
	var got = get_var("last_id")
	if got:
		load_scene(str(got))
	else:
		var a = await request_projects()
		if a:
			load_scene(a.keys()[0])
		else:
			var i = await create_empty_project("")
			load_empty_scene(i, "")


var parsed_projects = {}

func create_empty_project(name: String) -> int:
	var id: int = random_project_id()
	parsed_projects[str(id)] = {"name": name}
	ui.hourglass_on()
	var res = await save_empty(str(id), name)
	ui.hourglass_off()
	return id

func request_projects():
	var a = await web.POST("project_list", {
	"user": "n", 
	"pass": "1"
	})
	if a.body:
		a = JSON.parse_string(a.body.get_string_from_utf8())["list"]
		parsed_projects = a
		return a
	return {}

func random_project_id() -> int:
	return randi_range(0,999999999)

func _after_process(delta: float) -> void:
	hide_menus = false
	consumed_input.clear()
	hovered_connection_changed = false

	if space_just_pressed:
		pass
		#await save(str(get_project_id()))
		#load_scene("gr1")
	#prit(menu_type)

var opened_menu = null

var mouse_pressed: bool = false
var mouse_just_pressed: bool = false
var mouse_released: bool = false
var mouse_just_released: bool = false

var mouse_alt_pressed: bool = false
var mouse_alt_just_pressed: bool = false
var mouse_alt_released: bool = false
var mouse_alt_just_released: bool = false

var mouse_middle_pressed: bool = false
var mouse_middle_just_pressed: bool = false
var mouse_middle_released: bool = false
var mouse_middle_just_released: bool = false

var mouse_scroll: int = 0

var consumed_input: Dictionary[StringName, Control] = {}

var cam: Camera2D
var viewport: Viewport

const arrays: Dictionary[int, bool] = {
TYPE_ARRAY:true,
TYPE_PACKED_BYTE_ARRAY:true,
TYPE_PACKED_COLOR_ARRAY:true,
TYPE_PACKED_VECTOR2_ARRAY:true,
TYPE_PACKED_VECTOR3_ARRAY:true,
TYPE_PACKED_VECTOR4_ARRAY:true,
TYPE_PACKED_STRING_ARRAY:true,
TYPE_PACKED_FLOAT32_ARRAY:true,
TYPE_PACKED_FLOAT64_ARRAY:true,
TYPE_PACKED_INT32_ARRAY:true,
TYPE_PACKED_INT64_ARRAY:true
}

var units = [
	["T", 1_000_000_000_000],
	["B", 1_000_000_000],
	["M", 1_000_000],
	["K", 1_000]
]

func compact(n: int) -> String:
	if n < 1000:
		return str(n)

	for u in units:
		var suf: String = u[0]
		var val: int = u[1]
		if n >= val:
			var q: int = n / val
			var rem: int = n % val
			return str(q) + suf

	return str(n)


var iterables: Dictionary[int, bool] = arrays.merged({
TYPE_DICTIONARY:true,})

func is_array(a) -> bool: return typeof(a) in arrays
func is_iterable(a) -> bool: return typeof(a) in iterables

func list(type: int):
	var res = null
	match type:
		TYPE_ARRAY:res=[]
		TYPE_PACKED_BYTE_ARRAY:res=PackedByteArray()
		TYPE_PACKED_COLOR_ARRAY:res=PackedColorArray()
		TYPE_PACKED_VECTOR2_ARRAY:res=PackedVector2Array()
		TYPE_PACKED_VECTOR3_ARRAY:res=PackedVector3Array()
		TYPE_PACKED_VECTOR4_ARRAY:res=PackedVector4Array()
		TYPE_PACKED_STRING_ARRAY:res=PackedStringArray()
		TYPE_PACKED_FLOAT32_ARRAY:res=PackedFloat32Array()
		TYPE_PACKED_FLOAT64_ARRAY:res=PackedFloat64Array()
		TYPE_PACKED_INT32_ARRAY:res=PackedInt32Array()
		TYPE_PACKED_INT64_ARRAY:res=PackedInt64Array()
		TYPE_DICTIONARY:res={}
	return res

func consume_input(inst: Control, input: StringName):
	if not consumed_input.has(input) or consumed_input[input].z_index <= inst.z_index:
		consumed_input[input] = inst

func is_consumed(inst: Control, input: StringName):
	return consumed_input.has(input) and consumed_input[input] != inst

func get_consumed(input: StringName):
	return consumed_input.get(input, null)



func press_poll():
	mouse_just_pressed = Input.is_action_just_pressed("ui_mouse")
	mouse_pressed = Input.is_action_pressed("ui_mouse")
	mouse_just_released = Input.is_action_just_released("ui_mouse")
	mouse_released = not mouse_pressed

	mouse_alt_just_pressed = Input.is_action_just_pressed("ui_mouse_alt")
	mouse_alt_pressed = Input.is_action_pressed("ui_mouse_alt")
	mouse_alt_just_released = Input.is_action_just_released("ui_mouse_alt")
	mouse_alt_released = not mouse_alt_pressed

	mouse_middle_just_pressed = Input.is_action_just_pressed("ui_mouse_middle")
	mouse_middle_pressed = Input.is_action_pressed("ui_mouse_middle")
	mouse_middle_just_released = Input.is_action_just_released("ui_mouse_middle")
	mouse_middle_released = not mouse_alt_pressed
	
	if unpress_enq:
		glob.mouse_pressed = false
		glob.mouse_just_pressed = false
		glob.mouse_alt_pressed = false
		glob.mouse_alt_just_pressed = false
		unpress_enq = false
	
	if mouse_just_pressed:
		last_mouse_click_at = get_global_mouse_position()

var unpress_enq: bool = false

func reset_presses():
	unpress_enq = true

func cull(gp: Vector2, s: Vector2) -> bool:
	var p0: Vector2 = glob.world_to_screen(gp)
	var p1: Vector2 = glob.world_to_screen(gp + Vector2(s.x, 0.0))
	var p2: Vector2 = glob.world_to_screen(gp + Vector2(0.0, s.y))
	var p3: Vector2 = glob.world_to_screen(gp + s)

	var minx: float = min(p0.x, p1.x, p2.x, p3.x)
	var maxx: float  = max(p0.x, p1.x, p2.x, p3.x)
	var miny: float = min(p0.y, p1.y, p2.y, p3.y)
	var maxy: float = max(p0.y, p1.y, p2.y, p3.y)
	var rect_screen = Rect2(Vector2(minx, miny), Vector2(maxx - minx, maxy - miny))

	return rect_screen.intersects(window_rect)



func input_poll():
	press_poll()
	if Input.is_action_just_pressed("scroll_up"): mouse_scroll = -1
	elif Input.is_action_just_pressed("scroll_down"): mouse_scroll = 1
	else: mouse_scroll = 0


var ticks: int = 0


var menu_canvas: CanvasLayer = null
func get_display_mouse_position():
	return menu_canvas.root.get_global_mouse_position()

func twine(a: float, b: float, factor: float):
	pass
	#return lerp(a, b, 1.0 - exp(-speed * delta))


var window_size: Vector2 = Vector2.ONE
var window_middle: Vector2 = Vector2.ONE

var UP: int = 0
var DOWN: int = 1
var LEFT: int = 2
var RIGHT: int = 3

func world_to_screen(p_world: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * p_world

func screen_to_world(p_screen: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * p_screen

var follow_menus: Node
var window_rect: Rect2 = Rect2()
var time: float = 0.0
var space_pressed: bool = false
var space_just_pressed: bool = false

func _process(delta: float) -> void:
	
	
	
	space_just_pressed = Input.is_action_just_pressed("ui_accept")
	space_pressed = Input.is_action_pressed("ui_accept")
	time += delta
	ticks += 1
	if Engine.is_editor_hint(): return
	if not is_instance_valid(_menu_type_occupator):
		menu_type = ""
		_menu_type_occupator = null
	
	window_size = DisplayServer.window_get_size()
	window_rect = Rect2(Vector2(), window_size)
	window_middle = window_size / 2
	space_end = DisplayServer.window_get_size()

	_after_process.call_deferred(delta)
	
	var to_erase = []
	for timer in timers:
		timer.progress += delta if not timer.frames else 1
		if timer.progress > timer.wait_time: 
			timer.timeout.emit()
			to_erase.append(timer)
	for i in to_erase:
		timers.erase(i)
		i.free.call_deferred()
	input_poll()
	var occ = get_occupied("block_button_inside")
	if occ and not occ.is_mouse_inside():
		un_occupy(occ, "block_button_inside")


var hovered_connection_changed: bool = false

func is_graph_inside() -> bool: return is_occupied(self, "graph")

func byte(x) -> PackedByteArray:
	if x is Dictionary:
		return JSON.stringify(x).to_utf8_buffer()
	return PackedByteArray()

func compress_dict_gzip(dict: Dictionary):
	var jsonified = JSON.new().stringify(dict)
	var bytes = jsonified.to_ascii_buffer()
	return bytes.compress(FileAccess.CompressionMode.COMPRESSION_GZIP)

func compress_dict_zstd(dict: Dictionary):
	var jsonified = JSON.new().stringify(dict)
	var bytes = jsonified.to_ascii_buffer()
	return bytes.compress(FileAccess.CompressionMode.COMPRESSION_ZSTD)


var buffer: BackBufferCopy
var splines_layer: CanvasLayer
var top_splines_layer: CanvasLayer

func is_vec_approx(a: Vector2, b: Vector2, eps: float = 0.01) -> bool:
	return abs(a.x-b.x) < eps and abs(a.y-b.y) < eps

func inst_uniform(who: CanvasItem, uniform: StringName, val):
	RenderingServer.canvas_item_set_instance_shader_parameter(who.get_canvas_item(), uniform, val)

func inst_uniform_read(who: CanvasItem, uniform: StringName):
	#(RenderingServer.canvas_item_get_instance_shader_parameter_list(who.get_canvas_item()))
	return RenderingServer.canvas_item_get_instance_shader_parameter(who.get_canvas_item(), uniform)


func in_out_quad(t: float) -> float:
	t = clamp(t, 0.0, 1.0)
	return 2.0 * t * t if t < 0.5 else 1.0 - pow(-2.0 * t + 2.0, 2.0) / 2.0


func get_project_data(empty: bool = false) -> Dictionary:
	var data = {"graphs": {}, "lua": {}, "registry": {}}
	data["registry"]["subgraph_registry"] = {}
	if empty:
		return data
	for i in graphs._graphs:
		data["graphs"][i] = graphs._graphs[i].get_info()
	var texts = glob.tree_windows["env"].get_texts()
	for i in texts:
		data["lua"][i] = texts[i]
		
	data["camera"] = Vector3(cam.position.x, cam.position.y, cam.zoom.x)
	
	for sub_id in Graph._subgraph_registry:
		var ids = []
		for n in Graph._subgraph_registry[sub_id]:
			if is_instance_valid(n):
				ids.append(n.graph_id)
		data["registry"]["subgraph_registry"][sub_id] = ids
	return data



func init_scene(scene: String):
	tree_windows["env"].request_texts()


func delete_project(scene: int):
	web.POST("delete_project", {"user": "n", "pass": "1", "scene": str(scene)})
	parsed_projects.erase(str(scene))
	if project_id == scene:
		var i = await create_empty_project("")
		load_empty_scene(i, "")
	return true

func def(...args) -> void:
	pass


var tags = ["change_nodes", "connect_ports", "delete_nodes", "disconnect_ports"]

func tag_strip(text: String) -> Array:
	var out = ""
	var i = 0
	var stack: Array[String] = []
	var did_remove := false

	while i < text.length():
		var next_open = -1
		var next_close = -1
		var found_tag = ""
		var closing_tag = false

		for tag in tags:
			var pos_open = text.find("<%s>" % tag, i)
			var pos_close = text.find("</%s>" % tag, i)
			if pos_open != -1 and (next_open == -1 or pos_open < next_open):
				next_open = pos_open
				found_tag = tag
				closing_tag = false
			if pos_close != -1 and (next_close == -1 or pos_close < next_close):
				next_close = pos_close
				if next_open == -1 or next_close < next_open:
					found_tag = tag
					closing_tag = true

		if next_open == -1 and next_close == -1:
			out += text.substr(i)
			break

		var min_pos = INF
		if next_open != -1:
			min_pos = min(min_pos, next_open)
		if next_close != -1:
			min_pos = min(min_pos, next_close)

		out += text.substr(i, min_pos - i)
		i = min_pos

		if closing_tag:
			if stack.size() > 0 and stack.back() == found_tag:
				stack.pop_back()
			i += ("</%s>" % found_tag).length()
			did_remove = true
		else:
			stack.append(found_tag)
			i += ("<%s>" % found_tag).length()
			var close_pos = text.find("</%s>" % found_tag, i)
			if close_pos == -1:
				did_remove = true
				break
			i = close_pos + ("</%s>" % found_tag).length()
			did_remove = true

	return [out, did_remove]


func _match_tag_token(buf: String, pos: int) -> Variant:
	if pos >= buf.length() or buf[pos] != '<':
		return null

	for tag in tags:
		var open_tok = "<%s>" % tag
		var close_tok = "</%s>" % tag

		if buf.substr(pos, open_tok.length()) == open_tok:
			return {"kind": "open", "tag": tag, "len": open_tok.length()}
		if buf.substr(pos, close_tok.length()) == close_tok:
			return {"kind": "close", "tag": tag, "len": close_tok.length()}

	var tail = buf.substr(pos)
	for tag in tags:
		var open_tok = "<%s>" % tag
		var close_tok = "</%s>" % tag
		if open_tok.begins_with(tail) or close_tok.begins_with(tail):
			return {"kind": "partial"}

	return null




func parse_stream_tags(sock: SocketConnection, chunk: String) -> String:
	var state = sock.cache.get_or_add("parser_state", {"buf": "", "stack": [], "acc": []})
	var actions = sock.cache.get_or_add("actions", {})  # { tag: [body1, body2, ...] }

	state.buf += chunk

	var result: String = ""
	var i: int = 0

	while i < state.buf.length():
		var token = null
		if state.buf[i] == '<':
			token = _match_tag_token(state.buf, i)
			if token == null:
				if state.stack.size() == 0:
					result += state.buf[i]
				else:
					state.acc[state.acc.size() - 1] += state.buf[i]
				i += 1
				continue

			if token.has("kind") and token.kind == "partial":
				break

			if token.kind == "open":
				state.stack.append(token.tag)
				state.acc.append("")
				i += token.len
				continue

			if token.kind == "close":
				var top_ok = state.stack.size() > 0 and state.stack[state.stack.size() - 1] == token.tag
				if top_ok:
					var body: String = state.acc.pop_back()
					state.stack.pop_back()

					if not actions.has(token.tag):
						actions[token.tag] = []
					actions[token.tag].append(body)

					if state.acc.size() > 0:
						state.acc[state.acc.size() - 1] += body

					i += token.len
					continue
				else:
					if state.stack.size() == 0:
						result += state.buf[i]
					else:
						state.acc[state.acc.size() - 1] += state.buf[i]
					i += 1
					continue

		if state.stack.size() == 0:
			result += state.buf[i]
		else:
			state.acc[state.acc.size() - 1] += state.buf[i]
		i += 1

	state.buf = state.buf.substr(i)
	for j in tags:
		if not j in actions:
			actions[j] = []
	return result

func clean_message(s: String):
	#s = s.replace("```json\n", "")
	#s = s.replace("\n```", "")
	#s = s.strip_edges()
	return tag_strip(s)[0].strip_edges()


func message_chunk_received(data, sock: SocketConnection):
	var dt = data.get_string_from_utf8()
	var parsed = JSON.parse_string(dt)
	if not "text" in parsed:
		return
	var text_update = sock.get_meta("text_update")
	var text: String = parsed.text
	var clean_text = parse_stream_tags(sock, text)
	#clean_text = clean_text.replace("```json\n", "").replace("\n```", "").strip_edges()`
	if clean_text.is_empty():
		return
	sock.cache.get_or_add("message", [""])[0] += clean_text
	if text_update.is_valid():
		text_update.call(clean_text)


var message_sockets: Dictionary[int, SocketConnection] = {}

var last_mouse_click_at: Vector2 = Vector2()

var llm_name_mapping = {
	activation = "neuron",
	dense_layer = "layer",
	conv2d_layer = "conv2d",
	maxpool_layer = "maxpool",
	softmax = "softmax",
	flatten = "flatten",
	reshape2d = "reshape2d",
	out_classes =  "classifier",
	input_image_small = "input",
	model_name = "model_name",
	run_model = "run_model",
	train_begin = "train_begin",
	train_step = "train_input",
}

var tag_types = {}

func get_llm_tag(who: Graph) -> String:
	var res = ""; var iters: int = 0
	var g = who.get_meta("created_with")
	if not g in tag_types: tag_types[g] = {}
	while res in tag_types[g] or iters < 1:
		var r = ""
		r += llm_name_unmapping.get(g)
		r += "_" + str(len(tag_types[g]))
		res = r
		iters += 1
	tag_types[g][res] = true
	#print(res)
	return res

func set_llm_tag(who: Graph, val: String):
	var g = who.get_meta("created_with")
	if not g in tag_types: tag_types[g] = {}
	who.llm_tag = val
	tag_types[g][val] = true

var llm_name_unmapping = (func():
	var dict = {}
	for i in llm_name_mapping:
		dict[llm_name_mapping[i]] = i
	return dict).call()


func test_place():
	var a = cookies.open_or_create("test.bin").get_var()
	model_changes_apply(a)
	
func model_changes_apply(actions: Dictionary):
	cookies.open_or_create("test.bin").store_var(actions)
	var creating: Dictionary[String, Graph] = {}
	if actions["change_nodes"]:
		for i in ui.splashed:
			i.go_away()
	await wait(0.05)

	for pack in actions["change_nodes"]:
		for node in pack:
			var typename = llm_name_mapping.get(node.node)
			if not typename:
				continue
			var g = graphs.get_graph(typename, Graph.Flags.NEW, 0, node.tag)
			creating[node.tag] = g
			g.hold_for_frame()

	await get_tree().process_frame

	for pack in actions["connect_ports"]:
		for connection in pack:
			if connection.from.tag in creating and connection.to.tag in creating:
				var from_graph = creating[connection.from.tag]
				var to_graph = creating[connection.to.tag]

				var out_ports = from_graph.output_keys
				var in_ports = to_graph.input_keys

				if len(out_ports) == 1:
					connection.from.port = out_ports.keys()[0]
				if len(in_ports) == 1:
					connection.to.port = in_ports.keys()[0]

				out_ports[int(connection.from.port)].connect_to(in_ports[int(connection.to.port)])
	_auto_layout(creating)



func _auto_layout(creating: Dictionary[String, Graph], padding: float = 180.0):
	var visited := {}

	# pick arbitrary starting node (or one without inputs)
	var origins: Array = []
	for tag in creating.keys():
		var g: Graph = creating[tag]
		if g.server_typename == "InputNode" or g.server_typename == "TrainBegin":
			origins.append(g)
		g.hold_for_frame()
	if origins.is_empty():
		origins.append(creating.values()[0])
	for i in origins:
		if graphs.is_node(i, "TrainBegin"):
			i.position.y -= 310
	
	var leftover = creating
	for origin in origins:
		#origin.position = Vector2.ZERO
		graphs.reach(origin, func(from_conn: Connection, to_conn: Connection, branch_cache: Dictionary):
			var from_graph: Graph = from_conn.parent_graph
			var to_graph: Graph = to_conn.parent_graph
			if to_graph in visited:
				return
			visited[to_graph] = true
			var base_pos: Vector2 = from_graph.rect.global_position
			var dir: Vector2 = from_conn.dir_vector.normalized()
			var mult = Vector2(); var pad = 30
			mult.x = from_graph.rect.size.x + pad if dir.x >= 0 else pad
			mult.y = from_graph.rect.size.y + pad if dir.y >= 0 else pad
			if dir.y == 0:
				base_pos.y = from_graph.rect.global_position.y + from_graph.rect.size.y / 2
		#	to_graph.rect.position = base_pos + dir * mult
			to_graph.global_position = base_pos + dir * mult - to_graph.rect.position
			leftover.erase(to_graph.llm_tag)
		)
	for key in leftover:
		var node = leftover[key]
		# special rules for tag nodes
		if graphs.is_node(node, "LayerConfig"):
			var descendants = node.get_first_descendants()
			if descendants:
				var middle_x = float(0.0)
				for i in descendants:
					middle_x += i.rect.global_position.x + i.rect.size.x / 2
				middle_x /= len(descendants)
				var min_y = INF
				for i in descendants:
					min_y = min(min_y, i.rect.global_position.y)
				if min_y != INF:
					node.position = Vector2(middle_x, min_y - 100)

		if graphs.is_node(node, "ModelName"):
			var descendants = node.get_first_descendants()
			if descendants:
				var middle_x = INF
				for i in descendants:
					middle_x = min(middle_x, i.rect.global_position.x)
				var min_y = INF
				for i in descendants:
					min_y = min(min_y, i.rect.global_position.y)
				node.position = Vector2(middle_x - 80, min_y - 80)
	for i in origins:
		if graphs.is_node(i, "TrainBegin"):
			i.position.y += 90


func sock_end_life(chat_id: int, on_close: Callable, sock: SocketConnection):
	message_sockets.erase(chat_id)
	on_close.call()
	var acts = sock.cache.get("actions", {})
	
	for action in acts:
		for el in len(acts[action]):
			acts[action][el] = JSON.parse_string(acts[action][el])
	
	model_changes_apply(acts)
		#print()

func update_message_stream(input_text: String, chat_id: int, text_update: Callable = def, on_close: Callable = def, clear: bool = false) -> SocketConnection:
	if chat_id in message_sockets: return
	var sock = await sockets.connect_to("ws/talk", def)
	sock.send_json({"user": "n", "pass": "1", "chat_id": str(chat_id), 
	"text": input_text, "_clear": "1" if clear else "",
	"scene": str(get_project_id())})
	sock.packet.connect(message_chunk_received.bind(sock))
	message_sockets[chat_id] = sock
	sock.set_meta("text_update", text_update)
	sock.kill.connect(sock_end_life.bind(chat_id, on_close, sock))
	return sock

func get_my_message_state(chat_id: int, text_update: Callable = def) -> Array:
	if chat_id in message_sockets:
		var got = message_sockets[chat_id]
		got.set_meta("text_update", text_update)
		return [got, got.cache.get("message", [""])[0]]
	return [null, ""]


var env_dump = {}
func load_scene(from: String):
	project_id = int(from)
	var answer = await web.POST("project", {"scene": from, 
	 "user": "n", 
	"pass": "1"})
	if not "body" in answer: return
	var a = JSON.parse_string(answer["body"].get_string_from_utf8())
	if not a: return
	if not "scene" in a: return
	var dat = bytes_to_var(Marshalls.base64_to_raw(a["scene"]))
	if !dat: return
	fg.go_into_graph()
	await graphs.delete_all()
	set_var("last_id", project_id)
	tree_windows["env"].reset()
	
	fg.set_scene_name(a["name"])
	graphs.load_graph(dat["graphs"], dat["registry"].get("subgraph_registry", {}))
	env_dump = dat["lua"]
	tree_windows["env"].request_texts()
	if "camera" in dat and dat["camera"]:
		if cam is GraphViewport:
			cam.target_zoom = dat.camera.z
			cam.target_position = Vector2(dat.camera.x, dat.camera.y)
		#else:
		cam.zoom = Vector2(dat.camera.z, dat.camera.z)
		cam.position = Vector2(dat.camera.x, dat.camera.y)
	return true



func request_chat(chat_id: String):
	return await web.POST("get_chat", {"user": "n", 
	"pass": "1", 
	"chat_id": chat_id, 
	"scene": str(get_project_id())})


func load_empty_scene(pr_id: int, name: String):
	fg.go_into_graph()
	project_id = pr_id
	set_var("last_id", project_id)
	tree_windows["env"].reset()
	await graphs.delete_all()
	
	fg.set_scene_name(name)
	env_dump = {}
	tree_windows["env"].request_texts()

#func pull_scene_locally(from: String):
	#var old_var = cookies.open_or_create("scene_cache/%s.bin" % from).get_var()
	#

func save(from: String):
	var blob = Marshalls.raw_to_base64(var_to_bytes(get_project_data()))
	return await web.POST("save", {"scene": from, 
	"blob": blob,
	"name": fg.get_scene_name(),
	 "user": "n", 
	"pass": "1"})

func save_empty(from: String, name: String):
	var blob = Marshalls.raw_to_base64(var_to_bytes(get_project_data(true)))
	return await web.POST("save", {"scene": from, 
	"blob": blob,
	"name": name,
	 "user": "n", 
	"pass": "1"})



func rget_children(from_root: Node) -> Array:
	var result: Array = []
	var stack: Array = [from_root]

	while stack.size() > 0:
		var node: Node = stack.pop_back()
		for child in node.get_children(true):
			result.append(child)
			stack.append(child)

	return result


func _window_scenes() -> Dictionary:
	return {
	"graph": $"../base/WIN_GRAPH",
	"env": loaded("res://scenes/env_tab.tscn"),
	}

var space_begin: Vector2 = Vector2()
var space_end: Vector2 = DisplayServer.window_get_size()
func _ready() -> void:
	OS.low_processor_usage_mode = true
	splines_layer = CanvasLayer.new()
	splines_layer.layer = -124
	splines_layer.follow_viewport_enabled = true

	top_splines_layer = CanvasLayer.new()
	top_splines_layer.layer = 4
	top_splines_layer.follow_viewport_enabled = true
	
	get_tree().get_root().get_node("base/WIN_GRAPH").add_child(splines_layer)
	get_tree().get_root().get_node("base/WIN_GRAPH").add_child(top_splines_layer)
	
	await get_tree().process_frame
	_load_window_scenes = _window_scenes()
	go_window("graph")
	init_scene("")
	#open_last_project()
	
	test_place()
	
	

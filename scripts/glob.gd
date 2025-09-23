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
	return occ_layers.get(layer, null)

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
func reset_menu_type(occ: Node, type: StringName):
	if is_instance_valid(_menu_type_occupator) and _menu_type_occupator == occ: 
		_menu_type_occupator = null
		menu_type = &""

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

func get_label_text_size(lbl: Control) -> Vector2:
	# Measure label text size
	var font = lbl.get_theme_font("font")
	var size = lbl.get_theme_font_size("font_size")
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

func _after_process(delta: float) -> void:
	hide_menus = false
	consumed_input.clear()
	#print(menu_type)

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
func _process(delta: float) -> void:
	time += delta
	ticks += 1
	if Engine.is_editor_hint(): return
	
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

func compress_dict_gzip(dict: Dictionary):
	var jsonified = JSON.new().stringify(dict)
	var bytes = jsonified.to_ascii_buffer()
	return bytes.compress(FileAccess.CompressionMode.COMPRESSION_GZIP)


var buffer: BackBufferCopy
var splines_layer: CanvasLayer
var top_splines_layer: CanvasLayer

func is_vec_approx(a: Vector2, b: Vector2, eps: float = 0.01) -> bool:
	return abs(a.x-b.x) < eps and abs(a.y-b.y) < eps

func inst_uniform(who: CanvasItem, uniform: StringName, val):
	RenderingServer.canvas_item_set_instance_shader_parameter(who.get_canvas_item(), uniform, val)

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
	
	get_tree().get_root().get_node("base").add_child(splines_layer)
	get_tree().get_root().get_node("base").add_child(top_splines_layer)

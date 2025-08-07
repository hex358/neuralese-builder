@tool
extends Node2D

var base_graph = preload("res://base_graph.tscn")
var loop_graph = preload("res://loop.tscn")
var io_graph = preload("res://io_graph.tscn")
var neuron_graph = preload("res://neuron.tscn")
var default_spline = preload("res://default_spline.tscn")
var scroll_container = preload("res://vbox.tscn")

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

func get_spline(for_connection: Connection, keyword: StringName = &"") -> Spline:
	var new = default_spline.instantiate()
	new.keyword = keyword
	add_child(new); new.z_index = 9
	return new

# Occupation (some node blocks input of others)
var occ_layers: Dictionary[StringName, Control] = {}

func is_occupied(node: Node, layer: StringName) -> bool: 
	var occupied = occ_layers.get(layer, null)
	return is_instance_valid(occupied) and occupied != node
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

func get_graph(type = base_graph, flags = Graph.Flags.NONE) -> Graph:
	var new = type.instantiate()
	new.graph_flags = flags
	return new

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
	var wait_time: float; var progress: float
	signal timeout
	func _init(wait_time: float):
		self.wait_time = wait_time; self.progress = 0.0

var timers: Dictionary[_Timer, bool] = {}

func timer(wait_time: float):
	var timer = _Timer.new(wait_time)
	timers[timer] = true; return timer

func wait(wait_time: float):
	var timer = _Timer.new(wait_time)
	timers[timer] = true; return timer.timeout

func _after_process(delta: float) -> void:
	hide_menus = false
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
var mouse_scroll: int = 0

func press_poll():
	mouse_just_pressed = Input.is_action_just_pressed("ui_mouse")
	mouse_pressed = Input.is_action_pressed("ui_mouse")
	mouse_just_released = Input.is_action_just_released("ui_mouse")
	mouse_released = not mouse_pressed

	mouse_alt_just_pressed = Input.is_action_just_pressed("ui_mouse_alt")
	mouse_alt_pressed = Input.is_action_pressed("ui_mouse_alt")
	mouse_alt_just_released = Input.is_action_just_released("ui_mouse_alt")
	mouse_alt_released = not mouse_alt_pressed

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

func _process(delta: float) -> void:
	ticks += 1
	if Engine.is_editor_hint(): return
	
	window_size = DisplayServer.window_get_size()
	window_middle = window_size / 2

	_after_process.call_deferred(delta)
	
	var to_erase = []
	for timer in timers:
		timer.progress += delta
		if timer.progress > timer.wait_time: 
			timer.timeout.emit()
			to_erase.append(timer)
	for i in to_erase:
		timers.erase(i)
		i.free.call_deferred()

	input_poll()

func _ready() -> void:
	pass

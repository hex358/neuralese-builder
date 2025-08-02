@tool
extends Node2D

var base_graph = preload("res://base_graph.tscn")
var default_spline = preload("res://default_spline.tscn")
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

func get_spline(for_connection: Connection) -> Spline:
	var new = default_spline.instantiate()
	add_child(new); new.z_index = 9
	return new

# Occupation (some node blocks input of others)
var occ_layers: Dictionary[StringName, Control] = {}

func is_occupied(node: Control, layer: StringName) -> bool: 
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
	return menu_type == node.menu_type if menu_type else node.menu_type == &"add_graph"
func set_menu_type(occ: Node, type: StringName):
	if !is_instance_valid(_menu_type_occupator): 
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

func get_graph(flags = Graph.Flags.NONE) -> Graph:
	var new = base_graph.instantiate()
	new.graph_flags = flags
	return new

func get_label_text_size(lbl: Label) -> Vector2:
	# Measure label text size
	var font = lbl.get_theme_font("font")
	var size = lbl.get_theme_font_size("font_size")
	return font.get_string_size(lbl.text, lbl.horizontal_alignment, -1, size)

func layer_to_global(layer: CanvasLayer, point: Vector2):
	return layer.transform * point

func global_to_layer(layer: CanvasLayer, point: Vector2):
	return layer.transform.affine_inverse() * point

func spring(from: Vector2, to: Vector2, t: float,
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

var mouse_pressed: bool = false
var mouse_just_pressed: bool = false
var mouse_released: bool = false
var mouse_just_released: bool = false

var mouse_alt_pressed: bool = false
var mouse_alt_just_pressed: bool = false
var mouse_alt_released: bool = false
var mouse_alt_just_released: bool = false

func input_poll():
	if ticks <= 1: return
	var press = Input.is_action_pressed("ui_mouse")
	mouse_just_pressed = press and not mouse_pressed
	mouse_pressed = press

	var released = not Input.is_action_pressed("ui_mouse")
	mouse_just_released = released and not mouse_released
	mouse_released = released

	var press_alt = Input.is_action_pressed("ui_mouse_alt")
	mouse_alt_just_pressed = press_alt and not mouse_alt_pressed
	mouse_alt_pressed = press_alt

	var released_alt = not Input.is_action_pressed("ui_mouse_alt")
	mouse_alt_just_released = released_alt and not mouse_alt_released
	mouse_alt_released = released_alt

var ticks: int = 0
var propagation_q = {}
func next_frame_propagate(tied_to: Connection, key: int, value: Variant):
	propagation_q.get_or_add(tied_to, {}).get_or_add(key, []).append(value)
	#print(propagation_q)

func _process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	if propagation_q:
		#print(propagation_q)
		var dup = propagation_q.duplicate(1)
		propagation_q.clear()
		for conn: Connection in dup:
			conn.parent_graph._do_propagate(dup[conn])
	
		#graph._do_propagate() 
		
	
	ticks += 1
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

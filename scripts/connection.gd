extends ColorRect
class_name Connection

static var INPUT: int = 0
static var OUTPUT: int = 1


var accepted_datatypes: Dictionary[StringName, bool] = {}
var datatype: StringName = ""
@export var _accepted_datatypes: String = "": ##any(empty), float, config
	set(v):
		if not is_node_ready():
			await ready
		_accepted_datatypes = v
		accepted_datatypes.clear()
		if _accepted_datatypes:
			for i in _accepted_datatypes.split(" "):
				if connection_type == OUTPUT:
					datatype = i
				accepted_datatypes[i] = true
		#print(connection_type == OUTPUT)
@export var hint: int = 0
@export var server_name: StringName = "":
	set(v):
		assert(v, "Please set server_name for server execution identification")
		server_name = v
@export var keyword: StringName = &""
@export_enum("Input", "Output") var connection_type: int = INPUT
@export var area_paddings: Vector4 = Vector4(10,10,10,10)
@export var multiple_splines: bool = false
@export var origin_offset: Vector2 = Vector2()
@export var unpadded_area: Vector4 = Vector4()
@export var max_splines_by_keyword: Dictionary[StringName, int] = {}

@export var dir_vector: Vector2 = Vector2.RIGHT

@export var parent_graph: Graph
# @onready var spline = glob.get_spline(self) if connection_type == OUTPUT else null

var outputs: Dictionary[int, Spline] = {}
var active_outputs: Dictionary[int, Spline] = {}
var inputs: Dictionary[Spline, int] = {}
var connected: Dictionary[Connection, bool] = {}

var mouse_just_pressed: bool = false
var mouse_pressed: bool = false

func delete():
	if connection_type == INPUT:
		var dup =  inputs.duplicate()
		for i in dup:
			detatch_spline(i)
			i.origin.end_spline(dup[i])
	else:
		for i in outputs.duplicate():
			outputs[i].tied_to.detatch_spline(outputs[i])
			end_spline(i)

func is_mouse_inside(padding:Vector4=area_paddings) -> bool:
	# padded hit area
	#if glob.is_consumed(self, "conn_mouse_inside"): return false
	if glob.get_display_mouse_position().y < glob.space_begin.y\
	or glob.get_display_mouse_position().x > glob.space_end.x: return false
	var top_left = global_position - Vector2(padding.x, padding.y) * parent_graph.scale * scale
	var padded_size = size * parent_graph.scale * scale + Vector2(padding.x+padding.z, padding.y+padding.w)
	var has: bool = Rect2(top_left, padded_size).has_point(get_global_mouse_position())
	#if has: glob.consume_input(self, "conn_mouse_inside")
	return has

func reposition_splines():
	for id in outputs.keys():
		var spline = outputs[id]
		if is_instance_valid(spline.tied_to):
			spline.update_points(spline.origin.get_origin(), spline.tied_to.get_origin(), dir_vector, spline.tied_to.dir_vector)
	for spline in inputs.keys():
		if is_instance_valid(spline.origin) and is_instance_valid(spline.tied_to):
			spline.update_points(spline.origin.get_origin(), spline.tied_to.get_origin(), spline.origin.dir_vector, dir_vector)

func add_spline() -> int:
	
	var slot = randi_range(111111,999999)
	var spline = glob.get_spline(self)
	spline.turn_into(keyword)
	spline.origin = self
	key_by_spline[spline] = slot
	outputs[slot] = spline
	return slot

var key_by_spline: Dictionary[Spline, int] = {}
func start_spline(id: int):
	var spline = outputs[id]
	var node = spline.tied_to
	if is_instance_valid(node):
		node.inputs.erase(spline)
	spline.tied_to = null
	parent_graph.active_output_connections[self] = true
	spline.show()
	graphs.conns_active[self] = true
	active_outputs[id] = spline

func end_spline(id, hide: bool = true):
	if hide:
		var spline
		if id is int:
			if not id in outputs: return
			spline = outputs[id]
		else:
			spline = id; id = key_by_spline[id]
		var node = spline.tied_to
		if node:
			node.detatch_spline(spline)
		spline.disappear()
		key_by_spline.erase(spline)
		if is_instance_valid(node):
			node.forget_spline(spline, self)
		outputs.erase(id)
	active_outputs.erase(id)
	graphs.conns_active.erase(self)
	parent_graph.hold_for_frame()

func forget_spline(spline: Spline, from_conn: Connection):
	inputs.erase(spline)
	connected.erase(from_conn)

var last_connected: Spline = null
func attach_spline(id: int, target: Connection):
	var spline = active_outputs[id]
	spline.tied_to = target
	target.connected[self] = true
	conn_counts.get_or_add(target.conn_count_keyword, [0])[0] += 1
	target.inputs[spline] = id
	target.last_connected = spline
	spline.update_points(spline.origin.get_origin(), target.get_origin(), dir_vector, target.dir_vector)
	glob.hovered_connection = target
	_stylize_spline(spline, true, true)
	glob.hovered_connection = null
	graphs.attach_edge(self, target)
	parent_graph.just_connected(self, target)
	target.parent_graph.just_attached(self, target)
	end_spline(id, false)

var conn_id: int = 0
func _init() -> void:
	conn_id = randi_range(0,99999999)

func detatch_spline(spline: Spline):
	var other = spline.origin
	other.parent_graph.disconnecting(other, self)
	if not other.outputs.has(inputs[spline]): 
		return
	other.conn_counts.get_or_add(conn_count_keyword, [1])[0] -= 1
	other.start_spline(inputs[spline])
	graphs.remove_edge(spline.origin, spline.tied_to)
	forget_spline(spline, other)
	other.parent_graph.just_disconnected(other, self)


var conn_counts: Dictionary = {&"": [0]}
func _ready() -> void:
	if !Engine.is_editor_hint() and parent_graph:
		parent_graph.add_connection(self)

func _exit_tree() -> void:
	delete()
	if !Engine.is_editor_hint() and parent_graph:
		parent_graph.conn_exit(self)

func get_origin() -> Vector2:
	var global_rect = get_global_rect().size
	var dir: Vector2 = Vector2()
	if is_zero_approx(dir_vector.x):
		dir.x = global_rect.x / 2
	elif dir_vector.x > 0.0:
		dir.x = global_rect.x
	else:
		dir.x = 0.0
	
	if is_zero_approx(dir_vector.y):
		dir.y = global_rect.y / 2
	elif dir_vector.y > 0.0:
		dir.y = global_rect.y
	else:
		dir.y = 0.0
	return global_position + dir

func _is_suitable(conn: Connection) -> bool: return true # virtual

@export var conn_count_keyword: String = ""

func _accepts(conn: Connection) -> bool:
	if conn.keyword == "activ" and keyword == "activ": return false
	return true

const default_max_splines: int = 1
func multiple(conn: Connection) -> bool:
	var kw: StringName = conn.conn_count_keyword
	var allowed: int = default_max_splines
	if max_splines_by_keyword.has(kw):
		allowed = int(max(1, max_splines_by_keyword[kw]))
	var cur_arr = conn_counts.get_or_add(kw, [0])
	var cur: int = int(cur_arr[0])
	return cur < allowed

func is_suitable(conn: Connection) -> bool:
#	print((!conn.accepted_datatypes or conn.accepted_datatypes.has(datatype)))
	return (conn and conn != self and conn.connection_type == INPUT
		and (!conn.accepted_datatypes or conn.accepted_datatypes.has(datatype))
		and not conn.connected.has(self) and (conn.multiple_splines or len(conn.inputs) == 0 or conn.conn_count_keyword == &"router")
		and multiple(conn) #conn_counts.get_or_add(conn.conn_count_keyword, [0])[0] < 1 or true or conn.conn_count_keyword == &"router"
		and graphs.validate_acyclic_edge(self, conn)
		and conn._accepts(self)
		and _is_suitable(conn))

@export var gradient_color: Color = Color.WHITE

func _stylize_spline(spline: Spline, hovered_suitable: bool, finalize: bool = false):
	
	if hovered_suitable:
		spline.modulate = Color(1.1, 1.1, 1.1)
		spline.turn_into(keyword, glob.hovered_connection.keyword)
		spline.color_a = spline.origin.gradient_color
	else:
		spline.modulate = Color(0.8,0.8,0.8)
		spline.turn_into(keyword)
		spline.color_a = Color.WHITE
	if hovered_suitable:
		spline.color_b = glob.hovered_connection.gradient_color
	else:
		spline.color_b = Color.WHITE
	if finalize: spline.modulate.a = 1.0
	else: spline.modulate.a = 0.7

var hovered: bool = false
var prog: float = 0.0
func hover():
	hovered = true
@onready var base_modulate = modulate

var low = {"detatch": true, "edit_graph": true}
func _process(delta: float) -> void:
	if not visible or not parent_graph.visible:
		return
	var inside = is_mouse_inside()
	
	if active_outputs:
		parent_graph.hold_for_frame()
	
	if connection_type == INPUT:
		if inside:
			parent_graph.hold_for_frame()
			if not is_instance_valid(glob.hovered_connection):
				glob.hovered_connection = self
		elif glob.hovered_connection == self:
			glob.hovered_connection = null
	#print(glob.hovered_connection)

	#if not inside and not active_outputs:
		#return

	mouse_pressed = glob.mouse_pressed
	var not_occ = not glob.is_occupied(self, &"menu") and not glob.is_occupied(self, &"graph")
	mouse_just_pressed = glob.mouse_just_pressed and not_occ
	var unpadded = is_mouse_inside(unpadded_area)
	
	if unpadded:
		glob.set_menu_type(self, "detatch", low)
	else:
		glob.reset_menu_type(self, "detatch")

	var occ = glob.is_occupied(self, "conn_active")
	#if connection_type == OUTPUT:
	#	print(glob.is_occupied(self, &"menu_inside"))
	if connection_type == OUTPUT and inside and not occ:
		if mouse_just_pressed:
			if not glob.is_occupied(self, &"menu_inside") and not graphs.conns_active: # TODO: implement router splines
				var nspline = add_spline()
				start_spline(nspline)
				glob.activate_spline(outputs[nspline])
			#elif !multiple_splines and outputs:
				#outputs[0].tied_to.detatch_spline(outputs[0])
		elif glob.mouse_alt_just_pressed and inside:
			glob.menus["detatch"].show_up(outputs, self)

	if connection_type == INPUT and inside and not occ:
		if glob.mouse_alt_just_pressed and inside:
			glob.menus["detatch"].show_up(inputs, self)
		elif mouse_just_pressed and inputs:
			var detatch = inputs.keys()[-1]
			glob.activate_spline(detatch)
			detatch_spline(detatch)

	var to_end = []
	var to_attach = []
	if active_outputs:
		glob.occupy(self, &"conn_active")
	else:
		glob.un_occupy(self, &"conn_active")
	
	if hovered:
		#print("f")
		prog = 0
		modulate = modulate.lerp(Color(1.5, 1.5, 1.5), delta * 23.0)
	elif prog < 0.95:
		prog = lerpf(prog, 1, delta * 23.0)
		if prog < 0.95: modulate = modulate.lerp(base_modulate, delta * 23.0)
		else: modulate = base_modulate
	
	var suit
	if active_outputs:
		suit = is_suitable(glob.hovered_connection)
		#if glob.hovered_connection:
			#print(suit)
		parent_graph.active_output_connections[self] = true
		parent_graph.hold_for_frame()
	else:
		parent_graph.active_output_connections.erase(self)
	for id in active_outputs:
		var spline = active_outputs[id]
		# update using the splines origin
		spline.update_points(spline.origin.get_origin(), get_global_mouse_position(), dir_vector)
		
		if not mouse_pressed:
			if suit:
				glob.occupy(glob.hovered_connection, &"conn_active")
				to_attach.append(id)
			else:
				if glob.hovered_connection:
					glob.hovered_connection.parent_graph.hold_for_frame()
				glob.un_occupy(glob.hovered_connection, &"conn_active")
				to_end.append(id)
		#print(spline.tied_to)
		_stylize_spline(spline, suit)
	
	#if connection_type == OUTPUT and !active_outputs.is_empty():
		#print(suit)
	if suit and active_outputs:
		glob.hovered_connection.hover()
	

	for id in to_end:
		end_spline(id)
	for id in to_attach:
		glob.deactivate_spline(outputs[id])
		attach_spline(id, glob.hovered_connection)

	hovered = false

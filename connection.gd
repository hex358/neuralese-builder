extends ColorRect
class_name Connection

static var INPUT: int = 0
static var OUTPUT: int = 1



@export var hint: int = 0
@export var keyword: StringName = &""
@export_enum("Input", "Output") var connection_type: int = INPUT
@export var area_paddings: Vector4 = Vector4(10,10,10,10)
@export var multiple_splines: bool = false
@export var origin_offset: Vector2 = Vector2()

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
		for i in inputs.duplicate():
			detatch_spline(i)
	else:
		for i in outputs.duplicate():
			outputs[i].tied_to.detatch_spline(outputs[i])

func is_mouse_inside(padding:Vector4=area_paddings) -> bool:
	# padded hit area
	var top_left = global_position - Vector2(padding.x, padding.y) * parent_graph.scale * scale
	var padded_size = size * parent_graph.scale * scale + Vector2(padding.x+padding.z, padding.y+padding.w)
	return Rect2(top_left, padded_size).has_point(get_global_mouse_position())

func reposition_splines():
	for id in outputs.keys():
		var spline = outputs[id]
		if is_instance_valid(spline.tied_to):
			spline.update_points(spline.origin.get_origin(), spline.tied_to.get_origin(), dir_vector, spline.tied_to.dir_vector)
	for spline in inputs.keys():
		if is_instance_valid(spline.origin) and is_instance_valid(spline.tied_to):
			spline.update_points(spline.origin.get_origin(), spline.tied_to.get_origin(), spline.origin.dir_vector, dir_vector)

func add_spline() -> int:
	var slot = len(outputs)
	var spline = glob.get_spline(self, &"weight")
	spline.origin = self
	outputs[slot] = spline
	return slot

func start_spline(id: int):
	var spline = outputs[id]
	var node = spline.tied_to
	if is_instance_valid(node):
		node.inputs.erase(spline)
	spline.tied_to = null
	spline.show()
	active_outputs[id] = spline

func end_spline(id: int, hide: bool = true):
	if hide:
		var spline = outputs[id]
		var node = spline.tied_to
		spline.disappear()
		if is_instance_valid(node):
			node.forget_spline(spline, self)
		outputs.erase(id)
	active_outputs.erase(id)

func forget_spline(spline: Spline, from_conn: Connection):
	inputs.erase(spline)
	connected.erase(from_conn)

var last_connected: Spline = null
func attach_spline(id: int, target: Connection):
	var spline = active_outputs[id]
	spline.tied_to = target
	target.connected[self] = true
	target.inputs[spline] = id
	target.last_connected = spline
	spline.update_points(spline.origin.get_origin(), target.get_origin(), dir_vector, target.dir_vector)
	end_spline(id, false)

func detatch_spline(spline: Spline):
	var other = spline.origin
	other.start_spline(inputs[spline])
	forget_spline(spline, other)

func remove_input_spline(spline: Spline):
	# call end_spline on the origin of that spline
	spline.origin.end_spline(inputs[spline])

func _ready() -> void:
	if !Engine.is_editor_hint() and parent_graph:
		parent_graph.add_connection(self)

func get_origin() -> Vector2:
	return global_position + (origin_offset + size / 2) * scale

func _is_suitable(conn: Connection) -> bool: return true # virtual

func is_suitable(conn: Connection) -> bool:
	#print(len(outputs))
	return (conn and conn != self and conn.connection_type == INPUT
		and not conn.connected.has(self) and (conn.multiple_splines or len(conn.inputs) == 0)
		and (len(outputs) <= 1 or multiple_splines or conn.keyword == &"router")
		and _is_suitable(conn))

func _stylize_spline(spline: Spline):
	pass

var hovered: bool = false
var prog: float = 0.0
func hover():
	hovered = true
@onready var base_modulate = modulate

var low = {"detatch": true, "edit_graph": true}
func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return

	mouse_pressed = glob.mouse_pressed
	var not_occ = not glob.is_occupied(self, &"menu") and not glob.is_occupied(self, &"graph")
	mouse_just_pressed = glob.mouse_just_pressed and not_occ
	var inside = is_mouse_inside()
	
	if inside:
		glob.set_menu_type(self, "detatch", low)
	else:
		glob.reset_menu_type(self, "detatch")

	if inside:
		if not is_instance_valid(glob.hovered_connection):
			glob.hovered_connection = self
	elif glob.hovered_connection == self:
		glob.hovered_connection = null

	var occ = glob.is_occupied(self, "conn_active")
	if connection_type == OUTPUT and inside and not occ:
		if mouse_just_pressed:
			if 1: # TODO: implement router splines
				start_spline(add_spline())
			#elif !multiple_splines and outputs:
				#outputs[0].tied_to.detatch_spline(outputs[0])
		elif glob.mouse_alt_just_pressed and inside:
			glob.menus["detatch"].show_up(outputs, self)

	if connection_type == INPUT and inside and not occ:
		if glob.mouse_alt_just_pressed and inside:
			glob.menus["detatch"].show_up(inputs, self)
		elif mouse_just_pressed and inputs:
			detatch_spline(inputs.keys()[-1])

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
	for id in active_outputs:
		var spline = active_outputs[id]
		# live update using the splines origin
		spline.update_points(spline.origin.get_origin(), get_global_mouse_position(), dir_vector)
		
		if not mouse_pressed:
			if suit:
				glob.occupy(glob.hovered_connection, &"conn_active")
				to_attach.append(id)
			else:
				glob.un_occupy(glob.hovered_connection, &"conn_active")
				to_end.append(id)
	if suit and active_outputs:
		glob.hovered_connection.hover()

	for id in to_end:
		end_spline(id)
	for id in to_attach:
		attach_spline(id, glob.hovered_connection)

	hovered = false

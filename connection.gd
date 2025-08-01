extends ColorRect
class_name Connection

static var INPUT: int = 0
static var OUTPUT: int = 1

@export var hint: int = 0
@export_enum("Input", "Output") var connection_type: int = INPUT
@export var area_padding: float = 10.0
@export var multiple_splines: bool = false

@onready var parent_graph: Graph = get_parent()
# @onready var spline = glob.get_spline(self) if connection_type == OUTPUT else null

var outputs: Dictionary[int, Spline] = {}
var active_outputs: Dictionary[int, Spline] = {}
var inputs: Dictionary[Spline, int] = {}
var connected: Dictionary[Connection, bool] = {}

var mouse_just_pressed: bool = false
var mouse_pressed: bool = false

func is_mouse_inside() -> bool:
	# padded hit area
	var top_left = global_position - Vector2.ONE * area_padding * parent_graph.scale * scale
	var padded_size = size + Vector2(area_padding, area_padding) * 2
	return Rect2(top_left, padded_size).has_point(get_global_mouse_position())

func reposition_splines():
	for id in outputs.keys():
		var spline = outputs[id]
		if is_instance_valid(spline.tied_to):
			spline.update_points(spline.origin.get_origin(), spline.tied_to.get_origin())
	for spline in inputs.keys():
		if is_instance_valid(spline.origin) and is_instance_valid(spline.tied_to):
			spline.update_points(spline.origin.get_origin(), spline.tied_to.get_origin())

func add_spline() -> int:
	var slot = glob.free_slot()
	var spline = glob.get_spline(self)
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
		var spline = active_outputs[id]
		var node = spline.tied_to
		spline.disappear()
		if is_instance_valid(node):
			forget_spline(spline, node)
		outputs.erase(id)
	active_outputs.erase(id)

func forget_spline(spline: Spline, other_node: Connection):
	other_node.inputs.erase(spline)
	other_node.connected.erase(self)

func attach_spline(id: int, target: Connection):
	var spline = active_outputs[id]
	spline.update_points(spline.origin.get_origin(), target.get_origin())
	spline.tied_to = target
	target.connected[self] = true
	target.inputs[spline] = id
	end_spline(id, false)

func detatch_spline(spline: Spline):
	var other = spline.origin
	other.start_spline(inputs[spline])
	other.forget_spline(spline, self)

func remove_input_spline(spline: Spline):
	# call end_spline on the origin of that spline
	spline.origin.end_spline(inputs[spline])

func _ready() -> void:
	pass

func get_origin() -> Vector2:
	return global_position + size / 2

func _is_suitable(conn: Connection) -> bool: return true # virtual

func is_suitable(conn: Connection) -> bool:
	return (conn and conn != self and conn.connection_type == INPUT
		and not conn.connected.has(self) and (conn.multiple_splines or len(conn.inputs) == 0)
		and _is_suitable(conn))

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return

	mouse_pressed = glob.mouse_pressed
	mouse_just_pressed = glob.mouse_just_pressed
	var inside = is_mouse_inside()
	if inside:
		glob.set_menu_type(self, "detatch")
	else:
		glob.reset_menu_type(self, "detatch")

	if inside:
		if not is_instance_valid(glob.hovered_connection):
			glob.hovered_connection = self
	elif glob.hovered_connection == self:
		glob.hovered_connection = null

	if connection_type == OUTPUT and inside:
		if glob.mouse_just_pressed and (multiple_splines or len(outputs) == 0):
			start_spline(add_spline())
		elif glob.mouse_alt_just_pressed:
			glob.menus["detatch"].show_up(outputs, self)

	if connection_type == INPUT and inside:
		if glob.mouse_alt_just_pressed:
			glob.menus["detatch"].show_up(inputs, self)
		elif glob.mouse_just_pressed and inputs:
			detatch_spline(inputs.keys()[-1])

	var to_end = []
	var to_attach = []
	for id in active_outputs:
		var spline = active_outputs[id]
		# live update using the spline’s origin
		spline.update_points(spline.origin.get_origin(), get_global_mouse_position())
		if not mouse_pressed:
			if is_suitable(glob.hovered_connection):
				to_attach.append(id)
			else:
				to_end.append(id)

	for id in to_end:
		end_spline(id)
	for id in to_attach:
		attach_spline(id, glob.hovered_connection)

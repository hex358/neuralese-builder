extends ColorRect
class_name Connection

static var INPUT: int = 0
static var OUTPUT: int = 1

@export_enum("Input", "Output") var connection_type: int = INPUT
@export var area_padding: float = 10.0

@onready var parent_graph = get_parent()
# @onready var spline = glob.get_spline(self) if connection_type == OUTPUT else null

var splines: Dictionary[int, Array] = {}
var active_splines: Dictionary[int, Spline] = {}
var inputs: Dictionary[Spline, Array] = {}

var mouse_just_pressed: bool = false
var mouse_pressed: bool = false

func is_mouse_inside() -> bool:
	# padded hit area
	var top_left = global_position - Vector2.ONE * area_padding * parent_graph.scale * scale
	var padded_size = size + Vector2(area_padding, area_padding) * 2
	return Rect2(top_left, padded_size).has_point(get_global_mouse_position())

func reposition_splines():
	for id in splines.keys():
		var target = splines[id][1]
		if is_instance_valid(target):
			splines[id][0].update_points(get_origin(), target.get_origin())
	for spline in inputs.keys():
		spline.update_points(inputs[spline][1].get_origin(), get_origin())

func add_spline() -> int:
	var slot = glob.free_slot()
	splines[slot] = [glob.get_spline(self), null]
	return slot

func start_spline(id: int):
	var spline = splines[id][0]
	var node = splines[id][1]
	if is_instance_valid(node):
		node.inputs.erase(spline)
	splines[id][1] = null
	spline.show()
	active_splines[id] = spline

func end_spline(id: int, hide: bool = true):
	if hide:
		var spline = active_splines[id]
		var node = splines[id][1]
		spline.queue_free()
		if is_instance_valid(node):
			node.inputs.erase(spline)
		splines.erase(id)
	active_splines.erase(id)

func attach_spline(id: int, target: Connection):
	active_splines[id].update_points(get_origin(), target.get_origin())
	splines[id][1] = target
	target.inputs[active_splines[id]] = [id, self]
	end_spline(id, false)

func detatch_spline(spline: Spline):
	inputs[spline][1].start_spline(inputs[spline][0])

func remove_input_spline(spline: Spline):
	inputs[spline][1].end_spline(inputs[spline][0])

func _ready() -> void:
	pass

func get_origin() -> Vector2:
	return global_position + size / 2

func is_suitable(conn: Connection) -> bool:
	return conn and conn != self and conn.connection_type == INPUT

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return

	mouse_pressed = glob.mouse_pressed
	mouse_just_pressed = glob.mouse_just_pressed
	var inside = is_mouse_inside()
	if inside: 
		glob.set_menu_type(self, "detatch")
	else: glob.reset_menu_type(self, "detatch")
	#print(glob.menu_type)

	if inside:
		if not is_instance_valid(glob.hovered_connection):
			glob.hovered_connection = self
	elif glob.hovered_connection == self:
		glob.hovered_connection = null

	if connection_type == OUTPUT and inside:
		if glob.mouse_just_pressed:
			start_spline(add_spline())
		elif glob.mouse_alt_just_pressed and len(splines) > 1:
			# TODO: implement context menu for selecting between different splines
			pass

	if connection_type == INPUT and inside and inputs:
		if len(inputs) > 1:
			if glob.mouse_just_pressed or glob.mouse_alt_just_pressed:
				# TODO: implement context menu for selecting between different splines to disconnect
				pass
		elif glob.mouse_just_pressed:
			detatch_spline(inputs.keys()[0])

	var to_end = []
	var to_attach = []
	for id in active_splines:
		active_splines[id].update_points(get_origin(), get_global_mouse_position())
		if not mouse_pressed:
			if is_suitable(glob.hovered_connection):
				to_attach.append(id)
			else:
				to_end.append(id)

	for id in to_end:
		end_spline(id)
	for id in to_attach:
		attach_spline(id, glob.hovered_connection)

extends ColorRect
class_name Connection

# connection types
@export_enum("Input", "Output") var connection_type: int = 0

@export var area_padding: float = 10.0

@onready var parent_graph = get_parent()
@onready var spline = glob.get_spline(self) if (connection_type == 1) else null

# spline for each emiting output
var splines = {}
# state
var spline_active = false
var mouse_pressed = false
var input_from: Connection = null
var output_to: Connection = null

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return

	mouse_pressed = Input.is_action_pressed("ui_mouse")
	var inside = is_mouse_inside()
	if inside:
		glob.hovered_connection = self
	elif glob.hovered_connection == self:
		glob.hovered_connection = null

	handle_start_spline(inside)
	if spline_active:
		_update_spline()


func handle_start_spline(mouse_inside: bool) -> void:
	# only start on click inside and no active spline
	if not mouse_inside or not Input.is_action_just_pressed("ui_mouse") or glob.spline_connection != null:
		return

	# begin from connectors
	if connection_type == 1 and output_to == null:
		_start_spline(self)
	elif connection_type == 0 and input_from != null:
		# reconnect from existing input
		_start_spline(input_from)
		input_from.output_to = null

func _start_spline(conn: Connection) -> void:
	glob.spline_connection = conn
	conn.show_spline()

func _update_spline() -> void:
	if mouse_pressed:
		spline.points = PackedVector2Array([get_origin(), get_global_mouse_position()])
	else:
		_finish_spline()

func _finish_spline() -> void:
	var target = glob.hovered_connection
	if is_suitable(target):
		connect_to_input(target)
		connect_with_output(target)
	else:
		hide_spline()

func is_mouse_inside() -> bool:
	# padded hit area
	var top_left = global_position - Vector2(area_padding, area_padding)
	var padded_size = size + Vector2(area_padding, area_padding)
	var bounds = Rect2(top_left, padded_size)
	return bounds.has_point(get_global_mouse_position())

func get_origin() -> Vector2:
	return global_position + size / 2

func show_spline() -> void:
	spline.show()
	spline_active = true

func hide_spline() -> void:
	spline.hide()
	_disable_spline()

func _disable_spline() -> void:
	spline_active = false
	glob.spline_connection = null
	glob.hovered_connection = null

func is_suitable(target: Connection) -> bool:
	return target != null and target != self and target.connection_type == 0 and _is_suitable(target)

# override for custom validation
func _is_suitable(target: Connection) -> bool:
	return true

func connect_to_input(target: Connection) -> void:
	_disable_spline()
	# establish connection
	target.connect_with_output(self)
	output_to = target
	spline.points = PackedVector2Array([get_origin(), target.get_origin()])
	_connect_to_input(target)

func connect_with_output(from: Connection) -> void:
	input_from = from
	_connect_with_output(from)

# virtual callbacks
func _connect_to_input(target: Connection) -> void: pass
func _connect_with_output(from: Connection) -> void: pass

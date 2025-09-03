extends BaseNeuronLayer

@export var group_size: int = 5:
	set(v):
		group_size = v
		set_grid(grid.x, grid.y)

@export var grid: Vector2i = Vector2i(1, 1):
	set(v):
		grid = v
		set_grid(grid.x, grid.y)

@export var grid_padding: float = 5.0:
	set(v):
		grid_padding = v
		set_grid(grid.x, grid.y)

@export var offset: Vector2 = Vector2():
	set(v):
		offset = v
		set_grid(grid.x, grid.y)

@export var size_add_vec: Vector2 = Vector2():
	set(v):
		size_add_vec = v
		set_grid(grid.x, grid.y)

func _just_connected(who: Connection, to: Connection):
	if to.parent_graph.server_typename == "Flatten":
		to.parent_graph.set_count(grid.x * grid.y)

var current_units: Array[Control] = []
var _pool: Array[Control] = []
var _fading_in: Dictionary[Control, bool] = {}
var _fading_out: Dictionary[Control, bool] = {}

var grid_current: Vector2i = Vector2i.ZERO
var _cells: Dictionary = {}

# sizing
var biggest_size_possible: Vector2 = Vector2()
@onready var target_size_vec: Vector2 = rect.size

func useful_properties() -> Dictionary:
	var conf = {"activation": "none"}
	if 0 in input_keys:
		var ik = input_keys[0]
		if ik and ik.inputs and ik.inputs.size() > 0:
			var first_key = ik.inputs.keys()[0]
			if first_key and first_key.origin and first_key.origin.parent_graph:
				conf["activation"] = first_key.origin.parent_graph.selected_activation
	return {
		"neuron_count": grid.x * grid.y,
		"config": conf,
		"cache_tag": str(graph_id)
	}

@onready var base_output_offset = $o.position - rect.size
@onready var base_input_offset = $ni.position
@onready var base_activ_offset = $activ.position

func _after_ready() -> void:
	super()
	await get_tree().process_frame
	set_grid(grid.x, grid.y)
	_size_changed()

@export var label_offset: float = 25.0
func _size_changed() -> void:
	$o.position = Vector2(
		base_output_offset.x + rect.size.x,
		rect.size.y / 2.0 + rect.position.y - $o.size.y / 2.0
	)
	$ni.position = Vector2(
		base_input_offset.x,
		rect.size.y / 2.0 + rect.position.y - $ni.size.y / 2.0
	)
	$activ.position = Vector2(
		rect.size.x / 2.0 - $activ.size.x / 2.0 + rect.position.x,
		base_activ_offset.y
	)
	var label = $ColorRect/root/Label
	label.position.x = rect.size.x / 2.0 - label_offset
	reposition_splines()
	hold_for_frame()

func get_unit(_kw: Dictionary) -> Control:
	var u: Control = _pool.pop_back() if _pool.size() > 0 else _unit.duplicate()
	u.visible = true
	u.modulate.a = 0.0
	if u.get_parent() == null:
		add_child(u)
	_fading_in[u] = true
	return u

func _after_process(delta: float) -> void:
	super(delta)

	recompute_biggest_size_possible()

	for u in _fading_in.keys():
		if rect.size.x > biggest_size_possible.x-1.0:
			pass
		else:
			u.modulate.a = 0.0; u.hide(); continue
		var u_rect = u.get_global_rect()
		var m = u.modulate
		u.show()
		m.a = lerp(m.a, 1.0, delta * 5.0)
		u.modulate = m
		if m.a >= 0.9:
			u.modulate.a = 1.0
			_fading_in.erase(u)
	
	for u in _fading_out.keys():
		u.modulate.a = lerp(u.modulate.a, 0.0, delta * 30.0)
		if u.modulate.a <= 0.1:
			_fading_out.erase(u)
			u.queue_free()

	var target: Vector2 = target_size_vec.max(biggest_size_possible)
	var prev_size = rect.size
	rect.size = rect.size.lerp(target, delta * 20.0)
	if prev_size.distance_squared_to(rect.size) > 0.02:
		_size_changed()

func update_grid(x: int, y: int):
	grid.x = x
	grid.y = y

func set_grid(x: int, y: int) -> void:
	if not is_node_ready():
		await ready
	var columns = int(ceil(x / float(group_size)))
	var rows = int(ceil(y / float(group_size)))
	visualise_grid(max(columns, 1), max(rows, 1))
	hold_for_frame()


func _add_cell(i: int, j: int) -> void:
	var key = Vector2i(i, j)
	if _cells.has(key):
		return
	var u = get_unit({})
	u.modulate.a = 0.0
	_cells[key] = u
	_index_by_unit[u] = key
	_fading_in[u] = true
	_fading_out.erase(u)

func _remove_cell(i: int, j: int) -> void:
	var key = Vector2i(i, j)
	if not _cells.has(key):
		return
	var u: Control = _cells[key]
	_cells.erase(key)
	_fading_out[u] = true
	_fading_in.erase(u)

var _index_by_unit: Dictionary = {}
func recompute_biggest_size_possible() -> void:
	var max_i = -1
	var max_j = -1

	for key in _cells.keys():
		var ij: Vector2i = key
		var u: Control = _cells[key]
		if u:# and u.visible:
			if ij.x > max_i: max_i = ij.x
			if ij.y > max_j: max_j = ij.y

	for u in _fading_out.keys():
		if not u: continue
		#if !u.visible: continue
		if _index_by_unit.has(u):
			var ij: Vector2i = _index_by_unit[u]
			if ij.x > max_i: max_i = ij.x
			if ij.y > max_j: max_j = ij.y

	if max_i < 0 or max_j < 0:
		biggest_size_possible = Vector2.ZERO
		return

	var unit_size = _unit.size
	var width  = (max_i + 1) * (unit_size.x + grid_padding) + offset.x + size_add_vec.x
	var height = (max_j + 1) * (unit_size.y + grid_padding) + offset.y + size_add_vec.y
	biggest_size_possible = Vector2(width, height)


func visualise_grid(columns: int, rows: int) -> void:
	var old_x: int = grid_current.x
	var old_y: int = grid_current.y

	if columns > old_x:
		for i in range(old_x, columns):
			for j in range(0, rows):
				_add_cell(i, j)

	if rows > old_y:
		var max_old_cols = min(old_x, columns)
		for j in range(old_y, rows):
			for i in range(0, max_old_cols):
				_add_cell(i, j)

	if columns < old_x:
		for i in range(columns, old_x):
			for j in range(0, old_y):
				_remove_cell(i, j)

	if rows < old_y:
		var max_new_cols = min(columns, old_x)
		for j in range(rows, old_y):
			for i in range(0, max_new_cols):
				_remove_cell(i, j)

	grid_current = Vector2i(columns, rows)

	var unit_size = _unit.size
	for i in range(0, columns):
		for j in range(0, rows):
			var key = Vector2i(i, j)
			if _cells.has(key):
				var u: Control = _cells[key]
				u.position.x = i * (unit_size.x + grid_padding) + offset.x
				u.position.y = j * (unit_size.y + grid_padding) + offset.y

	target_size_vec.y = rows * (unit_size.y + grid_padding) + size_add_vec.y + offset.y
	target_size_vec.x = columns * (unit_size.x + grid_padding) + size_add_vec.x + offset.x
	_size_changed()

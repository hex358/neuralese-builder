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
	graphs.push_2d(grid.x, grid.y, to.parent_graph)

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
	size_changed()
	$filter.size = Vector2()
	$filter2.size = Vector2()

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
	set_extents()
	var label = $ColorRect/root/Label
	label.position.x = rect.size.x / 2.0 - label_offset
	reposition_splines()
	hold_for_frame()

func _dragged():
	set_extents()

func set_extents():
	if not Vector2i() in _cells: return
	var rect_end: Vector2 = Vector2.ONE * max_displayed * \
	(_unit.size + grid_padding*Vector2.ONE) + _cells[Vector2i()].global_position
	for j in _cells:
		var i = _cells[j]
		if j.x >= max_displayed-1 or j.y >= max_displayed-1: pass
		else: continue
		var unit_rect = i.get_node("ColorRect5")
		glob.inst_uniform(unit_rect, "extents", 
		Vector4(0.0, rect_end.y - 2.0,
		0.0, rect_end.x- 2.0))

func get_unit(_kw: Dictionary) -> Control:
	var u: Control = _pool.pop_back() if _pool.size() > 0 else _unit.duplicate()
	u.visible = true
	u.modulate.a = 0.0
	if u.get_parent() == null:
		add_child(u)
	_fading_in[u] = true
	return u

@export var max_size: Vector2 = Vector2()
@export var outline_padding: float = 1.0

func recompute_filter():
	if !grid.x or !grid.y: 
		target_filter_size = Vector2()
		target_filter2_size = Vector2()
		return
	var arr = get_filter_cells(Vector2i(0,0), kernel_size)
	if arr:
		$filter.position = arr[0].position
		target_filter_size = ((arr[1].position+arr[1].get_global_rect().size
		)-$filter.position+Vector2(0.5,0.5))/$filter.scale
	arr = get_filter_cells(Vector2i(stride,0), kernel_size)
	if arr:
		target_filter2_pos = arr[0].position
		target_filter2_size = ((arr[1].position+arr[1].get_global_rect().size
		)-arr[0].position+Vector2(0.5,0.5))/$filter2.scale
	elif ceil(grid.x/group_size) < 1:
		target_filter2_size = Vector2()



func get_filter_cells(origin: Vector2i, kernel_size: Vector2i):
	var first_cell = _cells.get(origin)
	var kernel_end: Vector2i = origin+kernel_size
	if (grid.x-1)/group_size < kernel_end.x: 
		kernel_end.x = (grid.x-1)/group_size
	if (grid.y-1)/group_size < kernel_end.y: 
		kernel_end.y = (grid.y-1)/group_size
	if first_cell and not first_cell in _fading_in and kernel_end in _cells and not _cells[kernel_end] in _fading_in:
		return [first_cell, _cells[kernel_end]]
	return []

func _can_drag() -> bool:
	return not ui.is_focus($LineEdit)

var prev_kernel: Vector2i = kernel_size
func _proceed_hold() -> bool:
	var a = !glob.is_vec_approx($filter.size, target_filter_size) \
	or !glob.is_vec_approx($filter2.position, target_filter2_pos)
	return a

var target_filter_size: Vector2 = Vector2()
var target_filter2_size: Vector2 = Vector2()
var target_filter2_pos: Vector2 = Vector2()
@export var kernel_size: Vector2i = Vector2i():
	set(v):
		kernel_size = v
		hold_for_frame()
@export var stride: int = 2:
	set(v):
		stride = v
		hold_for_frame()
func _after_process(delta: float) -> void:
	super(delta)
	
	recompute_biggest_size_possible()
	recompute_filter()
	
	$filter.size = $filter.size.lerp(target_filter_size, delta * 20.0)
	$filter2.size = $filter2.size.lerp(target_filter2_size, delta * 20.0)
	$filter2.position = $filter2.position.lerp(target_filter2_pos, delta * 20.0)
	
	for u in _fading_in.keys():
		if rect.size.x > biggest_size_possible.x-grid_padding\
		 and rect.size.y > biggest_size_possible.y-grid_padding:
			pass
		else:
			u.modulate.a = 0.0; u.hide(); continue
		var u_rect = u.get_global_rect()
		var m = u.modulate
		u.show()
		hold_for_frame()
		m.a = lerp(m.a, 1.0, delta * 15.0)
		u.modulate = m
		if m.a >= 0.9:
			u.modulate.a = 1.0
			_fading_in.erase(u)
	
	for u in _fading_out.keys():
		u.modulate.a = lerp(u.modulate.a, 0.0, delta * 15.0)
		hold_for_frame()
		if u.modulate.a <= 0.1:
			_fading_out.erase(u)
			_cells.erase(u.get_meta("coord"))
			u.queue_free()
	var target: Vector2 = target_size_vec.max(biggest_size_possible)
	if max_size:
		target = target.max(max_size)
	var prev_size = rect.size
	rect.size = rect.size.lerp(target, delta * 15.0)
	if !glob.is_vec_approx(prev_size,rect.size):
		size_changed()

func update_grid(x: int, y: int):
	grid.x = x
	grid.y = y
	graphs.push_2d(grid.x, grid.y, get_first_descendants())

@export var max_displayed: int = 4
func set_grid(x: int, y: int) -> void:
	if not is_node_ready():
		await ready
	var columns = int(ceil(x / float(group_size)))
	var rows = int(ceil(y / float(group_size)))
	if columns > max_displayed: columns = max_displayed
	if rows > max_displayed: rows = max_displayed
	visualise_grid(columns, rows)
	hold_for_frame()


func _add_cell(i: int, j: int) -> void:
	var key = Vector2i(i, j)
	if _cells.has(key):
		return
	var u = get_unit({})
	u.modulate.a = 0.0
	_cells[key] = u
	u.set_meta("coord", Vector2i(i, j))
	_index_by_unit[u] = key
	_fading_in[u] = true
	_fading_out.erase(u)

func _remove_cell(i: int, j: int) -> void:
	var key = Vector2i(i, j)
	#if not _cells.has(key):
		#return
	var u: Control = _cells[key]
	#_cells.erase(key)
	_fading_out[u] = true
	_fading_in.erase(u)

var _index_by_unit: Dictionary = {}

func recompute_biggest_size_possible() -> void:
	if _cells.is_empty() and _fading_out.is_empty():
		biggest_size_possible = Vector2.ZERO
		return

	var unit_size = _unit.size
	var max_right = 0.0
	var max_bottom = 0.0

	for key in _cells.keys():
		var u: Control = _cells.get(key)
		if not u: continue
		var r = u.position.x + unit_size.x + grid_padding
		var b = u.position.y + unit_size.y + grid_padding
		if r > max_right: max_right = r
		if b > max_bottom: max_bottom = b

	for u in _fading_out.keys():
		if not u: continue
		var r = u.position.x + unit_size.x + grid_padding
		var b = u.position.y + unit_size.y + grid_padding
		if r > max_right: max_right = r
		if b > max_bottom: max_bottom = b
	
	biggest_size_possible = Vector2(max_right, max_bottom) + size_add_vec


func visualise_grid(columns: int, rows: int) -> void:
	var old_x: int = grid_current.x
	var old_y: int = grid_current.y
	if columns == 0 or rows == 0:
		for i in range(old_x):
			for j in range(old_y):
				_remove_cell(i, j)

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
	size_changed()

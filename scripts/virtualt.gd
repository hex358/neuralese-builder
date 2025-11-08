extends Control
class_name VirtualTable

@export var vscrollbar: VScrollBar
@export var grid_line_color: Color = Color(1, 1, 1, 0.15)
@export var odd_row_tint: Color = Color(1, 1, 1, 0.04)
@export var grid_line_thickness: float = 1.0
@export var scroll_spawn_delay: float = 0.1
var _last_scroll_y: float = 0.0
@export var spawn_delay_threshold: float = 256.0
var _scroll_dirty: bool = false
var _scroll_cooldown: float = 0.0
@onready var _content_area: Control = Control.new()
const max_pool: int = 256
@export var content_margin: Vector4 = Vector4(4, 4, 4, 4)

@export var column_ratios: PackedFloat32Array = PackedFloat32Array([])
@export var hscrollbar: HScrollBar
enum ColumnWidthMode { FIT, RELAXED, FIXED }
@export var column_width_mode: ColumnWidthMode = ColumnWidthMode.RELAXED
@export_range(0.1, 3.0, 0.1) var max_total_width_scale: float = 1.25
@export_range(0.1, 3.0, 0.1) var min_total_column_ratio: float = 1.0
@export_range(10.0, 2000.0, 1.0) var min_column_width: float = 48.0



var default_type_heights: Dictionary[StringName, float] = {}

var cell_templates: Dictionary[StringName, PackedScene] = {
	"text": preload("res://scenes/cell.tscn")
}
var cell_defaults: Dictionary[StringName, TableCell] = {}

func _enter_tree() -> void:
	for i in cell_templates:
		cell_defaults[i] = cell_templates[i].instantiate()
		default_type_heights[i] = cell_defaults[i].height

var dataset: Array = []
var rows: int = 0
var cols: int = 0

var active_cells: Dictionary = {}

var pool_by_type: Dictionary = {}

var row_heights: PackedFloat32Array = PackedFloat32Array([])
var row_offsets: PackedFloat32Array = PackedFloat32Array([])

var col_widths: PackedFloat32Array = PackedFloat32Array([])
var col_offsets: PackedFloat32Array = PackedFloat32Array([])

var scroll_y: float = 0.0
var scroll_speed_wheel: float = 48.0

var _need_layout: bool = true
var _need_visible_refresh: bool = true

func _update_content_area_rect() -> void:
	if not is_instance_valid(_content_area):
		return

	var left = content_margin.x
	var top = content_margin.y
	var right = content_margin.z
	var bottom = content_margin.w

	_content_area.position = Vector2(left, top)

	# --- Fix ---
	# When RELAXED: do NOT recompute width from size.x.
	# Keep the current width (so columns never contract).
	# For other modes: use control size normally.
	var new_width: float = _content_area.size.x
	if column_width_mode != ColumnWidthMode.RELAXED:
		new_width = size.x - (left + right)

	_content_area.size = Vector2(new_width, size.y - (top + bottom))


#



func _ready() -> void:
	#_content_area.clip_contents = true
	add_child(_content_area)
	_update_content_area_rect()

	if vscrollbar:
		move_child(vscrollbar, -1)
		vscrollbar.scale.x = 1.5
		#vscrollbar.offset_left = vscrollbar.size.x
		vscrollbar.position.x -= vscrollbar.size.x * 0.5
		vscrollbar.value_changed.connect(_on_vscrollbar_value_changed)

	if hscrollbar:
		move_child(hscrollbar, -1)
		hscrollbar.scale.y = 1.5
		hscrollbar.position.y -= hscrollbar.size.y * 0.5
		hscrollbar.value_changed.connect(_on_hscrollbar_value_changed)


func _update_hscrollbar_range() -> void:
	if not hscrollbar:
		return

	var content_w: float = col_offsets[cols]
	var view_w: float = size.x - (content_margin.x + content_margin.z)

	hscrollbar.min_value = 0.0
	hscrollbar.max_value = max(content_w, 0.0)  # TOTAL content width, not scroll_range
	hscrollbar.page = max(view_w, 0.0)

	var max_scroll: float = max(0.0, content_w - view_w)
	scroll_x = clamp(scroll_x, 0.0, max_scroll)
	hscrollbar.set_value_no_signal(scroll_x)

	hscrollbar.visible = content_w > view_w + 1.0




func _set_scroll_x(new_value: float, from_bar: bool = false) -> void:
	var content_w: float = col_offsets[cols]
	var view_w: float = size.x - (content_margin.x + content_margin.z)

	var max_scroll = max(0.0, content_w - view_w)
	var clamped = clamp(new_value, 0.0, max_scroll)

	if abs(clamped - scroll_x) < 0.01:
		return

	scroll_x = clamped
	if hscrollbar and not from_bar:
		hscrollbar.set_value_no_signal(scroll_x)

	_need_layout = true
	queue_redraw()







func _on_hscrollbar_value_changed(value: float) -> void:
	_set_scroll_x(value, true)

var scroll_x: float = 0.0
var scroll_speed_horizontal: float = 48.0



func _on_vscrollbar_value_changed(value: float) -> void:
	_set_scroll_y(value, false)


func _update_scrollbar_range() -> void:
	if not vscrollbar:
		return
	var content_h: float = row_offsets[rows]
	var view_h: float = size.y
	vscrollbar.min_value = 0.0
	vscrollbar.max_value = max(0.0, content_h)
	vscrollbar.page = view_h
	vscrollbar.value = clamp(scroll_y, 0.0, vscrollbar.max_value)

var adapter_data = null
func _adapter_on_load(data, cols: int, rows: int) -> void:
	adapter_data = data
	self.cols = cols
	self.rows = rows

func _get_cell(row: int, col: int) -> Dictionary:
	return adapter_data[row][col]

func _set_cell(row: int, col: int, data: Dictionary) -> void:
	adapter_data[row][col] = data

func _init_row_metrics() -> void:
	row_heights.resize(rows)
	row_offsets.resize(rows + 1)
	row_offsets[0] = 0.0
	var acc := 0.0
	for r in range(rows):
		row_heights[r] = 0.0
		row_offsets[r + 1] = acc

func _ensure_row_metrics_visible(r0: int, r1: int) -> void:
	for r in range(r0, r1 + 1):
		if row_heights[r] == 0.0:
			var max_h := 0.0
			for c in range(cols):
				var cell_info: Dictionary = _get_cell(r, c)
				var cell_type: StringName = cell_info.type
				var default_cell: TableCell = cell_defaults[cell_type]
				max_h = max(max_h, default_cell._estimate_height(cell_info))
			row_heights[r] = max_h
	for r in range(r0, r1 + 1):
		row_offsets[r + 1] = row_offsets[r] + row_heights[r]

func load_dataset(data, _cols: int, _rows: int) -> void:
	dataset = []
	cols = _cols; rows = _rows
	_adapter_on_load(data, cols, rows)
	_ensure_column_ratios()

	_rebuild_row_heights_estimate()
	_rebuild_row_offsets()
	_rebuild_column_metrics()

	_need_layout = true
	_need_visible_refresh = true
	if vscrollbar:
		_update_scrollbar_range()
	queue_redraw()

func serialize() -> Array:
	var out: Array = []
	for r in rows:
		var row_data: Array = []
		for c in cols:
			var key = Vector2i(r, c)
			if active_cells.has(key):
				var cell: Node = active_cells[key]
				row_data.append(cell.get_data())
			else:
				row_data.append(_get_cell(r, c))
		out.append(row_data)
	return out


func set_column_ratios(ratios: PackedFloat32Array) -> void:
	column_ratios = ratios.duplicate()
	_ensure_column_ratios()
	_rebuild_column_metrics()
	_need_layout = true
	_need_visible_refresh = true
	queue_redraw()

func _ensure_column_ratios() -> void:
	if cols <= 0:
		column_ratios = PackedFloat32Array([])
		return
	if column_ratios.is_empty() or column_ratios.size() != cols:
		var even: float = 1.0
		column_ratios = PackedFloat32Array()
		column_ratios.resize(cols)
		for i in cols:
			column_ratios[i] = even

func _rebuild_column_metrics() -> void:
	col_widths = PackedFloat32Array()
	col_offsets = PackedFloat32Array()
	if cols <= 0:
		return

	col_widths.resize(cols)
	col_offsets.resize(cols + 1)

	var sum_ratios: float = 0.0
	for i in cols:
		sum_ratios += column_ratios[i]

	# --- Key change ---
	var view_w: float
	match column_width_mode:
		ColumnWidthMode.FIT, ColumnWidthMode.FIXED:
			view_w = size.x
		ColumnWidthMode.RELAXED:
			# use the initial size only once; keep it constant afterwards
			if not Engine.is_editor_hint() and not col_offsets.is_empty() and col_offsets[cols] > 0.0:
				view_w = col_offsets[cols] / max_total_width_scale
			else:
				view_w = size.x
	# -------------------

	var target_w: float = view_w
	match column_width_mode:
		ColumnWidthMode.FIT:
			target_w = view_w
		ColumnWidthMode.RELAXED:
			target_w = view_w * max_total_width_scale
		ColumnWidthMode.FIXED:
			target_w = view_w * sum_ratios / min_total_column_ratio

	var acc: float = 0.0
	col_offsets[0] = 0.0
	for i in cols:
		var ratio = column_ratios[i]
		var w = max(min_column_width, target_w * (ratio / sum_ratios))
		col_widths[i] = w
		acc += w
		col_offsets[i + 1] = acc

	if hscrollbar:
		_update_hscrollbar_range()

var _height_cache: Dictionary = {}
func _rebuild_row_heights_estimate() -> void:
	if rows <= 0 or cols <= 0:
		row_heights.clear()
		return

	row_heights.resize(rows)
	for r in range(rows):
		var max_h = 0.0
		for c in range(cols):
			var cell_info: Dictionary = adapter_data[r][c]
			var cell_type: StringName = cell_info.type

			var default_cell: TableCell = cell_defaults[cell_type]
			if not cell_type in _height_cache:
				_height_cache[cell_type] = {}
			var key: String = default_cell._height_key(cell_info)
			var h: float

			if _height_cache[cell_type].has(key):
				h = _height_cache[cell_type][key]
			else:
				h = default_cell._estimate_height(cell_info)
				_height_cache[cell_type][key] = h

			if h > max_h:
				max_h = h
		row_heights[r] = max_h




func add_row(cells: Array = [], at_index: int = -1) -> void:
	if at_index < 0 or at_index > rows:
		at_index = rows

	adapter_data.insert(at_index, cells)
	rows += 1

	var base_h = 0.0
	for c in range(cols):
		var cell_info = cells[c]
		var t: StringName = cell_info.type
		if cell_defaults.has(t):
			base_h = max(base_h, cell_defaults[t]._estimate_height(cell_info))

	row_heights.insert(at_index, base_h)

	if row_offsets.size() < rows + 1:
		row_offsets.resize(rows + 1)

	_rebuild_row_offsets(at_index)

	if vscrollbar:
		_update_scrollbar_range()
	_need_layout = true
	_need_visible_refresh = true
	queue_redraw()



## Remove a specific row
func remove_row(index: int) -> void:
	if index < 0 or index >= rows:
		return

	# remove adapter data
	adapter_data.remove_at(index)
	rows -= 1

	# clear any active cells belonging to this row
	for key in active_cells.keys():
		if key.x == index:
			_release_cell(active_cells[key])
			active_cells.erase(key)

	# remove metrics
	row_heights.remove_at(index)
	row_offsets.remove_at(index + 1)
	_rebuild_row_offsets(index)

	if vscrollbar:
		_update_scrollbar_range()
	_need_layout = true
	_need_visible_refresh = true
	queue_redraw()


func _rebuild_row_offsets(start_index: int = 0) -> void:
	if rows <= 0:
		return

	if row_offsets.size() < rows + 1:
		row_offsets.resize(rows + 1)
	if row_heights.size() < rows:
		row_heights.resize(rows)

	start_index = clamp(start_index, 0, rows - 1)

	if start_index == 0:
		row_offsets[0] = 0.0

	for i in range(start_index + 1, rows + 1):
		row_offsets[i] = row_offsets[i - 1] + row_heights[i - 1]



func _update_row_height_if_needed(row: int, new_height: float) -> void:
	if row < 0 or row >= rows: return
	if new_height > row_heights[row] + 0.5:
		row_heights[row] = new_height
		_rebuild_row_offsets()
		_need_layout = true
		_need_visible_refresh = true
		if vscrollbar:
			_update_scrollbar_range()
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_scroll_y(scroll_y - scroll_speed_wheel)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_scroll_y(scroll_y + scroll_speed_wheel)

func _set_scroll_y(new_value: float, vbar_update: bool = false) -> void:
	var content_h: float = row_offsets[rows] if (rows > 0) else 0.0
	var view_h: float = size.y
	var clamped = clamp(new_value, 0.0, max(0.0, content_h - view_h))
	if abs(clamped - scroll_y) < 0.5:
		return

	scroll_y = clamped
	if vscrollbar:
		vscrollbar.set_value_no_signal(scroll_y)
	_scroll_dirty = true
	_scroll_cooldown = 0.0
	_need_layout = true
	queue_redraw()

var just_resized: bool = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		#if column_width_mode != ColumnWidthMode.RELAXED:
		_update_content_area_rect()
		just_resized = true
		if column_width_mode != ColumnWidthMode.RELAXED:
			_rebuild_column_metrics()
		_need_layout = true
		_need_visible_refresh = true

		if vscrollbar:
			_update_scrollbar_range()
		if hscrollbar:
			_update_hscrollbar_range()
		queue_redraw()


var _time_since_scroll_move: float = 0.0
var _delay_active: bool = false
var _vel_smoothed: float = 0.0

var _last_scrollbar_rect: Rect2


func _process(delta: float) -> void:
	var dy = abs(scroll_y - _last_scroll_y)
	var inst_vel = dy / delta
	_vel_smoothed = lerp(_vel_smoothed, inst_vel, 5.0 * delta)
	_last_scroll_y = scroll_y

	var fast_scroll = _vel_smoothed > spawn_delay_threshold

	if dy > 0.5:
		_time_since_scroll_move = 0.0
		_delay_active = true
	else:
		_time_since_scroll_move += delta

	var allow_spawning = true
	if fast_scroll:
		if _delay_active and _time_since_scroll_move < scroll_spawn_delay:
			allow_spawning = false
		elif _time_since_scroll_move >= scroll_spawn_delay:
			_delay_active = false

	_refresh_visible_cells(allow_spawning)
	_layout_active_cells()
	just_resized = false




func _refresh_visible_cells(allow_spawning: bool = true) -> void:
	if rows <= 0 or cols <= 0:
		_hide_all_cells()
		return

	var inner_h := _content_area.size.y
	var view_top := scroll_y
	var view_bottom := scroll_y + inner_h
	var pre := 2

	var r0 = clamp(_find_row_for_y(view_top) - pre, 0, max(0, rows - 1))
	var r1 = clamp(_find_row_for_y(view_bottom) + pre, 0, rows - 1)
	var c0 = 0
	var c1 = cols - 1

	_ensure_row_metrics_visible(r0, r1)
	var seen = {}
	#print(just_resized)
	for r in range(r0, r1 + 1):
		for c in range(c0, c1 + 1):
			var key = Vector2i(r, c)
			seen[key] = true

			if active_cells.has(key):
				active_cells[key].visible = true
				if just_resized:
					active_cells[key]._resized.call_deferred()
				continue

			var reused = _try_reuse_cell(r, c)
			if reused:
				reused.visible = true
				active_cells[key] = reused
				if just_resized:
					reused._resized.call_deferred()
				continue

			if allow_spawning:
				_spawn_cell(r, c)

	for key in active_cells.keys():
		if not seen.has(key):
			var cell = active_cells[key]
			cell.visible = false
			_release_cell(cell)
			active_cells.erase(key)



func _try_reuse_cell(row: int, col: int) -> TableCell:
	var t: String = String(_get_cell(row, col).type)
	if not pool_by_type.has(t):
		return null
	var pool = pool_by_type[t]
	if pool.size() == 0:
		return null
	var cell: TableCell = pool.pop_back()
	_content_area.add_child(cell)
	cell.map_data(_get_cell(row, col))
	if just_resized:
		cell._resized()
	return cell




func _hide_all_cells() -> void:
	for key in active_cells.keys():
		var cell: TableCell = active_cells[key]
		cell.visible = false


func _spawn_cell(row: int, col: int) -> void:
	var t: StringName = _get_cell(row, col).type
	var cell: TableCell = _acquire_cell(t)
	cell._resized()
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if cell == null:
		return
	_content_area.add_child(cell)
	cell.visible = true

	var d: Dictionary = _get_cell(row, col)
	cell.map_data(d)
	active_cells[Vector2i(row, col)] = cell
	_cell_entered_view(cell, row, col)
	var desired: Vector2 = Vector2(col_widths[col], cell.height)
	_update_row_height_if_needed(row, desired.y)
	_need_layout = true


func _acquire_cell(cell_type: StringName) -> TableCell:
	if pool_by_type.has(cell_type) and pool_by_type[cell_type].size() > 0:
		return pool_by_type[cell_type].pop_back()
	return _create_cell_instance(cell_type)



func _release_cell(cell: TableCell) -> void:
	var t: String = cell.cell_type
	if not pool_by_type.has(t):
		pool_by_type[t] = []
	var pool = pool_by_type[t]
	if pool.size() < max_pool:
		_content_area.remove_child(cell)
		pool.append(cell)
	else:
		cell.queue_free()
	pool_by_type[t] = pool


func _layout_active_cells() -> void:
	for key in active_cells.keys():
		var row: int = key.x
		var col: int = key.y
		var cell: TableCell = active_cells[key]
		if not cell.visible: continue

		var x = col_offsets[col] - scroll_x
		var y = row_offsets[row] - scroll_y

		var w = col_widths[col]
		var h = row_heights[row]

		_position_cell(cell, row, col, Vector2(x, y), Vector2(w, h))
	queue_redraw()


func _position_cell(cell: TableCell, row: int, col: int, top_left: Vector2, size_rc: Vector2) -> void:
	cell.position = top_left.floor()
	cell.size = size_rc.floor()


func _draw() -> void:
	var left  = content_margin.x
	var top   = content_margin.y
	var right = content_margin.z
	var bottom = content_margin.w

	var inner_size = _content_area.size
	var content_w: float = (col_offsets[cols] if cols > 0 else 0.0)
	var content_h: float = (row_offsets[rows] if rows > 0 else 0.0)

	# Full outer border (includes margins)
	var total_w: float = content_w + left + right
	var total_h: float = content_h + top + bottom

	# background clear
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0), true)

	# visible rows by inner height
	var view_top: float = scroll_y
	var view_bottom: float = scroll_y + inner_size.y

	var r0 = clamp(_find_row_for_y(view_top), 0, max(0, rows - 1))
	var r1 = clamp(_find_row_for_y(view_bottom), 0, rows - 1)

	# odd rows
	for r in range(r0, r1 + 1):
		if (r % 2) == 1:
			var y0: float = row_offsets[r] - scroll_y + top
			var y1: float = row_offsets[r + 1] - scroll_y + top
			draw_rect(Rect2(Vector2(left, y0), Vector2(content_w, y1 - y0)), odd_row_tint, true)

	# vertical grid
	for c in range(0, cols + 1):
		var x = ((content_w if c == cols else col_offsets[c]) - scroll_x + left)
		draw_line(Vector2(x, top),
				  Vector2(x, top + min(inner_size.y, content_h - scroll_y)),
				  grid_line_color, grid_line_thickness)

	# horizontal grid
	for r in range(r0, r1 + 1):
		var y = row_offsets[r] - scroll_y + top
		draw_line(Vector2(left, y), Vector2(left + content_w, y), grid_line_color, grid_line_thickness)

	if rows > 0:
		var yb = row_offsets[min(rows, r1 + 1)] - scroll_y + top
		draw_line(Vector2(left, yb), Vector2(left + content_w, yb), grid_line_color, grid_line_thickness)


func _find_row_for_y(world_y: float) -> int:
	var lo = 0
	var hi = rows
	while lo < hi:
		var mid = (lo + hi) >> 1
		if row_offsets[mid + 1] <= world_y:
			lo = mid + 1
		elif row_offsets[mid] > world_y:
			hi = mid
		else:
			return mid
	return clamp(lo, 0, max(0, rows - 1))


func _create_cell_instance(cell_type: StringName) -> TableCell:
	var scene: PackedScene = cell_templates[cell_type]
	var inst = scene.instantiate()
	if not inst is TableCell:
		inst.cell_type = cell_type
		return inst
	inst.cell_type = cell_type
	return inst

func _cell_entered_view(cell: TableCell, row: int, col: int) -> void:
	pass

func _cell_exited_view(cell: TableCell, row: int, col: int) -> void:
	pass



func get_visible_row_range() -> Vector2i:
	var top = scroll_y
	var bottom = scroll_y + size.y
	return Vector2i(_find_row_for_y(top), _find_row_for_y(bottom))

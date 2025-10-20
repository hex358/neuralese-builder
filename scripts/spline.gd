@tool
extends Node2D
class_name Spline

@export var line_2d: Line2D
@export var keyword: StringName = "default"
@export var color: Color

# How far from each end to force hi-res baking (in pixels)
@export var end_smooth_range_px: float = 24.0

var origin: Connection
var tied_to: Connection

var curve := Curve2D.new()
var end_dir_vec: Vector2
var baked: PackedVector2Array = [Vector2(), Vector2()]
var space: PackedVector2Array = PackedVector2Array([Vector2(), Vector2()])
var doomed := false

# --- READY / PROCESS ------------------------------------------------------------

func _ready() -> void:
	if line_2d and line_2d.gradient:
		line_2d.gradient = line_2d.gradient.duplicate(true)
	if !Engine.is_editor_hint():
		$Marker2D.queue_free()
	_recolor_gradient()

func _process(delta: float) -> void:
	if Engine.is_editor_hint() and glob.ticks % 10 == 0:
		update_points(Vector2(), $Marker2D.position, Vector2.RIGHT)

# --- APPEAR / DISAPPEAR ---------------------------------------------------------

func appear() -> void:
	pass

func disappear() -> void:
	doomed = true
	queue_free()

# --- POINTS & CURVE -------------------------------------------------------------

func turn_into(word: StringName, other_word: StringName = &"default") -> void:
	match other_word:
		"router":
			color = Color(1, 1, 0.5)
			keyword = "default"
		_:
			color = Color.WHITE
			keyword = "default"

func weight_points(a: Vector2, b: Vector2, dir_a: Vector2, dir_b) -> void:
	space[0] = a
	space[1] = b
	baked = space

func other_default_points(start: Vector2, end: Vector2, start_dir: Vector2, end_dir):
	var delta = end - start
	var angle_to_x = start_dir.angle()
	var local = delta.rotated(-angle_to_x)
	var local_handle = Vector2()
	if local.x > 0:
		local_handle.x = local.x * 0.5
	else:
		local_handle.y = local.y * 0.5
	var handle_out = local_handle.rotated(angle_to_x)

	curve.add_point(start, Vector2.ZERO, handle_out)
	curve.add_point(end, Vector2.ZERO, Vector2.ZERO)

	var length = delta.length()
	var mid_interval = clamp(length * 0.1, 2.0, 30.0)
	baked = _bake_with_end_smoothing(mid_interval, end_smooth_range_px)

var mapping := {"weight": weight_points}

# --- GRADIENT RECOLORING (Optimized) -------------------------------------------

var _base_colors := PackedColorArray([Color.WHITE, Color.WHITE])
var _blended_colors := PackedColorArray([Color.WHITE, Color.WHITE])

@export var blender: Color = Color(1, 1, 1, 0.0):
	set(v):
		blender = v
		_recolor_gradient()

@export var color_a: Color = Color.WHITE:
	set(v):
		color_a = v
		_base_colors[0] = v
		_recolor_gradient()

@export var color_b: Color = Color.WHITE:
	set(v):
		color_b = v
		_base_colors[1] = v
		_recolor_gradient()

# New optimized modulate system using Dictionary for O(1) access
var _modulate_stack: Dictionary = {}  # { name: Color }

func invalid():
	push_modulate("invalid", Color.RED)

func valid():
	pop_modulate("invalid")

func push_modulate(name: String, color: Color) -> void:
	_modulate_stack[name] = color
	_recolor_gradient()

func pop_modulate(name: String) -> void:
	if _modulate_stack.has(name):
		_modulate_stack.erase(name)
		_recolor_gradient()

func clear_modulates() -> void:
	if _modulate_stack.size() > 0:
		_modulate_stack.clear()
		_recolor_gradient()

func _recolor_gradient() -> void:
	var ca: Color = _base_colors[0]
	var cb: Color = _base_colors[1]

	# Legacy blender (backward compatibility)
	if blender.a > 0.0:
		ca = ca.blend(blender)
		cb = cb.blend(blender)

	# Apply all modulates in insertion order (stable since Godot 4.2+)
	for name in _modulate_stack:
		var c: Color = _modulate_stack[name]
		if c.a > 0.0:
			ca = ca.blend(c)
			cb = cb.blend(c)

	_blended_colors[0] = ca
	_blended_colors[1] = cb

	if line_2d and line_2d.gradient:
		line_2d.gradient.colors = _blended_colors

# --- /Gradient recoloring ---

# --- CURVE UPDATE ---------------------------------------------------------------

func update_points(start: Vector2, end: Vector2, start_dir: Vector2, end_dir = null) -> void:
	curve.clear_points()
	mapping.get(keyword, default_points).call(start, end, start_dir, end_dir)
	line_2d.points = baked

func default_points(start: Vector2, end: Vector2, start_dir: Vector2, end_dir = null) -> void:
	if end_dir == null:
		if !end_dir_vec:
			end_dir_vec = -start_dir
		end_dir = end_dir_vec
	else:
		end_dir_vec = end_dir

	var length: float = (end - start).length()
	var size: float = clamp(length * 0.1, 2.0, 10.0) - 2.0

	var second_point = start + start_dir * size
	var end_second_point = end + end_dir * size
	curve.add_point(start, Vector2(), Vector2())
	curve.add_point(second_point, Vector2(), size * (second_point - start))
	curve.add_point(end_second_point, -size * (end - end_second_point), Vector2())
	curve.add_point(end, Vector2(), Vector2())

	var mid_interval = clamp(length * 0.05, 2.0, 30.0)
	baked = _bake_with_end_smoothing(mid_interval, end_smooth_range_px)

# --- SMOOTH BAKING --------------------------------------------------------------

func _bake_with_end_smoothing(mid_interval: float, end_range_px: float) -> PackedVector2Array:
	var prev = curve.bake_interval
	curve.bake_interval = mid_interval
	var mid = curve.get_baked_points()
	curve.bake_interval = prev
	if mid.size() <= 2:
		return mid

	var total_len = _poly_length(mid)
	if total_len <= end_range_px * 2.0 or mid_interval <= 1.0:
		return mid

	var left_idx = _index_at_distance_from_start(mid, end_range_px)
	var right_idx = _index_at_distance_from_end(mid, end_range_px)
	if left_idx >= right_idx:
		return mid

	var left_seam = mid[left_idx]
	var right_seam = mid[right_idx]

	var left_curve = _build_left_subcurve_covering(end_range_px)
	var left_hi = _bake_curve_1px(left_curve)
	var left_out = PackedVector2Array()
	if left_hi.size() > 0:
		var li = _nearest_index(left_hi, left_seam)
		for i in range(0, li):
			left_out.push_back(left_hi[i])
		left_out.push_back(left_seam)
	else:
		left_out.push_back(left_seam)

	var right_curve = _build_right_subcurve_covering(end_range_px)
	var right_hi = _bake_curve_1px(right_curve)
	var right_out = PackedVector2Array()
	right_out.push_back(right_seam)
	if right_hi.size() > 0:
		var ri = _nearest_index(right_hi, right_seam)
		for i in range(ri + 1, right_hi.size()):
			right_out.push_back(right_hi[i])

	var out = PackedVector2Array()
	for i in range(0, left_out.size()):
		out.push_back(left_out[i])
	for i in range(left_idx + 1, right_idx):
		out.push_back(mid[i])
	for i in range(0, right_out.size()):
		if out.size() == 0 or out[out.size() - 1] != right_out[i]:
			out.push_back(right_out[i])
	return out

func _build_left_subcurve_covering(target_px: float) -> Curve2D:
	var pc = curve.get_point_count()
	var c = Curve2D.new()
	if pc < 2:
		return c
	var max_idx = min(2, pc - 1)
	for i in range(0, max_idx + 1):
		c.add_point(curve.get_point_position(i), curve.get_point_in(i), curve.get_point_out(i))
	var baked = _bake_curve_1px(c)
	if _poly_length(baked) < target_px and pc > max_idx + 1:
		var j = max_idx + 1
		c.add_point(curve.get_point_position(j), curve.get_point_in(j), curve.get_point_out(j))
	return c

func _build_right_subcurve_covering(target_px: float) -> Curve2D:
	var pc = curve.get_point_count()
	var c = Curve2D.new()
	if pc < 2:
		return c
	var start_idx = max(0, pc - 3)
	for i in range(start_idx, pc):
		c.add_point(curve.get_point_position(i), curve.get_point_in(i), curve.get_point_out(i))
	var baked = _bake_curve_1px(c)
	if _poly_length(baked) < target_px and start_idx > 0:
		var j = start_idx - 1
		var c2 = Curve2D.new()
		c2.add_point(curve.get_point_position(j), curve.get_point_in(j), curve.get_point_out(j))
		for i in range(start_idx, pc):
			c2.add_point(curve.get_point_position(i), curve.get_point_in(i), curve.get_point_out(i))
		return c2
	return c

func _bake_curve_1px(c: Curve2D) -> PackedVector2Array:
	if c.get_point_count() < 2:
		return PackedVector2Array()
	var prev = c.bake_interval
	c.bake_interval = 1.0
	var pts = c.get_baked_points()
	c.bake_interval = prev
	return pts

# --- UTILS ----------------------------------------------------------------------

func _nearest_index(points: PackedVector2Array, p: Vector2) -> int:
	var best_i = 0
	var best_d = INF
	for i in range(points.size()):
		var d = points[i].distance_squared_to(p)
		if d < best_d:
			best_d = d
			best_i = i
	return best_i

func _poly_length(points: PackedVector2Array) -> float:
	var acc = 0.0
	for i in range(1, points.size()):
		acc += points[i].distance_to(points[i - 1])
	return acc

func _index_at_distance_from_start(points: PackedVector2Array, d: float) -> int:
	var acc = 0.0
	for i in range(1, points.size()):
		var seg = points[i].distance_to(points[i - 1])
		if acc + seg >= d:
			return i
		acc += seg
	return points.size() - 1

func _index_at_distance_from_end(points: PackedVector2Array, d: float) -> int:
	var acc = 0.0
	for i in range(points.size() - 1, 0, -1):
		var seg = points[i].distance_to(points[i - 1])
		if acc + seg >= d:
			return i
		acc += seg
	return 0

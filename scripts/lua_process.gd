class_name LuaProcess
extends Node2D

var lua: LuaAPI
var shapes: Array = []
var new_frame
var time := 0.0
var delta := 0.0

var methods = []
var physics_world: World2D
var _lua_coroutines: Array = []


class LuaFuture:
	var _done := false
	var _result = null
	func is_completed() -> bool: return _done
	func get_result() -> Variant: return _result
	func _complete(v: Variant) -> void:
		_done = true
		_result = v


func _process(delta: float) -> void:
	update(delta)


func _register_future_helpers():
	lua.push_variant("future_is_completed", func(f): return f.is_completed())
	lua.push_variant("future_get_result", func(f): return f.get_result())

var _lua_step
func _init(name: String, code: String):
	if not code:
		methods = _get_exposed_function_names()
		return
		
	lua = LuaAPI.new()
	
	lua.bind_libraries(["base", "table", "string", "math", "coroutine"])
	lua.push_variant("__gd_debug_print", func(...args):
		_debug_print(args)
)
	lua.do_string("""
	function print(...)
		__gd_debug_print(...)
	end
	""")


	_register_future_helpers()

	var prelude := """
	local __user_chunk = nil
	function __set_user_chunk(fn) __user_chunk = fn end

	local __main = coroutine.create(function()
	  if __user_chunk then __user_chunk() end
	end)

	function __step()
	  if coroutine.status(__main) ~= "dead" then
	    local ok, err = coroutine.resume(__main)
	    if not ok then error(debug.traceback(__main, tostring(err))) end
	  end
	end
	"""
	lua.do_string(prelude)
	


	# Wrap user code and load it
	var wrapped := "__set_user_chunk(function()\n" + code + "\nend)"
	lua.do_string(wrapped)
	_lua_step = lua.pull_variant("__step")


	lua.set_registry_value("__gd_call_bridge", func(reg_key: String, args: Array) -> Variant:
		var cb: Callable = lua.get_registry_value(reg_key)
		if cb == null:
			printerr("Lua attempted to call missing registry key: ", reg_key)
			return null
		var out = cb.callv(args)
		while typeof(out) == TYPE_CALLABLE:
			out = out.call()
	#	print("[bridge]", reg_key, "→", typeof(out), out)
		return out
	)




	var bridge_callable = lua.get_registry_value("__gd_call_bridge")
	lua.push_variant("__gd_call_bridge", bridge_callable)

	var error = lua.do_string("""
	function call_gd(reg_key, args)
		return __gd_call_bridge(reg_key, args)
	end
	""")
	if error is LuaError:
		printerr("Failed to define call_gd:", error.message)


	for fn_name in _get_exposed_functions():
		if fn_name.begins_with("lua_"):
			lua.push_variant(fn_name.trim_prefix("lua_"), get(fn_name))
		elif fn_name.begins_with("async_lua_"):
			var clean_name := fn_name.trim_prefix("async_lua_")
			var callable_fn: Callable = get(fn_name)

			var reg_key := "__gd_callable_" + clean_name
			lua.set_registry_value(reg_key, callable_fn)

			var lua_stub := """
function run_model(...)
  local fut = call_gd('__gd_callable_run_model', {...})
  if not fut then return {} end
  while not future_is_completed(fut) do
    coroutine.yield()
  end
  return future_get_result(fut)
end
"""


			var err = lua.do_string(lua_stub)
			if err is LuaError:
				printerr("Failed to create Lua stub for " + clean_name + ": " + err.message)

	#var err = lua.do_string(code)
	##if err is LuaError:
	#	printerr("Lua error in %s: %s" % [name, err.message])
	#	return

	var create_scene = lua.pull_variant("createScene")
	if create_scene: create_scene.call([])
	new_frame = lua.pull_variant("newFrame")


# -------------------------
# Auto-exposure helpers
# -------------------------
func _get_exposed_functions() -> Array[String]:
	var list: Array[String] = []
	for m in get_method_list():
		if m.name.begins_with("lua_") or m.name.begins_with("async_lua_"):
			list.append(m.name)
	return list

func _get_exposed_function_names() -> Array[String]:
	var list = _get_exposed_functions()
	for i in range(len(list)):
		list[i] = list[i].trim_prefix("lua_").trim_prefix("async_lua_")
	return list

# -------------------------
# Lifecycle
# -------------------------
func update(d: float):
	if _lua_step:
		_lua_step.call()
	for c in _lua_coroutines:
		if c == null: continue
		if c.is_done():
			_lua_coroutines.erase(c)
			continue
		c.resume([])
	if stopped: return
	delta = d
	time += d
	if new_frame:
		new_frame.call(delta)



func _physics_process(delta: float) -> void:
	# Sync physics bodies → shapes


	for shape in shapes:
		if shape == null: continue
		if shape.get("physics_enabled", false) and shape.has("body"):
			var b: Node2D = shape["body"]
			shape["x"] = b.position.x
			shape["y"] = b.position.y

func _draw() -> void:
	if stopped: return
	for shape in shapes:
		if shape == null: continue
		var pos = Vector2(shape["x"], -shape["y"])
		var rot = float(shape.get("rotation", 0.0))
		draw_set_transform(pos, -rot, Vector2.ONE)
		if shape["type"] == "circle":
			draw_circle(Vector2.ZERO, shape["r"], shape["color"])
		elif shape["type"] == "rect":
			draw_rect(Rect2(-shape["w"]/2, -shape["h"]/2, shape["w"], shape["h"]), shape["color"])
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
# -------------------------
# Lua API: creation
# -------------------------
func lua_Circle(x: float, y: float, r: float) -> int:
	var id = shapes.size()
	var shape = {
		"type": "circle",
		"x": x, "y": y,
		"r": r,
		"rotation": 0.0,
		"color": Color(1,1,1),
		"physics_enabled": false
	}
	shapes.append(shape)
	return id

func lua_Rectangle(x: float, y: float, w: float, h: float) -> int:
	var id = shapes.size()
	var shape = {
		"type": "rect",
		"x": x, "y": y,
		"w": w, "h": h,
		"rotation": 0.0,
		"color": Color(1,1,1),
		"physics_enabled": false
	}
	shapes.append(shape)
	return id

# -------------------------
# Lua API: physics
# -------------------------
func lua_enable_physics(id: int, enabled: bool) -> void:
	var s = _get_shape(id)
	if s.is_empty(): return
	if enabled and not s.get("physics_enabled", false):
		var body := RigidBody2D.new()
		var collider := CollisionShape2D.new()
		if s["type"] == "circle":
			var shape2d := CircleShape2D.new()
			shape2d.radius = s["r"]
			collider.shape = shape2d
		else:
			var shape2d := RectangleShape2D.new()
			shape2d.extents = Vector2(s["w"]/2, s["h"]/2)
			collider.shape = shape2d
		body.position = Vector2(s["x"], s["y"])
		body.add_child(collider)
		add_child(body)
		s["body"] = body
		s["physics_enabled"] = true
	elif not enabled and s.get("physics_enabled", false):
		if s.has("body"):
			s["body"].queue_free()
		s.erase("body")
		s["physics_enabled"] = false

func lua_apply_force(id: int, fx: float, fy: float) -> void:
	var s = _get_shape(id)
	if s.is_empty(): return
	if s.get("physics_enabled", false) and s.has("body"):
		s["body"].apply_central_force(Vector2(fx, fy))

func lua_set_velocity(id: int, vx: float, vy: float) -> void:
	var s = _get_shape(id)
	if s.is_empty(): return
	if s.get("physics_enabled", false) and s.has("body"):
		s["body"].linear_velocity = Vector2(vx, vy)

# -------------------------
# Lua API: helpers
# -------------------------
func lua_raycast(x1: float, y1: float, x2: float, y2: float) -> Dictionary:
	ray_params.from =  Vector2(x1,y1); ray_params.to = Vector2(x2,y2)
	var res = space_state.intersect_ray(ray_params)
	if res.is_empty():
		return {}
	return {"position": res.position, "collider": res.collider}

var ray_params: PhysicsRayQueryParameters2D
var point_params: PhysicsPointQueryParameters2D
@onready var space_state = get_world_2d().direct_space_state

func _ready():
	physics_world = get_world_2d()
	point_params = PhysicsPointQueryParameters2D.new()
	ray_params = PhysicsRayQueryParameters2D.new()

func lua_overlap_point(x: float, y: float) -> bool:
	point_params.position = Vector2(x,y)
	var res = space_state.intersect_point(point_params)
	return res.size() > 0

# -------------------------
# Existing Lua API
# -------------------------
func lua_move(id: int, dx: float, dy: float) -> void:
	var s = _get_shape(id)
	if s.is_empty(): return
	if s.get("physics_enabled", false):
		if s.has("body"):
			s["body"].position += Vector2(dx, dy)
	else:
		s["x"] += dx
		s["y"] += dy

func lua_set_pos(id: int, x: float, y: float) -> void:
	var s = _get_shape(id)
	if s.is_empty(): return
	if s.get("physics_enabled", false):
		if s.has("body"):
			s["body"].position = Vector2(x, y)
	else:
		s["x"] = x
		s["y"] = y

func lua_set_color(id: int, r: float, g: float, b: float) -> void:
	var s = _get_shape(id)
	if s.is_empty(): return
	s["color"] = Color(r,g,b)

func lua_set_size(id: int, s: float) -> void:
	var sh = _get_shape(id)
	if sh.is_empty(): return
	if sh["type"] == "circle":
		sh["r"] = float(sh["r"]) * s
	else:
		sh["w"] = float(sh["w"]) * s
		sh["h"] = float(sh["h"]) * s

func lua_delete(id: int) -> void:
	if id < 0 or id >= shapes.size(): return
	var s = shapes[id]
	if s and s.get("physics_enabled", false) and s.has("body"):
		s["body"].queue_free()
	shapes[id] = null

func lua_set_x(id: int, x: float) -> void:
	var s = _get_shape(id)
	if s.is_empty(): return
	if s.get("physics_enabled", false) and s.has("body"):
		var pos = s["body"].position
		s["body"].position = Vector2(x, pos.y)
	else:
		s["x"] = x

func lua_set_y(id: int, y: float) -> void:
	var s = _get_shape(id)
	if s.is_empty(): return
	if s.get("physics_enabled", false) and s.has("body"):
		var pos = s["body"].position
		s["body"].position = Vector2(pos.x, y)
	else:
		s["y"] = y


# -------------------------
# Queries
# -------------------------
func lua_get_x(id: int) -> float:
	var s = _get_shape(id)
	return float(s["x"]) if not s.is_empty() else 0.0

func lua_get_y(id: int) -> float:
	var s = _get_shape(id)
	return float(s["y"]) if not s.is_empty() else 0.0

func lua_get_width(id: int) -> float:
	var s = _get_shape(id)
	if s.is_empty(): return 0.0
	return float(s["w"]) if s["type"] == "rect" else float(s["r"]) * 2.0

func lua_get_height(id: int) -> float:
	var s = _get_shape(id)
	if s.is_empty(): return 0.0
	return float(s["h"]) if s["type"] == "rect" else float(s["r"]) * 2.0

func lua_get_radius(id: int) -> float:
	var s = _get_shape(id)
	return float(s["r"]) if (not s.is_empty() and s.has("r")) else 0.0

func lua_get_color(id: int) -> Dictionary:
	var s = _get_shape(id)
	if s.is_empty(): return {"r":0,"g":0,"b":0}
	var c: Color = s["color"]
	return {"r": c.r, "g": c.g, "b": c.b}

# -------------------------
# Input
# -------------------------
func lua_get_key(keyname: String) -> bool:
	if InputMap.has_action(keyname):
		return Input.is_action_pressed(keyname)
	match keyname:
		"left": return Input.is_key_pressed(KEY_LEFT)
		"right": return Input.is_key_pressed(KEY_RIGHT)
		"up": return Input.is_key_pressed(KEY_UP)
		"down": return Input.is_key_pressed(KEY_DOWN)
		"space": return Input.is_key_pressed(KEY_SPACE)
		"mouse_left": return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		"mouse_right": return Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
		_: return false

func lua_get_mouse_pos() -> Dictionary:
	var p: Vector2 = glob.get_global_mouse_position()
	return {"x": p.x, "y": -p.y}


# -------------------------
# Inference
# -------------------------

func async_lua_run_model(name: String, input: Array) -> LuaFuture:
	var f := LuaFuture.new()
	_call_inference(name, input, f)
	return f

var debug_printer: Callable = Callable()

func _debug_print(args) -> void:
	debug_printer.call(args)




func _call_inference(name: String, input: Array, fut: LuaFuture) -> void:
	_call_inference_task(name, input, fut)




func _call_inference_task(name: String, input: Array, fut: LuaFuture) -> void:
	var node = graphs.get_input_graph_by_name(name)
	if node == null:
		fut._complete({"_error":"no_node"})
		return

	var useful = node.useful_properties()
	useful["raw_values"] = input

	if not nn.is_infer_channel(node):
		var open_res = nn.open_infer_channel(node, node.close_runner)
		await open_res.connected
		while not open_res.is_listening():
			await get_tree().process_frame
		await glob.wait(0.1)

	var result = await nn.send_inference_data(node, useful, true)

	if typeof(result) != TYPE_DICTIONARY:
		result = {"_error":"bad_type", "type": typeof(result), "repr": str(result)}

	fut._complete(result)




# -------------------------
# Timing + control
# -------------------------
func lua_get_time() -> float:
	return time

func lua_get_delta() -> float:
	return delta

func lua_clear() -> void:
	for s in shapes:
		if s and s.get("physics_enabled", false) and s.has("body"):
			s["body"].queue_free()
	shapes.clear()

var stopped: bool = false

func stop() -> void:
	stopped = true

	for s in shapes:
		if s and s.get("physics_enabled", false) and s.has("body"):
			s["body"].queue_free()

	shapes.clear()

	queue_free()

func lua_set_rotation(id: int, angle: float) -> void:
	var s = _get_shape(id)
	if s.is_empty(): return
	if s.get("physics_enabled", false) and s.has("body"):
		s["body"].rotation = angle
	else:
		s["rotation"] = angle

func lua_get_rotation(id: int) -> float:
	var s = _get_shape(id)
	return float(s.get("rotation", 0.0)) if not s.is_empty() else 0.0

func lua_rotate(id: int, angle: float) -> void:
	var s = _get_shape(id)
	if s.is_empty(): return
	if s.get("physics_enabled", false) and s.has("body"):
		s["body"].rotation += angle
	else:
		s["rotation"] = float(s.get("rotation", 0.0)) + angle


# -------------------------
# Helpers
# -------------------------
func _get_shape(id: int) -> Dictionary:
	if id < 0 or id >= shapes.size(): return {}
	var s = shapes[id]
	if s == null: return {}
	return s

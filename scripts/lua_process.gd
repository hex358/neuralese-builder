class_name LuaProcess
extends Node2D

var lua: LuaAPI
var shapes: Array = []
var new_frame
var time := 0.0
var delta := 0.0

func _init(name: String, code: String):
	lua = LuaAPI.new()
	lua.bind_libraries(["base", "table", "string", "math"])

	# expose all local functions to Lua
	for fn_name in _get_exposed_functions():
		lua.push_variant(fn_name.trim_prefix("lua_"), get(fn_name))

	# run user code
	var err = lua.do_string(code)
	if err is LuaError:
		printerr("Lua error in %s: %s" % [name, err.message])
		return

	var create_scene = lua.pull_variant("createScene")
	if create_scene: create_scene.call([])
	new_frame = lua.pull_variant("newFrame")

# automatic introspection
func _get_exposed_functions() -> Array[String]:
	# convention: every func that starts with "lua_" is exposed
	var list: Array[String] = []
	for m in get_method_list():
		if m.name.begins_with("lua_"):
			list.append(m.name)
	return list

# called by LuaEnv
func update(d: float):
	delta = d
	time += d
	if new_frame:
		new_frame.call(delta)

func _draw() -> void:
	for shape in shapes:
		if shape == null: continue
		if shape["type"] == "circle":
			draw_circle(Vector2(shape["x"], -shape["y"]), shape["r"], shape["color"])
		elif shape["type"] == "rect":
			draw_rect(Rect2(shape["x"], -shape["y"], shape["w"], shape["h"]), shape["color"])

# --- creation
func lua_Circle(x: float, y: float, r: float) -> int:
	var id = shapes.size()
	var shape = { "type": "circle", "x": x, "y": y, "r": r, "color": Color(1,1,1) }
	shapes.append(shape)
	return id

func lua_Rectangle(x: float, y: float, w: float, h: float) -> int:
	var id = shapes.size()
	var shape = { "type": "rect", "x": x, "y": y, "w": w, "h": h, "color": Color(1,1,1) }
	shapes.append(shape)
	return id

# --- manipulation
func lua_move(id: int, dx: float, dy: float) -> void:
	var s = _get_shape(id)
	if s.is_empty(): return
	s["x"] += dx
	s["y"] += dy

func lua_set_pos(id: int, x: float, y: float) -> void:
	var s = _get_shape(id)
	if s.is_empty(): return
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
	shapes[id] = null
# --- queries
func lua_get_x(id: int) -> float:
	var s = _get_shape(id)
	return float(s["x"]) if not s.is_empty() else 0.0

func lua_get_y(id: int) -> float:
	var s = _get_shape(id)
	return float(s["y"]) if not s.is_empty() else 0.0

func lua_get_width(id: int) -> float:
	var s = _get_shape(id)
	if s.is_empty(): 
		return 0.0
	return float(s["w"]) if s["type"] == "rect" else float(s["r"]) * 2.0

func lua_get_height(id: int) -> float:
	var s = _get_shape(id)
	if s.is_empty(): 
		return 0.0
	return float(s["h"]) if s["type"] == "rect" else float(s["r"]) * 2.0

func lua_get_radius(id: int) -> float:
	var s = _get_shape(id)
	return float(s["r"]) if (not s.is_empty() and s.has("r")) else 0.0

func lua_get_color(id: int) -> Dictionary:
	var s = _get_shape(id)
	if s.is_empty():
		return {"r": 0.0, "g": 0.0, "b": 0.0}
	var c: Color = s["color"]
	return {"r": c.r, "g": c.g, "b": c.b}



# --- input
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
	var p: Vector2 = get_viewport().get_mouse_position()
	return {"x": p.x, "y": -p.y}

# --- timing
func lua_get_time() -> float:
	return time

func lua_get_delta() -> float:
	return delta

# --- control
func lua_clear() -> void:
	shapes.clear()

# -------------------------
# Helpers
# -------------------------
func _get_shape(id: int) -> Dictionary:
	if id < 0 or id >= shapes.size(): return {}
	var s = shapes[id]
	if s == null: return {}
	return s

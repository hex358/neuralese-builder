class_name LuaLessonRunner
extends LuaProcRunner

signal step_started(step_index: int, name: String)
signal step_completed(step_index: int, name: String)

# =========================
# STEP STATE
# =========================

var steps: Array = []
var current_step_index: int = -1
var step_active: bool = false


# =========================
# ACTION WAIT STATE
# =========================

var waiting_action_name: String = ""
var waiting_action_filter: Dictionary = {}
var waiting_future: LuaFuture = null


# =========================
# LIFECYCLE
# =========================

func _ready() -> void:
	LessonRouter.register_runner(self)
	super._ready()


func _exit_tree() -> void:
	LessonRouter.unregister_runner(self)
	super._exit_tree()


# =========================
# STEP API (Lua-facing)
# =========================

func lua_begin_step(name: String) -> void:
	if step_active:
		push_error("LuaLessonRunner: step already active")
		return

	var step = {
		"name": name,
		"completed": false
	}

	steps.append(step)
	current_step_index = steps.size() - 1
	step_active = true

	step_started.emit(current_step_index, name)


func lua_mark_step_completed() -> void:
	if not step_active:
		push_error("LuaLessonRunner: no active step to complete")
		return

	steps[current_step_index].completed = true
	step_active = false

	step_completed.emit(
		current_step_index,
		steps[current_step_index].name
	)


# =========================
# ACTION API (Lua-facing)
# =========================

func async_lua_wait_action(action_name: String, filter: Dictionary = {}) -> LuaFuture:
	if waiting_future != null:
		push_error("LuaLessonRunner: already waiting for an action")
		return null

	var fut := LuaFuture.new()

	waiting_action_name = action_name
	waiting_action_filter = filter
	waiting_future = fut

	return fut


# =========================
# ACTION DISPATCH (Godot-facing)
# =========================

func _on_action_emitted(action_name: String, data: Dictionary) -> void:
	if waiting_future == null:
		return

	if action_name != waiting_action_name:
		return

	for k in waiting_action_filter.keys():
		if not data.has(k):
			return
		if data[k] != waiting_action_filter[k]:
			return

	var fut := waiting_future

	waiting_future = null
	waiting_action_name = ""
	waiting_action_filter = {}

	fut._complete(data)

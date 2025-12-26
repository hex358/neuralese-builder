extends Node
class_name LessonRouter

static var active_runner: LuaLessonRunner = null


static func register_runner(runner: LuaLessonRunner) -> void:
	active_runner = runner


static func unregister_runner(runner: LuaLessonRunner) -> void:
	if active_runner == runner:
		active_runner = null


static func emit_action(action_name: String, data: Dictionary = {}) -> void:
	if active_runner == null:
		return

	active_runner._on_action_emitted(action_name, data)

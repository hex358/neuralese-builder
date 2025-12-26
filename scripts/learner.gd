extends Node

func _process(delta: float) -> void:
	if glob.space_just_pressed:
		emit_action("space", {"hello": true})

func register_runner(runner: LuaLessonRunner) -> void:
	LessonRouter.register_runner(runner)


func unregister_runner(runner: LuaLessonRunner) -> void:
	LessonRouter.unregister_runner(runner)



signal lesson_event(event: Dictionary)



func emit_action(action_name: String, data: Dictionary = {}) -> void:
	LessonRouter.emit_action(action_name, data)

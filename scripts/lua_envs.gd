
extends Node

var processes: Dictionary = {}

func _ready() -> void:
	pass

func create_process(name: String, code: String) -> LuaProcess:
	remove_process(name)
	var proc = LuaProcess.new(name, code)
	processes[name] = proc
	proc.error_splashed.connect(func(): processes.erase(name))
	proc.execution_finished.connect(func(): processes.erase(name))
	return proc

func remove_process(name: String) -> void:
	if processes.has(name):
		var proc: LuaProcess = processes[name]
		proc.stop()
		processes.erase(name)

var _accum_time: float = 0.0
func _process(delta: float) -> void:
	_accum_time += delta
	var frame_step: float = 1 / 30.0
	while _accum_time >= frame_step:
		for p in processes.values():
			p.update(frame_step)
			p.queue_redraw()
		_accum_time -= frame_step

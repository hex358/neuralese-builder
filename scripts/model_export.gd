extends SplashMenu

func _ready() -> void:
	super()
	$ColorRect/Label.set_is_valid_call(func(input):
		return len(input)> 0 and graphs.get_input_graph_by_name(input))

func _process(delta: float) -> void:
	super(delta)

func quit(data: Dictionary = {}):
	quitting.emit()
	if can_go:
		hide()
		ui.blur.self_modulate.a = 0
		emitter.res.emit(data)

func _resultate(data: Dictionary):
	emitter.res.emit(data)
	#glob.env_dump[data["text"]] = "-- Scene '%s'\nprint('Hello, world!')" % data["text"]
	#glob.tree_windows["env"].reload_scenes()
	go_away()



func _on_trainn_released() -> void:
	$ColorRect/Label.update_valid()
	if $ColorRect/Label.is_valid:
		resultate({"text": $ColorRect/Label.text})

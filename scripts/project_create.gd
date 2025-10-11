extends SplashMenu

func _ready() -> void:
	super()
	$ColorRect/Label.set_is_valid_call(func(input):
		return len(input)> 0 and not input in glob.env_dump)

func _process(delta: float) -> void:
	super(delta)

func _resultate(data: Dictionary):
	emitter.res.emit(data)
	#glob.env_dump[data["text"]] = "-- Scene '%s'\nprint('Hello, world!')" % data["text"]
	#glob.tree_windows["env"].reload_scenes()
	go_away()



func _on_trainn_released() -> void:
	$ColorRect/Label.update_valid()
	if $ColorRect/Label.is_valid:
		glob.create_empty_project($ColorRect/Label.text)
	can_go = false
	go_away()
	await quitting
	queue_free()
	ui.splash("works", splashed_from, emitter, true)
	
		#parsed[glob.random_project_id()] = {"name": "New Project"}
		#list.show_up(glob.parsed_projects)

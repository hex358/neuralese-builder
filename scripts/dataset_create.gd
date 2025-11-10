extends SplashMenu

func _ready() -> void:
	super()
	$ColorRect/Label.set_is_valid_call(func(input):
		return len(input)> 0 and not input in glob.ds_dump)

func _process(delta: float) -> void:
	super(delta)

func _resultate(data: Dictionary):
	var rand_dataset_id: int = randi_range(0,999999)
	emitter.res.emit(data)
	glob.ds_dump[data["text"]] = glob.create_dataset(rand_dataset_id, data["text"])
	glob.tree_windows["ds"].reload_scenes()
	go_away()



func _on_trainn_released() -> void:
	$ColorRect/Label.update_valid()
	if $ColorRect/Label.is_valid:
		resultate({"text": $ColorRect/Label.text})

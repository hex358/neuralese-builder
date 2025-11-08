extends SplashMenu

func _ready() -> void:
	super()
	$ColorRect/Label.set_is_valid_call(func(input):
		#print(graphs.get_input_graph_by_name(input))
		return len(input)> 0 and graphs.get_input_graph_by_name(input))
	un_all()
	_on_onnx_released()

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
	#if $ColorRect/Label.is_valid:
	#	resultate({"text": $ColorRect/Label.text})


@onready var buts = [$ColorRect/windows, $ColorRect/linux, $ColorRect/onnx, $ColorRect/tensor]

func un_all():
		#switch.base_modulate = Color(0.583, 0.578, 0.85) * 1.3
		#switch.text = "I"
	for switch in buts:
		switch.base_modulate = Color(0.583, 0.578, 0.85) * 0.7

func on(who: BlockComponent):
	who.base_modulate = Color(0.583, 0.578, 0.85) * 1.3

func _on_tensor_released() -> void:
	un_all()
	on(buts[3])


func _on_onnx_released() -> void:
	un_all()
	on(buts[2])


func _on_linux_released() -> void:
	un_all()
	on(buts[1])


func _on_windows_released() -> void:
	un_all()
	on(buts[0])

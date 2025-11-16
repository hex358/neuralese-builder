extends SplashMenu

func _ready() -> void:
	super()
	$ColorRect/Label.set_is_valid_call(func(input):
		#print(graphs.get_input_graph_by_name(input))
		return len(input)> 0 and graphs.get_input_graph_by_name(input))
	un_all()
	quant_un_all()
	_on_onnx_released()
	_on_int_8_released()

func _process(delta: float) -> void:
	super(delta)

func _splash():
	if $ColorRect/Label.text:
		$ColorRect/Label.update_valid()

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
		var got = graphs.get_input_graph_by_name($ColorRect/Label.text)
		web.POST("export", {"user": cookies.user(), "pass": cookies.pwd(), 
		"graph": graphs.get_syntax_tree(got),
		"context": str(got.context_id), "scene_id": glob.get_project_id(),
		"quant": type_quant,
		"platform": type})
	#	resultate({"text": $ColorRect/Label.text})


@onready var buts = [$ColorRect/windows, $ColorRect/linux, $ColorRect/onnx, $ColorRect/tensor]
@onready var quants = [$ColorRect/quant/float16, $ColorRect/quant/int8, $ColorRect/quant/none]

func un_all():
		#switch.base_modulate = Color(0.583, 0.578, 0.85) * 1.3
		#switch.text = "I"
	for switch in buts:
		switch.base_modulate = Color(0.583, 0.578, 0.85) * 0.7

func quant_un_all():
		#switch.base_modulate = Color(0.583, 0.578, 0.85) * 1.3
		#switch.text = "I"
	for switch in quants:
		switch.base_modulate = Color(0.583, 0.578, 0.85) * 0.7

var type: String = ""
func on(who: BlockComponent):
	who.base_modulate = Color(0.583, 0.578, 0.85) * 1.3
	type = who.hint

var type_quant: String = ""
func qon(who: BlockComponent):
	who.base_modulate = Color(0.583, 0.578, 0.85) * 1.3
	type_quant = who.hint

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


func _on_float_16_released() -> void:
	quant_un_all()
	qon(quants[0])

func _on_int_8_released() -> void:
	quant_un_all()
	qon(quants[1])

func _on_none_released() -> void:
	quant_un_all()
	qon(quants[2])

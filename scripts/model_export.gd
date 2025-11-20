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

@onready var dl_but = $ColorRect/train
func set_downloading():
	$ColorRect/ProgressBar.show()
	dl_but.hide()

func reset_downloading():
	$ColorRect/ProgressBar.hide()
	dl_but.show()

@onready var export_but: BlockComponent = $ColorRect/train
func _on_trainn_released() -> void:
	$ColorRect/Label.update_valid()
	
	if $ColorRect/Label.is_valid:
		set_downloading()
		#await glob.wait(1)
		#reset_downloading()
		#return
		export_but.text = "  Export"
		var got = graphs.get_input_graph_by_name($ColorRect/Label.text)
		var handle = web.POST("export", {"user": cookies.user(), "pass": cookies.pwd(), 
		"graph": graphs.get_syntax_tree(got),
		"context": str(got.context_id), "scene_id": glob.get_project_id(),
		"quant": type_quant,
		"platform": type}, false, true)
		#handle.on_chunk.connect(print)
		var a = await handle.completed
		#print(a)
		if a and a['body']:
			var ext = ".bin"
			match type:
				"windows":ext = ".exe"
				"linux":ext = ""
				"onnx":ext = ".onnx"
				"tensorrt":ext = ".trt"
			var filename = 'model_%s_%s%s' % [$ColorRect/Label.text, type_quant, ext]

			#print(OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS) + "/%s"%filename)
			#print("a")
			var f = FileAccess.open(OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS) + "/%s"%filename, FileAccess.WRITE)
			f.store_buffer(a["body"])
			f.close()
			reset_downloading()
			export_but.text = "  Saved!"
			#print(export_but.text)
			#await glob.wait(1.0)
			#export_but.text = "   Downloads"
			await glob.wait(1.0)
			export_but.text = "  Export"
		#print(a["body"].size() / 1024.0)
		reset_downloading()
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

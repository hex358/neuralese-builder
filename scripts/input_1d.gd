extends DynamicGraph

func _get_unit(kw: Dictionary) -> Control: #virtual
	var dup = _unit.duplicate()
	dup.get_node("Label").text = kw["text"]
	dup.show()
	dup.modulate.a = 0.0
	appear_units[dup] = true
#	dup.server_name = 
	if kw["features"]["type"] == "class":
		dup.get_node("loss").graph = dup
		dup.get_node("loss").auto_ready = true
	if kw["features"]["type"] == "bool":
		dup.get_node("bool").graph = dup
		dup.get_node("bool").auto_ready = true
	return dup

func class_unroll(frozen_duplicate: BlockComponent, args, kwargs):
	var output: Array[Node] = []
	var lines = []
	var i: int = 0
	for _i in args:
		i += 1
		var new: BlockComponent = frozen_duplicate.duplicate()
		new.placeholder = false
		new.text = _i
		new.auto_ready = true
		new.hint = _i
		output.append(new)
	return output


var hsliders = {}
func _adding_unit(who: Control, kw: Dictionary):
	
	who.set_meta("kw", kw)
	var idx = who

	who.get_node("HSlider").hide()
	who.get_node("Label2").hide()
	who.get_node("val").hide()
	who.get_node("loss").hide()
	who.get_node("bool").hide()
	
	if kw["features"]["type"] != "class":
		who.get_node("loss").queue_free()
	if kw["features"]["type"] != "bool":
		who.get_node("bool").queue_free()
	
	match kw["features"].get("type"):
		"int":
			who.get_node("val").show()
			who.get_node("val").min_value = features.get_or_add("min", 0)
			who.get_node("val").max_value = features.get_or_add("max", 80)
			hsliders[idx] = who.get_node("val")
			who.get_node("val").tree_exiting.connect(func(): hsliders.erase(idx))
		#	who.get_node("ColorRect").size.y -= 5
		"float":
			var hslider = who.get_node("HSlider")
			hslider.value_changed.connect(hslider_val_changed.bind(hslider, kw))
			hslider.show()
			who.get_node("Label2").show()
			#print(kw)
			hslider.tree_exiting.connect(func(): hsliders.erase(idx))
			hsliders[idx] = hslider
			#await get_tree().process_frame
			kw["min"] = 0.0
			kw["max"] = 1.0
			hslider_val_changed(0.0, hslider, kw)
		"class":
			var got = who.get_node("loss")
			got.show()
			hsliders[idx] = who.get_node("loss")
			got.predelete.connect(func(): hsliders.erase(idx))
			who.get_node("loss").released.connect(set_class.bind(kw, who.get_node("loss")))
			await get_tree().process_frame
			kw["n"] = -1
			set_class(kw, got)
			#set_class(kw, got)
			#who.get_node("loss").predelete.connect(func(): hsliders.erase(idx))
		"bool":
			var got = who.get_node("bool")
			got.show()
			hsliders[idx] = who.get_node("bool")
			got.predelete.connect(func(): hsliders.erase(idx))
			who.get_node("bool").released.connect(set_weight_dec.bind(kw, who.get_node("bool")))
			await get_tree().process_frame
			set_weight_dec(kw, got)
			set_weight_dec(kw, got)
			#who.get_node("bool").predelete.connect(func(): hsliders.erase(idx))

	await get_tree().process_frame
	if get_ancestor():
		graphs.model_updated.emit(get_ancestor().cfg["name"])

func set_class(kw: Dictionary, switch):
	kw = kw["features"]
	switch.text = kw["classes"][kw["n"]]
	kw["n"] += 1
	if kw["n"] == len(kw["classes"]):
		kw["n"] = 0


func set_weight_dec(kw: Dictionary, switch):
	var on: bool = kw.get("on", true)
	if on:
		switch.base_modulate = Color(0.85, 0.85, 0.85, 1.0) * 1.3
		switch.text = "I"
	else:
		switch.base_modulate = Color(0.85, 0.85, 0.85, 1.0) * 0.7
		switch.text = "O"
	kw["on"] = !on


func to_tensor(cells: bool = false):
	var a = []
	for i in units:
		var features = i.get_meta("kw")["features"]
		match features.type:
			"float":
				a.append(i.get_value() if !cells else [i.get_value()])
			"int":
				a.append(i.get_value() if !cells else [i.get_value()])
			"bool":
				if !cells:
					a.append(1.0 if features.get("on", false) else 0.0)
				else:
					a.append([1.0 if features.get("on", false) else 0.0])
			"class":
				var slices = []
				slices.resize(len(features["classes"]))
				slices.fill(0.0)
				slices[features["n"]-1] = 1.0
				if not cells:
					a.append_array(slices)
				else:
					a.append(slices)
	return a



func hslider_val_changed(val: float, slider: HSlider, kw: Dictionary):
	var k = (val / slider.max_value)
	var fit = k
	var capped = str(glob.cap(fit, 2))
	if len(capped.split(".")[-1]) == 1: capped += "0"
	slider.get_parent().get_node("Label2").text = capped


func _useful_properties() -> Dictionary:
	var input_features = []
	for i in units:
		input_features.append({"value": i.get_value(), "features": i.get_meta("kw").get("features", {})})
	return {
		"raw_values": [0.0],
		"config": {"input_features": input_features,
		"subname": "Input1D"}, "shape": len(to_tensor())
	}


var value_cache: Array = []
var manually: bool = false
func unit_set(unit, value, text):
	units[unit].set_weight(text)

func _config_field(field: StringName, value: Variant):
	#print(cfg)
	if not manually and field == "input_features":
		for i in len(units):
			remove_unit(0)
		for i in len(value):
			if value[i] is Dictionary: pass
			else: continue
			add_unit(value[i])
		#	units[i].get_node("Label").text = value[i]
		push_values(value_cache, per)
	#if not upd and field == "title":
	#	$ColorRect/root/Label.set_line(value)
	#	ch()


func something_focus() -> bool:
	if ui.is_focus($input/tabs/int/min): return true
	if ui.is_focus($input/tabs/int/max): return true
	return false

func _can_drag() -> bool:
	if features["type"] == "class" and ui.is_focus($input/tabs/class/Control/HFlowContainer.line_edit):
		return false
	if not super(): return false
	if something_focus(): return false
	if run_but.is_mouse_inside(): return false
	#print(hsliders)
	for i in hsliders.values():
		if ui.is_focus(i):
			return false
		if i is BlockComponent and i.is_mouse_inside(): return false
	return true
#	return super() and not ui.is_focus($ColorRect/root/Label)

func _proceed_hold() -> bool:
	#if prev_adding_size:
	#	return true
	if features["type"] == "class" and ui.is_focus($input/tabs/class/Control/HFlowContainer.line_edit):
		return true
	if something_focus(): return true
	for i in hsliders.values():
		if ui.is_focus(i):
			return true
		if i is BlockComponent and i.is_mouse_inside(): return true
	if not super(): return false
	return false
	#return ui.is_focus($ColorRect/root/Label)


func get_title() -> String:
	return $ColorRect/root/Label.text

var per: bool = false
func push_values(values: Array, percent: bool = false):
	per = percent
	var minimal = values.min() if !percent else 0.0
	var maximal = values.max() if !percent else 1.0
	var add = "%" if percent else ""
	for unit in len(values):
		var value = (values[unit] - minimal) / float(maximal - minimal)
		var capped = glob.cap(values[unit], 2) if !percent else round(values[unit]*100.0)
		if unit >= len(units): continue
		if percent:
			unit_set(unit, value, str(capped)+"%")
		else:
			unit_set(unit, value, str(capped))
	for unit in range(len(values), len(units)):
		if percent:
			unit_set(unit, 0.0, "0%")
		else:
			unit_set(unit, 0.0, "0.0")
	var res = []
	for i in units: 
		res.append(i.get_meta("kw"))
	manually = true
	update_config({"input_features": res})
	manually = false



func _unit_just_added() -> void:
	var ancestor = get_first_ancestors()
	if ancestor: 
		if ancestor[0].server_typename == "SoftmaxNode":
			push_values(value_cache, true)
		else:
			push_values(value_cache, false)
	else:
		push_values(value_cache, false)

func get_netname():
	for i in get_first_ancestors():
		if i.server_typename == "ModelName":
			return i
	return null




var res_meta: Dictionary = {}
func push_result_meta(meta: Dictionary):
	res_meta = meta
	ch()


func repr():
	var tensorified: PackedStringArray = []
	#for i in to_tensor(true):
	#	tensorified.append(str(len(i)))
	return base_dt + "(" +str( len(to_tensor())) + ")"

func validate(pack: Dictionary):
	return base_dt == pack.get("datatype", "") and pack.get("x", 0) == len(to_tensor())

var target_tab: String = ""
func _after_process(delta: float):
#	print(adding_size_y)
	#print(to_tensor())
	super(delta)
	if target_tab:
		for i in input.get_node("tabs").get_children():
			if i.name != target_tab:
				if 1:
					i.modulate.a = lerpf(i.modulate.a, 0.0, delta * 20.0)
					if i.modulate.a < 0.01:
						i.hide()
						
						adding_size_y = tg
			else:
				i.show()
				i.modulate.a = lerpf(i.modulate.a, 1.0, delta * 20.0)
	#print(cfg)
	#push_values(range(len(units)), true)
	if nn.is_infer_channel(self) and glob.space_just_pressed:
		nn.send_inference_data(self, useful_properties())
	if features["type"] == "class":
		var hflow = $input/tabs/class/Control/HFlowContainer
		adding_size_y = 18 + max((hflow.size.y-18)*$input/tabs/class/Control.scale.y, 0)
	
	
	#print($input/tabs/class/Control.custom_minimum_size.y)

func _unit_removal(id: int):
	await get_tree().process_frame
	if get_ancestor():
		graphs.model_updated.emit(get_ancestor().cfg["name"])

func ch():
	var target = graphs._reach_input(self)
	if !target: return
	var got = graphs.get_input_name_by_graph(target)
	if got:
		graphs.model_updated.emit(got)

func _on_color_rect_2_pressed() -> void:
	if features["type"] == "class":
		if not $input/tabs/class/Control/HFlowContainer.tags:
			return
	if line_edit.is_valid:
		await get_tree().process_frame
		#ui.click_screen(line_edit.global_position + Vector2(10,10))
		var maximal = float($input/tabs/int/max.text) if $input/tabs/int/max.text else 80
		var minimal = float($input/tabs/int/min.text) if $input/tabs/int/min.text else 0.0
		features["min"] = min(maximal, minimal)
		features["max"] = max(maximal, minimal)
	#	line_edit.grab_focus()
		if features["type"] == "class":
			features["classes"] = $input/tabs/class/Control/HFlowContainer.tags.duplicate()
			$input/tabs/class/Control/HFlowContainer.clear()
		add_unit({"text": line_edit.text, "features": features.duplicate()})
		line_edit.clear()


var upd = false
signal label_changed(text: String)
func _on_label_changed() -> void:
	ch()
	upd = true
	#update_config({"title": $ColorRect/root/Label.text})
	upd = false
	#var netname = target.get_netname()
	#if netname:
	#	netname.reload()
	#label_changed.emit($ColorRect/root/Label.text)


func _ready() -> void:
	super()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	#if not features.get("type"):
	#	_on_type_child_button_release($input/type.button_by_hint["float"])

var features = {"type": "float"}

var tg: float = 0.0
func _on_type_child_button_release(button: BlockComponent) -> void:
	button.is_contained.text = button.text
	button.is_contained.menu_hide()
	target_tab = str(button.hint)
	#var other = input.get_node("tabs").get_node(NodePath(button.hint))
	#if other: other.show()
	if button.hint == "class":
		#features["classes"] = ["hello", "hi", "returtttn"]
		features["n"] = 0
	features["type"] = button.hint
	if button.hint == "class" or button.hint == "int":
		tg = 30.0
		adding_size_y = tg
	else:
		tg = 0.0

@onready var run_but = $run
var running: bool = false
func _on_run_released() -> void:
	if not nn.is_infer_channel(self):
		running = true
		run_but.text_offset.x = 0
		run_but.text = "Stop"
		nn.open_infer_channel(self, close_runner)
	else:
		#run_but.text = "Run!"
		#run.text_offset.x = 2
		#running = false
		nn.close_infer_channel(self)

func close_runner():
	run_but.text_offset.x = 2
	run_but.text = "Run!"
	running = false
	nn.close_infer_channel(self)
		

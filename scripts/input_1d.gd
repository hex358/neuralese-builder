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
		for child in dup.get_node("loss").get_children():
			if child is BlockComponent:
				child.auto_ready = true
	if kw["features"]["type"] == "bool":
		dup.get_node("bool").graph = dup
		dup.get_node("bool").auto_ready = true
	return dup

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
			hslider_val_changed(0.0, hslider, kw)
		"class":
			who.get_node("loss").show()
			hsliders[idx] = who.get_node("loss")
			#who.get_node("loss").predelete.connect(func(): hsliders.erase(idx))
		"bool":
			who.get_node("bool").show()
			hsliders[idx] = who.get_node("bool")
			#who.get_node("bool").predelete.connect(func(): hsliders.erase(idx))

func hslider_val_changed(val: float, slider: HSlider, kw: Dictionary):
	var k = (val / slider.max_value)
	var fit = lerp(kw["features"].get("min", 0.0), kw["features"].get("max", 1.0), k)
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
		"subname": "Input1D"},
	}


var value_cache: Array = []
var manually: bool = false
func unit_set(unit, value, text):
	units[unit].set_weight(text)

func _config_field(field: StringName, value: Variant):
	#print(cfg)
	if not manually and field == "input_features":
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
	if ui.is_focus($input/tabs/float/min): return true
	if ui.is_focus($input/tabs/float/max): return true
	return false

func _can_drag() -> bool:
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

var target_tab: String = ""
func _after_process(delta: float):
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

func ch():
	var target = graphs._reach_input(self)
	if !target: return
	var got = graphs.get_input_name_by_graph(target)
	if got:
		graphs.model_updated.emit(got)

func _on_color_rect_2_pressed() -> void:
	if line_edit.is_valid:
		await get_tree().process_frame
		#ui.click_screen(line_edit.global_position + Vector2(10,10))
		var maximal = float($input/tabs/float/max.text) if $input/tabs/float/max.text else 1.0
		var minimal = float($input/tabs/float/min.text) if $input/tabs/float/min.text else 0.0
		features["min"] = min(maximal, minimal)
		features["max"] = max(maximal, minimal)
		line_edit.grab_focus()
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
	if not features.get("type"):
		_on_type_child_button_release($input/type.button_by_hint["int"])

var features = {"type": ""}

var tg: float = 0.0
func _on_type_child_button_release(button: BlockComponent) -> void:
	button.is_contained.text = button.text
	button.is_contained.menu_hide()
	target_tab = str(button.hint)
	#var other = input.get_node("tabs").get_node(NodePath(button.hint))
	#if other: other.show()
	features["type"] = button.hint
	if button.hint == "class" or button.hint == "float":
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
		

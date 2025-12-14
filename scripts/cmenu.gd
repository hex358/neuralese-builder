@tool
extends BlockComponent


func _menu_handle_release(button: BlockComponent):
	#freeze_input()
	#glob.menus["subctx"].pos = Vector2(position.x - glob.menus["subctx"].base_size.x * 0.75, get_global_mouse_position().y)
	#glob.menus["subctx"].show_up(["hi", "hello"], null)
	
	
	#return
	var type = button.hint
	#match button.hint:
		#"layer":
			#type = "layer"
		#"act":
			#type = "neuron"
		#"input1d":
			#type = "input_1d"
		#"input":
			#type = "input"
		#"train_input":
			#type = "train_input"
		#"softmax":
			#type = "softmax"
		#"reshape2d":
			#type = "reshape2d"
		#"flatten":
			#type = "flatten"
		#"conv2d":
			#type = "conv2d"
		#"maxpool":
			#type = "maxpool"
		#"classifier":
			#type = "classifier"
		#"train_begin":
			#type = "train_begin"
		#"augmenter":
			#type = "augmenter"
		#"run_model":
			#type = "run_model"
		#"model_name":
			#type = "model_name"
		#"dataset":
			#type = "dataset"
		#"augment_tf":
			#type = "augment_tf"
		#"output_map":
			#type = "output_map"
		#"lua_env":
			#type = "lua_env"
		#"train_rl":
			#type = "train_rl"
		#"dropout":
			#type = "dropout"
		#"concat":
			#type = "concat"

	var graph = graphs.get_graph(type, Graph.Flags.NEW)
	var world_pos = graphs.get_global_mouse_position()
	graph.global_position = world_pos - graph.rect.position - graph.rect.size / 2
	#await glob.wait(0.1)
	menu_hide()
	#unfreeze_input()

@export var name_groups: Array[PackedStringArray] = []

func _ready():
	if Engine.is_editor_hint():
		return

	var base: BlockComponent = $"5".duplicate()
	for child in get_children():
		if child is BlockComponent:
			child.free()

	# Build quick access: name -> button
	var button_map: Dictionary = {}

	for i in graphs.graph_buttons:
		if not i.name in glob.base_node.importance_chain:
			continue

		var dup: BlockComponent = base.duplicate()
		var title = i.title
		#print(i.name, " ", title)
		var pr = title
		match i.name:
			"model_name": title = "ModelName"
			"neuron": title = "Activation"
			"softmax": title = "Softmax"
			"layer": title = "DenseLayer"
			"conv2d": title = "Conv2DLayer"
			"flatten": title = "Flatten1D"
			"lua_env": title = "RLEnviron"
			"train_input": title = "TrainStep"
			"input": title = "Input2D"
		if title != pr:
			print(i.name, " ", title)
		dup.hint = i.name
		dup.text = title
		var outline_color: Color = _lift_color(i.outline_color, 0.65)
		var tuning_color: Color = _lift_color(i.tuning, 0.65)
		tuning_color.a = 0.7
		dup.set_instance_shader_parameter("outline_color", outline_color)
		dup.set_instance_shader_parameter("tuning", tuning_color)

		button_map[i.name] = dup

	# --- Build final list following exact order in name_groups ---
	var final_buttons: Array = []
	var used_names: Dictionary = {}

	for group in name_groups:
		for name in group:
			if button_map.has(name):
				final_buttons.append(button_map[name])
				used_names[name] = true

	# --- Add ungrouped buttons at the end, preserving discovery order ---
	for i in graphs.graph_buttons:
		if not i.name in used_names and i.name in button_map:
			final_buttons.append(button_map[i.name])

	# --- Add them in final order ---
	for btn in final_buttons:
		add_child(btn)

	super()





func _lift_color(c: Color, min_v: float = 0.55) -> Color:
	var hsv = _rgb_to_hsv(c)
	if hsv.v < min_v:
		hsv.v = min_v
	return _hsv_to_rgb(hsv.h, hsv.s, hsv.v, c.a)


func _rgb_to_hsv(c: Color) -> Dictionary:
	var r = c.r
	var g = c.g
	var b = c.b
	var max_c = max(r, g, b)
	var min_c = min(r, g, b)
	var delta = max_c - min_c
	var h = 0.0
	if delta != 0.0:
		if max_c == r:
			h = fmod((g - b) / delta, 6.0)
		elif max_c == g:
			h = ((b - r) / delta) + 2.0
		else:
			h = ((r - g) / delta) + 4.0
	h *= 60.0
	if h < 0.0:
		h += 360.0
	var s = 0.0 if max_c == 0.0 else delta / max_c
	return {"h": h / 360.0, "s": s, "v": max_c}


func _hsv_to_rgb(h: float, s: float, v: float, a: float = 1.0) -> Color:
	h *= 6.0
	var i = int(floor(h)) % 6
	var f = h - floor(h)
	var p = v * (1.0 - s)
	var q = v * (1.0 - f * s)
	var t = v * (1.0 - (1.0 - f) * s)
	match i:
		0:
			return Color(v, t, p, a)
		1:
			return Color(q, v, p, a)
		2:
			return Color(p, v, t, a)
		3:
			return Color(p, q, v, a)
		4:
			return Color(t, p, v, a)
		_:
			return Color(v, p, q, a)

func _sub_process(delta):
	pass
	#print(pos_clamp(get_global_mouse_position()))
	#print(DisplayServer.window_get_size())
	
	#print(global_position.y)
	#print(expanded_size)

var menu = null

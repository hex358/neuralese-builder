extends Graph

func get_training_data():
	return {"epochs": epochs if epochs else 1, "dataset": "datasets/mnist.ds", "test_dataset": "datasets/mnist_test.ds"}

var dataset_meta: Dictionary = {}

func display_ds_meta():
	pass

func set_dataset_meta(meta: Dictionary):
	dataset_meta = meta
	display_ds_meta()
	for i in graphs.get_cache("", self):
		i.push_meta(self, dataset_meta)
	#print(dataset_meta)
	set_meta("input_features", dataset_meta.get("inputs", {}))
	await get_tree().process_frame
#	print(get_descendant())
#	print(get_descendant().input_keys[0].hint)
	if get_descendant() and not get_descendant()._is_suitable_other_conn(outputs[0], get_descendant().input_keys[0]):
		#print(get_descendant()._is_suitable_conn(outputs[0], get_descendant().input_keys[0]))
		#await get_tree().process_frame
		#print(dataset_meta["name"])
		outputs[0].disconnect_all()

#func _just_attached(other_conn: Connection, my_conn: Connection):
		#set_dataset_meta({"name": "mnist", "outputs": [
		#{"label": "bbox", "length": 5, "dtype": "1d"}, {"label": "bbox", "length": 5, "dtype": "1d"}
	#]})

func _ready() -> void:
	super()
	#set_dataset_meta({"name": "mnist", "outputs": [
	#	{"label": "bbox", "length": 5, "dtype": "1d"}, {"label": "bbox", "length": 5, "dtype": "1d"}
	#]})
	graphs.spline_connected.connect(func(from: Connection, to: Connection):
		if to.parent_graph.server_typename == "OutputMap" and not to.virtual:
			var reached = graphs._reach_input(to.parent_graph, "TrainBegin")
			if reached and reached == self:
				graphs.bind_cache(to.parent_graph, "", self)
				to.parent_graph.push_meta(self, dataset_meta)
		#else:
			#var reached = graphs._reach_input(to.parent_graph, "TrainBegin")
			#if reached and reached == self:
				#graphs.bind_cache(to.parent_graph, "", self)
			##	to.parent_graph.push_meta(self, dataset_meta)
				#to.parent_graph.set_meta("input_features", dataset_meta.get("inputs", {}))
				#to.parent_graph.set_meta("inputs_owner", self)
			)
	graphs.spline_disconnected.connect(func(from: Connection, to: Connection):
		if to.parent_graph.server_typename == "OutputMap" and not to.virtual:
			if to.parent_graph.meta_owner == self:
				graphs.uncache(to.parent_graph, "", self)
				to.parent_graph.unpush_meta()
		#elif to.parent_graph.get_meta("input_owner") == self:
			#
			#to.parent_graph.set_meta("input_features", {})
			#to.parent_graph.set_meta("inputs_owner", null)
				#
			##var reached = graphs._reach_input(to.parent_graph, "TrainBegin")
			##if reached and reached == self and not to.virtual:
			##	to.parent_graph.push_meta(dataset_meta["outputs"])
			)
	

func get_training_head():
	var r = []
	var def_call = func(from: Connection, to: Connection, branch_cache: Dictionary):
		if graphs.is_node(to.parent_graph, "TrainInput"):
			r.append(to.parent_graph)
	graphs.reach(self, def_call)
	return r[0] if r else null

func _can_train() -> bool:
	var res = true
	return res

func additional_call(dict):
	if training:
		if dict["phase"] == "state":
			#print(dict)
			if "epoch" in dict["data"] and $YY.text.is_valid_int():
				var new_text = max(0, int(dict["data"].get("left", 0))-1)
				$YY.set_line(str(new_text) if new_text else "")
		if dict["phase"] == "done":
			train_stop(true)

var epochs: int = 0

var training: bool = false
var delaying: bool = false
func train_stop(force: bool = false):
	#$ColorRect2.alive = false
	if training and (not delaying or force) and _can_train():
		$YY.editable = true
		var a = func():
			delaying = true
			await glob.wait(2)
			delaying = false
		training = false
		train.text = "Train!"
		if old_head:
			old_head.train_stop()
			nn.stop_train(old_head)
		a.call()
		if int($YY.text) <= 1:
			$YY.set_line("")

func _can_drag() -> bool:
	return not train.is_mouse_inside() and not ui.is_focus($YY)

func _proceed_hold() -> bool:
	#if glob.space_just_pressed:
	#	set_dataset_meta({"outputs": [{"label": "hii"}]})
	return ui.is_focus($YY)

var old_head = null
func train_start():
	#timing_offset = -$ColorRect2.get_time()
	if not training and not delaying:
		$YY.editable = false
		training = true
		train.text = "Stop"
		old_head = get_training_head()
		#print(old_head)
		if not $YY.text: $YY.set_line("1"); epochs = 1
		else: epochs = int($YY.text)
		if old_head:
			#print("AA")
			old_head.train_start()
			nn.start_train(old_head, additional_call)
		#print($YY.text)

@onready var train = $train
func _on_train_released() -> void:
	if training:
		train_stop()
	else:
		train_start()

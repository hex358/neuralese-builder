extends Graph

func get_training_data():
	return {"epochs": epochs if epochs else 1, "dataset": "datasets/mnist.ds", "test_dataset": "datasets/mnist_test.ds"}

func get_training_head():
	var r = []
	var def_call = func(from: Connection, to: Connection, branch_cache: Dictionary):
		if graphs.is_node(to.parent_graph, "TrainInput"):
			r.append(to.parent_graph)
	graphs.reach(self, def_call)
	return r[0] if r else null

func additional_call(dict):
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
	if training and (not delaying or force):
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
			old_head.train_start()
			nn.start_train(old_head, additional_call)
		#print($YY.text)

@onready var train = $train
func _on_train_released() -> void:
	if training:
		train_stop()
	else:
		train_start()

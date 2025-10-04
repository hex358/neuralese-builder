extends Node

func train_state_received(bytes: PackedByteArray):
	var jsonified = bytes.get_string_from_utf8()
	var dict = JSON.parse_string(jsonified)
	if not "phase" in dict: return
	if dict["phase"] == "state":
		if dict["data"]["type"] == "complete":
			graphs._training_head.train_stop()
			return
		var data = dict["data"]["data"]
		var loss = data["val_loss"]
		graphs._training_head.push_acceptance(1.0 - loss, 0.0)

	#var chain = branch_cache.get_or_add("chain", [])
	#if  (chain and chain[-1].server_typename in block_types): return
	#chain.append(from.parent_graph)
	#
	#if to.parent_graph.server_typename == "Flatten":
		#to.parent_graph.set_count(count_reach)
#
#func _just_deattached(other_conn: Connection, my_conn: Connection):
	#set_count(0)
	#graphs.update_dependencies(self)
	#graphs.update_dependencies(self)
	#count_reach = 0
	#graphs.reach(self, call_count)

func request_save():
	for g in graphs._graphs:
		graphs._graphs[g].request_save()

var training_sockets = {}
func start_train(train_input: Graph, args: Dictionary = {}):
	var train_input_origin = graphs._reach_input(train_input, "TrainBegin")
	var execute_input_origin = null
	var _d = {}
	var cachify = func(from: Connection, to: Connection, branch_cache: Dictionary):
		if to.parent_graph.server_typename == "RunModel":
			assert(not _d.get("input"), "compile failed, run_model node >1 times banned")
			
			_d["input"] = graphs.get_input_graph_by_name(to.parent_graph.name_graph)
	#var all = 
	#print(train_input_origin)
	graphs.reach(train_input_origin, cachify)
	execute_input_origin = _d["input"]
	if !is_instance_valid(train_input_origin) or !execute_input_origin: return
	#print(execute_input_origin.server_typename)
	#print(train_input_origin.server_typename)
	request_save()
	var compressed = glob.compress_dict_gzip({
		"session": "neriqward",
		"graph": graphs.get_syntax_tree(execute_input_origin),
		"train_graph": graphs.get_syntax_tree(train_input_origin),
	})
	var a = sockets.connect_to("ws/train", train_state_received)
	training_sockets[train_input] = a
	a.connected.connect(func():
		a.send(compressed))
	a.closed.connect(func(...x):
		train_input.train_stop())

func stop_train(train_input: Graph):
	if not train_input in training_sockets:
		#web.POST("end_train", {})
		return
	training_sockets[train_input].send(glob.compress_dict_gzip({"stop": "true"}))


# ---------------- Inference channel (open/close only) ----------------

var inference_sockets := {}

func _infer_state_received(bytes: PackedByteArray) -> void:
	# Minimal handler for now (open/close only). Intentionally no UI logic.
	# You can expand this later to route "inference"/"error"/"stopped" phases.
	var _dict = JSON.parse_string(bytes.get_string_from_utf8())
	print(_dict)
	# noop


func is_infer_channel(input: Graph) -> bool:
	return input in inference_sockets and is_instance_valid(inference_sockets[input])

func open_infer_channel(input: Graph) -> void:
	if input in inference_sockets and is_instance_valid(inference_sockets[input]):
		return # already open
	request_save()
	var init_payload = {
		"session": "neriqward",
		"graph": graphs.get_syntax_tree(input)
	}
	var sock = sockets.connect_to("ws/infer", _infer_state_received)
	inference_sockets[input] = sock
	sock.connected.connect(func() -> void:
		sock.send(glob.compress_dict_gzip(init_payload))
	)
	sock.closed.connect(func(...x) -> void:
		if input in inference_sockets:
			inference_sockets.erase(input)
	)


func send_inference_data(input: Graph, data: Dictionary) -> void:
	# make sure channel is open
	print("try push!")
	if not (input in inference_sockets):
		push_warning("No inference channel open for this graph")
		return
	var sock = inference_sockets[input]
	if not is_instance_valid(sock):
		push_warning("Socket instance is no longer valid")
		inference_sockets.erase(input)
		return
	var do_update: bool = false
	var syntax = null

	var payload = {"data": data}
	var compressed = glob.compress_dict_gzip(payload)
	sock.send(compressed)

func _process(delta: float) -> void:
	pass
	if not is_instance_valid(graphs._input_origin_graph): return
	if Input.is_action_just_pressed("ui_accept"):
		if !is_infer_channel(graphs._input_origin_graph):
			open_infer_channel(graphs._input_origin_graph)
		else:
			send_inference_data(graphs._input_origin_graph, graphs._input_origin_graph.useful_properties())
	if Input.is_action_just_pressed("ui_x"):
		close_infer_channel(graphs._input_origin_graph)


func close_infer_channel(input: Graph) -> void:
	if not (input in inference_sockets):
		return
	var sock = inference_sockets[input]
	# Ask server/worker to stop, then the server will close the WS.
	sock.send(glob.compress_dict_gzip({"stop": "true"}))

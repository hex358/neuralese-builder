extends Node

func train_state_received(bytes: PackedByteArray, additional: Callable):
	var jsonified = bytes.get_string_from_utf8()
	var dict = JSON.parse_string(jsonified)
	if not dict: return
	if not "phase" in dict: return
	additional.call(dict)
	if dict["phase"] == "state":
	#	print(dict)
		if dict["data"]["type"] == "complete":
			graphs._training_head.train_stop()
			return
		#print(dict)
		var data = dict["data"]["data"]
		var acc = data["val_acc"]
		#print(loss)
		graphs._training_head.push_acceptance(acc, 0.0)



func request_save():
	for g in graphs._graphs:
		graphs._graphs[g].request_save()

var training_sockets = {}
func start_train(train_input: Graph, additional_call: Callable = glob.def, run_but: BlockComponent = null) -> bool:
	if not await glob.splash_login(run_but): return false
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
	if !is_instance_valid(train_input_origin) or !execute_input_origin: return false
	#print(execute_input_origin.server_typename)
	#print(train_input_origin.server_typename)
	request_save()
	var compressed = glob.compress_dict_zstd({
		"session": "neriqward",
		"graph": graphs.get_syntax_tree(execute_input_origin),
		"train_graph": graphs.get_syntax_tree(train_input_origin),
		"scene_id": str(glob.get_project_id()),
		"context": str(execute_input_origin.context_id)
	}.merged(train_input_origin.get_training_data()))
	#print(compressed)
	var a = sockets.connect_to("ws/train", train_state_received.bind(additional_call), cookies.get_auth_header())
	training_sockets[train_input] = a
	a.connected.connect(func():
		a.send(compressed))
	a.kill.connect(func(...x):
		#print("AA")
		train_input_origin.train_stop(true))
	return true

func stop_train(train_input: Graph):
	if not train_input in training_sockets:
		#web.POST("end_train", {})
		return
	training_sockets[train_input].send(glob.compress_dict_zstd({"stop": "true"}))
	training_sockets.erase(train_input)



var inference_sockets := {}

func _infer_state_received(bytes: PackedByteArray, ws: SocketConnection):
	var _dict = JSON.parse_string(bytes.get_string_from_utf8())
	var outs = {}
	if _dict and _dict is Dictionary:
		if "ack" in _dict:
			#print("ACK")
			ws.ack.emit()
		if "result" in _dict and _dict["result"] is Dictionary:
			for i in _dict["result"]:
				var node: Graph = graphs._graphs.get(int(i))
				if not node: continue
				for to_push in _dict["result"][i].values():
					if node.is_head:
						var flattened = glob.flatten_array(to_push)
						node.push_values(flattened, node.per)
						outs[node.get_title()] = flattened
	return outs
	#print(_dict)


func is_infer_channel(input: Graph) -> bool:
	return input in inference_sockets and is_instance_valid(inference_sockets[input])



func open_infer_channel(input: Graph, on_close: Callable = glob.def, run_but: BlockComponent = null):
#	print(run_but)
	if not await glob.splash_login(run_but):
		return false
	if input in inference_sockets and is_instance_valid(inference_sockets[input]):
		return false# already open
	request_save()
	var init_payload = {
		"session": "neriqward",
		"graph": graphs.get_syntax_tree(input),
		"scene_id": str(glob.get_project_id()),
		"context": str(input.context_id),
	}
	input.set_state_open()
	var sock = sockets.connect_to("ws/infer", Callable(),
	 cookies.get_auth_header())
	sock.packet.connect((func(bytes: PackedByteArray):
		var outs = _infer_state_received(bytes, sock)
		infer_clear(input, outs)
		))
	inference_sockets[input] = sock
	sock.connected.connect(func() -> void:
		sock.send(glob.compress_dict_zstd(init_payload))
	)
	sock.kill.connect(func(...x) -> void:
		if input in inference_sockets:
			inference_sockets.erase(input)
		on_close.call()
	)
	#await sock.connected
	return sock

var inference_polling: Dictionary = {}

func infer_clear(who, outputs: Dictionary):
	inference_polling[who] = outputs


func send_inference_data(input: Graph, data: Dictionary, output: bool = false):
	# make sure channel is open
	if not (input in inference_sockets):
		push_warning("No inference channel open for this graph")
		return
	var sock = inference_sockets[input]
	if not is_instance_valid(sock):
		push_warning("Socket instance is no longer valid")
		inference_sockets.erase(input)
		return
	if input in inference_polling: 
		inference_polling.erase(input)
	inference_polling[input] = true
	var do_update: bool = false
	var syntax = null

	var payload = {"data": data}
	var compressed = glob.compress_dict_zstd(payload)
	sock.send(compressed)
	if output:
		while input in inference_polling and inference_polling[input] is bool:
			await get_tree().process_frame
		if not input in inference_polling:
			return
		var out = inference_polling[input]
		inference_polling.erase(input)
		return out
	inference_polling.erase(input)
	return
	#print(data)

func _process(delta: float) -> void:
	pass

func close_all():
	for i in inference_sockets:
		close_infer_channel(i)
	for i in training_sockets:
		stop_train(i)


func close_infer_channel(input: Graph) -> void:
	if not (input in inference_sockets):
		return
	var sock = inference_sockets[input]
	sock.send(glob.compress_dict_zstd({"stop": "true"}))

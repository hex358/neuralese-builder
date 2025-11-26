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

func ws_ds_frames(train_input_origin: Graph, initial: Dictionary, ws: SocketConnection) -> void:
	var ds_name = train_input_origin.dataset_meta.get("name", "")
	if ds_name == "":
		push_warning("No dataset name found.")
		return
	if not glob.rle_cache.has(ds_name):
		push_warning("Dataset not yet compressed or cached.")
		return

	# --- prepare dataset ---
	await glob.join_ds_processing()
	DsObjRLE.flush_now(ds_name, glob.dataset_datas[ds_name])
	print(DsObjProbe.probe_dataset(ds_name))
	#return
	var ds: Dictionary = glob.rle_cache[ds_name]
	var inputs: Array = ds["data"][0]
	var outputs: Array = ds["data"][1]
	var header: Dictionary = ds["header"]

	var block_hashes := {"inputs": [], "outputs": []}
	for col in inputs:
		block_hashes["inputs"].append(col.get("hashes", []))
	for col in outputs:
		block_hashes["outputs"].append(col.get("hashes", []))

	initial["session"] = "neriqward"
	initial["header"] = header
	initial["header"]["name"] = ds_name
	initial["block_hashes"] = block_hashes
	initial["hash_algo"] = "sha256"

	# --- send header ---
	var header_bytes = glob.compress_dict_zstd(initial)
	ws.send(header_bytes)
	print("[WS] Sent compressed header (%.2f KB)" % [float(header_bytes.size()) / 1024.0])

	# --- shared counters (persist across closure) ---
	var stats := {
		"total_bytes": 0.0,
		"total_blocks": 0,
		"side_bytes": {"inputs": 0.0, "outputs": 0.0}
	}

	# --- packet callback ---
	var _on_packet = func(data: PackedByteArray) -> void:
		var text = data.get_string_from_utf8()
		if text == "__end__":
			return

		var need_json = JSON.parse_string(text)
		if typeof(need_json) != TYPE_DICTIONARY:
			push_warning("Invalid NEED payload: " + text)
			return
		var need: Dictionary = need_json

		var _send_block = func(side: String, col_i: int, blk_i: int, blk_data: PackedByteArray) -> void:
			var meta := {"side": side, "col": col_i, "blk": blk_i}
			var meta_bytes := JSON.stringify(meta).to_utf8_buffer()

			var frame := PackedByteArray()
			frame.append((meta_bytes.size() >> 8) & 0xFF)
			frame.append(meta_bytes.size() & 0xFF)
			frame.append_array(meta_bytes)
			frame.append_array(blk_data)

			ws.send(frame)

			var bytes_sent = float(frame.size())
			stats["total_bytes"] += bytes_sent
			stats["total_blocks"] += 1
			stats["side_bytes"][side] += bytes_sent

			if int(stats["total_blocks"]) % 50 == 0:
				print("[WS] Sent %d blocks (%.2f KB so far)" % [
					int(stats["total_blocks"]), stats["total_bytes"] / 1024.0
				])

		# --- transmit all requested blocks ---
		for side in ["inputs", "outputs"]:
			if not need.has(side):
				continue
			var cols_arr := (inputs if side == "inputs" else outputs)
			for col_key in need[side].keys():
				var col_i := int(col_key)
				var missing: Array = need[side][col_key]
				if missing.is_empty():
					continue
				var col_data: Dictionary = cols_arr[col_i]
				var blocks: Array = col_data.get("blocks", [])
				for blk_i in missing:
					if blk_i >= 0 and blk_i < blocks.size():
						var blk_data: PackedByteArray = blocks[blk_i]
						_send_block.call(side, col_i, blk_i, blk_data)

		# --- end transmission ---
		ws.send("__end__".to_utf8_buffer())

		print("[WS] Sent all missing dataset blocks to server.")
		print("[WS] Blocks sent: %d  |  Total bytes: %.2f KB (%.2f MB)" %
			[int(stats["total_blocks"]), stats["total_bytes"] / 1024.0, stats["total_bytes"] / 1024.0 / 1024.0])
		print("[WS] Inputs: %.2f KB   Outputs: %.2f KB" %
			[stats["side_bytes"]["inputs"] / 1024.0, stats["side_bytes"]["outputs"] / 1024.0])

	# --- connect listener ---
	ws.packet.connect(_on_packet)








var training_sockets = {}
func start_train(train_input: Graph, additional_call: Callable = glob.def, run_but: BlockComponent = null) -> bool:
	if not check_valid(train_input, true): return false
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
	if not train_input_origin.dataset_meta: return false
	if not train_input_origin.dataset_meta.get("name", ""): return false
	if not check_valid(execute_input_origin, false): return false
	request_save()
	var tdata = train_input_origin.get_training_data()
	var compressed = ({
		"session": "neriqward",
		"graph": graphs.get_syntax_tree(execute_input_origin),
		"train_graph": graphs.get_syntax_tree(train_input_origin),
		"scene_id": str(glob.get_project_id()),
		"context": str(execute_input_origin.context_id),
	}.merged(tdata))
				#var tdata = graph.get_training_data()
			#var a = await sockets.connect_to("ws/ds_load", func(a): null, cookies.get_auth_header())

	#print(compressed)
	var a = sockets.connect_to("ws/train", train_state_received.bind(additional_call), cookies.get_auth_header())
	
	ws_ds_frames(train_input_origin, tdata, a)
	training_sockets[train_input] = a
	a.connected.connect(func():
		#if tdata.get("local"):
		#	var data = DsObjRLE.compress_and_send(train_input_origin.dataset_meta["name"]) if tdata.get("local") else {}
		#	a.send()
		a.send(glob.compress_dict_zstd(compressed)))
		#ws_ds_frames(train_input_origin, compressed, a))
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
			#print(_dict)
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

func check_valid(input: Graph, train: bool = false):
	if train:
		input = graphs._reach_input(input, "TrainBegin")
	var simple = graphs.simple_reach(input, true)
	var has_necc: bool = false; var in_nodes = {}
	if train: in_nodes = {"RunModel": 1, "OutputMap": 1, "ModelName": 1, "DatasetName": 1}
	else: in_nodes = {"ClassifierNode": 1}
	#print(in_nodes)
	#print(input.server_typename)
	for i in simple:
		if graphs.in_nodes(i, in_nodes): has_necc = true
		if not i.is_valid():
			return false
	return has_necc

func validate_infer_channel(input: Graph):
	#if input in inference_sockets and is_instance_valid(inference_sockets[input]):
	#	return false# already open
	if not check_valid(input): 
	#	print("fals")
		return false
	if not glob._logged_in:
		return false
	return true

func open_infer_channel(input: Graph, on_close: Callable = glob.def, run_but: BlockComponent = null):
	if input in inference_sockets and is_instance_valid(inference_sockets[input]):
		return false# already open
	if not check_valid(input): 
	#	print("fals")
		return false
	if not await glob.splash_login(run_but):
		return false
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
			if inference_sockets[input] == sock:
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
	#print(data)
	if "full_graph" in data:
		if not check_valid(input):
			
			return false
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
	#if glob.space_just_pressed:
	#	pass
	#	upl_dataset(null)

func upl_dataset(from: Graph):
	for graph in graphs._graphs.values():
		if graph.server_typename == "TrainBegin":
			
			var tdata = graph.get_training_data()
			var a = await sockets.connect_to("ws/ds_load", func(a): null, cookies.get_auth_header())

			ws_ds_frames(graph, tdata, a)

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

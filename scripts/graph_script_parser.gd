extends Node

var tags = ["change_nodes", "connect_ports", "delete_nodes", "disconnect_ports"]




func tag_strip(text: String) -> Array:
	#return [text, 0]
	var out = ""
	var i = 0
	var stack: Array[String] = []
	var did_remove := false

	while i < text.length():
		var next_open = -1
		var next_close = -1
		var found_tag = ""
		var closing_tag = false

		for tag in tags:
			var pos_open = text.find("<%s>" % tag, i)
			var pos_close = text.find("</%s>" % tag, i)
			if pos_open != -1 and (next_open == -1 or pos_open < next_open):
				next_open = pos_open
				found_tag = tag
				closing_tag = false
			if pos_close != -1 and (next_close == -1 or pos_close < next_close):
				next_close = pos_close
				if next_open == -1 or next_close < next_open:
					found_tag = tag
					closing_tag = true

		if next_open == -1 and next_close == -1:
			out += text.substr(i)
			break

		var min_pos = INF
		if next_open != -1:
			min_pos = min(min_pos, next_open)
		if next_close != -1:
			min_pos = min(min_pos, next_close)

		out += text.substr(i, min_pos - i)
		i = min_pos

		if closing_tag:
			if stack.size() > 0 and stack.back() == found_tag:
				stack.pop_back()
			i += ("</%s>" % found_tag).length()
			did_remove = true
		else:
			stack.append(found_tag)
			i += ("<%s>" % found_tag).length()
			var close_pos = text.find("</%s>" % found_tag, i)
			if close_pos == -1:
				did_remove = true
				break
			i = close_pos + ("</%s>" % found_tag).length()
			did_remove = true

	return [out, did_remove]

func _match_tag_token(buf: String, pos: int) -> Variant:
	if pos >= buf.length() or buf[pos] != '<':
		return null

	for tag in tags:
		var open_tok = "<%s>" % tag
		var close_tok = "</%s>" % tag
		if buf.substr(pos, open_tok.length()) == open_tok:
			return {"kind": "open", "tag": tag, "len": open_tok.length()}
		if buf.substr(pos, close_tok.length()) == close_tok:
			return {"kind": "close", "tag": tag, "len": close_tok.length()}

	var tail = buf.substr(pos)
	for tag in tags:
		var open_tok = "<%s>" % tag
		var close_tok = "</%s>" % tag
		if open_tok.begins_with(tail) or close_tok.begins_with(tail):
			return {"kind": "partial"}
	return null

func parse_stream_tags(sock: SocketConnection, chunk: String) -> String:
	var state = sock.cache.get_or_add("parser_state", {"buf": "", "stack": [], "acc": []})
	var actions = sock.cache.get_or_add("actions", {})  # { tag: [body1, body2, ...] }

	state.buf += chunk
	var result: String = ""
	var i: int = 0

	while i < state.buf.length():
		var token = null
		if state.buf[i] == '<':
			token = _match_tag_token(state.buf, i)
			if token == null:
				if state.stack.size() == 0:
					result += state.buf[i]
				else:
					state.acc[state.acc.size() - 1] += state.buf[i]
				i += 1
				continue

			if token.has("kind") and token.kind == "partial":
				break

			if token.kind == "open":
				state.stack.append(token.tag)
				state.acc.append("")
				i += token.len
				continue

			if token.kind == "close":
				var top_ok = state.stack.size() > 0 and state.stack[state.stack.size() - 1] == token.tag
				if top_ok:
					var body: String = state.acc.pop_back()
					state.stack.pop_back()
					if not actions.has(token.tag):
						actions[token.tag] = []
					actions[token.tag].append(body)
					if state.acc.size() > 0:
						state.acc[state.acc.size() - 1] += body
					i += token.len
					continue
				else:
					if state.stack.size() == 0:
						result += state.buf[i]
					else:
						state.acc[state.acc.size() - 1] += state.buf[i]
					i += 1
					continue

		if state.stack.size() == 0:
			result += state.buf[i]
		else:
			state.acc[state.acc.size() - 1] += state.buf[i]
		i += 1

	state.buf = state.buf.substr(i)
	for j in tags:
		if not j in actions:
			actions[j] = []
	return result

func clean_message(s: String):
	return tag_strip(s)[0].strip_edges()

func preprocess(actions: Dictionary):
	var res = {}
	for tag in tags:
		res[tag] = []
		if not actions.has(tag):
			res[tag] = []
		else:
			for el in len(actions[tag]):
				if actions[tag][el] is String:
					res[tag].append(JSON.parse_string(actions[tag][el]))
	return res






func model_changes_apply(actions: Dictionary):
	cookies.open_or_create("test.bin").store_var(actions)
	actions = preprocess(actions)
	#print(actions); return
	var creating: Dictionary[String, Graph] = {}
	if actions["change_nodes"]:
		for i in ui.splashed:
			i.go_away()
	await glob.wait(0.05)

	for pack in actions["change_nodes"]:
		for node in pack:
			var typename = glob.llm_name_mapping.get(node.node)
			if not typename:
				continue
			var g = graphs.get_graph(typename, Graph.Flags.NEW, 0, node.tag)
			creating[node.tag] = g
			g.hold_for_frame()

	await get_tree().process_frame

	for pack in actions["connect_ports"]:
		for connection in pack:
			if connection.from.tag in creating and connection.to.tag in creating:
				var from_tag = connection.from.tag
				var to_tag = connection.to.tag
				if not (creating.has(from_tag) and creating.has(to_tag)):
					continue

				var from_graph = creating[from_tag]
				var to_graph = creating[to_tag]
				var out_ports = from_graph.output_keys
				var in_ports = to_graph.input_keys

				if len(out_ports) == 1:
					connection.from.port = out_ports.keys()[0]
				if len(in_ports) == 1:
					connection.to.port = in_ports.keys()[0]

				var from_port = int(connection.from.port)
				var to_port = int(connection.to.port)

				var valid_from = out_ports.has(from_port)
				var valid_to = in_ports.has(to_port)

				if not valid_from and valid_to:
					print("[Axon] Swapped reversed connection")
					var tmp = connection.from
					connection.from = connection.to
					connection.to = tmp

					from_graph = creating[connection.from.tag]
					to_graph = creating[connection.to.tag]
					out_ports = from_graph.output_keys
					in_ports = to_graph.input_keys
					from_port = int(connection.from.port)
					to_port = int(connection.to.port)
					valid_from = out_ports.has(from_port)
					valid_to = in_ports.has(to_port)

				if not (valid_from and valid_to):
					printerr("[Axon] Invalid connection skipped:", connection)
					continue

				out_ports[from_port].connect_to(in_ports[to_port])
	_auto_layout(creating)



func _auto_layout(creating: Dictionary[String, Graph], padding: float = 180.0):
	var visited := {}
	if not creating: return

	var origins: Array = []
	for tag in creating.keys():
		var g: Graph = creating[tag]
		if g.server_typename == "InputNode" or g.server_typename == "TrainBegin":
			origins.append(g)
		g.hold_for_frame()
	if origins.is_empty():
		origins.append(creating.values()[0])
	for i in origins:
		if graphs.is_node(i, "TrainBegin"):
			i.position.y -= 310
	
	var leftover = creating
	for origin in origins:
		#origin.position = Vector2.ZERO
		graphs.reach(origin, func(from_conn: Connection, to_conn: Connection, branch_cache: Dictionary):
			var from_graph: Graph = from_conn.parent_graph
			var to_graph: Graph = to_conn.parent_graph
			if to_graph in visited:
				return
			visited[to_graph] = true
			var base_pos: Vector2 = Vector2()
			var dir: Vector2 = from_conn.dir_vector
			var glob_rect: Rect2 = from_graph.rect.get_global_rect()
			glob_rect.size = from_graph._layout_size()
			if dir.x >= 0:
				base_pos.x = glob_rect.end.x + 50
			else:
				base_pos.x = glob_rect.position.x - 50
			if dir.y == 0:
				base_pos.y = glob_rect.position.y
			elif dir.y > 0:
				base_pos.y = glob_rect.end.y + 50
			else:
				base_pos.y = glob_rect.position.y - 50
			
		#	to_graph.rect.position = base_pos + dir * mult
			to_graph.global_position = base_pos - to_graph.rect.position
			leftover.erase(to_graph.llm_tag)
		)
	for key in leftover:
		var node = leftover[key]
		# special rules for tag nodes
		if graphs.is_node(node, "LayerConfig"):
			var descendants = node.get_first_descendants()
			if descendants:
				var middle_x = float(0.0)
				for i in descendants:
					middle_x += i.rect.global_position.x + i.rect.size.x / 2
				middle_x /= len(descendants)
				var min_y = INF
				for i in descendants:
					min_y = min(min_y, i.rect.global_position.y)
				if min_y != INF:
					node.position = Vector2(middle_x, min_y - 100)

		if graphs.is_node(node, "ModelName"):
			var descendants = node.get_first_descendants()
			if descendants:
				var middle_x = INF
				for i in descendants:
					middle_x = min(middle_x, i.rect.global_position.x)
				var min_y = INF
				for i in descendants:
					min_y = min(min_y, i.rect.global_position.y)
				node.position = Vector2(middle_x - 80, min_y - 80)
	for i in origins:
		if graphs.is_node(i, "TrainBegin"):
			i.position.y += 90

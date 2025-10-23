extends Node

var tags = ["change_nodes", "connect_ports", "delete_nodes", "disconnect_ports", "thinking"]

# ---- persistent tag index & spawn cursor to avoid overlap across calls
var _tag_index: Dictionary = {}            # String (llm_tag) -> Graph
var _spawn_cursor = Vector2(120.0, 120.0) # rolling anchor for next subgraph
var _spawn_padding = Vector2(280.0, 220.0)
const _DETACHED_JITTER = 16.0


func tag_strip(text: String) -> Array:
	var out = ""
	var i = 0
	var stack: Array[String] = []
	var did_remove = false

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
				var current_is_same = state.stack.size() > 0 and state.stack.back() == token.tag
				if current_is_same:
					if state.stack.size() == 0:
						result += "<%s>" % token.tag
					else:
						state.acc[state.acc.size() - 1] += "<%s>" % token.tag
					i += token.len
					continue

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
						state.acc[state.acc.size() - 1] += "<%s>%s</%s>" % [token.tag, body, token.tag]

					i += token.len
					continue
				else:
					if state.stack.size() == 0:
						result += "</%s>" % token.tag
					else:
						state.acc[state.acc.size() - 1] += "</%s>" % token.tag
					i += token.len
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


func _grid_snap(p: Vector2, step: float = 8.0) -> Vector2:
	return Vector2(round(p.x / step) * step, round(p.y / step) * step)




func _bbox_of(nodes: Dictionary[String, Graph]) -> Rect2:
	var any = true
	var r = Rect2()
	for g in nodes.values():
		var gr = g.rect.get_global_rect()
		gr.size = g._layout_size()
		if any:
			r = gr
			any = false
		else:
			r = r.merge(gr)
	return r


func _choose_origins(nodes: Dictionary[String, Graph]) -> Array:
	var origins: Array = []
	for tag in nodes.keys():
		var g: Graph = nodes[tag]
		if g.server_typename == "InputNode" or g.server_typename == "TrainBegin":
			origins.append(g)
	if origins.is_empty() and nodes.size() > 0:
		origins.append(nodes.values()[0])
	return origins


func _jitter(i: int) -> Vector2:
	return Vector2((i % 3) * _DETACHED_JITTER, int(i / 3) * _DETACHED_JITTER)


func model_changes_apply(actions: Dictionary):
	cookies.open_or_create("test.bin").store_var(actions)
	actions = preprocess(actions)
	actions["connect_ports"][-1].remove_at(1)
	var creating: Dictionary[String, Graph] = {}

	# --- create or reuse nodes
	if actions["change_nodes"]:
		for i in ui.splashed:
			i.go_away()
		await glob.wait(0.05)

		for pack in actions["change_nodes"]:
			for node in pack:
				var typename = glob.llm_name_mapping.get(node.type)
				if not typename:
					continue

				var existing: Graph = _tag_index.get(node.tag, null)
				if existing:
					creating[node.tag] = existing
					existing.set_meta("llm_pack", node)
					existing.hold_for_frame()
					continue

				var g = graphs.get_graph(typename, Graph.Flags.NEW, 0, node.tag)
				creating[node.tag] = g
				_tag_index[node.tag] = g
				g.set_meta("llm_pack", node)
				g.set_meta("llm_tag", node.tag)
				g.hold_for_frame()

	await get_tree().process_frame

	# --- connect ports (supports old + new)
	if actions["connect_ports"]:
		for pack in actions["connect_ports"]:
			for connection in pack:
				var from_graph: Graph = creating.get(connection.from.tag, _tag_index.get(connection.from.tag, null))
				var to_graph: Graph   = creating.get(connection.to.tag,   _tag_index.get(connection.to.tag, null))
				if from_graph == null or to_graph == null:
					printerr("[Axon] Skip connect: missing graph(s) for tags ", connection.from.tag, " -> ", connection.to.tag)
					continue

				var out_ports = from_graph.output_keys
				var in_ports  = to_graph.input_keys
				if len(out_ports) == 1:
					connection.from.port = out_ports.keys()[0]
				if len(in_ports) == 1:
					connection.to.port = in_ports.keys()[0]

				var from_port = int(connection.from.port)
				var to_port   = int(connection.to.port)
				var valid_from = out_ports.has(from_port)
				var valid_to   = in_ports.has(to_port)

				if not valid_from and valid_to:
					print("[Axon] Swapped reversed connection")
					var tmp = connection.from
					connection.from = connection.to
					connection.to = tmp
					from_graph = creating.get(connection.from.tag, _tag_index.get(connection.from.tag))
					to_graph   = creating.get(connection.to.tag,   _tag_index.get(connection.to.tag))
					out_ports = from_graph.output_keys
					in_ports  = to_graph.input_keys
					from_port = int(connection.from.port)
					to_port   = int(connection.to.port)
					valid_from = out_ports.has(from_port)
					valid_to   = in_ports.has(to_port)

				if not (valid_from and valid_to):
					printerr("[Axon] Invalid connection skipped:", connection)
					continue

				out_ports[from_port].connect_to(in_ports[to_port])

	await get_tree().process_frame

	# --- map configs
	for tag in creating.keys():
		var real_node: Graph = creating[tag]
		var cfg = real_node.get_meta("llm_pack").config
		var map = func(...args):
			var k = args[0]
			var v = args[1] if args.size() > 1 else k
			if real_node.base_config.size() == 1:
				k = real_node.base_config.keys()[0]
			if k in real_node.base_config:
				return glob.cast_variant(v, typeof(real_node.base_config[k]))
			else:
				return v
		cfg = glob.deep_map(cfg, map)
		real_node.llm_map(cfg)

	_auto_layout(creating)






func _auto_layout(creating: Dictionary[String, Graph], padding: float = 90.0):
	if not creating:
		return

	var H = 50.0  # fixed horizontal gap between node sides
	var V = 50.0   # fixed vertical gap between node sides

	var origins = _choose_origins(creating)
	for g in origins:
		g.hold_for_frame()
		if graphs.is_node(g, "TrainBegin"):
			g.position.y -= 310.0

	var visited: Dictionary = {}
	var placed: Dictionary = {}
	var anchor = _spawn_cursor

	# seed first node
	if origins.size() > 0:
		var seed = origins[0]
		var base = _grid_snap(anchor)
		seed.global_position = base - seed.rect.position
		visited[seed] = true
		placed[seed] = true

	# flow placement from origins
	for origin in origins:
		graphs.reach(origin, func(from_conn: Connection, to_conn: Connection, branch_cache: Dictionary):
			var from_graph: Graph = from_conn.parent_graph
			var to_graph: Graph = to_conn.parent_graph
			if to_graph in visited:
				return
			visited[to_graph] = true

			var from_rect: Rect2 = from_graph.rect.get_global_rect()
			from_rect.size = from_graph._layout_size()
			var to_size: Vector2 = to_graph._layout_size()
			var dir: Vector2 = from_conn.dir_vector
			var pos = Vector2()

			# Compute position relative to from_graph's *edge* plus fixed gap
			if abs(dir.x) >= abs(dir.y):
				# horizontal placement
				if dir.x >= 0.0:
					pos.x = from_rect.end.x + H
				else:
					pos.x = from_rect.position.x - (to_size.x + H)
				pos.y = from_rect.position.y
			else:
				# vertical placement
				pos.x = from_rect.position.x
				if dir.y >= 0.0:
					pos.y = from_rect.end.y + V
				else:
					pos.y = from_rect.position.y - (to_size.y + V)

			to_graph.global_position = _grid_snap(pos) - to_graph.rect.position
			placed[to_graph] = true
		)

	# fallback grid for unconnected nodes
	var leftovers: Array = []
	for tag in creating.keys():
		var g: Graph = creating[tag]
		if not (g in placed):
			leftovers.append(g)

	if leftovers.size() > 0:
		var cols = max(1, int(ceil(sqrt(float(leftovers.size())))))
		var row = 0
		var col = 0
		var grid_origin = _grid_snap(anchor + Vector2(H * 0.5, V * 1.0))
		for i in range(leftovers.size()):
			var g = leftovers[i]
			var cell_pos = grid_origin + Vector2(col * (H + g._layout_size().x * 0.5), row * (V + g._layout_size().y * 0.5)) + _jitter(i)
			g.global_position = _grid_snap(cell_pos) - g.rect.position
			col += 1
			if col >= cols:
				col = 0
				row += 1

	# special placement rules (unchanged)
	for tag in creating.keys():
		var node: Graph = creating[tag]
		if graphs.is_node(node, "LayerConfig"):
			var descendants = node.get_first_descendants()
			if descendants:
				var middle_x: float = 0.0
				for d in descendants:
					middle_x += d.rect.global_position.x + d.rect.size.x / 2.0
				middle_x /= float(len(descendants))
				var min_y = INF
				for d in descendants:
					min_y = min(min_y, d.rect.global_position.y)
				if min_y != INF:
					node.position = Vector2(middle_x, min_y - 100.0)

		if graphs.is_node(node, "ModelName"):
			var descendants = node.get_first_descendants()
			if descendants:
				var left_x = INF
				var min_y = INF
				for d in descendants:
					left_x = min(left_x, d.rect.global_position.x)
					min_y = min(min_y, d.rect.global_position.y)
				node.position = Vector2(left_x - 80.0, min_y - 80.0)

		if graphs.is_node(node, "DatasetName"):
			var descendants = node.get_first_descendants()
			if descendants:
				var left_x = INF
				var min_y = INF
				for d in descendants:
					left_x = min(left_x, d.rect.global_position.x)
					min_y = min(min_y, d.rect.global_position.y)
				node.position = Vector2(left_x - 100.0, min_y + 10.0)

	for g in _choose_origins(creating):
		if graphs.is_node(g, "TrainBegin"):
			g.position.y += 90.0

	# move next-batch spawn anchor right of this batch bbox
	var batch_bbox = _bbox_of(creating)
	_spawn_cursor = Vector2(batch_bbox.end.x + _spawn_padding.x, max(_spawn_cursor.y, batch_bbox.position.y) + _spawn_padding.y)

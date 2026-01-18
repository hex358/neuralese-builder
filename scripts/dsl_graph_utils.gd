class_name DSLGraphUtils
extends RefCounted

func eval_cfg_expressions(cfg: Dictionary, exprs: Dictionary) -> bool:
	for expr_str in exprs.values():
		var expr = Expression.new()
		if expr.parse(str(expr_str), cfg.keys()) != OK:
			return false
		if expr.execute(cfg.values(), null, true) != true:
			return false
	return true

func graph_has_connection(from_id, to_id, out_port: int, in_port: int) -> bool:
	var from = graphs._graphs.get(from_id)
	var to = graphs._graphs.get(to_id)
	if from == null or to == null:
		return false

	if out_port == -1:
		out_port = from.output_keys.keys()[0]

	if not out_port in from.output_keys:
		return false

	if in_port != -1 and not in_port in to.input_keys:
		return false
	
	if not from.output_keys[out_port].outputs:
		return false

	var first_out = from.output_keys[out_port].outputs.values()[0]
	if in_port == -1:
		return first_out.tied_to.parent_graph.graph_id == to_id

	return first_out.tied_to.hint == in_port and first_out.tied_to.parent_graph.graph_id == to_id

func graph_has_any_connection(from_id, to_id) -> bool:
	var from = graphs._graphs.get(from_id)
	if from == null:
		return false

	for out_port in from.output_keys.keys():
		for c in from.output_keys[out_port].outputs.values():
			if c.tied_to.parent_graph.graph_id == to_id:
				return true

	return false

func collect_reachable(root) -> Dictionary:
	var nodes: Dictionary = {}
	var edges: Array = []

	nodes[root.graph_id] = root

	graphs.reach(root, func(from_conn, to_conn, _cache):
		var a = from_conn.parent_graph
		var b = to_conn.parent_graph
		nodes[a.graph_id] = a
		nodes[b.graph_id] = b
		edges.append([a.graph_id, b.graph_id])
	)

	return { "nodes": nodes, "edges": edges }

func match_graph(scene: Dictionary, tpl: Dictionary) -> bool:
	var tpl_nodes: Dictionary = tpl["nodes"]
	var tpl_edges: Array = tpl["edges"]
	var candidates: Dictionary = {}

	for name in tpl_nodes.keys():
		var spec: Dictionary = tpl_nodes[name]
		candidates[name] = []

		for g in scene["nodes"].values():
			if g.get_meta("created_with") != spec["type"]:
				continue
			if spec.has("config"):
				if not eval_cfg_expressions(g.cfg, spec["config"]):
					continue
			candidates[name].append(g.graph_id)

		if candidates[name].is_empty():
			return false

	return assign_nodes(tpl_nodes.keys(), candidates, {}, tpl_edges)

func assign_nodes(names: Array, cand: Dictionary, assigned: Dictionary, edges: Array) -> bool:
	if assigned.size() == names.size():
		return check_edges(assigned, edges)

	var name = names[assigned.size()]
	for id in cand[name]:
		if id in assigned.values():
			continue
		assigned[name] = id
		if assign_nodes(names, cand, assigned, edges):
			return true
		assigned.erase(name)

	return false

func check_edges(map: Dictionary, edges: Array) -> bool:
	for e in edges:
		if not graph_has_any_connection(map[e[0]], map[e[1]]):
			return false
	return true

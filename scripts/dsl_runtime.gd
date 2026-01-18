class_name DSLRuntime
extends RefCounted

var reg: DSLRegistry
var graph: DSLGraphUtils

func run_action_explain_button(act: Dictionary, lesson) -> bool:
	await ui.quest.finish_exp()
	return true

func run_action_prohibit_deletion(act: Dictionary, lesson) -> bool:
	await glob.tree.process_frame
	print(act["nodes"])
	print(lesson.node_bindings)
	var ids = resolve_node_ids({"bind": act["nodes"]}, lesson.node_bindings)
	print(ids)
	for i in ids:
		graphs._graphs[i].prohibit_deletion()
	return true

func run_action_allow_deletion(act: Dictionary, lesson) -> bool:
	var ids = resolve_node_ids({"bind": act["nodes"]}, lesson.node_bindings)
	for i in ids:
		graphs._graphs[i].allow_deletion()
	return true
	
func run_action_explain_next(act: Dictionary, lesson) -> bool:
	await ui.quest.finish_and_hide()
	return true

func run_action_ask(act: Dictionary, lesson) -> bool:
	if act.get("_asked", false):
		return true

	act["_asked"] = true

	var head = act["head"]
	var options = act["options"]
	var correct = act.get("correct", [])
	var show = act.get("show", false)
	for i in len(correct):
		correct[i] -= 1

	var ans = str((await ui.quest.ask(head, options, correct, show))[0][0]+1)
	
	var on_answer: Dictionary = act.get("on_answer", {})
	var target: Dictionary = on_answer.get(ans, {})

	if target.is_empty() and act.has("default"):
		target = act.get("default", {})

	if not target.is_empty():
		var op = str(target.get("op", ""))
		if op == "goto":
			var br = str(target.get("target", "")).strip_edges()
			if br != "":
				lesson.call_branch(br)
				return false

	return true



func run_action_select(act: Dictionary, lesson) -> bool:
	var exprs: Dictionary = act.get("exprs", {})

	var eligible: Dictionary = {}

	for node in graphs._graphs.values():
		if exprs.is_empty():
			eligible[node.graph_id] = true
			continue
		
		if graph.eval_cfg_expressions(node.cfg, exprs):
			eligible[node.graph_id] = true

	var chosen: Dictionary = await ui.choose()
	var filtered: Array = []
	for g in chosen.keys():
		var id = g.graph_id
		if eligible.has(id):
			filtered.append(id)
	#lesson.last_highlighted_nodes = filtered
	return true



func run_action_explain(act: Dictionary, lesson) -> bool:
	var text_val = act.get("text", "")
	var wait_mode = str(act.get("wait", "next")).strip_edges()
	var t = float(act.get("time", 1.0))

	# normalize text -> Array[String]
	var segs: Array = []
	if typeof(text_val) == TYPE_ARRAY:
		for s in text_val:
			segs.append(str(s))
	else:
		segs.append(str(text_val))

	# optional signal for other listeners
	lesson.explain_requested.emit(segs, wait_mode)

	# fire-and-forget
	if wait_mode == "none":
		ui.quest.say(segs, false) # no await by design
		return true

	if wait_mode == "time":
		await ui.quest.say(segs, false)
		await glob.wait(t)
		return true

	# press-based
	if wait_mode == "next":
		await ui.quest.say(segs, true)
		return true

	push_error("Unknown explain.wait: %s" % wait_mode)
	return false

func run_action_create(act: Dictionary, lesson) -> bool:
	var bocs: Array = act.get("bind_on_create", [])
	if bocs.is_empty():
		return false

	var all_resolved := true

	for boc in bocs:
		if not boc.has("_registered"):
			boc["_registered"] = true
			lesson.pending_node_binds.append(boc)

		if not lesson.node_bindings.has(str(boc["bind"])):
			all_resolved = false

	return all_resolved


func run_action_require(act: Dictionary, lesson) -> bool:
	var reqs: Array = act.get("requires", [])

	for req in reqs:
		if not req.has("_resolved"):
			var ok = await lesson._compile_requirement(req).call()
			if not ok:
				return false
			req["_resolved"] = true
	
	return true





# ============================================================
# Runtime requirement checks (canonical req dict -> bool)
# ============================================================

func check_node(req: Dictionary, node_bindings: Dictionary) -> bool:
	var ids = resolve_node_ids(req["node"], node_bindings)
	return ids.size() > 0

func check_connection(req: Dictionary, node_bindings: Dictionary) -> bool:
	var from_ids = resolve_node_ids(req["from"], node_bindings)
	var to_ids = resolve_node_ids(req["to"], node_bindings)

	var out_port: int = int(req.get("out_port", -1))
	var in_port: int = int(req.get("in_port", -1))
	#print(req)
	for a in from_ids:
		for b in to_ids:
			if graph.graph_has_connection(a, b, out_port, in_port):
				return true

	return false

func check_config(req: Dictionary, node_bindings: Dictionary) -> bool:
	var ids = resolve_node_ids(req["node"], node_bindings)
	var exprs: Dictionary = req["exprs"]

	for id in ids:
		var node = graphs._graphs.get(id)
		if node == null:
			continue
		if graph.eval_cfg_expressions(node.cfg, exprs):
			return true

	return false

func check_topology_graph(req: Dictionary, node_bindings: Dictionary) -> bool:
	var roots = resolve_node_ids(req["root"], node_bindings)
	if roots.is_empty():
		return false

	for root_id in roots:
		var root = graphs._graphs.get(root_id)
		if root == null:
			continue

		var scene = graph.collect_reachable(root)
		if graph.match_graph(scene, req):
			return true

	return false

func check_wait(req: Dictionary, _node_bindings: Dictionary) -> bool:
	var t = float(req.get("time", 0))
	if t <= 0:
		return true
	await glob.wait(t)
	return true

func check_ask(req: Dictionary, _node_bindings: Dictionary) -> bool:
	if req.get("_asked", false):
		return false

	req["_asked"] = true

	await ui.quest.ask(
		req["head"],
		req["options"],
		req["correct"],
		req.get("show", false)
	)
	return true

func check_lock(req: Dictionary, _node_bindings: Dictionary) -> bool:
	if req.get("_locked", false):
		return false

	req["_locked"] = true
	await learner.push_classroom_event({"awaiting": true})
	await learner.wait_unblock()
	return true


# ============================================================
# Runtime helpers
# ============================================================

func resolve_node_ids(spec: Dictionary, node_bindings: Dictionary) -> Array:
	#print(node_bindings)
	#print(spec)
	if spec.has("bind"):
		if spec["bind"] is Array:
			var res = []
			for b in spec["bind"]:
				b = str(b)
				if node_bindings.has(b): res.append(node_bindings[b])
			return res
		var b = str(spec["bind"])
		if node_bindings.has(b):
			return [node_bindings[b]]
		return []

	var ids: Array = []
	for node in graphs._graphs.values():
		var ok = true
		for k in spec.keys():
			var kk = str(k)
			match kk:
				"type":
					if node.get_meta("created_with") != spec[kk]:
						ok = false
						break
				_:
					if not node.has_meta(kk) or node.get_meta(kk) != spec[kk]:
						ok = false
						break
		if ok:
			ids.append(node.graph_id)

	return ids

func run_action_highlight(act: Dictionary, lesson) -> bool:
	await glob.tree.process_frame
	await glob.tree.process_frame
	var targets: Array = act.get("targets", [])
	if targets.is_empty():
		return true

	var uniq: Dictionary = {} # id -> true

	for sel in targets:
		var ids: Array = _resolve_highlight_selector(sel, lesson.node_bindings)
		for id in ids:
			uniq[id] = true

	var out: Array = uniq.keys()
	ui.emphasize_nodes(out)
	return true

func run_action_confetti(act: Dictionary, lesson) -> bool:
	await glob.tree.process_frame
	await glob.tree.process_frame
	
	if act["whole"]:
		ui.conf_screen()
	else:
		var targets: Array = act.get("targets", [])
		if targets.is_empty():
			return true

		var uniq: Dictionary = {}

		for sel in targets:
			var ids: Array = _resolve_highlight_selector(sel, lesson.node_bindings)
			for id in ids:
				uniq[id] = true
		for i in uniq:
			ui.confetti(graphs._graphs[i].rect.get_global_rect().get_center())
		if act.wait:
			await glob.wait(1.0)
	return true


func _resolve_highlight_selector(sel: Dictionary, node_bindings: Dictionary) -> Array:
	var kind = str(sel.get("kind", "")).strip_edges()

	match kind:
		"bind":
			var b = str(sel.get("bind", "")).strip_edges()
			if b == "":
				return []
			return resolve_node_ids({ "bind": b }, node_bindings)

		"type":
			return _resolve_by_type_and_exprs(sel)

		"topology":
			var topo = sel.get("topology", null)
			if typeof(topo) != TYPE_DICTIONARY:
				return []
			return _resolve_by_rough_topology(topo, node_bindings)

		_:
			return []


func _resolve_by_type_and_exprs(sel: Dictionary) -> Array:
	var node_type = str(sel.get("node_type", "")).strip_edges()
	var exprs: Dictionary = sel.get("exprs", {})

	var out: Array = []
	for node in graphs._graphs.values():
		if node.get_meta("created_with") != node_type:
			continue
		if not exprs.is_empty():
			if not graph.eval_cfg_expressions(node.cfg, exprs):
				continue
		out.append(node.graph_id)

	return out

func _resolve_by_rough_topology(topo_req: Dictionary, node_bindings: Dictionary) -> Array:
	var roots = resolve_node_ids(topo_req.get("root", {}), node_bindings)
	if roots.is_empty():
		return []

	var out: Dictionary = {}

	for root_id in roots:
		var root = graphs._graphs.get(root_id)
		if root == null:
			continue

		var scene = graph.collect_reachable(root)
		var ids: Array = _collect_topology_nodes(scene, topo_req)

		for id in ids:
			out[id] = true

	return out.keys()


func _collect_topology_nodes(scene: Dictionary, topo_req: Dictionary) -> Array:
	# scene = { "nodes": Dictionary, "edges": Array }

	if not scene.has("nodes") or not scene.has("edges"):
		return []

	# 1) Проверяем, что topology вообще совпадает
	if not graph.match_graph(scene, topo_req):
		return []

	var tpl_nodes: Dictionary = topo_req.get("nodes", {})

	# 2) Если шаблон не уточняет nodes — подсвечиваем всё достижимое
	if tpl_nodes.is_empty():
		return scene["nodes"].keys()

	# 3) Собираем candidates ТОЧНО как match_graph
	var candidates: Dictionary = {} # alias -> [graph_id]

	for alias in tpl_nodes.keys():
		var spec: Dictionary = tpl_nodes[alias]
		var t = spec.get("type", null)
		var exprs: Dictionary = spec.get("config", {})

		var arr: Array = []
		for node in scene["nodes"].values():
			if node.get_meta("created_with") != t:
				continue
			if not exprs.is_empty() and not graph.eval_cfg_expressions(node.cfg, exprs):
				continue
			arr.append(node.graph_id)

		if arr.is_empty():
			return []

		candidates[alias] = arr

	# 4) Collect all ids used in any valid assignment
	var used: Dictionary = {}
	_collect_assignments(
		tpl_nodes.keys(),
		candidates,
		{},
		topo_req.get("edges", []),
		used
	)

	return used.keys()


func _collect_assignments(
	names: Array,
	cand: Dictionary,
	assigned: Dictionary,
	edges: Array,
	out_used: Dictionary
) -> void:
	if assigned.size() == names.size():
		# Проверяем edges точно так же
		for e in edges:
			if not graph.graph_has_any_connection(assigned[e[0]], assigned[e[1]]):
				return
		# Валидное сопоставление — сохраняем все graph_id
		for id in assigned.values():
			out_used[id] = true
		return

	var name = names[assigned.size()]
	for id in cand[name]:
		if id in assigned.values():
			continue
		assigned[name] = id
		_collect_assignments(names, cand, assigned, edges, out_used)
		assigned.erase(name)

class_name DSLRegistry
extends Node

var require = {
	"node": {"type": "node", "compile": _compile_req_node, "runtime": _check_node},
	"connection": {"type": "connection", "compile": _compile_req_connection, "runtime": _check_connection},
	"config": {"type": "config", "compile": _compile_req_config, "runtime": _check_config},
	"topology": {"type": "topology_graph", "compile": _compile_req_topology, "runtime": _check_topology_graph},
	"wait": {"type": "wait", "compile": _compile_req_wait, "runtime": _check_wait},
	"ask": {"type": "ask", "compile": _compile_req_ask, "runtime": _check_ask},
	"teacher_lock": {"type": "teacher_lock", "compile": _compile_req_lock, "runtime": _check_lock},
}

var step_directives = {
	"create": { "compile": _step_apply_create },
	"require": { "compile": _step_apply_require },
	"explain": { "compile": _step_apply_explain }, # legacy
	"actions": { "compile": _step_apply_actions },  # NEW
}

var action = {
	"explain": {
		"compile": _compile_action_explain,
		"runtime": _run_action_explain,
	},
	"require": {
		"compile": _compile_action_require,
		"runtime": _run_action_require,
	},
	"create": {
		"compile": _compile_action_create,
		"runtime": _run_action_create,
	},
}


func build_runtime_map_by_type() -> Dictionary:
	var out: Dictionary = {}
	for yaml_key in require.keys():
		var spec = require[yaml_key]
		out[str(spec["type"])] = spec["runtime"]
	return out

func _step_apply_create(out_step: Dictionary, create_val) -> bool:
	var boc = _compile_create(create_val)
	if boc.is_empty():
		return false
	out_step["bind_on_create"] = boc
	return true

# -------------------------
# Legacy explain (unchanged)
# -------------------------
func _step_apply_explain(out_step: Dictionary, explain_val) -> bool:
	if typeof(explain_val) == TYPE_STRING:
		out_step["explain"] = {
			"before": explain_val,
			"after": "",
			"_phase": "before",
			"_acknowledged": false
		}
		return true
	elif typeof(explain_val) == TYPE_DICTIONARY:
		out_step["explain"] = {
			"before": str(explain_val.get("before", "")),
			"after": str(explain_val.get("after", "")),
			"_phase": "before",
			"_acknowledged": false
		}
		return true

	push_error("YAML: invalid 'explain' value")
	return false

func _run_action_explain(act: Dictionary, lesson: LessonCode) -> bool:
	var text = act["text"]
	var wait_mode = act.get("wait", "none")
	var t = float(act.get("time", 1.0))

	lesson.explain_requested.emit(text, wait_mode)

	if wait_mode == "none":
		return true
	if wait_mode == "time":
		await glob.wait(t)
		return true

	# wait == "next"
	await lesson.explain_next_ack
	return true

func _compile_action_create(v) -> Dictionary:
	var boc = _compile_create(v)
	if boc.is_empty():
		return {}
	return {
		"type": "create",
		"bind_on_create": boc
	}

func _run_action_create(act: Dictionary, lesson: LessonCode) -> bool:
	var boc = act["bind_on_create"]

	if not boc.has("_registered"):
		boc["_registered"] = true
		lesson.pending_node_binds.append(boc)

	return lesson.node_bindings.has(boc["bind"])

func _run_action_require(act: Dictionary, lesson: LessonCode) -> bool:
	var reqs: Array = act["requires"]

	for req in reqs:
		if not req.has("_resolved"):
			var ok = await lesson._compile_requirement(req).call()
			if not ok:
				return false
			req["_resolved"] = true

	return true




func _show_explain_before(exp: Dictionary) -> void:
	await glob.wait(1.0)

func _show_explain_after(exp: Dictionary) -> void:
	await glob.wait(10.0)

func _step_apply_actions(out_step: Dictionary, actions_val) -> bool:
	if typeof(actions_val) != TYPE_ARRAY:
		push_error("YAML: 'actions' must be a list")
		return false

	var out_actions: Array = []

	for item in actions_val:
		var act: Dictionary

		if typeof(item) == TYPE_STRING:
			act = action["explain"]["compile"].call(item)
		elif typeof(item) == TYPE_DICTIONARY and item.size() == 1:
			var k = str(item.keys()[0])
			var v = item.values()[0]

			if not action.has(k):
				push_error("YAML: unknown action '%s'" % k)
				return false

			act = action[k]["compile"].call(v)
		else:
			push_error("YAML: invalid action format")
			return false

		if act.is_empty():
			return false

		out_actions.append(act)

	out_step["actions"] = out_actions
	return true




func _compile_action_explain(v) -> Dictionary:
	# explain: "text"
	# explain: { text: "...", wait: "next|time|none", time: 1.0 }
	if typeof(v) == TYPE_STRING:
		return { "type": "explain", "text": str(v), "wait": "next" }

	if typeof(v) == TYPE_DICTIONARY:
		var text = str(v.get("text", "")).strip_edges()
		if text == "":
			push_error("YAML: explain.text is required")
			return {}

		var wait_mode = str(v.get("wait", "next")).strip_edges()
		if wait_mode == "":
			wait_mode = "next"

		var t = float(v.get("time", 1.0))

		# Normalize
		if wait_mode != "next" and wait_mode != "time" and wait_mode != "none":
			push_error("YAML: explain.wait must be 'next', 'time', or 'none'")
			return {}

		return {
			"type": "explain",
			"text": text,
			"wait": wait_mode,
			"time": t
		}

	push_error("YAML: explain must be string or mapping")
	return {}


func _compile_action_require(req_val) -> Dictionary:
	var compiled_reqs = _compile_require_list(req_val)
	if compiled_reqs.is_empty():
		return {}
	return { "type": "require", "requires": compiled_reqs }


# ============================================================
# Refactor: compile require list once, reuse everywhere
# ============================================================

func _compile_require_list(req_val) -> Array:
	var req_map: Dictionary = {}

	if typeof(req_val) == TYPE_STRING:
		req_map[str(req_val)] = {}
	elif typeof(req_val) == TYPE_ARRAY:
		for item in req_val:
			if typeof(item) == TYPE_STRING:
				req_map[str(item)] = {}
			elif typeof(item) == TYPE_DICTIONARY:
				for k in item.keys():
					req_map[str(k)] = item[k]
			else:
				push_error("YAML: invalid item in 'require' list")
				return []
	elif typeof(req_val) == TYPE_DICTIONARY:
		req_map = req_val
	else:
		push_error("YAML: 'require' must be string, list, or mapping")
		return []

	var out: Array = []
	for yaml_key in req_map.keys():
		var key = str(yaml_key)
		var v = req_map[yaml_key]

		if not require.has(key):
			push_error("YAML: unknown require type '%s'" % key)
			return []

		var spec = require[key]
		var fn_name = spec.get("compile", null)
		if fn_name == null:
			push_error("YAML: require '%s' missing compile fn" % key)
			return []

		var compiled = fn_name.call(v)
		if typeof(compiled) != TYPE_DICTIONARY or compiled.is_empty():
			return []

		var expected_type = str(spec.get("type", ""))
		if expected_type != "" and str(compiled.get("type", "")) != expected_type:
			push_error("YAML: '%s' compiled to '%s', expected '%s'" % [
				key, str(compiled.get("type", "")), expected_type
			])
			return []

		out.append(compiled)

	return out


func _step_apply_require(out_step: Dictionary, req_val) -> bool:
	var out = _compile_require_list(req_val)
	if out.is_empty():
		return false
	out_step["requires"] = out
	return true





# ============================================================
# Requirement compilers (YAML -> canonical req dict)
# ============================================================

func _compile_req_wait(v) -> Dictionary:
	# wait:
	#   time: 5
	if typeof(v) != TYPE_DICTIONARY:
		return {}

	if not v.has("time"):
		return {}

	var t = float(v["time"])
	if t <= 0.0:
		return {}

	return {
		"type": "wait",
		"time": t
	}


func _compile_req_ask(v) -> Dictionary:
	# ask:
	#   head: ""
	#   options: []
	#   correct: []
	#   show: optional bool
	if typeof(v) != TYPE_DICTIONARY:
		return {}

	if not (v.get("head") is String) or not (v.get("options") is Array) or not (v.get("correct") is Array):
		return {}
	var dis = v.get("show", false)
	if not (dis is bool): return {}
	
	for i in len(v.correct):
		v.correct[i] = int(v.correct[i])
	return {
		"type": "ask",
		"options": v["options"],
		"correct": v["correct"],
		"show": dis,
		"head": v.head
	}

func _compile_req_lock(v) -> Dictionary:
	# lock
	return {"type": "teacher_lock"}

func _compile_req_node(v) -> Dictionary:
	# node: x   OR node: { bind: x } OR advanced mapping
	if typeof(v) == TYPE_STRING:
		var bind_name = str(v).strip_edges()
		if bind_name == "":
			return {}
		return {
			"type": "node",
			"node": { "bind": bind_name }
		}

	if typeof(v) == TYPE_DICTIONARY:
		# passthrough advanced spec
		return {
			"type": "node",
			"node": v
		}

	return {}


func _compile_req_connection(v) -> Dictionary:
	# connection: { from: x, to: d, out_port?:, in_port?: }
	if typeof(v) != TYPE_DICTIONARY:
		return {}

	if not v.has("from") or not v.has("to"):
		return {}

	var out_req: Dictionary = {
		"type": "connection",
		"from": _normalize_node_ref(v["from"]),
		"to": _normalize_node_ref(v["to"]),
	}

	if v.has("out_port"):
		out_req["out_port"] = int(v["out_port"])
	if v.has("in_port"):
		out_req["in_port"] = int(v["in_port"])

	return out_req


func _compile_req_config(v) -> Dictionary:
	# config:
	#   node: x
	#   exprs: { neuron_count: ">= 8" }
	if typeof(v) != TYPE_DICTIONARY:
		return {}

	if not v.has("node") or not v.has("exprs"):
		return {}

	if typeof(v["exprs"]) != TYPE_DICTIONARY:
		return {}

	return {
		"type": "config",
		"node": _normalize_node_ref(v["node"]),
		"exprs": _compile_config_exprs(v["exprs"])
	}


func _compile_req_topology(v) -> Dictionary:
	# topology:
	#   root: x
	#   nodes: { split: layer, merge: { layer: { neuron_count: ">= 8" } } }
	#   edges: ["a -> b", ["a","b"]]
	if typeof(v) != TYPE_DICTIONARY:
		return {}

	var root_bind = str(v.get("root", "")).strip_edges()
	if root_bind == "":
		return {}

	var nodes_in = v.get("nodes", null)
	if typeof(nodes_in) != TYPE_DICTIONARY:
		return {}

	var edges_in = v.get("edges", null)
	if typeof(edges_in) != TYPE_ARRAY:
		return {}

	var nodes_out: Dictionary = {}
	for name in nodes_in.keys():
		var node_name = str(name).strip_edges()
		if node_name == "":
			return {}
		var compiled = _compile_topology_node_spec(nodes_in[name])
		if compiled.is_empty():
			return {}
		nodes_out[node_name] = compiled

	var edges_out: Array = []
	for e in edges_in:
		var pair = _compile_edge(e)
		if pair.is_empty():
			return {}
		edges_out.append(pair)

	return {
		"type": "topology_graph",
		"root": { "bind": root_bind },
		"nodes": nodes_out,
		"edges": edges_out
	}


# ============================================================
# Runtime requirement checks (canonical req dict -> bool)
# ============================================================

func _check_node(req: Dictionary,node_bindings: Dictionary) -> bool:
	var ids = _resolve_node_ids(req["node"], node_bindings)
	return ids.size() > 0


func _check_connection(req: Dictionary,node_bindings: Dictionary) -> bool:
	var from_ids = _resolve_node_ids(req["from"],  node_bindings)
	var to_ids = _resolve_node_ids(req["to"],node_bindings)

	var out_port: int = req.get("out_port", -1)
	var in_port: int = req.get("in_port", -1)

	for a in from_ids:
		for b in to_ids:
			if _graph_has_connection(a, b, out_port, in_port):
				return true

	return false


func _check_config(req: Dictionary,  node_bindings: Dictionary) -> bool:
	var ids = _resolve_node_ids(req["node"],node_bindings)
	var exprs = req["exprs"]

	for id in ids:
		var node = graphs._graphs.get(id)
		if node == null:
			continue
		if _eval_cfg_expressions(node.cfg, exprs):
			return true

	return false


func _check_topology_graph(req: Dictionary,  node_bindings: Dictionary) -> bool:
	var roots = _resolve_node_ids(req["root"],  node_bindings)
	if roots.is_empty():
		return false
	
	for root_id in roots:
		var root = graphs._graphs.get(root_id)
		if root == null:
			continue

		var scene = _collect_reachable(root)
		#print(scene)
		if _match_graph(scene, req):
			return true

	return false


func _check_wait(req: Dictionary, node_bindings: Dictionary) -> bool:
	var t = float(req.get("time", 0))
	if t <= 0:
		return true

	await glob.wait(t)
	return true

func _check_ask(req: Dictionary, node_bindings: Dictionary) -> bool:
	if req.get("_asked", false):
		return false

	req["_asked"] = true
	for i in len(req.correct):
		req.correct[i] = int(req.correct[i])
	
	await ui.quest.ask(
		req.head,
		req.options,
		req.correct,
		req.show
	)
	return true

func _check_lock(req: Dictionary, node_bindings: Dictionary) -> bool:
	if req.get("_locked", false):
		return false

	req["_locked"] = true
	await learner.push_classroom_event({"awaiting": true})
	await learner.wait_unblock()
	return true


# ============================================================
# Runtime helpers
# ============================================================

func _resolve_node_ids(spec: Dictionary, node_bindings: Dictionary) -> Array:
	if spec.has("bind"):
		var b = str(spec["bind"])
		if node_bindings.has(b):
			return [node_bindings[b]]
		return []

	var ids := []
	for node in graphs._graphs.values():
		var ok := true
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


func _eval_cfg_expressions(cfg: Dictionary, exprs: Dictionary) -> bool:
	for expr_str in exprs.values():
		var expr = Expression.new()
		if expr.parse(str(expr_str), cfg.keys()) != OK:
			return false
		if expr.execute(cfg.values(), null, true) != true:
			return false
	return true


func _graph_has_connection(from_id, to_id, out_port: int, in_port: int) -> bool:
	var from = graphs._graphs.get(from_id)
	var to = graphs._graphs.get(to_id)
	if from == null or to == null:
		return false

	if out_port == -1:
		out_port = from.output_keys.keys()[0]

	if not out_port in from.output_keys:
		return false

	if in_port != -1:
		if not in_port in to.input_keys:
			return false

	if not from.output_keys[out_port].outputs:
		return false

	var first_out = from.output_keys[out_port].outputs.values()[0]
	if in_port == -1:
		if first_out.tied_to.parent_graph.graph_id == to_id:
			return true
	else:
		if first_out.tied_to.hint == in_port and first_out.tied_to.parent_graph.graph_id == to_id:
			return true

	return false


func _collect_reachable(root) -> Dictionary:
	var nodes := {}
	var edges := []

	nodes[root.graph_id] = root

	graphs.reach(root, func(from_conn, to_conn, _cache):
		var a = from_conn.parent_graph
		var b = to_conn.parent_graph
		nodes[a.graph_id] = a
		nodes[b.graph_id] = b
		edges.append([a.graph_id, b.graph_id])
	)

	return { "nodes": nodes, "edges": edges }


func _match_graph(scene: Dictionary, tpl: Dictionary) -> bool:
	var tpl_nodes = tpl["nodes"]
	var tpl_edges = tpl["edges"]
	var candidates := {}

	for name in tpl_nodes.keys():
		var spec = tpl_nodes[name]
		candidates[name] = []

		for g in scene["nodes"].values():
			if g.get_meta("created_with") != spec["type"]:
				continue
			if spec.has("config"):
				if not _eval_cfg_expressions(g.cfg, spec["config"]):
					continue
			candidates[name].append(g.graph_id)

		if candidates[name].is_empty():
			return false

	return _assign_nodes(tpl_nodes.keys(), candidates, {}, tpl_edges)


func _assign_nodes(names: Array, cand: Dictionary, assigned: Dictionary, edges: Array) -> bool:
	if assigned.size() == names.size():
		return _check_edges(assigned, edges)

	var name = names[assigned.size()]
	for id in cand[name]:
		if id in assigned.values():
			continue
		assigned[name] = id
		if _assign_nodes(names, cand, assigned, edges):
			return true
		assigned.erase(name)

	return false


func _check_edges(map: Dictionary, edges: Array) -> bool:
	for e in edges:
		if not _graph_has_any_connection(map[e[0]], map[e[1]]):
			return false
	return true


func _graph_has_any_connection(from_id, to_id) -> bool:
	var from = graphs._graphs.get(from_id)
	if from == null:
		return false

	for out_port in from.output_keys.keys():
		for c in from.output_keys[out_port].outputs.values():
			if c.tied_to.parent_graph.graph_id == to_id:
				return true

	return false


# ============================================================
# YAML compilation helpers
# ============================================================

func _compile_create(create_val) -> Dictionary:
	if typeof(create_val) != TYPE_DICTIONARY:
		push_error("YAML: 'create' must be a mapping like { x: input_1d }")
		return {}

	if create_val.size() != 1:
		push_error("YAML: 'create' supports exactly one bind per step")
		return {}

	var bind_name = str(create_val.keys()[0]).strip_edges()
	var node_type = str(create_val.values()[0]).strip_edges()
	if bind_name == "" or node_type == "":
		return {}

	return {
		"bind": bind_name,
		"type": node_type
	}


func _compile_topology_node_spec(spec) -> Dictionary:
	# - "layer"
	# - { layer: { neuron_count: ">= 8" } }
	# - { type: "layer", config: { neuron_count: "neuron_count >= 8" } } (passthrough)
	if typeof(spec) == TYPE_STRING:
		var t = str(spec).strip_edges()
		if t == "":
			return {}
		return { "type": t }

	if typeof(spec) != TYPE_DICTIONARY:
		return {}

	if spec.has("type"):
		var out: Dictionary = { "type": str(spec["type"]).strip_edges() }
		if out["type"] == "":
			return {}
		if spec.has("config"):
			if typeof(spec["config"]) != TYPE_DICTIONARY:
				return {}
			out["config"] = _compile_config_exprs(spec["config"])
		return out

	if spec.size() != 1:
		return {}

	var t2 = str(spec.keys()[0]).strip_edges()
	if t2 == "":
		return {}

	var cfg_in = spec.values()[0]
	var out2: Dictionary = { "type": t2 }

	if cfg_in == null:
		return out2

	if typeof(cfg_in) != TYPE_DICTIONARY:
		return {}

	out2["config"] = _compile_config_exprs(cfg_in)
	return out2


func _compile_config_exprs(cfg_in: Dictionary) -> Dictionary:
	# YAML: { neuron_count: ">= 8" }
	# JSON expects: { neuron_count: "neuron_count >= 8" }
	var out: Dictionary = {}
	for k in cfg_in.keys():
		var key = str(k).strip_edges()
		var expr = str(cfg_in[k]).strip_edges()
		if key == "" or expr == "":
			continue

		var expr_low = expr.to_lower()
		if expr_low.find(key.to_lower()) == -1:
			expr = "%s %s" % [key, expr]

		out[key] = expr

	return out


func _compile_edge(e) -> Array:
	# Accept:
	# - "a -> b"
	# - ["a","b"]
	if typeof(e) == TYPE_ARRAY:
		if e.size() != 2:
			return []
		return [str(e[0]).strip_edges(), str(e[1]).strip_edges()]

	if typeof(e) == TYPE_STRING:
		var parts = str(e).split("->", false)
		if parts.size() != 2:
			return []
		var a = parts[0].strip_edges()
		var b = parts[1].strip_edges()
		if a == "" or b == "":
			return []
		return [a, b]

	return []


func _normalize_node_ref(v):
	if typeof(v) == TYPE_STRING:
		return { "bind": str(v).strip_edges() }
	return v

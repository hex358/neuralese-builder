class_name DSLRegistry
extends Node


var require = {
	"node": {
		"type": "node",
		"compile": _compile_req_node,
		"runtime": _check_node,
	},
	"connection": {
		"type": "connection",
		"compile": _compile_req_connection,
		"runtime": _check_connection,
	},
	"config": {
		"type": "config",
		"compile": _compile_req_config,
		"runtime": _check_config,
	},
	"topology": {
		"type": "topology_graph",
		"compile": _compile_req_topology,
		"runtime": _check_topology_graph,
	},
	"wait": {
		"type": "wait",
		"compile": _compile_req_wait,
		"runtime": _check_wait,
	},
}

var step_directives = {
	"create": { "compile": _step_apply_create },
	"require": { "compile": _step_apply_require },
}


func build_runtime_map_by_type() -> Dictionary:
	# canonical req.type -> DSLRegistry runtime method name
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


func _step_apply_require(out_step: Dictionary, req_val) -> bool:
	if typeof(req_val) != TYPE_DICTIONARY:
		push_error("YAML: 'require' must be a mapping")
		return false

	var out: Array = []

	for k in req_val.keys():
		var yaml_key = str(k)
		var v = req_val[k]

		if not require.has(yaml_key):
			push_error("YAML: unknown require type '%s'" % yaml_key)
			return false

		var spec = require[yaml_key]
		var fn_name = spec.get("compile", null)
		if fn_name == null:
			push_error("YAML: require missing compile fn for '%s'" % yaml_key)
			return false

		var compiled = fn_name.call(v)
		if typeof(compiled) != TYPE_DICTIONARY:
			return false
		if compiled.is_empty():
			return false

		# sanity: enforce canonical type
		var expected_type = str(spec.get("type", ""))
		if expected_type != "":
			if str(compiled.get("type", "")) != expected_type:
				push_error("YAML: '%s' compiled to '%s', expected '%s'" % [
					yaml_key, str(compiled.get("type", "")), expected_type
				])
				return false

		out.append(compiled)

	if out.size() > 0:
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
			if _graph_has_connection(a, b, out_port, in_port, graphs):
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

		var scene = _collect_reachable(root, graphs)
		if _match_graph(scene, req, graphs):
			return true

	return false


func _check_wait(req: Dictionary, node_bindings: Dictionary) -> bool:
	var t = float(req.get("time", 0))
	if t <= 0:
		return true

	await glob.wait(t)
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


func _graph_has_connection(from_id, to_id, out_port: int, in_port: int, graphs) -> bool:
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


func _collect_reachable(root, graphs) -> Dictionary:
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


func _match_graph(scene: Dictionary, tpl: Dictionary, graphs) -> bool:
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

	return _assign_nodes(tpl_nodes.keys(), candidates, {}, tpl_edges, graphs)


func _assign_nodes(names: Array, cand: Dictionary, assigned: Dictionary, edges: Array, graphs) -> bool:
	if assigned.size() == names.size():
		return _check_edges(assigned, edges, graphs)

	var name = names[assigned.size()]
	for id in cand[name]:
		if id in assigned.values():
			continue
		assigned[name] = id
		if _assign_nodes(names, cand, assigned, edges, graphs):
			return true
		assigned.erase(name)

	return false


func _check_edges(map: Dictionary, edges: Array, graphs) -> bool:
	for e in edges:
		if not _graph_has_any_connection(map[e[0]], map[e[1]], graphs):
			return false
	return true


func _graph_has_any_connection(from_id, to_id, graphs) -> bool:
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

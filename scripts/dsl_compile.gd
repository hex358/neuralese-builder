class_name DSLCompile
extends RefCounted

var reg: DSLRegistry
var graph: DSLGraphUtils

# ============================================================
# Step directive compilers
# ============================================================

func step_apply_create(out_step: Dictionary, create_val) -> bool:
	var bocs = compile_create(create_val)
	if bocs.is_empty():
		return false

	out_step["bind_on_create"] = bocs
	return true


func step_apply_require(out_step: Dictionary, req_val) -> bool:
	var out = compile_require_list(req_val)
	if out.is_empty():
		return false
	out_step["requires"] = out
	return true

func compile_action_ask(v) -> Dictionary:
	if typeof(v) != TYPE_DICTIONARY:
		push_error("YAML: ask must be a mapping")
		return {}

	var head = v.get("head", null)
	var options = v.get("options", null)
	if not (head is String) or not (options is Array) or options.is_empty():
		push_error("YAML: ask.head (string) and ask.options (non-empty list) required")
		return {}

	var show = v.get("show", false)
	if not (show is bool):
		push_error("YAML: ask.show must be bool")
		return {}

	var correct_out: Array = []
	if v.has("correct"):
		var correct = v.get("correct", null)
		if not (correct is Array):
			push_error("YAML: ask.correct must be a list")
			return {}
		for c in correct:
			correct_out.append(int(c))

	var on_answer_out: Dictionary = {}
	if v.has("on_answer"):
		var oa = v.get("on_answer", null)
		if typeof(oa) != TYPE_DICTIONARY:
			push_error("YAML: ask.on_answer must be a mapping")
			return {}
		for k in oa.keys():
			var idx = int(k)
			if idx <= 0:
				push_error("YAML: ask.on_answer keys are 1-based integers")
				return {}
			var target = _compile_goto_target(oa[k])
			if target.is_empty():
				return {}
			on_answer_out[idx] = target

	var default_out: Dictionary = {}
	if v.has("default"):
		default_out = _compile_goto_target(v.get("default"))
		if default_out.is_empty():
			return {}

	var out: Dictionary = {
		"type": "ask",
		"head": head,
		"options": options,
		"show": show,
	}

	if correct_out.size() > 0:
		out["correct"] = correct_out
	if not on_answer_out.is_empty():
		out["on_answer"] = on_answer_out
	if not default_out.is_empty():
		out["default"] = default_out

	return out

func _compile_goto_target(v) -> Dictionary:
	# sugar: "goto explain_1"
	if typeof(v) == TYPE_STRING:
		var s = str(v).strip_edges()
		if s.begins_with("goto "):
			var name = s.substr(5, s.length() - 5).strip_edges()
			if name == "":
				push_error("YAML: goto target missing")
				return {}
			return { "op": "goto", "target": name }
		push_error("YAML: invalid goto string, expected 'goto <branch>'")
		return {}

	# explicit: { goto: explain_1 }
	if typeof(v) == TYPE_DICTIONARY and v.size() == 1:
		var k = str(v.keys()[0]).strip_edges()
		var vv = str(v.values()[0]).strip_edges()
		if k != "goto" or vv == "":
			push_error("YAML: goto must be { goto: <branch> }")
			return {}
		return { "op": "goto", "target": vv }

	push_error("YAML: invalid goto target format")
	return {}


func step_apply_actions(out_step: Dictionary, actions_val) -> bool:
	if typeof(actions_val) != TYPE_ARRAY:
		push_error("YAML: 'actions' must be a list")
		return false

	var out_actions: Array = []

	for item in actions_val:
		var act: Dictionary

		# Shorthand: "- 'text'" == explain action
		if typeof(item) == TYPE_STRING:
			act = reg.action["explain"]["compile"].call(item)

		elif typeof(item) == TYPE_DICTIONARY and item.size() == 1:
			var k = str(item.keys()[0])
			var v = item.values()[0]

			if not reg.action.has(k):
				push_error("YAML: unknown action '%s'" % k)
				return false

			act = reg.action[k]["compile"].call(v)

		else:
			push_error("YAML: invalid action format")
			return false

		if typeof(act) != TYPE_DICTIONARY or act.is_empty():
			return false

		out_actions.append(act)

	out_step["actions"] = out_actions
	return true


# ============================================================
# Action compilers (YAML -> canonical action dict)
# ============================================================

func compile_action_explain_button(v) -> Dictionary:
	return {
		"type": "explain_button",
		"exprs": {}
	}

func compile_action_prohibit_deletion(v) -> Dictionary:
	print(v)
	return {
		"type": "prohibit_deletion",
		"nodes": v if v is Array else [v]
	}

func compile_action_allow_deletion(v) -> Dictionary:
	return {
		"type": "allow_deletion",
		"nodes": v if v is Array else [v]
	}

func compile_action_explain_next(v) -> Dictionary:
	return {
		"type": "explain_next",
		"exprs": {}
	}


func compile_action_confetti(v) -> Dictionary:
	# No auto-mode: must specify what to highlight
	var wait = bool(v.get("whole_screen", false))
	if bool(v.get("whole_screen", false)):
		return { "type": "confetti", "targets": [], "whole": true, "wait": wait }
	
	if v == null:
		push_error("YAML: confetti requires a body (no auto mode).")
		return {}

	if typeof(v) != TYPE_DICTIONARY or v.is_empty():
		push_error("YAML: confetti must be a non-empty mapping.")
		return {}

	var targets_in = v.get("targets", null)
	if targets_in != null:
		if typeof(targets_in) != TYPE_ARRAY or targets_in.is_empty():
			push_error("YAML: confetti.targets must be a non-empty list.")
			return {}
		var targets_out: Array = []
		for t in targets_in:
			var one = _compile_highlight_selector(t)
			if one.is_empty():
				return {}
			targets_out.append(one)
		return { "type": "confetti", "targets": targets_out, "whole": false, "wait": wait }

	# Single selector form
	var one_sel = _compile_highlight_selector(v)
	if one_sel.is_empty():
		return {}
	return { "type": "confetti", "targets": [one_sel], "whole": false, "wait": wait }


func compile_action_explain(v) -> Dictionary:
	if typeof(v) == TYPE_STRING:
		return { "type": "explain", "text": str(v), "wait": "next" }

	if typeof(v) == TYPE_DICTIONARY:
		var text = v.get("text", "")
		if !text:
			push_error("YAML: explain.text is required")
			return {}

		var wait_mode = str(v.get("wait", "spare_press")).strip_edges()
		if wait_mode == "":
			wait_mode = "spare_press"

		var t = float(v.get("time", 1.0))

		if wait_mode != "next" and wait_mode != "time" and wait_mode != "none" and wait_mode != "spare_press":
			push_error("YAML: explain.wait must be 'next', 'spare_press', 'time', or 'none'")
			return {}

		return {
			"type": "explain",
			"text": text,
			"wait": wait_mode,
			"time": t,
		}

	push_error("YAML: explain must be string or mapping")
	return {}


func compile_action_select(v) -> Dictionary:
	if v == null:
		return {
			"type": "select",
			"exprs": {}
		}

	if typeof(v) == TYPE_DICTIONARY and v.is_empty():
		return {
			"type": "select",
			"exprs": {}
		}

	if typeof(v) == TYPE_DICTIONARY:
		var exprs = compile_config_exprs(v)
		if exprs.is_empty() and not v.is_empty():
			return {}
		return {
			"type": "select",
			"exprs": exprs
		}

	push_error("YAML: select must be a mapping or empty")
	return {}


func compile_action_require(req_val) -> Dictionary:
	var compiled_reqs = compile_require_list(req_val)
	if compiled_reqs.is_empty():
		return {}
	return { "type": "require", "requires": compiled_reqs }

func compile_action_create(v) -> Dictionary:
	var bocs = compile_create(v)
	if bocs.is_empty():
		return {}

	return {
		"type": "create",
		"bind_on_create": bocs
	}



# ============================================================
# Require list compilation (shared by step.require and action.require)
# ============================================================

func compile_require_list(req_val) -> Array:
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

		if not reg.require.has(key):
			push_error("YAML: unknown require type '%s'" % key)
			return []

		var spec: Dictionary = reg.require[key]
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


# ============================================================
# Requirement compilers (YAML -> canonical req dict)
# ============================================================

func compile_req_wait(v) -> Dictionary:
	if typeof(v) != TYPE_DICTIONARY:
		return {}
	if not v.has("time"):
		return {}
	var t = float(v["time"])
	if t <= 0.0:
		return {}
	return { "type": "wait", "time": t }


func compile_req_lock(_v) -> Dictionary:
	return { "type": "teacher_lock" }

func compile_req_node(v) -> Dictionary:
	if typeof(v) == TYPE_STRING:
		var bind_name = str(v).strip_edges()
		if bind_name == "":
			return {}
		return { "type": "node", "node": { "bind": bind_name } }

	if typeof(v) == TYPE_DICTIONARY:
		return { "type": "node", "node": v }

	return {}

func compile_req_connection(v) -> Dictionary:
	if typeof(v) != TYPE_DICTIONARY:
		return {}
	if not v.has("from") or not v.has("to"):
		return {}

	var out_req: Dictionary = {
		"type": "connection",
		"from": normalize_node_ref(v["from"]),
		"to": normalize_node_ref(v["to"]),
	}

	if v.has("out_port"):
		out_req["out_port"] = int(v["out_port"])
	if v.has("in_port"):
		out_req["in_port"] = int(v["in_port"])

	return out_req

func compile_req_config(v) -> Dictionary:
	if typeof(v) != TYPE_DICTIONARY:
		return {}
	if not v.has("node") or not v.has("exprs"):
		return {}
	if typeof(v["exprs"]) != TYPE_DICTIONARY:
		return {}

	return {
		"type": "config",
		"node": normalize_node_ref(v["node"]),
		"exprs": compile_config_exprs(v["exprs"])
	}

func compile_req_topology(v) -> Dictionary:
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
		var compiled = compile_topology_node_spec(nodes_in[name])
		if compiled.is_empty():
			return {}
		nodes_out[node_name] = compiled

	var edges_out: Array = []
	for e in edges_in:
		var pair = compile_edge(e)
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
# YAML compilation helpers
# ============================================================

func compile_create(create_val) -> Array:
	if typeof(create_val) != TYPE_DICTIONARY or create_val.is_empty():
		push_error("YAML: 'create' must be a non-empty mapping")
		return []

	var out: Array = []

	for k in create_val.keys():
		var bind_name = str(k).strip_edges()
		var node_type = str(create_val[k]).strip_edges()

		if bind_name == "" or node_type == "":
			push_error("YAML: create entries must be non-empty")
			return []

		out.append({
			"bind": bind_name,
			"type": node_type
		})

	return out


func compile_topology_node_spec(spec) -> Dictionary:
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
			out["config"] = compile_config_exprs(spec["config"])
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

	out2["config"] = compile_config_exprs(cfg_in)
	return out2

func compile_config_exprs(cfg_in: Dictionary) -> Dictionary:
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

func compile_edge(e) -> Array:
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

func normalize_node_ref(v):
	if typeof(v) == TYPE_STRING:
		return { "bind": str(v).strip_edges() }
	return v
	
func compile_action_highlight(v) -> Dictionary:
	# No auto-mode: must specify what to highlight
	if v == null:
		push_error("YAML: highlight requires a body (no auto mode).")
		return {}

	if typeof(v) != TYPE_DICTIONARY or v.is_empty():
		push_error("YAML: highlight must be a non-empty mapping.")
		return {}

	var targets_in = v.get("targets", null)
	if targets_in != null:
		if typeof(targets_in) != TYPE_ARRAY or targets_in.is_empty():
			push_error("YAML: highlight.targets must be a non-empty list.")
			return {}
		var targets_out: Array = []
		for t in targets_in:
			var one = _compile_highlight_selector(t)
			if one.is_empty():
				return {}
			targets_out.append(one)
		return { "type": "highlight", "targets": targets_out }

	# Single selector form
	var one_sel = _compile_highlight_selector(v)
	if one_sel.is_empty():
		return {}
	return { "type": "highlight", "targets": [one_sel] }


func _compile_highlight_selector(v) -> Dictionary:
	if typeof(v) != TYPE_DICTIONARY or v.is_empty():
		push_error("YAML: highlight selector must be a non-empty mapping.")
		return {}

	# 1) bind
	if v.has("bind"):
		var b = str(v.get("bind", "")).strip_edges()
		if b == "":
			push_error("YAML: highlight.bind must be a non-empty string.")
			return {}
		return { "kind": "bind", "bind": b }

	# 2) rough_topology (same shape as require.topology)
	if v.has("topology"):
		var topo_in = v["topology"]
		var topo_req = compile_req_topology(topo_in) # returns canonical topology_graph dict
		if topo_req.is_empty():
			push_error("YAML: highlight.topology failed to compile.")
			return {}
		return { "kind": "topology", "topology": topo_req }

	# 3) type (+ exprs)
	if v.has("type"):
		var t = str(v.get("type", "")).strip_edges()
		if t == "":
			push_error("YAML: highlight.type must be a non-empty string.")
			return {}

		# Two ways to pass exprs:
		# - highlight: { type: layer, where: {...} }
		# - highlight: { type: layer, neuron_count: ">= 8" } (shorthand)
		var exprs_in: Dictionary = {}

		if v.has("where"):
			if typeof(v["where"]) != TYPE_DICTIONARY:
				push_error("YAML: highlight.where must be a mapping.")
				return {}
			exprs_in = v["where"]
		else:
			# shorthand: all keys except "type" are exprs
			for k in v.keys():
				var kk = str(k)
				if kk == "type":
					continue
				exprs_in[kk] = v[k]

		var exprs = compile_config_exprs(exprs_in)
		# If exprs_in was non-empty but compiled empty -> error
		if exprs.is_empty() and not exprs_in.is_empty():
			push_error("YAML: highlight exprs are invalid.")
			return {}

		return { "kind": "type", "node_type": t, "exprs": exprs }

	push_error("YAML: highlight selector must contain one of: bind, type, rough_topology.")
	return {}

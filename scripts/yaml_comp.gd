# res://lesson_dsl/yaml_compiler.gd
# Requires: https://github.com/fimbul-works/godot-yaml (YAML.parse / YAML.emit)
# Input: YAML string (smart author DSL)
# Output: Dictionary (canonical dumb runtime JSON bundle)

class_name YAMLComp
extends RefCounted


static func compile_bundle(yaml_text: String) -> Dictionary:
	var root = _parse_yaml(yaml_text)
	if root == null:
		return {}

	var bundle_name = str(root.get("name", "")).strip_edges()
	if bundle_name == "":
		push_error("YAML: missing top-level 'name'")
		return {}

	var lessons_in = root.get("lessons", null)
	if typeof(lessons_in) != TYPE_DICTIONARY or lessons_in.is_empty():
		push_error("YAML: missing/invalid top-level 'lessons'")
		return {}

	# lesson order (optional)
	var lesson_keys: Array = lessons_in.keys()
	var lesson_order_src = root.get("lesson_order", null)

	if lesson_order_src != null:
		if typeof(lesson_order_src) != TYPE_ARRAY:
			push_error("YAML: 'lesson_order' must be a list")
			return {}
		lesson_keys = []
		for k in lesson_order_src:
			if not lessons_in.has(k):
				push_error("YAML: lesson_order references unknown lesson '%s'" % k)
				return {}
			lesson_keys.append(k)

	# compile lessons
	var lessons_out: Dictionary = {}
	var lesson_order_out: Array = []

	var idx := 1
	for lesson_key in lesson_keys:
		var lesson_def = lessons_in[lesson_key]
		if typeof(lesson_def) != TYPE_DICTIONARY:
			push_error("YAML: lesson '%s' must be a mapping" % str(lesson_key))
			return {}

		var flow = lesson_def.get("flow", null)
		if typeof(flow) != TYPE_ARRAY:
			push_error("YAML: lesson '%s' missing/invalid 'flow'" % str(lesson_key))
			return {}

		var steps_out: Array = []
		for item in flow:
			var step_def = _compile_flow_item(item)
			if step_def.is_empty():
				push_error("YAML: failed to compile step in lesson '%s'" % str(lesson_key))
				return {}
			steps_out.append(step_def)

		var lesson_id = str(idx)
		idx += 1

		lessons_out[lesson_id] = {
			"lesson_title": str(lesson_def.get("lesson_title", lesson_key)),
			"code": {
				"step_index": 0,
				"total_steps": steps_out.size(),
				"steps": steps_out
			}
		}

		lesson_order_out.append(lesson_id)

	return {
		"name": bundle_name,
		"lesson_order": lesson_order_out,
		"lessons": lessons_out
	}


static func compile_bundle_json(yaml_text: String, indent: String = "\t") -> String:
	var dict_out = compile_bundle(yaml_text)
	return JSON.stringify(dict_out, indent)


static func _parse_yaml(yaml_text: String):
	var data = YAML.parse(yaml_text).get_document()
	if data == null:
		push_error("YAML: parse failed")
		return null
	if typeof(data) != TYPE_DICTIONARY:
		push_error("YAML: root must be a mapping (dictionary)")
		return null
	return data


static func _compile_flow_item(item) -> Dictionary:
	if typeof(item) != TYPE_DICTIONARY or item.size() != 1:
		push_error("YAML: each flow item must be a mapping with a single key like 'step <id>:'")
		return {}

	var key = str(item.keys()[0])
	var body = item.values()[0]
	if typeof(body) != TYPE_DICTIONARY:
		push_error("YAML: step body must be a mapping")
		return {}

	var step_id = _parse_step_key(key)
	if step_id == "":
		push_error("YAML: invalid step key '%s' (expected 'step <id>')" % key)
		return {}

	var out_step: Dictionary = {
		"id": step_id,
		"title": str(body.get("title", step_id))
	}

	if bool(body.get("persistent", false)):
		out_step["persistent"] = true

	# Apply directives from registry
	for k in body.keys():
		var kk = str(k)

		if kk == "title" or kk == "persistent":
			continue

		if dsl_reg.step_directives.has(kk):
			var spec = dsl_reg.step_directives[kk]
			var fn_name = spec.get("compile", null)
			if fn_name == null:
				push_error("YAML: STEP_DIRECTIVES missing compile fn for '%s'" % kk)
				return {}
			
			print(fn_name)
			var ok = fn_name.call(out_step, body[kk])
			if ok != true:
				return {}
		else:
			# pass-through unknown step keys (future metadata)
			out_step[kk] = body[kk]

	return out_step


static func _parse_step_key(key: String) -> String:
	var s = key.strip_edges()
	if not s.begins_with("step "):
		return ""
	return s.substr(5, s.length() - 5).strip_edges()

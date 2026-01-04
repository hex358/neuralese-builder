class_name YAMLComp
extends RefCounted

static func compile_bundle(zip_path: String, zip: bool = false) -> Dictionary:
	var dir
	if zip:
		dir = glob.unzip_to_temp_dir(zip_path)
		if dir == null:
			push_error("ZIP: failed to unzip '%s'" % zip_path)
			return {}

		if dir.dir_exists("lesson_bundle"):
			dir.change_dir("lesson_bundle")
	else:
		dir = DirAccess.open(zip_path)
		print(dir.get_directories())

	if not dir.file_exists("bundle.yaml"):
		push_error("ZIP: missing bundle.yaml")
		return {}

	var bundle_yaml = _read_text_file(dir, "bundle.yaml")
	if bundle_yaml == "":
		return {}

	var bundle_root = _parse_yaml(bundle_yaml)
	if bundle_root == null:
		return {}

	var bundle_name = str(bundle_root.get("name", "")).strip_edges()
	if bundle_name == "":
		push_error("bundle.yaml: missing 'name'")
		return {}

	var lesson_order_src = bundle_root.get("lesson_order", [])
	if typeof(lesson_order_src) != TYPE_ARRAY:
		push_error("bundle.yaml: 'lesson_order' must be a list")
		return {}

	# ---------------- lessons ----------------
	if not dir.dir_exists("lessons"):
		push_error("ZIP: missing lessons/ directory")
		return {}

	var lessons_dir = DirAccess.open(dir.get_current_dir().path_join("lessons"))
	if lessons_dir == null:
		push_error("ZIP: cannot open lessons/")
		return {}

	var lessons_out := {}
	var lesson_order_out := []

	for lesson_key in lesson_order_src:
		var key := str(lesson_key)
		var lesson_file := "%s.yaml" % key

		if not lessons_dir.file_exists(lesson_file):
			push_error("lesson '%s' missing (%s)" % [key, lesson_file])
			return {}

		var lesson_yaml = _read_text_file(lessons_dir, lesson_file)
		if lesson_yaml == "":
			return {}

		var compiled = _compile_single_lesson(lesson_yaml, key)
		if compiled.is_empty():
			return {}

		lessons_out[key] = compiled
		lesson_order_out.append(key)

	return {
		"name": bundle_name,
		"lesson_order": lesson_order_out,
		"lessons": lessons_out
	}



static func _compile_single_lesson(yaml_text: String, fallback_title: String) -> Dictionary:
	var root = _parse_yaml(yaml_text)
	if root == null:
		return {}

	var flow = root.get("flow", null)
	if typeof(flow) != TYPE_ARRAY:
		push_error("lesson '%s': missing/invalid 'flow'" % fallback_title)
		return {}

	var steps_out = []
	for item in flow:
		var step_def = _compile_flow_item(item)
		if step_def.is_empty():
			push_error("lesson '%s': step compilation failed" % fallback_title)
			return {}
		steps_out.append(step_def)

	return {
		"lesson_title": str(root.get("lesson_title", fallback_title)),
		"code": {
			"step_index": 0,
			"total_steps": steps_out.size(),
			"steps": steps_out
		}
	}



static func _read_text_file(dir: DirAccess, path: String) -> String:
	var f = FileAccess.open(dir.get_current_dir().path_join(path), FileAccess.READ)
	if f == null:
		push_error("IO: failed to read %s" % path)
		return ""
	var txt = f.get_as_text()
	f.close()
	return txt





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

class_name LessonCode
extends Node

signal step_started(step_index: int, step: Dictionary)
signal step_completed(step_index: int, step: Dictionary)
signal invariant_broken(step_index: int, step: Dictionary, reason: String)

func _ready() -> void:
	_runtime_req_map = dsl_reg.build_runtime_map_by_type()

var _runtime_req_map: Dictionary = {}

var steps: Array = []
var current_step_index: int = -1

var node_bindings: Dictionary = {}
var pending_node_binds: Array = []
var active_invariants: Array[Callable] = []

func stop() -> void:
	current_step_index = -1
	node_bindings.clear()
	pending_node_binds.clear()
	active_invariants.clear()
	
	for step in steps:
		step["_completed"] = false
		for req in step.get("requires", []):
			req.erase("_resolved")

func load_steps(step_defs: Array) -> void:
	steps.clear()
	node_bindings.clear()
	pending_node_binds.clear()
	active_invariants.clear()

	for s in step_defs:
		var step = s.duplicate(true)
		step["_completed"] = false
		steps.append(step)

	current_step_index = -1

func start() -> void:
	await _advance_to_next_step()

func on_graph_changed() -> void:
	_check_invariants()
	_evaluate_current_step()

func load_state():
	pass # load stuff

func get_state():
	return {}

func on_node_created(node: Graph) -> void:
	for bind_spec in pending_node_binds:
		var bind_name = bind_spec["bind"]
		if node_bindings.has(bind_name):
			continue
		if node.get_meta("created_with") == bind_spec["type"]:
			node_bindings[bind_name] = node.graph_id
			pending_node_binds.erase(bind_spec)
			break
	on_graph_changed()

func _advance_to_next_step() -> void:
	current_step_index += 1
	if current_step_index >= steps.size():
		return

	var step = steps[current_step_index]

	if step.has("bind_on_create"):
		pending_node_binds.append(step["bind_on_create"])

	step_started.emit(current_step_index, step)
	await _evaluate_current_step()

func _evaluate_current_step() -> void:
	if current_step_index < 0 or current_step_index >= steps.size():
		return

	var step = steps[current_step_index]
	var exp = step.get("explain")
	
	if exp:
		if not exp.has("_phase"): exp["_phase"] = "before"
		if exp["_phase"] == "before" and not exp.get("_shown_before", false):
			exp["_shown_before"] = true
			await dsl_reg._show_explain_before(exp)

	var requires_ok = await _step_satisfied(step)
	if not requires_ok:
		return

	if exp:
		if exp["_phase"] == "before": exp["_phase"] = "after"
		if exp["_phase"] == "after" and not exp.get("_shown_after", false):
			exp["_shown_after"] = true
			await dsl_reg._show_explain_after(exp)
			_complete_step(step)
	else:
		_complete_step(step)


func _complete_step(step: Dictionary) -> void:
	if step["_completed"]:
		return

	step["_completed"] = true
	step_completed.emit(current_step_index, step)

	if step.get("persistent", false):
		for req in step.get("requires", []):
			active_invariants.append(_compile_requirement(req))

	_advance_to_next_step()

func _step_satisfied(step: Dictionary) -> bool:
	for req in step.get("requires", []):
		if not req.has("_resolved"):
			var ok = await _compile_requirement(req).call()
			if not ok:
				return false
			req["_resolved"] = true
	return true


func _compile_requirement(req: Dictionary) -> Callable:
	var t = str(req.get("type", ""))
	var fn_name = _runtime_req_map.get(t, null)

	if fn_name == null:
		push_error("Unknown requirement type: %s" % t)
		return func() -> bool:
			return false

	return func() -> bool:
		return await fn_name.call(req, node_bindings)

func _check_invariants() -> void:
	for inv in active_invariants:
		if not inv.call():
			invariant_broken.emit(current_step_index, steps[current_step_index], "Invariant broken")
			return

class_name LessonCode
extends Node

signal step_started(step_index: int, step: Dictionary)
signal step_completed(step_index: int, step: Dictionary)
signal invariant_broken(step_index: int, step: Dictionary, reason: String)

# NEW: explanations as first-class runtime interaction
signal explain_requested(text: String, wait_mode: String)
signal explain_next_ack()

func ack_explain_next() -> void:
	explain_next_ack.emit()

func _ready() -> void:
	_runtime_req_map = dsl_reg.build_runtime_map_by_type()

var _runtime_req_map: Dictionary = {}
var steps: Array = []
var current_step_index: int = -1

var node_bindings: Dictionary = {}
var pending_node_binds: Array = []
var active_invariants: Array[Callable] = []

# NEW: re-entrancy guard
var _evaluating: bool = false
var _queued_eval: bool = false

func stop() -> void:
	current_step_index = -1
	node_bindings.clear()
	pending_node_binds.clear()
	active_invariants.clear()

	for step in steps:
		step["_completed"] = false
		step.erase("_action_i")

		# legacy requires
		for req in step.get("requires", []):
			req.erase("_resolved")

		# actions requires
		for act in step.get("actions", []):
			if typeof(act) == TYPE_DICTIONARY and str(act.get("type", "")) == "require":
				for req2 in act.get("requires", []):
					req2.erase("_resolved")

func load_code(code: Dictionary) -> void:
	# ------------------------------------------------
	# Validate
	# ------------------------------------------------
	if typeof(code) != TYPE_DICTIONARY:
		push_error("load_code: code must be a Dictionary")
		return

	var entry = str(code.get("entry", "")).strip_edges()
	var src_flows = code.get("flows", null)

	if entry == "" or typeof(src_flows) != TYPE_DICTIONARY:
		push_error("load_code: invalid code structure")
		return

	if not src_flows.has(entry):
		push_error("load_code: entry flow '%s' not found" % entry)
		return

	# ------------------------------------------------
	# Reset ALL runtime state
	# ------------------------------------------------
	flows.clear()
	flow_stack.clear()
	node_bindings.clear()
	pending_node_binds.clear()
	active_invariants.clear()

	_evaluating = false
	_queued_eval = false

	# ------------------------------------------------
	# Deep-copy and normalize all flows
	# ------------------------------------------------
	for fname in src_flows.keys():
		var src_steps = src_flows[fname]
		if typeof(src_steps) != TYPE_ARRAY:
			push_error("load_code: flow '%s' must be an Array" % fname)
			return

		var out_steps: Array = []

		for s in src_steps:
			var step = s.duplicate(true)

			# per-step runtime flags
			step["_completed"] = false
			step.erase("_action_i")

			# legacy requires
			for req in step.get("requires", []):
				req.erase("_resolved")

			# action.require requires
			for act in step.get("actions", []):
				if typeof(act) == TYPE_DICTIONARY and str(act.get("type", "")) == "require":
					for req2 in act.get("requires", []):
						req2.erase("_resolved")

			# ask action internal flags
			for act2 in step.get("actions", []):
				if typeof(act2) == TYPE_DICTIONARY and str(act2.get("type", "")) == "ask":
					act2.erase("_asked")

			out_steps.append(step)

		flows[fname] = out_steps

	# ------------------------------------------------
	# Activate entry flow
	# ------------------------------------------------
	active_flow = entry
	main_flow_name = entry
	steps = flows[entry]
	main_flow_steps_count = steps.size()
	current_step_index = -1

func get_main_total_steps() -> int:
	return main_flow_steps_count

func get_main_step_index() -> int:
	if active_flow != main_flow_name:
		return flow_stack[0].step_index if flow_stack.size() > 0 else current_step_index
	return current_step_index


var main_flow_name: String = "flow"
var main_flow_steps_count: int = 0

func start() -> void:
	await _advance_to_next_step()

func on_graph_changed() -> void:
	_check_invariants()
	_request_evaluate()

func _request_evaluate() -> void:
	# prevents multiple concurrent evals
	if _evaluating:
		_queued_eval = true
		return
	await _evaluate_current_step()

func on_node_created(node: Graph) -> void:
	for bind_spec in pending_node_binds:
		var bind_name = bind_spec["bind"]
		if node_bindings.has(bind_name):
			continue
		if bind_spec["type"] == "anytype" or node.get_meta("created_with") == bind_spec["type"]:
			node_bindings[bind_name] = node.graph_id
			pending_node_binds.erase(bind_spec)
			break
	on_graph_changed()

func _dbg(msg: String) -> void:
	print("[LESSON][%s] %s" % [active_flow, msg])

func _advance_to_next_step() -> void:
	_dbg("ADVANCE from index=%d steps=%d" %
		[current_step_index, steps.size()])

	if current_step_index + 1 >= steps.size():
		_dbg(" FLOW END detected")

		if _return_from_flow_if_needed():
			_dbg(" RESUMED after return")
			call_deferred("_advance_to_next_step")
			return

		_dbg(" NO FLOW TO RETURN TO — STOP")
		return

	current_step_index += 1
	var step = steps[current_step_index]

	_dbg(" ENTER STEP %d title='%s'" %
		[current_step_index, step.get("title", step.get("id", "?"))])

	if step.has("bind_on_create"):
		pending_node_binds.append(step["bind_on_create"])

	step_started.emit(current_step_index, step)
	call_deferred("_request_evaluate")




func call_branch(flow_name: String) -> void:
	_dbg("CALL_BRANCH -> %s" % flow_name)

	if not flows.has(flow_name):
		push_error("Unknown branch: %s" % flow_name)
		return

	var step = steps[current_step_index]
	var next_i = int(step.get("_action_i", 0)) + 1

	_dbg(" PUSH FRAME {flow=%s step=%d action_i=%d}" %
		[active_flow, current_step_index, next_i])

	flow_stack.append({
		"flow": active_flow,
		"step_index": current_step_index,
		"action_i": next_i,
	})

	step["_action_i"] = step.get("actions", []).size()

	_switch_flow(flow_name, true)




func _switch_flow(flow_name: String, restart: bool) -> void:
	_dbg("SWITCH_FLOW -> %s restart=%s" % [flow_name, restart])

	active_flow = flow_name
	steps = flows[flow_name]

	if restart:
		current_step_index = -1
	else:
		current_step_index = max(current_step_index, -1)

	_dbg(" current_step_index=%d steps=%d" %
		[current_step_index, steps.size()])

	call_deferred("_advance_to_next_step")



func _return_from_flow_if_needed() -> bool:
	if flow_stack.is_empty():
		_dbg("RETURN_FLOW: stack empty")
		return false

	var fr = flow_stack.pop_back()

	_dbg("RETURN_FLOW -> flow=%s step=%d action_i=%d" %
		[fr["flow"], fr["step_index"], fr["action_i"]])

	active_flow = fr["flow"]
	steps = flows[active_flow]
	current_step_index = int(fr["step_index"])

	var step = steps[current_step_index]
	step["_action_i"] = int(fr["action_i"])

	_dbg(" RESTORED step_index=%d action_i=%d" %
		[current_step_index, step["_action_i"]])

	return true



var flows: Dictionary = {}     # name -> steps Array
var flow_stack: Array = []     # stack of frames
var active_flow: String = "flow"

func _evaluate_current_step() -> void:
	if current_step_index < 0 or current_step_index >= steps.size():
		return

	_evaluating = true
	while true:
		_queued_eval = false

		var step = steps[current_step_index]
		var ok = await _run_actions(step)
		if ok:
			_complete_step(step)

		if not _queued_eval:
			break

	_evaluating = false


# ============================================================
# NEW: action execution
# ============================================================

func _run_actions(step: Dictionary) -> bool:
	# returns true when all actions completed for this step
	if not step.has("_action_i"):
		step["_action_i"] = 0

	var actions: Array = step.get("actions", [])
	while int(step["_action_i"]) < actions.size():
		var i: int = int(step["_action_i"])
		var act = actions[i]
		var done = await _run_action(step, act)
		if not done:
			return false # blocked
		step["_action_i"] = i + 1

	return true


func _run_action(step: Dictionary, act: Dictionary) -> bool:
	var t = str(act.get("type", ""))
	var fn = dsl_reg.action.get(t, {}).get("runtime", null)

	if fn == null:
		push_error("Unknown action type: %s" % t)
		return false

	return await fn.call(act, self)




func _requirements_satisfied(reqs: Array) -> bool:
	for req in reqs:
		if not req.has("_resolved"):
			var ok = await _compile_requirement(req).call()
			if not ok:
				return false
			req["_resolved"] = true
	return true

# ============================================================
# Existing completion + requirement runtime (unchanged)
# ============================================================

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

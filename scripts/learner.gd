extends Node

var lesson: LessonCode



func cache():
	lesson_cache = glob.get_var("lesson_cache", {}, "classrooms.bin")
	for i in lesson_cache.keys():
		if lesson_cache[i].has("classroom_data"):
			lesson_cache[i] = lesson_cache[i].classroom_data
		if not i:
			lesson_cache.erase(i)
	glob.set_var("lesson_cache", lesson_cache, "classrooms.bin")

func ack_explain_next():
	if lesson:
		lesson.ack_explain_next()

func _enter_tree() -> void:
	
	cache()
	#print(lesson_cache)

func active() -> bool: 
	return lesson_list().keys().find(current_lesson_key) != -1

func try_load_cached():
	var got = glob.get_var("lesson_cache", {}, "classroom.bin")
	lesson_cache = got

func dbg_load_lesson(path:String):
	var compiled = YAMLComp.new().compile_bundle(path, false)
	print(JSON.stringify(compiled, "\t"))
	#print(compiled)
	if compiled:
		load_classroom_data(compiled)

func _ready() -> void:
	#print(dsl_reg)
	
	lesson_re_reg()

func lesson_re_reg():
	if lesson:
		lesson.queue_free()
		lesson = null
	await get_tree().process_frame
	lesson = LessonCode.new()
	add_child(lesson)

	lesson.step_started.connect(_on_step_started)
	lesson.step_completed.connect(_on_step_completed)
	lesson.invariant_broken.connect(_on_invariant_broken)
	graphs.node_added.connect(lesson.on_node_created)
	
	LessonRouter.register_lesson(lesson)


func stop_lesson():
	if lesson:
		ui.quest.reset()
		ui.recreate_quest()
		current_lesson_key = null
		lesson.stop()
		ui.lesson_bar.dissapear()
		await get_tree().process_frame
		lesson_re_reg()


func join_classroom(id: String) -> Dictionary:
	var resp = await web.JPOST("classroom/join", {
		"user": cookies.user(), "pass": cookies.pwd(), "classroom_id": id})
	if resp and resp.get("ok", false):
		cookies.set_profile("my_classroom", id)

		load_classroom_data(resp.data)
	return resp


func cache_classroom_data():
	var resp = await web.JPOST("classroom/meta", {
		"user": cookies.user(), "pass": cookies.pwd(), "classroom_id": cookies.profile("my_classroom") })
	#print(resp.data)
	if resp and resp.get("ok", false):
		load_classroom_data(resp.data)


func leave_classroom() -> bool:
	if cookies.profile("my_classroom"):
		var resp = await web.JPOST("classroom/leave", {
			"user": cookies.user(), "pass": cookies.pwd(), "classroom_id": cookies.profile("my_classroom")})
	cookies.set_profile("my_classroom", "")
	return true



func is_lesson_open(who):
	#print(lesson_list().keys().find(who))
	#print(classroom_data["lesson_customs"].get((lesson_list().keys().find(who)), {}))
	return classroom_data and classroom_data["lesson_customs"].get((lesson_list().keys().find(who)), {}).get("opened", false)

func create_classroom(name: String = "Untitled") -> String:
	var resp = await web.JPOST("classroom/create", {
		"user": cookies.user(), "pass": cookies.pwd(), 
		"meta": {"name": name}})
	if not resp: return ""
	classroom_data = {}
	if resp and "classroom_id" in resp:
		cookies.set_profile("my_classroom", resp["classroom_id"])
		load_classroom_data(resp.data.classroom_data)
	#print(classroom_data)
	return resp.get("classroom_id", "")


func classroom_stream():
	if not cookies.user(): return
	var h = web.GET_SSE(
		"classroom/events",
		{"classroom_id": cookies.profile("my_classroom")},
		{
			"X-Auth-User": cookies.user(),
			"X-Auth-Pass": cookies.pwd()
		}
	)
	
	return h

class EndSignal:
	signal end_signal

func wait_unblock():
	if glob.DEBUG_RELOAD_LESSONS:
		return true
	var h = classroom_stream()
	var end = EndSignal.new()
	var x = func(evt):
		#print(JSON.stringify(evt, "\t"))
		if evt.get("event", "") != "snapshot": return
		evt = JSON.parse_string(evt.data)
		if not evt.students.get(cookies.user(), {}).get("awaiting", false):
			end.end_signal.emit()
		#if evt["end"]: end.end_signal.emit()
	h.on_sse.connect(x)
	await end.end_signal
	h.cancel()
	return true


func _process(delta: float) -> void:
	pass


var lesson_cache = {}
var classroom_data = {}

func lesson_list():
	var profile = lesson_cache.get(cookies.profile("my_classroom"), {})
	
	if not profile: return {}
	var output = {}
	for i in profile.lesson_order:
		output[i] = {"name": profile.lessons[i].lesson_title}
	return output


	#cookies.open_or_create("class.json", "C:/Users/Mike/Downloads/").store_string(JSON.stringify(lesson_cache["535706"], "\t"))


func load_classroom_data(data: Dictionary):
	if "classroom_data" in data:
		data = data.classroom_data
	#	print(data)
	var customs = {}
	for i in data.get("lesson_customs", {}):
		customs[int(i)] = data["lesson_customs"][i]
	data["lesson_customs"] = customs
	
	#	print_stack()
	classroom_data = data
	lesson_cache[cookies.profile("my_classroom")] = classroom_data
	glob.set_var("lesson_cache", lesson_cache, "classroom.bin")
	#print(data)

func get_classroom_frontend():
	return lesson_cache.get(cookies.profile("my_classroom"), {})

var current_lesson = {}; var current_lesson_key = null
func enter_lesson(lesson_key):
	#print(lesson_cache.get(cookies.profile("my_classroom"), {}).\
	#get("lessons", {}))
	ui.quest.reset()
	ui.recreate_quest()
	lesson.stop()
	await lesson_re_reg()
	var orch = lesson_cache.get(cookies.profile("my_classroom"), {}).\
	get("lessons", {}).get(lesson_key, {})
	if not orch: printerr("Lesson doesn't exist"); return
	current_lesson = orch; current_lesson_key = lesson_key
	current_code = orch.code
	#print(JSON.stringify(current_code, "\t"))
	lesson.load_code(orch.code)
	lesson.start()
	ui.lesson_bar.appear()
	push_classroom_event({"on_lesson": get_classroom_frontend().lesson_order.find(lesson_key), "awaiting": false})
	
var current_code = {}

func push_classroom_event(event: Dictionary, target = null):
	if not cookies.user(): return
	var resp = await web.JPOST("classroom/update_state", {"target": target if target != null else cookies.user(),
	"user": cookies.user(), "pass": cookies.pwd(), "payload": event, "classroom_id": cookies.profile("my_classroom")})

func upload_classroom_meta(meta: Dictionary):
	load_classroom_data(meta)
	var resp = await web.JPOST("classroom/update_meta", {
	"user": cookies.user(), "pass": cookies.pwd(), "payload": meta, "classroom_id": cookies.profile("my_classroom")})


func upload_lesson_customs(lesson_id: int, meta: Dictionary):
	classroom_data.get_or_add("lesson_customs", {})[lesson_id] = meta
	var resp = await web.JPOST("classroom/update_lessons", {
	"user": cookies.user(), "pass": cookies.pwd(), "payload": {lesson_id: meta}, "classroom_id": cookies.profile("my_classroom")})


func mark_explanation_made(idx: int = -1):

	var resp = await web.JPOST("classroom/mark_explanation_made", {"lesson_idx": idx,
	"user": cookies.user(), "pass": cookies.pwd(), "classroom_id": cookies.profile("my_classroom")})



func _exit_tree() -> void:
	LessonRouter.unregister_lesson(lesson)


func _on_step_started(idx: int, step: Dictionary) -> void:
	#print(current_code.keys())
	#print(current_code.steps)
	print("STEP START:", step.get("title", step.get("id")), " ", idx)
	push_classroom_event({"step": idx+1})
	await get_tree().process_frame
	ui.lesson_bar.update_data({
	classroom_name = classroom_data["name"],
	step_index = lesson.get_main_step_index() + 1,
	step_shorthand = step.get("title", ""),
	lesson_index = get_classroom_frontend().lesson_order.find(current_lesson_key) + 1,
	lesson_name = current_lesson.lesson_title,
	total_steps = lesson.get_main_total_steps()
}, idx == 0, idx != 0)


func estimate_read_time(text: String) -> float:
	# --- Base reading speed ---
	var WPM := 160.0
	var words := text.split(" ", false)
	var base_time := (words.size() / WPM) * 60.0

	# --- Punctuation pauses ---
	var punctuation_time := 0.0

	punctuation_time += text.count(",") * 0.15
	punctuation_time += text.count(".") * 0.35
	punctuation_time += text.count("?") * 0.45
	punctuation_time += text.count("!") * 0.45
	punctuation_time += (text.count(":") + text.count(";")) * 0.30
	punctuation_time += text.count("\n") * 0.50

	# --- Long word penalty ---
	var long_word_time := 0.0
	for word in words:
		if word.length() > 8:
			long_word_time += 0.04

	# --- Numbers slow reading ---
	var number_time := 0.0
	for c in text:
		if c.is_valid_int():
			number_time += 0.20

	# --- Final time ---
	var total_time := base_time + punctuation_time + long_word_time + number_time

	# Clamp to avoid absurd values
	return max(total_time, 0.5)


func _on_step_completed(idx: int, step: Dictionary) -> void:
	print("STEP DONE:", step.get("title", step.get("id")))


func _on_invariant_broken(idx: int, step: Dictionary, reason: String) -> void:
	print("INVARIANT BROKEN:", reason)

func _build_smoke_test() -> Dictionary:
	return {"total_steps": 7,
		"step_index": 0,
		"steps":[
		{
			"id": "create_input",
			"title": "Create input node",
			"bind_on_create": {
				"type": "input_1d",
				"bind": "x"
			},
			"requires": [
				{
					"type": "node",
					"node": { "bind": "x" }
				}
			]
		},
		{
			"id": "create_dense_a",
			"title": "Create first dense layer",
			"bind_on_create": {
				"type": "layer",
				"bind": "dense_a"
			},
			"requires": [
				{
					"type": "node",
					"node": { "bind": "dense_a" }
				}
			]
		},
		{
			"id": "create_dense_b",
			"title": "Create second dense layer",
			"bind_on_create": {
				"type": "layer",
				"bind": "dense_b"
			},
			"requires": [
				{
					"type": "node",
					"node": { "bind": "dense_b" }
				}
			]
		},
		{
			"id": "connect_input_dense",
			"title": "Connect input to first dense",
			"requires": [
				{
					"type": "connection",
					"from": { "bind": "x" },
					"to":   { "bind": "dense_a" }
				}
			],
			"persistent": true
		},
		{
			"id": "connect_dense_dense",
			"title": "Connect dense to dense",
			"requires": [
				{
					"type": "connection",
					"from": { "bind": "dense_a" },
					"to":   { "bind": "dense_b" }
				}
			],
			"persistent": true
		},
		{
			"id": "config_dense",
			"title": "Configure dense units",
			"requires": [
				{
					"type": "config",
					"node": { "bind": "dense_a" },
					"exprs": {
						"neuron_count": "neuron_count >= 4"
					}
				}
			],
			"persistent": true
		},
		{
			"id": "finish",
			"title": "Lesson finished"
		}
	]}



	

func notify_update():
	LessonRouter.notify_graph_changed()

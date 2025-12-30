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

func _enter_tree() -> void:
	
	cache()

func _ready() -> void:
	#print(dsl_reg)
	#print(
		#JSON.stringify(
		#YAMLComp.new().compile_bundle(FileAccess.\
		#get_file_as_string("c:/users/mike/downloads/class.yaml")), "\t"))
	
	await glob.wait(1)

	lesson = LessonCode.new()
	add_child(lesson)

	lesson.step_started.connect(_on_step_started)
	lesson.step_completed.connect(_on_step_completed)
	lesson.invariant_broken.connect(_on_invariant_broken)
	graphs.node_added.connect(lesson.on_node_created)
	
	LessonRouter.register_lesson(lesson)



func join_classroom(id: String) -> Dictionary:
	var resp = await web.JPOST("classroom/join", {
		"user": cookies.user(), "pass": cookies.pwd(), "classroom_id": id})
	if resp and resp.get("ok", false):
		cookies.set_profile("my_classroom", id)

		load_classroom_data(resp.data)
	return resp


func cache_classroom_data():
	var resp = await web.JPOST("classroom/meta", {
		"user": cookies.user(), "pass": cookies.pwd()})
	if resp and resp.get("ok", false):
		load_classroom_data(resp.data)


func leave_classroom() -> bool:
	if cookies.profile("my_classroom"):
		var resp = await web.JPOST("classroom/leave", {
			"user": cookies.user(), "pass": cookies.pwd(), "classroom_id": cookies.profile("my_classroom")})
	cookies.set_profile("my_classroom", "")
	return true





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
	var h = classroom_stream()
	var end = EndSignal.new()
	var x = func(evt):
		if evt.get("event", "") != "event": return
		evt = JSON.parse_string(evt.data)
		if evt["end"]: end.end_signal.emit()
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
	
	#	print_stack()
	classroom_data = data
	lesson_cache[cookies.profile("my_classroom")] = classroom_data
	glob.set_var("lesson_cache", lesson_cache, "classroom.bin")


func get_classroom_frontend():
	return lesson_cache.get(cookies.profile("my_classroom"), {})

var current_lesson = {}; var current_lesson_key = null
func enter_lesson(lesson_key):
	#print(lesson_cache.get(cookies.profile("my_classroom"), {}).\
	#get("lessons", {}))
	var orch = lesson_cache.get(cookies.profile("my_classroom"), {}).\
	get("lessons", {}).get(lesson_key, {})
	if not orch: printerr("Lesson doesn't exist"); return
	current_lesson = orch; current_lesson_key = lesson_key
	current_code = orch.code
	lesson.load_steps(orch.code.steps)
	lesson.start()
	ui.lesson_bar.appear()
	push_classroom_event({"on_lesson": get_classroom_frontend().lesson_order.find(lesson_key)})
	
var current_code = {}

func push_classroom_event(event: Dictionary):

	var resp = await web.JPOST("classroom/update_state", {
	"user": cookies.user(), "pass": cookies.pwd(), "payload": event, "classroom_id": cookies.profile("my_classroom")})

func upload_classroom_meta(meta: Dictionary):
	load_classroom_data(meta)
	var resp = await web.JPOST("classroom/update_meta", {
	"user": cookies.user(), "pass": cookies.pwd(), "payload": meta, "classroom_id": cookies.profile("my_classroom")})


func mark_explanation_made(idx: int = -1):

	var resp = await web.JPOST("classroom/mark_explanation_made", {"lesson_idx": idx,
	"user": cookies.user(), "pass": cookies.pwd(), "classroom_id": cookies.profile("my_classroom")})



func _exit_tree() -> void:
	LessonRouter.unregister_lesson(lesson)


func _on_step_started(idx: int, step: Dictionary) -> void:
	print("STEP START:", step.get("title", step.get("id")))
	push_classroom_event({"step": idx+1})
	await get_tree().process_frame
	ui.lesson_bar.update_data({
	classroom_name = classroom_data["name"], 
	step_index = idx+1, step_shorthand = step.get("title", ""),
	lesson_index = get_classroom_frontend().lesson_order.find(current_lesson_key)+1, lesson_name = current_lesson.lesson_title, total_steps = int(current_code.total_steps)}, idx == 0)




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

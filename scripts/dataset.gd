extends SplashMenu

@onready var list = $ColorRect/list



func _process(delta: float) -> void:
	var prev_s = $ColorRect.scale
	super(delta)
	if !glob.is_vec_approx(prev_s, $ColorRect.scale):
		list.update_children_reveal()
		
var parsed = {}
func _ready() -> void:
	super()
	await get_tree().process_frame
	#$ColorRect/Label.text = cookies.get_username()
	ui.hourglass_on()
	var a = {"n/mnist": {"some data": 1}, "n/iris": {"some data": 1}}#await glob.request_projects()
	ui.hourglass_off()
	$ColorRect/list.passed_who = passed_data.get("with_who", "")
	#quitting.connect(
#	glob.reset_menu_type.bind($ColorRect/list, &"delete_project"))
	#var a = await web.POST("project_list", {
	#"user": "neri", 
	#"pass": "123"
	#})
	#if a.body:
		#parsed = JSON.parse_string(a.body.get_string_from_utf8())["list"]
	list.show_up(a)
	await get_tree().process_frame

func _resultate(data: Dictionary):
	emitter.res.emit(data)
	go_away()


func _on_list_child_button_release(button: BlockComponent) -> void:
	resultate({"ds": button.hint})


func _on_add() -> void:
	pass
	#can_go = false
	#go_away()
	#await quitting
	#queue_free()
	#ui.splash("project_create", splashed_from, emitter, true)



func _on_logout() -> void:
	pass # Replace with function body.

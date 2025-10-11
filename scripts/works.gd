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
	$ColorRect/Label.text = cookies.get_username()
	var a = await glob.request_projects()
	#var a = await web.POST("project_list", {
	#"user": "neri", 
	#"pass": "123"
	#})
	#if a.body:
		#parsed = JSON.parse_string(a.body.get_string_from_utf8())["list"]
	list.show_up(a)
	await get_tree().process_frame
	for i in list._contained:
		if i.metadata["project_id"] == glob.get_project_id():
			i.set_tuning(i.base_tuning * 1.2)


func _on_list_child_button_release(button: BlockComponent) -> void:
	glob.load_scene(str(button.metadata["project_id"]))
	go_away()


func _on_add() -> void:
	can_go = false
	go_away()
	await quitting
	queue_free()
	ui.splash("project_create", splashed_from, emitter, true)



func _on_logout() -> void:
	pass # Replace with function body.

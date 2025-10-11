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
	quitting.connect(
	glob.reset_menu_type.bind($ColorRect/list, &"delete_project"))
	#var a = await web.POST("project_list", {
	#"user": "neri", 
	#"pass": "123"
	#})
	#if a.body:
		#parsed = JSON.parse_string(a.body.get_string_from_utf8())["list"]
	list.show_up(a)
	await get_tree().process_frame



func _on_list_child_button_release(button: BlockComponent) -> void:
	if not glob.menus["delete_project"].state.expanding \
	and (!glob.menus["delete_project"].visible or not glob.menus["delete_project"].state.tween_hide):
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

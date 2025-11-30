extends SplashMenu

@onready var list = $ColorRect/list

func _process(delta: float) -> void:
	var prev_s = $ColorRect.scale
	super(delta)
	if !glob.is_vec_approx(prev_s, $ColorRect.scale):
		list.update_children_reveal()
		
var parsed = {}
func _ready() -> void:
	update_lang()
	super() 
	await get_tree().process_frame
	$ColorRect/Label.text = cookies.get_username()
	ui.hourglass_on()
	if !glob.loaded_project_once:
		glob.loaded_project_once = true
		await glob.save_empty(str(glob.project_id), glob.fg.get_scene_name())
	var a = await glob.request_projects()
	ui.hourglass_off()
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
		if button.metadata["project_id"] != glob.get_project_id():
			ui.hourglass_on()
			var a = await glob.load_scene(str(button.metadata["project_id"]))
			ui.hourglass_off()
		go_away()


func _on_add() -> void:
	can_go = false
	go_away()
	await quitting
	queue_free()
	ui.splash("project_create", splashed_from, emitter, true)



func _on_logout() -> void:
	glob.reset_logged_in(true)
	can_go = true
	go_away()
	await quitting
	queue_free()


func _on_list_scroll_changed() -> void:
	glob.hide_all_menus()

@onready var lang_button = $ColorRect/lang
func _on_lang_released() -> void:
	glob.switch_lang()
	#print(glob.get_lang())
	update_lang()

func update_lang():
	match glob.get_lang():
		"en":
			lang_button.text = "ENG"
		"ru":
			lang_button.text = "RUS"
		"kz":
			lang_button.text = "KAZ"

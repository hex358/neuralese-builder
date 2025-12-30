extends SplashMenu

@onready var list = $ColorRect/list

func _process(delta: float) -> void:
	var prev_s = $ColorRect.scale
	super(delta)
	if !glob.is_vec_approx(prev_s, $ColorRect.scale):
		list.update_children_reveal()
		
var parsed = {}
func _ready() -> void:
	#print("a")
	super() 
	await get_tree().process_frame
	#$ColorRect/Label.text = cookies.get_username()
	#ui.hourglass_on()
	#if !glob.loaded_project_once and not glob.DUMMY_LOGIN:
	#	glob.loaded_project_once = true
	#	await glob.save_empty(str(glob.project_id), glob.fg.get_scene_name())
	var a = learner.lesson_list()
	#ui.hourglass_off()
	#quitting.connect(
	#glob.reset_menu_type.bind($ColorRect/list, &"delete_project"))
	#var a = await web.POST("project_list", {
	#"user": "neri", 
	#"pass": "123"
	#})
	#if a.body:
		#parsed = JSON.parse_string(a.body.get_string_from_utf8())["list"]
	list.show_up(a)
	await get_tree().process_frame



func _on_list_child_button_release(button: BlockComponent) -> void:
	learner.enter_lesson(button.hint)
	go_away()




func _on_list_scroll_changed() -> void:
	glob.hide_all_menus()

@onready var lang_button = $ColorRect/lang
func _on_lang_released() -> void:
	resultate({"go_setts": true})
	#ui.splash("settings", lang_button)
	#glob.switch_lang()
	#print(glob.get_lang())
	#update_lang()


func _resultate(data: Dictionary):
	if "go_path" in data:
		can_go = false
		go_away()
		await quitting
		queue_free()
		ui.splash_and_get_result("path_open", splashed_from, emitter, true, 
		{"filter": ["nls"], "from_proj": splashed_from})
	elif "go_setts" in data:
		can_go = false
		go_away()
		await quitting
		queue_free()
		ui.splash("settings", lang_button, emitter, true, {"from_but": splashed_from})
	else:
		#var rand_dataset_id: int = randi_range(0,999999)
		emitter.res.emit(data)
		pass
		go_away()
#
#
#func _on_trainn_released() -> void:
	#$ColorRect/Label.update_valid()
	#if $ColorRect/Label.is_valid:
		#var result = {"text": $ColorRect/Label.text}
		#if passed_data.has("path"):
			#result["path"] = passed_data["path"]
		#resultate(result)
#
#
#func _on_load_released() -> void:
	##var a = await ui.splash_and_get_result("path_open", csv)
	#resultate({"go_path": true})
	#pass # Replace with function body.





func _on_import_released() -> void:
	
	resultate({"go_path": true})
	pass # Replace with function body.


func _on_lessons_released() -> void:
	inner = true
	go_away(false)
	can_tween_zero = false
	await quitting
	ui.splash("workslist", splashed_from, emitter, true)

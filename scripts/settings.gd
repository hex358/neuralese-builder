extends SplashMenu

@onready var list = $ColorRect/list
@onready var diff = $ColorRect.size.x - $ColorRect/Account.position.x
func _process(delta: float) -> void:
	var prev_s = $ColorRect.scale
	super(delta)
	#list_unroll.max_size = 50
	$ColorRect/Account.position.x = $ColorRect.size.x - diff

func usr_update():
	var prefix = "User: "
	match glob.curr_lang:
		"kz":
			prefix = "Адам: "
		"ru":
			prefix = "Юзер: "
	$ColorRect/Control/Label.text = prefix + cookies.user()


func set_teacher_layout():
	set_base_size(Vector2(518,472.0))
	$ColorRect/studentjoin.hide()
	$ColorRect/studentyes.hide()
	$ColorRect/classroomstatus.show()
	$ColorRect/buts.position = Vector2(345.0, 45)
	$ColorRect/Account.hide()
	unroll_do()

func set_student_layout():
	set_base_size(Vector2(462.0,259))
	$ColorRect/studentjoin.show()
	$ColorRect/studentyes.hide()
	$ColorRect/classroomstatus.hide()
	$ColorRect/buts.position = Vector2(32, 96)
	$ColorRect/Account.show()

var parsed = {}
func _ready() -> void:
	if 0:#!ui.profile("teacher"):
		set_student_layout()
	else:
		set_teacher_layout()
	usr_update()
	glob.language_changed.connect(usr_update)
	$ColorRect/Control/Label.resize()
	update_lang()
	super() 
	if ui.profile("teacher"):
		$ColorRect/Control/Label2.text = "Teacher"
	else:
		$ColorRect/Control/Label2.text = "Student"

func unroll_do():
	$ColorRect/classroomstatus/list/ProceduralNodes.unroll()
	await get_tree().process_frame
	list_unroll.menu_show(list_unroll.position)
	list_unroll.state.holding = false
	list_unroll.unblock_input()
	#list.tune()

@onready var list_unroll = $ColorRect/classroomstatus/list


func _on_logout() -> void:
	#print("a")
	glob.reset_logged_in(true)
	can_go = true
	go_away()
	await quitting
	queue_free()


func _on_list_scroll_changed() -> void:
	glob.hide_all_menus()

@onready var lang_button = $ColorRect/buts/lang
func _on_lang_released() -> void:
	pass
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


func quit(data: Dictionary = {}):
	if not visible: return
	quitting.emit()
	#print(grid.current_dir)
	hide()
	if can_go:
		hide()
		ui.blur.self_modulate.a = 0
		emitter.res.emit(data)


func _quit_request():
	can_go = true
	await quitting
	queue_free()
	hide()
	#ui.splash("works", passed_data["from_but"], emitter, true)


func _resultate(data: Dictionary):
	#if "go_path" in data:
		#can_go = false
		#go_away()
		#await quitting
		#queue_free()
		#ui.splash_and_get_result("path_open", splashed_from, emitter, true, 
		#{"filter": ["nls"], "from_proj": splashed_from})
	#else:
		##var rand_dataset_id: int = randi_range(0,999999)
	emitter.res.emit(data)
	pass
	go_away()

func unroll(dup, args, kwargs):
	var output: Array[Node] = []
	for i in 8:
		var new: BlockComponent = dup.duplicate()
		new.placeholder = false
		new.show()
		var user = "miu"
		if len(user) > 13:
			user = user.substr(0,13)
			user += ".."
		var footer = "1/2 | Building" if i % 2 == 0 else "1/2 | Awaiting"
		# 12.7
		var total_letters: int = (list_unroll.size.x - list_unroll.arrangement_padding.x * 2) / 12.7
		new.text = user + " ".repeat(total_letters - len(user) - len(footer) - 2) + footer
		output.append(new)
	#print(output)
	return output

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

# 462.0 259
# 518.0.0 472.0
func _on_confirm_valid(input: String) -> void:
	
	target_size = Vector2(462,230.0)
	$ColorRect/studentjoin.hide()
	$ColorRect/studentyes.show()
	print("valid! ", input)


func classroom_create() -> void:
	target_size = Vector2(518,432.0)
	$ColorRect/classroomcr.hide()
	$ColorRect/classroomstatus.show()
	await glob.wait(0.2)
	unroll_do()

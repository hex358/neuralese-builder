extends SplashMenu

@onready var list = $ColorRect/list



func _process(delta: float) -> void:
	var prev_s = $ColorRect.scale
	super(delta)
	if !glob.is_vec_approx(prev_s, $ColorRect.scale):
		list.update_children_reveal()

var loaded_datasets = {}
var parsed = {}
func _ready() -> void:
	super()
	await get_tree().process_frame
	#$ColorRect/Label.text = cookies.get_username()
	ui.hourglass_on()
	#"name": "", "outputs": [], "input_format": {}}
	loaded_datasets = {"n/mnist": 
		{"name": "mnist", "outputs": [
		{"label": "digit", "x": 10, "datatype": "1d"}],
		"inputs": {"x": 28, "y": 28, "datatype": "2d"}}, 
	"n/iris": {"name": "iris", "outputs": [
		{"label": "digit", "x": 3, "datatype": "1d"}],
		"inputs": {"x": 28, "datatype": "1d"}}}#await glob.request_projects()
	#print(loaded_datasets)
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
	list.show_up(loaded_datasets)
	await get_tree().process_frame

func _resultate(data: Dictionary):
	emitter.res.emit(data)
	go_away()


func _on_list_child_button_release(button: BlockComponent) -> void:
	resultate({"ds": button.hint, "meta": loaded_datasets[button.hint]})


func _on_add() -> void:
	pass
	#can_go = false
	#go_away()
	#await quitting
	#queue_free()
	#ui.splash("project_create", splashed_from, emitter, true)



func _on_logout() -> void:
	pass # Replace with function body.

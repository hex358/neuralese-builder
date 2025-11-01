extends ColorRect
class_name TopBar

@export var menus: Dictionary[StringName, SubMenu] = {}

func _enter_tree() -> void:
	glob.fg = self

func _ready() -> void:
	glob.space_begin.y = size.y + position.y

func _process(delta: float) -> void:
	if size.x != glob.window_size.x-position.x*2:
		size.x = glob.window_size.x-position.x*2
		for m in menus:
			var menu = menus[m]
			menu.attachement_x = size.x - menu.size.x + 30
		#if glob.window_size.x < 50:
	if (glob.window_size.x) < 899:
		if not in_small_mode:
			var idx: int = -1
			for i in buts:
				idx += 1; i.text = ""
				i.resize(Vector2(41, i.base_size.y))
			buts[1]._wrapped_in.position = buts[2]._wrapped_in.position - Vector2(48,0)
			buts[0]._wrapped_in.position = buts[1]._wrapped_in.position - Vector2(48,0)
		in_small_mode = true
	else:
		if in_small_mode:
			for i in len(buts):
				#i.resize_after = 20
				buts[i].text = b_texts[i]
				buts[i].resize(b_szs[i])
				buts[i]._wrapped_in.position = b_poss[i]
		in_small_mode = false
	$Control3.position.x = max(size.x / 2, 420)
		
	#if Input.is_action_just_pressed("ui_accept"):
		#menus["a"].expand()
	#elif Input.is_action_just_pressed("down"):
		#menus["a"].close()
var in_small_mode: bool = false
@onready var buts: Array[BlockComponent] = [$Control/ai, $Control/export, $Control/login]
@onready var b_texts = [buts[0].text, buts[1].text, buts[2].text]
@onready var b_szs = [buts[0].size, buts[1].size, buts[2].size]
@onready var b_poss = [buts[0].position, buts[1].position, buts[2].position]

func get_scene_name():
	return $Label.text

func set_scene_name(name: String):
	$Label.text = name


var game_icon = preload("res://game_assets/icons/game.png")
var build_icon = preload("res://game_assets/icons/splines.png")
@onready var play = $Control/play
func _on_play_released() -> void:
	if play.hint == "play_tab": 
	#	play.hint = "build_tab"
	#	play.text_offset = Vector2(7,0)
#		play.text = " Make"
		#play.get_node("i").texture = build_icon
		#play.get_node("i").offset.x = -3
		glob.go_window("env")
	else:
		go_into_graph()

func go_into_graph():
#	play.hint = "play_tab"
#	play.text_offset = Vector2(7,0)
#	play.text = " Test"
#	play.get_node("i").texture = game_icon
	glob.go_window("graph")

var logged_in: bool = false

func set_login_state(name: String):
	logged_in = len(name) > 0
	pass
	#if name:
	#	login_btn.text = name
	#else:
	#	login_btn.text = "Login"


@onready var login_btn = $Control/login
func _on_login_released() -> void:
	#if !ui.is_splashed("login"):
	#	login_btn.in_splash = true
	
	if !logged_in:
		var a = await ui.splash_and_get_result("login", login_btn)
		if a:
			set_login_state("Works")
			ui.splash("works", login_btn)
		else:
			set_login_state("")
	else:
		ui.splash("works", login_btn)
	#else:
	#	login_btn.in_splash = false
	#	ui.get_splash("login").go_away()


func _on__released() -> void:
	ui.hourglass_on()
	var a = await glob.save(str(glob.get_project_id()))
	ui.hourglass_off()

@onready var axon = $Control/ai
func _on_ai_released() -> void:
	if !logged_in:
		var a = 1#await ui.splash_and_get_result("login", axon)
		if a:
			set_login_state("Works")
			ui.splash("ai_help", axon)
		else:
			set_login_state("")
	else:
		ui.splash("ai_help", axon)


func _on_ds_released() -> void:
	pass # Replace with function body.


func _on_graphs_released() -> void:
	go_into_graph()


func _on_datasets_released() -> void:
	glob.go_window("ds")


func _on_minigames_released() -> void:
	glob.go_window("env")

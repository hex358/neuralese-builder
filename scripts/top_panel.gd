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
	#if Input.is_action_just_pressed("ui_accept"):
		#menus["a"].expand()
	#elif Input.is_action_just_pressed("down"):
		#menus["a"].close()


var game_icon = preload("res://game_assets/icons/game.png")
var build_icon = preload("res://game_assets/icons/build.png")
@onready var play = $Control/play
func _on_play_released() -> void:
	if play.hint == "play_tab": 
		play.hint = "build_tab"
		play.text_offset = Vector2(7,0)
		play.text = " Make"
		play.get_node("i").texture = build_icon
		#play.get_node("i").offset.x = -3
		glob.go_window("env")
	else:
		play.hint = "play_tab"
		play.text_offset = Vector2(7,0)
		play.text = " Test"
		play.get_node("i").texture = game_icon
		glob.go_window("graph")

@onready var login_btn = $Control/login
func _on_login_released() -> void:
	if !ui.is_splashed("login"):
		login_btn.in_splash = true
		ui.splash("login")
	else:
		login_btn.in_splash = false
		ui.get_splash("login").go_away()

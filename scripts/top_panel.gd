extends ColorRect
class_name TopBar

@export var menus: Dictionary[StringName, SubMenu] = {}

func _ready() -> void:
	glob.space_begin.y = size.y + position.y

func _process(delta: float) -> void:
	if size.x != glob.window_size.x-position.x*2:
		size.x = glob.window_size.x-position.x*2
		for m in menus:
			var menu = menus[m]
			menu.attachement_x = size.x - menu.size.x + 30
	if Input.is_action_just_pressed("ui_accept"):
		menus["a"].expand()

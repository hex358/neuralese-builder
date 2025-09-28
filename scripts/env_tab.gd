extends TabWindow

@onready var list = $Control/scenes/list
func _ready() -> void:
	window_hide()
	await get_tree().process_frame
	glob.reset_menu_type(list, "list")
	$CanvasLayer.hide()
	glob.un_occupy(list, &"menu")
	glob.un_occupy(list, "menu_inside")

func _window_hide():
	process_mode = Node.PROCESS_MODE_DISABLED
	hide()
	glob.reset_menu_type(list, "list")
	$CanvasLayer.hide()
	glob.un_occupy(list, &"menu")
	glob.un_occupy(list, "menu_inside")
	

@onready var base_size = $Control.size
func _window_show():
	process_mode = Node.PROCESS_MODE_ALWAYS
	$Control.position.y = glob.space_begin.y
	$Control.size.y = glob.window_size.y - $Control.position.y
	$CanvasLayer.show()
	show()
	$Control/scenes/list.menu_show($Control/scenes/list.global_position)
	prev_win = Vector2()
	tick()

func _process(delta: float) -> void:
	tick()

var division_ratio: Array[float] = [0.2, 0.6]
var min_scenes_size: float = 150.0
var prev_win: Vector2 = Vector2()
func tick() -> void:
	if visible:
		var win: float = glob.window_size.x
		if prev_win != glob.window_size:
			$Control.position.y = glob.space_begin.y
			$Control.size.y = glob.window_size.y - $Control.position.y
			$Control/scenes.size.x = max(win * division_ratio[0], min_scenes_size)
			$Control/CodeEdit.position.x = $Control/scenes.size.x
			$Control/CodeEdit.size.x = win * division_ratio[1]
			$Control/view.position.x = $Control/CodeEdit.size.x + $Control/CodeEdit.position.x 
			$Control/view.size.x = win - $Control/view.position.x
			var view_size = $Control/view.size.x
			$Control/view/Label.resize()
			var rect = $Control/view/TextureRect
			rect.scale = Vector2.ONE *\
				view_size / float(rect.size.x)
			var scenes_size_y = $Control/scenes.size.y
			list.set_menu_size(($Control/scenes.size.x - list.position.x * 2 + 3) / list.scale.x, 
			(scenes_size_y - list.position.y - 10)/ list.scale.y)
		prev_win = glob.window_size
		

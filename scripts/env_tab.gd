extends TabWindow

func _ready() -> void:
	window_hide()

func _window_hide():
	process_mode = Node.PROCESS_MODE_DISABLED
	hide()
	glob.reset_menu_type($Control/scenes/detatch, "list")
	$CanvasLayer.hide()
	var list = $Control/scenes/list
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
var prev_win: Vector2 = Vector2()
func tick() -> void:
	if visible:
		var win: float = glob.window_size.x
		if prev_win != glob.window_size:
			$Control.position.y = glob.space_begin.y
			$Control.size.y = glob.window_size.y - $Control.position.y
			$Control/scenes.size.x = win * division_ratio[0]
			$Control/CodeEdit.position.x = $Control/scenes.size.x
			$Control/CodeEdit.size.x = win * division_ratio[1]
			$Control/view.position.x = $Control/CodeEdit.size.x + $Control/CodeEdit.position.x 
			$Control/view.size.x = win - $Control/view.position.x
			$Control/view/Label.resize()
			var scenes_size_y = $Control/scenes.size.y
			var list = $Control/scenes/list
			list.set_menu_size(($Control/scenes.size.x - list.position.x * 2) / list.scale.x, scenes_size_y - list.position.y * 2)
		prev_win = glob.window_size
		

extends TabWindow

@onready var list = $Control/scenes/list
func _ready() -> void:
	window_hide()
	await get_tree().process_frame
	glob.reset_menu_type(list, "list")
	$CanvasLayer.hide()
	glob.un_occupy(list, &"menu")
	glob.un_occupy(list, "menu_inside")
	border_rect_1 = ColorRect.new()
	border_rect_1.color.a = 0; border_rect_1.mouse_default_cursor_shape = Control.CURSOR_HSIZE
	add_child(border_rect_1)
	border_rect_2 = ColorRect.new()
	border_rect_2.color.a = 0; border_rect_2.mouse_default_cursor_shape = Control.CURSOR_HSIZE
	add_child(border_rect_2)
	
	repos()

func repos():
	border_rect_1.position = Vector2($Control/scenes.size.x - border_hit, 
	$Control/scenes.global_position.y)
	border_rect_1.size = Vector2(border_hit*2, $Control/scenes.size.y)
	border_rect_2.position = Vector2($Control/CodeEdit.size.x + $Control/CodeEdit.position.x, 
	$Control/scenes.global_position.y)
	border_rect_2.size = Vector2(border_hit, $Control/scenes.size.y)

var border_rect_1: ColorRect
var border_rect_2: ColorRect

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
	for i in 5:
		await get_tree().process_frame
	$Control/scenes/list.update_children_reveal()

func _process(delta: float) -> void:
	tick()

var division_ratio: Array[float] = [0.2, 0.6]
var min_scenes_size: float = 150.0
var max_scenes_size: float = 300.0
var min_game_size: float = 150.0
var max_game_size: float = 500.0
var prev_win: Vector2 = Vector2()
var border_hit = 10.0
var _dragging: int = -1
var _drag_anchor: float = 0.0

var code_hidden: bool = false
var max_game_size_ncode: float = 1800.0

func set_code_hidden(hidden: bool) -> void:
	code_hidden = hidden
	$Control/CodeEdit.visible = not hidden
	tick(true)
	ui.move_mouse(get_global_mouse_position())


func tick(force: bool = false) -> void:
	
	if not visible:
		return
	handle_division_drag()

	var win: float = glob.window_size.x
	if get_global_mouse_position().x > border_rect_2.position.x:
		$Control/CodeEdit.process_mode = Node.PROCESS_MODE_DISABLED
	else:
		$Control/CodeEdit.process_mode = Node.PROCESS_MODE_INHERIT
	if prev_win != glob.window_size or _dragging != -1 or force:
		$Control.position.y = glob.space_begin.y
		$Control.size.y = glob.window_size.y - $Control.position.y

		var scenes_w = clamp(win * division_ratio[0], min_scenes_size, max_scenes_size)

		var codeedit_target = win * division_ratio[1]
		var codeedit_w = 0.0 if code_hidden else codeedit_target

		var game_w = win - scenes_w - codeedit_w
		game_w = clamp(game_w, min_game_size, max_game_size_ncode if code_hidden else max_game_size)

		if not code_hidden:
			if codeedit_w < 0.0:
				var deficit = -codeedit_w
				game_w = max(min_game_size, game_w - deficit)
				codeedit_w = max(0.0, win - scenes_w - game_w)
				if codeedit_w < 0.0:
					codeedit_w = 0.0
					game_w = max(0.0, win - scenes_w)

		$Control/scenes.size.x = scenes_w
		$Control/CodeEdit.position.x = scenes_w
		$Control/CodeEdit.size.x = codeedit_w

		$Control/view.position.x = scenes_w + codeedit_w
		$Control/view.size.x = game_w

		var rect = $Control/view/TextureRect
		var game_window = $Control/view
		if rect.size.x > 0.0:
			rect.scale = Vector2.ONE * ((game_w-4) / float(rect.size.x))
		else:
			rect.scale = Vector2.ONE
		var max_y = game_window.size.y - 0.2 * (glob.window_size.y + 60)
		var x = 2
		var y = 0
		if rect.size.y * rect.scale.y > max_y:
			rect.scale = Vector2.ONE * max_y / rect.size.y
			x += game_w / 2 - rect.scale.x * rect.size.x / 2
			y += 15
			y -= glob.window_size.y * 0.02
		y += 15
		rect.position = Vector2(x, game_window.size.y / 2 - rect.scale.y * rect.size.y / 2 + y)


		var scenes_size_y = $Control/scenes.size.y
		list.set_menu_size(
			($Control/scenes.size.x - list.position.x * 2 + 3) / list.scale.x,
			(scenes_size_y - list.position.y - 10) / list.scale.y
		)
		
		if code_hidden:
			$Control/scenes.size.x += 2
		prev_win = glob.window_size
		repos()

	$Control/view/Label.resize()






func handle_division_drag() -> void:
	if not visible:
		return

	var win = glob.window_size.x
	if win <= 0.0:
		return

	var scenes_w = $Control/scenes.size.x
	var code_target = win * division_ratio[1]
	var game_w = clamp(win - scenes_w - code_target, min_game_size, max_game_size)
	var code_w = max(0.0, win - scenes_w - game_w)

	var border1 = scenes_w
	var border2 = scenes_w + code_w

	var mp = get_global_mouse_position()
	var ctrl = $Control
	var in_y = mp.y >= ctrl.position.y and mp.y <= (ctrl.position.y + ctrl.size.y)
	


	if glob.mouse_just_pressed and in_y:
		if abs(mp.x - border1) <= border_hit:
			_dragging = 0
			_drag_anchor = border1 - mp.x
		elif mp.x - border2 <= border_hit and mp.x > border2:
			_dragging = 1
			_drag_anchor = border2 - mp.x

	if glob.mouse_pressed and _dragging != -1:
		var new_x = clamp(mp.x + _drag_anchor, 0.0, win)

		if _dragging == 0:
			var new_scenes = clamp(new_x, min_scenes_size, max_scenes_size)
			var desired_code = max(0.0, border2 - new_scenes)

			var new_game = clamp(win - new_scenes - desired_code, min_game_size, max_game_size)
			var new_code = max(0.0, win - new_scenes - new_game)

			division_ratio[0] = new_scenes / win
			division_ratio[1] = new_code / win

		elif _dragging == 1:
			var desired_code = max(0.0, new_x - scenes_w)

			var new_game = clamp(win - scenes_w - desired_code, min_game_size, max_game_size)
			var new_code = max(0.0, win - scenes_w - new_game)

			division_ratio[0] = scenes_w / win
			division_ratio[1] = new_code / win

	if not glob.mouse_pressed and _dragging != -1:
		_dragging = -1
		_drag_anchor = 0.0


func _on__released() -> void:
	set_code_hidden(!code_hidden)


func get_current_game_name() -> String:
	return "Lua_process_1"


func get_current_game_code() -> String:
	return $Control/CodeEdit.text


func _on_run_released() -> void:
	var viewport = $Control/view/game
	var process = luas.create_process(get_current_game_name(), get_current_game_code())
	viewport.add_child(process)
	process.position.y = viewport.size.y

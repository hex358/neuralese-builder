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
var max_scenes_size: float = 300.0
var min_game_size: float = 150.0
var max_game_size: float = 500.0
var prev_win: Vector2 = Vector2()
func tick() -> void:
	if not visible:
		return
	handle_division_drag()

	var win: float = glob.window_size.x
	if prev_win != glob.window_size or _dragging != -1:
		$Control.position.y = glob.space_begin.y
		$Control.size.y = glob.window_size.y - $Control.position.y

		var scenes_w = clamp(win * division_ratio[0], min_scenes_size, max_scenes_size)

		var codeedit_target = win * division_ratio[1]

		var game_w = win - scenes_w - codeedit_target
		game_w = clamp(game_w, min_game_size, max_game_size)

		var codeedit_w = win - scenes_w - game_w

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

		# Keep existing scaling logic (safe-guard against zero)
		$Control/view/Label.resize()
		var rect = $Control/view/TextureRect
		if rect.size.x > 0.0:
			rect.scale = Vector2.ONE * (game_w / float(rect.size.x))
		else:
			rect.scale = Vector2.ONE

		# menu sizing for the scenes list stays consistent
		var scenes_size_y = $Control/scenes.size.y
		list.set_menu_size(
			($Control/scenes.size.x - list.position.x * 2 + 3) / list.scale.x,
			(scenes_size_y - list.position.y - 10) / list.scale.y
		)

		prev_win = glob.window_size


func handle_division_drag() -> void:
	if not visible:
		return

	var win = glob.window_size.x
	if win <= 0.0:
		return

	# Current “proposed” widths, respecting clamps (same logic style as your layout)
	var scenes_w = $Control/scenes.size.x
	#print(scenes_w)
	var code_target = win * division_ratio[1]
	var game_w = clamp(win - scenes_w - code_target, min_game_size, max_game_size)
	var code_w = max(0.0, win - scenes_w - game_w)

	var border1 = scenes_w                   # x of scenes↔code border
	var border2 = scenes_w + code_w          # x of code↔game border

	# Mouse state
	var mp = get_global_mouse_position()
	var ctrl = $Control
	var in_y = mp.y >= ctrl.position.y and mp.y <= (ctrl.position.y + ctrl.size.y)

	# Begin drag?
	if glob.mouse_just_pressed and in_y:
		if abs(mp.x - border1) <= BORDER_HIT:
			_dragging = 0
			_drag_anchor = border1 - mp.x
		elif abs(mp.x - border2) <= BORDER_HIT:
			_dragging = 1
			_drag_anchor = border2 - mp.x

	# Dragging
	if glob.mouse_pressed and _dragging != -1:
		var new_x = clamp(mp.x + _drag_anchor, 0.0, win)

		if _dragging == 0:
			# Move scenes border; try to keep the right border where it is
			var new_scenes = clamp(new_x, min_scenes_size, max_scenes_size)
			var desired_code = max(0.0, border2 - new_scenes)

			# Enforce game clamps by adjusting code width
			var new_game = clamp(win - new_scenes - desired_code, min_game_size, max_game_size)
			var new_code = max(0.0, win - new_scenes - new_game)

			# Update ratios
			division_ratio[0] = new_scenes / win
			division_ratio[1] = new_code / win

		elif _dragging == 1:
			# Move right border; scenes width fixed
			var desired_code = max(0.0, new_x - scenes_w)

			# Enforce game clamps by adjusting code width
			var new_game = clamp(win - scenes_w - desired_code, min_game_size, max_game_size)
			var new_code = max(0.0, win - scenes_w - new_game)

			# Update ratios
			division_ratio[0] = scenes_w / win
			division_ratio[1] = new_code / win

	# End drag
	if not glob.mouse_pressed and _dragging != -1:
		_dragging = -1
		_drag_anchor = 0.0



const BORDER_HIT = 6.0  # px, clickable width around borders

var _dragging: int = -1  # -1 none, 0 = left border (scenes↔code), 1 = right border (code↔game)
var _drag_anchor: float = 0.0  # mouse-to-border offset to avoid snapping

		

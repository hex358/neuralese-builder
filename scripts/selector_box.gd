extends ColorRect

var selecting: bool = false
var select_origin: Vector2 = Vector2()

var target_pos: Vector2
var target_size: Vector2
@export var lerp_speed: float = 15.0  # higher = snappier

func _ready() -> void:
	hide()
	target_pos = position
	target_size = size

var q: bool = false
func _process(delta: float) -> void:
	#print(graphs.conning())
	if not graphs.conning():
		q = true
	else:
		selecting = false
		hide()
		ui.selecting_box = false
		q = false
	if glob.curr_window != "graph":
		hide()
	if q and not ui.active_splashed() and glob.mouse_just_pressed and not glob.is_graph_inside() and not glob.is_occupied(self, "menu_inside") \
	and not graphs.dragged and not graphs.conning() and not ui.get_focus() and get_global_mouse_position().y > glob.space_begin.y:
		select_origin = get_global_mouse_position()
		selecting = true
		ui.selecting_box = true
		show()
		position = select_origin
		size = Vector2.ZERO

	if selecting:
		if not glob.mouse_pressed:
			selecting = false
			hide()
			ui.selecting_box = false
			return

		var curr = get_global_mouse_position()
		curr.y = max(curr.y, glob.space_begin.y)
		var diff = curr - select_origin

		# update target_size and target_pos
		if diff.x >= 0:
			target_size.x = diff.x
			target_pos.x = select_origin.x
		else:
			target_size.x = -diff.x
			target_pos.x = curr.x

		if diff.y >= 0:
			target_size.y = diff.y
			target_pos.y = select_origin.y
		else:
			target_size.y = -diff.y
			target_pos.y = curr.y

	# lerp position & size toward targets every frame
	position = position.lerp(target_pos, lerp_speed * delta)
	size = size.lerp(target_size, lerp_speed * delta)
	
	if (glob.mouse_alt_just_pressed or glob.mouse_just_pressed) and !visible and not glob.get_occupied("graph"):
		graphs.unselect_all()
	
	if visible:
		var raw = get_global_rect()
		var p1 = glob.canvas_to_world(raw.position)
		var p2 = glob.canvas_to_world(raw.position + raw.size)
		var rect = Rect2(p1, p2 - p1).abs()  # always positive size

		for g in graphs._graphs:
			var target = graphs._graphs[g].rect.get_global_rect().abs()
			if rect.intersects(target):
				graphs._graphs[g].select()
			else:
				graphs._graphs[g].unselect()
	#else:
		#graphs.unselect_all()

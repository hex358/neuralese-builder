extends Control
@export var _unit: Control
@export var grid_padding: float
@export var grid: Vector2


func _draw():
	if not _unit: return
	var chunk_color = Color.WHITE
	chunk_color.a = 1.0
	
	# Draw vertical lines every 3 cells
	for x in range(0, grid.x + 1):
		if x % 3 == 0:
			var start_pos = Vector2(x * (_unit.size.x + grid_padding), 0)
			var end_pos = Vector2(x * (_unit.size.x + grid_padding), grid.y *  (_unit.size.x + grid_padding))
			draw_line(start_pos, end_pos, chunk_color, 2.0)
	
	# Draw horizontal lines every 3 cells
	for y in range(0, grid.y + 1):
		if y % 3 == 0:
			var start_pos = Vector2(0, y * (_unit.size.x + grid_padding))
			var end_pos = Vector2(grid.x * (_unit.size.x + grid_padding), y * (_unit.size.x + grid_padding))
			draw_line(start_pos, end_pos, chunk_color, 2.0)

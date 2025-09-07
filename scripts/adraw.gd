extends Control
@export var _unit: Control
@export var grid_padding: float
@export var grid: Vector2


func _draw():
	if not _unit: return
	var chunk_color = Color.WHITE
	
	for x in range(0, grid.x + 1):
		if x % 3 == 0 or x == grid.x:
			var start_pos = Vector2(x * (_unit.size.x + grid_padding), 0)
			start_pos.y -= 0.75
			var end_pos = Vector2(x * (_unit.size.x + grid_padding), grid.y *  (_unit.size.x + grid_padding))
			end_pos.x -= 0.75
			start_pos.x -= 0.75
			draw_line(start_pos, end_pos, chunk_color, 1.5)
	
	for y in range(0, grid.y + 1):
		if y % 3 == 0 or y == grid.y:
			var start_pos = Vector2(0, y * (_unit.size.x + grid_padding))
			start_pos.x -= 0.75
			var end_pos = Vector2(grid.x * (_unit.size.x + grid_padding), y * (_unit.size.x + grid_padding))
			end_pos.y -= 0.75
			start_pos.y -= 0.75
			draw_line(start_pos, end_pos, chunk_color, 1.5)

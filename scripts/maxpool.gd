extends Conv2D

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var active = {}

func _after_ready():
	super()
	rng.seed = randi()

func _after_process(delta: float):
	super(delta)
	recompute_biggest_size_possible()
	fade_process(delta)

var cr = Vector2i()
func _grid_visualised(columns: int, rows: int):
	$Control.position = offset
	$Control.grid_padding = grid_padding
	$Control.grid = Vector2i(columns, rows)
	$Control._unit = _unit
	$Control.queue_redraw()  # Added this line
	cr = Vector2i(columns, rows)




func _proceed_hold() -> bool:
	return true

func _cell_added(x: int, y: int):
	# Find which 3x3 chunk this cell belongs to
	var chunk_x = x / 3
	var chunk_y = y / 3
	
	# Find center of this chunk
	var center_x = chunk_x * 3 + 1  # Center is at position 1 within chunk
	var center_y = chunk_y * 3 + 1
	
	# Use chunk position as seed for consistent randomness per chunk
	rng.seed = chunk_x * 100 + chunk_y
	
	# Pick winner near center (center ± 1)
	var winner_x = min(center_x + rng.randi_range(-1, 1), cr.x-1)
	var winner_y = min(center_y + rng.randi_range(-1, 1), cr.y-1)
	
	# Highlight if this is the winner
	if x == winner_x and y == winner_y:
		_fading_in[Vector2i(x,y)] = 1.0
	else:
		_fading_in[Vector2i(x,y)] = 0.3

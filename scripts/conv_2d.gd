extends BaseNeuronLayer

@export var group_size: int = 5:
	set(v):
		group_size = v
		set_grid(grid.x, grid.y)

@export var grid: Vector2i = Vector2i(1,1):
	set(v):
		grid = v
		set_grid(grid.x, grid.y)

@export var grid_padding: float = 5.0:
	set(v):
		grid_padding = v
		set_grid(grid.x, grid.y)

@export var offset: Vector2 = Vector2():
	set(v):
		offset = v
		set_grid(grid.x, grid.y)

@export var size_add_vec: Vector2 = Vector2():
	set(v):
		size_add_vec = v
		set_grid(grid.x, grid.y)

var current_units: Array[Control] = []

func useful_properties() -> Dictionary:
	var conf = {"activation": "none"}
	if input_keys[0].inputs:
		conf["activation"] = input_keys[0].inputs.keys()[0].origin.parent_graph.selected_activation
	return {
		"neuron_count": grid.x * grid.y,
		"config": conf,
		"cache_tag": str(graph_id)
	}

@onready var base_output_offset = $o.position - rect.size
func _size_changed():
	$o.position = base_output_offset + rect.size

func get_unit(kw: Dictionary) -> Control:
	return _unit.duplicate()

func set_grid(x: int, y: int):
	if not is_node_ready(): await ready
	visualise_grid(ceil(x / float(group_size)), ceil(y / float(group_size)))

func visualise_grid(columns: int, rows: int):
	var needed_count = columns * rows
	var current_count = current_units.size()
	
	while current_units.size() < needed_count:
		var new_unit = get_unit({})
		current_units.append(new_unit)
		add_child(new_unit)
	
	while current_units.size() > needed_count:
		var excess_unit = current_units.pop_back()
		excess_unit.queue_free()

	for i in range(needed_count):
		var row = i / columns
		var col = i % columns
		
		var unit = current_units[i]
		unit.position.x = col * (unit.size.x + padding) + offset.x
		unit.position.y = row * (unit.size.y + padding) + offset.y
	target_size = rows * (_unit.size.y + padding) + size_add_vec.y + offset.y
	rect.size.x = columns * (_unit.size.x + padding) + offset.x + size_add_vec.x

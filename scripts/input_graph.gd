extends Graph

func _can_drag() -> bool:
	return !$TextureRect.mouse_inside

func get_raw_values():
	var width: int = $TextureRect.image.get_width()
	var total: int = $TextureRect.image.get_width() * $TextureRect.image.get_height()
	var res = []
	for y in width:
		var row = []
		for x in width:
			row.append($TextureRect.get_pixel(Vector2(x,y)).r)
		res.append(row)
	return res

func _just_connected(who: Connection, to: Connection):
	#if to.parent_graph.server_typename == "Flatten":
	#	to.parent_graph.set_count(cfg.rows * cfg.columns)
	if graphs._input_origin_graph == null:
		graphs._input_origin_graph = self
	graphs.push_2d(28, 28, to.parent_graph)

func _just_disconnected(who: Connection, to: Connection):
	if graphs._input_origin_graph == self:
		graphs._input_origin_graph = null
	graphs.unpush_2d(to.parent_graph)

func _useful_properties() -> Dictionary:
	#print("A")
	return {"raw_values": get_raw_values(), "config": {"rows": 28, "columns": 28}}


var image_dims = Vector2i(1,1)
func _after_ready() -> void:
	super()
	image_dims = Vector2i($TextureRect.image.get_width(), $TextureRect.image.get_height())

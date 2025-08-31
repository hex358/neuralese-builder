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

func _useful_properties() -> Dictionary:
	#print("A")
	return {"raw_values": get_raw_values(), "config": {"rows": 28, "columns": 28}}

func _just_connected(who: Connection, to: Connection):
	(graphs.reach(self))
	#if to.parent_graph is NeuronLayer:
		#to.parent_graph.neurons_fixed = true
		#to.parent_graph.push_neuron_count($TextureRect.image.get_width() * $TextureRect.image.get_height())

func _just_disconnected(who: Connection, from: Connection):
	if from.parent_graph is NeuronLayer:
		from.parent_graph.neurons_fixed = false
	#	to.parent_graph.push_neuron_count($TextureRect.image.size.x * $TextureRect.image.size.y)

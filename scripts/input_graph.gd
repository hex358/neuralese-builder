extends Graph

func _can_drag() -> bool:
	return !$TextureRect.mouse_inside

func _just_connected(who: Connection, to: Connection):
	if to.parent_graph is NeuronLayer:
		to.parent_graph.neurons_fixed = true
		to.parent_graph.push_neuron_count($TextureRect.image.get_width() * $TextureRect.image.get_height())

func _just_disconnected(who: Connection, from: Connection):
	if from.parent_graph is NeuronLayer:
		from.parent_graph.neurons_fixed = false
	#	to.parent_graph.push_neuron_count($TextureRect.image.size.x * $TextureRect.image.size.y)

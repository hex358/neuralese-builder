extends DynamicGraph
func push_values(values: Array):
	var minimal = values.min()
	var maximal = values.max()
	
	for unit in len(values):
		units[unit].set_weight((values[unit] - minimal) / float(maximal - minimal), 
		str(glob.cap(values[unit], 1)))


func _after_process(delta: float):
	super(delta)
	push_values(range(len(units)))

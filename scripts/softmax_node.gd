extends Graph

func _useful_properties() -> Dictionary:
	var is_output: bool = false
	var desc = get_first_descendants()
	is_output = desc.size() == 0
	for i in desc:
		if i.is_head:
			is_output = true
	return {"config":{
		"role": "output" if is_output else "none"}}

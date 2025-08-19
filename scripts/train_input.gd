extends Graph

func _useful_properties() -> Dictionary:
	return {
		"config":{ 
			"optimizer": "sgd", "target": [0.0, 0.0, 0.0, 0.0], "loss": "mse"
			}
			}

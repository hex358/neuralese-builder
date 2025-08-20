extends Graph

func _useful_properties() -> Dictionary:
	return {
		"config":{ 
			"optimizer": "adam", "target": [0.0, 0.0, 0.0, 0.0], "loss": "cross_entropy"
			}
			}

func _exit_tree() -> void:
	super()

func _after_ready():
	super()

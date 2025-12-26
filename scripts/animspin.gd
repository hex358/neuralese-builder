extends Node
class_name AnimSpin

@onready var parent = get_parent()
func play():
	pass

var t_play: float = 0.0; var queue_play: bool = false
signal cycle_made
func _process(delta: float) -> void:
	if queue_play:
		t_play += delta
		

func play_once():
	pass

func stop():
	pass

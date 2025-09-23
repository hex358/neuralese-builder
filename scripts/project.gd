extends Node2D


func _ready() -> void:
	pass

func train_state_received(bytes: PackedByteArray):
	var jsonified = bytes.get_string_from_utf8()
	var dict = JSON.parse_string(jsonified)
	if not "phase" in dict: return
	if dict["phase"] == "state":
		var data = dict["data"]["data"]
		var loss = data["val_loss"]
		graphs._training_head.push_acceptance(1.0-loss, 0.0)

func _process(delta: float) -> void:
	pass
	if Input.is_action_just_pressed("ui_accept"):
		var compressed = glob.compress_dict_gzip({"train": 1, 
		"session": "neriqward", 
		"graph": graphs.get_syntax_tree(graphs._input_origin_graph)})
		#print("fjfjf")
		var a = sockets.connect_to("ws/train", train_state_received)
			
		a.connected.connect(func():
			a.send(compressed))
		a.closed.connect(print)
		

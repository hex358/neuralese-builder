extends Node2D


func _ready() -> void:
	pass
	#var a = sockets.connect_to("ws://localhost:8000/ws/a9e177e4283d44b89b3635c9ba43406e", func(x: PackedByteArray):
	#	print(x.get_string_from_utf8()))
		
	#a.connected.connect(func():
	#	var graph_payload = {"layers": [784, 256, 10]}
	#	a.send_json(graph_payload))
	#a.closed.connect(print)
		

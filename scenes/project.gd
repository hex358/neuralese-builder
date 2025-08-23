extends Node2D

func _ready() -> void:
	var ws = $WebSocketEasy
	$WebSocketEasy.connect_to("ws://localhost:8000/ws/e4ffa2f59a6f4555aae7110fc6147b6b", func(x: PackedByteArray):
		print(x.get_string_from_utf8()))
	#ws.connected.connect(func():
	#	var graph_payload = {"layers": [784, 256, 10]}
	#	ws.send_json(graph_payload))
		

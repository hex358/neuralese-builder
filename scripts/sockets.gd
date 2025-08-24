extends Node

var _conns: Dictionary = {}	# { SocketConnection: true }

func _process(_dt: float) -> void:
	var to_del: Array = []

	for conn in _conns.keys():
		if conn == null:
			to_del.append(conn)
			continue
		conn._poll()
		if conn.is_closed():
			to_del.append(conn)

	for c in to_del:
		_conns.erase(c)

func connect_to(url: String, on_packet: Callable = Callable()) -> SocketConnection:
	var c = SocketConnection.new(url)
	_conns[c] = true
	if on_packet.is_valid():
		c.packet.connect(on_packet)
	return c

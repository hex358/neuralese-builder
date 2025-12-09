extends Node

var _conns: Dictionary = {}	# { SocketConnection: true }
#"wss://localhost:8000/"
var connection_prefix: String = glob.get_root_ws()#"wss://neriqward.360hub.ru/api/"

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



func connect_to(url: String, on_packet: Callable = Callable(), headers: Dictionary = {}) -> SocketConnection:
	var c = SocketConnection.new(connection_prefix + url, true, headers)
	_conns[c] = true
	if on_packet.is_valid():
		c.packet.connect(on_packet)
	return c

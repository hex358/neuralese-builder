extends Node
class_name WebSocketEasy

signal connected
signal closed(code: int, reason: String, clean: bool)

var _ws: WebSocketPeer = WebSocketPeer.new()
var _on_message: Callable = Callable()
var _last_state: int = WebSocketPeer.STATE_CLOSED
var _queue: Array = []

func connect_to(url: String, on_message: Callable = Callable()) -> void:
	_on_message = on_message
	var err := _ws.connect_to_url(url)
	if err != OK:
		push_error("socket connect_to_url failed: %s" % err)
	set_process(true)

func close() -> void:
	match _ws.get_ready_state():
		WebSocketPeer.STATE_CONNECTING, WebSocketPeer.STATE_OPEN:
			_ws.close()
		_:
			pass
	set_process(false)

func send_json(v: Variant) -> void:
	var text = JSON.stringify(v)
	if _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.send_text(text)
	else:
		_queue.append({"text": text})

func _process(_dt: float) -> void:
	_ws.poll()

	var state := _ws.get_ready_state()
	if state != _last_state:
		if state == WebSocketPeer.STATE_OPEN:
			# Flush queued outgoing messages.
			for item in _queue:
				_ws.send_text(item)
			_queue.clear()
			connected.emit()
		elif state == WebSocketPeer.STATE_CLOSED:
			var code := _ws.get_close_code()
			var reason := _ws.get_close_reason()
			closed.emit(code, reason, code != -1)
			set_process(false)
		_last_state = state

	if state == WebSocketPeer.STATE_OPEN:
		while _ws.get_available_packet_count() > 0:
			var data: PackedByteArray = _ws.get_packet()
			var payload: Variant = data
			if _on_message.is_valid():
				_on_message.call(payload)

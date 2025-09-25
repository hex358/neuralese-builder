extends Node

const api_url: String = "http://localhost:8000/"

# ---------- tiny handle that exposes a statically-declared signal ----------
class RequestHandle:
	extends RefCounted
	signal completed(result: Dictionary)  # you can: await handle.completed  OR  handle.completed.connect(...)
	var id: StringName = ""

# ---------- headers ----------
func get_headers() -> PackedStringArray:
	var os_name = OS.get_name()
	var os_version = OS.get_version()
	var gvi = Engine.get_version_info()
	var project_name = ProjectSettings.get_setting("application/config/name", "UnnamedProject")
	var project_version = ProjectSettings.get_setting("application/config/version", "dev")

	var ua_string = "User-Agent: %s/%s Godot/%s.%s.%s-%s (%s %s)" % [
		project_name, project_version,
		gvi.major, gvi.minor, gvi.patch, gvi.status,
		os_name, os_version
	]

	var headers = PackedStringArray()
	headers.append(ua_string)
	headers.append("Content-Type: application/json")
	return headers

var _headers: PackedStringArray

func _enter_tree() -> void:
	_headers = get_headers()

# ---------- PUBLIC API: return Signal, not data ----------
func POST(page: String, data, bytes: bool = false) -> Signal:
	return _request(api_url + page, data, HTTPClient.METHOD_POST, bytes)

func GET(page: String) -> Signal:
	return _request(api_url + page, {}, HTTPClient.METHOD_GET, false)

# ---------- core request (signal-first) ----------
func _request(address: String, request_body, method: int, bytes: bool = false) -> Signal:
	# per-request handle with a static signal (easy to await / connect)
	var handle = RequestHandle.new()
	handle.id = "req_%s" % str(Time.get_ticks_usec())

	# also expose a dynamic signal on *this* node for string-based connections
	# e.g. connect("http_done_<id>", ...) if you prefer dynamic names
	add_user_signal("http_done_%s" % handle.id, ["result"])

	var req = HTTPRequest.new()
	req.timeout = 3.0
	req.use_threads = true
	add_child(req)

	# kick the request
	var err: int
	if bytes:
		err = req.request_raw(address, _headers, method, request_body)
	else:
		var body = JSON.stringify(request_body, "", true, true)
		err = req.request(address, _headers, method, body)

	# immediate failure (bad URL, etc.)
	if err != OK:
		var fail = {"ok": false, "error": err, "code": 0, "body": PackedByteArray(), "address": address, "id": handle.id}
		# emit next frame so caller can reliably connect/await
		call_deferred("_emit_http_done", handle, fail)
		return handle.completed

	# normal completion path
	req.request_completed.connect(func(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
		var payload = {
			"ok": response_code >= 200 and response_code < 300,
			"result": result,
			"code": response_code,
			"headers": headers,
			"body": body,
			"address": address,
			"id": handle.id
		}
		_emit_http_done(handle, payload)
		req.queue_free()
	)

	return handle.completed

# helper to emit both the handle signal and the dynamic add_user_signal one
func _emit_http_done(handle: RequestHandle, payload: Dictionary) -> void:
	# emit on the handle (best for: await handle.completed)
	handle.emit_signal("completed", payload)

	# emit dynamic, per-request signal name on this node (for string-based connections)
	var dyn = "http_done_%s" % handle.id
	emit_signal(dyn, payload)

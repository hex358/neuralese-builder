extends Node
class_name WebAPI

const api_url: String = "http://localhost:8000/"

func _ready() -> void:
	add_child(Transcriber.new())

class RequestHandle:
	extends RefCounted
	signal completed(result: Dictionary)
	var id: StringName = ""

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

	var cookie_header = cookies.get_header()
	if cookie_header != "":
		headers.append(cookie_header)

	return headers


func _enter_tree() -> void:
	pass

func POST(page: String, data, bytes: bool = false) -> Signal:
	return _request(api_url + page, data, HTTPClient.METHOD_POST, bytes)

func GET(page: String, args: Dictionary = {}) -> Signal:
	var full_url = api_url + page
	if not args.is_empty():
		full_url += "?" + _encode_query(args)
	return _request(full_url, {}, HTTPClient.METHOD_GET, false)

func _encode_query(params: Dictionary) -> String:
	var parts: PackedStringArray = []
	for k in params.keys():
		var key = String(k).uri_encode()
		var val = String(params[k]).uri_encode()
		parts.append("%s=%s" % [key, val])
	return "&".join(parts)

func _request(address: String, request_body, method: int, bytes: bool = false) -> Signal:
	var handle = RequestHandle.new()
	handle.id = "req_%s" % str(Time.get_ticks_usec())

	add_user_signal("http_done_%s" % handle.id, ["result"])

	var req = HTTPRequest.new()
	req.timeout = 3.0
	req.use_threads = true
	add_child(req)

	var err: int
	if bytes:
		err = req.request_raw(address, get_headers(), method, request_body)
	else:
		var body = JSON.stringify(request_body, "", true, true)
		err = req.request(address, get_headers(), method, body)

	if err != OK:
		var fail = {"ok": false, "error": err, "code": 0, "body": PackedByteArray(), "address": address, "id": handle.id}
		call_deferred("_emit_http_done", handle, fail)
		return handle.completed

	req.request_completed.connect(func(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
		cookies.update_from_headers(headers)
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

func _emit_http_done(handle: RequestHandle, payload: Dictionary) -> void:
	handle.emit_signal("completed", payload)
	var dyn = "http_done_%s" % handle.id
	emit_signal(dyn, payload)

extends Node

const api_url: String = "http://localhost:8000/"

var _http_request: HTTPRequest
var _headers: PackedStringArray = PackedStringArray()

func get_headers() -> PackedStringArray:
	var os_name = OS.get_name()
	var os_version = OS.get_version()
	var godot_version = Engine.get_version_info()
	var project_name = ProjectSettings.get_setting("application/config/name", "UnnamedProject")
	var project_version = ProjectSettings.get_setting("application/config/version", "dev")

	var ua_string = "User-Agent: %s/%s Godot/%s.%s.%s-%s (%s %s)" % [
		project_name,
		project_version,
		godot_version.major,
		godot_version.minor,
		godot_version.patch,
		godot_version.status,
		os_name,
		os_version
	]

	return PackedStringArray([ua_string])

func _enter_tree() -> void:
	_http_request = HTTPRequest.new()
	_headers = get_headers()
	add_child(_http_request)

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	pass

func POST(page: String, data, bytes: bool = false) -> Dictionary:
	return await _request(api_url + page, data, HTTPClient.METHOD_POST, bytes)

func GET(page: String) -> Dictionary:
	return await _request(api_url + page, {}, HTTPClient.METHOD_GET, false)

signal res_dict_assigned(dict: Dictionary)
func _request(address: String, request_body, method: int, bytes: bool = false) -> Dictionary:
	var request = HTTPRequest.new()
	request.timeout = 3.0
	request.use_threads = true
	add_child(request)
	if !bytes:
		var body = JSON.stringify(request_body, "", true, true)
		request.request(address, _headers, method, body)
	else:
		request.request_raw(address, _headers, method, request_body)
	var res_dict: Dictionary = {}
	var res_call = func(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
		res_dict_assigned.emit({
			"code": response_code,
			"body": body
		})
	request.request_completed.connect(res_call)
	return (await res_dict_assigned)

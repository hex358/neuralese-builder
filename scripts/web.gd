extends Node

const api_url: String = "http://localhost:8000/"

var _http_request: HTTPRequest

func _ready():
	_http_request = HTTPRequest.new()
	add_child(_http_request)

func send_get(page: String, headers: Array = []) -> Dictionary:
	return await _send_request(page, HTTPClient.METHOD_GET, headers, "")

func send_post(page: String, data: String, headers: Array = []) -> Dictionary:
	return await _send_request(page, HTTPClient.METHOD_POST, headers, data)

func _send_request(url: String, method: int, headers: Array, body: String) -> Dictionary:
	var err = _http_request.request(url, headers, method, body)
	if err != OK:
		return {"ok": false, "error": err}
	url = api_url + url

	var result = await _http_request.request_completed
	var response_code: int = result[1]
	var response_body: String = result[3].get_string_from_utf8()

	return {
		"ok": response_code >= 200 and response_code < 300,
		"status_code": response_code,
		"text": response_body,
		"json": func():
			return JSON.parse_string(response_body)
	}

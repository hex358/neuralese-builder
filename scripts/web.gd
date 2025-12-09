extends Node
class_name WebAPI
"https://neriqward.360hub.ru/api/"
"http://localhost:8000/"
var api_url: String = glob.get_root_http()
const _READ_CHUNK: int = 64 * 1024
const _CONNECT_TIMEOUT_S: float = 3.0
const _IO_YIELD_US: int = 500

var transcriber: Transcriber
func _ready() -> void:
	transcriber = Transcriber.new()
	add_child(transcriber)

class RequestHandle:
	extends RefCounted
	signal completed(result: Dictionary)
	signal on_chunk(chunk: PackedByteArray)
	var id: StringName = ""

# ───────────────────────────────────────────────
# Public API (identical to old)
# ───────────────────────────────────────────────
func POST(page: String, data, bytes: bool = false, obj: bool = false):
	return _request(api_url + page, data, HTTPClient.METHOD_POST, bytes, obj)

func GET(page: String, args: Dictionary = {}, obj: bool = false):
	var full_url = api_url + page
	if not args.is_empty():
		full_url += "?" + _encode_query(args)
	return _request(full_url, {}, HTTPClient.METHOD_GET, false, obj)

# ───────────────────────────────────────────────
# Headers
# ───────────────────────────────────────────────
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
	headers.append("Accept: */*")

	var cookie_header = cookies.get_header()
	if cookie_header != "":
		headers.append(cookie_header)

	return headers

# ───────────────────────────────────────────────
# Internal
# ───────────────────────────────────────────────
func _encode_query(params: Dictionary) -> String:
	var parts: PackedStringArray = []
	for k in params.keys():
		var key = String(k).uri_encode()
		var val = String(params[k]).uri_encode()
		parts.append("%s=%s" % [key, val])
	return "&".join(parts)

func _request(address: String, request_body, method: int, bytes: bool = false, obj: bool = false):
	var handle := RequestHandle.new()
	handle.id = "req_%s" % str(Time.get_ticks_usec())

	var thread := Thread.new()
	_threads.append(thread)

	var payload := {
		"address": address,
		"method": method,
		"body": request_body,
		"bytes": bytes,
		"headers": get_headers(),
		"handle": handle,
	}
	thread.start(Callable(self, "_http_thread").bind(payload, thread))

	if obj:
		return handle
	return handle.completed

static func _split_url(url: String) -> Dictionary:
	var ssl := false
	var rest := url
	if rest.begins_with("https://"):
		ssl = true
		rest = rest.substr(8)
	elif rest.begins_with("http://"):
		ssl = false
		rest = rest.substr(7)

	var slash := rest.find("/")
	var host_port := rest if slash == -1 else rest.substr(0, slash)
	var path := "/" if slash == -1 else rest.substr(slash)
	var host := host_port
	var port := 443 if ssl else 80
	var colon := host_port.find(":")
	if colon != -1:
		host = host_port.substr(0, colon)
		port = int(host_port.substr(colon + 1))
	return {"ssl": ssl, "host": host, "port": port, "path": path}

# ───────────────────────────────────────────────
# Background thread using HTTPClient
# ───────────────────────────────────────────────
var _threads: Array[Thread] = []

func _http_thread(p: Dictionary, thread: Thread) -> void:
	var handle: RequestHandle = p.handle
	var address: String = p.address
	var method: int = p.method
	var req_body = p.body
	var send_bytes: bool = p.bytes
	var hdrs: PackedStringArray = p.headers

	var url := _split_url(address)
	var client := HTTPClient.new()
	client.blocking_mode_enabled = false

	var has_host := false
	for h in hdrs:
		if h.to_lower().begins_with("host:"):
			has_host = true
			break
	if not has_host:
		hdrs.append("Host: %s" % url.host)

	var body_data: PackedByteArray = PackedByteArray()
	if send_bytes:
		body_data = req_body
	else:
		body_data = (JSON.stringify(req_body, "", true, true)).to_utf8_buffer()

	var start := Time.get_ticks_msec()
	var tls_opts: TLSOptions = null
	if url.ssl:
		tls_opts = TLSOptions.client()  # standard client TLS options

	var err := client.connect_to_host(url.host, url.port, tls_opts)



	if err != OK:
		call_deferred("_emit_http_done", handle, {
			"ok": false, "error": err, "code": 0, "body": PackedByteArray(),
			"address": address, "id": handle.id
		})
		call_deferred("_cleanup_thread", thread)
		return

	while client.get_status() in [HTTPClient.STATUS_CONNECTING, HTTPClient.STATUS_RESOLVING]:
		client.poll()
		if float(Time.get_ticks_msec() - start) / 1000.0 > _CONNECT_TIMEOUT_S:
			call_deferred("_emit_http_done", handle, {
				"ok": false, "error": ERR_TIMEOUT, "code": 0, "body": PackedByteArray(),
				"address": address, "id": handle.id
			})
			call_deferred("_cleanup_thread", thread)
			return
		OS.delay_usec(_IO_YIELD_US)
	
	var is_get = p.method == HTTPClient.METHOD_GET
	if send_bytes:
		err = client.request_raw(method, url.path, hdrs, body_data if not is_get else PackedByteArray())
	else:
		err = client.request(method, url.path, hdrs, body_data.get_string_from_utf8() if not is_get else "")
	if err != OK:
		call_deferred("_emit_http_done", handle, {
			"ok": false, "error": err, "code": 0, "body": PackedByteArray(),
			"address": address, "id": handle.id
		})
		call_deferred("_cleanup_thread", thread)
		return

	while client.get_status() == HTTPClient.STATUS_REQUESTING:
		client.poll()
		OS.delay_usec(_IO_YIELD_US)

	var response_code := client.get_response_code()
	var resp_headers: PackedStringArray = client.get_response_headers()
	call_deferred("_cookies_from_headers", resp_headers)

	var accum := PackedByteArray()
	while client.get_status() == HTTPClient.STATUS_BODY:
		client.poll()
		var chunk := client.read_response_body_chunk()
		if chunk.size() > 0:
			call_deferred("_emit_http_chunk", handle, chunk)
			accum.append_array(chunk)
		else:
			OS.delay_usec(_IO_YIELD_US)

	call_deferred("_emit_http_done", handle, {
		"ok": response_code >= 200 and response_code < 300,
		"result": OK,
		"code": response_code,
		"headers": resp_headers,
		"body": accum,
		"address": address,
		"id": handle.id
	})
	call_deferred("_cleanup_thread", thread)

# ───────────────────────────────────────────────
# Main-thread emitters and cleanup
# ───────────────────────────────────────────────
func _emit_http_chunk(handle: RequestHandle, chunk: PackedByteArray) -> void:
	handle.emit_signal("on_chunk", chunk)

func _emit_http_done(handle: RequestHandle, payload: Dictionary) -> void:
	handle.emit_signal("completed", payload)
	var dyn = "http_done_%s" % handle.id
	#semit_signal(dyn, payload)

func _cookies_from_headers(headers: PackedStringArray) -> void:
	cookies.update_from_headers(headers)
func _cleanup_thread(thread: Thread) -> void:
	if thread == null:
		return
	# This function is always called via call_deferred() → main thread.
	if thread.is_started():
		thread.wait_to_finish()
	_threads.erase(thread)

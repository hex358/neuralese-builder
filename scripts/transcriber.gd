
extends WebAPI
class_name Transcriber

const AUDIO_SAMPLE_RATE: int = 16000
const AUDIO_DTYPE: String = "float32" # or "int16" depending on your buffer type

func _ready() -> void:
	var res = await transcribe_audio_file("res://sturkturu.wav").completed
	print(res)

## High-level API
func transcribe_audio_file(path: String) -> RequestHandle:
	"""
	Reads a .wav or .raw PCM file from disk and uploads to /transcribe_file.
	Returns a RequestHandle (connect to its `completed` signal).
	"""
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		push_error("Failed to open audio file: %s" % path)
		return null
	var data := f.get_buffer(f.get_length())
	f.close()

	# Prepare request headers
	var headers := get_headers()
	headers.erase("Content-Type: application/json") # raw upload, not JSON
	headers.append("Content-Type: application/octet-stream")
	headers.append("X-Sample-Rate: %d" % AUDIO_SAMPLE_RATE)
	headers.append("X-DType: %s" % AUDIO_DTYPE)
	headers.append("user: n")  # must match server login
	headers.append("pass: 1")  # must match server login

	return _request_raw(api_url + "transcribe_file", data, headers)


## Optional: microphone capture support
func transcribe_recorded_audio(mic_stream: AudioStreamWAV) -> RequestHandle:
	"""
	Takes an AudioStreamWAV (recorded audio) and uploads it directly.
	"""
	var pcm_bytes: PackedByteArray = mic_stream.data
	var headers := get_headers()
	headers.erase("Content-Type: application/json")
	headers.append("Content-Type: application/octet-stream")
	headers.append("X-Sample-Rate: %d" % AUDIO_SAMPLE_RATE)
	headers.append("X-DType: %s" % AUDIO_DTYPE)
	headers.append("user: myuser")
	headers.append("pass: mypass")

	return _request_raw(api_url + "transcribe_file", pcm_bytes, headers)


# ---- INTERNAL RAW REQUEST ----
func _request_raw(address: String, body: PackedByteArray, headers: PackedStringArray, as_utf8: bool = true) -> RequestHandle:
	var handle = RequestHandle.new()
	handle.id = "req_%s" % str(Time.get_ticks_usec())
	add_user_signal("http_done_%s" % handle.id, ["result"])

	var req := HTTPRequest.new()
	req.timeout = 5.0
	req.use_threads = true
	add_child(req)

	var err := req.request_raw(address, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		var fail = {"ok": false, "error": err, "code": 0, "body": PackedByteArray(), "address": address, "id": handle.id}
		call_deferred("_emit_http_done", handle, fail)
		return handle

	req.request_completed.connect(func(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
		var json_result := {}
		print(body)
		if body.size() > 0:
			var text := body.get_string_from_utf8()
			json_result = JSON.parse_string(text)
		var payload = {
			"ok": response_code >= 200 and response_code < 300,
			"code": response_code,
			"body": json_result,
			"address": address,
			"id": handle.id
		}
		_emit_http_done(handle, payload)
		req.queue_free()
	)
	return handle

extends WebAPI
class_name Transcriber

const DEBUG_WAV := "C:/Users/Mike/Desktop/debug_record.wav"
const API_URL := "http://localhost:8000/transcribe_file"

var mic_player: AudioStreamPlayer
var record_effect: AudioEffectRecord
var recording := false


# ───────────────────────────────────────────────
#  INITIALIZATION
# ───────────────────────────────────────────────
func _ready() -> void:
	# 🎛 Create a dedicated muted recording bus
	var rec_idx := AudioServer.bus_count
	AudioServer.add_bus()
	AudioServer.set_bus_name(rec_idx, "RecordBus")
	AudioServer.set_bus_mute(rec_idx, true) # mute = no playback

	record_effect = AudioEffectRecord.new()
	record_effect.format = AudioStreamWAV.FORMAT_16_BITS
	#record_effect.mix_rate = AudioServer.get_mix_rate()

	AudioServer.add_bus_effect(rec_idx, record_effect)

	# 🎤 Route mic to that bus
	mic_player = AudioStreamPlayer.new()
	mic_player.stream = AudioStreamMicrophone.new()
	mic_player.bus = "RecordBus"
	add_child(mic_player)
	mic_player.play()

	print("🎤 Mic active → recording silently on RecordBus")
	print("Press Space to start/stop recording")


# ───────────────────────────────────────────────
#  PROCESS LOOP: debug toggle
# ───────────────────────────────────────────────
func _process(_delta: float) -> void:
	return
	if glob.space_just_pressed:
		if recording:
			end_recording()
			var handle := send_recording()
			if handle:
				handle.completed.connect(func(res): print("📨 Server result:", res))
		else:
			begin_recording()


# ───────────────────────────────────────────────
#  RECORD CONTROL
# ───────────────────────────────────────────────
func begin_recording() -> void:
	record_effect.set_recording_active(true)
	recording = true
	print("🎙 Recording...")


func end_recording() -> void:
	record_effect.set_recording_active(false)
	recording = false
	var wav: AudioStreamWAV = record_effect.get_recording()
	if not wav:
		push_error("❌ No recording captured. Check mic permissions.")
		return

	# Save to disk (debug)
	var f := FileAccess.open(DEBUG_WAV, FileAccess.WRITE)
	f.store_buffer(wav_to_buffer(wav))
	f.close()

	print("✅ Saved proper WAV:", DEBUG_WAV, "length:", wav.get_length(), "sec")


# ───────────────────────────────────────────────
#  WAV ENCODER (from your verified sketch)
# ───────────────────────────────────────────────
func wav_to_buffer(wav: AudioStreamWAV) -> PackedByteArray:
	var buf := PackedByteArray()

	var format_code := 1 # PCM
	var n_channels := 2 if wav.stereo else 1
	var sample_rate := AudioServer.get_mix_rate()
	var bytes_per_sample := 1 if wav.format == AudioStreamWAV.FORMAT_8_BITS else 2
	var data_bytes := wav.get_data().size()

	var put_str = func put_str(s: String): buf.append_array(s.to_utf8_buffer())
	var put_u16 = func put_u16(v: int): buf.append_array(PackedByteArray([v & 0xFF, (v >> 8) & 0xFF]))
	var put_u32 = func put_u32(v: int):
		buf.append_array(PackedByteArray([
			v & 0xFF, (v >> 8) & 0xFF,
			(v >> 16) & 0xFF, (v >> 24) & 0xFF
		]))

	put_str.call("RIFF")
	put_u32.call(data_bytes + 36)
	put_str.call("WAVEfmt ")
	put_u32.call(16)
	put_u16.call(format_code)
	put_u16.call(n_channels)
	put_u32.call(sample_rate)
	put_u32.call(sample_rate * n_channels * bytes_per_sample)
	put_u16.call(n_channels * bytes_per_sample)
	put_u16.call(bytes_per_sample * 8)
	put_str.call("data")
	put_u32.call(data_bytes)

	var raw := wav.get_data()
	if bytes_per_sample == 1:
		for i in raw.size():
			var s := raw[i]
			buf.append((s + 128) & 0xFF)
	else:
		for i in range(0, raw.size(), 2):
			var lo := raw[i]
			var hi := raw[i + 1]
			buf.append(lo)   # little endian: low byte first
			buf.append(hi)

	return buf


# ───────────────────────────────────────────────
#  SEND TO SERVER
# ───────────────────────────────────────────────
func send_recording() -> RequestHandle:
	var file := FileAccess.open(DEBUG_WAV, FileAccess.READ)
	if not file:
		push_error("Cannot read debug WAV.")
		return null
	var wav_bytes := file.get_buffer(file.get_length())
	file.close()

	var headers := get_headers()
	headers.erase("Content-Type: application/json")
	headers.append("Content-Type: audio/wav")
	headers.append("X-DType: wav")
	headers.append("user: n")
	headers.append("pass: 1")

	return _request_raw(API_URL, wav_bytes, headers)


# ───────────────────────────────────────────────
#  INTERNAL RAW REQUEST
# ───────────────────────────────────────────────
func _request_raw(address: String, body: PackedByteArray, headers: PackedStringArray) -> RequestHandle:
	var handle := RequestHandle.new()
	handle.id = "req_%s" % str(Time.get_ticks_usec())
	add_user_signal("http_done_%s" % handle.id, ["result"])

	var req := HTTPRequest.new()
	req.timeout = 5.0
	req.use_threads = true
	add_child(req)

	var err := req.request_raw(address, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		var fail := {"ok": false, "error": err, "code": 0, "body": PackedByteArray(), "address": address, "id": handle.id}
		call_deferred("_emit_http_done", handle, fail)
		return handle

	req.request_completed.connect(func(result: int, code: int, hdrs: PackedStringArray, body: PackedByteArray):
		var json_result := {}
		if body.size() > 0:
			var text := body.get_string_from_utf8()
			json_result = JSON.parse_string(text)
		var payload := {
			"ok": code >= 200 and code < 300,
			"code": code,
			"body": json_result,
			"address": address,
			"id": handle.id
		}
		_emit_http_done(handle, payload)
		req.queue_free()
	)
	return handle

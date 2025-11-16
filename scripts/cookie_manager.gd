extends Node
class_name Cookies

const cookie_file = "user://cookies.json"
var _cookies: Dictionary = {}

func _ready() -> void:
	_load_cookies()

func get_auth_header() -> Dictionary:
	return glob._logged_in

func get_username() -> String:
	return glob._logged_in.user

func get_pass() -> String:
	return glob._logged_in.pass

func user() -> String:
	return glob._logged_in.user

func pwd() -> String:
	return glob._logged_in.pass

func open_or_create(path: String) -> FileAccess:
	var full_path = "user://" + path
	var dir_path = full_path.get_base_dir()
	var dir := DirAccess.open("user://")
	if not dir.dir_exists(dir_path):
		var err = dir.make_dir_recursive(dir_path)
		if err != OK:
			push_error("Failed to create directory: %s" % dir_path)
			return null
	var file = FileAccess.open(full_path, FileAccess.READ_WRITE)
	if file:
		return file
	file = FileAccess.open(full_path, FileAccess.WRITE_READ)
	if not file:
		push_error("Failed to open or create file: %s" % full_path)
		return null
	return file

func dir_or_create(path: String) -> DirAccess:
	var full_path = "user://" + path
	
	var dir := DirAccess.open("user://")
	if dir == null:
		push_error("Cannot open user://")
		return null
	
	if not dir.dir_exists(path):
		var err = dir.make_dir_recursive(path)
		if err != OK:
			push_error("Failed to create directory: %s" % full_path)
			return null
	
	return DirAccess.open(full_path)


func _save_cookies() -> void:
	var f = FileAccess.open(cookie_file, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_cookies, "", true, true))
		f.close()

func set_cookie(name: String, value: String) -> void:
	_cookies[name] = value
	_save_cookies()

func has_cookie(name: String) -> bool:
	return _cookies.has(name)

func delete_cookie(name: String) -> void:
	if _cookies.has(name):
		_cookies.erase(name)
		_save_cookies()

func _load_cookies() -> void:
	if not FileAccess.file_exists(cookie_file):
		return
	var f = FileAccess.open(cookie_file, FileAccess.READ)
	if f:
		var txt = f.get_as_text().strip_edges()
		f.close()
		if txt != "":
			var parsed = JSON.parse_string(txt)
			if typeof(parsed) == TYPE_DICTIONARY:
				_cookies = parsed

func update_from_headers(headers: PackedStringArray) -> void:
	for h in headers:
		var lower = h.to_lower()
		if lower.begins_with("set-cookie:"):
			var cookie_str = h.substr(12).strip_edges()
			_parse_cookie(cookie_str)
	_save_cookies()

func _parse_cookie(cookie_str: String) -> void:
	var parts = cookie_str.split(";")[0].split("=")
	if parts.size() == 2:
		var name = parts[0].strip_edges()
		var value = parts[1].strip_edges()
		_cookies[name] = value

func get_header() -> String:
	if _cookies.is_empty():
		return ""
	var list: Array[String] = []
	for n in _cookies.keys():
		list.append("%s=%s" % [n, _cookies[n]])
	return "Cookie: " + "; ".join(list)

func clear():
	_cookies.clear()
	if FileAccess.file_exists(cookie_file):
		DirAccess.open("user://").remove(cookie_file)

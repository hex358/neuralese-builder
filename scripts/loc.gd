extends Node
class_name Loc

@export var auto: bool = false
var lang: String = "en"
@export var localizations_ru: Dictionary[String, String] = {}
@export var localizations_kz: Dictionary[String, String] = {}

var _parent: Node
var _source_text: String = ""   # always stores original, unlocalized text
var _last_display: String = ""  # stores current displayed text
var _translation_fn: Callable

func _ready() -> void:
	lang = glob.get_lang()
	_parent = get_parent()
	if localizations_ru and localizations_ru.keys()[0] == "_":
		var old = localizations_ru.keys()[0]
		var val = localizations_ru[old]
		localizations_ru.erase(localizations_ru.keys()[0])
		localizations_ru[sanitize(_get_text())] = val
	if localizations_kz and localizations_kz.keys()[0] == "_":
		var old = localizations_kz.keys()[0]
		var val = localizations_kz[old]
		localizations_kz.erase(localizations_kz.keys()[0])
		localizations_kz[sanitize(_get_text())] = val
	if not _parent:
		push_warning("Localization node requires a parent control.")
		return

	# Detect text or placeholder properties automatically
	_bind_signals()
	_source_text = _get_text()
	#print(get_parent().text)
	_translate_now()

	## Optionally connect to global language change signal if you have one
	#if Engine.has_singleton("LocalizationManager"):
		#var lm = Engine.get_singleton("LocalizationManager")
		#if lm.has_signal("language_changed"):
			#lm.language_changed.connect(func(new_lang):
				#lang = new_lang
				#_translate_now())

var prev_txt = null
func _bind_signals() -> void:
	if _parent is LabelAutoResize  or _parent is Label:
		_parent.draw.connect(func():
			#print("s")
			if prev_txt == null or prev_txt != _parent.text:
				prev_txt = _parent.text
				_on_parent_text_changed())
	elif _parent is BlockComponent:
		_parent.text_changed.connect(_on_parent_text_changed)
	#elif _parent is LineEdit:
#		_parent.placeholder_text_changed.connect(_on_parent_text_changed)
	# For custom classes:
	else:
		_handle_custom(_parent)

func _on_parent_text_changed() -> void:
	_source_text = _get_text()
	_translate_now()

func _get_text() -> String:
	if _parent is LabelAutoResize or _parent is BlockComponent or _parent is Label:
		return _parent.text
	elif _parent is LineEdit or _parent is ValidInput:
		return _parent.placeholder_text
	else:
		return ""

func _set_text(t: String) -> void:
	if _parent is LabelAutoResize:
		_parent.text = t
		#_parent.resize()
	elif _parent is BlockComponent:
		_parent.set_txt_no_emit(t)
	elif _parent is Label:
		_parent.text = t
	elif _parent is LineEdit:
		_parent.placeholder_text = t
	elif _parent is ValidInput:
		_parent.set_line(t)
	else:
		_handle_custom(_parent)

func _translate_now() -> void:
	if not _parent:
		return

	var new_text := _translate_to(_source_text, lang)
	if new_text != _last_display:
		_set_text(new_text)
		_last_display = new_text


var let_kz_last: int = ord("ұ")
func sanitize(src: String) -> String:
	var result := ""
	var prev_space := true

	var let_a := ord("a")
	var let_z := ord("z")

	var let_ru_first := ord("а")
	var let_ru_last := ord("я")
	var let_ru_yo := "ё"

	var kz_ext := {
		"ә": true, "ғ": true, "қ": true, "ң": true,
		"ө": true, "ұ": true, "ү": true, "һ": true, "і": true
	}

	for c in src.to_lower():
		var order = ord(c)

		var is_latin = order >= let_a and order <= let_z
		var is_digit = c.is_valid_int()
		var is_ru = (order >= let_ru_first and order <= let_ru_last) or (c == let_ru_yo)
		var is_kz = kz_ext.has(c)

		if is_digit or is_latin or is_ru or is_kz:
			result += c
			prev_space = false
		elif c == " ":
			if not prev_space:
				result += " "
				prev_space = true
		else:
			pass # drop any other character

	# trim trailing space
	if result.ends_with(" "):
		result = result.substr(0, result.length() - 1)

	return result

func _aux(text: String, lang: String):
	pass
# Override this in children for project-specific translations
func _translate_to(text: String, lang: String) -> String:
	_aux(text, lang)
	#print(text, " ", lang)
	if auto:
		if lang == "kz":
			return localizations_kz.get(sanitize(text), text)
		if lang == "ru":
			return localizations_ru.get(sanitize(text), text)
	return text

# Extend this to support more control types
func _handle_custom(node: Node) -> void:
	pass

extends Control

func is_focus(control: Control):
	if control is HSlider: return (control.get_global_rect().has_point(get_global_mouse_position()))
	return control and get_viewport().gui_get_focus_owner() == control
	
func get_focus():
	return get_viewport().gui_get_focus_owner()

var topr: Control = null

func set_topr_text(text: String):
	topr.show_text(text)

func hide_topr():
	topr.hide()

var _active_splashed: bool = false

func active_splashed() -> bool:
	return _active_splashed

var mouse_buttons: Dictionary = {1: true, 2: true, 3: true}
var wheel_buttons: Dictionary = {
	MOUSE_BUTTON_WHEEL_UP: true,
	MOUSE_BUTTON_WHEEL_DOWN: true,
	MOUSE_BUTTON_WHEEL_LEFT: true,
	MOUSE_BUTTON_WHEEL_RIGHT: true,
}

func line_block(line: LineEdit):
	line.editable = false
	line.selecting_enabled = false
	line.release_focus()
	line.mouse_filter = MOUSE_FILTER_IGNORE

func line_unblock(line: LineEdit):
	line.editable = true
	line.selecting_enabled = true
	line.mouse_filter = MOUSE_FILTER_STOP

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index in wheel_buttons:
			var hovered = get_viewport().gui_get_hovered_control()
			if hovered and hovered is Slider:
				accept_event()
				return
	#	elif event.button_index == MOUSE_BUTTON_LEFT:
	#		print(get_focus())

	if event is InputEventMouse:
		var focused = get_viewport().gui_get_focus_owner()
		#var occ = glob.is_occupied(focused, "menu_inside")
		#print(occ)
		if event is InputEventMouseButton and event.pressed:
			#print(glob.is_occupied(focused, "menu_inside"))
			if event.button_index in mouse_buttons:
				if focused and (focused is LineEdit or focused is Slider or focused is TextEdit or focused is RichTextLabel):
					var rect = focused.get_global_rect()
					if not rect.has_point(get_global_mouse_position()) and not event.has_meta("_emulated"):
						focused.release_focus()
						#if focused is ValidInput:
						focused.focus_exited.emit()
		elif not glob.mouse_pressed:
			if focused is Slider and not event.has_meta("_emulated"):
				#print("fj")
				focused.release_focus()
				focused.focus_exited.emit()

var expanded_menu: SubMenu = null
var _buttons = []

func move_mouse(pos: Vector2) -> void:
	var vp = get_viewport()
	var motion = InputEventMouseMotion.new()
	motion.global_position = pos
	motion.position = pos
	motion.relative = Vector2.ZERO
	motion.set_meta("_emulated", true)

	vp.push_input(motion)


var topr_inside: bool = false
#var _parent_graphs = {}
func reg_button(b: BlockComponent):
	pass
	#_parent_graphs[b] = [b.graph, b.graph.z_index if b.graph else 0]

func unreg_button(b: BlockComponent):
	pass

func _process(delta: float):
	var ct: int = 0
	for i in splashed.keys():
		if not is_instance_valid(i): splashed.erase(i); continue
		if i.persistent and not i.visible:
			ct += 1
	_active_splashed = len(splashed) != ct
#	print(get_viewport().gui_get_focus_owner())
			

var blur = preload("res://scenes/blur.tscn").instantiate()
var splash_menus = {
	"login": preload("res://scenes/splash.tscn"),
	"signup": preload("res://scenes/signup.tscn"),
	"scene_create": preload("res://scenes/scene_create.tscn"),
	"works": preload("res://scenes/works.tscn"),
	"project_create": preload("res://scenes/project_create.tscn"),
	"ai_help": preload("res://scenes/ai_help.tscn"),
	"select_dataset": preload("res://scenes/select_dataset.tscn"),
}


var cl = CanvasLayer.new()
var hg = preload("res://scenes/hourglass.tscn")
var hourglass: TextureRect

func hourglass_on():
	hourglass.on()

func hourglass_off():
	hourglass.off()

func _ready():
	cl.layer = 128
	add_child(cl)
	blur.self_modulate.a = 0
	cl.add_child(blur)
	var inst: Control = hg.instantiate()
	hourglass = inst
	hourglass.hide()
	cl.add_child(inst)
	inst.scale = Vector2.ONE * 2.0
	#inst.position = Vector2(30,30)
	#inst.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	inst.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_KEEP_HEIGHT, 39)
	inst.z_index = 90
	
	configure_richtext_theme_auto(header_theme, header_font, base_font)

var splashed = {}

func add_splashed(who: SplashMenu):
	splashed[who] = true

func rem_splashed(who: SplashMenu):
	splashed.erase(who)

func is_splashed(who: String) -> bool:
	for i in splashed:
		if i.typename == who: return true
	return false

func get_splash(who: String) -> SplashMenu:
	for i in splashed:
		if i.typename == who: return i
	return null

func force_layout_update(node: Control):
	node.propagate_call("minimum_size_changed")
	node.propagate_call("queue_sort")
	node.propagate_call("size_flags_changed")
	node.propagate_call("update_minimum_size")
	node.propagate_call("update")
	node.propagate_call("notification", [NOTIFICATION_LAYOUT_DIRECTION_CHANGED])


func splash(menu: String, splashed_from = null, emitter_ = null, inner = false, passed_data = null) -> SplashMenu:
	hourglass.off(true)
	if splashed_from:
		if !is_splashed(menu):
			splashed_from.in_splash = true
		else:
			splashed_from.in_splash = false
			get_splash(menu).go_away()
			return null
	var m: SplashMenu 
	if menu in already_splashed:
		m = already_splashed[menu]
	else:
		m = splash_menus[menu].instantiate()
	m.inner = inner
	hide_topr()
	if passed_data: m.passed_data = passed_data
	if not menu in already_splashed:
		cl.add_child(m)
	else:
		m.readys()
		m.splash()
	already_splashed[menu] = m
	m.splashed_from = splashed_from
	var emitter = ResultEmitter.new() if !emitter_ else emitter_
	m.emitter = emitter
	m.tree_exited.connect(func(): already_splashed.erase(menu))
	return m

func error(text: String):
	print(text)

class ResultEmitter:
	signal res(data: Dictionary, who: String)

var already_splashed: Dictionary = {}
signal result_emit(data: Dictionary)
func splash_and_get_result(menu: String, splashed_from = null, emitter_ = null, inner = false, passed_data = null) -> Dictionary:
	#print_stack()
	hourglass.off(true)
	if splashed_from:
		if !is_splashed(menu):
			splashed_from.in_splash = true
		else:
			splashed_from.in_splash = false
			get_splash(menu).go_away()
			return {}
	var m: SplashMenu 
	if menu in already_splashed:
		m = already_splashed[menu]
	else:
		m = splash_menus[menu].instantiate()
	m.inner = inner
	hide_topr()
	if passed_data: m.passed_data = passed_data
	if not menu in already_splashed:
		cl.add_child(m)
	else:
		m.readys()
		m.splash()
	already_splashed[menu] = m
	m.splashed_from = splashed_from
	var emitter = ResultEmitter.new() if !emitter_ else emitter_
	m.emitter = emitter
	m.tree_exited.connect(func(): already_splashed.erase(menu))
	var a = await emitter.res
	return a


func configure_richtext_theme_auto(theme: Theme, base_font: FontFile, monospaced_font: FontFile) -> void:
	if theme == null or base_font == null:
		push_warning("configure_richtext_theme_auto: theme/base_font must be non-null")
		return
	if monospaced_font == null:
		monospaced_font = base_font
	var has_axes := func(f: Font, tag: String) -> bool:
		if f and f.has_method(&"get_supported_variation_list"):
			var axes: Dictionary = f.get_supported_variation_list()
			return axes.has(tag)
		return false

	var make_bold := func(f: Font) -> Font:
		var v := FontVariation.new()
		v.base_font = f
		if has_axes.call(f, "wght"):
			var coords := v.variation_opentype
			coords["wght"] = 700.0
			v.variation_opentype = coords
		else:
			v.variation_embolden = 0.8
		return v

	var make_italic := func(f: Font) -> Font:
		var v := FontVariation.new()
		v.base_font = f
		if has_axes.call(f, "ital"):
			var coords := v.variation_opentype
			coords["ital"] = 1.0
			v.variation_opentype = coords
		elif has_axes.call(f, "slnt"):
			var coords := v.variation_opentype
			coords["slnt"] = -12.0
			v.variation_opentype = coords
		else:
			v.variation_transform = Transform2D(Vector2(1, 0.2), Vector2(0, 1), Vector2.ZERO)
		return v

	var make_bold_italic := func(f: Font) -> Font:
		var v := FontVariation.new()
		v.base_font = f
		var used_axes := false
		if has_axes.call(f, "wght"):
			var coords := v.variation_opentype
			coords["wght"] = 700.0
			v.variation_opentype = coords
			used_axes = true
		if has_axes.call(f, "ital") or has_axes.call(f, "slnt"):
			var coords := v.variation_opentype
			if has_axes.call(f, "ital"):
				coords["ital"] = 1.0
			elif has_axes.call(f, "slnt"):
				coords["slnt"] = -12.0
			v.variation_opentype = coords
			used_axes = true
		if not used_axes:
			v.variation_embolden = 0.8
			v.variation_transform = Transform2D(Vector2(1, 0.2), Vector2(0, 1), Vector2.ZERO)
		return v

	var normal_font: Font = base_font
	var bold_font: Font = make_bold.call(base_font)
	var italics_font: Font = make_italic.call(base_font)
	var bold_italics_font: Font = make_bold_italic.call(base_font)
	var mono_font: Font = monospaced_font


	theme.set_font(&"normal_font", &"RichTextLabel", normal_font)
	theme.set_font(&"bold_font", &"RichTextLabel", bold_font)
	theme.set_font(&"italics_font", &"RichTextLabel", italics_font)
	theme.set_font(&"bold_italics_font", &"RichTextLabel", bold_italics_font)
	theme.set_font(&"mono_font", &"RichTextLabel", mono_font)




const _CODEBLOCK_TOKEN = "\uF000CODEBLOCK%03d\uF000"
const _CODESPAN_TOKEN  = "\uF001CODESPAN%03d\uF001"

func markdown_to_bbcode(md: String) -> String:
	var codeblocks: Array[String] = []
	var codespans: Array[String] = []
	var text = md

	# ---------- 1) Extract fenced code blocks: ```...```
	var re_block = RegEx.new()
	re_block.compile("(?s)```(?:[A-Za-z0-9_+-]+)?\\s*(.*?)\\s*```")
	while true:
		var m = re_block.search(text)
		if m == null: break
		var code = m.get_string(1)
		codeblocks.append(code)
		var token = _CODEBLOCK_TOKEN % (codeblocks.size() - 1)
		text = text.substr(0, m.get_start()) + token + text.substr(m.get_end())

	# ---------- 2) Extract inline code: `...`
	var re_span = RegEx.new()
	re_span.compile("`([^`\\n]+?)`")
	while true:
		var m2 = re_span.search(text)
		if m2 == null: break
		var span = m2.get_string(1)
		codespans.append(span)
		var token2 = _CODESPAN_TOKEN % (codespans.size() - 1)
		text = text.substr(0, m2.get_start()) + token2 + text.substr(m2.get_end())

	# ---------- 3) Links: [text](url)
	var re_link = RegEx.new()
	re_link.compile("\\[([^\\]]+)\\]\\(([^)\\s]+)\\)")
	while true:
		var ml = re_link.search(text)
		if ml == null: break
		var label = ml.get_string(1)
		var url = ml.get_string(2)
		var rep = "[url=%s]%s[/url]" % [url, label]
		text = text.substr(0, ml.get_start()) + rep + text.substr(ml.get_end())

	# ---------- 4) Headings: #..######  → just make them bold + newline
	# (Top to bottom to avoid double-processing)
	for level in range(6, 0, -1):
		var pfx = String("#").repeat(level)
		var re_h = RegEx.new()
		re_h.compile("(?m)^%s\\s+(.*)$" % pfx)
		while true:
			var mh = re_h.search(text)
			if mh == null: break
			var body = mh.get_string(1).strip_edges()
			var rep_h = "[b]%s[/b]" % body
			text = text.substr(0, mh.get_start()) + rep_h + text.substr(mh.get_end())

	# ---------- 5) Strikethrough: ~~text~~
	var re_s = RegEx.new()
	re_s.compile("~~(.+?)~~")
	while true:
		var ms = re_s.search(text)
		if ms == null: break
		text = text.substr(0, ms.get_start()) + "[s]" + ms.get_string(1) + "[/s]" + text.substr(ms.get_end())

	# ---------- 6) Bold: **text** and __text__
	for pat in ["\\*\\*(.+?)\\*\\*", "__(.+?)__"]:
		var re_b = RegEx.new()
		re_b.compile(pat)
		while true:
			var mb = re_b.search(text)
			if mb == null: break
			text = text.substr(0, mb.get_start()) + "[b]" + mb.get_string(1) + "[/b]" + text.substr(mb.get_end())

	# ---------- 7) Italic: *text* and _text_  (avoid touching ** already handled)
	for pat_i in ["(?<!\\*)\\*(?!\\*)(.+?)(?<!\\*)\\*(?!\\*)"]:
		var re_i = RegEx.new()
		re_i.compile(pat_i)
		while true:
			var mi = re_i.search(text)
			if mi == null: break
			text = text.substr(0, mi.get_start()) + "[i]" + mi.get_string(1) + "[/i]" + text.substr(mi.get_end())

	# ---------- 8) Simple bullets: lines starting with "- " or "* "
	for pat_bullet in ["(?m)^-\\s+", "(?m)^\\*\\s+"]:
		var re_bu = RegEx.new()
		re_bu.compile(pat_bullet)
		text = re_bu.sub(text, "• ", true)

	# ---------- 9) Restore code spans and blocks as [code]...[/code]
	# Escape BBCode brackets inside code so they render literally.
	var esc = func(s: String) -> String:
		return s.replace("[", "\\[").replace("]", "\\]")

	# Spans first (so blocks can contain tokens without conflict)
	for idx in range(codespans.size()):
		var token = _CODESPAN_TOKEN % idx
		var repl = "[code]" + esc.call(codespans[idx]) + "[/code]"
		text = text.replace(token, repl)

	for idxb in range(codeblocks.size()):
		var tokenb = _CODEBLOCK_TOKEN % idxb
		var body = esc.call(codeblocks[idxb])
		# Ensure code blocks are separated by blank lines for RTL auto-parsing
		var replb = "\n[code]\n%s\n[/code]\n" % body
		text = text.replace(tokenb, replb)

	return text





var base_theme = preload("res://resources/theme.tres")
var header_theme = preload("res://resources/theme_headers.tres")
var header_font = preload("res://game_assets/fonts/JetBrainsSans[wght]-VF.ttf") as FontFile
var base_font = preload("res://game_assets/fonts/JetBrainsMono-VariableFont_wght.ttf") as FontFile



var selecting_box: bool = false
func click_screen(pos: Vector2, button = MOUSE_BUTTON_LEFT, double_click = false) -> void:
	var vp = get_viewport()

	var down = InputEventMouseButton.new()
	down.button_index = button
	down.pressed = true
	down.double_click = double_click
	down.position = pos
	down.global_position = pos
	down.set_meta("_emulated", true)
	vp.push_input(down)

	var up = InputEventMouseButton.new()
	up.button_index = button
	up.pressed = false
	up.double_click = false
	up.position = pos
	up.global_position = pos
	up.set_meta("_emulated", true)
	vp.push_input(up)

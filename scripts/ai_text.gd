extends RichTextLabel

func _normalize_newlines(s: String) -> String:
	# Collapse all sequences of 2+ newlines into a single one.
	while "\n\n" in s:
		s = s.replace("\n\n", "\n")
	# Trim accidental newlines inside BBCode tags like [/color]\n[...]
	s = s.replace("[/color]\n[", "[/color][")
	return s.strip_edges()


var actual_text = ""
func push_text(new: String):
	actual_text += new
	text = actual_text
	if thinking: text += (actual_text + "\n[color=gray]Building...[/color]").strip_edges()
	else: text = actual_text
	text = ui.markdown_to_bbcode(text)
	text = _normalize_newlines(text)
	text = text.strip_edges()

var thinking: bool = false

func set_thinking(yes: bool):
	thinking = yes

func set_txt(text_: String):
	actual_text = text_
	text = actual_text
	text = ui.markdown_to_bbcode(text)
	text = _normalize_newlines(text)
	text = text.strip_edges()

func _process(delta: float) -> void:
	if glob.mouse_just_pressed and get_global_rect().has_point(get_global_mouse_position()) and not ui.get_focus():
		#print("f")
		#print(text)
		#DisplayServer.clipboard_set("")
		DisplayServer.clipboard_set(text)
		#print(text)
		#print(DisplayServer.clipboard_get())

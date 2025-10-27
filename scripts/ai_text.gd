extends RichTextLabel


var actual_text = ""
func push_text(new: String):
	actual_text += new
	text = actual_text
	if thinking: text += (actual_text + "\n[color=gray]Thinking...[/color]").strip_edges()
	else: text = actual_text
	text = ui.markdown_to_bbcode(text)
	text = text.replace("\n\n", "\n")
	text = text.strip_edges()

var thinking: bool = false

func set_thinking(yes: bool):
	thinking = yes

func set_txt(text_: String):
	actual_text = text_
	text = actual_text
	text = ui.markdown_to_bbcode(text)
	text = text.replace("\n\n", "\n")
	text = text.strip_edges()

func _process(delta: float) -> void:
	if glob.mouse_just_pressed and get_global_rect().has_point(get_global_mouse_position()) and not ui.get_focus():
		#print("f")
		#print(text)
		#DisplayServer.clipboard_set("")
		DisplayServer.clipboard_set(text)
		#print(text)
		#print(DisplayServer.clipboard_get())

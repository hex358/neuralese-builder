extends Loc

func _aux(text: String, lang: String):
	#print(text)
	if text.begins_with("Т"):
		_parent.text_offset.x = 1
	else:
		_parent.text_offset.x = 0

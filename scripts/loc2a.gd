extends Loc

func _aux(text: String, lang: String):
	if lang != "kz":
		_parent.text_offset.x = 2
	else:
		_parent.text_offset.x = 0

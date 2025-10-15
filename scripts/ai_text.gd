extends RichTextLabel


var actual_text = ""
func push_text(new: String):
	actual_text += new
	text = actual_text.strip_edges()


func _process(delta: float) -> void:
	pass

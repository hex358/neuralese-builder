extends TableCell

func _map_data(data: Dictionary) -> void:
	#print(data)
	$Label.text = data["text"]
	$Label.resize.call_deferred()

func _height_key(info: Dictionary) :
	return ""

func _resized():
	#print("AA")
	$Label.resize.call_deferred()

func _get_data() -> Dictionary:
	return {"text": $Label.text}

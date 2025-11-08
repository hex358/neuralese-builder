extends TableCell

func _map_data(data: Dictionary) -> void:
	#print(data)
	$Label.text = data["text"]
	$Label.resize()

func _height_key(info: Dictionary) -> String:
	return ""

func _resized():
	#print("AA")
	$Label.resize()

func _get_data() -> Dictionary:
	return {"text": $Label.text}

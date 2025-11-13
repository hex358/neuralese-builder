extends TableCell
func _map_data(data: Dictionary) -> void:
	#print(data)
	cell_data = data
	if int(data["num"]) == $Label.min_value:
		$Label.set_line("")
	else:
		$Label.set_line(str(data["num"]))
	#_on_label_changed.call_deferred()

func _height_key(info: Dictionary) :
	return 0

func _convert(data: Dictionary, dtype: String) -> Dictionary:
	if dtype == "text":
		return {"type": "text", "text": str(data["num"]), "ok": true}
	return {}

func _field_convert(who: String, data: String):
	return int(data) if data.is_valid_int() else null

func _defaults() -> Dictionary:
	return {"num": 0}

var cache = {}
func _resized():
	#print("AA")
	#cache = {}
	
	$Label.position = Vector2(10, size.y / 2 - $Label.size.y * $Label.scale.y / 2)
	
	#$Label.size.x = min((size.x - 20) / $Label.scale.x, len(cell_data["text"]) * 30)
	#cache[cell_data["text"]] = Rect2($Label.position, $Label.size)
	var minimal = (size.x - 20)/$Label.scale.x 
	$Label.size.x = min(minimal, 
	max(len($Label.text),3) * 30 * $Label.scale.x)
	$Label.resize_after = int(minimal / 20)
	#print($Label.resize_after)
	if not $Label.is_node_ready():
		await $Label.ready
	##$Label.set_line($Label.text, false, true)
	$Label._resize_monospace()
	##_on_label_changed()
	#if name == "ergergerg1":
		#print($Label.override)
	#$Label.resize.call_deferred()
	#print("fjfj")


func _on_label_line_enter() -> void:
	if $Label.is_valid:
		cell_data["num"] = int($Label.get_value())



func _on_label_changed() -> void:
	pass
	#await get_tree().process_frame
##	print(cell_data["text"])
	#var minimal = (size.x - 40)/$Label.scale.x 
	#$Label.size.x = min(minimal, 
	#len($Label.text) * 30 * $Label.scale.x)
	#if $Label.size.x >= minimal-1:
	#$Label.resize_after = 18
	#else:
		#$Label.resize_after = 0
	##if cell_data.text == "egrergger":
	##	print($Label.base_font_size)
	##	print($Label.resize_after)
	#$Label._resize_monospace()
	#print(glob.get_label_text_size($Label).x)

extends TableCell

func _map_data(data: Dictionary) -> void:
	#print(data)
	cell_data = data
	#_on_label_changed.call_deferred()

func _height_key(info: Dictionary) :
	return 0

func _defaults() -> Dictionary:
	return {"img": "", "x": 28, "y": 28}

@onready var upload = $Label/train2

func _mouse_enter():
	upload.show()

func _mouse_exit():
	upload.hide()


func _convert(data: Dictionary, dtype: String) -> Dictionary:
	return {}


var cache = {}
var prev_size_x: int = size.x
func _resized():
	if size.x != prev_size_x:
		prev_size_x = size.x
		#print("AA")
		$Label.resize.call_deferred()
	pass


func _on_label_line_enter() -> void:
	pass



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


func _on_train_2_released() -> void:
	print("fjfj")

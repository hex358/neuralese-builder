extends TableCell

var none = preload("res://game_assets/icons/none.png")
func _map_data(data: Dictionary) -> void:
	#print(data)
	cell_data = data
	#print(data)
	var got = data.get("img", null)
	var img: bool = got is Object
	if img:
		$TextureRect.texture = data["img"]
		$TextureRect.self_modulate = Color.WHITE
		#$TextureRect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		#$TextureRect.anchor_bottom = -6
	else:
		$TextureRect.self_modulate = Color(0.5, 0.5, 0.5, 1)
		#$TextureRect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		$TextureRect.texture = none
		#$TextureRect.anchor_bottom = -6
	if img:
		var dims = get_dims()
		cell_data["x"] = dims.x
		cell_data["y"] = dims.y
	else:
		cell_data["x"] = 0
		cell_data["y"] = 0
	
	#_on_label_changed.call_deferred()

func _height_key(info: Dictionary) :
	return 0

func _field_convert(who: String, data: String):
	if who == "img":
		return 0
	return null

func get_dims():
	return $TextureRect.texture.get_size()

func _defaults() -> Dictionary:
	return {"img": null, "x": 0, "y": 0}

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
	var seti = ["png", "jpg", "jpeg"]
	var a = await ui.splash_and_get_result("path_open", upload, null, true, 
	{"filter": seti, "dirs": true})
	var setified = glob.to_set(seti)
	if a:
		var path = a["path"]
		var files = []
		var is_dir: bool = false
		if DirAccess.dir_exists_absolute(path):
			is_dir = true
			files = DirAccess.get_files_at(path)
		else:
			files = [path]
		#print(files)
		var imgs = []
		for file in files:
			
			if file.rsplit(".", true, 1)[-1] in setified:
				pass
			else:
				continue
			if is_dir:
				file = path + "/"+ file
			var img = Image.load_from_file(file)
			#print(img)
			var new = ImageTexture.create_from_image(img)
			#print(new)
			imgs.append(new)
		table.push_textures(self, imgs)
		#if imgs:
		#	$TextureRect.texture = imgs[0]
		#print(imgs)

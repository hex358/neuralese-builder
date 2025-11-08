class_name TableCell
extends Control

@export var cell_type: StringName
@export var height: float = 67.0

signal changed

# Base serialization entry point
func get_data() -> Dictionary:
	var base_data = {"type": cell_type}
	base_data.merge(_get_data())
	return base_data

func _height_key(info: Dictionary) -> String:
	return ""

func _resized():
	pass

func _get_data() -> Dictionary:
	return {}

func map_data(data: Dictionary) -> void:
	_map_data(data)

func _map_data(data: Dictionary) -> void:
	pass

func _estimate_height(data: Dictionary):
#	print(data)
	return height

func get_desired_size() -> Vector2:
	return size

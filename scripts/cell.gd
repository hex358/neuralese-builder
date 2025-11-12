class_name TableCell
extends Control

var table: VirtualTable = null
@export var cell_type: StringName
@export var height: float = 67.0

signal changed

func _defaults() -> Dictionary:
	return {}

var cell_data: Dictionary = {}
func _ready() -> void:
	cell_data["type"] = cell_type
	_resized()

func get_data() -> Dictionary:
	return {}

func _height_key(info: Dictionary):
	return ""

func _resized():
	pass

func _mouse_enter():
	#print(cell_data)
	pass

func _mouse_exit():
	pass

func _convert(data: Dictionary, dtype: String) -> Dictionary:
	return {}


func map_data(data: Dictionary) -> void:
	if data["type"] != cell_type: return
	_map_data(data)

func _map_data(data: Dictionary) -> void:
	pass

func _estimate_height(data: Dictionary):
#	print(data)
	return height

func get_desired_size() -> Vector2:
	return size

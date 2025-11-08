class_name GridOverlay
extends Control

var table: VirtualTable



func _draw() -> void:
	if table == null or not is_instance_valid(table):
		return
	table._draw_grid(self)

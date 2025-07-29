@tool
extends Node

var base_graph = preload("res://base_graph.tscn")
var viewport_moving: bool = false
var viewport_just_started_moving: bool = false

func get_graph(flags = Graph.Flags.NONE) -> Graph:
	var new = base_graph.instantiate()
	new.graph_flags = flags
	return new

func get_label_text_size(lbl: Label) -> Vector2:
	# Measure label text size
	var font = lbl.get_theme_font("font")
	var size = lbl.get_theme_font_size("font_size")
	return font.get_string_size(lbl.text, lbl.horizontal_alignment, -1, size)

func layer_to_global(layer: CanvasLayer, point: Vector2):
	return layer.transform * point

func global_to_layer(layer: CanvasLayer, point: Vector2):
	return layer.transform.affine_inverse() * point

func spring(from: Vector2, to: Vector2, t: float,
			frequency: float = 4.5,
			damping: float = 4.0,
			amplitude: float = 2.0
) -> Vector2:
	var w = frequency * PI * 2.0
	var decay = exp(-damping * t)
	var osc = cos(w * t) + (damping / w) * sin(w * t)
	var amp_factor = lerp(1.0, amplitude, t)
	var factor = 1.0 - decay * osc * amp_factor
	return from + (to - from) * factor

func _ready() -> void:
	pass

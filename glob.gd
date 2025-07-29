@tool
extends Node

var base_graph = preload("res://base_graph.tscn")
var hide_menus: bool = false

func reset_menus() -> void: hide_menus = true

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


class _Timer extends RefCounted:
	var wait_time: float; var progress: float
	signal timeout
	func _init(wait_time: float):
		self.wait_time = wait_time; self.progress = 0.0

var timers: Dictionary[_Timer, bool] = {}

func wait(wait_time: float):
	var timer = _Timer.new(wait_time)
	timers[timer] = true; return timer.timeout

func _after_process(delta: float) -> void:
	hide_menus = false

func _process(delta: float) -> void:
	_after_process.call_deferred(delta)
	
	var to_erase = []
	for timer in timers:
		timer.progress += delta
		if timer.progress > timer.wait_time: 
			timer.timeout.emit()
			to_erase.append(timer)
	for i in to_erase:
		timers.erase(i)

func _ready() -> void:
	pass

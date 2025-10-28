extends Label
class_name LabelAutoResize

@onready var base_scale: float = scale.x
@export var padding: Vector2 = Vector2(4, 4) # optional extra spacing
@export var min_scale: float = 0.1
@export var parent_indep: bool = false
@export var base_size: Vector2
@export var simple: bool = false
@export var simple_letters: int = 0 

func _ready() -> void:
	if not simple:
		resize.call_deferred()


@onready var _font = get_theme_font("font")
@onready var base_font_size = get_theme_font_size("font")

func _resize_simple() -> void:
	var txt = text
	if txt.is_empty():
		add_theme_font_size_override("font_size", base_font_size)
		return
	
	var n = txt.length()
	if n <= simple_letters:
		add_theme_font_size_override("font_size", base_font_size)
		return

	# Shrink proportionally to how many letters exceed the limit
	var ratio = float(simple_letters) / float(n)
	var new_fs = int(round(base_font_size * ratio))
	new_fs = clamp(new_fs, 6, base_font_size)
	add_theme_font_size_override("font_size", new_fs)

func resize() -> void:
	if simple:
		_resize_simple()
		return
	if !parent_indep: resize_dep(); return
	var available: Vector2
	
	if parent_indep:
		available = base_size
	else:
		var parent_ctrl = get_parent()
		if not (parent_ctrl is Control):
			return
		available = parent_ctrl.size - position
	
	padding = Vector2.ZERO
	var text_size: Vector2 = glob.get_label_text_size(self, base_scale if !parent_indep else 1.0)
	if !parent_indep:
		text_size += padding / scale
	else:
		text_size += padding
	
	if text_size.x <= 0.0 or text_size.y <= 0.0:
		return
	
	var kx: float = available.x / text_size.x
	var ky: float = available.y / text_size.y
	var k: float = min(kx, ky)
	var new_scale: float = clamp(base_scale * k, min_scale, base_scale)
	scale = Vector2.ONE * new_scale



func resize_dep() -> void:
	var parent_ctrl = get_parent()
	if not (parent_ctrl is Control):
		return
	var parent_size: Vector2 = parent_ctrl.size
	var available: Vector2 = parent_size - position
	var text_size: Vector2 = glob.get_label_text_size(self, base_scale) + padding / scale
	
	if text_size.x <= 0.0 or text_size.y <= 0.0:
		return

	var kx: float = available.x / text_size.x
	var ky: float = available.y / text_size.y
	var k: float = min(kx, ky)
	
	scale = Vector2.ONE * min(base_scale, max(min_scale, base_scale * k))

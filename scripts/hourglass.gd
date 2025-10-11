@tool
extends TextureRect

var delay: float = 0.0
var prog: float = 0.0
func _process(delta: float) -> void:
	if delay > 0.3: delay = 0.0; prog = 0.0
	if delay: 
		delay += delta; return
	prog += delta * 1.5
	if prog > 1.0:
		rotation = PI
		delay += delta; return
	rotation = lerpf(PI, 0, glob.in_out_quad(prog))

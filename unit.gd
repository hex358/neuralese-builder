extends Control

var low = {"edit_graph": true}
func _process(delta: float) -> void:
	var inside: bool = Rect2(0,0,size.x,size.y).has_point(get_local_mouse_position())
	#print(inside)
	if inside:
		glob.set_menu_type(self, &"delete_getvar", low)
	else:
		glob.reset_menu_type(self, &"delete_getvar")
		

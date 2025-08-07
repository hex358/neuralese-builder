extends Control

var low = {"edit_graph": true}
func _process(delta: float) -> void:
	var inside: bool = Rect2(0,0,size.x,size.y).has_point(get_local_mouse_position())
	#print(inside)
	if inside:
		glob.set_menu_type(self, &"delete_i", low)
		if glob.mouse_alt_just_pressed:
			glob.menus[&"delete_i"].show_up($Label.text)
	else:
		glob.reset_menu_type(self, &"delete_i")
		

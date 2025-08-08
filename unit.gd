extends Control

var id: int = 0
var connect_position: float = 0.0
var low = {"edit_graph": true}

func delete():
	$o.delete()

func _process(delta: float) -> void:
	var inside: bool = Rect2(0,0,size.x,size.y).has_point(get_local_mouse_position())
	#print(inside)
	if inside:
		glob.set_menu_type(self, &"delete_i", low)
		if glob.mouse_alt_just_pressed:
			glob.menus[&"delete_i"].show_up($Label.text, get_parent().remove_unit.bind(id))
	else:
		glob.reset_menu_type(self, &"delete_i")
		

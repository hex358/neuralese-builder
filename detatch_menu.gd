@tool

extends BlockComponent

func show_up(iter, node):
	#if visible: return=
	#menu_hide()
	#if is_instance_valid(timer):
	#	await timer.timeout
	glob.getref("detatch_unroll").unroll(iter)
	if not mouse_open:
		menu_show(pos_clamp(get_global_mouse_position()))
	state.holding = false
	unblock_input()
	
	#menu_expand()

var old_hovered = {}; var _hovered = {}
func _menu_handle_hovering(button: BlockComponent):
	_hovered[instance_from_id(button.metadata["id"])] = 0.0

func _sub_process(delta:float):
	if Engine.is_editor_hint(): return
	
	for i in old_hovered:
		if not i in _hovered:
			i.modulate = Color.WHITE
	old_hovered = _hovered
	for i in _hovered:
		i.modulate = Color.RED
	_hovered = {}

func _menu_handle_release(button: BlockComponent):
	block_input()
	var inst = instance_from_id(button.metadata["id"])
	var node = inst.tied_to
	node.detatch_spline(inst)
	_hovered.clear()
	menu_hide()
	

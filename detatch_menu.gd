@tool

extends BlockComponent

func show_up(iter, node):
	#if visible: return=
	#menu_hide()
	#if is_instance_valid(timer):
	#	await timer.timeout
	
	glob.getref("detatch_unroll").unroll(iter)
	await get_tree().process_frame
	if not mouse_open:
		menu_show(pos_clamp(get_global_mouse_position()))
	state.holding = false
	unblock_input()
	
	
	#menu_expand()

var old_hovered = {}; var _hovered = {}
func _menu_handle_hovering(button: BlockComponent):
	var _inst = button.metadata["inst"]
	if button.metadata["all"]:
		for inst in _inst:
			_hovered[inst] = [0.0, inst.modulate]
	else:
		_hovered[_inst] = [0.0, _inst.modulate]

func _sub_process(delta:float):
	if Engine.is_editor_hint(): return
	#print(expanded_size)
	
	var to_delete = []
	for spline in old_hovered:
		if not spline in _hovered:
			if not is_instance_valid(spline):
				to_delete.append(spline)
				continue
			old_hovered[spline][0] = lerpf(old_hovered[spline][0], 1.0, delta*14.0)
			if old_hovered[spline][0] > 0.9: 
				spline.modulate = Color.WHITE
				to_delete.append(spline)
				continue
			spline.modulate = spline.modulate.lerp(Color.WHITE, delta*14.0)
	for i in to_delete:
		old_hovered.erase(i)
	old_hovered.merge(_hovered)
	for spline in _hovered:
		spline.modulate = spline.modulate.lerp(Color.RED, delta * 14.0)
	_hovered = {}

func _menu_handle_release(button: BlockComponent):
	
	block_input()
	var _inst = button.metadata["inst"]
	if button.metadata["all"]:
		var node = _inst[0].tied_to
		for inst in _inst:
			node.remove_input_spline(inst)
	else:
		_inst.tied_to.remove_input_spline(_inst)
	_hovered.clear()
	menu_hide()
	

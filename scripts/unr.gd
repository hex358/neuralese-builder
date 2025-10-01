@tool

extends BlockComponent

@onready var par = get_parent()


func _ready() -> void:
	if not Engine.is_editor_hint():
		super()
		show_up(range(1), null)

func show_up(iter, node):
	#if visible: return=
	#menu_hide()
	#if is_instance_valid(timer):
	#	await timer.timeout
	glob.getref("list_unroll").unroll(iter)
	await get_tree().process_frame
	if not mouse_open:
		menu_show(position)
	state.holding = false
	unblock_input()
	
	
	#menu_expand()

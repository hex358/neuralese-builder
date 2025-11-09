extends Node2D
class_name TabWindow
@export var window_name: String = ""
@export var camera: Camera2D

func _enter_tree() -> void:
	assert(!glob.tree_windows.has(window_name), "occupied")
	glob.tree_windows[window_name] = self
	camera.enabled = false

func _window_show():
	process_mode = Node.PROCESS_MODE_ALWAYS
	graphs.show()
	$menus.show()
	$follow_menus.show()
	$bg/TextureRect.show()
	show()
	if glob.cam is GraphViewport:
		glob.cam.reset()

func _window_hide():
	if glob.cam is GraphViewport:
		glob.cam.reset()
	process_mode = Node.PROCESS_MODE_DISABLED
	glob.hide_all_menus()
	graphs.hide()
	$menus.hide()
	$follow_menus.hide()
	$bg/TextureRect.hide()
	hide()

func window_hide():
	glob.cam = null
	camera.enabled = false
	_window_hide()

func window_show():
	glob.cam = camera
	camera.make_current()
	camera.enabled = true
	_window_show()

	#$GraphStorage.process_mode = Node.PROCESS_MODE_DISABLED

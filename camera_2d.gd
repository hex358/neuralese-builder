extends Camera2D
var pressed = Input.is_action_pressed

@onready var bg = get_parent().get_node("c/SubViewport/BlurredBackground")
@onready var blurbox = get_parent().get_node("c/SubViewport/blur")
@onready var subv = get_parent().get_node("c/SubViewport")

var init_pos = position
func _physics_process(delta: float) -> void:
	var po = position
	var axis_x = Input.get_axis("left", "right")
	var axis_y = Input.get_axis("up", "down") 
	glob.viewport_just_started_moving = (axis_x or axis_y) and not glob.viewport_moving
	glob.viewport_moving = axis_x or axis_y
	position.x += axis_x * delta * 500
	position.y += axis_y * delta * 500

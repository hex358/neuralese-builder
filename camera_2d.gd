extends Camera2D
var pressed = Input.is_action_pressed

@onready var bg = get_parent().get_node("c/SubViewport/BlurredBackground")
@onready var blurbox = get_parent().get_node("c/SubViewport/blur")
@onready var subv = get_parent().get_node("c/SubViewport")

var init_pos = position
func _physics_process(delta: float) -> void:
	var po = position
	position.x += Input.get_axis("left", "right") * delta * 500
	position.y += Input.get_axis("up", "down") * delta * 500

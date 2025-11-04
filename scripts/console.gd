extends RichTextLabel

@export var wheel_mult : float = 6.0  # adjust this to suit

var vsb : VScrollBar = null

func _ready():
	# Attempt to get internal VScrollBar
	vsb = get_v_scroll_bar()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MouseButton.MOUSE_BUTTON_WHEEL_UP:
			if vsb:
				#print("A")
				vsb.value = max(vsb.min_value, vsb.value - vsb.step * wheel_mult)
				accept_event()
		elif event.button_index == MouseButton.MOUSE_BUTTON_WHEEL_DOWN:
			if vsb:
				vsb.value = min(vsb.max_value, vsb.value + vsb.step * wheel_mult)
				accept_event()

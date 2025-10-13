extends SplashMenu


func _just_splash():
	ui.blur.set_tuning(Color(0,0,0,0.5))

func _process(delta: float) -> void:
	super(delta)
	var tr = $ColorRect/root/TextureRect
	var bar: VScrollBar = $ColorRect/ScrollContainer.get_v_scroll_bar()
	#bar.offset_left = -3
	$ColorRect/root/TextureRect2.visible = bar.value > 0.1
	#print($ColorRect/ScrollContainer.get_v_scroll_bar().max_value )
	#print($ColorRect/ScrollContainer.get_v_scroll_bar().value )
	tr.visible = bar.max_value - bar.page > bar.value
	tr.position = $ColorRect/Label2.position - Vector2(0,5)

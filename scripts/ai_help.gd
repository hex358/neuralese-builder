extends SplashMenu

@export var _user_message: HBoxContainer
@export var _ai_message: HBoxContainer

var chat_id: int = 0

@onready var user_message = _user_message.duplicate()
@onready var ai_message = _ai_message.duplicate()
func _ready() -> void:
	super()
	_user_message.queue_free()
	_ai_message.queue_free()
	set_messages([
		{"user": false, "text": "Hi! My name is Axon. I'm here to help & teach you Neural Networks!"},
		])

func text_receive(data: PackedByteArray):
	var dt = data.get_string_from_utf8()
	var parsed = JSON.parse_string(dt)
	if "text" in parsed:
		get_last_message().object.push_text(parsed.text)

func send_message(text: String):
	add_message({"user": true, "text": text})
	$ColorRect/Label2.disable()
	add_message({"user": false, "text": "", "_pending": true})
	var sock = await sockets.connect_to("ws/talk", text_receive)
	sock.send_json({"user": "n", "pass": "1", "chat_id": str(chat_id), "text": $ColorRect/Label2.text})
	$ColorRect/Label2.clear()
	await sock.closed
	get_last_message().erase("_pending")
	$ColorRect/Label2.enable()

var _message_list: Array[Dictionary] = []

@onready var scroller = $ColorRect/ScrollContainer/MarginContainer2/MarginContainer/VBoxContainer
func set_messages(messages: Array[Dictionary]):
	for message in messages:
		add_message(message)

func add_message(message: Dictionary):
	_message_list.append(message)
	var new = null
	if message.user:
		new = user_message.duplicate()
	else:
		new = ai_message.duplicate()
	scroller.add_child(new)
	new.get_node("txt").text = message.text
	message.object = new.get_node("txt")


func _just_splash():
	ui.blur.set_tuning(Color(0,0,0,0.5))

@onready var bs = $ColorRect/ScrollContainer.size.y
func _process(delta: float) -> void:
	super(delta)
	var tr = $ColorRect/root/TextureRect
	var bar: VScrollBar = $ColorRect/ScrollContainer.get_v_scroll_bar()
	#bar.offset_left = -3
	$ColorRect/root/TextureRect2.visible = bar.value > 0.1
	#print($ColorRect/ScrollContainer.get_v_scroll_bar().max_value )
	#print($ColorRect/ScrollContainer.get_v_scroll_bar().value )
	tr.visible = bar.max_value - bar.page > bar.value or $ColorRect/Label2.size.y > 46.5
	
	var scrolling = bar.max_value - bar.page > bar.value
	#if !scrolling:
		
	#if scrolling:
	#	$ColorRect/ScrollContainer.size.y = bs + 6
	#else:
	#$ColorRect/ScrollContainer.size.y = bs - 90
		
	
	if $ColorRect/Label2.size.y > 46.5:
		if scrolling:
			tr.position = $ColorRect/Label2.position + Vector2(0,-1)
		else:
			tr.position = $ColorRect/Label2.position + Vector2(0,-11)
			
	else:
		if scrolling:
			tr.position = $ColorRect/Label2.position + Vector2(0,-0)
		else:
			tr.position = $ColorRect/Label2.position + Vector2(0,-11)
		


func _on_train_hovering() -> void:
	pass # Replace with function body.


func get_last_message() -> Dictionary:
	return _message_list[-1] if _message_list else null


func on_send(txt: String) -> void:
	if get_last_message() and not get_last_message().has("_pending"):
		send_message($ColorRect/Label2.text)

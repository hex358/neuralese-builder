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
	var received = await glob.request_chat(str(chat_id))
	if received and received.body:
		var json = JSON.parse_string(received.body.get_string_from_utf8())
		if not "messages" in json: return
		for i in json.messages:
			if i["role"] == "user":
				i.user = true
			elif i["role"] != "system":
				i.user = false
				i.text = glob.clean_message(i.text)
			i.erase("role")
		set_messages(json.messages)
	
	await get_tree().process_frame
	$ColorRect/ScrollContainer.set_deferred("scroll_vertical", $ColorRect/ScrollContainer.get_v_scroll_bar().max_value)
	if get_last_message().user:
		if glob.message_sockets.has(chat_id):
			var got = glob.get_my_message_state(chat_id, text_receive)
			if got[0]:
				$ColorRect/Label2.disable()
				got[0].kill.connect(func():
						get_last_message().erase("_pending")
						$ColorRect/Label2.enable())
				#print(got[1])
				add_message({"user": false, "text": got[1]})

func text_receive(text):
	get_last_message().object.push_text(text)

func send_message(text: String):
	add_message({"user": true, "text": text})
	$ColorRect/Label2.disable()
	add_message({"user": false, "text": "", "_pending": true})
	$ColorRect/Label2.clear()
	var sock = await glob.update_message_stream(text, chat_id, text_receive, glob.def, true)
	if sock:
	#var sock = await sockets.connect_to("ws/talk", text_receive)
	#sock.send_json({"user": "n", "pass": "1", "chat_id": str(chat_id), 
	#"text": $ColorRect/Label2.text, "_clear": "",
	#"scene": str(glob.get_project_id())})
		await sock.kill
	get_last_message().erase("_pending")
	$ColorRect/Label2.enable()
	#await get_tree().process_frame
	#$ColorRect/ScrollContainer.set_deferred("scroll_vertical", $ColorRect/ScrollContainer.get_v_scroll_bar().max_value)

var _message_list: Array[Dictionary] = []

@onready var scroller = $ColorRect/ScrollContainer/MarginContainer2/MarginContainer/VBoxContainer
func set_messages(messages: Array):
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
	if not message.user:
		new.get_node("txt").actual_text = message.text
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
			tr.position = $ColorRect/Label2.position + Vector2(0,-1)
			
	else:
		if scrolling:
			tr.position = $ColorRect/Label2.position + Vector2(0,-0)
		else:
			tr.position = $ColorRect/Label2.position + Vector2(0,-1)
		


func _on_train_hovering() -> void:
	pass # Replace with function body.


func get_last_message() -> Dictionary:
	return _message_list[-1] if _message_list else null


func on_send(txt: String) -> void:
	if get_last_message() and not get_last_message().has("_pending"):
		send_message($ColorRect/Label2.text)

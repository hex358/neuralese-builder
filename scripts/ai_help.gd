extends SplashMenu
class_name AIHelpMenu

func _enter_tree() -> void:
	glob.ai_help_menu = self

@export var _user_message: HBoxContainer
@export var _ai_message: HBoxContainer

var chat_id: int = 0

@onready var user_message = _user_message.duplicate()
@onready var ai_message = _ai_message.duplicate()

static var cached_scroller = null

#func reparent_stuff():
	##print(scroller)
	#scroller.set_meta("mlist", _message_list)
	#AIHelpMenu.cached_scroller = scroller
	#remove_child(scroller)
	##scroller.tree_exiting.connect(print.bind("hello"))
#
#func get_stuff():
	##print(AIHelpMenu.cached_scroller)
	#if AIHelpMenu.cached_scroller:
		##var p = scroller.get_parent()
		#scroller.queue_free()
		##p.add_child(AIHelpMenu.cached_scroller)
		#scroller = AIHelpMenu.cached_scroller
		#get_node("ColorRect").add_child(AIHelpMenu.cached_scroller)
		#_message_list = scroller.get_meta("mlist")

func quit(data: Dictionary = {}):
	quitting.emit()
	if can_go:
		hide()
		ui.blur.self_modulate.a = 0
		emitter.res.emit(data)
		#get_parent().remove_child(self)

func re_recv():
	var received = await glob.request_chat(str(chat_id))
	if received:
		for i in received:
			if !i.has("role"): continue
			if i["role"] == "user":
				i.user = true
			elif i["role"] != "system":
				i.text = parser.clean_message(i.text)
				i.user = false
			i.erase("role")
		var new_recv = []
		for i in range(len(_message_list), len(received)):
		#	new_recv.append(received[i])
			add_message(received[i])
	
	
	if get_last_message() and get_last_message().user:
		if glob.message_sockets.has(chat_id):
			var got = glob.get_my_message_state(chat_id, text_receive)
			trect.texture = stop
			if got[0]:
				$ColorRect/Label2.disable()
				got[0].kill.connect(func():
						get_last_message().erase("_pending")
						#print("ff")
						#glob.update_chat_cache(str(chat_id), get_last_message())
						trect.texture = mic_texture
						$ColorRect/Label2.enable())
				#print(got[1])
				add_message({"user": false, "text": got[1]})
	await get_tree().process_frame
	#scroller.queue_sort()
	scroller.force_update_transform()
	#ui.force_layout_update(scroller)
	$ColorRect/ScrollContainer.set("scroll_vertical", $ColorRect/ScrollContainer.get_v_scroll_bar().max_value)




func _ready() -> void:
	super()
	#get_stuff()
	#quitting.connect(reparent_stuff)
	_user_message.queue_free()
	_ai_message.queue_free()
	#set_messages([
	#	{"user": false, "text": "Hi! My name is Axon. I'm here to help & teach you Neural Networks!"},
	#	])
	re_recv()

func text_receive(arr):
	if arr[1]:
		if not get_last_message().get("marked_thinking", false):
			get_last_message().object.set_thinking(true)
		get_last_message()["marked_thinking"] = true
	else:
		get_last_message().object.set_thinking(false)
		get_last_message()["marked_thinking"] = false
		
	get_last_message().text += arr[0]
	get_last_message().object.push_text(arr[0])

func send_message(text: String):
	add_message({"user": true, "text": text})
	glob.update_chat_cache(str(chat_id), _message_list[-1])
	$ColorRect/Label2.disable()
	fixed_mode = true
	add_message({"user": false, "text": "", "_pending": true})
	$ColorRect/Label2._guard = false
	$ColorRect/Label2._clear_text_and_reset()
	var sock = await glob.update_message_stream(text, chat_id, text_receive, glob.def, false)
	$ColorRect/Label2._clear_text_and_reset()
	if sock:
		await sock.kill
	get_last_message().erase("_pending")
	trect.texture = mic_texture
	#print(get_last_message())
	#glob.update_chat_cache(str(chat_id), get_last_message())
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
	new.get_node("txt").set_txt(message.text)
	message.object = new.get_node("txt")


func _just_splash():
	ui.blur.set_tuning(Color(0,0,0,0.5))

var fixed_mode: bool = false
@onready var bs = $ColorRect/ScrollContainer.size.y
func _process(delta: float) -> void:
	if not visible: return
	super(delta)
	var tr = $ColorRect/root/TextureRect
	var bar: VScrollBar = $ColorRect/ScrollContainer.get_v_scroll_bar()
	#bar.offset_left = -3
	$ColorRect/root/TextureRect2.visible = bar.value > 0.1
	#print($ColorRect/ScrollContainer.get_v_scroll_bar().max_value )
	#print($ColorRect/ScrollContainer.get_v_scroll_bar().value )
	#print(fixed_mode)
	if get_last_message():
		get_last_message().get_or_add("timing", [0.0])[0] += delta
	if get_last_message() and get_last_message().get("_pending") and fixed_mode:
		$ColorRect/ScrollContainer.set("scroll_vertical", bar.max_value)
	if glob.mouse_scroll == -1:
		fixed_mode = false
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


func get_last_message():
	return _message_list[-1] if _message_list else null

func get_my_ws():
	return glob.message_sockets.get(chat_id)

func on_send(txt: String) -> void:
	#if get_last_message().has("_pending"):
	#	return
	#print(get_last_message())

	if trect.texture == stop and get_last_message() and get_last_message().has("_pending") and get_my_ws() and not txt and get_last_message().get("timing", [0.0])[0] > 0.1:
		get_my_ws().send(glob.compress_dict_zstd({"stop": true}))
		get_last_message().object.queue_free()
		_message_list.remove_at(-1)
		glob.rem_chat_cache(str(chat_id))
		
		#print("ff")

	if (not get_last_message() or not get_last_message().has("_pending")) and $ColorRect/Label2.text:
		send_message($ColorRect/Label2.text)
		trect.texture = stop
var can_enter: bool = false

@onready var trect = $ColorRect/Label2/train/TextureRect
@onready var mic_texture = $ColorRect/Label2/train/TextureRect.texture
@onready var stop = preload("res://game_assets/icons/stop.png")
var def_texture = preload("res://game_assets/icons/send.png")
func _on_label_2_text_changed() -> void:
	if $ColorRect/Label2.text:
		trect.texture = def_texture
	else:
		trect.texture = mic_texture

func clear_all():
	for i in range(len(_message_list)):
		_message_list[i].object.get_parent().queue_free()
	_message_list.clear()
	$ColorRect/ScrollContainer.set("scroll_vertical", 0)

func _on_cl_released() -> void:
	for i in range(len(_message_list)):
		_message_list[i].object.get_parent().queue_free()
	_message_list.clear()
	glob.clear_chat(chat_id)
	$ColorRect/ScrollContainer.set("scroll_vertical", 0)

extends SplashMenu

@export var _user_message: HBoxContainer
@export var _ai_message: HBoxContainer

@onready var user_message = _user_message.duplicate()
@onready var ai_message = _ai_message.duplicate()
func _ready() -> void:
	super()
	_user_message.queue_free()
	_ai_message.queue_free()
	set_messages([
		{"user": true, "text": "Hi!"}, {"user": false, "text": "**Hi!**"}
		])


func markdown_to_bbcode(input: String) -> String:
	var output := input
	
	# Escape BBCode brackets (optional)
	output = output.replace("[", "[lb]").replace("]", "[rb]")

	# Bold: **text** -> [b]text[/b]
	var bold_re = RegEx.new()
	bold_re.compile(r"\*\*(.+?)\*\*")
	output = bold_re.sub(output, "[b]$1[/b]", true)

	# Italic: *text* -> [i]text[/i]
	var italic_re = RegEx.new()
	italic_re.compile(r"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)") # prevents ** from being caught as *
	output = italic_re.sub(output, "[i]$1[/i]", true)

	# Code: `text` -> [code]text[/code]
	var code_re = RegEx.new()
	code_re.compile(r"`(.+?)`")
	output = code_re.sub(output, "[code]$1[/code]", true)

	return output

@onready var scroller = $ColorRect/ScrollContainer/MarginContainer/VBoxContainer
func set_messages(messages: Array[Dictionary]):
	for message in messages:
		var new = null
		if message.user:
			new = user_message.duplicate()
		else:
			new = ai_message.duplicate()
		scroller.add_child(new)
		new.get_node("txt").text = markdown_to_bbcode(message.text)
			
	


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
	tr.visible = bar.max_value - bar.page > bar.value or $ColorRect/Label2.size.y > 73
	if $ColorRect/Label2.size.y > 73:
		tr.position = $ColorRect/Label2.position + Vector2(0,1)
	else:
		tr.position = $ColorRect/Label2.position - Vector2(0,11)
		


func _on_train_hovering() -> void:
	pass # Replace with function body.


func on_send() -> void:
	pass # Replace with function body.

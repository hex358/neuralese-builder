
extends Control
class_name Quest

func _enter_tree():
	ui.quest = self

@export var scroll_cont: ScrollContainer
@export var row_spacing: float = 8.0

var indexed: Array = []

@onready var cont = $ColorRect/ScrollContainer/c
var types: Dictionary = {}
var _content_h: float = 0.0


func apply_extents():
	var sb = scroll_cont.get_v_scroll_bar()

	var o = scroll_cont.global_position.y + 5.0
	var i = global_position.y + scroll_cont.size.y * scale.y * scroll_cont.scale.y - 10.0
	var maxval = sb.max_value - sb.page - 5.0

	var top = o if sb.value > 5.0 else 0.0
	var bot = i if sb.value < maxval else 0.0
	
	for node in indexed:
		glob.inst_uniform(node, "extents", Vector4(top, bot, 0, 0))

var should_be_visible: Callable = func(): return true
var target_mod: float = 0.0
func _process(_delta: float) -> void:
	if glob.space_just_pressed:
		show_correct()
	if not visible:
		ui.upd_topr_inside(self, false)
		return
	
	if is_waiting:
		target_mod = 1.0 if should_be_visible.call() else 0.0
		next.modulate.a = lerpf(next.modulate.a, target_mod, _delta * 10.0)
		if is_equal_approx(next.modulate.a, 0.0):
			next.hide()
		if target_mod > 0.9:
			next.show()
			next.unblock_input()
		else:
			next.block_input()
	apply_extents()

	if $ColorRect.get_global_rect().has_point(get_global_mouse_position()):
		ui.upd_topr_inside(self, true)
		glob.set_menu_type(self, "o")
	else:
		glob.reset_menu_type(self, "i")
		ui.upd_topr_inside(self, false)


func _snap_layout() -> void:
	var y := 0.0
	for dup in content():
		dup.position.y = y
		y += dup.size.y + row_spacing

	_content_h = y
	cont.custom_minimum_size.y = _content_h


func reindex():
	indexed.clear()
	$ColorRect/ScrollContainer/c.relayout()
	for i in $ColorRect/ScrollContainer/c.get_children():
		indexed.append_array(i.indexed)


func load_bubble(data: Dictionary):
	for i in content():
		i.queue_free()
	
	indexed.clear()
	_snap_layout()
	
	if data:
		return await layout_bubble(data)



var selected_state = {}

signal submit
var child_map = []
var result = {}
var data = {}
var next = null

var is_waiting: bool = false
func layout_bubble(_data: Dictionary) -> Array:
	data = _data
	var classes = glob.to_set("checkbox", "radio")
	var index_map := []
	result.clear()
	child_map.clear()
	var ref = [null]

	var answer_received = func answer_received(on: bool, index: int):
		child_map[index].set_persistent(on)
		var was_empty = result.size() == 0
		if on:
			result[index] = true
		else:
			result.erase(index)
	
	var pressed_once = [false]
	for i in data["elements"]:
		var dup = types[i.type].duplicate()
		dup.abstract = false
		dup.passed_data = i

		dup.size.x = $ColorRect.size.x
		cont.add_child(dup)

		if i.type in classes:
			dup.modulate.a = 0
			dup.toggled.connect(answer_received.bind(len(index_map)))
			index_map.append(i)
			child_map.append(dup)
		if i.type == "next":
			next = dup
			dup.toggled.connect(func(a): 
				pressed_once[0] = true
				)
			dup.hide()
			dup.modulate.a = 0

		dup.root = self
		dup.reinit()
	
	await get_tree().process_frame
	reindex()
	layout()
	await show_anim()
	is_waiting = true
	while not pressed_once[0]:
		await get_tree().process_frame
	pressed_once[0] = false
	is_waiting = false
	
	var correct: bool = false
	if data.flags and data.flags.show_correct:
		show_correct()
		while not pressed_once[0]:
			await get_tree().process_frame
	await hide_anim()
	
	return [result.keys(), correct]

func show_correct():
	for i in len(child_map):
		var unit = child_map[i]
		if i in result:
			if i in data.flags.correct_answers:
				unit.set_valid(BubbleUnit.AnsType.RightSelection)
			else:
				unit.set_valid(BubbleUnit.AnsType.WrongSelection)
		elif i in data.flags.correct_answers:
			unit.set_valid(BubbleUnit.AnsType.WasCorrect)
		else:
			unit.set_valid(BubbleUnit.AnsType.Default)


func layout():
	scroll_cont.get_v_scroll_bar().value = 0
	_snap_layout()
	await get_tree().process_frame
	var is_scrolling = _content_h + 19 > scroll_cont.size.y
	for dup in content():
		dup.size.x = $ColorRect.size.x - (32 if is_scrolling else 18)

		if dup.unit_type in dup.check_dtypes:
			dup.position.x += 3; dup.size.x -= 3
		if dup.unit_type == BubbleUnit.UnitType.Text:
			dup.position.x += 3; dup.size.x -= 10
		dup.reinit()
	_snap_layout()


func content():
	return cont.get_children()


func ask(head: String, options: Array, correct: Array, show_correct: bool = false):
	show()
	var els = [{"type": "text", "text": head}]
	for i in options:
		els.append({"type": "checkbox" if correct.size() > 1 else "radio", "text": i})
	els.append({"type": "next", "text": ""})
	should_be_visible = func(): return result.size() > 0
	var res = await load_bubble({"elements":els, 
	"flags": {"show_correct": show_correct, "correct_answers": correct}})
	return res

func show_anim():
	show()
	$ColorRect.position = Vector2(-30, 0)
	await glob.tween_call({"t": 0},
		func(data, delta): 
			data.t += delta / 1
			$ColorRect.position.x = glob.lerp_expo_out(-30, 0, data.t)
			$ColorRect.modulate.a = glob.lerp_expo_out(0.0, 1.0, data.t)
			if data.t > 1.0:
				return true
			)
	var lerp_call = func(data,delta): 
			data.t += delta / 0.7
			data.obj.modulate.a = glob.lerp_quad(0.0, 1.0, data.t)
			if data.t > 1.0:
				return true
	for i in content():
		if i.unit_type in i.check_dtypes:
			glob.tween_call({"t": 0, "obj": i}, lerp_call)
			await glob.wait(0.3)
			


func hide_anim():
	await glob.tween_call({"t": 0},
		func(data, delta): 
			data.t += delta * 2
			$ColorRect.position.x = glob.lerp_expo_in(0, 30, data.t)
			$ColorRect.modulate.a = glob.lerp_expo_in(1.0, 0.0, data.t)
			if data.t > 1.0:
				return true
			)
	hide()



func _ready() -> void:
	hide()
	$ColorRect.modulate.a = 0
	for i in content():
		types[i.name] = i
		cont.remove_child(i)
		#await get_tree().process_frame

	$ColorRect/ScrollContainer.clip_contents = true
	hide()
	
	#
	#await glob.wait(1)
	#ask("What is the role of an input layer?", 
	#["Performs backpropagation", "Receives raw data and passes it forward", 
	#"Calculates loss", "Applies activation functions"], [1,2], true)


func _on_ai_released() -> void:
	hide()


func _on_item_rect_changed() -> void:
	layout()

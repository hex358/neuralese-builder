extends Control

func _enter_tree():
	ui.quest = self

@export var txt: RichTextLabel
@export var scroll_cont: ScrollContainer

func apply_extents():
	var o = scroll_cont.global_position.y + 5
	var i = global_position.y+scroll_cont.size.y*scale.y*scroll_cont.scale.y + 10
	var maxval = scroll_cont.get_v_scroll_bar().max_value - scroll_cont.get_v_scroll_bar().page - 5
	
	#i = lerp(o, i, clamp(glob.time / 5.0, 0, 1))
	
	for node in indexed:
		glob.inst_uniform(node, "extents", 
		Vector4(o if scroll_cont.get_v_scroll_bar().value > 5 else 0, 
		i if scroll_cont.get_v_scroll_bar().value < maxval else 0, 
		0, 0))
		#print(node.get_instance_shader_parameter("extents"))
		#print(node.name)


func _process(delta: float) -> void:
	if not visible:
		ui.upd_topr_inside(self,false); return
	
	apply_extents()
	if $ColorRect.get_global_rect().has_point(get_global_mouse_position()):
		ui.upd_topr_inside(self,true)
		glob.set_menu_type(self, "o")
	else:
		glob.reset_menu_type(self, "i")
		ui.upd_topr_inside(self,false)
	#print(ui.get_focus())
		#$txt.get_v_scroll_bar().grab_focus()


var indexed = []
func reindex():
	indexed.clear()
	$ColorRect/ScrollContainer/c.relayout()
	for i in $ColorRect/ScrollContainer/c.get_children():
		indexed.append_array(i.indexed)
	#print(indexed)


func load_bubble(data: Dictionary):
	for i in content():
		i.queue_free()
	if data:
		layout_bubble(data)
	reindex()

var selected_state = {}

func layout_bubble(data: Dictionary):
	var last_y: int = 0
	var flags = data.flags
	var classes = glob.to_set("checkbox", "radio")
	var index_map = []; var result = {}
	var answer_received = func answer_received(on: bool, index: int):
		if on:
			result[index] = true
		else:
			result.erase(index)
	for i in data["elements"]:
		var dup = types[i.type].duplicate()
		dup.passed_data = i
		dup.position.y = last_y
		cont.add_child(dup)
		if i.type in classes:
			dup.toggled.connect(answer_received.bind(len(index_map)))
			index_map.append(i)
		#print(dup.size.y)
		last_y = dup.size.y + dup.position.y

func content():
	return cont.get_children()

@onready var cont = $ColorRect/ScrollContainer/c
var types = {}

func _ready() -> void:
	for i in content():
		types[i.name] = i
		cont.remove_child(i)
	#Привет! Сегодня мы построим простой классификатор изображений как на пилотном уроке и изучим то, что делает его ответы интерпретируемыми как вероятности.
	$ColorRect/ScrollContainer.clip_contents = true
	load_bubble({"elements": [
	{"type": "text", "text": "Когда мы запустим модель, то, что получает последний узел, лучше всего описано как..."},
	{"type": "checkbox", "text": "А) Вероятности каждого класса"},
	{"type": "checkbox", "text": "Б) Отношения, сравнивающие классы"},
	{"type": "checkbox", "text": "В) Бинарные значения (либо 0, либо 1)"},
	{"type": "checkbox", "text": "Г) Случайный шум"},
	{"type": "next", "text": ""},
	], "flags": {"show_correct": true, "correct_answers": [1]}})



func _on_ai_released() -> void:
	hide()

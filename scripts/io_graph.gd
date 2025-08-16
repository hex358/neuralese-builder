extends Graph
class_name DynamicGraph

@export var bottom_attached: bool = false
@export var unit: Control
@export var add_button: BlockComponent
@export var input: Control
@export var padding: float = 0.0
@export var line_edit: ValidInput
@export var unit_offset_y: float = 0.0

@onready var _unit = unit.duplicate()


func _unit_modulate_updated(unit: Control, fin: bool = false):
	pass

var connection_paths = []
func _enter_tree():
	for i in unit.get_children():
		if i is Connection:
			connection_paths.append(NodePath(i.name))

@export var target_size: float = 94
var total_size: float = 0.0
var hint_counter: int = 5
var unit_script = null
func _after_ready():
	#total_size += input.size.y
	
	unit.queue_free()
	unit_script = unit.get_script()
	#for i in 100:
	#	add_unit({"text": "hif"})

func _can_drag() -> bool:
	return (! line_edit or not ui.is_focus(line_edit)) and (!add_button or not add_button.state.hovering)

var units = []
var appear_units = {}
var dissapear_units = {}
var offset_units = {}
func _get_unit(kw: Dictionary) -> Control: #virtual
	var dup = _unit.duplicate()
	dup.get_node("Label").text = kw["text"]
	dup.show()
	dup.modulate.a = 0.0
	appear_units[dup] = true
	return dup

func remove_unit(id: int):
	var unit = units[id]; var dec = unit.size.y + padding
	appear_units.erase(unit)
	if glob.cull(unit.global_position, unit.size):
		dissapear_units[unit] = true
	else:
		unit.modulate.a = 0.0
		unit.queue_free()
	total_size -= dec; target_size -= dec
	target_y = total_size
	#units[id].delete()
	units.remove_at(id)
	for i in range(id, len(units)):
		offset_units[units[i]] = (units[i].position.y-dec if units[i].connect_position != null 
		else units[i].connect_position-dec)
		units[i].connect_position = units[i].position.y-dec
		units[i].id -= 1
		if not glob.cull(units[i].global_position, units[i].size):
			units[i].position.y = offset_units[units[i]]
			offset_units.erase(units[i])

var target_y: float = 0.0
func add_unit(kw: Dictionary = {}):
	add_q.append(_add_q.bind(kw))

var add_q: Queue = Queue.new()
func _add_q(kw: Dictionary):
	var new_unit = _get_unit(kw)
	appear_units[new_unit] = true
	new_unit.set_script(unit_script)
	new_unit.id = len(units)
	units.append(new_unit)
	new_unit.position.y = total_size + padding + unit_offset_y
	if bottom_attached:
		new_unit.position.y -= input.size.y
	total_size += new_unit.size.y + padding
	target_y = total_size
	
	#input.position.y = total_size
	target_size += new_unit.size.y + padding
	for path in connection_paths:
		var conn = new_unit.get_node(path)
		hint_counter += 1
		conn.hint = hint_counter
		conn.parent_graph = self
#	graphs.increment_z_counter(3)
	add_child(new_unit)
	if not glob.cull(new_unit.global_position, new_unit.size):
		new_unit.modulate.a = 1.0
		appear_units.erase(new_unit)
		#_unit_modulate_updated(new_unit)

func _after_process(delta: float):
	for i in 100:
		if add_q.empty(): break
		var popped = add_q.pop()
		popped.call()
	var to_del = []
	for appearer in appear_units:
		appearer.modulate.a = lerpf(appearer.modulate.a, 1.0, 10.0*delta)
		if appearer.modulate.a > 0.9:
			appearer.modulate.a = 1.0
			to_del.append(appearer)
			_unit_modulate_updated(appearer, true)
		else:
			_unit_modulate_updated(appearer, false)
	for unit in to_del:
		appear_units.erase(unit)
	to_del = []
	for dissapearer in dissapear_units:
		dissapearer.modulate.a = lerpf(dissapearer.modulate.a, 0.0, 20.0*delta)
		if dissapearer.modulate.a < 0.1:
			dissapearer.modulate.a = 0
			dissapearer.queue_free()
			to_del.append(dissapearer)
			_unit_modulate_updated(dissapearer, true)
		else:
			_unit_modulate_updated(dissapearer, false)
	for unit in to_del:
		dissapear_units.erase(unit)
	to_del = []
	for unit in offset_units:
		var target = offset_units[unit]
		unit.position.y = lerpf(unit.position.y, target, delta*20.0)
		if abs(target - unit.position.y) < 1:
			unit.position.y = target
			to_del.append(unit)
	for unit in to_del:
		offset_units.erase(unit)
	
	if bottom_attached:
		input.position.y = lerpf(input.position.y, target_y, delta*20.0)
	rect.size.y = lerpf(rect.size.y, target_size, delta*20.0)
	if ui.is_focus(line_edit):
		hold_for_frame()


func _on_color_rect_2_pressed() -> void:
	if line_edit.is_valid:
		#ui.click_screen(line_edit.global_position + Vector2(10,10))
		line_edit.grab_focus()
		add_unit({"text": line_edit.text})
		line_edit.clear()

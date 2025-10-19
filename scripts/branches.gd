extends DynamicGraph

var name_graph: String = ""

var unit_keys = {}
func _useful_properties() -> Dictionary:
	return {}



func _request_save():
	pass
	#set_name_graph(name_graph)

func dis():
	$Label2.hide()


var manually: bool = false


func _map_properties(pack: Dictionary):
	pass


	#set_loss_type(str(node.graph_id), "mse")
	#print("A!")




func _process(delta: float) -> void:
	super(delta)
	#if glob.space_just_pressed:
		#print(_useful_properties())

func _just_attached(other_conn: Connection, my_conn: Connection):
	pass


func set_pellets(pellets):
	hold_for_frame()
	for unit in len(units):
		remove_unit(0)
	for pellet in pellets:
		add_unit({"text": pellet})
	#print(prev_branches)
	#print(old_units)
	#print(prev_branches)
	#print(unit_keys)
	#for j in branch_ends:
	#	var title = j.get_title()
	#	var loss = prev_by_title.get(title, "mse")
	#	set_loss_type(str(j.graph_id), loss)



func _get_unit(kw: Dictionary) -> Control: #virtual
	var dup = _unit.duplicate()
	dup.get_node("i").hint = randf_range(0,999999)
	dup.get_node("i").repoll_accepted()
	#print(dup.get_node("i")._accepted_datatypes)
	dup.get_node("i").dynamic = false
	dup.get_node("Control/Label").text = kw["text"]
	dup.show()
	dup.modulate.a = 0.0
	appear_units[dup] = true
	#update_config_subfield({"branches/%s"%})
	return dup


func _unit_removal(id: int):
	units[id].get_node("i").queue_free()


var meta_owner: Graph = null
func push_meta(who: Graph, data):
	meta_owner = who
	var gathered = []
	for i in data["outputs"]:
		gathered.append(i.label)
	set_pellets(gathered)

func unpush_meta():
	meta_owner = null
	set_pellets([])


func _ready() -> void:
	super()

extends Graph

func _can_drag() -> bool:
	return !$TextureRect.mouse_inside and not run.is_mouse_inside()

func get_raw_values():
	var width: int = $TextureRect.image.get_width()
	var total: int = $TextureRect.image.get_width() * $TextureRect.image.get_height()
	var res = []
	for y in width:
		#var row = []
		for x in width:
			res.append($TextureRect.get_pixel(Vector2(x,y)).r)
		#res.append(row)
	return res


#func _connecting(who: Connection, to: Connection):
	#if graphs._reach_input(to.parent_graph):
		#


func get_netname():
	for i in get_first_ancestors():
		if i.server_typename == "ModelName":
			return i
	return null

func _just_connected(who: Connection, to: Connection):
	#if to.parent_graph.server_typename == "Flatten":
	#	to.parent_graph.set_count(cfg.rows * cfg.columns)
	#if graphs._input_origin_graph == null:
	#	graphs._input_origin_graph = self
	graphs.push_2d(28, 28, to.parent_graph)



@onready var run = $run
func _just_disconnected(who: Connection, to: Connection):
	pass
	#if graphs._input_origin_graph == self:
	#	graphs._input_origin_graph = null
	#graphs.unpush_2d(to.parent_graph)

func graph_updated():
	if running:
	#	print("a")
		nn.send_inference_data(self, {"full_graph": graphs.get_syntax_tree(self)})

func _useful_properties() -> Dictionary:
	#print("A")
	return {"raw_values": get_raw_values(), "config": {"rows": 28, "columns": 28, 
		"subname": "Input2D"}, "shape": 28*28}

func repr():
	var tensorified: PackedStringArray = []
	tensorified.append(str(image_dims.x))
	tensorified.append(str(image_dims.y))
	return base_dt + "(" + "x".join(tensorified) + ")"

func validate(pack: Dictionary):
#	print(pack)
	return base_dt == pack.get("datatype", "") and pack.get("x", 0) == image_dims.x and pack.get("y", 0) == image_dims.y


var running: bool = false
var cd: float = 0.0
func _process(delta: float) -> void:
	super(delta)
	#if glob.space_just_pressed:
		#print("export")
	#	print(graphs.get_syntax_tree(self))
		#web.POST("export", {"user": "n", "pass": "1", "graph": graphs.get_syntax_tree(self),
		#"context": str(self.context_id), "scene_id": glob.get_project_id()})
#	print(cd)
	if nn.is_infer_channel(self) and $TextureRect.drawing > 0.01 and cd < 0.01:
		cd = 0.3
		nn.send_inference_data(self, useful_properties())
	if cd >= 0.0:
		cd -= delta
	else:
		cd = 0.0
	#if glob.space_just_pressed:
	#	print(graphs.get_syntax_tree(self))

func _proceed_hold() -> bool:
	if running: return true
	return false

var image_dims = Vector2i(1,1)
func _after_ready() -> void:
	super()
	graphs._input_origin_graph = self
	image_dims = Vector2i($TextureRect.image.get_width(), $TextureRect.image.get_height())

func set_state_open():
	running = true
	run_but.text_offset.x = 0
	match glob.get_lang():
		"kz":
			run_but.text = "Тоқта"
		"ru":
			run_but.text = "Стоп"
		_:
			run_but.text = "Stop"


@onready var run_but = $run
func _on_run_released() -> void:
	if not nn.is_infer_channel(self):
		cd = 2.0
		if await nn.open_infer_channel(self, close_runner, run_but):
			running = true
			run_but.text_offset.x = 0
			match glob.get_lang():
				"kz":
					run_but.text = "Тоқта"
				"ru":
					run_but.text = "Стоп"
				_:
					run_but.text = "Stop"
	else:
		#run_but.text = "Run!"
		#run.text_offset.x = 2
		#running = false
		nn.close_infer_channel(self)
	await glob.wait(2, true)
	hold_for_frame()

func close_runner():
	run_but.text_offset.x = 2
	run_but.text = "Run!"
	running = false
	nn.close_infer_channel(self)

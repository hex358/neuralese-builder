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

func _useful_properties() -> Dictionary:
	#print("A")
	return {"raw_values": get_raw_values(), "config": {"rows": 28, "columns": 28, 
		"subname": "Input2D"},}

var running: bool = false
func _process(delta: float) -> void:
	super(delta)
	#if glob.space_just_pressed:
		#print("export")
	#	web.POST("export", {"user": "n", "pass": "1", "graph": graphs.get_syntax_tree(self),
	#	"context": self.context_id, "scene_id": glob.get_project_id()})
	if nn.is_infer_channel(self) and glob.space_just_pressed:
		nn.send_inference_data(self, useful_properties())
	#if glob.space_just_pressed:
	#	print(graphs.get_syntax_tree(self))

var image_dims = Vector2i(1,1)
func _after_ready() -> void:
	super()
	graphs._input_origin_graph = self
	image_dims = Vector2i($TextureRect.image.get_width(), $TextureRect.image.get_height())


@onready var run_but = $run
func _on_run_released() -> void:
	if not nn.is_infer_channel(self):
		running = true
		run_but.text_offset.x = 0
		run_but.text = "Stop"
		nn.open_infer_channel(self, close_runner)
	else:
		#run_but.text = "Run!"
		#run.text_offset.x = 2
		#running = false
		nn.close_infer_channel(self)

func close_runner():
	run_but.text_offset.x = 2
	run_but.text = "Run!"
	running = false
	nn.close_infer_channel(self)

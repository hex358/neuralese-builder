extends Control

@export var base: Control = null

var _base = null
func _ready() -> void:
	_base = base.duplicate()
	base.queue_free()
	push_cfg({})
	
func push_cfg(cfg: Dictionary):
	$Label2.text = cfg.get("name", "")
	$Label3.text = glob.compact(cfg.get("size", 0)) if "size" in cfg else ""
	#print(cfg)
	var who = $ScrollContainer/VBoxContainer
	for child in who.get_children():
		child.queue_free()
	for i in cfg.get("input_hints", []):
		var new_child = _base.duplicate()
		new_child.get_node("name").text = i.name
		new_child.get_node("value").text = i.get("value", "")
		new_child.get_node("dtype").text = i.get("dtype", "")
		who.add_child(new_child)

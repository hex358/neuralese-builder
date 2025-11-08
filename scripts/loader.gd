extends Control

@export var table: VirtualTable

func _ready() -> void:
	var data := []
	for r in 100_000:
		var row := []
		row.append({"type": "text", "text": str(r)})
		for c in 2:
			row.append({"type": "text", "text": "R%s C%s" % [r, c]})
		data.append(row)

	table.load_dataset(data, 3, 100000)
	
	table.set_column_ratios(PackedFloat32Array([0.1, 0.45, 0.45]))

func _process(delta: float) -> void:
	if glob.space_just_pressed:
		var a = (table.get_row_at_position(table.get_local_mouse_position()))
		if a != -1:
			table.remove_row(a)
		#var t = Time.get_ticks_msec()
		#var row := []
		#row.append({"type": "text", "text": "0"})
		#for c in 2:
			#row.append({"type": "text", "text": "regegres"})
		#
		#table.add_row(row, 99990)
		#await get_tree().process_frame
		#print(glob.get_process_delta_time())
		#t = Time.get_ticks_msec()
	#	table.scroll_to_row(49999, "center")
	#	print(Time.get_ticks_msec() - t)
			

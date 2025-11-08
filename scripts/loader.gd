extends Control

@export var table: VirtualTable

func _ready() -> void:
	var data := []
	for r in 50000:
		var row := []
		for c in 2:
			row.append({"type": "text", "text": "R%s C%s" % [r, c]})
		data.append(row)

	table.load_dataset(data, 2, 50000)

	table.set_column_ratios(PackedFloat32Array([1/3.0, 1/3.0, 1/3.0]))
	var row := []
	for c in 2:
		row.append({"type": "text", "text": "R%s C%s" % [c, 799]})
	table.add_row(row)

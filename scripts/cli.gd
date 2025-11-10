extends CodeEdit

var parser := Commands.CommandParser.new()

@export var table: VirtualTable = null
var dataset: Array = []
@export var console: RichTextLabel

var ct: int = -1


# ===============================
# ======= DATASET BRIDGE ========
# ===============================

func connect_ds(ds: Array):
	dataset = ds

func dataset_updated(force_full: bool = false):
	if table == null:
		return
	if force_full or table.rows != dataset.size():
		table.load_dataset(dataset, (dataset[0].size() if dataset.size() > 0 else 0), dataset.size())
	else:
		table.refresh_dataset(true)


func debug_print(text: String):
	ct += 1
	console.append_text("[color=gray][%d][/color] %s\n" % [ct, text])


# ===============================
# ======= MAIN INPUT LOOP =======
# ===============================

func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and event.keycode == KEY_ENTER:
		var line = text.strip_edges().strip_escapes()
		if line == "":
			return
		compile()
		var result = parser.parse(line)
		if result.has("error"):
			debug_print("[color=coral]" + result["error"] + "[/color]")
		else:
			var cmd_name = result["command"]
			var def: Commands.CommandDef = parser.registry[cmd_name]
			def.handler.call(result)
		await get_tree().process_frame
		clear()


# ===============================
# ======= COMMAND REGISTRY ======
# ===============================

func _ready():
	table.ds_cleared.connect(func(): dataset = table.dataset)
	compile()


func compile():
	syntax_highlighter.define_group("commands", syntax_highlighter.C_CMD, 
		["filter", "shuffle", "drop", "addrow", "removerow", "setcols"])
	syntax_highlighter.define_group("meta", syntax_highlighter.C_META, 
		["begin", "commit", "undo", "redo"])
	syntax_highlighter.define_group("arguments", syntax_highlighter.C_ARG, 
		["col", "row", "as", "by", "on"])

	parser.registry.clear()
	
	# FILTER
	parser.register(Commands.CommandDef.new(
		"filter",
		_on_filter_command,
		[],
		["keep-even", "drop-empty"],
		"Filters dataset rows based on condition.\n   filter if row > 5\n   filter drop if col == 0",
		false,
		["keep", "drop"],
		false
	))

	# SHUFFLE
	parser.register(Commands.CommandDef.new(
		"shuffle",
		_on_shuffle_command,
		[],
		[],
		"Randomly shuffles dataset rows.",
		false,
		[],
		true
	))

	# DROP
	parser.register(Commands.CommandDef.new(
		"drop",
		_on_drop_command,
		[],
		[],
		"Drops dataset entirely.",
		false,
		[],
		true
	))

	# ADDROW
	parser.register(Commands.CommandDef.new(
		"addrow",
		_on_addrow_command,
		[],
		[],
		"Adds or inserts a new row.\nExamples:\n   addrow text(text=\"hi\")\n   addrow 3 text(text=\"hi\")",
		false,
		[],
		false
	))

	# REMOVEROW
	parser.register(Commands.CommandDef.new(
		"removerow",
		_on_removerow_command,
		[],
		[],
		"Removes row by index. Example:\n   removerow 3",
		false,
		[],
		false
	))
	
	parser.register(Commands.CommandDef.new(
		"setcols",
		_on_setcols_command,
		[],
		[],
		"Sets all column names.\nExamples:\n   setcols name age salary\n   setcols name,age,salary",
		false,
		[],
		false
	))


func _on_setcols_command(_data: Dictionary):
	var line = text.strip_edges().strip_escapes()
	var parts = line.split(" ", false)

	if parts.size() < 2:
		debug_print("[color=coral]Usage: setcols <name1> <name2> ... or comma-separated.[/color]")
		return

	# join everything after "setcols"
	var cols_str = line.substr(line.find(parts[0]) + parts[0].length()).strip_edges()
	var raw_names = cols_str.replace(",", " ").split(" ", false)

	var col_names: Array = []
	for n in raw_names:
		var clean = n.strip_edges()
		if clean != "":
			col_names.append(clean)

	if col_names.is_empty():
		debug_print("[color=coral]No valid column names provided.[/color]")
		return
	
	var cols = len(col_names)
	# rebuild dataset columns to match new layout
	for r in dataset:
		var new_r = []
		for i in cols:
			if i >= len(r):
				new_r.append(r[len(r)-1])
			else:
				new_r.append(r[i])
		r.clear()
		for i in new_r:
			r.append(i)
#	print(dataset[0])
	# update table metadata (assuming it keeps columns count)
	table.cols = cols
	table.set_column_names(col_names)
	var float32 = PackedFloat32Array()
	float32.resize(table.cols)
	float32.fill(1.0 / table.cols)
	table.set_column_ratios(float32)
	table._rebuild_column_metrics()
	
	table._need_layout = true
	table._need_visible_refresh = true
	#dataset_updated(true)
	#print(table.cols)
	debug_print("Columns set to: %s" % str(col_names))



# ---- FILTER ----
func _on_filter_command(data: Dictionary):
	var cond = data["args"].get("condition", "")
	var action = data["args"].get("action", "keep")

	if cond == "":
		debug_print("Filter: no condition provided.")
		return

	var expr = Expression.new()
	if expr.parse(cond, ["row"]) != OK:
		debug_print("Invalid expression: %s" % expr.get_error_text())
		return

	var new_ds: Array = []
	for row in dataset:
		var ok = expr.execute([row])
		if (ok and action == "keep") or (not ok and action == "drop"):
			new_ds.append(row)

	dataset = new_ds
	dataset_updated(true)
	debug_print("Filter applied. Rows: %d" % dataset.size())


# ---- SHUFFLE ----
func _on_shuffle_command(_data: Dictionary):
	dataset.shuffle()
	dataset_updated(true)
	debug_print("Dataset shuffled.")


# ---- DROP ----
func _on_drop_command(_data: Dictionary):
	dataset.clear()
	dataset_updated(true)
	debug_print("Dataset dropped.")



func _parse_inline_cells(expr: String) -> Array:
	var cells: Array = []
	var buf := ""
	var depth := 0
	var inside_token := false

	for ch in expr:
		if ch == "(":
			depth += 1
			buf += ch
			inside_token = true
		elif ch == ")":
			depth -= 1
			buf += ch
		elif (ch == " " or ch == ",") and depth == 0:
			if buf.strip_edges() != "":
				cells.append(buf.strip_edges())
				buf = ""
				inside_token = false
		else:
			buf += ch
			if not inside_token and not ch == " ":
				inside_token = true

	if buf.strip_edges() != "":
		cells.append(buf.strip_edges())

	# Now convert text-like tokens into dictionaries
	var parsed: Array = []
	for part in cells:
		var m = part.find("(")
		var type = ""
		var args = {}

		if m == -1:
			type = part
			args = table.get_type_default(type)
			if not args: continue
			args["type"] = type
			parsed.append(args)
			continue

		type = part.substr(0, m)
		var inside = part.substr(m + 1, part.length() - m - 2)
		args = table.get_type_default(type)
		if not args: continue
		args["type"] = type
		var key_0 = args.keys()[0] if args.size() > 0 else "value"

		if inside != "":
			var pairs = inside.split(",", false)
			for p in pairs:
				var kv = p.strip_edges().split("=", false)
				if kv.size() == 2:
					args[kv[0].strip_edges()] = kv[1].strip_edges().trim_prefix("\"").trim_suffix("\"")
				elif kv.size() == 1:
					args[key_0] = kv[0].strip_edges().trim_prefix("\"").trim_suffix("\"")

		parsed.append(args)

	return parsed


func _on_addrow_command(_data: Dictionary):
	var line = text.strip_edges().strip_escapes()
	var parts = line.split(" ", false)
	if parts.size() < 2:
		# empty row
		if table.cols > 0:
			debug_print("[color=coral]Cannot add row: no cells provided.[/color]")
		else:
			debug_print("[color=coral]Cannot add row: table has no columns defined.[/color]")
		return

	var idx = -1
	var row_expr = ""

	if parts[1].is_valid_int():
		idx = int(parts[1])
		row_expr = line.substr(line.find(parts[1]) + parts[1].length()).strip_edges()
	else:
		row_expr = line.substr(line.find(parts[0]) + parts[0].length()).strip_edges()

	var cells = _parse_inline_cells(row_expr)
	#print(table.cols)
	#print(table.cols)
	
	if table.cols > 0 and cells.size() != table.cols:
		debug_print("[color=coral]Row rejected: expected %d columns, got %d.[/color]" % [table.cols, cells.size()])
		return

	
	table.add_row(cells, idx)

	#if idx == -1:
		#dataset.append(cells)
	debug_print("Row appended.")
	#else:
		#idx = clamp(idx, 0, dataset.size())
		#dataset.insert(idx, cells)
		#debug_print("Row inserted at %d." % idx)

	#dataset_updated(true)
	dataset = table.adapter_data


# ---- REMOVEROW ----
func _on_removerow_command(data: Dictionary):
	var parts = text.strip_edges().split(" ", false)
	if parts.size() < 2:
		debug_print("Usage: removerow <index>")
		return
	var idx = int(parts[1])
	#print(table.adapter_data)
	if idx < 0 or idx >= dataset.size():
		debug_print("Invalid row index.")
		return
	table.remove_row(idx)
	debug_print("Row removed at %d." % idx)
	dataset = table.adapter_data

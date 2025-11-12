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
			await get_tree().process_frame
			clear()
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
		["filter", "shuffle", "drop", "nrow", "drow", "cols", "keep", "outs", "acol", "dcol", "conv"])
	syntax_highlighter.define_group("meta", syntax_highlighter.C_META, 
		["begin", "commit", "undo", "redo"])
	syntax_highlighter.define_group("arguments", syntax_highlighter.C_ARG, 
		["col", "row", "as", "by", "on", "if"])

	parser.registry.clear()
	
	# FILTER
	parser.register(Commands.CommandDef.new(
		"filter",
		_on_filter_command,
		[],
		[],
		"Filters dataset rows based on condition.\n   filter if row > 5\n   filter drop if col == 0",
		false,
		["keep", "drop"],
		false
	))

	parser.register(Commands.CommandDef.new(
		"acol",
		_on_acol_command,
		[],
		[],
		"Adds a new column. Can append or insert by index.\nExamples:\n   acol salary:num\n   acol 0 salary:num\n   acol -1 id:txt",
		false,
		[],
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

	# nrow
	parser.register(Commands.CommandDef.new(
		"nrow",
		_on_nrow_command,
		[],
		[],
		"Adds or inserts a new row.\nExamples:\n   nrow text(text=\"hi\")\n   nrow 3 text(text=\"hi\")\n   nrow text:hi",
		false,
		[],
		true
	))

	parser.register(Commands.CommandDef.new(
		"dcol",
		_on_dcol_command,
		[],
		[],
		"Deletes a column by index.\nExample:\n   dcol 2",
		false,
		[],
		false
	))

	parser.register(Commands.CommandDef.new(
		"outs",
		_on_outs_command,
		[],
		[],
		"Sets output range to begin from specified column ID\nExample:\n   outs 2",
		false,
		[],
		false
	))


	# drow
	parser.register(Commands.CommandDef.new(
		"drow",
		_on_drow_command,
		[],
		[],
		"Removes row by index. Example:\n   drow 3",
		false,
		[],
		false
	))
	
	parser.register(Commands.CommandDef.new(
		"cols",
		_on_cols_command,
		[],
		["force"],
		"Sets all column names.\nExamples:\n   cols name:txt age:num salary:num\n   cols name:txt,age:num,salary:num",
		false,
		[],
		false
	))

	parser.register(Commands.CommandDef.new(
		"conv",
		_on_convert_command,
		[],
		["force"],
		"Converts a column’s datatype by index.\nExample:\n   conv 2 txt",
		false,
		[],
		false
	))



func _on_dcol_command(_data: Dictionary):
	var parts = text.strip_edges().split(" ", false)
	if parts.size() < 2:
		debug_print("[color=coral]Usage: dcol <column_index>[/color]")
		return

	var idx_str = parts[1]
	if not idx_str.is_valid_int():
		debug_print("[color=coral]Column index must be an integer.[/color]")
		return

	var col_idx = int(idx_str)
	if col_idx < -table.cols or col_idx >= table.cols:
		debug_print("[color=coral]Invalid column index %d.[/color]" % col_idx)
		return
	if col_idx < 0:
		col_idx += table.cols
	#print(col_idx)
	# Remove from dataset
	for row in dataset:
		if col_idx < row.size():
			row.remove_at(col_idx)

	# Update table metadata
	var col_names: Array = table.dataset_obj.get("col_names", [])
	if col_idx < col_names.size():
		col_names.remove_at(col_idx)
	table.dataset_obj["col_names"] = col_names
	#print(col_names)
	
	table.set_column_names(col_names)
	dataset_updated()

func _on_outs_command(_data: Dictionary):
	var parts = text.strip_edges().split(" ", false)
	if parts.size() < 2:
		debug_print("[color=coral]Usage: dcol <column_index>[/color]")
		return

	var idx_str = parts[1]
	if not idx_str.is_valid_int():
		debug_print("[color=coral]Column index must be an integer.[/color]")
		return

	var col_idx = int(idx_str)
	if col_idx < -table.cols or col_idx >= table.cols:
		debug_print("[color=coral]Invalid column index %d.[/color]" % col_idx)
		return
	if col_idx == 0:
		debug_print("[color=coral]Dataset must have at least 1 input column.[/color]")
		return
	#if col_idx == table.cols:
		#debug_print("[color=coral]Dataset must have at least 1 output column.[/color]" % col_idx)
		#return
	
	table.set_outputs_from(col_idx)
	debug_print("Output format changed.")

func _convert_column(col_idx: int, to_dtype: String, force: bool = false) -> bool:
	if to_dtype not in type_map:
		debug_print("[color=coral]Unknown datatype: %s[/color]" % to_dtype)
		return false
	var dtype = type_map[to_dtype]

	if col_idx < -table.cols or col_idx >= table.cols:
		debug_print("[color=coral]Invalid column index %d.[/color]" % col_idx)
		return false
	if col_idx < 0:
		col_idx += table.cols
#	print(dtype)
	if table.column_datatypes[col_idx] == dtype:
		debug_print("[color=coral]Datatype didn't change.[/color]" % col_idx)
		return true

	var convs: Array = []
	var cant: Array = []
	var is_range: int = 0

	#print(new_names)

	for y in range(dataset.size()):
		var converted = table.convert_cell(y, col_idx, dtype)
		if not "ok" in converted: 
			converted = table.get_type_default(dtype)
			converted["type"] = dtype
		if not force and not converted.get("ok", false):
			is_range += 1
			if is_range == 1:
				cant.append([y, 1])
			else:
				cant[-1][1] = is_range
			continue
		is_range = 0
		converted.erase("ok")
		convs.append(converted)
	
	if cant:
		var cant_str = ""
		for j in len(cant):
			var i = cant[j]
			if i[1] == 1:
				cant_str += str(i[0])
			else:
				cant_str += str(i[0]) + "-" + str(i[1]+i[0])
			if j != len(cant)-1:
				cant_str += ", "
		var err = "[color=coral]Cannot convert these rows: %s\nUse --force flag to override.[/color]" % cant_str
		debug_print(err)
		return false

	for y in range(len(convs)):
		dataset[y][col_idx] = convs[y]

	dataset_updated(true)
	debug_print("Converted column %d → %s" % [col_idx, dtype])
	var new_names = []
	for i in table.cols:
		if i == col_idx:
			new_names.append(table.column_names[i] + ":" +  dtype)
		else:
			new_names.append(table.column_names[i] + ":" +  table.column_datatypes[i])
	table.set_column_names(new_names)
	table.dataset_obj["col_names"] = new_names
	if table.rows:
		table.re_uni()
		table.types_changed = false
	return true


func _on_acol_command(_data: Dictionary):
	var parts = text.strip_edges().split(" ", false)
	if parts.size() < 2:
		debug_print("[color=coral]Usage: acol [index] <name>:<type>[/color]")
		return

	var insert_at: int = table.cols  # default append mode
	var token: String

	# detect index
	if parts[1].is_valid_int() and parts.size() >= 3:
		insert_at = int(parts[1])
		token = parts[2]
	else:
		token = parts[1]

	var splited = token.rsplit(":", true, 1)
	if splited.size() != 2:
		debug_print("[color=coral]Column format must be name:type. Example: acol salary:num[/color]")
		return

	var col_name = splited[0].strip_edges()
	var dtype_key = splited[1].strip_edges()
	if dtype_key not in type_map:
		debug_print("[color=coral]Unknown datatype: %s[/color]" % dtype_key)
		return
	var dtype = type_map[dtype_key]

	# clamp index safely
	if insert_at < 0:
		insert_at = table.cols + insert_at + 1
	insert_at = clamp(insert_at, 0, table.cols)

	# copy current column names
	var old_names: Array = table.dataset_obj.get("col_names", [])
	var new_col_names: Array = old_names.duplicate()

	var full_name = "%s:%s" % [col_name, dtype]
	new_col_names.insert(insert_at, full_name)

	# Extend each row deterministically
	for r in dataset:
		var def = table.get_type_default(dtype)
		if def == null:
			debug_print("[color=coral]Type %s is not supported by VirtualTable.[/color]" % dtype)
			return
		def["type"] = dtype
		r.insert(insert_at, def)

	# Update metadata and layout
	table.cols = new_col_names.size()
	table.set_column_names(new_col_names, true)
	table.dataset_obj["col_names"] = new_col_names

	var ratios = PackedFloat32Array()
	ratios.resize(table.cols)
	ratios.fill(1.0 / table.cols)
	table.set_column_ratios(ratios)
	table._rebuild_column_metrics()
	table._need_layout = true
	table._need_visible_refresh = true

	dataset_updated(true)
	debug_print("Inserted column '%s' of type %s at index %d." % [col_name, dtype, insert_at])




func _on_convert_command(_data: Dictionary):
	var parts = text.strip_edges().split(" ", false)
	var force: bool = _data["flags"].has("force")

	if parts.size() < 3:
		debug_print("[color=coral]Usage: conv <column_index> <to_dtype>[/color]")
		return

	var idx_str = parts[1]
	if not idx_str.is_valid_int():
		debug_print("[color=coral]Column index must be an integer.[/color]")
		return
	var col_idx = int(idx_str)
	var to_dtype = parts[2]
	
	if table.rows:
		_convert_column(col_idx, to_dtype, force)





func _on_cols_command(_data: Dictionary):
#	print(table.column_datatypes)
	var line = text.strip_edges().strip_escapes()
	var parts = line.split(" ", false)

	if parts.size() < 2:
		debug_print("[color=coral]Usage: cols <name1> <name2> ... or comma-separated [--force] [/color]")
		return

	var cols_str = line.substr(line.find(parts[0]) + parts[0].length()).strip_edges()
	var raw_names = cols_str.replace(",", " ").split(" ", false)

	var col_names: Array = []
	for n in raw_names:
		var clean = n.strip_edges()
		if clean != "" and clean != "--force":
			col_names.append(clean)
	
	var force: bool = _data["flags"].has("force")
	if col_names.is_empty():
		debug_print("[color=coral]No valid column names provided.[/color]")
		return
	#print(table.column_datatypes)
	var dtypes = []
	for j in len(col_names):
		var i = col_names[j]
		var splited = i.rsplit(":", true, 1)
		if len(splited) > 1 and splited[-1] in type_map:
			dtypes.append(type_map[splited[-1]])
			var dtype = type_map[splited[-1]]
			col_names[j] = ":".join(splited.slice(0, len(splited) - 1)) + ":" + dtype

			if table.rows and table.column_datatypes.size() > j and dtype != table.column_datatypes[j]:
				if not force:
					debug_print("[color=coral]Column datatype mismatch at column %d. Use --force to autoconvert.[/color]" % j)
					return
				else:
					debug_print("[color=gray]Auto-converting column %d to %s...[/color]" % [j, dtype])
					_convert_column(j, splited[-1], true)
		else:
			debug_print("[color=coral]Columns have to own a type. Example: name:txt[/color]")
			return
	
	var cols = len(col_names)
	#var types = []
	for r in dataset:
		var new_r = []
		for i in cols:
			if i >= len(r):
				var type = dtypes[i]
				var def = table.get_type_default(type)
				def["type"] = type
				new_r.append(def)
			else:
				new_r.append(r[i])
		r.clear()
		for i in new_r:
			r.append(i)
#	print(dataset[0])
	# update table metadata (assuming it keeps columns count)
	table.cols = cols
	table.set_column_names(col_names, true)
	#print(table.column_datatypes)
	#print(col_names)
	table.dataset_obj["col_names"] = col_names
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

	#if cond == "":
		## Run filter flags without condition
		#if data["flags"].is_empty():
			#debug_print("Filter: no condition or flags provided.")
			#return
		#debug_print("Filter flags applied: %s" % str(data["flags"]))
		#return

	var expr = Expression.new()
	#print(cond)
	if expr.parse(cond, ["row"]) != OK:
		debug_print("Invalid expression: %s" % expr.get_error_text())
		return

	var new_ds: Array = []
	for row in len(dataset):
		var ok = expr.execute([row])
		if (ok and action == "keep") or (not ok and action == "drop"):
			new_ds.append(dataset[row])
	dataset = new_ds
	if new_ds:
		table.load_dataset(dataset, table.cols, len(new_ds))
	else:
		table.load_empty_dataset(true, dataset)
	#dataset_updated(true)
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



var type_map = {"txt": "text", "num": "num", "img": "image", "text": "text", "str": "text", "int": "num", "image": "image"}
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

	var parsed: Array = []

	for part in cells:
		part = part.strip_edges()

		if ":" in part and "(" not in part:
			var segs = part.split(":", false)
			if segs.size() == 2:
				var type = segs[0].strip_edges()
				type = type_map.get(type, type)
				var val = segs[1].strip_edges().trim_prefix("\"").trim_suffix("\"")

				var args = table.get_type_default(type)
				if not args:
					continue
				args["type"] = type
				var key_0 = args.keys()[0] if args.size() > 0 else "value"
				args[key_0] = val
				parsed.append(args)
				continue

		var m = part.find("(")
		var type = ""
		var args = {}

		if m == -1:
			type = type_map.get(part, part)
			args = table.get_type_default(type)
			if not args:
				continue
			args["type"] = type
			parsed.append(args)
			continue

		type = part.substr(0, m)
		type = type_map.get(type, type)
		var inside = part.substr(m + 1, part.length() - m - 2)
		args = table.get_type_default(type)
		if not args:
			continue
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



func _on_nrow_command(_data: Dictionary):
	var line = text.strip_edges().strip_escapes()
	var parts = line.split(" ", false)

	if parts.size() == 1:
		if not table or table.cols == 0:
			debug_print("[color=coral]Cannot add row: table has no columns defined.[/color]")
			return
		var default_row = table.get_default_row()
		if default_row == null:
			debug_print("[color=coral]Table returned no default row definition.[/color]")
			return
		table.add_row(default_row)
		dataset = table.adapter_data
		debug_print("Default row appended.")
		return

	var idx = -1
	var row_expr = ""

	if parts[1].is_valid_int():
		idx = int(parts[1])
		row_expr = line.substr(line.find(parts[1]) + parts[1].length()).strip_edges()
	else:
		row_expr = line.substr(line.find(parts[0]) + parts[0].length()).strip_edges()

	# Case 2: explicit cells provided
	if row_expr == "":
		# No explicit cell expression after nrow → fallback to default
		var default_row = table.get_default_row()
		if default_row == null:
			debug_print("[color=coral]Cannot add row: table.get_default_row() returned null.[/color]")
			return
		table.add_row(default_row, idx)
		dataset = table.adapter_data
		debug_print("Default row inserted at %d." % (idx if idx != -1 else dataset.size() - 1))
		return

	var cells = _parse_inline_cells(row_expr)
	
	if table.cols > 0 and cells.size() != table.cols:
		debug_print("[color=coral]Row rejected: expected %d columns, got %d.[/color]" % [table.cols, cells.size()])
		return

	table.add_row(cells, idx)
	dataset = table.adapter_data
	debug_print("Row appended.")



func _on_drow_command(data: Dictionary):
	var parts = text.strip_edges().split(" ", false)
	if parts.size() < 2:
		debug_print("Usage: drow <index>")
		return
	var idx = int(parts[1])
	#print(table.adapter_data)
	if idx < 0 or idx >= dataset.size():
		debug_print("Invalid row index.")
		return
	table.remove_row(idx)
	debug_print("Row removed at %d." % idx)
	dataset = table.adapter_data

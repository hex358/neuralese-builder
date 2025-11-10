extends Node

func _normalize_newlines(raw: String) -> String:
	return raw.replace("\r\n", "\n").replace("\r", "\n")


func detect_csv_delimiter_from_preview(preview_text: String) -> String:
	var candidate_delimiters = [",", ";", "\t", "|", " "]
	var lines: Array[String] = []
	preview_text = _normalize_newlines(preview_text)

	for line in preview_text.split("\n", false):
		line = line.strip_edges()
		if line == "":
			continue
		lines.append(line)
		if lines.size() >= 100:
			break

	if lines.size() < 2:
		return ","

	var best_delim := ","
	var best_score := -INF

	for delim in candidate_delimiters:
		var total_occurrences := 0
		var counts: Array[int] = []

		for line in lines:
			var occ := line.count(delim)
			total_occurrences += occ
			counts.append(line.split(delim, false).size())

		if total_occurrences == 0:
			continue

		var mean := 0.0
		for c in counts:
			mean += c
		mean /= float(counts.size())

		var variance := 0.0
		for c in counts:
			variance += abs(c - mean)
		variance /= float(counts.size())

		var score := ((mean - 1.0) * total_occurrences) / (1.0 + variance)
		if score > best_score:
			best_score = score
			best_delim = delim

	return best_delim

func parse_csv_lines(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Failed to open CSV: " + path)
		return []

	var preview_text := ""
	var max_bytes := 200_000
	var read_bytes := 0
	while not file.eof_reached() and read_bytes < max_bytes:
		var chunk := file.get_buffer(min(4096, max_bytes - read_bytes))
		if chunk.size() == 0:
			break
		var s := chunk.get_string_from_utf8()
		preview_text += s
		read_bytes += chunk.size()
	file.seek(0)

	var detected_delim := detect_csv_delimiter_from_preview(preview_text)
	print("Detected CSV delimiter:", detected_delim)

	var rows: Array = []
	var buffer := ""

	while not file.eof_reached():
		var chunk := file.get_buffer(8192)
		if chunk.size() == 0:
			break

		buffer += chunk.get_string_from_utf8()
		buffer = _normalize_newlines(buffer)

		var ends_with_newline := buffer.ends_with("\n")
		var parts := buffer.split("\n", false)

		if not ends_with_newline:
			buffer = parts[-1]
			parts.remove_at(-1)
		else:
			buffer = ""

		for line in parts:
			line = line.strip_edges()
			if line != "":
				rows.append(line.split(detected_delim, false))

	if buffer.strip_edges() != "":
		rows.append(buffer.strip_edges().split(detected_delim, false))

	file.close()
	return rows

func _row_to_cells(row: Array) -> Array[Dictionary]:
	var res: Array[Dictionary] = []
	for i in row:
		res.append({"type": "text", "text": i})
	return res

func parse_csv_dataset(path: String) -> Dictionary:
	var ds_obj = {"col_names": [], "arr": []}
	var rows = parse_csv_lines(path)
	if len(rows) == 1:
		ds_obj.col_names = ["Input", "Output"]
		ds_obj.arr.append(_row_to_cells(rows[0]))
		return ds_obj
	ds_obj.col_names = rows[0]
	for i in range(1,len(rows)):
		ds_obj.arr.append(_row_to_cells(rows[i]))
	return ds_obj

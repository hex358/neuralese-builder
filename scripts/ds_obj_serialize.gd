extends Node
class_name DsObjRLE

# =========================
# Tunables
# =========================
const BLOCK_ROWS: int = 1024
# How many consecutive blocks to re-encode immediately after a change,
# to make readers of rle_cache see the fresh data without a heavy suffix rebuild.
const FAST_REBUILD_BLOCKS: int = 1  # 1 block ~= 1024 rows; tune to 2–4 if you want a wider visible window

# =========================
# Preview (unchanged API)
# =========================
static func get_preview(dataset_obj: Dictionary, validate_cols: bool = false) -> Dictionary:
	if not dataset_obj or not dataset_obj.has("arr"):
		return {"fatal": "no_dataset"}
	var arr: Array = dataset_obj["arr"]
	if arr.is_empty():
		return {"fatal": "empty"}
	var cols: int = (arr[0].size() if arr.size() > 0 else 0)
	if cols <= 0:
		return {"fatal": "no_columns"}
	var col_names: Array = dataset_obj.get("col_names", [])
	if col_names.is_empty():
		return {"fatal": "missing_schema"}

	var col_dtypes: Array = []
	for name in col_names:
		var parts = name.rsplit(":", true, 1)
		col_dtypes.append(parts[1] if parts.size() > 1 else "text")

	var outputs_from: int = dataset_obj.get("outputs_from", 1)
	var cache_cols: Array = dataset_obj.get("cache", {}).get("cols", [])
	if cols == 1:
		return {"fail": "no_outputs"}

	var res: Dictionary = {
		"size": arr.size(),
		"name": dataset_obj.get("name", "unnamed"),
		"input_hints": [],
	}

	# outputs
	var cur_out = {"label_names": [], "datatype": "1d", "x": 0, "label": "Output"}
	for i in range(outputs_from, cols):
		if i >= col_dtypes.size() or col_dtypes[i] == "image":
			return {"fail": "no_1d_outs"}
		cur_out["label_names"].append(col_names[i].split(":")[0])
	res["outputs"] = [cur_out]

	# inputs
	var inputs: Dictionary = {"datatype": "", "x": 0}
	var to_validate = -1
	for i in range(0, max(1, outputs_from)):
		var dt = col_dtypes[i]
		if dt == "image":
			if inputs["datatype"]:
				return {"fail": "mix_2d"}
			inputs["datatype"] = "2d"
			to_validate = i
		else:
			if inputs["datatype"] == "2d":
				return {"fail": "mix_2d"}
			inputs["datatype"] = "1d(len:1)"
			inputs["x"] += 1
			res["input_hints"].append({
				"name": col_names[i].split(":")[0],
				"value": ds_to_val(dataset_obj, i),
				"dtype": col_dtypes[i]
			})

	# image validation (if first input is image)
	if to_validate != -1:
		if cache_cols.is_empty() or to_validate >= cache_cols.size():
			return {"fail": "bad_img"}
		var got_col_container = cache_cols[to_validate]
		var got: Dictionary = {}
		if got_col_container.size() == 1 and got_col_container.has(0):
			got = got_col_container[0]
		else:
			got = got_col_container
		if got.is_empty() or got.size() != 1 or got.keys()[0] == 0:
			return {"fail": "bad_img"}
		var key: int = got.keys()[0]
		var xs = key >> 16
		var ys = key & 0xFFFF
		if xs <= 0 or ys <= 0:
			return {"fail": "bad_img"}
		res["input_hints"].append({
			"name": col_names[to_validate].split(":")[0],
			"value": str(xs) + "x" + str(ys),
			"dtype": "image"
		})
	return res

# =========================
# Helpers / header
# =========================
static func _derive_col_dtypes(col_names: Array) -> Array:
	var col_dtypes: Array = []
	for n in col_names:
		var spl = n.rsplit(":", true, 1)
		col_dtypes.append(spl[1] if spl.size() > 1 else "text")
	return col_dtypes

static func _ensure_cache(name: String) -> Dictionary:
	if not glob.rle_cache.has(name):
		glob.rle_cache[name] = {}
	var cache = glob.rle_cache[name]
	if not cache.has("header"):
		cache["header"] = {}
	if not cache.has("data"):
		cache["data"] = [[], []]
	if not cache["header"].has("dirty_from"):
		cache["header"]["dirty_from"] = -1
	# Delta journal for O(1) edits
	if not cache.has("deltas"):
		cache["deltas"] = []   # list of {op: "insert"|"delete"|"update", row?, count?, rows?}
	if not cache.has("meta"):
		cache["meta"] = {"base_version": 0}
	return cache

static func _mark_dirty_from(cache: Dictionary, row_idx: int) -> void:
	var hdr = cache["header"]
	if not hdr.has("dirty_from") or hdr["dirty_from"] == -1:
		hdr["dirty_from"] = row_idx
	else:
		hdr["dirty_from"] = min(hdr["dirty_from"], row_idx)
	cache["header"] = hdr

static func _clear_dirty(cache: Dictionary) -> void:
	cache["header"]["dirty_from"] = -1

static func ds_to_val(dataset_obj: Dictionary, col_idx: int) -> String:
	var col_dtypes = dataset_obj.get("col_dtypes", [])
	var col_args = dataset_obj.get("col_args", [])
	if col_idx >= col_dtypes.size():
		return "_"
	var dt = col_dtypes[col_idx]
	var args = {}
	if col_idx < col_args.size():
		args = col_args[col_idx].duplicate(true)
	var default_argpacks = {
		"text": {},
		"num": {"min": 0, "max": 100},
		"image": {},
		"float": {}
	}
	args.merge(default_argpacks.get(dt, {}), true)
	match dt:
		"num":
			var min_v = args.get("min", 0)
			var max_v = args.get("max", 100)
			return str(min_v) + "-\n" + str(max_v)
		"float":
			return "0..1"
		"text":
			return "_"
		_:
			return "_"

# =========================
# Encoders (unchanged signatures)
# =========================
static func encode_partial_column(ds: Dictionary, col: int, from_row: int, to_row: int) -> PackedByteArray:
	var dtypes = ds.get("col_dtypes", [])
	if col >= dtypes.size():
		return PackedByteArray()
	var dtype = dtypes[col]
	match dtype:
		"num":   return encode_int_column_partial(ds, col, from_row, to_row)
		"float": return encode_float_column_partial(ds, col, from_row, to_row)
		"text":  return encode_text_column_partial(ds, col, from_row, to_row)
		"image": return encode_image_column_partial(ds, col, from_row, to_row)
		_:       return PackedByteArray()

static func encode_int_column_partial(ds: Dictionary, col: int, from_row: int, to_row: int) -> PackedByteArray:
	var args: Dictionary = {}
	if ds.has("col_args") and col < ds["col_args"].size():
		args = ds["col_args"][col]
	var mn: int = int(args.get("min", 0))
	var mx: int = int(args.get("max", 100))
	var rangev = max(1, mx - mn)
	var bits = clamp(int(ceil(log(rangev + 1) / log(2.0))), 1, 32)

	var bp = glob.BitPacker.new()
	var arr: Array = ds["arr"]
	for r in range(from_row, to_row):
		var v: int = int(arr[r][col].get("num", 0))
		bp.push(v - mn, bits)
	return bp.to_bytes()

static func encode_float_column_partial(ds: Dictionary, col: int, from_row: int, to_row: int) -> PackedByteArray:
	var out = PackedByteArray()
	var arr: Array = ds["arr"]
	out.resize(to_row - from_row)
	for i in range(from_row, to_row):
		var v: float = float(arr[i][col].get("val", 0.0))
		out[i - from_row] = clamp(int(v * 255.0), 0, 255)
	return out

static func encode_text_column_partial(ds: Dictionary, col: int, from_row: int, to_row: int) -> PackedByteArray:
	var out = PackedByteArray()
	var arr: Array = ds["arr"]
	for r in range(from_row, to_row):
		var s = str(arr[r][col].get("text", ""))
		out.append_array(s.to_utf8_buffer())
		out.append(0)
	return out

static func encode_image_column_partial(ds: Dictionary, col: int, from_row: int, to_row: int) -> PackedByteArray:
	var out = PackedByteArray()
	var arr: Array = ds["arr"]
	for r in range(from_row, to_row):
		var cell = arr[r][col]
		if cell.has("img") and cell["img"] != null:
			var img: Image = cell["img"].get_image()
			out.append_array(img.get_data())
	return out

# =========================
# RLE
# =========================
static func rle_encode_into(src: PackedByteArray) -> PackedByteArray:
	if src.is_empty():
		var out = PackedByteArray(); out.append(0); return out
	var rle = PackedByteArray()
	var last = src[0]
	var count = 1
	for i in range(1, src.size()):
		var v = src[i]
		if v == last and count < 65535:
			count += 1
		else:
			rle.append(count >> 8); rle.append(count & 0xFF); rle.append(last)
			last = v; count = 1
	rle.append(count >> 8); rle.append(count & 0xFF); rle.append(last)

	if rle.size() + 1 < src.size() + 1:
		var out1 = PackedByteArray(); out1.append(1); out1.append_array(rle); return out1
	else:
		var out2 = PackedByteArray(); out2.append(0); out2.append_array(src); return out2

# =========================
# Public API
# =========================

# Full initial baseline build (no deltas)
static func compress_blocks(ds: Dictionary) -> Dictionary:
	var arr: Array = ds["arr"]
	if arr.is_empty():
		return {"header": {"rows": 0, "inputs_count": 0, "outputs_count": 0, "columns": {}, "dirty_from": -1}, "data": [[], []], "deltas": [], "meta": {"base_version": 1}}

	var rows: int = arr.size()
	var cols: int = arr[0].size()
	var outputs_from: int = ds.get("outputs_from", 0)
	ds["col_dtypes"] = _derive_col_dtypes(ds.get("col_names", []))

	var header = {
		"rows": rows,
		"inputs_count": outputs_from,
		"outputs_count": cols - outputs_from,
		"columns": {},
		"rows_per_block": BLOCK_ROWS,
		"dirty_from": -1,
	}

	var inputs: Array = []
	var outputs: Array = []

	for c in range(cols):
		var dtype: String = ds["col_dtypes"][c]
		var col_blocks: Array = []
		var hashes: Array = []

		var start_row = 0
		while start_row < rows:
			var end_row = min(start_row + BLOCK_ROWS, rows)
			var raw = encode_partial_column(ds, c, start_row, end_row)
			var enc = rle_encode_into(raw)
			var hv: int = hash(enc)
			var u := (hv if hv >= 0 else (hv + (1 << 63) * 2))
			var h = String.num_uint64(u, 16)
			col_blocks.append(enc)
			hashes.append(h)
			start_row = end_row

		var col_data = {"blocks": col_blocks, "hashes": hashes, "rows_per_block": BLOCK_ROWS, "dtype": dtype}
		if c < outputs_from:
			inputs.append(col_data)
		else:
			outputs.append(col_data)

		var meta = {"dtype": dtype}
		if dtype == "num":
			var args := {}
			if ds.has("col_args"):
				var col_args: Array = ds["col_args"]
				if c < col_args.size():
					args = col_args[c]
			meta["min"] = int(args.get("min", 0))
			meta["max"] = int(args.get("max", 100))
		header["columns"][str(c)] = meta

	return {"header": header, "data": [inputs, outputs], "deltas": [], "meta": {"base_version": 1}}

# One-shot full flush (optional — call on export/save)
static func flush_now(name: String, ds: Dictionary) -> void:
	var rebuilt = compress_blocks(ds)
	var cache = _ensure_cache(name)
	rebuilt["meta"]["base_version"] = int(cache["meta"].get("base_version", 0)) + 1
	glob.rle_cache[name] = rebuilt

# === Bounded-local refresh to make edits visible without global recompression ===
static func _refresh_blocks(name: String, ds: Dictionary, start_block: int, block_count: int) -> void:
	var cache = _ensure_cache(name)
	if cache.is_empty() or not cache.has("header") or not cache.has("data"):
		# bootstrap
		glob.rle_cache[name] = compress_blocks(ds)
		return

	var rows: int = ds["arr"].size()
	var cols: int = (ds["arr"][0].size() if rows > 0 else 0)
	var inputs_count: int = int(cache["header"].get("inputs_count", 0))
	var outputs_count: int = int(cache["header"].get("outputs_count", max(0, cols - inputs_count)))
	var rows_per_block: int = int(cache["header"].get("rows_per_block", BLOCK_ROWS))

	var total_blocks = int(ceil(max(1.0, float(rows)) / float(rows_per_block)))
	var b0 = clamp(start_block, 0, total_blocks - 1)
	var bN = clamp(b0 + max(1, block_count), 1, total_blocks)

	# helpers as lambdas (Godot rule: assign then .call)
	var rebuild_range := func(side_prev: Array, base_col_idx: int, count: int) -> Array:
		var side_new: Array = []
		for i in range(count):
			var col_idx = base_col_idx + i
			var dtype: String = ds["col_dtypes"][col_idx]
			var prev_col: Dictionary = (side_prev[i] if i < side_prev.size() else {"blocks": [], "hashes": [], "rows_per_block": rows_per_block, "dtype": dtype})
			var blocks: Array = prev_col.get("blocks", []).duplicate(false)
			var hashes: Array = prev_col.get("hashes", []).duplicate(false)
			if blocks.size() < total_blocks:
				blocks.resize(total_blocks)
				hashes.resize(total_blocks)
			for b in range(b0, bN):
				var start_row = b * rows_per_block
				var end_row = min(start_row + rows_per_block, rows)
				var raw: PackedByteArray
				match dtype:
					"num":   raw = encode_int_column_partial(ds, col_idx, start_row, end_row)
					"float": raw = encode_float_column_partial(ds, col_idx, start_row, end_row)
					"text":  raw = encode_text_column_partial(ds, col_idx, start_row, end_row)
					"image": raw = encode_image_column_partial(ds, col_idx, start_row, end_row)
					_:      raw = PackedByteArray()
				var enc = rle_encode_into(raw)
				var hv: int = hash(enc)
				var u := (hv if hv >= 0 else (hv + (1 << 63) * 2))
				var h = String.num_uint64(u, 16)
				blocks[b] = enc
				hashes[b] = h
			side_new.append({
				"blocks": blocks,
				"hashes": hashes,
				"rows_per_block": rows_per_block,
				"dtype": dtype
			})
		return side_new

	var prev_inputs: Array = cache["data"][0]
	var prev_outputs: Array = cache["data"][1]
	var new_inputs = rebuild_range.call(prev_inputs, 0, inputs_count)
	var new_outputs = rebuild_range.call(prev_outputs, inputs_count, outputs_count)

	# patch header (cheap)
	var new_header = cache["header"].duplicate(true)
	new_header["rows"] = rows
	new_header["rows_per_block"] = rows_per_block
	if not ds.has("col_dtypes"):
		ds["col_dtypes"] = _derive_col_dtypes(ds.get("col_names", []))
	for c in range(cols):
		var dtype = ds["col_dtypes"][c]
		if not new_header["columns"].has(str(c)):
			new_header["columns"][str(c)] = {}
		new_header["columns"][str(c)]["dtype"] = dtype
		if dtype == "num":
			var args := {}
			if ds.has("col_args"):
				var col_args: Array = ds["col_args"]
				if c < col_args.size():
					args = col_args[c]
			new_header["columns"][str(c)]["min"] = int(args.get("min", 0))
			new_header["columns"][str(c)]["max"] = int(args.get("max", 100))

	glob.rle_cache[name] = {"header": new_header, "data": [new_inputs, new_outputs], "deltas": cache.get("deltas", []), "meta": cache.get("meta", {"base_version": 0})}

# =========================
# Incremental API (unchanged signatures)
# =========================

# NOTE: This now appends a delta (O(1)) AND does a tiny local block refresh so readers see the change.
static func recompress_changed_blocks(ds: Dictionary, changed_rows: Array) -> Dictionary:
	var name = ds.get("name", "unnamed")
	var cache = _ensure_cache(name)

	# keep header rows in sync with live ds
	cache["header"]["rows"] = ds["arr"].size()

	# ensure schema info is present
	if not ds.has("col_dtypes"):
		ds["col_dtypes"] = _derive_col_dtypes(ds.get("col_names", []))
	if not cache["header"].has("columns"):
		cache["header"]["columns"] = {}

	# journal the update (row-level modifications)
	if changed_rows != null and changed_rows is Array and changed_rows.size() > 0:
		cache["deltas"].append({"op": "update", "rows": (changed_rows as Array).duplicate(), "ts": Time.get_ticks_msec()})

		# budgeted local refresh: rebuild only touched blocks, bounded
		var rows_per_block: int = int(cache["header"].get("rows_per_block", BLOCK_ROWS))
		var mn := 1 << 30
		for r in changed_rows:
			var rr = int(r)
			if rr >= 0:
				mn = min(mn, rr)
		if mn != (1 << 30):
			var start_block = mn / rows_per_block
			_refresh_blocks(name, ds, start_block, FAST_REBUILD_BLOCKS)

	glob.rle_cache[name] = _ensure_cache(name)
	return glob.rle_cache[name]

static func delete_rows(dataset_obj: Dictionary, name: String, del_from: int, del_to: int) -> void:
	var cache = _ensure_cache(name)
	var arr: Array = dataset_obj["arr"]
	var total_rows = arr.size()
	del_from = clamp(del_from, 0, total_rows)
	del_to   = clamp(del_to, del_from, total_rows)
	var count = max(0, del_to - del_from)
	if count <= 0:
		return

	cache["deltas"].append({"op": "delete", "row": del_from, "count": count, "ts": Time.get_ticks_msec()})
	_mark_dirty_from(cache, del_from)
	cache["header"]["rows"] = dataset_obj["arr"].size()

	# budgeted local refresh for visibility
	var rows_per_block: int = int(cache["header"].get("rows_per_block", BLOCK_ROWS))
	var start_block = del_from / rows_per_block
	_refresh_blocks(name, dataset_obj, start_block, FAST_REBUILD_BLOCKS)

	glob.rle_cache[name] = cache

static func insert_rows(dataset_obj: Dictionary, name: String, insert_at: int, new_rows: Array) -> void:
	var cache = _ensure_cache(name)
	var arr: Array = dataset_obj["arr"]
	var total_rows_before = arr.size() - max(0, (new_rows.size() if new_rows is Array else 0)) # heuristic; caller mutates arr first usually
	insert_at = clamp(insert_at, 0, max(0, total_rows_before))
	var count = (new_rows.size() if new_rows is Array else 1)
	if count <= 0:
		count = 1

	cache["deltas"].append({"op": "insert", "row": insert_at, "count": count, "ts": Time.get_ticks_msec()})
	_mark_dirty_from(cache, insert_at)
	cache["header"]["rows"] = dataset_obj["arr"].size()

	# budgeted local refresh for visibility (most inserts you do are at top => block 0 refresh)
	var rows_per_block: int = int(cache["header"].get("rows_per_block", BLOCK_ROWS))
	var start_block = insert_at / rows_per_block
	_refresh_blocks(name, dataset_obj, start_block, FAST_REBUILD_BLOCKS)

	glob.rle_cache[name] = cache

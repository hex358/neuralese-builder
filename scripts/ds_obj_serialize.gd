extends Node
class_name DsObjRLE


static func get_preview(dataset_obj: Dictionary, validate_cols: bool = false) -> Dictionary:
	if not dataset_obj or not dataset_obj.has("arr"):
		return {"fatal": "no_dataset"}

	var arr: Array = dataset_obj["arr"]
	if arr.is_empty():
		return {"fatal": "empty"}

	var cols: int = len(arr[0]) if arr.size() > 0 else 0
	var rows: int = arr.size()
	if cols <= 0:
		return {"fatal": "no_columns"}

	var col_names: Array = dataset_obj.get("col_names", [])
	if col_names.is_empty():
		return {"fatal": "missing_schema"}

	# Derive col_dtypes from col_names dynamically
	var col_dtypes: Array = []
	for name in col_names:
		var parts = name.rsplit(":", true, 1)
		col_dtypes.append(parts[1] if parts.size() > 1 else "text")

	var outputs_from: int = dataset_obj.get("outputs_from", 1)
	var cache_cols: Array = dataset_obj.get("cache", {}).get("cols", [])

	if cols == 1:
		return {"fail": "no_outputs"}

	var res: Dictionary = {
		"size": rows,
		"name": dataset_obj.get("name", "unnamed"),
		"input_hints": [],
	}

	# ------------------ outputs ------------------
	var cur_out = {
		"label_names": [],
		"datatype": "1d",
		"x": 0,
		"label": "Output"
	}
	for i in range(outputs_from, cols):
		if i >= col_dtypes.size() or col_dtypes[i] == "image":
			return {"fail": "no_1d_outs"}
		cur_out["label_names"].append(col_names[i].split(":")[0])
	res["outputs"] = [cur_out]

	# ------------------ inputs -------------------
	var inputs: Dictionary = {"datatype": "", "x": 0}
	var to_validate := -1
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

	# ------------------ image validation -------------------
	if to_validate != -1:
		if cache_cols.is_empty() or to_validate >= cache_cols.size():
			return {"fail": "bad_img"}

		var got_col_container = cache_cols[to_validate]
		# Sometimes VirtualTable nests column cache in {0: {...}}
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



# --- helpers ---

static var _default_argpacks = {
	"text": {},
	"num": {"min": 0, "max": 100},
	"image": {},
	"float": {},
}

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


static func encode_image_column(dataset_obj: Dictionary, col: int) -> PackedByteArray:
	var out := PackedByteArray()
	var arr: Array = dataset_obj["arr"]
	var rows: int = arr.size()

	for r in range(rows):
		var cell = arr[r][col]
		if not cell.has("img") or cell["img"] == null:
			continue
		var img: Image = cell["img"].get_image()
		var data: PackedByteArray = img.get_data()
		var pixel_count = img.get_width() * img.get_height()
		var idx := 0
		for p in range(pixel_count):
			var r8 = data[idx]
			var g8 = data[idx + 1]
			var b8 = data[idx + 2]
			var gray = int(0.299 * r8 + 0.587 * g8 + 0.114 * b8)
			out.append(gray)
			idx += 3
	return out


static func encode_float_column(dataset_obj: Dictionary, col: int) -> PackedByteArray:
	var out := PackedByteArray()
	var arr: Array = dataset_obj["arr"]
	var rows: int = arr.size()
	out.resize(rows)
	for r in range(rows):
		var v: float = float(arr[r][col].get("val", 0.0))
		out[r] = clamp(int(v * 255.0), 0, 255)
	return out


static func encode_int_column(dataset_obj: Dictionary, col: int) -> PackedByteArray:
	var args: Dictionary = {}
	if dataset_obj.has("col_args") and col < dataset_obj["col_args"].size():
		args = dataset_obj["col_args"][col]
	var mn: int = int(args.get("min", 0))
	var mx: int = int(args.get("max", 100))
	var range = max(1, mx - mn)
	var bits = clamp(int(ceil(log(range + 1) / log(2.0))), 1, 32)

	var bp = glob.BitPacker.new()
	var arr: Array = dataset_obj["arr"]
	var rows: int = arr.size()

	for r in range(rows):
		var v: int = int(arr[r][col].get("num", 0))
		bp.push(v - mn, bits)

	return bp.to_bytes()


static func rle_encode_into(src: PackedByteArray) -> PackedByteArray:
	if src.is_empty():
		var out := PackedByteArray()
		out.append(0) # flag = raw
		return out

	var rle := PackedByteArray()
	var last := src[0]
	var count := 1
	for i in range(1, src.size()):
		var v := src[i]
		if v == last and count < 65535:
			count += 1
		else:
			rle.append(count >> 8)
			rle.append(count & 0xFF)
			rle.append(last)
			last = v
			count = 1
	rle.append(count >> 8)
	rle.append(count & 0xFF)
	rle.append(last)

	# choose compressed only if smaller
	if rle.size() + 1 < src.size() + 1:
		var out := PackedByteArray()
		out.append(1) # flag = compressed
		out.append_array(rle)
		return out
	else:
		var out := PackedByteArray()
		out.append(0) # flag = raw
		out.append_array(src)
		return out


static func compress_and_send(dataset_obj: Dictionary, b64: bool = false) -> Dictionary:
	var arr: Array = dataset_obj["arr"]
	if arr.is_empty():
		return {"header": {}, "data": [[], []]}

	var rows: int = arr.size()
	var cols: int = arr[0].size()
	var outputs_from: int = dataset_obj.get("outputs_from", 0)
	var col_args: Array = dataset_obj.get("col_args", [])
	var col_names: Array = dataset_obj.get("col_names", [])

	# --- derive dtypes from col_names ---
	var dtypes: Array = []
	for n in col_names:
		var spl = n.rsplit(":", true, 1)
		dtypes.append(spl[1] if spl.size() > 1 else "text")

	var inputs_count := outputs_from
	var outputs_count := cols - outputs_from
	var result_inputs := []
	var result_outputs := []
	result_inputs.resize(inputs_count)
	result_outputs.resize(outputs_count)

	var header := {
		"rows": rows,
		"inputs_count": inputs_count,
		"outputs_count": outputs_count,
		"columns": {}
	}

	for c in range(cols):
		var dtype = dtypes[c]
		var meta = {"dtype": dtype}

		if c < col_args.size():
			meta.merge(col_args[c])

		match dtype:
			"num":
				var mn := int(meta.get("min", 0))
				var mx := int(meta.get("max", 0))
				var range = max(1, mx - mn)
				meta["bits"] = clamp(int(ceil(log(range + 1) / log(2.0))), 1, 32)
			"image":
				var first = arr[0][c]
				meta["pixels"] = int(first.get("x", 0)) * int(first.get("y", 0))

		header["columns"][str(c)] = meta

	for c in range(cols):
		var dtype = dtypes[c]
		var raw := PackedByteArray()

		match dtype:
			"num":
				raw = encode_int_column(dataset_obj, c)
			"float":
				raw = encode_float_column(dataset_obj, c)
			"image":
				raw = encode_image_column(dataset_obj, c)
			"text":
				# Always raw UTF-8
				var text_bytes := PackedByteArray()
				for r in range(rows):
					var s = str(arr[r][c].get("text", ""))
					text_bytes.append_array(s.to_utf8_buffer())
					text_bytes.append(0) # null separator for row boundary
				raw = text_bytes

				var encoded = rle_encode_into(raw)
				if b64:
					encoded = Marshalls.raw_to_base64(encoded)

				if c < outputs_from:
					result_inputs[c] = encoded
				else:
					result_outputs[c - outputs_from] = encoded


		var rle = rle_encode_into(raw)
		if b64:
			rle = Marshalls.raw_to_base64(rle)

		if c < outputs_from:
			result_inputs[c] = rle
		else:
			result_outputs[c - outputs_from] = rle

	return {"header": header, "data": [result_inputs, result_outputs]}

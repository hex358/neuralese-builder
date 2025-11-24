extends Node
class_name DsObjProbe


class _BitReader:
	var _data: PackedByteArray
	var _bit_pos: int
	var _total_bits: int
	func _init(buf: PackedByteArray) -> void:
		_data = buf
		_bit_pos = 0
		_total_bits = buf.size() * 8
	func set_pos(bitpos: int) -> void:
		_bit_pos = clamp(bitpos, 0, _total_bits)
	func pop(bits: int) -> int:
		var v = 0
		for i in range(bits):
			var byte_i = _bit_pos >> 3
			if byte_i >= _data.size():
				break
			var bit_i = 7 - (_bit_pos & 7)
			var b = (_data[byte_i] >> bit_i) & 1
			v = (v << 1) | b
			_bit_pos += 1
		return v

# =========================================================
# Probe cache that uses block addressing (no row_ptrs)
# =========================================================
static func probe_dataset(name: String, sample_rows: int = 3, from_row: int = 0, to_row: int = -1) -> Dictionary:
	if not glob.rle_cache.has(name):
		return {"ok": false, "reason": "no cache entry"}

	var cached: Dictionary = glob.rle_cache[name]
	if not cached.has("header") or not cached.has("data"):
		return {"ok": false, "reason": "incomplete cache structure"}

	var header: Dictionary = cached["header"]
	var inputs: Array = cached["data"][0]
	var outputs: Array = cached["data"][1]

	var total_rows: int = int(header.get("rows", 0))
	var rpb: int = int(header.get("rows_per_block", DsObjRLE.BLOCK_ROWS))
	if rpb <= 0:
		rpb = 1024

	# ---- normalize range (negative indices + swap) ----
	if to_row < 0:
		to_row = total_rows + to_row + 1
	if from_row < 0:
		from_row = total_rows + from_row
	if from_row > to_row:
		var t = from_row
		from_row = to_row
		to_row = t
	from_row = clamp(from_row, 0, total_rows)
	to_row = clamp(to_row, 0, total_rows)

	var span: int = max(0, to_row - from_row)
	var rows_to_show: int = min(sample_rows, (span if span > 0 else total_rows))
	if rows_to_show <= 0:
		rows_to_show = 0

	var info = {
		"ok": true,
		"name": name,
		"rows": total_rows,
		"inputs": header.get("inputs_count", inputs.size()),
		"outputs": header.get("outputs_count", outputs.size()),
		"sample": {},
		"errors": [],
	}

	# ---------------- helpers ----------------

	var _rle_decode_adaptive = func(data: PackedByteArray) -> PackedByteArray:
		if data.is_empty():
			return PackedByteArray()
		var flag = data[0]
		var payload = data.slice(1, data.size())
		if flag == 0:
			return payload
		elif flag == 1:
			return rle_decode(payload)
		return payload

	var _get_block_raw = func(col_entry: Dictionary, block_idx: int) -> PackedByteArray:
		var blocks: Array = col_entry.get("blocks", [])
		if block_idx < 0 or block_idx >= blocks.size():
			return PackedByteArray()
		return _rle_decode_adaptive.call(blocks[block_idx])

	var _col_meta = func(col_i: int) -> Dictionary:
		return header.get("columns", {}).get(str(col_i), {})

	# --- numeric bit access at row ---


	# --- typed getters (per logical row) ---
	var _get_num_at = func(col_entry: Dictionary, col_i: int, logical_row: int) -> int:
		var meta: Dictionary = _col_meta.call(col_i)
		var mn: int = int(meta.get("min", 0))
		var mx: int = int(meta.get("max", 100))
		var range: int = max(1, mx - mn)
		var bits: int = clamp(int(ceil(log(range + 1) / log(2.0))), 1, 32)

		var block_idx: int = logical_row / rpb
		var within: int = logical_row - block_idx * rpb
		var buf = _get_block_raw.call(col_entry, block_idx)
		if buf.is_empty():
			return mn

		var br = _BitReader.new(buf)
		br.set_pos(within * bits)
		return br.pop(bits) + mn

	var _get_float_at = func(col_entry: Dictionary, logical_row: int) -> float:
		var block_idx: int = logical_row / rpb
		var within: int = logical_row - block_idx * rpb
		var buf = _get_block_raw.call(col_entry, block_idx)
		if buf.is_empty() or within < 0 or within >= buf.size():
			return 0.0
		return float(buf[within]) / 255.0

	# Text is null-terminated per row; scan to the N-th string in block.
	var _get_text_at = func(col_entry: Dictionary, logical_row: int) -> String:
		var block_idx: int = logical_row / rpb
		var within: int = logical_row - block_idx * rpb
		var buf = _get_block_raw.call(col_entry, block_idx)
		if buf.is_empty():
			return ""
		var idx: int = 0
		var row_i: int = 0
		while idx < buf.size():
			# gather until '\0'
			var start = idx
			while idx < buf.size() and buf[idx] != 0:
				idx += 1
			if row_i == within:
				var slice = buf.slice(start, idx)  # no terminator
				return slice.get_string_from_utf8()
			row_i += 1
			# skip terminator
			idx += 1
		return ""

	# Images are variable length; without per-row size table we only can show a placeholder
	var _get_image_at = func(col_entry: Dictionary, logical_row: int) -> String:
		var block_idx: int = logical_row / rpb
		var buf = _get_block_raw.call(col_entry, block_idx)
		return str(buf.size()) + " bytes img"

	var _extract_preview = func(col_entry: Dictionary, col_i: int, dtype: String) -> Array:
		var out: Array = []
		if rows_to_show <= 0:
			return out
		match dtype:
			"num":
				for k in range(rows_to_show):
					out.append(_get_num_at.call(col_entry, col_i, from_row + k))
			"float":
				for k in range(rows_to_show):
					out.append(_get_float_at.call(col_entry, from_row + k))
			"text":
				for k in range(rows_to_show):
					out.append(_get_text_at.call(col_entry, from_row + k))
			"image":
				# For images: show a coarse indicator
				for k in range(rows_to_show):
					out.append(_get_image_at.call(col_entry, from_row + k))
			_:
				for k in range(rows_to_show):
					out.append("unknown")
		return out

	var _probe_side = func(side: Array, label: String, offset: int):
		var side_samples: Dictionary = {}
		for i in range(side.size()):
			var col_entry: Dictionary = side[i]
			var col_i: int = i + offset
			var dtype: String = str(col_entry.get("dtype", header.get("columns", {}).get(str(col_i), {}).get("dtype", "unknown")))
			var vals: Array = _extract_preview.call(col_entry, col_i, dtype)
			side_samples["col_%d:%s" % [col_i, dtype]] = vals
		info["sample"][label] = side_samples

	_probe_side.call(inputs, "inputs", 0)
	_probe_side.call(outputs, "outputs", int(header.get("inputs_count", 0)))

	return info


# =========================================================
# RLE decode (same as before)
# =========================================================
static func rle_decode(data: PackedByteArray) -> PackedByteArray:
	var out = PackedByteArray()
	var i = 0
	while i + 2 < data.size():
		var count = (data[i] << 8) | data[i + 1]
		var value = data[i + 2]
		for _j in range(count):
			out.append(value)
		i += 3
	return out

extends Control
class_name TableOverlay

var table: VirtualTable

func _ready() -> void:
	anchor_left = 0
	anchor_top = 0
	anchor_right = 1
	anchor_bottom = 1
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	mouse_filter = MOUSE_FILTER_IGNORE
	z_index = 999
	clip_contents = false

func _draw() -> void:
	if not table:
		return
	var vt = table
	if vt.rows <= 0 and vt.cols <= 0:
		return

	# Exact copy of your working code (only "content_margin" taken from vt)
	var left = vt.content_margin.x
	var top = vt.content_margin.y
	var right = vt.content_margin.z
	var bottom = vt.content_margin.w

	var inner_size = vt._content_area.size
	var content_w: float = (vt.col_offsets[vt.cols] if vt.cols > 0 else 0.0)
	var content_h: float = vt._sum_heights

	var view_top: float = vt.scroll_y
	var view_bottom: float = vt.scroll_y + inner_size.y

	var r0 = clamp(vt._find_row_for_y(view_top), 0, max(0, vt.rows - 1))
	var r1 = clamp(vt._find_row_for_y(view_bottom), 0, vt.rows - 1)

#	vt._extend_offsets_to(r1 + 1)
	var header_rect = Rect2(Vector2(left, 0), Vector2(size.x, vt.header_height))
	# HEADER
	if vt.cols > 0 and not vt.column_names.is_empty():
		
		draw_rect(header_rect, vt.header_bg_color, true)


		var font = get_theme_font("font", "Label")
		var fsize = vt.header_font_size
		var offset_x = -vt.scroll_x + left
		for i in range(min(vt.cols, vt.column_names.size())):
			var col_name = vt.column_names[i]
			var text_pos = Vector2(offset_x + 6, header_rect.position.y + header_rect.size.y * 0.6)
			draw_string(font, text_pos, col_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, vt.header_text_color)
			offset_x += vt.col_widths[i]

	# ROW IDS
	if vt.rows > 0:
		var font = get_theme_font("font", "Label")
		var base_fsize = vt.header_font_size
		draw_rect(Rect2(Vector2(0, 0), Vector2(vt.header_width, size.y)), vt.header_bg_color, true)
		for r in range(r0, r1 + 1):
			var y0 = vt.row_offsets[r] - vt.scroll_y + top / 2
			var h = vt.row_heights[r]
			if y0 + h < 0 or y0 > size.y:
				continue

			var cell_rect = Rect2(Vector2(0, y0), Vector2(vt.header_width, h + vt.header_height))

			var label_text = str(r + 1)
			var text_w = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, base_fsize).x

			var pad = 3.0

			var max_w = vt.header_width - pad * 2.0
			var max_h = h - 4.0
			var fsize = base_fsize

			if text_w > max_w:
				var scale_factor = max_w / text_w
				fsize = clamp(fsize * scale_factor, fsize * 0.3, fsize)

			# recalc metrics for current size
			var ascent = font.get_ascent(fsize)
			var descent = font.get_descent(fsize)
			var text_h = ascent + descent
			var y_center = cell_rect.position.y + (h - text_h) * 0.5 + ascent

			# x position slides to 0 when text_w approaches header width
			var x_offset = pad
			var text_pos = Vector2(cell_rect.position.x + x_offset, y_center)

			draw_string(font, text_pos, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, vt.header_text_color)

		draw_rect(Rect2(Vector2(0, 0), Vector2(vt.header_width, vt.header_height)), vt.header_bg_color, true)
		draw_line(Vector2(vt.header_width, vt.header_height), Vector2(vt.header_width, size.y),
				  vt.header_grid_color, vt.grid_line_thickness)

		draw_rect(Rect2(Vector2(0, 0), Vector2(vt.header_width, vt.header_height)), vt.header_bg_color, true)
	#	draw_line(Vector2(vt.header_width, 0), Vector2(vt.header_width, size.y), vt.header_grid_color, vt.grid_line_thickness)
		#draw_line(Vector2(0, vt.header_height), Vector2(size.x, vt.header_height), vt.header_grid_color, vt.grid_line_thickness)
	draw_line(Vector2(0,header_rect.position.y) + Vector2(0, header_rect.size.y),
			  header_rect.position + Vector2(header_rect.size.x, header_rect.size.y),
			  vt.header_grid_color, vt.grid_line_thickness)
	
	if vt.column_width_mode != vt.ColumnWidthMode.RELAXED:
		draw_line(Vector2(0, size.y-vt.grid_line_thickness), Vector2(size.x, size.y-vt.grid_line_thickness), vt.header_grid_color, vt.grid_line_thickness)

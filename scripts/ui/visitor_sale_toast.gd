extends PanelContainer

## Non-modal confirmation for a visitor sale. It renders only the immutable
## presentation payload emitted by VisitorNegotiationManager.
signal dismissed

const AUCTION_PREVIEW := preload("res://scenes/ui/AuctionPreview3D.tscn")
const DISPLAY_SECONDS := 8.0

var _remaining_seconds := DISPLAY_SECONDS

func _ready() -> void:
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)

func present(payload: Dictionary) -> void:
	for child in get_children():
		child.queue_free()
	_remaining_seconds = DISPLAY_SECONDS
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 11)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 7)
	margin.add_child(content)
	var header := HBoxContainer.new()
	content.add_child(header)
	var title := Label.new()
	title.text = "BOUTIQUE · VENTA CERRADA"
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", Color(0.95, 0.78, 0.35))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := Button.new()
	close_button.text = "×"
	close_button.tooltip_text = "Cerrar confirmación de venta"
	close_button.pressed.connect(_dismiss)
	header.add_child(close_button)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	content.add_child(row)
	row.add_child(_make_portrait(payload.get("item", {}) as Dictionary))
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 3)
	row.add_child(copy)
	var item_name := Label.new()
	item_name.text = String(payload.get("item_name", "Pieza vendida"))
	item_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item_name.add_theme_font_size_override("font_size", 16)
	item_name.add_theme_color_override("font_color", Color(0.98, 0.92, 0.8))
	copy.add_child(item_name)
	var price := Label.new()
	price.text = "Precio acordado  %s" % _format_money(int(payload.get("final_price", 0)))
	price.add_theme_font_size_override("font_size", 13)
	price.add_theme_color_override("font_color", Color(0.86, 0.73, 0.43))
	copy.add_child(price)
	var customer := Label.new()
	customer.text = "%s · %s" % [String(payload.get("customer_name", "Cliente")), String(payload.get("profile_name", "Cliente interesado"))]
	customer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	customer.add_theme_font_size_override("font_size", 11)
	customer.add_theme_color_override("font_color", Color(0.7, 0.72, 0.67))
	content.add_child(customer)
	var quote := Label.new()
	quote.text = "“%s”" % String(payload.get("quote", "Gracias por la atención."))
	quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quote.add_theme_font_size_override("font_size", 12)
	quote.add_theme_color_override("font_color", Color(0.8, 0.84, 0.72))
	content.add_child(quote)

func _make_portrait(item: Dictionary) -> Control:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(80, 80)
	frame.add_theme_stylebox_override("panel", _frame_style())
	var image_path := String(item.get("preview_image_path", ""))
	var texture := load(image_path) as Texture2D if not image_path.is_empty() and ResourceLoader.exists(image_path) else null
	if texture != null:
		var image := TextureRect.new()
		image.texture = texture
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(image)
	else:
		var model_path := String(item.get("model_path", ""))
		if not model_path.is_empty() and ResourceLoader.exists(model_path):
			var preview := AUCTION_PREVIEW.instantiate() as Control
			preview.custom_minimum_size = Vector2.ZERO
			preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			frame.add_child(preview)
			preview.call("set_interaction_enabled", false)
			preview.call("set_item_context", String(item.get("item_type", "watch")), String(item.get("category", "")))
			preview.call("set_model_path", model_path)
			return frame
		var fallback := Label.new()
		fallback.text = "PIEZA\nVENDIDA"
		fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fallback.add_theme_font_size_override("font_size", 10)
		fallback.add_theme_color_override("font_color", Color(0.76, 0.68, 0.51))
		frame.add_child(fallback)
	return frame

func _process(delta: float) -> void:
	if _is_paused_for_attention():
		return
	_remaining_seconds -= delta
	if _remaining_seconds <= 0.0:
		_dismiss()

func _is_paused_for_attention() -> bool:
	if get_global_rect().has_point(get_global_mouse_position()):
		return true
	var focus_owner := get_viewport().gui_get_focus_owner()
	return focus_owner != null and (focus_owner == self or is_ancestor_of(focus_owner))

func _dismiss() -> void:
	dismissed.emit()

func _frame_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.075, 0.06)
	style.border_color = Color(0.5, 0.4, 0.24)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	return style

func _format_money(value: int) -> String:
	return "%s €" % value

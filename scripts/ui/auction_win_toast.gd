extends PanelContainer

## Non-blocking acknowledgement for lots that have already entered inventory.
## WorkshopUI owns navigation; this node only presents the awarded lot.
signal dismissed
signal inventory_requested

const AUCTION_PREVIEW := preload("res://scenes/ui/AuctionPreview3D.tscn")
const DISPLAY_SECONDS := 8.0

var _remaining_seconds := DISPLAY_SECONDS

func _ready() -> void:
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)

func present(lot: Dictionary, final_price: int) -> void:
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
	title.text = "SALÓN DE LOTES · ADJUDICADO"
	title.tooltip_text = "Lote adjudicado e incorporado al inventario"
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", Color(0.95, 0.78, 0.35))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := Button.new()
	close_button.text = "×"
	close_button.tooltip_text = "Cerrar aviso de lote adjudicado"
	close_button.accessibility_name = "Cerrar aviso de lote adjudicado"
	close_button.pressed.connect(_dismiss)
	header.add_child(close_button)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	content.add_child(row)
	row.add_child(_make_preview(lot))
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 3)
	row.add_child(copy)
	var name_label := Label.new()
	name_label.text = String(lot.get("name", "Pieza adjudicada"))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color(0.98, 0.92, 0.8))
	copy.add_child(name_label)
	var price := Label.new()
	price.text = "Adquisición  %s" % _format_money(final_price)
	price.add_theme_font_size_override("font_size", 13)
	price.add_theme_color_override("font_color", Color(0.86, 0.73, 0.43))
	copy.add_child(price)
	var confirmation := Label.new()
	confirmation.text = "Ya está en tu inventario"
	confirmation.add_theme_font_size_override("font_size", 13)
	confirmation.add_theme_color_override("font_color", Color(0.8, 0.84, 0.72))
	content.add_child(confirmation)
	var inventory_button := Button.new()
	inventory_button.text = "Ver inventario"
	inventory_button.tooltip_text = "Abrir el inventario de piezas adquiridas"
	inventory_button.accessibility_name = "Ver inventario"
	inventory_button.pressed.connect(_open_inventory)
	content.add_child(inventory_button)

func _make_preview(lot: Dictionary) -> Control:
	var frame := Control.new()
	frame.custom_minimum_size = Vector2(80, 80)
	frame.size = Vector2(80, 80)
	frame.clip_contents = true
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var model_path := String(lot.get("model_path", ""))
	if not model_path.is_empty() and ResourceLoader.exists(model_path):
		var preview := AUCTION_PREVIEW.instantiate() as Control
		preview.custom_minimum_size = Vector2.ZERO
		preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		frame.add_child(preview)
		preview.call("set_interaction_enabled", false)
		preview.call("set_item_context", String(lot.get("item_type", "watch")), String(lot.get("category", "")))
		preview.call("set_model_path", model_path)
	else:
		var fallback := Label.new()
		fallback.text = "PIEZA\nADQUIRIDA"
		fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fallback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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

func _open_inventory() -> void:
	inventory_requested.emit()

func _format_money(value: int) -> String:
	return "%s €" % value

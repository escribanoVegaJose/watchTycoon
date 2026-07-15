extends "res://scripts/ui/commerce_panel.gd"

## Standalone presentation for acquired pieces and display placement.
## Inventory mutations remain owned by GameState and placement controllers.

const HISTORY_FILTER_AVAILABLE := "available"
const HISTORY_FILTER_DISPLAY := "display"
const HISTORY_FILTER_SOLD := "sold"
const HISTORY_FILTER_ALL := "all"

var _history_filter := HISTORY_FILTER_AVAILABLE

func _ready() -> void:
	add_to_group("inventory_panel")
	z_index = 20
	visible = false
	_build_ui()
	EventBus.inventory_changed.connect(_on_inventory_changed)
	EventBus.stats_changed.connect(_on_stats_changed)
	EventBus.purchase_history_changed.connect(_on_purchase_history_changed)
	EventBus.watch_display_changed.connect(_on_watch_display_changed)
	EventBus.carried_watch_changed.connect(_on_carried_watch_changed)
	get_node("/root/SettingsManager").connect(&"language_changed", _on_language_changed)

func open() -> void:
	_store_scroll_position()
	_active_scroll = null
	visible = true
	_active_tab = "inventory"
	_render()
	call_deferred("_focus_close_button")

func _render() -> void:
	_store_scroll_position()
	for child in _content.get_children():
		child.queue_free()
	var header := HBoxContainer.new()
	_content.add_child(header)
	var title := Label.new()
	title.text = "INVENTARIO"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.95, 0.78, 0.35))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := Button.new()
	close_button.text = "Cerrar · Esc"
	close_button.pressed.connect(close)
	header.add_child(close_button)
	_feedback_label = Label.new()
	_feedback_label.text = _feedback_message
	_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.42) if _feedback_severity == "error" else Color(0.67, 0.88, 0.65))
	_content.add_child(_feedback_label)
	_render_sell()
	_restore_scroll_position()

func _on_purchase_history_changed() -> void:
	if visible:
		_render()

func _on_inventory_changed(_owned_count: int, _listed_count: int) -> void:
	if visible:
		_render()

func _on_watch_display_changed(_snapshot: Dictionary) -> void:
	if visible:
		_render()

func _on_carried_watch_changed(_watch: Dictionary) -> void:
	if visible:
		_render()

func _render_sell() -> void:
	var capacity := Label.new()
	capacity.text = "VITRINAS  %d / %d HUECOS OCUPADOS" % [GameState.get_watch_display_count(), GameState.get_total_display_capacity()] if not GameState.get_display_counter_id().is_empty() else "VITRINA NO INSTALADA"
	capacity.add_theme_color_override("font_color", Color(0.95, 0.78, 0.35))
	_content.add_child(capacity)
	_content.add_child(_make_history_filters())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content.add_child(scroll)
	_active_scroll = scroll
	var cards_grid := GridContainer.new()
	var viewport_width := get_viewport_rect().size.x
	cards_grid.columns = 1 if viewport_width < 560.0 else 2 if viewport_width < 900.0 else 4
	cards_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_grid.add_theme_constant_override("h_separation", 12)
	cards_grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(cards_grid)

	if _history_filter in [HISTORY_FILTER_AVAILABLE, HISTORY_FILTER_ALL]:
		if not GameState.carried_watch.is_empty():
			cards_grid.add_child(_make_carried_watch_card())
		for index in GameState.owned_pieces.size():
			cards_grid.add_child(_make_inventory_card(index))
	if _history_filter in [HISTORY_FILTER_DISPLAY, HISTORY_FILTER_ALL]:
		for index in GameState.listed_pieces.size():
			cards_grid.add_child(_make_listed_piece_card(index))
	if _history_filter in [HISTORY_FILTER_SOLD, HISTORY_FILTER_ALL]:
		for entry in GameState.purchase_history:
			if _is_sold_history_entry(entry):
				cards_grid.add_child(_make_sold_history_card(entry))
	if cards_grid.get_child_count() == 0:
		var empty := Label.new()
		empty.text = _history_empty_message()
		# A lone label has no natural minimum width. Make it fill the existing grid
		# column so word wrapping cannot collapse it into one character per line.
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		empty.custom_minimum_size = Vector2(0, 72)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_color_override("font_color", Color(0.84, 0.81, 0.7))
		cards_grid.add_child(empty)

func _make_history_filters() -> HBoxContainer:
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 6)
	for filter_data in [
		{"id": HISTORY_FILTER_AVAILABLE, "label": "Disponible"},
		{"id": HISTORY_FILTER_DISPLAY, "label": "En vitrina"},
		{"id": HISTORY_FILTER_SOLD, "label": "Vendidas"},
		{"id": HISTORY_FILTER_ALL, "label": "Todo"},
	]:
		var filter_id := String(filter_data["id"])
		var button := Button.new()
		button.text = String(filter_data["label"])
		button.toggle_mode = true
		button.button_pressed = _history_filter == filter_id
		button.add_theme_stylebox_override("normal", _button_style(_history_filter == filter_id))
		button.add_theme_stylebox_override("hover", _button_style(true))
		button.pressed.connect(_select_history_filter.bind(filter_id))
		filters.add_child(button)
	return filters

func _select_history_filter(filter_id: String) -> void:
	if _history_filter == filter_id:
		return
	_store_scroll_position()
	_history_filter = filter_id
	_scroll_positions["inventory"] = 0
	_render()

func _is_sold_history_entry(entry: Dictionary) -> bool:
	return String(entry.get("status", "")).begins_with("Vendida")

func _make_sold_history_card(entry: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(210, 0)
	card.add_theme_stylebox_override("panel", _card_style())
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	card.add_child(column)
	var title := Label.new()
	title.text = "%s · VENDIDA" % String(entry.get("name", "Pieza sin nombre")).to_upper()
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size = Vector2(0, 48)
	title.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	title.add_theme_color_override("font_color", Color(0.95, 0.78, 0.35))
	column.add_child(title)
	# La venta se conserva como historial, pero debe mantener la misma lectura
	# editorial que una pieza activa: imagen, importes y referencia de mercado.
	column.add_child(_make_inventory_preview(entry))
	var price := Label.new()
	price.text = "Compra %s · Venta %s" % [_format_money(int(entry.get("price_paid", 0))), _format_money(int(entry.get("final_price", 0)))]
	price.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	price.add_theme_color_override("font_color", Color(0.77, 0.75, 0.67))
	column.add_child(price)
	column.add_child(_make_sale_range_label(entry))
	var sold := Label.new()
	sold.text = "VENDIDA · Operación cerrada"
	sold.add_theme_color_override("font_color", Color(0.86, 0.76, 0.48))
	column.add_child(sold)
	var day := Label.new()
	var sold_day := int(entry.get("sold_day", 0))
	day.text = "Vendida el día %d" % sold_day if sold_day > 0 else "Día de venta no registrado"
	day.add_theme_color_override("font_color", Color(0.77, 0.75, 0.67))
	column.add_child(day)
	return card

func _history_empty_message() -> String:
	match _history_filter:
		HISTORY_FILTER_AVAILABLE:
			return "No hay piezas disponibles en inventario."
		HISTORY_FILTER_DISPLAY:
			return "No hay piezas expuestas en vitrina."
		HISTORY_FILTER_SOLD:
			return "Aún no hay piezas vendidas."
	return "No hay piezas registradas todavía."

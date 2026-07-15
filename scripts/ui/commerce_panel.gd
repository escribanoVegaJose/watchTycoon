extends Control

## Presentation for curated auction lots.
## Auction rules live in AuctionManager; this panel only reads its snapshot and sends bids.

const AUCTION_PREVIEW := preload("res://scenes/ui/AuctionPreview3D.tscn")
const AUCTION_ICON := preload("res://assets/icons/auction.svg")

var _active_tab := "auction"
var _feedback_message := ""
var _feedback_severity := "info"

var _panel: PanelContainer
var _content: VBoxContainer
var _feedback_label: Label
var _timer_label: Label
var _active_scroll: ScrollContainer
var _scroll_positions := {"auction": 0}
var _auction_balance_label: Label
var _auction_cards: Dictionary = {}
var _price_modal: Control
var _price_input: LineEdit
var _price_error: Label
var _price_feedback: Label
var _price_target: Dictionary = {}

func _process(_delta: float) -> void:
	if visible and _active_tab == "auction" and is_instance_valid(_timer_label):
		var snapshots := _auction_snapshots()
		if not snapshots.is_empty():
			var snapshot := snapshots[0]
			_timer_label.text = "Nuevo lote en %s" % _format_time(float(snapshot.get("cooldown_seconds", 0.0))) if String(snapshot.get("phase", "")) == "resolved" else "Cierra en %s" % _format_time(float(snapshot.get("remaining_seconds", 0.0)))

func _ready() -> void:
	add_to_group("commerce_panel")
	z_index = 20
	visible = false
	_build_ui()
	EventBus.stats_changed.connect(_on_stats_changed)
	get_node("/root/SettingsManager").connect(&"language_changed", _on_language_changed)
	if EventBus.has_signal(&"auction_state_changed"):
		EventBus.connect(&"auction_state_changed", _on_auction_state_changed)
	if EventBus.has_signal(&"auction_resolved"):
		EventBus.connect(&"auction_resolved", _on_auction_resolved)

func open() -> void:
	_store_scroll_position()
	_active_scroll = null
	visible = true
	_active_tab = "auction"
	_render()
	call_deferred("_focus_close_button")

func close() -> void:
	visible = false

func _on_language_changed(_locale: String) -> void:
	if visible:
		_render()

func toggle() -> void:
	if visible:
		close()
	else:
		open()

func _unhandled_key_input(event: InputEvent) -> void:
	if is_instance_valid(_price_modal) and _price_modal.visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_close_price_modal()
		get_viewport().set_input_as_handled()
		return
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.015, 0.02, 0.02, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_gui_input)
	add_child(dim)

	_panel = PanelContainer.new()
	# Keep the modal bounded by the viewport. A child grid must never force this
	# overlay wider than a small window; the lot list adapts and scrolls instead.
	_panel.anchor_left = 0.02
	_panel.anchor_top = 0.02
	_panel.anchor_right = 0.98
	_panel.anchor_bottom = 0.96
	_panel.clip_contents = true
	_panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	_panel.add_child(margin)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 10)
	margin.add_child(_content)
	_build_price_modal()

func _build_price_modal() -> void:
	_price_modal = Control.new()
	_price_modal.name = "PriceEditModal"
	_price_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_price_modal.visible = false
	_price_modal.z_index = 2
	add_child(_price_modal)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.015, 0.015, 0.76)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_close_price_modal()
	)
	_price_modal.add_child(dim)
	var dialog := PanelContainer.new()
	dialog.set_anchors_preset(Control.PRESET_CENTER)
	dialog.position = Vector2(-190, -150)
	dialog.size = Vector2(380, 300)
	dialog.custom_minimum_size = Vector2(300, 0)
	dialog.add_theme_stylebox_override("panel", _card_style())
	_price_modal.add_child(dialog)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	dialog.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	margin.add_child(column)
	var title := Label.new()
	title.text = "EDITAR PRECIO DE VITRINA"
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", Color(0.95, 0.78, 0.35))
	column.add_child(title)
	var piece_name := Label.new()
	piece_name.name = "PieceName"
	piece_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	piece_name.add_theme_font_size_override("font_size", 16)
	column.add_child(piece_name)
	var reference := Label.new()
	reference.name = "Reference"
	reference.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reference.add_theme_color_override("font_color", Color(0.77, 0.75, 0.67))
	column.add_child(reference)
	_price_input = LineEdit.new()
	_price_input.placeholder_text = "Precio entero en €"
	_price_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	_price_input.max_length = 10
	_price_input.text_changed.connect(_on_price_input_changed)
	_price_input.text_submitted.connect(func(_value: String) -> void: _save_price_modal())
	column.add_child(_price_input)
	_price_error = Label.new()
	_price_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_price_error.add_theme_color_override("font_color", Color(1.0, 0.5, 0.42))
	column.add_child(_price_error)
	_price_feedback = Label.new()
	_price_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_price_feedback.add_theme_color_override("font_color", Color(0.86, 0.76, 0.48))
	column.add_child(_price_feedback)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 8)
	column.add_child(actions)
	var cancel := Button.new()
	cancel.text = "Cancelar · Esc"
	cancel.custom_minimum_size = Vector2(110, 40)
	cancel.pressed.connect(_close_price_modal)
	actions.add_child(cancel)
	var save := Button.new()
	save.text = "Guardar"
	save.custom_minimum_size = Vector2(100, 40)
	save.pressed.connect(_save_price_modal)
	actions.add_child(save)

func _open_price_modal(item: Dictionary) -> void:
	if GameState.is_visitor_reserved(String(item.get("id", ""))):
		_notify("La pieza está reservada hasta terminar la atención en caja.", "error")
		return
	_price_target = item.duplicate(true)
	_price_modal.get_node("PanelContainer/MarginContainer/VBoxContainer/PieceName").text = String(item.get("name", "Pieza sin nombre"))
	var low := int(item.get("estimated_low", 0))
	var high := int(item.get("estimated_high", 0))
	_price_modal.get_node("PanelContainer/MarginContainer/VBoxContainer/Reference").text = "Referencia orientativa: %s–%s" % [_format_money(low), _format_money(high)] if low > 0 or high > 0 else "Sin rango de referencia disponible."
	_price_input.text = str(int(item.get("sale_price", item.get("suggested_price", item.get("auction_price", 0)))))
	_price_error.text = ""
	_price_modal.visible = true
	_on_price_input_changed(_price_input.text)
	call_deferred("_focus_price_input")

func _focus_price_input() -> void:
	_price_input.grab_focus()
	_price_input.select_all()

func _close_price_modal() -> void:
	if is_instance_valid(_price_modal):
		_price_modal.visible = false
	_price_target.clear()

func _on_price_input_changed(value: String) -> void:
	var valid := value.is_valid_int() and int(value) > 0
	_price_error.text = "" if valid else "Introduce un precio entero positivo."
	if valid:
		_price_feedback.text = _price_position_hint(int(value), _purchase_cost_for(_price_target), int(_price_target.get("estimated_low", 0)), int(_price_target.get("estimated_high", 0)))
	else:
		_price_feedback.text = ""

func _save_price_modal() -> void:
	var value := _price_input.text
	if not value.is_valid_int() or int(value) <= 0:
		_price_error.text = "Introduce un precio entero positivo."
		return
	if not GameState.set_piece_sale_price(String(_price_target.get("id", "")), int(value)):
		_price_error.text = "No se pudo actualizar: la pieza puede estar reservada."
		return
	_close_price_modal()
	_notify("Precio de vitrina actualizado a %s." % _format_money(int(value)), "info")
	if visible:
		_render()

func _render() -> void:
	_store_scroll_position()
	for child in _content.get_children():
		child.queue_free()
	var header := HBoxContainer.new()
	_content.add_child(header)
	var title := Label.new()
	title.text = "SALÓN DE LOTES"
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
	_render_auction()
	_restore_scroll_position()

func _render_auction() -> void:
	_auction_cards.clear()
	var snapshots := _auction_snapshots()
	var auction_meta := HBoxContainer.new()
	_content.add_child(auction_meta)
	var balance := Label.new()
	_auction_balance_label = balance
	balance.text = "SALDO DISPONIBLE  %s" % _format_money(GameState.money)
	balance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	balance.add_theme_color_override("font_color", Color(0.95, 0.78, 0.35))
	balance.add_theme_font_size_override("font_size", 14)
	auction_meta.add_child(balance)
	_timer_label = Label.new()
	_timer_label.add_theme_color_override("font_color", Color(0.95, 0.78, 0.35))
	_timer_label.add_theme_font_size_override("font_size", 16)
	auction_meta.add_child(_timer_label)

	var lot_scroll := ScrollContainer.new()
	lot_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lot_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content.add_child(lot_scroll)
	_active_scroll = lot_scroll
	var lots_grid := GridContainer.new()
	var viewport_width := get_viewport_rect().size.x
	# Avoid a fixed-width grid: it used to propagate its 756 px minimum back to
	# the modal, leaving only a clipped dark strip on narrow viewports.
	lots_grid.columns = 1 if viewport_width < 560.0 else 2 if viewport_width < 960.0 else 4
	lots_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lots_grid.add_theme_constant_override("h_separation", 12)
	lots_grid.add_theme_constant_override("v_separation", 12)
	lot_scroll.add_child(lots_grid)
	for snapshot in snapshots:
		lots_grid.add_child(_make_auction_card(snapshot))
	if snapshots.is_empty():
		var empty := Label.new()
		empty.text = "Preparando la próxima selección de lotes."
		lots_grid.add_child(empty)
	if _auction_manager() == null:
		_notify("El Salón de Lotes se está preparando.", "info")

func _make_auction_card(snapshot: Dictionary) -> PanelContainer:
	var showcase := PanelContainer.new()
	# Do not cap the card height: the valuation rows and CTA must remain inside
	# the card's input rect, otherwise only the CTA's top edge receives clicks.
	showcase.custom_minimum_size = Vector2(180, 0)
	showcase.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	showcase.add_theme_stylebox_override("panel", _card_style())
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	showcase.add_child(column)
	var status := String(snapshot.get("status", snapshot.get("phase", "Activa")))
	var current_bid := int(snapshot.get("current_bid", snapshot.get("highest_bid", 0)))
	var minimum_bid := int(snapshot.get("minimum_bid", snapshot.get("next_bid", current_bid + 1)))
	var player_bid := int(snapshot.get("player_bid", 0))
	var bidder := String(snapshot.get("highest_bidder", snapshot.get("leader", "Sin pujas")))
	var chip := Label.new()
	chip.text = status.to_upper()
	chip.add_theme_font_size_override("font_size", 11)
	chip.add_theme_color_override("font_color", Color(0.95, 0.78, 0.35) if String(snapshot.get("phase", "")) == "active" else Color(0.65, 0.65, 0.62))
	column.add_child(chip)
	var name_label := Label.new()
	name_label.text = String(snapshot.get("name", "Lote"))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", Color(0.08, 0.07, 0.05, 1.0))
	var name_backdrop := StyleBoxFlat.new()
	name_backdrop.bg_color = Color(0.94, 0.88, 0.76, 0.5)
	name_backdrop.set_corner_radius_all(4)
	name_backdrop.content_margin_left = 8
	name_backdrop.content_margin_top = 4
	name_backdrop.content_margin_right = 8
	name_backdrop.content_margin_bottom = 4
	name_label.add_theme_stylebox_override("normal", name_backdrop)
	column.add_child(name_label)
	var identity_label := Label.new()
	var category := String(snapshot.get("category", ""))
	identity_label.text = "%s · %s%s" % [String(snapshot.get("brand", "Marca")), tr(String(snapshot.get("segment", ""))), " · %s" % tr(category) if not category.is_empty() else ""]
	identity_label.add_theme_font_size_override("font_size", 12)
	identity_label.add_theme_color_override("font_color", Color(0.77, 0.75, 0.67))
	column.add_child(identity_label)
	var preview_image_path := String(snapshot.get("preview_image_path", ""))
	if not preview_image_path.is_empty():
		column.add_child(_make_image_preview(preview_image_path, 190))
	elif not String(snapshot.get("model_path", "")).is_empty():
		var preview_frame := Control.new()
		preview_frame.custom_minimum_size = Vector2(0, 190)
		preview_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# This frame is solely a visual clip for the model. Ignoring pointer input
		# ensures it can never form an invisible hit area over the bid CTA.
		preview_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview_frame.clip_contents = true
		column.add_child(preview_frame)
		var preview := AUCTION_PREVIEW.instantiate() as Control
		# The reusable scene has a desktop-sized minimum. Inside a lot card its
		# visual surface must be constrained by the frame, not overlap the price.
		preview.custom_minimum_size = Vector2.ZERO
		preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		# The card preview is display-only here. It must not steal clicks from the
		# CTA below when its viewport extends across the card's visual area.
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview_frame.add_child(preview)
		preview.call("set_interaction_enabled", false)
		preview.call("set_item_context", String(snapshot.get("item_type", "watch")), String(snapshot.get("category", "")))
		preview.call("set_model_path", String(snapshot.get("model_path", "")))
		var preview_controls := HBoxContainer.new()
		preview_controls.anchor_left = 1.0
		preview_controls.anchor_top = 1.0
		preview_controls.anchor_right = 1.0
		preview_controls.anchor_bottom = 1.0
		preview_controls.offset_left = -64
		preview_controls.offset_top = -33
		preview_controls.offset_right = -8
		preview_controls.offset_bottom = -7
		preview_controls.add_theme_constant_override("separation", 6)
		preview_frame.add_child(preview_controls)
		var zoom_out := Button.new()
		zoom_out.text = "−"
		zoom_out.tooltip_text = "Alejar pieza"
		zoom_out.pressed.connect(Callable(preview, "zoom_out"))
		preview_controls.add_child(zoom_out)
		var zoom_in := Button.new()
		zoom_in.text = "+"
		zoom_in.tooltip_text = "Acercar pieza"
		zoom_in.pressed.connect(Callable(preview, "zoom_in"))
		preview_controls.add_child(zoom_in)
	else:
		var pending_preview := PanelContainer.new()
		pending_preview.custom_minimum_size = Vector2(0, 190)
		pending_preview.add_theme_stylebox_override("panel", _preview_placeholder_style())
		var pending_label := Label.new()
		pending_label.text = "MODELO EN CATALOGACIÓN"
		pending_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pending_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		pending_label.add_theme_font_size_override("font_size", 11)
		pending_label.add_theme_color_override("font_color", Color(0.58, 0.55, 0.46))
		pending_preview.add_child(pending_label)
		column.add_child(pending_preview)

	var bid_caption := Label.new()
	bid_caption.text = "PUJA ACTUAL" if String(snapshot.get("phase", "")) == "active" else "PRECIO DE CIERRE"
	bid_caption.add_theme_font_size_override("font_size", 11)
	bid_caption.add_theme_color_override("font_color", Color(0.62, 0.64, 0.59))
	column.add_child(bid_caption)
	var price_label := Label.new()
	price_label.text = _format_money(current_bid)
	price_label.add_theme_font_size_override("font_size", 24)
	price_label.add_theme_color_override("font_color", Color(0.95, 0.78, 0.35))
	column.add_child(price_label)
	var secondary := Label.new()
	secondary.text = "Lidera %s · Est. %s–%s" % [bidder, _format_money(int(snapshot.get("estimated_low", 0))), _format_money(int(snapshot.get("estimated_high", 0)))]
	secondary.add_theme_font_size_override("font_size", 12)
	secondary.add_theme_color_override("font_color", Color(0.77, 0.75, 0.67))
	column.add_child(secondary)
	var player_bid_label := Label.new()
	player_bid_label.add_theme_font_size_override("font_size", 11)
	column.add_child(player_bid_label)
	column.add_child(_make_valuation_label(snapshot.get("valuation", {})))
	var bid := Button.new()
	bid.text = "Pujar %s" % _format_money(minimum_bid) if String(snapshot.get("phase", "")) == "active" else "Lote cerrado"
	bid.disabled = String(snapshot.get("phase", "")) != "active" or not GameState.carried_watch.is_empty() or not GameState.can_make_voluntary_payment(minimum_bid)
	_configure_bid_cta(bid)
	bid.mouse_filter = Control.MOUSE_FILTER_STOP
	# A native tooltip opens over the lower part of this CTA when the card is at
	# the bottom of the modal. It then steals hover/click input from the button.
	# Keep the bid control tooltip-free; its visible price already states the
	# required minimum bid.
	bid.tooltip_text = ""
	bid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bid.pressed.connect(_place_bid.bind(String(snapshot.get("instance_id", ""))))
	column.add_child(bid)
	_auction_cards[String(snapshot.get("instance_id", ""))] = {
		"chip": chip, "bid_caption": bid_caption, "price": price_label, "secondary": secondary,
		"player_bid": player_bid_label, "bid": bid,
	}
	_refresh_auction_card(_auction_cards[String(snapshot.get("instance_id", ""))], snapshot)
	return showcase

func _render_sell() -> void:
	var capacity := Label.new()
	capacity.text = "VITRINAS  %d / %d HUECOS OCUPADOS" % [GameState.get_watch_display_count(), GameState.get_total_display_capacity()] if not GameState.get_display_counter_id().is_empty() else "VITRINA NO INSTALADA"
	capacity.add_theme_color_override("font_color", Color(0.95, 0.78, 0.35))
	_content.add_child(capacity)
	var has_stock := not GameState.owned_pieces.is_empty() or not GameState.listed_pieces.is_empty() or not GameState.carried_watch.is_empty()
	if not has_stock:
		var empty := Label.new()
		empty.text = "Inventario vacío"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_color_override("font_color", Color(0.84, 0.81, 0.7))
		_content.add_child(empty)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content.add_child(scroll)
	_active_scroll = scroll
	var cards_grid := GridContainer.new()
	cards_grid.columns = 4
	cards_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_grid.add_theme_constant_override("h_separation", 12)
	cards_grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(cards_grid)
	if not GameState.carried_watch.is_empty():
		cards_grid.add_child(_make_carried_watch_card())
	for index in GameState.owned_pieces.size():
		cards_grid.add_child(_make_inventory_card(index))
	for index in GameState.listed_pieces.size():
		cards_grid.add_child(_make_listed_piece_card(index))

func _make_inventory_card(index: int) -> PanelContainer:
	var item := GameState.owned_pieces[index]
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(210, 0)
	card.add_theme_stylebox_override("panel", _card_style())
	var column := VBoxContainer.new()
	card.add_child(column)
	var name_label := Label.new()
	name_label.text = String(item.get("name", "Pieza sin nombre"))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 16)
	column.add_child(name_label)
	column.add_child(_make_inventory_preview(item))
	var acquisition_price := Label.new()
	acquisition_price.text = "Compra  %s" % _format_money(_purchase_cost_for(item))
	acquisition_price.add_theme_color_override("font_color", Color(0.77, 0.75, 0.67))
	column.add_child(acquisition_price)
	column.add_child(_make_sale_range_label(item))
	column.add_child(_make_valuation_label(GameState.get_watch_valuation(item)))
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	column.add_child(row)
	var price_readout := Label.new()
	price_readout.text = "PRECIO DE VITRINA  %s" % _format_money(_piece_sale_price(item))
	price_readout.add_theme_color_override("font_color", Color(0.95, 0.78, 0.35))
	row.add_child(price_readout)
	var edit_price := Button.new()
	edit_price.text = "Editar precio"
	edit_price.custom_minimum_size = Vector2(0, 40)
	edit_price.pressed.connect(_open_price_modal.bind(item))
	row.add_child(edit_price)
	var action := Button.new()
	action.text = "Colocar en vitrina"
	action.custom_minimum_size = Vector2(0, 40)
	var display_id := GameState.get_display_counter_id()
	var is_full := not display_id.is_empty() and not GameState.has_free_display_slot()
	action.disabled = display_id.is_empty() or is_full
	if display_id.is_empty():
		action.tooltip_text = "Instala una vitrina para exponer esta pieza."
	elif is_full:
		action.tooltip_text = "Vitrinas completas (%d/%d). Vende una pieza para liberar un hueco." % [GameState.get_watch_display_count(), GameState.get_total_display_capacity()]
	else:
		action.tooltip_text = "Elige un hueco libre iluminado en una vitrina."
	action.pressed.connect(_start_display_placement.bind(index, _piece_sale_price(item)))
	row.add_child(action)
	return card

func _make_carried_watch_card() -> PanelContainer:
	var item := GameState.carried_watch
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(210, 0)
	card.add_theme_stylebox_override("panel", _card_style())
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	card.add_child(column)
	var title := Label.new()
	title.text = "%s · EN MANO" % String(item.get("name", "Pieza")).to_upper()
	title.add_theme_color_override("font_color", Color(0.95, 0.78, 0.35))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(title)
	column.add_child(_make_inventory_preview(item))
	var acquisition_price := Label.new()
	acquisition_price.text = "Compra  %s" % _format_money(_purchase_cost_for(item))
	acquisition_price.add_theme_color_override("font_color", Color(0.77, 0.75, 0.67))
	column.add_child(acquisition_price)
	column.add_child(_make_sale_range_label(item))
	column.add_child(_make_valuation_label(GameState.get_watch_valuation(item)))
	var price_readout := Label.new()
	price_readout.text = "PRECIO DE VITRINA  %s" % _format_money(_piece_sale_price(item))
	price_readout.add_theme_color_override("font_color", Color(0.95, 0.78, 0.35))
	column.add_child(price_readout)
	var edit_price := Button.new()
	edit_price.text = "Editar precio"
	edit_price.custom_minimum_size = Vector2(0, 40)
	edit_price.pressed.connect(_open_price_modal.bind(item))
	column.add_child(edit_price)
	return card

func _make_listed_piece_card(index: int) -> PanelContainer:
	var item := GameState.listed_pieces[index]
	if _display_slot_for_unit(String(item.get("id", ""))) >= 0:
		return _make_displayed_nexora_card(index, item)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(210, 0)
	card.add_theme_stylebox_override("panel", _card_style())
	var column := VBoxContainer.new()
	card.add_child(column)
	var label := Label.new()
	label.text = String(item.get("name", "Pieza sin nombre"))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(label)
	column.add_child(_make_inventory_preview(item))
	var prices := Label.new()
	prices.text = "Compra  %s · Venta  %s" % [_format_money(_purchase_cost_for(item)), _format_money(int(item.get("sale_price", 0)))]
	prices.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prices.add_theme_color_override("font_color", Color(0.77, 0.75, 0.67))
	column.add_child(prices)
	column.add_child(_make_sale_range_label(item))
	column.add_child(_make_valuation_label(GameState.get_watch_valuation(item)))
	var availability := Label.new()
	availability.text = "Disponible para visitantes"
	availability.add_theme_color_override("font_color", Color(0.86, 0.76, 0.48))
	column.add_child(availability)
	var edit_price := Button.new()
	edit_price.text = "Editar precio"
	edit_price.custom_minimum_size = Vector2(0, 40)
	edit_price.pressed.connect(_open_price_modal.bind(item))
	column.add_child(edit_price)
	return card

func _make_displayed_nexora_card(index: int, item: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(210, 0)
	card.add_theme_stylebox_override("panel", _card_style())
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	card.add_child(column)
	var title := Label.new()
	title.text = "%s · EXPUESTO" % String(item.get("name", "Pieza")).to_upper()
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Reserve two lines so a long product name cannot push only its preview down.
	title.custom_minimum_size = Vector2(0, 48)
	title.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color(0.95, 0.78, 0.35))
	column.add_child(title)
	column.add_child(_make_inventory_preview(item))
	var prices := Label.new()
	prices.text = "Compra  %s · Venta  %s" % [_format_money(_purchase_cost_for(item)), _format_money(int(item.get("sale_price", 0)))]
	prices.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prices.add_theme_color_override("font_color", Color(0.77, 0.75, 0.67))
	column.add_child(prices)
	column.add_child(_make_sale_range_label(item))
	column.add_child(_make_valuation_label(GameState.get_watch_valuation(item)))
	var controls := VBoxContainer.new()
	controls.add_theme_constant_override("separation", 8)
	column.add_child(controls)
	var sale := Label.new()
	sale.text = "Disponible para visitantes"
	sale.add_theme_color_override("font_color", Color(0.86, 0.76, 0.48))
	controls.add_child(sale)
	var edit_price := Button.new()
	edit_price.text = "Editar precio"
	edit_price.custom_minimum_size = Vector2(0, 40)
	edit_price.pressed.connect(_open_price_modal.bind(item))
	controls.add_child(edit_price)
	return card

func _make_inventory_preview(item: Dictionary) -> Control:
	var image_path := _get_preview_image_path(item)
	if not image_path.is_empty():
		return _make_image_preview(image_path, 118)
	var frame := Control.new()
	frame.custom_minimum_size = Vector2(0, 118)
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.clip_contents = true
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var model_path := String(item.get("model_path", ""))
	if model_path.is_empty():
		var placeholder := PanelContainer.new()
		placeholder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		placeholder.add_theme_stylebox_override("panel", _preview_placeholder_style())
		var label := Label.new()
		label.text = "MINIATURA NO DISPONIBLE"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 10)
		label.add_theme_color_override("font_color", Color(0.58, 0.55, 0.46))
		placeholder.add_child(label)
		frame.add_child(placeholder)
		return frame
	var preview := AUCTION_PREVIEW.instantiate() as Control
	preview.custom_minimum_size = Vector2.ZERO
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(preview)
	preview.call("set_interaction_enabled", false)
	preview.call("set_item_context", String(item.get("item_type", "watch")), String(item.get("category", "")))
	preview.call("set_model_path", model_path)
	return frame

func _get_preview_image_path(item: Dictionary) -> String:
	var image_path := String(item.get("preview_image_path", ""))
	if image_path.is_empty():
		image_path = DataRegistry.get_lot_preview_path(String(item.get("lot_id", "")))
	return image_path

func _make_image_preview(image_path: String, height: float) -> Control:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(0, height)
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.clip_contents = true
	frame.add_theme_stylebox_override("panel", _preview_placeholder_style())
	var image := TextureRect.new()
	image.texture = load(image_path) as Texture2D
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(image)
	return frame

func _make_item_identity_label(item: Dictionary) -> Label:
	var label := Label.new()
	var category := String(item.get("category", ""))
	label.text = "%s · %s%s" % [String(item.get("brand", "Marca")), tr(String(item.get("segment", ""))), " · %s" % tr(category) if not category.is_empty() else ""]
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.77, 0.75, 0.67))
	return label

func _make_purchase_history_section() -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _card_style())
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	card.add_child(column)
	var title := Label.new()
	title.text = "HISTORIAL DE COMPRAS"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.95, 0.78, 0.35))
	column.add_child(title)
	if GameState.purchase_history.is_empty():
		var empty := Label.new()
		empty.text = "Aún no hay compras registradas."
		column.add_child(empty)
		return card
	for entry in GameState.purchase_history:
		var row := Label.new()
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.text = "%s · Coste %s · Día %d · Est. %s–%s · %s" % [String(entry.get("name", "Pieza")), _format_money(int(entry.get("price_paid", 0))), int(entry.get("acquired_day", 0)), _format_money(int(entry.get("estimated_low", 0))), _format_money(int(entry.get("estimated_high", 0))), String(entry.get("status", "Sin estado"))]
		column.add_child(row)
	return card

func _auction_manager() -> Node:
	return get_node_or_null("/root/AuctionManager")

func _auction_snapshots() -> Array[Dictionary]:
	var manager := _auction_manager()
	if manager == null or not manager.has_method(&"get_snapshots"): return []
	var result: Variant = manager.call(&"get_snapshots")
	var snapshots: Array[Dictionary] = []
	if result is Array:
		for entry in result:
			if entry is Dictionary:
				snapshots.append(entry)
	return snapshots

func _place_bid(instance_id: String) -> void:
	var manager := _auction_manager()
	if manager == null or not manager.has_method(&"place_player_bid"):
		_notify("La mesa de subasta no está disponible todavía.", "error")
		return
	var snapshot := _auction_snapshot_for(instance_id)
	if snapshot.is_empty():
		_notify("Este lote ya no está disponible.", "error")
		return
	var result: Variant = manager.call(&"place_player_bid", instance_id, int(snapshot.get("minimum_bid", 0)))
	if result is bool and not result:
		_notify("La puja no ha sido aceptada. Revisa el mínimo y tu saldo.", "error")
		return
	if result is Dictionary and not bool(result.get("success", true)):
		_notify(String(result.get("message", "La puja no ha sido aceptada.")), "error")
		return
	_notify(String(result.get("message", "Puja enviada.")) if result is Dictionary else "Puja enviada.", "info")

func _pick_up_watch(index: int, price_input: LineEdit) -> void:
	var sale_price := int(price_input.text.to_int())
	if sale_price <= 0:
		_notify("Indica un precio de venta válido.", "error")
		return
	if not GameState.pick_up_owned_watch(index, sale_price):
		_notify("No se pudo recoger la pieza. Ya puedes estar transportando otra.", "error")
		return
	_notify("Pieza recogida. Acércate a una vitrina y pulsa E.", "info")
	_render()

func _start_display_placement(index: int, sale_price: int) -> void:
	if sale_price <= 0:
		_notify("Edita primero un precio de venta válido.", "error")
		return
	close()
	EventBus.owned_watch_display_placement_requested.emit(index, sale_price)

func _piece_sale_price(item: Dictionary) -> int:
	return int(item.get("sale_price", item.get("suggested_price", item.get("auction_price", 0))))

func _update_carried_price(price_input: LineEdit) -> void:
	var sale_price := int(price_input.text.to_int())
	if not GameState.set_carried_watch_sale_price(sale_price):
		_notify("Indica un precio de venta válido.", "error")
		return
	_notify("Precio de vitrina actualizado a %s." % _format_money(sale_price), "info")
	_render()

func _rotate_displayed_watch(delta_radians: float) -> void:
	if not GameState.rotate_displayed_watch(delta_radians):
		_notify("No hay ninguna pieza expuesta para girar.", "error")

func _display_slot_for_unit(unit_id: String) -> int:
	for entry in GameState.displayed_watches:
		if String(entry.get("unit_id", "")) == unit_id:
			return int(entry.get("slot_index", -1))
	return -1

func _purchase_cost_for(item: Dictionary) -> int:
	var unit_id := String(item.get("id", ""))
	for entry in GameState.purchase_history:
		if String(entry.get("unit_id", "")) == unit_id:
			return int(entry.get("price_paid", 0))
	return int(item.get("auction_price", 0))

func _make_valuation_label(valuation: Dictionary) -> VBoxContainer:
	var summary := VBoxContainer.new()
	summary.add_theme_constant_override("separation", 3)
	var movement_label := String(valuation.get("movement_label", "Mecanismo"))
	var heading := Label.new()
	heading.text = "%s  %s" % [String(valuation.get("stars_text", "★★★★☆")), String(valuation.get("label", "Pieza recomendable"))]
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.add_theme_font_size_override("font_size", 11)
	heading.add_theme_color_override("font_color", Color(0.86, 0.76, 0.48))
	summary.add_child(heading)
	for stat in [
		{"label": "Calidad", "value": int(valuation.get("quality", 0))},
		{"label": "Marca", "value": int(valuation.get("brand", 0))},
		{"label": "Estado", "value": int(valuation.get("condition", 0))},
		{"label": "Rareza", "value": int(valuation.get("rarity", 0))},
		{"label": "Demanda", "value": int(valuation.get("demand", 0))},
	]:
		summary.add_child(_make_valuation_stat_row(String(stat.label), int(stat.value)))
	var detail := Label.new()
	detail.text = "%s %d · Precio %s" % [movement_label, int(valuation.get("movement", 0)), String(valuation.get("price_fit_label", "Revisar precio"))]
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_font_size_override("font_size", 10)
	detail.add_theme_color_override("font_color", Color(0.68, 0.67, 0.59))
	summary.add_child(detail)
	return summary

func _make_valuation_stat_row(stat_name: String, value: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	var name_label := Label.new()
	name_label.text = stat_name
	name_label.custom_minimum_size = Vector2(53, 0)
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.add_theme_color_override("font_color", Color(0.76, 0.74, 0.66))
	row.add_child(name_label)
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 100
	bar.value = clampi(value, 0, 100)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(58, 8)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_theme_stylebox_override("background", _valuation_bar_background_style())
	bar.add_theme_stylebox_override("fill", _valuation_bar_fill_style())
	row.add_child(bar)
	var value_label := Label.new()
	value_label.text = "%d" % clampi(value, 0, 100)
	value_label.custom_minimum_size = Vector2(24, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override("font_size", 10)
	value_label.add_theme_color_override("font_color", Color(0.9, 0.86, 0.75))
	row.add_child(value_label)
	return row

func _make_sale_range_label(item: Dictionary) -> Label:
	var label := Label.new()
	var low := int(item.get("estimated_low", 0))
	var high := int(item.get("estimated_high", 0))
	label.text = "RANGO APROX. DE VENTA  %s–%s" % [_format_money(low), _format_money(high)]
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.tooltip_text = "Referencia orientativa basada en la estimación del lote."
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.86, 0.76, 0.48))
	return label

func _price_position_hint(price: int, cost: int, estimate_low: int, estimate_high: int) -> String:
	var margin := price - cost
	var position := ""
	if price < estimate_low:
		position = "precio de salida"
	elif price < int(lerpf(estimate_low, estimate_high, 0.25)):
		position = "posición accesible"
	elif price <= int(lerpf(estimate_low, estimate_high, 0.7)):
		position = "posición premium equilibrada"
	elif price <= estimate_high:
		position = "posición exclusiva"
	else:
		position = "posición muy exclusiva"
	return "Margen: %s · %s. Referencia de vitrina: %s–%s." % [_format_money(margin), position, _format_money(estimate_low), _format_money(estimate_high)]

func _update_price_positioning(value: String, label: Label, cost: int, estimate_low: int, estimate_high: int) -> void:
	label.text = _price_position_hint(int(value.to_int()), cost, estimate_low, estimate_high)

func _complete_sale(index: int) -> void:
	if not GameState.complete_sale(index):
		_notify("No se pudo completar la venta.", "error")
		return
	_notify("Venta completada. La tesorería ha aumentado.", "info")
	_render()

func _on_stats_changed(_money: int, _reputation: int) -> void:
	if visible:
		_render()

func _on_auction_state_changed(_snapshot: Variant = null) -> void:
	if visible and _active_tab == "auction":
		_refresh_auction_dynamic_values()

func _auction_snapshot_for(instance_id: String) -> Dictionary:
	for snapshot in _auction_snapshots():
		if String(snapshot.get("instance_id", "")) == instance_id:
			return snapshot
	return {}

func _refresh_auction_dynamic_values() -> void:
	var snapshots := _auction_snapshots()
	if snapshots.size() != _auction_cards.size():
		_render()
		return
	for snapshot in snapshots:
		var instance_id := String(snapshot.get("instance_id", ""))
		if not _auction_cards.has(instance_id):
			_render()
			return
		_refresh_auction_card(_auction_cards[instance_id], snapshot)
	if is_instance_valid(_auction_balance_label):
		_auction_balance_label.text = "SALDO DISPONIBLE  %s" % _format_money(GameState.money)

func _refresh_auction_card(card: Dictionary, snapshot: Dictionary) -> void:
	var phase := String(snapshot.get("phase", ""))
	var status := String(snapshot.get("status", snapshot.get("phase", "Activa")))
	var current_bid := int(snapshot.get("current_bid", 0))
	var minimum_bid := int(snapshot.get("minimum_bid", current_bid))
	var player_bid := int(snapshot.get("player_bid", 0))
	var bidder := String(snapshot.get("highest_bidder", "Sin pujas"))
	var chip := card["chip"] as Label
	chip.text = status.to_upper()
	chip.add_theme_color_override("font_color", Color(0.95, 0.78, 0.35) if phase == "active" else Color(0.65, 0.65, 0.62))
	(card["bid_caption"] as Label).text = "PUJA ACTUAL" if phase == "active" else "PRECIO DE CIERRE"
	(card["price"] as Label).text = _format_money(current_bid)
	(card["secondary"] as Label).text = "Lidera %s · Est. %s–%s" % [bidder, _format_money(int(snapshot.get("estimated_low", 0))), _format_money(int(snapshot.get("estimated_high", 0)))]
	var player_bid_label := card["player_bid"] as Label
	player_bid_label.visible = player_bid > 0
	player_bid_label.text = "TU PUJA ACTUAL  %s" % _format_money(player_bid)
	player_bid_label.add_theme_color_override("font_color", Color(0.67, 0.88, 0.65) if bidder == "Tú" else Color(1.0, 0.66, 0.42))
	var bid := card["bid"] as Button
	bid.text = "Pujar %s" % _format_money(minimum_bid) if phase == "active" else "Lote cerrado"
	bid.disabled = phase != "active" or not GameState.carried_watch.is_empty() or not GameState.can_make_voluntary_payment(minimum_bid)
	bid.tooltip_text = "Deposita primero la pieza que transportas en una vitrina." if not GameState.carried_watch.is_empty() else "Incremento mínimo: %s" % _format_money(int(snapshot.get("bid_increment", 0)))

func _on_auction_resolved(_result: Variant = null) -> void:
	if _result is Dictionary:
		# WorkshopUI owns the non-blocking awarded-lot toast. Do not duplicate its
		# confirmation in this modal or the global feedback channel.
		if bool(_result.get("awarded", false)) and String(_result.get("winner", "")) == "player":
			if visible:
				_render()
			return
		# A rival winning is represented by the closed lot itself; it does not need
		# to interrupt the player with a global notification.
		if String(_result.get("winner", "")) == "collector":
			return
		_notify(String(_result.get("message", "La subasta ha finalizado.")), "info" if bool(_result.get("awarded", true)) else "error")
	else:
		_notify("La subasta ha finalizado.", "info")
	if visible:
		_render()

func _store_scroll_position() -> void:
	if is_instance_valid(_active_scroll):
		_scroll_positions[_active_tab] = _active_scroll.scroll_vertical

func _restore_scroll_position() -> void:
	if not is_instance_valid(_active_scroll):
		return
	var scroll := _active_scroll
	var position := int(_scroll_positions.get(_active_tab, 0))
	scroll.call_deferred("set", "scroll_vertical", position)

func _notify(message: String, severity: String) -> void:
	_feedback_message = message
	_feedback_severity = severity
	EventBus.feedback_requested.emit(message, severity)
	if _feedback_label != null:
		_feedback_label.text = message
		_feedback_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.42) if severity == "error" else Color(0.67, 0.88, 0.65))

func _on_dim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()

func _focus_close_button() -> void:
	var close_button := _content.get_child(0).get_child(1) as Button
	if close_button != null:
		close_button.grab_focus()

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.047, 0.05, 0.98)
	style.border_color = Color(0.72, 0.57, 0.32, 0.82)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	return style

func _card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.115, 0.11, 1.0)
	style.content_margin_left = 12
	style.content_margin_top = 10
	style.content_margin_right = 12
	style.content_margin_bottom = 10
	style.set_corner_radius_all(7)
	return style

func _preview_placeholder_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.052, 0.049, 1.0)
	style.border_color = Color(0.3, 0.27, 0.2, 0.7)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	return style

func _valuation_bar_background_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.068, 0.063, 1.0)
	style.border_color = Color(0.34, 0.3, 0.21, 0.75)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	return style

func _valuation_bar_fill_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.73, 0.57, 0.3, 1.0)
	style.set_corner_radius_all(2)
	return style

func _configure_bid_cta(button: Button) -> void:
	# Keep the bid interaction visually distinct from secondary panel controls.
	# The existing auction icon already uses a dark stroke, matching this CTA.
	button.icon = AUCTION_ICON
	button.expand_icon = true
	button.custom_minimum_size = Vector2(0, 42)
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", Color(0.10, 0.085, 0.06))
	button.add_theme_color_override("font_hover_color", Color(0.075, 0.06, 0.04))
	button.add_theme_color_override("font_pressed_color", Color(0.055, 0.045, 0.03))
	button.add_theme_color_override("font_disabled_color", Color(0.82, 0.80, 0.73))
	button.add_theme_stylebox_override("normal", _bid_cta_style(Color(0.78, 0.62, 0.34), Color(0.94, 0.78, 0.46)))
	button.add_theme_stylebox_override("hover", _bid_cta_style(Color(0.91, 0.75, 0.45), Color(1.0, 0.88, 0.60)))
	button.add_theme_stylebox_override("pressed", _bid_cta_style(Color(0.63, 0.47, 0.24), Color(0.83, 0.66, 0.36)))
	button.add_theme_stylebox_override("focus", _bid_cta_style(Color(0.78, 0.62, 0.34), Color(1.0, 0.88, 0.60), 2))
	button.add_theme_stylebox_override("disabled", _bid_cta_style(Color(0.20, 0.205, 0.19), Color(0.43, 0.42, 0.37)))

func _bid_cta_style(background: Color, border: Color, border_width := 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	return style

func _button_style(selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.48, 0.33, 0.12, 1.0) if selected else Color(0.13, 0.14, 0.13, 1.0)
	style.set_corner_radius_all(6)
	return style

func _format_money(amount: int) -> String:
	return "%s €" % str(amount).replace("-", "−")

func _format_time(seconds: float) -> String:
	var total := maxi(0, ceili(seconds))
	return "%02d:%02d" % [total / 60, total % 60]

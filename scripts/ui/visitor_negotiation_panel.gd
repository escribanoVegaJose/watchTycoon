class_name VisitorNegotiationPanel
extends Control

## Tarjeta no modal de negociación. El manager conserva reglas, límites y snapshots;
## esta vista sólo muestra el estado activo y comunica las intenciones del jugador.

const GOLD := Color(0.84, 0.65, 0.35)
const CREAM := Color(0.96, 0.92, 0.84)
const MUTED := Color(0.68, 0.65, 0.57)
const CARD_WIDTH := 360.0
const CARD_MARGIN := 16.0

var _panel: PanelContainer
var _customer_name: Label
var _customer_profile: Label
var _piece_name: Label
var _piece_meta: Label
var _preview: TextureRect
var _preview_fallback: Control
var _listed_price: Label
var _offer: Label
var _patience: ProgressBar
var _patience_label: Label
var _queue_label: Label
var _queue: HBoxContainer
var _review_section: VBoxContainer
var _counter: SpinBox
var _accept: Button
var _review: Button
var _expanded := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 100
	# Sólo la tarjeta recibe clics: comercio e inventario permanecen utilizables.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()
	_layout_card()
	EventBus.visitor_negotiation_changed.connect(_on_changed)
	EventBus.visitor_negotiation_resolved.connect(_on_resolved)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_instance_valid(_panel):
		_layout_card()

func _build() -> void:
	_panel = PanelContainer.new()
	# La posición se calcula contra el borde derecho; mantener el ancla en origen
	# evita aplicar dos veces el ancho del viewport al actualizar el layout.
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override("panel", _surface_style(Color(0.055, 0.047, 0.039, 0.99), 10, 1, Color(GOLD, 0.72)))
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 13)
	margin.add_theme_constant_override("margin_top", 11)
	margin.add_theme_constant_override("margin_right", 13)
	margin.add_theme_constant_override("margin_bottom", 11)
	_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)

	var header := HBoxContainer.new()
	column.add_child(header)
	var heading := _label("OFERTA EN VITRINA", 15, GOLD)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	_queue_label = _label("", 10, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	header.add_child(_queue_label)

	var client_row := HBoxContainer.new()
	client_row.add_theme_constant_override("separation", 6)
	column.add_child(client_row)
	_customer_name = _label("Cliente interesado", 14, CREAM)
	_customer_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_customer_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	client_row.add_child(_customer_name)
	_customer_profile = _label("", 11, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	client_row.add_child(_customer_profile)

	column.add_child(_build_piece_card())

	var patience_row := HBoxContainer.new()
	patience_row.add_theme_constant_override("separation", 7)
	column.add_child(patience_row)
	_patience_label = _label("", 11, CREAM)
	_patience_label.custom_minimum_size = Vector2(116, 0)
	patience_row.add_child(_patience_label)
	_patience = ProgressBar.new()
	_patience.show_percentage = false
	_patience.custom_minimum_size = Vector2(0, 8)
	_patience.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_patience.add_theme_stylebox_override("background", _surface_style(Color(0.16, 0.13, 0.10), 5))
	_patience.add_theme_stylebox_override("fill", _surface_style(GOLD, 5))
	patience_row.add_child(_patience)

	_queue = HBoxContainer.new()
	_queue.add_theme_constant_override("separation", 4)
	column.add_child(_queue)

	_review_section = VBoxContainer.new()
	_review_section.add_theme_constant_override("separation", 5)
	column.add_child(_review_section)
	var counter_hint := _label("Tu contraoferta consume paciencia.", 11, MUTED)
	_review_section.add_child(counter_hint)
	var counter_row := HBoxContainer.new()
	counter_row.add_theme_constant_override("separation", 7)
	_review_section.add_child(counter_row)
	_counter = SpinBox.new()
	_counter.min_value = 1
	_counter.max_value = 99999
	_counter.step = 5
	_counter.allow_greater = true
	_counter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_counter.tooltip_text = "Indica tu contraoferta en euros."
	counter_row.add_child(_counter)
	var counter_button := Button.new()
	counter_button.text = "Enviar"
	counter_button.tooltip_text = "Enviar una contraoferta"
	counter_button.pressed.connect(func(): EventBus.visitor_negotiation_action_requested.emit("counter", int(_counter.value)))
	counter_row.add_child(counter_button)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 7)
	column.add_child(actions)
	_accept = Button.new()
	_accept.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_accept.add_theme_font_size_override("font_size", 14)
	_accept.add_theme_stylebox_override("normal", _surface_style(Color(0.30, 0.22, 0.12), 6, 1, GOLD))
	_accept.pressed.connect(func(): EventBus.visitor_negotiation_action_requested.emit("accept", 0))
	actions.add_child(_accept)
	_review = Button.new()
	_review.text = "Revisar"
	_review.tooltip_text = "Abrir contraoferta"
	_review.pressed.connect(_toggle_review)
	actions.add_child(_review)
	var reject := Button.new()
	reject.text = "Rechazar"
	reject.tooltip_text = "Cancelar la operación y conservar la pieza en vitrina"
	reject.pressed.connect(func(): EventBus.visitor_negotiation_action_requested.emit("reject", 0))
	actions.add_child(reject)
	_set_review_expanded(false)

func _build_piece_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _surface_style(Color(0.075, 0.064, 0.053), 7))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	card.add_child(row)
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(52, 52)
	frame.add_theme_stylebox_override("panel", _surface_style(Color(0.035, 0.031, 0.027), 5, 1, Color(0.45, 0.35, 0.22)))
	row.add_child(frame)
	_preview = TextureRect.new()
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 4)
	_preview.visible = false
	frame.add_child(_preview)
	_preview_fallback = _make_preview_fallback()
	_preview_fallback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 4)
	frame.add_child(_preview_fallback)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 2)
	row.add_child(details)
	_piece_name = _label("Pieza expuesta", 13, CREAM)
	_piece_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	details.add_child(_piece_name)
	_piece_meta = _label("", 10, MUTED)
	_piece_meta.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	details.add_child(_piece_meta)
	var prices := HBoxContainer.new()
	prices.add_theme_constant_override("separation", 5)
	details.add_child(prices)
	_listed_price = _price_label(Color(0.72, 0.68, 0.57))
	_listed_price.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prices.add_child(_listed_price)
	_offer = _price_label(GOLD)
	_offer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prices.add_child(_offer)
	return card

func _on_changed(snapshot: Dictionary) -> void:
	if not snapshot.has("queue"):
		return
	var should_show := String(snapshot.get("state", "")) == "active"
	visible = should_show
	EventBus.visitor_negotiation_card_visibility_changed.emit(should_show, _panel.size.y if should_show else 0.0)
	if not should_show:
		return
	var profile: Dictionary = snapshot.get("profile", {})
	var watch: Dictionary = snapshot.get("watch", {})
	_customer_name.text = String(snapshot.get("customer_name", "Cliente interesado"))
	_customer_profile.text = String(profile.get("purchasing_power", "discreto")).capitalize()
	_piece_name.text = String(watch.get("name", "Pieza expuesta"))
	var brand := String(watch.get("brand", ""))
	var category := String(watch.get("category", watch.get("item_type", "reloj")))
	_piece_meta.text = "%s%s" % [brand, " · %s" % category.capitalize() if not category.is_empty() else ""]
	var listed := int(watch.get("sale_price", 0))
	var offer := int(snapshot.get("offer", 0))
	_listed_price.text = "Vitrina %s €" % listed
	_offer.text = "Oferta %s €" % offer
	_accept.text = "Aceptar %s €" % offer
	_counter.value = maxi(offer + 5, listed)
	var patience := int(snapshot.get("patience", 1))
	var max_patience := int(snapshot.get("max_patience", 1))
	_patience.max_value = max_patience
	_patience.value = patience
	_patience_label.text = "Paciencia %d/%d" % [patience, max_patience]
	var queue: Array = snapshot.get("queue", [])
	_queue_label.text = "%d EN COLA" % queue.size()
	_set_queue(queue)
	_set_preview(watch)
	_layout_card()
	call_deferred("_layout_card")

func present(snapshot: Dictionary) -> void:
	_on_changed(snapshot)

func _on_resolved(_result: Dictionary) -> void:
	pass

func _toggle_review() -> void:
	_set_review_expanded(not _expanded)

func _set_review_expanded(expanded: bool) -> void:
	_expanded = expanded
	_review_section.visible = expanded
	_review.text = "Cerrar" if expanded else "Revisar"
	_layout_card()
	call_deferred("_layout_card")

func _set_queue(queue: Array) -> void:
	for child in _queue.get_children():
		child.queue_free()
	for entry_variant in queue:
		if not entry_variant is Dictionary:
			continue
		var entry: Dictionary = entry_variant
		var item := _label(String(entry.get("name", "Cliente")), 10, GOLD if String(entry.get("state", "")) == "EN CAJA" else MUTED)
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_queue.add_child(item)

func _set_preview(watch: Dictionary) -> void:
	var path := String(watch.get("preview_image_path", ""))
	if path.is_empty():
		path = DataRegistry.get_lot_preview_path(String(watch.get("lot_id", "")))
	var texture: Texture2D = load(path) as Texture2D if not path.is_empty() and ResourceLoader.exists(path) else null
	_preview.texture = texture
	_preview.visible = texture != null
	_preview_fallback.visible = texture == null

func _layout_card() -> void:
	if not is_instance_valid(_panel):
		return
	var viewport_size := get_viewport_rect().size
	var content_size := _panel.get_combined_minimum_size()
	var card_size := Vector2(CARD_WIDTH, maxf(1.0, content_size.y))
	var available_size := Vector2(maxf(1.0, viewport_size.x - CARD_MARGIN * 2.0), maxf(1.0, viewport_size.y - CARD_MARGIN * 2.0))
	var scale_factor := minf(1.0, minf(available_size.x / card_size.x, available_size.y / card_size.y))
	_panel.size = card_size
	_panel.scale = Vector2.ONE * scale_factor
	_panel.position = Vector2(viewport_size.x - card_size.x * scale_factor - CARD_MARGIN, CARD_MARGIN)
	if visible:
		EventBus.visitor_negotiation_card_visibility_changed.emit(true, card_size.y * scale_factor)

func _make_preview_fallback() -> Control:
	var fallback := VBoxContainer.new()
	fallback.alignment = BoxContainer.ALIGNMENT_CENTER
	fallback.add_child(_label("◆", 18, Color(0.58, 0.45, 0.27), HORIZONTAL_ALIGNMENT_CENTER))
	return fallback

func _price_label(color: Color) -> Label:
	var label := _label("", 10, color, HORIZONTAL_ALIGNMENT_CENTER)
	label.add_theme_stylebox_override("normal", _surface_style(Color(0.045, 0.039, 0.032), 4))
	return label

func _label(text: String, font_size: int, color: Color, alignment := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = alignment
	return label

func _surface_style(color: Color, radius: int, border_width := 0, border_color := Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 7
	style.content_margin_top = 5
	style.content_margin_right = 7
	style.content_margin_bottom = 5
	return style

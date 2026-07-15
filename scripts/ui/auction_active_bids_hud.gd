extends Control

## Persistent HUD queue for bids the player is following. It only presents
## AuctionManager snapshots; closing a card never changes the actual bid.

@onready var _cards: VBoxContainer = %Cards

var _dismissed_instance_ids: Dictionary = {}
var _card_views: Dictionary = {}

func _ready() -> void:
	EventBus.auction_state_changed.connect(_on_auction_state_changed)
	_refresh()

func _process(_delta: float) -> void:
	_refresh_card_values()

func _on_auction_state_changed(_snapshot: Dictionary) -> void:
	_refresh()

func _refresh() -> void:
	var active_lots := _active_player_lots()
	var active_ids: Dictionary = {}
	for lot in active_lots:
		active_ids[String(lot.get("instance_id", ""))] = true
	for instance_id in _dismissed_instance_ids.keys():
		if not active_ids.has(instance_id):
			_dismissed_instance_ids.erase(instance_id)
	for child in _cards.get_children():
		child.queue_free()
	_card_views.clear()
	for lot in active_lots:
		var instance_id := String(lot.get("instance_id", ""))
		if not _dismissed_instance_ids.has(instance_id):
			_cards.add_child(_make_card(lot))
	visible = _cards.get_child_count() > 0

func _active_player_lots() -> Array[Dictionary]:
	var lots: Array[Dictionary] = []
	for lot in AuctionManager.get_snapshots():
		if String(lot.get("phase", "")) == "active" and int(lot.get("player_bid", 0)) > 0:
			lots.append(lot)
	lots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("remaining_seconds", 0.0)) < float(b.get("remaining_seconds", 0.0))
	)
	return lots

func _make_card(lot: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(300, 0)
	card.add_theme_stylebox_override("panel", _card_style())
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 9)
	card.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var name_label := Label.new()
	name_label.text = String(lot.get("name", "Lote"))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 14)
	header.add_child(name_label)
	var close_button := Button.new()
	close_button.text = "×"
	close_button.tooltip_text = "Quitar seguimiento. Tu puja actual seguirá activa."
	close_button.accessibility_name = "Quitar esta puja de la cola"
	close_button.pressed.connect(_dismiss_card.bind(String(lot.get("instance_id", ""))))
	header.add_child(close_button)
	var details := Label.new()
	details.add_theme_font_size_override("font_size", 12)
	column.add_child(details)
	var bid_button := Button.new()
	bid_button.custom_minimum_size = Vector2(0, 36)
	bid_button.pressed.connect(_place_bid.bind(String(lot.get("instance_id", ""))))
	column.add_child(bid_button)
	_card_views[String(lot.get("instance_id", ""))] = {"details": details, "bid": bid_button}
	_refresh_card(String(lot.get("instance_id", "")), lot)
	return card

func _refresh_card_values() -> void:
	for lot in _active_player_lots():
		var instance_id := String(lot.get("instance_id", ""))
		if _card_views.has(instance_id):
			_refresh_card(instance_id, lot)

func _refresh_card(instance_id: String, lot: Dictionary) -> void:
	var view := _card_views[instance_id] as Dictionary
	var current_bid := int(lot.get("current_bid", 0))
	var minimum_bid := int(lot.get("minimum_bid", current_bid))
	var leading := String(lot.get("highest_bidder", "")) == "Tú"
	var details := view["details"] as Label
	details.text = "%s · Actual %s · %s" % ["VAS GANANDO" if leading else "TE HAN SUPERADO", _format_money(current_bid), _format_time(float(lot.get("remaining_seconds", 0.0)))]
	details.add_theme_color_override("font_color", Color(0.68, 0.88, 0.65) if leading else Color(1.0, 0.66, 0.42))
	var bid := view["bid"] as Button
	bid.text = "Vas ganando" if leading else "Pujar %s" % _format_money(minimum_bid)
	bid.disabled = leading or not GameState.can_make_voluntary_payment(minimum_bid) or not GameState.carried_watch.is_empty()
	bid.tooltip_text = "Solo se cobra si ganas." if not leading else "Tu puja es la más alta."

func _place_bid(instance_id: String) -> void:
	for lot in _active_player_lots():
		if String(lot.get("instance_id", "")) == instance_id:
			var result := AuctionManager.place_player_bid(instance_id, int(lot.get("minimum_bid", 0)))
			if not bool(result.get("success", false)):
				EventBus.feedback_requested.emit(String(result.get("message", "No se pudo realizar la puja.")), "error")
			return

func _dismiss_card(instance_id: String) -> void:
	_dismissed_instance_ids[instance_id] = true
	_refresh()

func _card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.04, 0.042, 0.97)
	style.border_color = Color(0.72, 0.57, 0.32, 0.88)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	return style

func _format_money(value: int) -> String:
	return "%s €" % value

func _format_time(seconds: float) -> String:
	var whole_seconds: int = maxi(0, ceili(seconds))
	return "%02d:%02d" % [whole_seconds / 60, whole_seconds % 60]

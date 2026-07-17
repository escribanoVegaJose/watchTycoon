extends Node

const STARTING_MONEY := 5000
const STARTING_REPUTATION := 1
const MAX_REPUTATION_LEVEL := 12
## Índice cero = REP 1. Cada hito expresa las ventas acumuladas necesarias.
const REPUTATION_SALES_THRESHOLDS := [0, 5, 15, 30, 50, 75, 105, 140, 180, 225, 275, 330]
const MAIN_DOOR_PRICE := 850
const POINT_OF_SALE_FACILITY_ID := "counter_01"
const DEFAULT_WATCH_MODEL_PATH := "res://assets/meshy/godot_ready/nexora-b.glb"
const WatchValuation = preload("res://scripts/gameplay/watch_valuation.gd")

var money := STARTING_MONEY
var reputation := STARTING_REPUTATION
## Solo las ventas cobradas a visitantes hacen avanzar la reputación de la maison.
var visitor_sales_count := 0
## Calendar day is persisted separately from the real-time progress within a day.
var current_day := 1
var has_main_door := false
var hidden_built_elements: Dictionary = {}
var owned_pieces: Array[Dictionary] = []
var listed_pieces: Array[Dictionary] = []
## Exactly one physical watch may be carried between commerce and a display.
var carried_watch: Dictionary = {}
## Immutable acquisition records plus the single physical display slot.
var purchase_history: Array[Dictionary] = []
var displayed_watch: Dictionary = {}
## Each display facility has independently priced physical slots.
var displayed_watches: Array[Dictionary] = []
## Legacy capacity retained for callers and saves that only know the original counter.
const DISPLAY_CAPACITY := 6
const DISPLAY_FACILITY_DEFINITIONS := {
	"display_counter_01": preload("res://data/facilities/display_counter_01.tres"),
	"display_case_small_02": preload("res://data/facilities/display_case_small_02.tres"),
	"display_case_medium_04": preload("res://data/facilities/display_case_medium_04.tres"),
}
## These catalogue items are no longer available. Filtering them during load keeps
## legacy saves from retaining invisible furniture that blocks new placements.
const RETIRED_FACILITY_ITEM_IDS := ["display_case_glass_vertical_01", "display_case_gallery_18_01"]
var _display_capacity_migration_pending := false
## Persisted auction instances only; AuctionManager owns their transitions.
var active_auctions: Array[Dictionary] = []
## Availability is persisted separately from an auction instance so rare watches
## keep their intended delay after loading a game.
var auction_availability: Dictionary = {}
var auction_round_index := 0
## Serializable world data only: no NodePaths or scene references belong here.
var facade_installations: Array[Dictionary] = []
var _next_facade_installation_id := 1
var facility_installations: Array[Dictionary] = []
var _next_facility_installation_id := 1
var wall_finishes: Dictionary = {}
## Future employee and production systems write these gameplay values; FinanceManager
## only reads them to calculate a monthly closing.
var active_employee_monthly_costs: Array[int] = []
var units_produced_this_month := 0
var finance_state: Dictionary = {}
## Accumulators for the current accounting period. They deliberately remain small:
## the game needs a readable summary, not a full accounting ledger.
var finance_period := _new_finance_period()
var last_closed_finance_summary: Dictionary = {}
var active_visitor_negotiation: Dictionary = {}
## Las visitas se guardan en orden de atención. Sólo la primera puede usar el TPV.
var visitor_negotiations: Array[Dictionary] = []
## Reviews are the sole source for the public 0-5 customer rating.
var customer_reviews: Array[Dictionary] = []
## The generated identity belongs to the visit, rather than to a visual profile.
## Persisting the cursor keeps names stable across save/load and unique enough for
## the small rolling review history.
var _next_customer_name_index := 0
## Evita que el visitante premium ocupe continuamente la segunda plaza.
var last_collector_spawn_day := -1

const CUSTOMER_NAME_GIVEN := ["Arelia", "Nivara", "Selune", "Virelia", "Orelia", "Calira", "Darevia", "Elvaira", "Lunessa", "Mirevon"]
const CUSTOMER_NAME_FAMILY := ["Velorin", "Cendral", "Orvessa", "Lunovar", "Serevin", "Valdren", "Corvane", "Neralis", "Aurelis", "Viremont"]

func _ready() -> void:
	_emit_stats()

## Restores every runtime value to the new-game baseline.
func reset_state() -> void:
	money = STARTING_MONEY
	reputation = STARTING_REPUTATION
	visitor_sales_count = 0
	current_day = 1
	has_main_door = false
	hidden_built_elements.clear()
	owned_pieces.clear()
	listed_pieces.clear()
	carried_watch.clear()
	purchase_history.clear()
	displayed_watch.clear()
	displayed_watches.clear()
	_display_capacity_migration_pending = false
	active_auctions.clear()
	auction_availability.clear()
	auction_round_index = 0
	facade_installations.clear()
	_next_facade_installation_id = 1
	facility_installations.clear()
	_next_facility_installation_id = 1
	wall_finishes.clear()
	active_employee_monthly_costs.clear()
	units_produced_this_month = 0
	finance_state.clear()
	finance_period = _new_finance_period()
	last_closed_finance_summary.clear()
	active_visitor_negotiation.clear()
	visitor_negotiations.clear()
	customer_reviews.clear()
	_next_customer_name_index = 0
	last_collector_spawn_day = -1
	_emit_stats()
	_emit_inventory()

func get_reputation_level() -> int:
	return reputation

func get_visitor_sales_count() -> int:
	return visitor_sales_count

func get_sales_required_for_level(level: int) -> int:
	var index := clampi(level - 1, 0, REPUTATION_SALES_THRESHOLDS.size() - 1)
	return int(REPUTATION_SALES_THRESHOLDS[index])

func get_reputation_progress() -> Dictionary:
	var level := get_reputation_level()
	var current_sales := get_sales_required_for_level(level)
	var is_max_level := level >= MAX_REPUTATION_LEVEL
	return {
		"level": level,
		"sales": visitor_sales_count,
		"current_level_sales": current_sales,
		"next_level_sales": current_sales if is_max_level else get_sales_required_for_level(level + 1),
		"is_max_level": is_max_level,
	}

func _recalculate_reputation_level() -> void:
	reputation = STARTING_REPUTATION
	for level in range(2, MAX_REPUTATION_LEVEL + 1):
		if visitor_sales_count >= get_sales_required_for_level(level):
			reputation = level
		else:
			break
	_emit_carried_watch()
	_notify_customer_reviews_changed()
	EventBus.facade_installations_reloaded.emit()
	EventBus.facility_installations_reloaded.emit()

func can_afford(amount: int) -> bool:
	return money >= amount

func can_make_voluntary_payment(amount: int) -> bool:
	return amount >= 0 and money >= 0 and can_afford(amount)

func apply_mandatory_expense(amount: int) -> void:
	if amount <= 0:
		return
	money -= amount
	finance_period["other_mandatory"] = int(finance_period["other_mandatory"]) + amount
	_emit_stats()

## Applies a closing as one persisted state change before notifying observers.
func apply_monthly_settlement(amount: int, new_finance_state: Dictionary) -> void:
	if amount <= 0:
		return
	finance_state = new_finance_state.duplicate(true)
	units_produced_this_month = 0
	money -= amount
	# A new month starts immediately after the closing. The applied closing is
	# preserved by FinanceManager; this summary then represents the new period.
	finance_period["operating_closing"] = amount
	last_closed_finance_summary = _build_finance_summary(finance_period)
	finance_period = _new_finance_period()
	_emit_stats()

func get_monthly_personnel_cost() -> int:
	var total := 0
	for cost in active_employee_monthly_costs:
		total += maxi(0, cost)
	return total

func set_finance_state(state: Dictionary) -> void:
	finance_state = state.duplicate(true)

func get_finance_state() -> Dictionary:
	return finance_state.duplicate(true)

func get_finance_summary() -> Dictionary:
	return _build_finance_summary(finance_period)

func get_last_closed_finance_summary() -> Dictionary:
	return last_closed_finance_summary.duplicate(true)

func _build_finance_summary(period: Dictionary) -> Dictionary:
	var income := int(period.get("sales", 0)) + int(period.get("refunds", 0))
	var expenses := int(period.get("purchases", 0)) + int(period.get("other_mandatory", 0)) + int(period.get("operating_closing", 0))
	return {
		"sales": int(period.get("sales", 0)),
		"refunds": int(period.get("refunds", 0)),
		"purchases": int(period.get("purchases", 0)),
		"other_mandatory": int(period.get("other_mandatory", 0)),
		"operating_closing": int(period.get("operating_closing", 0)),
		"income_total": income,
		"expense_total": expenses,
		"profit": income - expenses,
	}

func advance_day() -> int:
	current_day += 1
	return current_day

## Compatibility entry point for simulation systems.
func pass_day() -> int:
	return advance_day()

func buy_main_door() -> bool:
	if has_main_door or not can_make_voluntary_payment(MAIN_DOOR_PRICE):
		return false
	money -= MAIN_DOOR_PRICE
	_record_purchase(MAIN_DOOR_PRICE)
	has_main_door = true
	hidden_built_elements["main_door"] = false
	_emit_stats()
	return true

## The placement controller validates geometry. This method atomically records and pays
## for an already-valid installation without knowing anything about scene nodes.
func try_install_facade_item(item_id: String, wall_id: String, transform_data: Dictionary, price: int, footprint: Dictionary = {}) -> bool:
	if item_id.is_empty() or wall_id.is_empty() or price < 0 or not can_make_voluntary_payment(price):
		return false
	if not _is_valid_transform_data(transform_data):
		return false
	var installation := {
		"installation_id": "facade_%d" % _next_facade_installation_id,
		"item_id": item_id,
		"wall_id": wall_id,
		"transform": transform_data.duplicate(true),
		"footprint": _sanitize_footprint(footprint),
		"purchase_price": price,
	}
	_next_facade_installation_id += 1
	money -= price
	_record_purchase(price)
	facade_installations.append(installation)
	_emit_stats()
	EventBus.facade_installation_added.emit(installation.duplicate(true))
	return true

func get_facade_installations() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for installation in facade_installations:
		result.append(installation.duplicate(true))
	return result

func try_install_facility(item_id: String, transform_data: Dictionary, price: int, footprint: Dictionary) -> bool:
	if item_id.is_empty() or price < 0 or not can_make_voluntary_payment(price) or not _is_valid_transform_data(transform_data):
		return false
	var installation := {
		"installation_id": "facility_%d" % _next_facility_installation_id,
		"item_id": item_id,
		"transform": transform_data.duplicate(true),
		"footprint": _sanitize_facility_footprint(footprint),
		"purchase_price": price,
	}
	_next_facility_installation_id += 1
	money -= price
	_record_purchase(price)
	facility_installations.append(installation)
	_emit_stats()
	EventBus.facility_installation_added.emit(installation.duplicate(true))
	return true

func get_facility_installations() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for installation in facility_installations:
		result.append(installation.duplicate(true))
	return result

## Commerce requires an installed point of sale, independently of its visual scene.
func can_access_commerce() -> bool:
	for installation in facility_installations:
		if String(installation.get("item_id", "")) == POINT_OF_SALE_FACILITY_ID:
			return true
	return false

func move_facility_installation(installation_id: String, transform_data: Dictionary, footprint: Dictionary) -> bool:
	if installation_id.is_empty() or not _is_valid_transform_data(transform_data):
		return false
	for index in range(facility_installations.size()):
		var installation := facility_installations[index]
		if String(installation.get("installation_id", "")) != installation_id:
			continue
		installation["transform"] = transform_data.duplicate(true)
		installation["footprint"] = _sanitize_facility_footprint(footprint)
		facility_installations[index] = installation
		EventBus.facility_installation_updated.emit(installation.duplicate(true))
		return true
	return false

func demolish_facility_installation(installation_id: String) -> int:
	for index in range(facility_installations.size()):
		var installation := facility_installations[index]
		if String(installation.get("installation_id", "")) != installation_id:
			continue
		if is_display_counter_occupied(installation_id):
			return 0
		var refund := floori(float(installation.get("purchase_price", 0)) * 0.8)
		facility_installations.remove_at(index)
		money += refund
		finance_period["refunds"] = int(finance_period["refunds"]) + refund
		_emit_stats()
		EventBus.facility_installation_removed.emit(installation_id, refund)
		return refund
	return 0

func is_display_counter_occupied(installation_id: String) -> bool:
	for entry in displayed_watches:
		if String(entry.get("facility_installation_id", "")) == installation_id:
			return true
	return false

func move_facade_installation(installation_id: String, wall_id: String, transform_data: Dictionary) -> bool:
	if installation_id.is_empty() or wall_id.is_empty() or not _is_valid_transform_data(transform_data):
		return false
	for index in range(facade_installations.size()):
		var installation := facade_installations[index]
		if String(installation.get("installation_id", "")) != installation_id:
			continue
		installation["wall_id"] = wall_id
		installation["transform"] = transform_data.duplicate(true)
		facade_installations[index] = installation
		EventBus.facade_installation_updated.emit(installation.duplicate(true))
		return true
	return false

func demolish_facade_installation(installation_id: String) -> int:
	for index in range(facade_installations.size()):
		var installation := facade_installations[index]
		if String(installation.get("installation_id", "")) != installation_id:
			continue
		var refund := floori(float(installation.get("purchase_price", 0)) * 0.8)
		facade_installations.remove_at(index)
		money += refund
		finance_period["refunds"] = int(finance_period["refunds"]) + refund
		_emit_stats()
		EventBus.facade_installation_removed.emit(installation_id, refund)
		return refund
	return 0

func get_wall_finish(wall_id: String) -> String:
	return String(wall_finishes.get(wall_id, "ivory"))

func set_wall_finish(wall_id: String, finish_id: String) -> bool:
	if wall_id.is_empty() or finish_id.is_empty():
		return false
	wall_finishes[wall_id] = finish_id
	EventBus.wall_finish_changed.emit(wall_id, finish_id)
	return true

func export_state() -> Dictionary:
	return {
		"version": 16,
		"money": money,
		"reputation": reputation,
		"visitor_sales_count": visitor_sales_count,
		"current_day": current_day,
		"has_main_door": has_main_door,
		"hidden_built_elements": hidden_built_elements.duplicate(true),
		"owned_pieces": owned_pieces.duplicate(true),
		"listed_pieces": listed_pieces.duplicate(true),
		"carried_watch": carried_watch.duplicate(true),
		"purchase_history": purchase_history.duplicate(true),
		"displayed_watch": displayed_watch.duplicate(true),
		"displayed_watches": displayed_watches.duplicate(true),
		"active_auctions": active_auctions.duplicate(true),
		"auction_availability": auction_availability.duplicate(true),
		"auction_round_index": auction_round_index,
		"facade_installations": get_facade_installations(),
		"next_facade_installation_id": _next_facade_installation_id,
		"facility_installations": get_facility_installations(),
		"next_facility_installation_id": _next_facility_installation_id,
		"wall_finishes": wall_finishes.duplicate(true),
		"active_employee_monthly_costs": active_employee_monthly_costs.duplicate(),
		"units_produced_this_month": units_produced_this_month,
		"finance_state": finance_state.duplicate(true),
		"finance_period": finance_period.duplicate(true),
		"last_closed_finance_summary": last_closed_finance_summary.duplicate(true),
		"active_visitor_negotiation": active_visitor_negotiation.duplicate(true),
		"visitor_negotiations": visitor_negotiations.duplicate(true),
		"customer_reviews": customer_reviews.duplicate(true),
		"next_customer_name_index": _next_customer_name_index,
		"last_collector_spawn_day": last_collector_spawn_day,
	}

func import_state(state: Dictionary) -> bool:
	if state.is_empty():
		return false
	money = _read_int(state.get("money"), STARTING_MONEY)
	var legacy_reputation := _read_int(state.get("reputation"), STARTING_REPUTATION)
	visitor_sales_count = _read_non_negative_int(state.get("visitor_sales_count"), floori(maxi(0, legacy_reputation) / 2.0))
	_recalculate_reputation_level()
	# Older saves have no calendar value and therefore start on day one.
	current_day = _read_positive_int(state.get("current_day"), 1)
	has_main_door = bool(state.get("has_main_door", false))
	hidden_built_elements = _sanitize_hidden_elements(state.get("hidden_built_elements", {}))
	owned_pieces = _sanitize_piece_list(state.get("owned_pieces", []))
	listed_pieces = _sanitize_piece_list(state.get("listed_pieces", []))
	carried_watch = _sanitize_carried_watch(state.get("carried_watch", {}))
	purchase_history = _sanitize_purchase_history(state.get("purchase_history", []))
	_display_capacity_migration_pending = false
	var saved_facilities: Variant = state.get("facility_installations", [])
	var displaced_display_unit_ids := _get_display_unit_ids_outside_capacity(state.get("displayed_watches", []), saved_facilities)
	_return_displaced_display_watches_to_inventory(displaced_display_unit_ids)
	_normalize_piece_ids()
	displayed_watch = _sanitize_displayed_watch(state.get("displayed_watch", {}))
	displayed_watches = _sanitize_displayed_watches(state.get("displayed_watches", []), saved_facilities)
	if displayed_watches.is_empty() and not displayed_watch.is_empty():
		displayed_watch["slot_index"] = 0
		displayed_watches.append(displayed_watch.duplicate(true))
	active_auctions = _sanitize_auction_list(state.get("active_auctions", []))
	auction_availability = _sanitize_auction_availability(state.get("auction_availability", {}))
	auction_round_index = _read_non_negative_int(state.get("auction_round_index"), 0)
	# Migration for saves from the original single Nexora-B auction.
	if active_auctions.is_empty():
		var legacy := _sanitize_auction_state(state.get("nexora_auction_state", {}))
		if not legacy.is_empty():
			legacy["instance_id"] = "legacy_nexora_b"
			legacy["lot_id"] = "nexora_b"
			active_auctions.append(legacy)
	facade_installations.clear()
	facility_installations.clear()
	wall_finishes.clear()
	active_employee_monthly_costs.clear()
	units_produced_this_month = _read_non_negative_int(state.get("units_produced_this_month"), 0)
	finance_state = state.get("finance_state", {}).duplicate(true) if state.get("finance_state", {}) is Dictionary else {}
	finance_period = _sanitize_finance_period(state.get("finance_period", {}))
	last_closed_finance_summary = _sanitize_finance_summary(state.get("last_closed_finance_summary", {}))
	_next_customer_name_index = _read_non_negative_int(state.get("next_customer_name_index"), 0)
	last_collector_spawn_day = _read_int(state.get("last_collector_spawn_day"), -1)
	visitor_negotiations = _sanitize_visitor_negotiations(state.get("visitor_negotiations", []))
	customer_reviews = _sanitize_customer_reviews(state.get("customer_reviews", []))
	# Las partidas anteriores sólo guardaban la visita activa.
	if visitor_negotiations.is_empty():
		var legacy_negotiation := _sanitize_visitor_negotiation(state.get("active_visitor_negotiation", {}))
		if not legacy_negotiation.is_empty():
			visitor_negotiations.append(legacy_negotiation)
	_sync_active_visitor_negotiation()
	var raw_employee_costs: Variant = state.get("active_employee_monthly_costs", [])
	if raw_employee_costs is Array:
		for cost in raw_employee_costs:
			if _is_number(cost) and int(cost) >= 0:
				active_employee_monthly_costs.append(int(cost))
	var raw_finishes: Variant = state.get("wall_finishes", {})
	if raw_finishes is Dictionary:
		for wall_id: Variant in raw_finishes:
			if wall_id is String and raw_finishes[wall_id] is String:
				wall_finishes[wall_id] = raw_finishes[wall_id]
	var used_ids: Dictionary = {}
	var fallback_id := 1
	var raw_installations: Variant = state.get("facade_installations", [])
	if raw_installations is Array:
		for raw_installation: Variant in raw_installations:
			if not raw_installation is Dictionary:
				continue
			var raw_dictionary: Dictionary = raw_installation
			var installation := _sanitize_facade_installation(raw_dictionary)
			if installation.is_empty():
				continue
			var installation_id := String(installation.get("installation_id", ""))
			while installation_id.is_empty() or used_ids.has(installation_id):
				installation_id = "facade_%d" % fallback_id
				fallback_id += 1
			installation["installation_id"] = installation_id
			used_ids[installation_id] = true
			facade_installations.append(installation)
	var minimum_next_id := _get_next_id_from_installations()
	_next_facade_installation_id = _read_positive_int(state.get("next_facade_installation_id"), minimum_next_id)
	if _next_facade_installation_id < minimum_next_id:
		_next_facade_installation_id = minimum_next_id
	var raw_facilities: Variant = state.get("facility_installations", [])
	var used_facility_ids: Dictionary = {}
	var fallback_facility_id := 1
	if raw_facilities is Array:
		for raw_facility: Variant in raw_facilities:
			if not raw_facility is Dictionary:
				continue
			if String(raw_facility.get("item_id", "")) in RETIRED_FACILITY_ITEM_IDS:
				continue
			var facility := _sanitize_facility_installation(raw_facility)
			if facility.is_empty():
				continue
			var facility_id := String(facility.get("installation_id", ""))
			while facility_id.is_empty() or used_facility_ids.has(facility_id):
				facility_id = "facility_%d" % fallback_facility_id
				fallback_facility_id += 1
			facility["installation_id"] = facility_id
			used_facility_ids[facility_id] = true
			facility_installations.append(facility)
	var minimum_next_facility_id := _get_next_facility_id()
	_next_facility_installation_id = _read_positive_int(state.get("next_facility_installation_id"), minimum_next_facility_id)
	if _next_facility_installation_id < minimum_next_facility_id:
		_next_facility_installation_id = minimum_next_facility_id
	_normalize_displayed_watch()
	_emit_stats()
	_emit_inventory()
	_emit_carried_watch()
	EventBus.purchase_history_changed.emit()
	EventBus.watch_display_changed.emit(get_watch_display_snapshot())
	notify_visitor_negotiation_changed()
	_notify_customer_reviews_changed()
	EventBus.facade_installations_reloaded.emit()
	EventBus.facility_installations_reloaded.emit()
	if _display_capacity_migration_pending:
		call_deferred("_emit_display_capacity_migration_feedback")
	return true

func has_pending_display_capacity_migration() -> bool:
	return _display_capacity_migration_pending

func mark_display_capacity_migration_saved() -> void:
	_display_capacity_migration_pending = false

func _emit_display_capacity_migration_feedback() -> void:
	EventBus.feedback_requested.emit("Relojes fuera de vitrina devueltos al inventario.", "info")

func is_built_element_hidden(element_id: String) -> bool:
	return bool(hidden_built_elements.get(element_id, false))

func set_built_element_hidden(element_id: String, hidden: bool) -> void:
	hidden_built_elements[element_id] = hidden

func buy_piece_from_virtual_auction(piece: Dictionary) -> bool:
	var price: int = piece.get("auction_price", 0)
	if price <= 0 or not carried_watch.is_empty() or not can_make_voluntary_payment(price):
		return false
	money -= price
	_record_purchase(price)
	carried_watch = piece.duplicate(true)
	if String(carried_watch.get("id", "")).is_empty():
		carried_watch["id"] = "commerce_piece_%d" % (purchase_history.size() + 1)
	_ensure_carried_watch_identity()
	carried_watch["sale_price"] = int(carried_watch.get("suggested_price", price))
	purchase_history.append({
		"unit_id": String(carried_watch["id"]),
		"lot_id": String(carried_watch.get("lot_id", "commerce")),
		"name": String(carried_watch.get("name", "Reloj adquirido")),
		"acquired_day": current_day,
		"price_paid": price,
		"estimated_low": int(carried_watch.get("estimated_low", price)),
		"estimated_high": int(carried_watch.get("estimated_high", price)),
		"status": "En transporte",
	})
	_emit_stats()
	_emit_carried_watch()
	EventBus.purchase_history_changed.emit()
	return true

## The auction manager calls this once on a player win. Won lots enter the
## inventory directly, ready to be assigned to a specific display slot by UI.
## UI must not transfer lots directly.
func award_auction_lot(lot: Dictionary, final_price: int) -> bool:
	if final_price <= 0 or not can_make_voluntary_payment(final_price):
		return false
	money -= final_price
	_record_purchase(final_price)
	var unit_id := "%s_%d" % [String(lot.get("lot_id", "auction_piece")), owned_pieces.size() + listed_pieces.size() + purchase_history.size() + 1]
	var piece: Dictionary = {
		"id": unit_id,
		"lot_id": String(lot.get("lot_id", "")),
		"item_type": String(lot.get("item_type", "watch")),
		"category": String(lot.get("category", "")),
		"tags": (lot.get("tags", []) as Array).duplicate(),
		"name": String(lot.get("name", "Pieza de subasta")),
		"detail": String(lot.get("detail", "Pieza adquirida en el Salón de Lotes")),
		"model_path": String(lot.get("model_path", "")),
		"preview_image_path": String(lot.get("preview_image_path", "")),
		"auction_price": final_price,
		"suggested_price": int(lot.get("suggested_price", final_price)),
		"estimated_low": int(lot.get("estimated_low", final_price)),
		"estimated_high": int(lot.get("estimated_high", final_price)),
		"sale_price": int(lot.get("suggested_price", final_price)),
		"brand": String(lot.get("brand", "")),
		"segment": String(lot.get("segment", "")),
		"quality_score": int(lot.get("quality_score", 70)),
		"movement_score": int(lot.get("movement_score", 70)),
		"jewelry_technique_id": String(lot.get("jewelry_technique_id", "legacy_unspecified")) if String(lot.get("item_type", "watch")) == "jewelry" else "",
		"brand_score": int(lot.get("brand_score", 60)),
		"condition_score": int(lot.get("condition_score", 80)),
		"rarity_score": int(lot.get("rarity_score", 50)),
		"market_demand_score": int(lot.get("market_demand_score", 60)),
	}
	piece["id"] = _unique_piece_id(unit_id, _get_used_piece_ids())
	unit_id = String(piece["id"])
	owned_pieces.append(piece)
	purchase_history.append({"unit_id": unit_id, "lot_id": String(lot.get("lot_id", "")), "name": String(lot.get("name", "Pieza de subasta")), "acquired_day": current_day, "price_paid": final_price, "estimated_low": int(lot.get("estimated_low", final_price)), "estimated_high": int(lot.get("estimated_high", final_price)), "status": "En inventario"})
	_emit_stats()
	_emit_inventory()
	EventBus.purchase_history_changed.emit()
	return true

func get_watch_valuation(watch: Dictionary, asking_price: int = -1) -> Dictionary:
	var price := asking_price if asking_price > 0 else int(watch.get("sale_price", watch.get("suggested_price", 0)))
	var appraisal_piece := watch.duplicate(true)
	if String(appraisal_piece.get("item_type", "watch")) == "jewelry":
		appraisal_piece["jewelry_technique_label"] = DataRegistry.get_jewelry_technique_label(String(appraisal_piece.get("jewelry_technique_id", "legacy_unspecified")))
	return WatchValuation.evaluate(appraisal_piece, price)

func get_display_counter_id() -> String:
	for installation in facility_installations:
		if _is_display_facility_item(String(installation.get("item_id", ""))):
			return String(installation.get("installation_id", ""))
	return ""

func is_display_facility(facility_installation_id: String) -> bool:
	return _get_display_slot_count(facility_installation_id) > 0

func get_display_slot_count(facility_installation_id: String) -> int:
	return _get_display_slot_count(facility_installation_id)

func get_display_slot(facility_installation_id: String, slot_index: int) -> Dictionary:
	var definition := _get_display_facility_definition(facility_installation_id)
	return definition.get_display_slot(slot_index) if definition != null else {}

func pick_up_owned_watch(piece_index: int, sale_price: int) -> bool:
	if not carried_watch.is_empty() or piece_index < 0 or piece_index >= owned_pieces.size() or sale_price <= 0:
		return false
	carried_watch = owned_pieces.pop_at(piece_index)
	_ensure_carried_watch_identity()
	carried_watch["sale_price"] = sale_price
	_update_history_status(String(carried_watch.get("id", "")), "En transporte")
	_emit_inventory()
	_emit_carried_watch()
	EventBus.purchase_history_changed.emit()
	return true

## Atomic hand-off invoked by the world proximity controller, never by UI.
func deposit_carried_watch(facility_installation_id: String, sale_price: int) -> bool:
	if carried_watch.is_empty() or sale_price <= 0 or get_watch_display_count_for_facility(facility_installation_id) >= _get_display_slot_count(facility_installation_id):
		return false
	if not is_display_facility(facility_installation_id):
		return false
	_ensure_carried_watch_identity()
	var piece := carried_watch.duplicate(true)
	piece["sale_price"] = sale_price
	var slot := _first_free_display_slot(facility_installation_id)
	if slot < 0:
		return false
	listed_pieces.append(piece)
	var display_entry := {"unit_id": String(piece.get("id", "")), "facility_installation_id": facility_installation_id, "sale_price": sale_price, "rotation_y": 0.0, "slot_index": slot}
	displayed_watches.append(display_entry)
	displayed_watch = display_entry.duplicate(true) # Compatibility with older saves/UI.
	_update_history_status(String(piece.get("id", "")), "En vitrina por %s €" % sale_price)
	carried_watch.clear()
	_emit_inventory()
	_emit_carried_watch()
	EventBus.purchase_history_changed.emit()
	EventBus.watch_display_changed.emit(get_watch_display_snapshot())
	return true

## Moves an owned watch directly into a chosen display slot. This keeps the
## physical carry state exclusively for world interactions that require it.
func display_owned_watch(piece_index: int, facility_installation_id: String, slot_index: int, sale_price: int) -> bool:
	if piece_index < 0 or piece_index >= owned_pieces.size() or sale_price <= 0:
		return false
	if not is_display_facility(facility_installation_id) or not is_display_slot_free(facility_installation_id, slot_index):
		return false
	var piece: Dictionary = owned_pieces.pop_at(piece_index)
	piece["sale_price"] = sale_price
	listed_pieces.append(piece)
	var display_entry := {"unit_id": String(piece.get("id", "")), "facility_installation_id": facility_installation_id, "sale_price": sale_price, "rotation_y": 0.0, "slot_index": slot_index}
	displayed_watches.append(display_entry)
	displayed_watch = display_entry.duplicate(true)
	_update_history_status(String(piece.get("id", "")), "En vitrina por %s €" % sale_price)
	_emit_inventory()
	EventBus.purchase_history_changed.emit()
	EventBus.watch_display_changed.emit(get_watch_display_snapshot())
	return true

func set_carried_watch_sale_price(sale_price: int) -> bool:
	if carried_watch.is_empty() or sale_price <= 0:
		return false
	carried_watch["sale_price"] = sale_price
	_emit_carried_watch()
	return true

## Updates the saved asking price without exposing collection mutations to UI.
func set_piece_sale_price(unit_id: String, sale_price: int) -> bool:
	if unit_id.is_empty() or sale_price <= 0 or is_visitor_reserved(unit_id):
		return false
	if String(carried_watch.get("id", "")) == unit_id:
		carried_watch["sale_price"] = sale_price
		_emit_carried_watch()
		return true
	for index in range(owned_pieces.size()):
		if String(owned_pieces[index].get("id", "")) == unit_id:
			owned_pieces[index]["sale_price"] = sale_price
			_emit_inventory()
			return true
	for index in range(listed_pieces.size()):
		if String(listed_pieces[index].get("id", "")) == unit_id:
			listed_pieces[index]["sale_price"] = sale_price
			for display_index in range(displayed_watches.size()):
				if String(displayed_watches[display_index].get("unit_id", "")) == unit_id:
					displayed_watches[display_index]["sale_price"] = sale_price
					displayed_watch = displayed_watches[display_index].duplicate(true)
			_emit_inventory()
			EventBus.watch_display_changed.emit(get_watch_display_snapshot())
			return true
	return false

func rotate_displayed_watch(delta_radians: float) -> bool:
	if displayed_watches.is_empty():
		return false
	displayed_watches[0]["rotation_y"] = float(displayed_watches[0].get("rotation_y", 0.0)) + delta_radians
	displayed_watch = displayed_watches[0].duplicate(true)
	EventBus.watch_display_changed.emit(get_watch_display_snapshot())
	return true

func get_watch_display_count() -> int:
	return displayed_watches.size()

func get_watch_display_count_for_facility(facility_installation_id: String) -> int:
	var count := 0
	for entry in displayed_watches:
		if String(entry.get("facility_installation_id", "")) == facility_installation_id:
			count += 1
	return count

func get_total_display_capacity() -> int:
	var capacity := 0
	for installation in facility_installations:
		capacity += _get_display_slot_count(String(installation.get("installation_id", "")))
	return capacity

func has_free_display_slot() -> bool:
	for installation in facility_installations:
		var facility_id := String(installation.get("installation_id", ""))
		if is_display_facility(facility_id) and get_watch_display_count_for_facility(facility_id) < _get_display_slot_count(facility_id):
			return true
	return false

func is_display_slot_free(facility_installation_id: String, slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= _get_display_slot_count(facility_installation_id):
		return false
	for entry in displayed_watches:
		if String(entry.get("facility_installation_id", "")) == facility_installation_id and int(entry.get("slot_index", -1)) == slot_index:
			return false
	return true

func get_watch_display_snapshot() -> Dictionary:
	return {"capacity": get_total_display_capacity(), "count": displayed_watches.size(), "watches": displayed_watches.duplicate(true)}

func get_displayed_watch(unit_id: String) -> Dictionary:
	var index := _displayed_watch_index(unit_id)
	return displayed_watches[index].duplicate(true) if index >= 0 else {}

## La pieza sólo queda bloqueada cuando el visitante ya ha terminado de verla
## y está en caja. Esperar fuera o entrar no equivale a una reserva.
func is_visitor_reserved(unit_id: String) -> bool:
	if unit_id.is_empty():
		return false
	for negotiation in visitor_negotiations:
		var state := String(negotiation.get("state", ""))
		if String(negotiation.get("unit_id", "")) == unit_id and (state == "waiting" or state == "active"):
			return true
	return false

## A displayed watch always occupies one explicit vitrina slot. Keeping relocation
## slot-based prevents free-form visual positions from leaking into saved gameplay.
func move_displayed_watch(unit_id: String, target_facility_id: String, target_slot_index: int) -> bool:
	var index := _displayed_watch_index(unit_id)
	if index < 0 or is_visitor_reserved(unit_id) or not is_display_facility(target_facility_id):
		return false
	if target_slot_index < 0 or target_slot_index >= _get_display_slot_count(target_facility_id):
		return false
	var current: Dictionary = displayed_watches[index]
	if String(current.get("facility_installation_id", "")) == target_facility_id and int(current.get("slot_index", -1)) == target_slot_index:
		return true
	if not is_display_slot_free(target_facility_id, target_slot_index):
		return false
	displayed_watches[index]["facility_installation_id"] = target_facility_id
	displayed_watches[index]["slot_index"] = target_slot_index
	if not displayed_watch.is_empty() and String(displayed_watch.get("unit_id", "")) == unit_id:
		displayed_watch = displayed_watches[index].duplicate(true)
	EventBus.watch_display_changed.emit(get_watch_display_snapshot())
	return true

func _first_free_display_slot(facility_installation_id: String) -> int:
	var used: Dictionary = {}
	for entry in displayed_watches:
		if String(entry.get("facility_installation_id", "")) == facility_installation_id:
			used[int(entry.get("slot_index", -1))] = true
	for slot in range(_get_display_slot_count(facility_installation_id)):
		if not used.has(slot): return slot
	return -1

func list_piece_for_sale(piece_index: int, sale_price: int) -> bool:
	# Kept as a compatibility API, but direct UI listing is intentionally disabled.
	return false

func complete_sale(listed_index: int) -> bool:
	if listed_index < 0 or listed_index >= listed_pieces.size():
		return false
	var candidate: Dictionary = listed_pieces[listed_index]
	if is_visitor_reserved(String(candidate.get("id", ""))):
		return false
	var piece: Dictionary = listed_pieces.pop_at(listed_index)
	var unit_id := String(piece.get("id", ""))
	var displayed_index := _displayed_watch_index(unit_id)
	if displayed_index >= 0:
		displayed_watches.remove_at(displayed_index)
		displayed_watch = displayed_watches[0].duplicate(true) if not displayed_watches.is_empty() else {}
		_update_history_sale(unit_id, int(piece.get("sale_price", 0)))
		EventBus.watch_display_changed.emit(get_watch_display_snapshot())
		EventBus.purchase_history_changed.emit()
	money += int(piece.get("sale_price", 0))
	finance_period["sales"] = int(finance_period["sales"]) + int(piece.get("sale_price", 0))
	_emit_stats()
	_emit_inventory()
	return true

func complete_visitor_sale(unit_id: String, final_price: int) -> bool:
	if unit_id.is_empty() or final_price <= 0:
		return false
	var listed_index := -1
	for index in listed_pieces.size():
		if String(listed_pieces[index].get("id", "")) == unit_id:
			listed_index = index
			break
	if listed_index < 0:
		return false
	var displayed_index := _displayed_watch_index(unit_id)
	if displayed_index < 0:
		return false
	listed_pieces.remove_at(listed_index)
	displayed_watches.remove_at(displayed_index)
	displayed_watch = displayed_watches[0].duplicate(true) if not displayed_watches.is_empty() else {}
	_update_history_sale(unit_id, final_price)
	money += final_price
	visitor_sales_count += 1
	_recalculate_reputation_level()
	finance_period["sales"] = int(finance_period["sales"]) + final_price
	EventBus.watch_display_changed.emit(get_watch_display_snapshot())
	EventBus.purchase_history_changed.emit()
	_emit_stats()
	_emit_inventory()
	return true

func add_customer_review(rating: int, emoji: String, text: String, customer_name := "") -> void:
	if emoji.is_empty() or text.is_empty():
		return
	customer_reviews.append({
		"rating": clampi(rating, 1, 5),
		"emoji": emoji,
		"text": text,
		"day": current_day,
		"customer_name": _sanitize_customer_name(customer_name),
	})
	# A compact history keeps saves and the HUD responsive while retaining recent sentiment.
	if customer_reviews.size() > 100:
		customer_reviews.pop_front()
	_notify_customer_reviews_changed()

func get_customer_reviews() -> Array[Dictionary]:
	return customer_reviews.duplicate(true)

func get_customer_rating() -> float:
	if customer_reviews.is_empty():
		return 0.0
	var total := 0
	for review in customer_reviews:
		total += int(review.get("rating", 0))
	return float(total) / float(customer_reviews.size())

func set_active_visitor_negotiation(negotiation: Dictionary) -> void:
	var sanitized := _sanitize_visitor_negotiation(negotiation)
	visitor_negotiations = [sanitized] if not sanitized.is_empty() else []
	_sync_active_visitor_negotiation()
	notify_visitor_negotiation_changed()

func clear_active_visitor_negotiation() -> void:
	visitor_negotiations.clear()
	_sync_active_visitor_negotiation()
	notify_visitor_negotiation_changed()

func set_visitor_negotiations(negotiations: Array[Dictionary]) -> void:
	visitor_negotiations = _sanitize_visitor_negotiations(negotiations)
	_sync_active_visitor_negotiation()
	notify_visitor_negotiation_changed()

func get_visitor_negotiations() -> Array[Dictionary]:
	return visitor_negotiations.duplicate(true)

func _sync_active_visitor_negotiation() -> void:
	active_visitor_negotiation = visitor_negotiations[0].duplicate(true) if not visitor_negotiations.is_empty() else {}

func notify_visitor_negotiation_changed() -> void:
	EventBus.visitor_negotiation_changed.emit(active_visitor_negotiation.duplicate(true))

func generate_customer_name() -> String:
	var name_index := _next_customer_name_index
	_next_customer_name_index += 1
	var family_index := int(name_index / CUSTOMER_NAME_GIVEN.size()) % CUSTOMER_NAME_FAMILY.size()
	return "%s %s" % [CUSTOMER_NAME_GIVEN[name_index % CUSTOMER_NAME_GIVEN.size()], CUSTOMER_NAME_FAMILY[family_index]]

func _sanitize_customer_name(value: Variant) -> String:
	var customer_name := String(value).strip_edges()
	return customer_name if not customer_name.is_empty() else generate_customer_name()

func _sanitize_visitor_negotiation(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {}
	var negotiation: Dictionary = raw
	var profile_id := String(negotiation.get("profile_id", ""))
	var unit_id := String(negotiation.get("unit_id", ""))
	if profile_id.is_empty() or unit_id.is_empty():
		return {}
	var max_patience := clampi(_read_positive_int(negotiation.get("max_patience"), 3), 1, 5)
	return {
		"profile_id": profile_id, "unit_id": unit_id,
		"target_facility_installation_id": String(negotiation.get("target_facility_installation_id", "")),
		"customer_name": _sanitize_customer_name(negotiation.get("customer_name", "")),
		"search_intent": negotiation.get("search_intent", {}).duplicate(true) if negotiation.get("search_intent", {}) is Dictionary else {},
		"state": String(negotiation.get("state", "waiting")),
		"offer": _read_positive_int(negotiation.get("offer"), 1),
		"budget": _read_positive_int(negotiation.get("budget"), 1),
		"patience": clampi(_read_positive_int(negotiation.get("patience"), max_patience), 1, max_patience),
		"max_patience": max_patience,
		"turns": _read_non_negative_int(negotiation.get("turns"), 0),
		"customer_slot": clampi(int(negotiation.get("customer_slot", -1)), -1, 1),
	}

func _sanitize_visitor_negotiations(raw: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var reserved_units: Dictionary = {}
	var assigned_customer_slots: Dictionary = {}
	if not raw is Array:
		return result
	for entry in raw:
		var negotiation := _sanitize_visitor_negotiation(entry)
		var unit_id := String(negotiation.get("unit_id", ""))
		if negotiation.is_empty() or reserved_units.has(unit_id):
			continue
		var customer_slot := int(negotiation.get("customer_slot", -1))
		if customer_slot < 0 or assigned_customer_slots.has(customer_slot):
			customer_slot = 0 if not assigned_customer_slots.has(0) else 1
		negotiation["customer_slot"] = customer_slot
		reserved_units[unit_id] = true
		assigned_customer_slots[customer_slot] = true
		result.append(negotiation)
		if result.size() == 2:
			break
	return result

func _sanitize_customer_reviews(raw: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not raw is Array:
		return result
	for entry in raw:
		if not entry is Dictionary:
			continue
		var review: Dictionary = entry
		var emoji := String(review.get("emoji", ""))
		var text := String(review.get("text", ""))
		if emoji.is_empty() or text.is_empty():
			continue
		result.append({
			"rating": clampi(_read_positive_int(review.get("rating"), 1), 1, 5),
			"emoji": emoji,
			"text": text,
			"day": _read_positive_int(review.get("day"), 1),
			"customer_name": _sanitize_customer_name(review.get("customer_name", "")),
		})
		if result.size() == 100:
			break
	return result

func _sanitize_facade_installation(raw: Dictionary) -> Dictionary:
	var item_id: Variant = raw.get("item_id")
	var wall_id: Variant = raw.get("wall_id")
	var transform_data: Variant = raw.get("transform")
	if not item_id is String or item_id.is_empty() or not wall_id is String or wall_id.is_empty() or not transform_data is Dictionary:
		return {}
	if not _is_valid_transform_data(transform_data):
		return {}
	return {
		"installation_id": String(raw.get("installation_id", "")),
		"item_id": item_id,
		"wall_id": wall_id,
		"transform": transform_data.duplicate(true),
		"footprint": _sanitize_footprint(raw.get("footprint", {})),
		"purchase_price": _read_non_negative_int(raw.get("purchase_price"), 650),
	}

func _sanitize_facility_installation(raw: Dictionary) -> Dictionary:
	var item_id: Variant = raw.get("item_id")
	var transform_data: Variant = raw.get("transform")
	if not item_id is String or item_id.is_empty() or not transform_data is Dictionary or not _is_valid_transform_data(transform_data):
		return {}
	return {
		"installation_id": String(raw.get("installation_id", "")),
		"item_id": item_id,
		"transform": transform_data.duplicate(true),
		"footprint": _sanitize_facility_footprint(raw.get("footprint", {})),
		"purchase_price": _read_non_negative_int(raw.get("purchase_price"), 0),
	}

func _sanitize_footprint(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var result := {}
	for key in ["half_width", "half_height"]:
		if _is_number(value.get(key)) and float(value[key]) > 0.0:
			result[key] = float(value[key])
	return result

func _sanitize_hidden_elements(value: Variant) -> Dictionary:
	var result := {}
	if value is Dictionary:
		for element_id: Variant in value:
			if element_id is String and value[element_id] is bool:
				result[element_id] = value[element_id]
	return result

func _sanitize_piece_list(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for piece: Variant in value:
			if piece is Dictionary:
				var clean: Dictionary = piece.duplicate(true)
				if String(clean.get("item_type", "watch")) == "watch" and String(clean.get("model_path", "")).is_empty():
					clean["model_path"] = DEFAULT_WATCH_MODEL_PATH
				result.append(clean)
	return result

func _sanitize_carried_watch(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var result: Dictionary = (value as Dictionary).duplicate(true)
	# An omitted or empty saved payload means the watchmaker is not carrying
	# anything. Do not turn it into a watch merely by supplying a fallback model.
	if result.is_empty() or (result.size() == 1 and result.has("model_path")):
		return {}
	if String(result.get("item_type", "watch")) == "watch" and String(result.get("model_path", "")).is_empty():
		result["model_path"] = DEFAULT_WATCH_MODEL_PATH
	return result

func _normalize_piece_ids() -> void:
	var used: Dictionary = {}
	for index in range(owned_pieces.size()):
		var piece := owned_pieces[index]
		piece["id"] = _unique_piece_id(String(piece.get("id", "")), used)
		owned_pieces[index] = piece
	for index in range(listed_pieces.size()):
		var piece := listed_pieces[index]
		piece["id"] = _unique_piece_id(String(piece.get("id", "")), used)
		listed_pieces[index] = piece
	if not carried_watch.is_empty():
		carried_watch["id"] = _unique_piece_id(String(carried_watch.get("id", "")), used)

func _ensure_carried_watch_identity() -> void:
	if carried_watch.is_empty():
		return
	var used: Dictionary = {}
	for piece in owned_pieces:
		used[String(piece.get("id", ""))] = true
	for piece in listed_pieces:
		used[String(piece.get("id", ""))] = true
	carried_watch["id"] = _unique_piece_id(String(carried_watch.get("id", "")), used)
	if String(carried_watch.get("item_type", "watch")) == "watch" and String(carried_watch.get("model_path", "")).is_empty():
		carried_watch["model_path"] = DEFAULT_WATCH_MODEL_PATH

func _get_used_piece_ids() -> Dictionary:
	var used: Dictionary = {}
	for piece in owned_pieces:
		used[String(piece.get("id", ""))] = true
	for piece in listed_pieces:
		used[String(piece.get("id", ""))] = true
	if not carried_watch.is_empty():
		used[String(carried_watch.get("id", ""))] = true
	return used

func _unique_piece_id(preferred_id: String, used: Dictionary) -> String:
	var base := preferred_id.strip_edges()
	if base.is_empty():
		base = "legacy_piece"
	var candidate := base
	var suffix := 2
	while used.has(candidate):
		candidate = "%s_%d" % [base, suffix]
		suffix += 1
	used[candidate] = true
	return candidate

func _sanitize_purchase_history(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for entry in value:
			if entry is Dictionary and not String(entry.get("unit_id", "")).is_empty():
				var clean: Dictionary = entry.duplicate(true)
				# Older saves only stored the sale in the display string. Preserve that
				# record and expose a structured final price for the history UI.
				var status := String(clean.get("status", ""))
				if status.begins_with("Vendida por ") and not clean.has("final_price"):
					var legacy_price := status.trim_prefix("Vendida por ").trim_suffix(" €")
					if legacy_price.is_valid_int():
						clean["final_price"] = int(legacy_price)
				result.append(clean)
	return result

func _sanitize_displayed_watch(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var unit_id := String(value.get("unit_id", ""))
	var facility_id := String(value.get("facility_installation_id", ""))
	if unit_id.is_empty() or facility_id.is_empty() or int(value.get("sale_price", 0)) <= 0:
		return {}
	return {"unit_id": unit_id, "facility_installation_id": facility_id, "sale_price": int(value.get("sale_price", 0)), "rotation_y": float(value.get("rotation_y", 0.0))}

## Finds watches stored in slots removed by the current shared capacity.
func _get_display_unit_ids_outside_capacity(value: Variant, saved_facilities: Variant) -> Dictionary:
	var unit_ids: Dictionary = {}
	if value is Array:
		for entry in value:
			if not entry is Dictionary:
				continue
			var slot := int(entry.get("slot_index", -1))
			var unit_id := String(entry.get("unit_id", ""))
			if slot >= _get_saved_display_slot_count(String(entry.get("facility_installation_id", "")), saved_facilities) and not unit_id.is_empty():
				unit_ids[unit_id] = true
	return unit_ids

## Restores pieces from removed slots before display normalization can discard them.
func _return_displaced_display_watches_to_inventory(unit_ids: Dictionary) -> void:
	if unit_ids.is_empty():
		return
	var remaining_listed: Array[Dictionary] = []
	var returned_count := 0
	for piece in listed_pieces:
		var unit_id := String(piece.get("id", ""))
		if unit_ids.has(unit_id):
			var returned_piece := piece.duplicate(true)
			returned_piece.erase("sale_price")
			owned_pieces.append(returned_piece)
			_update_history_status(unit_id, "En inventario")
			returned_count += 1
		else:
			remaining_listed.append(piece)
	listed_pieces = remaining_listed
	if returned_count > 0:
		_display_capacity_migration_pending = true

func _sanitize_displayed_watches(value: Variant, saved_facilities: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var used_units: Dictionary = {}
	var used_slots: Dictionary = {}
	if value is Array:
		for entry in value:
			var clean := _sanitize_displayed_watch(entry)
			var slot := int((entry as Dictionary).get("slot_index", -1)) if entry is Dictionary else -1
			var slot_key := "%s:%d" % [String(clean.get("facility_installation_id", "")), slot]
			if clean.is_empty() or slot < 0 or slot >= _get_saved_display_slot_count(String(clean.get("facility_installation_id", "")), saved_facilities) or used_units.has(String(clean.get("unit_id", ""))) or used_slots.has(slot_key): continue
			clean["slot_index"] = slot
			used_units[String(clean.get("unit_id", ""))] = true
			used_slots[slot_key] = true
			result.append(clean)
	return result

func _displayed_watch_index(unit_id: String) -> int:
	for index in range(displayed_watches.size()):
		if String(displayed_watches[index].get("unit_id", "")) == unit_id: return index
	return -1

## Every saved display depends on a physical counter and a listed item. Recover
## invalid entries instead of retaining invisible watches that reserve a slot.
func _normalize_displayed_watch() -> void:
	var valid_entries: Array[Dictionary] = []
	for entry in displayed_watches:
		var unit_id := String(entry.get("unit_id", ""))
		var listed_index := -1
		for index in range(listed_pieces.size()):
			if String(listed_pieces[index].get("id", "")) == unit_id:
				listed_index = index
				break
		var facility_id := String(entry.get("facility_installation_id", ""))
		var slot_index := int(entry.get("slot_index", -1))
		if is_display_facility(facility_id) and slot_index >= 0 and slot_index < _get_display_slot_count(facility_id) and listed_index >= 0:
			valid_entries.append(entry)
			continue
		if listed_index >= 0:
			var piece: Dictionary = listed_pieces.pop_at(listed_index)
			piece.erase("sale_price")
			owned_pieces.append(piece)
			_update_history_status(unit_id, "En inventario")
	displayed_watches = valid_entries
	displayed_watch = displayed_watches[0].duplicate(true) if not displayed_watches.is_empty() else {}

func _update_history_status(unit_id: String, status: String) -> void:
	for index in range(purchase_history.size()):
		if String(purchase_history[index].get("unit_id", "")) == unit_id:
			purchase_history[index]["status"] = status
			return

func _update_history_sale(unit_id: String, final_price: int) -> void:
	for index in range(purchase_history.size()):
		if String(purchase_history[index].get("unit_id", "")) == unit_id:
			purchase_history[index]["status"] = "Vendida"
			purchase_history[index]["final_price"] = final_price
			purchase_history[index]["sold_day"] = current_day
			return

func _sanitize_auction_list(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for entry: Variant in value:
			var state := _sanitize_auction_state(entry)
			if not state.is_empty():
				state["instance_id"] = String((entry as Dictionary).get("instance_id", ""))
				state["lot_id"] = String((entry as Dictionary).get("lot_id", ""))
				if not String(state["instance_id"]).is_empty() and not String(state["lot_id"]).is_empty():
					result.append(state)
	return result

func _sanitize_auction_availability(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if not value is Dictionary:
		return result
	for raw_lot_id: Variant in value:
		var lot_id := String(raw_lot_id)
		if lot_id.is_empty() or not _is_number(value[raw_lot_id]):
			continue
		result[lot_id] = maxi(0, int(value[raw_lot_id]))
	return result

func _sanitize_auction_state(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var raw: Dictionary = value
	var phase := String(raw.get("phase", ""))
	if phase not in ["active", "resolved"]:
		return {}
	var leader_id := String(raw.get("leader_id", "none"))
	if leader_id not in ["none", "player", "collector"]:
		leader_id = "none"
	var npc_bid_budgets: Array[int] = []
	if raw.get("npc_bid_budgets") is Array:
		for raw_budget in raw["npc_bid_budgets"]:
			if _is_number(raw_budget) and int(raw_budget) > 0 and npc_bid_budgets.size() < 7:
				npc_bid_budgets.append(int(raw_budget))
	return {
		"phase": phase,
		"remaining_seconds": maxf(0.0, float(raw.get("remaining_seconds", 0.0))) if _is_number(raw.get("remaining_seconds")) else 0.0,
		"current_bid": _read_positive_int(raw.get("current_bid"), 180),
		"player_bid": _read_non_negative_int(raw.get("player_bid"), 0),
		"bid_increment": _read_positive_int(raw.get("bid_increment"), 10),
		"leader_id": leader_id,
		"npc_max_bid": _read_positive_int(raw.get("npc_max_bid"), 240),
		"npc_interest": clampi(_read_non_negative_int(raw.get("npc_interest"), 0), 0, 100),
		"npc_bid_budgets": npc_bid_budgets,
		"npc_bidder_plan_generated": bool(raw.get("npc_bidder_plan_generated", false)),
		"npc_response_seconds": float(raw.get("npc_response_seconds", -1.0)) if _is_number(raw.get("npc_response_seconds")) else -1.0,
		"late_npc_bid_delay": float(raw.get("late_npc_bid_delay", 0.0)) if _is_number(raw.get("late_npc_bid_delay")) else 0.0,
		"cooldown_seconds": maxf(0.0, float(raw.get("cooldown_seconds", 0.0))) if _is_number(raw.get("cooldown_seconds")) else 0.0,
	}

func _sanitize_facility_footprint(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var result := {}
	for key in ["half_x", "half_z"]:
		if _is_number(value.get(key)) and float(value[key]) > 0.0:
			result[key] = float(value[key])
	return result

func _is_valid_transform_data(transform_data: Dictionary) -> bool:
	var origin: Variant = transform_data.get("origin", [])
	var basis: Variant = transform_data.get("basis", [])
	if not origin is Array or not basis is Array or origin.size() != 3 or basis.size() != 9:
		return false
	for value in origin:
		if not _is_number(value):
			return false
	for value in basis:
		if not _is_number(value):
			return false
	return true

func _get_next_id_from_installations() -> int:
	var highest_id := 0
	for installation in facade_installations:
		var installation_id := String(installation.get("installation_id", ""))
		if installation_id.begins_with("facade_"):
			var suffix := installation_id.trim_prefix("facade_")
			if suffix.is_valid_int():
				highest_id = maxi(highest_id, suffix.to_int())
	return maxi(1, highest_id + 1)

func _get_next_facility_id() -> int:
	var highest_id := 0
	for installation in facility_installations:
		var installation_id := String(installation.get("installation_id", ""))
		if installation_id.begins_with("facility_"):
			var suffix := installation_id.trim_prefix("facility_")
			if suffix.is_valid_int():
				highest_id = maxi(highest_id, suffix.to_int())
	return maxi(1, highest_id + 1)

func _read_non_negative_int(value: Variant, fallback: int) -> int:
	if not _is_number(value):
		return fallback
	return maxi(0, int(value))

func _read_positive_int(value: Variant, fallback: int) -> int:
	if not _is_number(value) or int(value) <= 0 or float(value) != floor(float(value)):
		return fallback
	return int(value)

func _read_int(value: Variant, fallback: int) -> int:
	return int(value) if _is_number(value) else fallback

func _is_number(value: Variant) -> bool:
	return value is int or value is float

func _new_finance_period() -> Dictionary:
	return {"sales": 0, "refunds": 0, "purchases": 0, "other_mandatory": 0, "operating_closing": 0}

func _sanitize_finance_period(value: Variant) -> Dictionary:
	var result := _new_finance_period()
	if not value is Dictionary:
		return result
	var raw: Dictionary = value
	for key in result:
		if _is_number(raw.get(key)):
			result[key] = maxi(0, int(raw[key]))
	return result

func _record_purchase(amount: int) -> void:
	if amount > 0:
		finance_period["purchases"] = int(finance_period["purchases"]) + amount

func _sanitize_finance_summary(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var raw: Dictionary = value
	var period := _new_finance_period()
	for key in period:
		if _is_number(raw.get(key)):
			period[key] = maxi(0, int(raw[key]))
	return _build_finance_summary(period)

func _emit_stats() -> void:
	EventBus.stats_changed.emit(money, reputation)

func _notify_customer_reviews_changed() -> void:
	EventBus.customer_reviews_changed.emit(get_customer_rating(), get_customer_reviews())

func _emit_inventory() -> void:
	EventBus.inventory_changed.emit(owned_pieces.size(), listed_pieces.size())

func _emit_carried_watch() -> void:
	EventBus.carried_watch_changed.emit(carried_watch.duplicate(true))

func _get_display_slot_count(installation_id: String) -> int:
	var definition := _get_display_facility_definition(installation_id)
	return definition.display_slots.size() if definition != null else 0

func _get_saved_display_slot_count(installation_id: String, saved_facilities: Variant) -> int:
	if saved_facilities is Array:
		for raw_facility in saved_facilities:
			if raw_facility is Dictionary and String(raw_facility.get("installation_id", "")) == installation_id:
				var definition := DISPLAY_FACILITY_DEFINITIONS.get(String(raw_facility.get("item_id", ""))) as FacilityDefinition
				return definition.display_slots.size() if definition != null else 0
	return DISPLAY_CAPACITY

func _get_display_facility_definition(installation_id: String) -> FacilityDefinition:
	for installation in facility_installations:
		if String(installation.get("installation_id", "")) == installation_id:
			return DISPLAY_FACILITY_DEFINITIONS.get(String(installation.get("item_id", ""))) as FacilityDefinition
	return null

func _is_display_facility_item(item_id: String) -> bool:
	return DISPLAY_FACILITY_DEFINITIONS.has(item_id)

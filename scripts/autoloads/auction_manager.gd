extends Node

## Small, curated acquisition channel. Definitions are immutable; only generated
## instance state is persisted, so saves never reroll prices or competitors.
const AUCTION_SECONDS := 30.0
const RESULT_SECONDS := 0.0
const NPC_BIDDING_START_SECONDS := 10.0
const MAX_LOTS_PER_ROUND := 4
const LOTS_PATHS := ["res://data/watches/auction_lots.json", "res://data/jewelry/auction_lots.json"]
const WatchValuation = preload("res://scripts/gameplay/watch_valuation.gd")
const AuctionInterest = preload("res://scripts/gameplay/auction_interest.gd")

var _rng := RandomNumberGenerator.new()
var _seconds_since_checkpoint := 0.0
var _lots: Array[Dictionary] = []

func _ready() -> void:
	_rng.randomize()
	_lots = _load_lots()
	if _lots.is_empty():
		push_error("Auction catalogs are empty or invalid.")
		return
	if GameState.active_auctions.is_empty() or not _has_valid_round():
		_start_new_round()

func _process(delta: float) -> void:
	if _lots.is_empty():
		return
	# SaveManager can restore an empty or obsolete auction state after this
	# autoload's _ready. Repair it even while the simulation is paused, otherwise
	# the Salón de Lotes would remain empty until time is resumed.
	if GameState.active_auctions.is_empty() or not _has_valid_round():
		_start_new_round()
		return
	if TimeManager.is_paused:
		return
	var changed := false
	var all_resolved := true
	for index in range(GameState.active_auctions.size()):
		var state := GameState.active_auctions[index]
		_ensure_bidder_plan(state)
		var auction_delta := TimeManager.get_simulation_delta(delta)
		if String(state.get("phase", "active")) == "resolved":
			state["cooldown_seconds"] = maxf(0.0, float(state.get("cooldown_seconds", 0.0)) - auction_delta)
			GameState.active_auctions[index] = state
			changed = true
			continue
		all_resolved = false
		state["remaining_seconds"] = maxf(0.0, float(state.get("remaining_seconds", AUCTION_SECONDS)) - auction_delta)
		var scheduled_response := float(state.get("npc_response_seconds", -1.0))
		var response_after := scheduled_response - auction_delta
		state["npc_response_seconds"] = response_after
		if scheduled_response >= 0.0 and response_after <= 0.0:
			_apply_npc_bid(state)
		elif float(state["remaining_seconds"]) <= 0.0:
			_resolve(state)
		else:
			# Buyers begin competing without player input during the final seconds.
			# The generic leader represents several online collectors, not one bidder
			# artificially raising their own bid.
			if float(state["remaining_seconds"]) <= _npc_bidding_start_seconds(state):
				state["late_npc_bid_delay"] = float(state.get("late_npc_bid_delay", 0.0)) - auction_delta
				if float(state["late_npc_bid_delay"]) <= 0.0:
					_apply_npc_bid(state)
					continue
			GameState.active_auctions[index] = state
		changed = true
	if all_resolved and _all_cooldowns_finished():
		_start_new_round()
		return
	_seconds_since_checkpoint += TimeManager.get_simulation_delta(delta)
	if changed and _seconds_since_checkpoint >= 5.0:
		_seconds_since_checkpoint = 0.0
		EventBus.auction_state_persist_requested.emit()

func get_snapshots() -> Array[Dictionary]:
	var snapshots: Array[Dictionary] = []
	for state in GameState.active_auctions:
		var lot := _lot_for_id(String(state.get("lot_id", "")))
		if lot.is_empty():
			continue
		if String(lot.get("item_type", "watch")) == "jewelry":
			lot["jewelry_technique_label"] = DataRegistry.get_jewelry_technique_label(String(lot.get("jewelry_technique_id", "legacy_unspecified")))
		var phase := String(state.get("phase", "active"))
		var leader := String(state.get("leader_id", "none"))
		var player_bid := int(state.get("player_bid", 0))
		var status := "Activa" if phase == "active" else "Cerrada"
		if phase == "active" and leader == "player": status = "Vas ganando"
		elif phase == "active" and player_bid > 0: status = "Te han superado"
		elif phase == "active" and leader != "none": status = "En puja"
		var current_bid := int(state.get("current_bid", 0))
		snapshots.append(lot.merged({
			"instance_id": String(state.get("instance_id", "")), "phase": phase, "status": status,
			"current_bid": current_bid, "minimum_bid": current_bid + int(state.get("bid_increment", 10)),
			"player_bid": player_bid,
			"bid_increment": int(state.get("bid_increment", 10)), "highest_bidder": _leader_label(leader),
			"remaining_seconds": float(state.get("remaining_seconds", 0.0)), "cooldown_seconds": float(state.get("cooldown_seconds", 0.0)),
			"valuation": WatchValuation.evaluate(lot, current_bid),
		}, true))
	return snapshots

func place_player_bid(instance_id: String, amount: int) -> Dictionary:
	if not GameState.can_access_commerce():
		return {"success": false, "message": "Instala un Punto de venta antes de participar en pujas."}
	if not GameState.carried_watch.is_empty():
		return {"success": false, "message": "Deposita la pieza que transportas en una vitrina antes de pujar de nuevo."}
	var index := _index_for_instance(instance_id)
	if index < 0: return {"success": false, "message": "Este lote ya no está disponible."}
	var state := GameState.active_auctions[index]
	if String(state.get("phase", "")) != "active" or float(state.get("remaining_seconds", 0.0)) <= 0.0:
		return {"success": false, "message": "Esta subasta ya ha cerrado."}
	var minimum := int(state.get("current_bid", 0)) + int(state.get("bid_increment", 10))
	if amount != minimum: return {"success": false, "message": "La siguiente puja es %s €." % minimum}
	if not GameState.can_make_voluntary_payment(amount): return {"success": false, "message": "Fondos insuficientes para cubrir esta puja."}
	state["current_bid"] = amount
	# Keep the player's offer independent from the current leader. A collector can
	# overbid it later, but the active lot must remain identifiable in the UI.
	state["player_bid"] = amount
	state["leader_id"] = "player"
	state["npc_response_seconds"] = _rng.randf_range(4.0, 7.0) if _has_eligible_npc_bid(state) and float(state["remaining_seconds"]) > 8.0 else -1.0
	GameState.active_auctions[index] = state
	_emit_changed()
	return {"success": true, "message": "Puja líder. Solo se cobrará si ganas."}

func _start_new_round() -> void:
	_seconds_since_checkpoint = 0.0
	var first_catalogue_round := GameState.auction_round_index == 0 and GameState.auction_availability.is_empty()
	GameState.auction_round_index += 1
	var selected_lots := _select_lots_for_round(first_catalogue_round)
	GameState.active_auctions.clear()
	for lot in selected_lots:
		var state := {"instance_id": "round_%d_%s" % [Time.get_ticks_msec(), lot["lot_id"]], "lot_id": lot["lot_id"], "phase": "active", "remaining_seconds": AUCTION_SECONDS, "current_bid": int(lot.get("opening_bid", 180)), "player_bid": 0, "bid_increment": int(lot.get("bid_increment", 20)), "leader_id": "none", "npc_max_bid": int(lot.get("npc_max_bid", 240)), "npc_response_seconds": -1.0, "late_npc_bid_delay": _rng.randf_range(2.5, 4.5), "cooldown_seconds": 0.0}
		state.merge(AuctionInterest.create_bidder_plan(lot, _rng))
		GameState.active_auctions.append(state)
		GameState.auction_availability[String(lot["lot_id"])] = GameState.auction_round_index + _rounds_until_return(lot)
	_emit_changed()
	# On a first launch this autoload may run before SaveManager connects; defer a
	# persistence checkpoint so generated prices and rival limits are never lost.
	call_deferred("_request_persist")

func _request_persist() -> void:
	EventBus.auction_state_persist_requested.emit()

func _apply_npc_bid(state: Dictionary) -> void:
	var next_bid := int(state.get("current_bid", 0)) + int(state.get("bid_increment", 10))
	var budget := _take_next_eligible_npc_budget(state)
	if budget >= next_bid and float(state.get("remaining_seconds", 0.0)) > 2.0:
		state["current_bid"] = next_bid
		state["leader_id"] = "collector"
	state["npc_response_seconds"] = -1.0
	state["late_npc_bid_delay"] = _rng.randf_range(5.0, 8.0) if _has_eligible_npc_bid(state) else 999.0
	GameState.active_auctions[_index_for_instance(String(state["instance_id"]))] = state
	_emit_changed()

func _ensure_bidder_plan(state: Dictionary) -> void:
	if bool(state.get("npc_bidder_plan_generated", false)):
		return
	var lot := _lot_for_id(String(state.get("lot_id", "")))
	if lot.is_empty():
		state["npc_interest"] = 0
		state["npc_bid_budgets"] = []
		return
	state.merge(AuctionInterest.create_bidder_plan(lot, _rng))

func _has_eligible_npc_bid(state: Dictionary) -> bool:
	var next_bid := int(state.get("current_bid", 0)) + int(state.get("bid_increment", 10))
	for budget in state.get("npc_bid_budgets", []):
		if int(budget) >= next_bid:
			return true
	return false

func _npc_bidding_start_seconds(state: Dictionary) -> float:
	# Desirable lots attract early attention without requiring the player to make
	# the opening move. Ordinary pieces retain a quieter final-round cadence.
	var interest := int(state.get("npc_interest", 0))
	if interest >= 90:
		return 20.0
	if interest >= 75:
		return 15.0
	return NPC_BIDDING_START_SECONDS

func _take_next_eligible_npc_budget(state: Dictionary) -> int:
	var budgets: Array = state.get("npc_bid_budgets", [])
	var next_bid := int(state.get("current_bid", 0)) + int(state.get("bid_increment", 10))
	while not budgets.is_empty():
		var budget := int(budgets.pop_front())
		if budget >= next_bid:
			state["npc_bid_budgets"] = budgets
			return budget
	state["npc_bid_budgets"] = budgets
	return 0

func _resolve(state: Dictionary) -> void:
	var lot := _lot_for_id(String(state.get("lot_id", "")))
	var winner := String(state.get("leader_id", "none"))
	var price := int(state.get("current_bid", 0))
	var awarded := winner == "player" and GameState.award_auction_lot(lot, price)
	if winner == "player" and not awarded: winner = "none"
	state["phase"] = "resolved"; state["remaining_seconds"] = 0.0; state["cooldown_seconds"] = RESULT_SECONDS
	GameState.active_auctions[_index_for_instance(String(state["instance_id"]))] = state
	var message := "%s adjudicado por %s €. Está en el inventario: asígnale un precio y colócalo en una vitrina." % [lot["name"], price] if awarded else ("Otro coleccionista ha ganado %s." % lot["name"] if winner == "collector" else "%s ha cerrado sin adjudicación." % lot["name"])
	# Include the immutable catalogue snapshot so presentation can acknowledge a
	# player win without querying or mutating auction state after resolution.
	EventBus.auction_resolved.emit({"winner": winner, "final_price": price, "awarded": awarded, "lot": lot, "message": message})
	_emit_changed()

func _lot_for_id(lot_id: String) -> Dictionary:
	for lot in _lots:
		if String(lot["lot_id"]) == lot_id: return lot.duplicate(true)
	return {}
func _index_for_instance(instance_id: String) -> int:
	for index in range(GameState.active_auctions.size()):
		if String(GameState.active_auctions[index].get("instance_id", "")) == instance_id: return index
	return -1
func _all_cooldowns_finished() -> bool:
	for state in GameState.active_auctions:
		if float(state.get("cooldown_seconds", 0.0)) > 0.0: return false
	return true
func _has_valid_round() -> bool:
	if GameState.active_auctions.is_empty(): return false
	var seen_lot_ids: Dictionary = {}
	var seen_instance_ids: Dictionary = {}
	for state in GameState.active_auctions:
		var lot_id := String(state.get("lot_id", ""))
		var instance_id := String(state.get("instance_id", ""))
		if lot_id.is_empty() or instance_id.is_empty() or seen_lot_ids.has(lot_id) or seen_instance_ids.has(instance_id) or _lot_for_id(lot_id).is_empty(): return false
		seen_lot_ids[lot_id] = true
		seen_instance_ids[instance_id] = true
	return true

## Every catalogue piece is eligible for the opening selection. Later rounds
## rotate affordable pieces more quickly than exceptional scarce ones.
func _select_lots_for_round(include_all: bool) -> Array[Dictionary]:
	var eligible: Array[Dictionary] = []
	for lot in _lots:
		var available_after := int(GameState.auction_availability.get(String(lot["lot_id"]), 0))
		if include_all or GameState.auction_round_index >= available_after:
			eligible.append(lot)
	if eligible.is_empty():
	# A small catalogue must never leave the auction room empty. Pick the piece
		# whose scheduled return is nearest, while preserving its future scarcity.
		var earliest_lot: Dictionary = _lots[0]
		var earliest_round := int(GameState.auction_availability.get(String(earliest_lot["lot_id"]), 0))
		for lot in _lots:
			var available_after := int(GameState.auction_availability.get(String(lot["lot_id"]), 0))
			if available_after < earliest_round:
				earliest_lot = lot
				earliest_round = available_after
		eligible.append(earliest_lot)
	var selected: Array[Dictionary] = []
	var start_index := ((GameState.auction_round_index - 1) * MAX_LOTS_PER_ROUND) % eligible.size()
	for offset in range(mini(MAX_LOTS_PER_ROUND, eligible.size())):
		selected.append(eligible[(start_index + offset) % eligible.size()])
	return selected

func _rounds_until_return(lot: Dictionary) -> int:
	var stars := float(WatchValuation.evaluate(lot, int(lot.get("opening_bid", 1))).get("stars", 4.0))
	if stars >= 5.0:
		return 4 # Three full rounds absent before returning.
	if stars >= 4.5:
		return 2 # One full round absent before returning.
	return 0
func _round_to_increment(amount: int, increment: int) -> int: return maxi(increment, int(round(float(amount) / increment)) * increment)
func _leader_label(leader: String) -> String: return "Tú" if leader == "player" else ("Coleccionistas online" if leader == "collector" else "Sin pujas")
func _emit_changed() -> void: EventBus.auction_state_changed.emit({"lots": get_snapshots()})

func _load_lots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var used_ids: Dictionary = {}
	for path in LOTS_PATHS:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			push_error("Auction catalog could not be opened: %s" % path)
			continue
		var json := JSON.new()
		if json.parse(file.get_as_text()) != OK or not json.data is Dictionary:
			push_error("Auction catalog contains invalid JSON: %s" % path)
			continue
		for entry in (json.data as Dictionary).get("lots", []):
			if not entry is Dictionary:
				push_error("Auction catalog contains a non-dictionary lot.")
				continue
			var lot: Dictionary = entry
			var lot_id := String(lot.get("lot_id", ""))
			if used_ids.has(lot_id) or not _is_valid_lot(lot):
				push_error("Auction catalog has invalid lot data: %s" % lot_id)
				continue
			used_ids[lot_id] = true
			result.append(lot.duplicate(true))
	return result

func _is_valid_lot(lot: Dictionary) -> bool:
	for key in ["lot_id", "name", "brand", "segment", "item_type"]:
		if String(lot.get(key, "")).is_empty():
			return false
	if String(lot["item_type"]) not in ["watch", "jewelry"]:
		return false
	if String(lot["item_type"]) == "jewelry" and not DataRegistry.has_jewelry_technique(String(lot.get("jewelry_technique_id", ""))):
		return false
	for key in ["estimated_low", "estimated_high", "suggested_price", "opening_bid", "bid_increment", "npc_max_bid"]:
		# Godot's JSON parser represents all JSON numbers as float values.
		if not _is_number(lot.get(key)) or int(lot[key]) <= 0:
			return false
	if int(lot["estimated_low"]) > int(lot["estimated_high"]) or int(lot["opening_bid"]) > int(lot["npc_max_bid"]):
		return false
	for key in ["quality_score", "movement_score", "brand_score", "condition_score", "rarity_score", "market_demand_score"]:
		if not _is_number(lot.get(key)) or int(lot[key]) < 0 or int(lot[key]) > 100:
			return false
	return true

func _is_number(value: Variant) -> bool:
	return value is int or value is float

extends Node

const STARTING_MONEY := 5000
const STARTING_REPUTATION := 0
const MAIN_DOOR_PRICE := 850

var money := STARTING_MONEY
var reputation := STARTING_REPUTATION
var has_main_door := false
var hidden_built_elements: Dictionary = {}
var owned_pieces: Array[Dictionary] = []
var listed_pieces: Array[Dictionary] = []
## Serializable world data only: no NodePaths or scene references belong here.
var facade_installations: Array[Dictionary] = []
var _next_facade_installation_id := 1
var wall_finishes: Dictionary = {}

func _ready() -> void:
	_emit_stats()

func can_afford(amount: int) -> bool:
	return money >= amount

func buy_main_door() -> bool:
	if has_main_door or not can_afford(MAIN_DOOR_PRICE):
		return false
	money -= MAIN_DOOR_PRICE
	has_main_door = true
	hidden_built_elements["main_door"] = false
	_emit_stats()
	return true

## The placement controller validates geometry. This method atomically records and pays
## for an already-valid installation without knowing anything about scene nodes.
func try_install_facade_item(item_id: String, wall_id: String, transform_data: Dictionary, price: int, footprint: Dictionary = {}) -> bool:
	if item_id.is_empty() or wall_id.is_empty() or price < 0 or not can_afford(price):
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
	facade_installations.append(installation)
	_emit_stats()
	EventBus.facade_installation_added.emit(installation.duplicate(true))
	return true

func get_facade_installations() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for installation in facade_installations:
		result.append(installation.duplicate(true))
	return result

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
		"version": 1,
		"money": money,
		"reputation": reputation,
		"facade_installations": get_facade_installations(),
		"next_facade_installation_id": _next_facade_installation_id,
		"wall_finishes": wall_finishes.duplicate(true),
	}

func import_state(state: Dictionary) -> bool:
	if state.is_empty():
		return false
	money = _read_non_negative_int(state.get("money"), STARTING_MONEY)
	reputation = _read_int(state.get("reputation"), STARTING_REPUTATION)
	facade_installations.clear()
	wall_finishes.clear()
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
	_emit_stats()
	return true

func is_built_element_hidden(element_id: String) -> bool:
	return bool(hidden_built_elements.get(element_id, false))

func set_built_element_hidden(element_id: String, hidden: bool) -> void:
	hidden_built_elements[element_id] = hidden

func buy_piece_from_virtual_auction(piece: Dictionary) -> bool:
	var price: int = piece.get("auction_price", 0)
	if price <= 0 or not can_afford(price):
		return false
	money -= price
	owned_pieces.append(piece.duplicate(true))
	_emit_stats()
	_emit_inventory()
	return true

func list_piece_for_sale(piece_index: int, sale_price: int) -> bool:
	if piece_index < 0 or piece_index >= owned_pieces.size() or sale_price <= 0:
		return false
	var piece: Dictionary = owned_pieces.pop_at(piece_index)
	piece["sale_price"] = sale_price
	listed_pieces.append(piece)
	_emit_inventory()
	return true

func complete_sale(listed_index: int) -> bool:
	if listed_index < 0 or listed_index >= listed_pieces.size():
		return false
	var piece: Dictionary = listed_pieces.pop_at(listed_index)
	money += int(piece.get("sale_price", 0))
	_emit_stats()
	_emit_inventory()
	return true

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

func _sanitize_footprint(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var result := {}
	for key in ["half_width", "half_height"]:
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

func _emit_stats() -> void:
	EventBus.stats_changed.emit(money, reputation)

func _emit_inventory() -> void:
	EventBus.inventory_changed.emit(owned_pieces.size(), listed_pieces.size())

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

func _emit_stats() -> void:
	EventBus.stats_changed.emit(money, reputation)

func _emit_inventory() -> void:
	EventBus.inventory_changed.emit(owned_pieces.size(), listed_pieces.size())

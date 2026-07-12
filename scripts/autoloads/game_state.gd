extends Node

const STARTING_MONEY := 5000
const STARTING_REPUTATION := 0

var money := STARTING_MONEY
var reputation := STARTING_REPUTATION
var owned_pieces: Array[Dictionary] = []
var listed_pieces: Array[Dictionary] = []

func _ready() -> void:
	_emit_stats()

func can_afford(amount: int) -> bool:
	return money >= amount

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

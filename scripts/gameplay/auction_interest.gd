class_name AuctionInterest
extends RefCounted

## Converts the editorial qualities of a lot into a small, fixed pool of
## collector budgets. The pool is generated once per auction instance and is
## subsequently persisted by GameState.

static func create_bidder_plan(lot: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var interest := score(lot)
	var attempts := clampi(2 + floori(float(interest - 50) / 10.0), 2, 7)
	var increment := maxi(1, int(lot.get("bid_increment", 10)))
	var opening_bid := int(lot.get("opening_bid", increment))
	var catalogue_cap := int(lot.get("npc_max_bid", opening_bid))
	var estimated_low := int(lot.get("estimated_low", opening_bid))
	var estimated_high := maxi(estimated_low, int(lot.get("estimated_high", estimated_low)))
	var budgets: Array[int] = []
	var has_wealthy_collector := interest >= 75
	var modest_attempts := attempts - 1 if has_wealthy_collector else attempts
	for _attempt in range(modest_attempts):
		var modest_budget := round_down_to_increment(roundi(float(estimated_low) * rng.randf_range(0.80, 1.00)), increment)
		budgets.append(clampi(modest_budget, opening_bid, catalogue_cap))
	if has_wealthy_collector:
		var wealthy_budget := round_down_to_increment(roundi(estimated_low + float(estimated_high - estimated_low) * rng.randf_range(0.60, 1.00)), increment)
		budgets.append(clampi(wealthy_budget, opening_bid, catalogue_cap))
	return {"npc_interest": interest, "npc_bid_budgets": budgets, "npc_bidder_plan_generated": true}

static func score(lot: Dictionary) -> int:
	var interest := _stat(lot, "quality_score", 70) * 0.15
	interest += _stat(lot, "movement_score", 70) * 0.10
	interest += _stat(lot, "brand_score", 60) * 0.15
	interest += _stat(lot, "condition_score", 80) * 0.10
	interest += _stat(lot, "rarity_score", 50) * 0.20
	interest += _stat(lot, "market_demand_score", 60) * 0.30
	return clampi(roundi(interest), 0, 100)

static func round_down_to_increment(amount: int, increment: int) -> int:
	return int(floor(float(amount) / float(increment))) * increment

static func _stat(lot: Dictionary, key: String, fallback: int) -> int:
	return clampi(int(lot.get(key, fallback)), 0, 100)

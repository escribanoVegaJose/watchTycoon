class_name WatchValuation
extends RefCounted

## Pure commercial appraisal. Ratings are derived at display time, never saved.
## Price contributes only when it is coherent with the suggested value; a higher
## asking price therefore cannot improve an appraisal by itself.

static func evaluate(watch: Dictionary, asking_price: int) -> Dictionary:
	var quality := _score(watch, "quality_score", 70)
	var movement := _score(watch, "movement_score", 70)
	var brand := _score(watch, "brand_score", 60)
	var condition := _score(watch, "condition_score", 80)
	var rarity := _score(watch, "rarity_score", 50)
	var demand := _score(watch, "market_demand_score", 60)
	var suggested_price := maxi(1, int(watch.get("suggested_price", asking_price)))
	var price_fit := _price_fit(asking_price, suggested_price)
	var score := quality * 0.15 + movement * 0.10 + brand * 0.20 + condition * 0.15 + rarity * 0.15 + demand * 0.10 + price_fit * 0.15
	var stars := 4.0 if score < 80.0 else (4.5 if score < 90.0 else 5.0)
	var is_jewelry := String(watch.get("item_type", "watch")) == "jewelry"
	var movement_label := "Artesanía · %s" % String(watch.get("jewelry_technique_label", "Técnica sin catalogar")) if is_jewelry else "Mecanismo"
	return {
		"score": roundi(score),
		"stars": stars,
		"stars_text": _stars_text(stars),
		"label": "Pieza excepcional" if stars >= 5.0 else ("Pieza sobresaliente" if stars >= 4.5 else "Pieza recomendable"),
		"quality": quality,
		"movement": movement,
		"movement_label": movement_label,
		"brand": brand,
		"condition": condition,
		"rarity": rarity,
		"demand": demand,
		"price_fit": price_fit,
		"price_fit_label": "Muy coherente" if price_fit >= 90 else ("Coherente" if price_fit >= 75 else "Revisar precio"),
	}

static func _score(watch: Dictionary, key: String, fallback: int) -> int:
	return clampi(int(watch.get(key, fallback)), 0, 100)

static func _price_fit(price: int, suggested_price: int) -> int:
	if price <= 0:
		return 0
	var ratio := float(price) / float(suggested_price)
	# A modest discount remains attractive. Overpricing is penalised more strongly.
	var fit := 70.0 + ratio * 30.0 if ratio <= 1.0 else 100.0 - (ratio - 1.0) * 100.0
	return clampi(roundi(fit), 0, 100)

static func _stars_text(stars: float) -> String:
	if stars >= 5.0:
		return "★★★★★"
	if stars >= 4.5:
		return "★★★★½"
	return "★★★★☆"

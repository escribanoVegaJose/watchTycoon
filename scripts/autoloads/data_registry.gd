extends Node

const VISITORS_PATH := "res://data/visitors/visitors.json"
const JEWELRY_TECHNIQUES_PATH := "res://data/jewelry/techniques.json"
const WATCH_LOTS_PATH := "res://data/watches/auction_lots.json"
const JEWELRY_LOTS_PATH := "res://data/jewelry/auction_lots.json"
const VISITOR_VISUAL_IDS := ["standard_customer", "classic_customer", "gift_buyer", "aspirational_professional", "demanding_collector", "careful_retiree"]

var _visitor_profiles: Array[Dictionary] = []
var _jewelry_techniques: Dictionary = {}
var _lot_preview_paths: Dictionary = {}

func _ready() -> void:
	_load_visitors()
	_load_jewelry_techniques()
	_load_lot_preview_paths(WATCH_LOTS_PATH)
	_load_lot_preview_paths(JEWELRY_LOTS_PATH)

func get_visitor_profiles() -> Array[Dictionary]:
	return _visitor_profiles.duplicate(true)

func get_visitor_profile(profile_id: String) -> Dictionary:
	for profile in _visitor_profiles:
		if String(profile.get("id", "")) == profile_id:
			return profile.duplicate(true)
	return {}

func has_jewelry_technique(technique_id: String) -> bool:
	return _jewelry_techniques.has(technique_id)

func get_jewelry_technique_label(technique_id: String) -> String:
	var technique: Dictionary = _jewelry_techniques.get(technique_id, {})
	return String(technique.get("label", "Técnica sin catalogar"))

func get_lot_preview_path(lot_id: String) -> String:
	return String(_lot_preview_paths.get(lot_id, ""))

func _load_visitors() -> void:
	_visitor_profiles.clear()
	var file := FileAccess.open(VISITORS_PATH, FileAccess.READ)
	if file == null:
		push_error("No se pudo cargar el catálogo de visitantes.")
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not json.data is Dictionary:
		push_error("El catálogo de visitantes no es válido.")
		return
	var raw_profiles: Variant = (json.data as Dictionary).get("visitors", [])
	if not (raw_profiles is Array) or raw_profiles.is_empty():
		push_error("El catálogo de visitantes no contiene perfiles.")
		return
	for raw_profile in raw_profiles:
		if not (raw_profile is Dictionary):
			push_error("El catálogo de visitantes contiene un perfil inválido.")
			continue
		var profile: Dictionary = raw_profile
		var min_budget := int(profile.get("min_budget", 0))
		var max_budget := int(profile.get("max_budget", 0))
		var spawn_weight := int(profile.get("spawn_weight", 1))
		var segments: Variant = profile.get("preferred_segments", [])
		var visual_id := String(profile.get("visual_id", ""))
		var item_types: Variant = profile.get("required_item_types", [])
		var categories: Variant = profile.get("preferred_categories", [])
		var preferred_brands: Variant = profile.get("preferred_brands", [])
		var excluded_categories: Variant = profile.get("excluded_categories", [])
		var required_tags: Variant = profile.get("required_tags", [])
		var excluded_tags: Variant = profile.get("excluded_tags", [])
		var valid_visual := visual_id in VISITOR_VISUAL_IDS
		if String(profile.get("id", "")).is_empty() or not valid_visual or min_budget <= 0 or max_budget < min_budget or spawn_weight <= 0 or not (segments is Array) or segments.is_empty() or not (item_types is Array) or not (categories is Array) or not (preferred_brands is Array) or not (excluded_categories is Array) or not (required_tags is Array) or not (excluded_tags is Array):
			push_error("Perfil de visitante inválido: %s" % String(profile.get("id", "sin id")))
			continue
		_visitor_profiles.append(profile.duplicate(true))

func _load_jewelry_techniques() -> void:
	_jewelry_techniques.clear()
	var file := FileAccess.open(JEWELRY_TECHNIQUES_PATH, FileAccess.READ)
	if file == null:
		push_error("No se pudo cargar el catálogo de técnicas de joyería.")
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not json.data is Dictionary:
		push_error("El catálogo de técnicas de joyería no es válido.")
		return
	for raw_technique in (json.data as Dictionary).get("techniques", []):
		if not raw_technique is Dictionary:
			continue
		var technique: Dictionary = raw_technique
		var technique_id := String(technique.get("id", ""))
		if technique_id.is_empty() or String(technique.get("label", "")).is_empty() or _jewelry_techniques.has(technique_id):
			push_error("Técnica de joyería inválida: %s" % technique_id)
			continue
		_jewelry_techniques[technique_id] = technique.duplicate(true)

func _load_lot_preview_paths(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("No se pudo cargar el catálogo de previews: %s" % path)
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not json.data is Dictionary:
		push_error("El catálogo de previews no es válido: %s" % path)
		return
	for raw_lot in (json.data as Dictionary).get("lots", []):
		if not raw_lot is Dictionary:
			continue
		var lot: Dictionary = raw_lot
		var lot_id := String(lot.get("lot_id", ""))
		var preview_path := String(lot.get("preview_image_path", ""))
		if not lot_id.is_empty() and not preview_path.is_empty():
			_lot_preview_paths[lot_id] = preview_path

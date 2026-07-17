class_name VisitorNegotiationManager
extends Node

## Coordina dos visitas persistentes. GameState conserva las reservas y este nodo
## sólo asigna cuerpos físicos, cola y acceso exclusivo al TPV.
@export var customer_paths: Array[NodePath] = []
@export var watchmaker_path: NodePath
var customers: Array[CustomerVisitor] = []
var watchmaker: Node3D
var _arrived_at_counter: Dictionary = {}
var _next_practical_attempt := 0.0
var _departing_customer_ids: Dictionary = {}
var _negotiation_panel: VisitorNegotiationPanel
var _waiting_browse_customer: CustomerVisitor

func _ready() -> void:
	add_to_group("visitor_negotiation_manager")
	for path in customer_paths:
		var customer := get_node_or_null(path) as CustomerVisitor
		if customer != null:
			customer.customer_slot = customers.size()
			customers.append(customer)
	watchmaker = get_node_or_null(watchmaker_path) as Node3D
	# El modal vive en Main.tscn para que esté listo y conectado antes de que
	# cualquier visitante llegue a caja.
	if get_node_or_null("../HudLayer/VisitorNegotiationPanel") == null:
		var panel := VisitorNegotiationPanel.new()
		get_node("../HudLayer").add_child(panel)
	_negotiation_panel = get_node_or_null("../HudLayer/VisitorNegotiationPanel") as VisitorNegotiationPanel
	EventBus.visitor_negotiation_action_requested.connect(_on_action_requested)
	EventBus.visitor_door_open_requested.connect(admit_next_waiting_visitor)
	EventBus.facility_installations_reloaded.connect(_resume_visits)
	_next_practical_attempt = _practical_attempt_interval()
	if not GameState.get_visitor_negotiations().is_empty():
		call_deferred("_resume_visits")

func _try_start_pair() -> void:
	# A scheduled attempt never joins a partial queue or reuses a body that is
	# still walking out after a sale. This keeps the two visual slots authoritative.
	if not GameState.can_access_commerce() or customers.is_empty() or not GameState.get_visitor_negotiations().is_empty() or _waiting_browse_customer != null or not _departing_customer_ids.is_empty():
		return
	for customer in customers:
		if not customer.is_available_for_visit():
			return
	var negotiations: Array[Dictionary] = []
	var selected_unit_ids: Dictionary = {}
	var profile_ids := _profile_ids_for_rating()
	profile_ids.shuffle()
	for profile_id in profile_ids:
		if negotiations.size() >= customers.size():
			break
		if profile_id == "premium_collector" and not _collector_window_is_open():
			continue
		var profile := DataRegistry.get_visitor_profile(profile_id)
		var candidate := _best_candidate_for_profile(profile, "")
		if candidate.is_empty() or selected_unit_ids.has(String(candidate.get("id", ""))):
			continue
		selected_unit_ids[String(candidate["id"])] = true
		negotiations.append(_new_negotiation(profile_id, candidate, negotiations.size()))
		if profile_id == "premium_collector":
			GameState.last_collector_spawn_day = GameState.current_day
	if negotiations.is_empty():
		if not customers.is_empty() and not customers[0].is_leaving_store():
			_waiting_browse_customer = customers[0]
			EventBus.visitor_doorbell_requested.emit()
			_waiting_browse_customer.begin_waiting_to_browse()
		EventBus.feedback_requested.emit("Ha sonado el timbre: abre la puerta para dejar pasar al cliente.", "info")
		return
	GameState.set_visitor_negotiations(negotiations)
	_start_physical_visits()
	EventBus.visitor_doorbell_requested.emit()
	EventBus.feedback_requested.emit("Ha sonado el timbre: abre la puerta desde el punto de venta." if negotiations.size() == 1 else "Han llegado dos clientes: abre la puerta desde el punto de venta.", "info")

func _profile_ids_for_rating() -> Array[String]:
	var rating := clampf(maxf(1.0, GameState.get_customer_rating()), 1.0, 5.0)
	var result: Array[String] = []
	for profile in DataRegistry.get_visitor_profiles():
		if rating < float(profile.get("min_rating_stars", 1)) or rating > float(profile.get("max_rating_stars", 5)):
			continue
		for _weight in range(maxi(1, int(profile.get("spawn_weight", 1)))):
			result.append(String(profile.get("id", "")))
	return result

func _new_negotiation(profile_id: String, candidate: Dictionary, customer_slot: int) -> Dictionary:
	var profile := DataRegistry.get_visitor_profile(profile_id)
	var price := int(candidate.get("sale_price", 0))
	var display := GameState.get_displayed_watch(String(candidate.get("id", "")))
	var intentions: Array = profile.get("search_intentions", [])
	var intention: Dictionary = intentions.pick_random().duplicate(true) if not intentions.is_empty() else {}
	return {"profile_id": profile_id, "unit_id": String(candidate["id"]), "target_facility_installation_id": String(display.get("facility_installation_id", "")), "customer_name": GameState.generate_customer_name(), "search_intent": intention, "state": "waiting_outside", "offer": mini(int(round(price * _initial_offer_ratio(profile))), int(profile.get("max_budget", price))), "patience": int(profile.get("patience", 3)), "max_patience": int(profile.get("patience", 3)), "budget": int(profile.get("max_budget", 0)), "turns": 0, "customer_slot": customer_slot}

## Confirma la reserva después de que el cliente haya examinado la pieza.
## La validación tardía permite que precio, vitrina e idoneidad cambien mientras entra.
func customer_chose_piece(visitor_id: String) -> bool:
	var negotiations := GameState.get_visitor_negotiations()
	for index in negotiations.size():
		var customer := _customer_for_negotiation(negotiations[index], index)
		if customer != null and customer.visitor_instance_id == visitor_id:
			var negotiation: Dictionary = negotiations[index]
			if String(negotiation.get("state", "")) != "entering":
				return false
			var profile := DataRegistry.get_visitor_profile(String(negotiation.get("profile_id", "")))
			var watch := _watch_for_unit(String(negotiation.get("unit_id", "")))
			var display := GameState.get_displayed_watch(String(watch.get("id", "")))
			var target_facility_id := String(negotiation.get("target_facility_installation_id", ""))
			if profile.is_empty() or watch.is_empty() or display.is_empty() or (not target_facility_id.is_empty() and String(display.get("facility_installation_id", "")) != target_facility_id) or not _is_piece_suitable_for_profile(watch, profile):
				return false
			# La oferta conserva el ratio del perfil, pero se calcula con el precio actual.
			var price := int(watch.get("sale_price", 0))
			negotiation["offer"] = mini(int(round(price * _initial_offer_ratio(profile))), int(profile.get("max_budget", price)))
			negotiations[index] = negotiation
			negotiations[index]["state"] = "waiting"
			GameState.set_visitor_negotiations(negotiations)
			return true
	return false

func _resume_visits() -> void:
	if GameState.get_visitor_negotiations().is_empty():
		return
	_start_physical_visits()
	_publish_active()

func _start_physical_visits() -> void:
	var negotiations := GameState.get_visitor_negotiations()
	_arrived_at_counter.clear()
	for index in negotiations.size():
		var negotiation: Dictionary = negotiations[index]
		var profile := DataRegistry.get_visitor_profile(String(negotiation.get("profile_id", "")))
		var watch := _watch_for_unit(String(negotiation.get("unit_id", "")))
		var display := GameState.get_displayed_watch(String(negotiation.get("unit_id", "")))
		var customer := _customer_for_negotiation(negotiation, index)
		var state := String(negotiation.get("state", ""))
		# Una visita ya reservada puede restaurarse aunque la visual de vitrina aún
		# no se haya reconstruido; no se cancela ni se pierde su panel al cargar.
		var requires_display := state == "waiting_outside" or state == "entering"
		if customer == null or profile.is_empty() or (requires_display and (watch.is_empty() or display.is_empty())) or not customer.set_visitor_profile(profile):
			continue
		if state == "waiting_outside":
			customer.begin_waiting_outside(index, String(negotiation.get("customer_name", "")))
		elif state == "entering":
			customer.begin_purchase_visit(display, String(watch.get("name", "Pieza expuesta")), index, String(negotiation.get("customer_name", "")))
		elif state == "waiting" or state == "active":
			# La reserva ya existía al guardar. Reanudarla en caja evita repetir la
			# observación (y customer_chose_piece), que invalidaría la negociación.
			customer.restore_waiting_at_counter(index, String(negotiation.get("customer_name", "")), state == "active")
			_arrived_at_counter[customer.visitor_instance_id] = true

func admit_next_waiting_visitor() -> void:
	var negotiations := GameState.get_visitor_negotiations()
	# Una visita fuera no reserva la pieza: si se vendió o retiró, se libera su
	# cuerpo aquí mismo. No se la hace cruzar la tienda sólo para salir.
	var cancelled_count := _cancel_invalid_waiting_outside_visits(negotiations)
	negotiations = GameState.get_visitor_negotiations()
	var admitted_count := 0
	for index in negotiations.size():
		if String(negotiations[index].get("state", "")) != "waiting_outside":
			continue
		var customer := _customer_for_negotiation(negotiations[index], index)
		var display := GameState.get_displayed_watch(String(negotiations[index].get("unit_id", "")))
		var watch := _watch_for_unit(String(negotiations[index].get("unit_id", "")))
		if customer == null or display.is_empty() or watch.is_empty():
			continue
		if not customer.begin_purchase_visit(display, String(watch.get("name", "Pieza expuesta")), index, String(negotiations[index].get("customer_name", ""))):
			EventBus.feedback_requested.emit("La vitrina no está disponible todavía.", "error")
			continue
		negotiations[index]["state"] = "entering"
		admitted_count += 1
	if admitted_count > 0:
		GameState.set_visitor_negotiations(negotiations)
		EventBus.feedback_requested.emit("Has abierto la puerta. Los clientes entran en la boutique." if admitted_count > 1 else "Has abierto la puerta. El cliente entra en la boutique.", "info")
		_publish_active()
		return
	if cancelled_count > 0:
		_publish_active()
		EventBus.feedback_requested.emit("La pieza prevista ya no está expuesta; el cliente se ha marchado.", "info")
		return
	if _waiting_browse_customer != null and is_instance_valid(_waiting_browse_customer) and _waiting_browse_customer.is_waiting_outside():
		_waiting_browse_customer.begin_browse_visit()
		_waiting_browse_customer = null
		EventBus.feedback_requested.emit("Has abierto la puerta. El cliente entra a explorar la boutique.", "info")

func _cancel_invalid_waiting_outside_visits(negotiations: Array[Dictionary]) -> int:
	var cancelled_count := 0
	for index in range(negotiations.size() - 1, -1, -1):
		var negotiation: Dictionary = negotiations[index]
		if String(negotiation.get("state", "")) != "waiting_outside":
			continue
		var unit_id := String(negotiation.get("unit_id", ""))
		if not _watch_for_unit(unit_id).is_empty() and not GameState.get_displayed_watch(unit_id).is_empty():
			continue
		var customer := _customer_for_negotiation(negotiation, index)
		negotiations.remove_at(index)
		if customer != null:
			customer.cancel_waiting_outside()
		_record_review(negotiation, "invalid")
		cancelled_count += 1
	if cancelled_count > 0:
		GameState.set_visitor_negotiations(negotiations)
		EventBus.visitor_negotiation_resolved.emit({"result": "invalid", "message": "La pieza ya no está disponible."})
	return cancelled_count

func has_waiting_browse_visitor() -> bool:
	return _waiting_browse_customer != null and is_instance_valid(_waiting_browse_customer) and _waiting_browse_customer.is_waiting_outside()


func _process(delta: float) -> void:
	_next_practical_attempt -= TimeManager.get_simulation_delta(delta)
	if _next_practical_attempt <= 0.0:
		_try_start_pair()
		_next_practical_attempt = _practical_attempt_interval()
	var negotiations := GameState.get_visitor_negotiations()
	if negotiations.is_empty() or watchmaker == null:
		return
	var active_customer := _customer_for_negotiation(negotiations[0], 0)
	if active_customer != null and _arrived_at_counter.get(active_customer.visitor_instance_id, false) and active_customer.global_position.distance_to(watchmaker.global_position) <= 4.0:
		_activate_first()

func customer_waiting_for_attendance(visitor_id: String) -> void:
	_arrived_at_counter[visitor_id] = true
	var negotiations := GameState.get_visitor_negotiations()
	var active_customer := _customer_for_negotiation(negotiations[0], 0) if not negotiations.is_empty() else null
	if active_customer != null and active_customer.visitor_instance_id == visitor_id:
		EventBus.feedback_requested.emit("Cliente en caja: acércate para atenderle.", "info")
		# La llegada a caja es el hito definitivo de esta versión. Abrimos el
		# diálogo aquí para que una lectura de distancia imprecisa no bloquee UI.
		_activate_first()

func customer_visit_failed(visitor_id: String, message: String) -> void:
	_remove_visit_for_customer(visitor_id, "cancelled", "El cliente se ha marchado: %s" % message, "La visita se ha interrumpido.\n%s" % message)

func customer_left_store(visitor_id: String) -> void:
	_departing_customer_ids.erase(visitor_id)

func _activate_first() -> void:
	var negotiations := GameState.get_visitor_negotiations()
	if negotiations.is_empty() or String(negotiations[0].get("state", "")) == "active":
		return
	negotiations[0]["state"] = "active"
	GameState.set_visitor_negotiations(negotiations)
	_publish_active()

func _on_action_requested(action: String, amount: int) -> void:
	var negotiations := GameState.get_visitor_negotiations()
	if negotiations.is_empty() or String(negotiations[0].get("state", "")) != "active":
		return
	var negotiation: Dictionary = negotiations[0]
	var profile := DataRegistry.get_visitor_profile(String(negotiation.get("profile_id", "")))
	var watch := _watch_for_unit(String(negotiation.get("unit_id", "")))
	if profile.is_empty() or watch.is_empty():
		_resolve_first("invalid", "La pieza ya no está disponible.")
		return
	var ceiling := mini(int(negotiation.get("budget", 0)), _willingness_to_pay(watch, profile))
	if action == "accept" and _complete_sale(negotiation, profile, watch, int(negotiation["offer"])):
		_resolve_first("sold", "Venta acordada por %s €." % int(negotiation["offer"]), _sold_departure_text(watch, int(negotiation["offer"])))
	elif action == "reject":
		_resolve_first("rejected", "Has cancelado la operación. La pieza vuelve a quedar disponible.")
	elif action == "counter" and amount > int(negotiation["offer"]):
		negotiation["patience"] = int(negotiation["patience"]) - 1
		negotiation["turns"] = int(negotiation["turns"]) + 1
		if amount <= ceiling and _complete_sale(negotiation, profile, watch, amount):
			_resolve_first("sold", "El cliente acepta tu propuesta: %s €." % amount, _sold_departure_text(watch, amount))
		elif int(negotiation["patience"]) <= 0:
			_resolve_first("left", "El cliente se ha cansado de negociar.")
		else:
			negotiation["offer"] = mini(ceiling, int(negotiation["offer"]) + maxi(1, int((ceiling - int(negotiation["offer"])) * 0.5)))
			negotiations[0] = negotiation
			GameState.set_visitor_negotiations(negotiations)
			_publish_active()

func _resolve_first(result: String, message: String, departure_text := "") -> void:
	var negotiations := GameState.get_visitor_negotiations()
	if negotiations.is_empty(): return
	var resolved_negotiation: Dictionary = negotiations[0]
	_record_review(resolved_negotiation, result)
	var customer := _customer_for_negotiation(resolved_negotiation, 0)
	negotiations.remove_at(0)
	GameState.set_visitor_negotiations(negotiations)
	if customer != null:
		if result == "sold":
			_departing_customer_ids[customer.visitor_instance_id] = true
			customer.resolve_purchase_visit_with_departure("checkout", departure_text)
		else:
			_departing_customer_ids[customer.visitor_instance_id] = true
			customer.resolve_purchase_visit_with_departure("angry", departure_text if not departure_text.is_empty() else _departure_text(resolved_negotiation, result))
	_activate_first_if_arrived()
	EventBus.visitor_negotiation_resolved.emit({"result": result, "message": message})
	EventBus.feedback_requested.emit(message, "info")

func _complete_sale(negotiation: Dictionary, profile: Dictionary, watch: Dictionary, agreed_price: int) -> bool:
	# Keep all UI-facing data before GameState removes the listed/displayed unit.
	var item_snapshot := watch.duplicate(true)
	if not GameState.complete_visitor_sale(String(watch.get("id", "")), agreed_price):
		return false
	var customer_name := String(negotiation.get("customer_name", profile.get("name", "Cliente")))
	var item_name := String(item_snapshot.get("name", "la pieza"))
	EventBus.visitor_sale_completed.emit({
		"item": item_snapshot,
		"item_name": item_name,
		"final_price": agreed_price,
		"customer_name": customer_name,
		"profile_name": String(profile.get("name", "Cliente interesado")),
		"quote": "Me llevo %s por %s €." % [item_name, agreed_price],
	})
	return true

func _departure_text(negotiation: Dictionary, result: String) -> String:
	match result:
		"rejected", "left":
			return "La pieza encaja conmigo,\npero no hay acuerdo."
		"cancelled":
			return "La visita se ha\ninterrumpido."
		"invalid":
			return "La pieza ya no está\ndisponible. Lo entiendo."
		_:
			return "Gracias por la atención."

func _sold_departure_text(watch: Dictionary, agreed_price: int) -> String:
	return "Me llevo %s por\n%s €. Gracias." % [String(watch.get("name", "la pieza")), agreed_price]

func _remove_visit_for_customer(visitor_id: String, result: String, message: String, departure_text := "") -> void:
	var negotiations := GameState.get_visitor_negotiations()
	for index in negotiations.size():
		var customer := _customer_for_negotiation(negotiations[index], index)
		if customer != null and customer.visitor_instance_id == visitor_id:
			var resolved_negotiation: Dictionary = negotiations[index]
			_record_review(resolved_negotiation, result)
			negotiations.remove_at(index)
			GameState.set_visitor_negotiations(negotiations)
			_departing_customer_ids[customer.visitor_instance_id] = true
			customer.resolve_purchase_visit_with_departure("angry", departure_text if not departure_text.is_empty() else _departure_text(resolved_negotiation, result))
			_activate_first_if_arrived()
			EventBus.visitor_negotiation_resolved.emit({"result": result, "message": message})
			return

## El cuerpo es un recurso físico de la cola, no una propiedad del perfil. El
## slot persistido evita que, al resolver el primero, el segundo cambie de cuerpo.
## Las partidas previas no tenían customer_slot: se restauran por índice actual.
func _customer_for_negotiation(negotiation: Dictionary, fallback_index: int) -> CustomerVisitor:
	var customer_slot := int(negotiation.get("customer_slot", fallback_index))
	if customer_slot < 0 or customer_slot >= customers.size():
		return null
	return customers[customer_slot]

func _activate_first_if_arrived() -> void:
	var negotiations := GameState.get_visitor_negotiations()
	if negotiations.is_empty():
		_publish_active()
		return
	var customer := _customer_for_negotiation(negotiations[0], 0)
	if customer != null and _arrived_at_counter.get(customer.visitor_instance_id, false):
		_activate_first()
	else:
		_publish_active()

func _best_candidate_for_profile(profile: Dictionary, excluded_unit_id: String) -> Dictionary:
	var best: Dictionary = {}
	if profile.is_empty():
		return best
	for watch in GameState.listed_pieces:
		if String(watch.get("id", "")) == excluded_unit_id or GameState.get_displayed_watch(String(watch.get("id", ""))).is_empty(): continue
		if not _is_piece_suitable_for_profile(watch, profile): continue
		var quality := int(watch.get("quality_score", 0))
		var best_quality := int(best.get("quality_score", 0))
		if best.is_empty() or quality > best_quality or (quality == best_quality and _is_preferred_brand(watch, profile) and not _is_preferred_brand(best, profile)):
			best = watch.duplicate(true)
	return best

## Reutiliza los mismos criterios al elegir y al reservar una pieza.
func _is_piece_suitable_for_profile(watch: Dictionary, profile: Dictionary) -> bool:
	if profile.is_empty() or GameState.reputation < int(profile.get("min_reputation", 0)):
		return false
	if int(watch.get("sale_price", 0)) < int(profile.get("min_budget", 0)) or int(watch.get("sale_price", 0)) > int(profile.get("max_budget", 0)) or int(watch.get("quality_score", 0)) < int(profile.get("min_quality", 0)):
		return false
	if not (profile.get("preferred_segments", []) as Array).has(String(watch.get("segment", ""))):
		return false
	return _matches_profile_item_filters(watch, profile)

## Filtros opcionales y data-driven. Los perfiles antiguos, que no los declaran,
## conservan su comportamiento actual y sus partidas guardadas siguen siendo válidas.
func _matches_profile_item_filters(item: Dictionary, profile: Dictionary) -> bool:
	var item_types := profile.get("required_item_types", []) as Array
	var categories := profile.get("preferred_categories", []) as Array
	var excluded_categories := profile.get("excluded_categories", []) as Array
	var required_tags := profile.get("required_tags", []) as Array
	var excluded_tags := profile.get("excluded_tags", []) as Array
	var item_tags := item.get("tags", []) as Array
	if not item_types.is_empty() and not item_types.has(String(item.get("item_type", "watch"))):
		return false
	if not categories.is_empty() and not categories.has(String(item.get("category", ""))):
		return false
	if excluded_categories.has(String(item.get("category", ""))):
		return false
	for tag in required_tags:
		if not item_tags.has(tag):
			return false
	for tag in excluded_tags:
		if item_tags.has(tag):
			return false
	return true

func _is_preferred_brand(item: Dictionary, profile: Dictionary) -> bool:
	return (profile.get("preferred_brands", []) as Array).has(String(item.get("brand", "")))

func _initial_offer_ratio(profile: Dictionary) -> float:
	return 0.88 if String(profile.get("bargaining", "")) == "suave" else 0.80

func _willingness_to_pay(watch: Dictionary, profile: Dictionary) -> int:
	return mini(int(profile.get("max_budget", 0)), int(round(int(watch.get("sale_price", 0)) * 0.96)))

func _practical_attempt_interval() -> float:
	var rating := GameState.get_customer_rating()
	return 15.0 if rating < 2.5 else 30.0 if rating < 4.0 else 60.0

func _collector_window_is_open() -> bool:
	return GameState.current_day >= 3 and posmod(GameState.current_day, 3) == 0 and GameState.last_collector_spawn_day != GameState.current_day

func _record_review(negotiation: Dictionary, result: String) -> void:
	var turns := int(negotiation.get("turns", 0))
	var customer_name := String(negotiation.get("customer_name", ""))
	match result:
		"sold":
			GameState.add_customer_review(4 if turns > 0 else 5, "😊", "Atención cuidada y compra resuelta con éxito.", customer_name)
		"rejected":
			GameState.add_customer_review(2, "😕", "La venta se canceló después de esperar en caja.", customer_name)
		"left":
			GameState.add_customer_review(1, "😣", "La negociación se alargó y preferí marcharme.", customer_name)
		"cancelled":
			GameState.add_customer_review(1, "😣", "La visita se interrumpió antes de poder completar la compra.", customer_name)
		"invalid":
			GameState.add_customer_review(1, "😣", "Esperé una pieza que finalmente no estuvo disponible.", customer_name)
		_:
			GameState.add_customer_review(2, "😕", "La visita no pudo completarse.", customer_name)

func _watch_for_unit(unit_id: String) -> Dictionary:
	for watch in GameState.listed_pieces:
		if String(watch.get("id", "")) == unit_id: return watch.duplicate(true)
	return {}

func _publish_active() -> void:
	var negotiations := GameState.get_visitor_negotiations()
	var snapshot: Dictionary = {}
	if not negotiations.is_empty():
		snapshot = negotiations[0].duplicate(true)
		snapshot["profile"] = DataRegistry.get_visitor_profile(String(snapshot.get("profile_id", "")))
		snapshot["watch"] = _watch_for_unit(String(snapshot.get("unit_id", "")))
	snapshot["queue"] = _presentation_queue(negotiations)
	EventBus.visitor_negotiation_changed.emit(snapshot)
	if is_instance_valid(_negotiation_panel):
		_negotiation_panel.present(snapshot)

## Datos efímeros para la UI. La cola persistida conserva sólo los IDs y las
## reglas de negociación; el panel no debe resolver perfiles ni piezas desde GameState.
func _presentation_queue(negotiations: Array[Dictionary]) -> Array[Dictionary]:
	var queue: Array[Dictionary] = []
	for index in negotiations.size():
		var negotiation: Dictionary = negotiations[index]
		queue.append({
			"name": String(negotiation.get("customer_name", "Cliente interesado")),
			"state": "EN CAJA" if index == 0 else "EN ESPERA",
			"profile": DataRegistry.get_visitor_profile(String(negotiation.get("profile_id", ""))),
			"watch": _watch_for_unit(String(negotiation.get("unit_id", ""))),
		})
	return queue

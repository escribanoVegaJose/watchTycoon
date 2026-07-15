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

func _ready() -> void:
	add_to_group("visitor_negotiation_manager")
	for path in customer_paths:
		var customer := get_node_or_null(path) as CustomerVisitor
		if customer != null:
			customers.append(customer)
	watchmaker = get_node_or_null(watchmaker_path) as Node3D
	# El modal vive en Main.tscn para que esté listo y conectado antes de que
	# cualquier visitante llegue a caja.
	if get_node_or_null("../HudLayer/VisitorNegotiationPanel") == null:
		var panel := VisitorNegotiationPanel.new()
		get_node("../HudLayer").add_child(panel)
	_negotiation_panel = get_node_or_null("../HudLayer/VisitorNegotiationPanel") as VisitorNegotiationPanel
	EventBus.visitor_negotiation_action_requested.connect(_on_action_requested)
	EventBus.facility_installations_reloaded.connect(_resume_visits)
	_next_practical_attempt = _practical_attempt_interval()
	if not GameState.get_visitor_negotiations().is_empty():
		call_deferred("_resume_visits")

func _try_start_pair() -> void:
	# A scheduled attempt never joins a partial queue or reuses a body that is
	# still walking out after a sale. This keeps the two visual slots authoritative.
	if not GameState.can_access_commerce() or customers.is_empty() or not GameState.get_visitor_negotiations().is_empty() or not _departing_customer_ids.is_empty():
		return
	var negotiations: Array[Dictionary] = []
	var practical_profile := DataRegistry.get_visitor_profile("practical_low")
	var practical_candidate := _best_candidate_for_profile(practical_profile, "")
	if practical_profile.is_empty() or practical_candidate.is_empty():
		# No se puede valorar una boutique sin haberla visitado. El cliente entra,
		# recorre la sala y sólo una futura salida evaluada podrá dejar reseña.
		if not customers.is_empty() and not customers[0].is_leaving_store():
			customers[0].begin_browse_visit()
		EventBus.feedback_requested.emit("Un cliente ha entrado a explorar la boutique.", "info")
		return
	negotiations.append(_new_negotiation("practical_low", practical_candidate))
	# La segunda plaza alterna entre el perfil medio y el coleccionista. El
	# coleccionista sólo visita una vez cada tres días y nunca crea un tercer NPC.
	if customers.size() > 1:
		var secondary_profile_id := "premium_collector" if _collector_window_is_open() else "classic_medium"
		var secondary_profile := DataRegistry.get_visitor_profile(secondary_profile_id)
		var secondary_candidate := _best_candidate_for_profile(secondary_profile, String(practical_candidate["id"]))
		# Una ventana premium sin reloj apto no debe vaciar la segunda plaza.
		if secondary_profile_id == "premium_collector" and secondary_candidate.is_empty():
			secondary_profile_id = "classic_medium"
			secondary_profile = DataRegistry.get_visitor_profile(secondary_profile_id)
			secondary_candidate = _best_candidate_for_profile(secondary_profile, String(practical_candidate["id"]))
		if not secondary_profile.is_empty() and not secondary_candidate.is_empty():
			negotiations.append(_new_negotiation(secondary_profile_id, secondary_candidate))
			if secondary_profile_id == "premium_collector":
				GameState.last_collector_spawn_day = GameState.current_day
	GameState.set_visitor_negotiations(negotiations)
	_start_physical_visits()
	var second_is_collector := negotiations.size() > 1 and String(negotiations[1].get("profile_id", "")) == "premium_collector"
	EventBus.feedback_requested.emit("Un coleccionista exigente ha entrado; espera turno en caja." if second_is_collector else "Dos clientes han entrado; el segundo espera turno en caja." if negotiations.size() > 1 else "Una compradora de regalo ha entrado en la boutique.", "info")

func _new_negotiation(profile_id: String, candidate: Dictionary) -> Dictionary:
	var profile := DataRegistry.get_visitor_profile(profile_id)
	var price := int(candidate.get("sale_price", 0))
	return {"profile_id": profile_id, "unit_id": String(candidate["id"]), "customer_name": GameState.generate_customer_name(), "state": "entering", "offer": mini(int(round(price * _initial_offer_ratio(profile))), int(profile.get("max_budget", price))), "patience": int(profile.get("patience", 3)), "max_patience": int(profile.get("patience", 3)), "budget": int(profile.get("max_budget", 0)), "turns": 0}

func customer_chose_piece(visitor_id: String) -> void:
	var negotiations := GameState.get_visitor_negotiations()
	for index in negotiations.size():
		var customer := _customer_for_profile(String(negotiations[index].get("profile_id", "")))
		if customer != null and customer.visitor_instance_id == visitor_id:
			negotiations[index]["state"] = "waiting"
			GameState.set_visitor_negotiations(negotiations)
			return

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
		var customer := _customer_for_profile(String(negotiation.get("profile_id", "")))
		if customer == null or profile.is_empty() or watch.is_empty() or display.is_empty() or not customer.set_visitor_profile(profile):
			continue
		customer.begin_purchase_visit(display, String(watch.get("name", "Pieza expuesta")), index, String(negotiation.get("customer_name", "")))


func _process(delta: float) -> void:
	_next_practical_attempt -= TimeManager.get_simulation_delta(delta)
	if _next_practical_attempt <= 0.0:
		_try_start_pair()
		_next_practical_attempt = _practical_attempt_interval()
	var negotiations := GameState.get_visitor_negotiations()
	if negotiations.is_empty() or watchmaker == null:
		return
	var active_customer := _customer_for_profile(String(negotiations[0].get("profile_id", "")))
	if active_customer != null and _arrived_at_counter.get(active_customer.visitor_instance_id, false) and active_customer.global_position.distance_to(watchmaker.global_position) <= 4.0:
		_activate_first()

func customer_waiting_for_attendance(visitor_id: String) -> void:
	_arrived_at_counter[visitor_id] = true
	var negotiations := GameState.get_visitor_negotiations()
	var active_customer := _customer_for_profile(String(negotiations[0].get("profile_id", ""))) if not negotiations.is_empty() else null
	if active_customer != null and active_customer.visitor_instance_id == visitor_id:
		EventBus.feedback_requested.emit("Cliente en caja: acércate para atenderle.", "info")
		# La llegada a caja es el hito definitivo de esta versión. Abrimos el
		# diálogo aquí para que una lectura de distancia imprecisa no bloquee UI.
		_activate_first()

func customer_visit_failed(visitor_id: String, message: String) -> void:
	_remove_visit_for_customer(visitor_id, "cancelled", "El cliente se ha marchado: %s" % message)

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
	if action == "accept" and GameState.complete_visitor_sale(String(watch["id"]), int(negotiation["offer"]), _reputation_gain(watch, profile)):
		_resolve_first("sold", "Venta acordada por %s €." % int(negotiation["offer"]))
	elif action == "reject":
		_resolve_first("rejected", "Has cancelado la operación. La pieza vuelve a quedar disponible.")
	elif action == "counter" and amount > int(negotiation["offer"]):
		negotiation["patience"] = int(negotiation["patience"]) - 1
		negotiation["turns"] = int(negotiation["turns"]) + 1
		if amount <= ceiling and GameState.complete_visitor_sale(String(watch["id"]), amount, _reputation_gain(watch, profile)):
			_resolve_first("sold", "El cliente acepta tu propuesta: %s €." % amount)
		elif int(negotiation["patience"]) <= 0:
			_resolve_first("left", "El cliente se ha cansado de negociar.")
		else:
			negotiation["offer"] = mini(ceiling, int(negotiation["offer"]) + maxi(1, int((ceiling - int(negotiation["offer"])) * 0.5)))
			negotiations[0] = negotiation
			GameState.set_visitor_negotiations(negotiations)
			_publish_active()

func _resolve_first(result: String, message: String) -> void:
	var negotiations := GameState.get_visitor_negotiations()
	if negotiations.is_empty(): return
	_record_review(negotiations[0], result)
	var customer := _customer_for_profile(String(negotiations[0].get("profile_id", "")))
	negotiations.remove_at(0)
	GameState.set_visitor_negotiations(negotiations)
	if customer != null:
		if result == "sold":
			_departing_customer_ids[customer.visitor_instance_id] = true
			customer.resolve_purchase_visit("checkout")
		else:
			_departing_customer_ids[customer.visitor_instance_id] = true
			customer.resolve_purchase_visit("angry")
	_activate_first_if_arrived()
	EventBus.visitor_negotiation_resolved.emit({"result": result, "message": message})
	EventBus.feedback_requested.emit(message, "info")

func _remove_visit_for_customer(visitor_id: String, result: String, message: String) -> void:
	var negotiations := GameState.get_visitor_negotiations()
	for index in negotiations.size():
		var customer := _customer_for_profile(String(negotiations[index].get("profile_id", "")))
		if customer != null and customer.visitor_instance_id == visitor_id:
			_record_review(negotiations[index], result)
			negotiations.remove_at(index)
			GameState.set_visitor_negotiations(negotiations)
			_departing_customer_ids[customer.visitor_instance_id] = true
			customer.resolve_purchase_visit("angry")
			_activate_first_if_arrived()
			EventBus.visitor_negotiation_resolved.emit({"result": result, "message": message})
			return

func _customer_for_profile(profile_id: String) -> CustomerVisitor:
	return customers[0] if profile_id == "practical_low" and not customers.is_empty() else customers[1] if customers.size() > 1 else null

func _activate_first_if_arrived() -> void:
	var negotiations := GameState.get_visitor_negotiations()
	if negotiations.is_empty():
		_publish_active()
		return
	var customer := _customer_for_profile(String(negotiations[0].get("profile_id", "")))
	if customer != null and _arrived_at_counter.get(customer.visitor_instance_id, false):
		_activate_first()
	else:
		_publish_active()

func _best_candidate_for_profile(profile: Dictionary, excluded_unit_id: String) -> Dictionary:
	var best: Dictionary = {}
	if profile.is_empty() or GameState.reputation < int(profile.get("min_reputation", 0)):
		return best
	for watch in GameState.listed_pieces:
		if String(watch.get("id", "")) == excluded_unit_id or GameState.get_displayed_watch(String(watch.get("id", ""))).is_empty(): continue
		if int(watch.get("sale_price", 0)) < int(profile.get("min_budget", 0)) or int(watch.get("sale_price", 0)) > int(profile.get("max_budget", 0)) or int(watch.get("quality_score", 0)) < int(profile.get("min_quality", 0)): continue
		if not (profile.get("preferred_segments", []) as Array).has(String(watch.get("segment", ""))): continue
		if best.is_empty() or int(watch.get("quality_score", 0)) > int(best.get("quality_score", 0)): best = watch.duplicate(true)
	return best

func _initial_offer_ratio(profile: Dictionary) -> float:
	return 0.88 if String(profile.get("bargaining", "")) == "suave" else 0.80

func _willingness_to_pay(watch: Dictionary, profile: Dictionary) -> int:
	return mini(int(profile.get("max_budget", 0)), int(round(int(watch.get("sale_price", 0)) * 0.96)))

func _reputation_gain(_watch: Dictionary, _profile: Dictionary) -> int:
	return 2

func _practical_attempt_interval() -> float:
	var rating := GameState.get_customer_rating()
	return 60.0 if rating < 2.5 else 30.0 if rating < 4.0 else 15.0

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
		"cancelled", "invalid":
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

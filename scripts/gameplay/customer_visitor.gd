class_name CustomerVisitor
extends CharacterBody3D

## Cliente ambiental: primera máquina de estados visual, sin ventas ni pedidos.
## Un único cuerpo cambia de set visual según el perfil que selecciona el manager.
enum State { IDLE, WAITING_OUTSIDE, ENTERING_STORE, DECIDING_PURCHASE, WALKING_TO_DISPLAY, VIEWING_DISPLAY, WALKING_TO_COUNTER, VIEWING_COUNTER, WALKING_TO_PURCHASE_DISPLAY, VIEWING_PURCHASE_DISPLAY, WALKING_TO_NEGOTIATION, WAITING_FOR_ATTENDANCE, BROWSING_EMPTY, WALKING_TO_EXIT_DOOR, LEAVING_STORE, REACTION }

const STANDARD_VISUAL_ID := "standard_customer"
const CLASSIC_VISUAL_ID := "classic_customer"
const GIFT_BUYER_VISUAL_ID := "gift_buyer"
const ASPIRATIONAL_PROFESSIONAL_VISUAL_ID := "aspirational_professional"
const DEMANDING_COLLECTOR_VISUAL_ID := "demanding_collector"
const CAREFUL_RETIREE_VISUAL_ID := "careful_retiree"
const WORLD_SOLID_MASK := 8
const DETOUR_DISTANCE := 1.15
const MAX_CONSECUTIVE_COLLISIONS := 6
enum AttentionBubbleStyle { THOUGHT, DIALOGUE }

## La presentación decide cómo mostrar este aviso; el visitante sólo comunica su estado.
signal attention_indicator_changed(is_visible: bool, message: String, bubble_style: int)

@export var move_speed := 1.35
@export var arrival_distance := 0.1
@export var counter_viewing_margin := 1.35
@export var display_viewing_duration := 1.75
@export var doorway_position := Vector3(1.47, 0.0, -6.25)
@export var entrance_position := Vector3(1.47, 0.0, -5.35)
@export var exit_position := Vector3(1.47, 0.0, -7.4)
@export var visitor_instance_id := "customer_1"

@onready var idle_visual: Node3D = $IdleVisual
@onready var walk_visual: Node3D = $WalkVisual
@onready var classic_idle_visual: Node3D = $ClassicIdleVisual
@onready var classic_walk_visual: Node3D = $ClassicWalkVisual
# Preparados para futuros estados de gameplay; no añaden transiciones nuevas.
@onready var classic_run_visual: Node3D = $ClassicRunVisual
@onready var classic_inspect_visual: Node3D = $ClassicInspectVisual

var _destination := Vector3.ZERO
var _state := State.IDLE
var _target_visual: Node3D
var _display_view_point_index := 0
var _viewing_time_remaining := 0.0
var _idle_animation_player: AnimationPlayer
var _walk_animation_player: AnimationPlayer
var _classic_idle_animation_player: AnimationPlayer
var _classic_walk_animation_player: AnimationPlayer
var _pending_display_visual: Node3D
var _pending_watch_name := ""
var _is_browse_visit := false
var _thought_label: Label3D
var _visual_id := STANDARD_VISUAL_ID
var _is_walking := false
var _queue_position := 0
var _customer_name := ""
var _entry_route: Array[Vector3] = []
var _entry_route_index := 0
var _detour_waypoints: Array[Vector3] = []
var _consecutive_collisions := 0
var _detour_side := 1.0
var _reaction_time_remaining := 0.0

func _ready() -> void:
	# Los props instalados y las paredes publican su volumen en WorldSolid. No se
	# usa NavigationAgent: el layout todavía no contiene un NavigationRegion/NavMesh.
	collision_mask = WORLD_SOLID_MASK
	add_to_group("world_selectable_customer")
	set_meta("selection_id", visitor_instance_id)
	# No hay visitante visible al iniciar una partida nueva; el manager lo crea
	# cuando vence el intervalo de llegada.
	visible = not GameState.active_visitor_negotiation.is_empty()
	_idle_animation_player = _find_animation_player(idle_visual)
	_walk_animation_player = _find_animation_player(walk_visual)
	_create_thought_label()
	_classic_idle_animation_player = _find_animation_player(classic_idle_visual)
	_classic_walk_animation_player = _find_animation_player(classic_walk_visual)
	_set_walking(false)
	EventBus.facility_installation_added.connect(_on_facilities_changed)
	EventBus.facility_installation_updated.connect(_on_facilities_changed)
	EventBus.facility_installation_removed.connect(_on_facility_removed)
	EventBus.facility_installations_reloaded.connect(_refresh_behavior)
	call_deferred("_refresh_behavior")

## El manager usa este punto de entrada antes de iniciar o restaurar una visita.
## Devuelve false para que un dato no validado nunca cambie el aspecto activo.
func set_visitor_profile(profile: Dictionary) -> bool:
	return set_visitor_visual(String(profile.get("visual_id", "")))

func set_visitor_visual(visual_id: String) -> bool:
	if not _visual_nodes_for(visual_id).has("idle"):
		push_warning("Visual de visitante no soportado: %s" % visual_id)
		return false
	_visual_id = visual_id
	if is_node_ready():
		_set_walking(_is_walking)
	return true

func _physics_process(delta: float) -> void:
	if TimeManager.is_paused:
		velocity = Vector3.ZERO
		_set_walking(false)
		return
	var simulation_delta := TimeManager.get_simulation_delta(delta)
	match _state:
		State.ENTERING_STORE, State.WALKING_TO_DISPLAY, State.WALKING_TO_COUNTER, State.WALKING_TO_PURCHASE_DISPLAY, State.WALKING_TO_NEGOTIATION, State.WALKING_TO_EXIT_DOOR, State.LEAVING_STORE:
			_move_to_destination(simulation_delta)
		State.VIEWING_DISPLAY:
			_face_target()
			_viewing_time_remaining -= simulation_delta
			if _viewing_time_remaining <= 0.0:
				if _is_browse_visit:
					leave_store()
				else:
					_display_view_point_index = 1 - _display_view_point_index
					_destination = _display_viewing_point(_display_view_point_index)
					_state = State.WALKING_TO_DISPLAY
		State.VIEWING_PURCHASE_DISPLAY:
			_face_target()
			_viewing_time_remaining -= simulation_delta
			if _viewing_time_remaining <= 0.0:
				if not _walk_to_negotiation_counter():
					_notify_visit_failed("No hay una caja disponible.")
		State.VIEWING_COUNTER:
			_face_target()
		State.BROWSING_EMPTY:
			_viewing_time_remaining -= simulation_delta
			if _viewing_time_remaining <= 0.0:
				leave_store()
		State.DECIDING_PURCHASE:
			_viewing_time_remaining -= simulation_delta
			if _viewing_time_remaining <= 0.0:
				var manager := get_tree().get_first_node_in_group("visitor_negotiation_manager")
				if manager != null:
					manager.customer_chose_piece(visitor_instance_id)
				_start_pending_purchase_display()
		State.REACTION:
			_reaction_time_remaining -= simulation_delta
			if _reaction_time_remaining <= 0.0:
				leave_store()

func _move_to_destination(delta: float) -> void:
	var movement_target: Vector3 = _detour_waypoints.front() if not _detour_waypoints.is_empty() else _destination
	var offset := movement_target - global_position
	offset.y = 0.0
	if offset.length() <= arrival_distance:
		if not _detour_waypoints.is_empty():
			_detour_waypoints.pop_front()
			return
		velocity = Vector3.ZERO
		_set_walking(false)
		if _state == State.ENTERING_STORE:
			_advance_entry_route()
		elif _state == State.WALKING_TO_EXIT_DOOR:
			# Desde el interior se llega primero al umbral; sólo después se cruza
			# recto al exterior para no cortar visualmente una pared lateral.
			_destination = exit_position
			_state = State.LEAVING_STORE
		elif _state == State.LEAVING_STORE:
			visible = false
			set_attention_indicator(false)
			_state = State.IDLE
			var manager := get_tree().get_first_node_in_group("visitor_negotiation_manager")
			if manager != null:
				manager.customer_left_store(visitor_instance_id)
		elif _state == State.WALKING_TO_DISPLAY:
			_state = State.VIEWING_DISPLAY
			_viewing_time_remaining = display_viewing_duration
			_face_target()
			set_attention_indicator(true, "Esta vitrina merece\nuna mirada.")
		elif _state == State.WALKING_TO_PURCHASE_DISPLAY:
			_state = State.VIEWING_PURCHASE_DISPLAY
			_viewing_time_remaining = display_viewing_duration
			_face_target()
			_show_profile_visual("agree", false)
			set_attention_indicator(true, "La esfera tiene una\npresencia exquisita.")
		elif _state == State.WALKING_TO_NEGOTIATION:
			_state = State.WAITING_FOR_ATTENDANCE
			_face_target()
			var manager := get_tree().get_first_node_in_group("visitor_negotiation_manager")
			if manager != null:
				manager.customer_waiting_for_attendance(visitor_instance_id)
		else:
			_state = State.VIEWING_COUNTER
			_face_target()
		return

	var direction := offset.normalized()
	velocity = direction * move_speed
	look_at(global_position + direction, Vector3.UP)
	var step := minf(offset.length(), move_speed * delta)
	# La ruta de entrada/salida ya está compuesta por los puntos del vano de la
	# puerta. Cruzarla de forma guiada evita que el desvío local interprete el
	# marco como un obstáculo y mande al cliente alrededor de la fachada.
	if _state == State.ENTERING_STORE or _state == State.LEAVING_STORE:
		global_position += direction * step
		_set_walking(true)
		return
	var collision := move_and_collide(direction * step)
	if collision == null:
		_consecutive_collisions = 0
		_set_walking(true)
		return
	velocity = Vector3.ZERO
	_set_walking(false)
	_plan_detour(collision, direction)

## Desvío local: se apoya en el normal de la colisión y vuelve al
## waypoint original. Así los visitantes rodean muebles sin requerir NavMesh.
func _plan_detour(collision: KinematicCollision3D, travel_direction: Vector3) -> void:
	_consecutive_collisions += 1
	if _consecutive_collisions > MAX_CONSECUTIVE_COLLISIONS:
		_abort_blocked_visit()
		return
	var normal := collision.get_normal()
	normal.y = 0.0
	if normal.length_squared() <= 0.001:
		normal = -travel_direction
	normal = normal.normalized()
	var tangent := Vector3(-normal.z, 0.0, normal.x)
	# Preferimos el lado que mantiene avance hacia el objetivo y alternamos tras
	# un choque consecutivo para escapar de esquinas y extremos de mostradores.
	var preferred_side := 1.0 if tangent.dot(travel_direction) >= 0.0 else -1.0
	if _consecutive_collisions > 1:
		_detour_side *= -1.0
	else:
		_detour_side = preferred_side
	var detour := global_position + tangent * _detour_side * DETOUR_DISTANCE + travel_direction * 0.35
	detour.y = global_position.y
	_detour_waypoints.clear()
	_detour_waypoints.append(detour)

func _abort_blocked_visit() -> void:
	# Si un mueble bloquea el último tramo, el cliente sigue visible y espera en
	# el punto alcanzado: nunca desaparece al dirigirse a caja.
	_detour_waypoints.clear()
	velocity = Vector3.ZERO
	_set_walking(false)
	var manager := get_tree().get_first_node_in_group("visitor_negotiation_manager")
	if not _is_browse_visit:
		_state = State.WAITING_FOR_ATTENDANCE
		set_attention_indicator(true, "Estoy listo para\natender la oferta.")
		if manager != null:
			manager.customer_waiting_for_attendance(visitor_instance_id)
	else:
		leave_store()

func _on_facilities_changed(_installation: Dictionary) -> void:
	call_deferred("_refresh_behavior")

func _on_facility_removed(_installation_id: String, _refund: int) -> void:
	call_deferred("_refresh_behavior")

func _refresh_behavior() -> void:
	if not visible:
		return
	if not GameState.active_visitor_negotiation.is_empty():
		return
	var display_id := GameState.get_display_counter_id()
	var display_visual := _get_nearest_visual("customer_display_counter")
	if not display_id.is_empty() and display_visual != null:
		_target_visual = display_visual
		_display_view_point_index = _closest_display_view_point_index()
		_destination = _display_viewing_point(_display_view_point_index)
		_state = State.WALKING_TO_DISPLAY
		return
	var counter := _get_installed_facility(GameState.POINT_OF_SALE_FACILITY_ID)
	var counter_visual := _get_nearest_visual("point_of_sale_counter")
	if not counter.is_empty() and counter_visual != null:
		_target_visual = counter_visual
		_destination = _closest_counter_viewing_point(counter, counter_visual)
		_state = State.WALKING_TO_COUNTER
		return
	_target_visual = null
	_state = State.IDLE
	velocity = Vector3.ZERO
	_set_walking(false)

func begin_purchase_visit(display_entry: Dictionary, watch_name: String, queue_position := 0, customer_name := "") -> bool:
	_is_browse_visit = false
	_queue_position = queue_position
	_customer_name = customer_name.strip_edges()
	var facility_id := String(display_entry.get("facility_installation_id", ""))
	var display_visual := _get_visual_by_selection_id("customer_display_counter", facility_id)
	if display_visual != null and not facility_id.is_empty():
		visible = true
		# Both customers enter through the actual doorway before fanning out inside;
		# never reveal a queued visitor beside a display or the checkout.
		# Los dos visitantes esperan fuera en posiciones separadas antes de cruzar
		# el mismo umbral, evitando que parezcan aparecer superpuestos dentro.
		global_position = exit_position + Vector3(float(queue_position) * 0.65, 0.0, -float(queue_position) * 0.45)
		_pending_display_visual = display_visual
		_pending_watch_name = watch_name
		_target_visual = null
		_begin_entry_route(queue_position)
		_state = State.ENTERING_STORE
		set_attention_indicator(true, "Busco una pieza\ncon carácter.")
		return true
	return false

func begin_waiting_outside(queue_position := 0, customer_name := "") -> void:
	_is_browse_visit = false
	_queue_position = queue_position
	_customer_name = customer_name.strip_edges()
	visible = true
	global_position = exit_position + Vector3(float(queue_position) * 0.65, 0.0, -float(queue_position) * 0.45)
	velocity = Vector3.ZERO
	_state = State.WAITING_OUTSIDE
	set_attention_indicator(true, "Esperando en\nla entrada")
	_set_walking(false)

func begin_waiting_to_browse() -> void:
	if is_leaving_store():
		return
	set_visitor_visual(STANDARD_VISUAL_ID)
	visible = true
	global_position = exit_position
	_is_browse_visit = true
	_customer_name = ""
	_target_visual = null
	velocity = Vector3.ZERO
	_state = State.WAITING_OUTSIDE
	set_attention_indicator(true, "Esperando en\nla entrada")
	_set_walking(false)

func _start_pending_purchase_display() -> void:
	if _is_browse_visit:
		var display_visual := _get_nearest_visual("customer_display_counter")
		if display_visual == null:
			_viewing_time_remaining = 3.0
			_state = State.BROWSING_EMPTY
			set_attention_indicator(true, "Explorando\nla boutique")
			return
		_target_visual = display_visual
		_display_view_point_index = _closest_display_view_point_index()
		_destination = _display_viewing_point(_display_view_point_index)
		_state = State.WALKING_TO_DISPLAY
		set_attention_indicator(true, "Explorando\nla boutique")
		return
	if _pending_display_visual == null or not is_instance_valid(_pending_display_visual):
		_notify_visit_failed("La vitrina ya no está disponible.")
		return
	_target_visual = _pending_display_visual
	_display_view_point_index = _closest_display_view_point_index()
	_destination = _display_viewing_point(_display_view_point_index)
	_state = State.WALKING_TO_PURCHASE_DISPLAY
	set_attention_indicator(true, "Examinando\n%s" % _pending_watch_name)

func begin_browse_visit() -> void:
	if is_leaving_store():
		return
	# Ambient visits do not have an economic profile. Always use the standard
	# shopper instead of retaining the appearance of a prior classic purchase.
	set_visitor_visual(STANDARD_VISUAL_ID)
	visible = true
	global_position = exit_position
	_is_browse_visit = true
	_customer_name = ""
	_target_visual = null
	_begin_entry_route()
	_state = State.ENTERING_STORE
	set_attention_indicator(true, "¿Qué habrá hoy\nen la boutique?")

func is_waiting_outside() -> bool:
	return _state == State.WAITING_OUTSIDE

func _begin_entry_route(queue_position := 0) -> void:
	_detour_waypoints.clear()
	_consecutive_collisions = 0
	# Door threshold, inner threshold, then a visible interior staging point.
	# The latter gives simultaneous visitors room to queue without widening the
	# exterior spawn beyond the door opening.
	_entry_route = [
		doorway_position,
		entrance_position,
		entrance_position + Vector3(float(queue_position) * 0.75, 0.0, 0.8),
	]
	_entry_route_index = 0
	_destination = _entry_route[_entry_route_index]

func _advance_entry_route() -> void:
	_entry_route_index += 1
	if _entry_route_index < _entry_route.size():
		_destination = _entry_route[_entry_route_index]
		return
	_entry_route.clear()
	_viewing_time_remaining = 2.5
	_state = State.DECIDING_PURCHASE
	set_attention_indicator(true, "Voy a mirar con\ncalma primero.")

func _walk_to_negotiation_counter() -> bool:
	var counter := _get_installed_facility(GameState.POINT_OF_SALE_FACILITY_ID)
	var counter_visual := _get_nearest_visual("point_of_sale_counter")
	if counter.is_empty() or counter_visual == null:
		return false
	_target_visual = counter_visual
	_destination = _closest_counter_viewing_point(counter, counter_visual)
	# Un único TPV: las visitas posteriores esperan detrás de la primera.
	_destination += counter_visual.global_transform.basis.orthonormalized() * Vector3(0.0, 0.0, float(_queue_position) * 0.9)
	_state = State.WALKING_TO_NEGOTIATION
	set_attention_indicator(true, "Puede ser la pieza\nadecuada.")
	return true

func _notify_visit_failed(message: String) -> void:
	_state = State.IDLE
	set_attention_indicator(false)
	var manager := get_tree().get_first_node_in_group("visitor_negotiation_manager")
	if manager != null:
		manager.customer_visit_failed(visitor_instance_id, message)

func end_purchase_visit() -> void:
	_is_browse_visit = false
	set_attention_indicator(false)
	_state = State.IDLE
	velocity = Vector3.ZERO
	_set_walking(false)
	call_deferred("_refresh_behavior")

## La resolución visual ocurre antes de la salida. Mantiene la regla económica
## en el manager y sólo presenta pago o frustración en el personaje.
func resolve_purchase_visit(reaction: String) -> void:
	_detour_waypoints.clear()
	_consecutive_collisions = 0
	velocity = Vector3.ZERO
	_is_browse_visit = false
	set_attention_indicator(reaction == "checkout", "Pago confirmado." if reaction == "checkout" else "No llegaremos a un acuerdo.")
	_show_profile_visual(reaction, false)
	_reaction_time_remaining = 1.35
	_state = State.REACTION

func leave_store() -> void:
	_detour_waypoints.clear()
	_consecutive_collisions = 0
	_is_browse_visit = false
	set_attention_indicator(true, "Volveré cuando encuentre\nla pieza perfecta.")
	# Salida en dos tramos: posición interior de la puerta y exterior.
	_destination = entrance_position
	_state = State.WALKING_TO_EXIT_DOOR

func is_leaving_store() -> bool:
	return _state == State.WALKING_TO_EXIT_DOOR or _state == State.LEAVING_STORE

func _get_installed_facility(item_id: String) -> Dictionary:
	for installation in GameState.get_facility_installations():
		if String(installation.get("item_id", "")) == item_id:
			return installation
	return {}

func _get_nearest_visual(group_name: String) -> Node3D:
	var nearest: Node3D
	var nearest_distance := INF
	for node in get_tree().get_nodes_in_group(group_name):
		if node is Node3D:
			var visual := node as Node3D
			var distance := global_position.distance_squared_to(visual.global_position)
			if distance < nearest_distance:
				nearest = visual
				nearest_distance = distance
	return nearest

func _get_visual_by_selection_id(group_name: String, selection_id: String) -> Node3D:
	for node in get_tree().get_nodes_in_group(group_name):
		if node is Node3D and String(node.get_meta("selection_id", "")) == selection_id:
			return node as Node3D
	return null

func set_attention_indicator(is_visible: bool, message := "", bubble_style := AttentionBubbleStyle.THOUGHT) -> void:
	var display_message := message
	if not _customer_name.is_empty() and not message.strip_edges().is_empty():
		display_message = "%s\n%s" % [_customer_name, message]
	if _thought_label != null:
		_thought_label.text = display_message
		_thought_label.visible = is_visible and not display_message.strip_edges().is_empty()
	attention_indicator_changed.emit(is_visible and not display_message.strip_edges().is_empty(), display_message, bubble_style)

func _create_thought_label() -> void:
	_thought_label = Label3D.new()
	_thought_label.name = "CustomerThought"
	_thought_label.position = Vector3(0.0, 2.15, 0.0)
	_thought_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_thought_label.font_size = 40
	_thought_label.pixel_size = 0.004
	_thought_label.outline_size = 4
	_thought_label.modulate = Color(0.98, 0.94, 0.84, 0.95)
	_thought_label.outline_modulate = Color(0.08, 0.06, 0.04, 0.9)
	_thought_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_thought_label.no_depth_test = true
	_thought_label.visible = false
	add_child(_thought_label)

func _closest_display_view_point_index() -> int:
	var first_distance := global_position.distance_squared_to(_display_viewing_point(0))
	var second_distance := global_position.distance_squared_to(_display_viewing_point(1))
	return 0 if first_distance <= second_distance else 1

func _display_viewing_point(index: int) -> Vector3:
	if _target_visual == null:
		return global_position
	# These are world-space distances from the front of the display; visual import
	# scale must not make the customer stand farther away.
	var points: Array[Vector3] = [Vector3(-1.25, 0.0, 0.95), Vector3(1.25, 0.0, 0.95)]
	var viewing_point: Vector3 = _target_visual.global_position + _target_visual.global_transform.basis.orthonormalized() * points[index]
	viewing_point.y = global_position.y
	return viewing_point

func _face_target() -> void:
	if _target_visual == null:
		return
	var look_target := _target_visual.global_position
	look_target.y = global_position.y
	if not global_position.is_equal_approx(look_target):
		look_at(look_target, Vector3.UP)

func _closest_counter_viewing_point(counter: Dictionary, counter_visual: Node3D) -> Vector3:
	var footprint: Dictionary = counter.get("footprint", {})
	var local_footprint := _local_footprint(footprint, counter_visual)
	var half_x := local_footprint.x
	var half_z := local_footprint.y
	var local_candidates: Array[Vector3] = [
		Vector3(half_x + counter_viewing_margin, 0.0, 0.0),
		Vector3(-half_x - counter_viewing_margin, 0.0, 0.0),
		Vector3(0.0, 0.0, half_z + counter_viewing_margin),
		Vector3(0.0, 0.0, -half_z - counter_viewing_margin),
	]
	var counter_basis := counter_visual.global_transform.basis.orthonormalized()
	var closest := counter_visual.global_position + counter_basis * local_candidates[0]
	var closest_distance := global_position.distance_squared_to(closest)
	for index in range(1, local_candidates.size()):
		var candidate: Vector3 = counter_visual.global_position + counter_basis * local_candidates[index]
		var candidate_distance := global_position.distance_squared_to(candidate)
		if candidate_distance < closest_distance:
			closest = candidate
			closest_distance = candidate_distance
	closest.y = global_position.y
	return closest

func _local_footprint(footprint: Dictionary, visual: Node3D) -> Vector2:
	var half_x := float(footprint.get("half_x", 1.0))
	var half_z := float(footprint.get("half_z", 1.0))
	var local_x_axis := visual.global_transform.basis.orthonormalized().x
	return Vector2(half_z, half_x) if absf(local_x_axis.z) > absf(local_x_axis.x) else Vector2(half_x, half_z)

func _set_walking(is_walking: bool) -> void:
	_is_walking = is_walking
	if _state != State.REACTION:
		_show_profile_visual("walk" if is_walking else "idle", true)

func _show_profile_visual(kind: String, loop: bool) -> void:
	var nodes := _visual_nodes_for(_visual_id)
	var visual_name := String(nodes.get(kind, nodes.get("idle", "")))
	if visual_name.is_empty():
		return
	for node_name in _all_visual_node_names():
		var visual := get_node_or_null(NodePath(node_name)) as Node3D
		if visual == null:
			continue
		var is_selected := node_name == visual_name
		visual.visible = is_selected
		var player := _find_animation_player(visual)
		if is_selected:
			if kind == "idle" and bool(nodes.get("idle_static", false)):
				_show_first_animation_pose(player)
			else:
				_play_first_animation(player, loop)
		else:
			_stop_animation(player)

func _visual_nodes_for(visual_id: String) -> Dictionary:
	match visual_id:
		GIFT_BUYER_VISUAL_ID:
			return {"idle": "GiftBuyerIdleVisual", "walk": "GiftBuyerWalkVisual", "agree": "GiftBuyerAgreeVisual", "checkout": "GiftBuyerCheckoutVisual", "inspect": "GiftBuyerInspectVisual", "angry": "GiftBuyerIdleVisual"}
		ASPIRATIONAL_PROFESSIONAL_VISUAL_ID:
			return {"idle": "ProfessionalIdleVisual", "walk": "ProfessionalWalkVisual", "agree": "ProfessionalAgreeVisual", "checkout": "ProfessionalCheckoutVisual", "angry": "ProfessionalAngryVisual"}
		DEMANDING_COLLECTOR_VISUAL_ID:
			return {"idle": "CollectorIdleVisual", "walk": "CollectorWalkVisual", "agree": "CollectorAgreeVisual", "checkout": "CollectorCheckoutVisual", "angry": "CollectorAngryVisual"}
		CAREFUL_RETIREE_VISUAL_ID:
			# No hay GLB idle: parado conserva la pose inicial del GLB walk.
			return {"idle": "CarefulRetireeWalkVisual", "walk": "CarefulRetireeWalkVisual", "agree": "CarefulRetireeAgreeVisual", "checkout": "CarefulRetireeCheckoutVisual", "angry": "CarefulRetireeAngryVisual", "run": "CarefulRetireeRunVisual", "idle_static": true}
		CLASSIC_VISUAL_ID:
			return {"idle": "ClassicIdleVisual", "walk": "ClassicWalkVisual", "inspect": "ClassicInspectVisual", "agree": "ClassicInspectVisual", "checkout": "ClassicIdleVisual", "angry": "ClassicRunVisual"}
		_:
			return {"idle": "IdleVisual", "walk": "WalkVisual", "agree": "IdleVisual", "checkout": "IdleVisual", "angry": "IdleVisual"}

func _all_visual_node_names() -> Array[String]:
	return ["IdleVisual", "WalkVisual", "ClassicIdleVisual", "ClassicWalkVisual", "ClassicRunVisual", "ClassicInspectVisual", "GiftBuyerIdleVisual", "GiftBuyerWalkVisual", "GiftBuyerAgreeVisual", "GiftBuyerCheckoutVisual", "GiftBuyerInspectVisual", "ProfessionalIdleVisual", "ProfessionalWalkVisual", "ProfessionalAgreeVisual", "ProfessionalCheckoutVisual", "ProfessionalAngryVisual", "CollectorIdleVisual", "CollectorWalkVisual", "CollectorAgreeVisual", "CollectorCheckoutVisual", "CollectorAngryVisual", "CarefulRetireeWalkVisual", "CarefulRetireeAgreeVisual", "CarefulRetireeCheckoutVisual", "CarefulRetireeAngryVisual", "CarefulRetireeRunVisual"]

func _stop_animation(animation_player: AnimationPlayer) -> void:
	if animation_player != null:
		animation_player.stop()

func _play_first_animation(animation_player: AnimationPlayer, loop := true) -> void:
	if animation_player == null or animation_player.is_playing():
		return
	for animation_name in animation_player.get_animation_list():
		if animation_name != "RESET":
			var animation := animation_player.get_animation(animation_name)
			if animation != null:
				animation.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
			animation_player.play(animation_name)
			return

## No reproduce el walk al estar parado: deja únicamente su fotograma inicial.
func _show_first_animation_pose(animation_player: AnimationPlayer) -> void:
	if animation_player == null:
		return
	for animation_name in animation_player.get_animation_list():
		if animation_name != "RESET":
			animation_player.play(animation_name)
			animation_player.seek(0.0, true)
			animation_player.pause()
			return

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null

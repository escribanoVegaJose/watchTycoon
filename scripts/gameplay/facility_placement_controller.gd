extends Node

@export var camera_path: NodePath
@export var installation_container_path: NodePath
@export var facility_definitions: Array[FacilityDefinition] = []
@export var placement_collision_mask := 1
@export var floor_half_extents := Vector2(8.45, 5.95)

@onready var camera: Camera3D = get_node(camera_path) as Camera3D
@onready var installation_container: Node3D = get_node(installation_container_path) as Node3D

var _active := false
var _definition: FacilityDefinition
var _ghost: GhostPreview3D
var _candidate_transform := Transform3D.IDENTITY
var _candidate_valid := false
var _candidate_reason := ""
var _rendered_installations: Dictionary = {}
var _rotation_y := 0.0
var _moving_installation_id := ""
var _selected_installation_id := ""
var _selected_displayed_watch_id := ""
var _placement_mode_active := false
const FACILITY_SELECTION_MASK := 32
const WATCH_SELECTION_MASK := 64
const CUSTOMER_SELECTION_MASK := 16

func _ready() -> void:
	EventBus.facility_item_selected.connect(_on_facility_item_selected)
	EventBus.facade_item_selected.connect(_on_facade_item_selected)
	EventBus.placement_cancel_requested.connect(cancel_placement)
	EventBus.facility_installation_added.connect(_render_installation)
	EventBus.facility_installation_updated.connect(_on_facility_installation_updated)
	EventBus.facility_installation_removed.connect(_on_facility_installation_removed)
	EventBus.facility_installations_reloaded.connect(_restore_installations)
	EventBus.facility_move_requested.connect(_on_facility_move_requested)
	EventBus.facade_move_requested.connect(_on_facade_move_requested)
	EventBus.facility_demolish_requested.connect(_on_facility_demolish_requested)
	EventBus.world_selection_changed.connect(_on_world_selection_changed)
	EventBus.placement_state_changed.connect(_on_placement_state_changed)
	call_deferred("_restore_installations")

func _process(_delta: float) -> void:
	if _active:
		_update_candidate()

func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		if _placement_mode_active:
			return
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT and _select_at_mouse():
				get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			cancel_placement()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_confirm_placement()
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_Q or event.keycode == KEY_E):
		_rotation_y += PI * 0.5 if event.keycode == KEY_Q else -PI * 0.5
		_update_candidate()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("placement_cancel"):
		cancel_placement()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("placement_confirm"):
		_confirm_placement()
		get_viewport().set_input_as_handled()

func _on_facility_item_selected(item_id: String) -> void:
	for definition in facility_definitions:
		if definition != null and definition.item_id == item_id:
			if _has_reached_installation_limit(definition):
				EventBus.feedback_requested.emit("Ya has instalado el máximo de %s." % definition.display_name, "error")
				return
			_start_placement(definition)
			return
	EventBus.feedback_requested.emit("Esta instalación no está disponible.", "error")

func _on_facade_item_selected(_item_id: String) -> void:
	# Only one placement mode may own the shared preview bar and pointer input.
	cancel_placement(false)

func _start_placement(definition: FacilityDefinition) -> void:
	_start_placement_for_installation(definition, "")

func _start_placement_for_installation(definition: FacilityDefinition, moving_installation_id: String) -> void:
	cancel_placement(false)
	EventBus.world_selection_changed.emit("", "", Vector3.ZERO)
	_definition = definition
	_moving_installation_id = moving_installation_id
	_rotation_y = _rotation_for_installation(moving_installation_id)
	_ghost = GhostPreview3D.new()
	var visual := definition.visual_scene.instantiate() as Node3D
	visual.scale = definition.visual_scale
	_ghost.set_visual(visual)
	installation_container.add_child(_ghost)
	_active = true
	EventBus.placement_state_changed.emit(true, "Mover %s" % definition.display_name if not moving_installation_id.is_empty() else definition.display_name)
	_update_candidate()

func cancel_placement(emit_event := true) -> void:
	var was_active := _active
	if _ghost != null and is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null
	_definition = null
	_moving_installation_id = ""
	_rotation_y = 0.0
	_active = false
	_candidate_valid = false
	if emit_event and was_active:
		EventBus.placement_state_changed.emit(false, "")

func _update_candidate() -> void:
	_candidate_valid = false
	_candidate_reason = "Apunta al suelo del taller."
	var origin := camera.project_ray_origin(get_viewport().get_mouse_position())
	var end := origin + camera.project_ray_normal(get_viewport().get_mouse_position()) * 100.0
	var query := PhysicsRayQueryParameters3D.create(origin, end, placement_collision_mask)
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and _definition != null:
		var position: Vector3 = hit.position
		position.y = _definition.floor_offset
		_candidate_transform = Transform3D(Basis(Vector3.UP, _rotation_y), position)
		var footprint := _rotated_footprint(_definition.footprint_half_extents)
		if absf(position.x) + footprint.x > floor_half_extents.x or absf(position.z) + footprint.y > floor_half_extents.y:
			_candidate_reason = "La instalación debe quedar dentro del taller."
		elif _overlaps_existing(position, footprint):
			_candidate_reason = "No hay espacio: se solapa con otra instalación."
		elif _has_reached_installation_limit(_definition, _moving_installation_id):
			_candidate_reason = "Ya has instalado el máximo de %s." % _definition.display_name
		elif _moving_installation_id.is_empty() and not GameState.can_make_voluntary_payment(_definition.price):
			_candidate_reason = "Inversión suspendida: recupera liquidez con ventas o entregas." if GameState.money < 0 else "Fondos insuficientes para colocar esta instalación."
		else:
			_candidate_valid = true
			_candidate_reason = "Posición válida. Q/E para rotar · clic izquierdo o Enter para confirmar."
	if _ghost != null:
		_ghost.global_transform = _candidate_transform
		_ghost.visible = not hit.is_empty()
		_ghost.set_valid(_candidate_valid)
	EventBus.placement_preview_changed.emit(_candidate_valid, _candidate_reason)

func _overlaps_existing(position: Vector3, footprint: Vector2) -> bool:
	for installation in GameState.get_facility_installations():
		var transform_data: Dictionary = installation.get("transform", {})
		var origin: Array = transform_data.get("origin", [])
		var other_footprint: Dictionary = installation.get("footprint", {})
		if origin.size() != 3:
			continue
		var half_x := float(other_footprint.get("half_x", 0.0))
		var half_z := float(other_footprint.get("half_z", 0.0))
		if String(installation.get("installation_id", "")) != _moving_installation_id and absf(position.x - float(origin[0])) < footprint.x + half_x and absf(position.z - float(origin[2])) < footprint.y + half_z:
			return true
	return false

func _has_reached_installation_limit(definition: FacilityDefinition, excluded_installation_id := "") -> bool:
	if definition == null or definition.max_installations <= 0:
		return false
	var installed := 0
	for installation in GameState.get_facility_installations():
		if String(installation.get("installation_id", "")) != excluded_installation_id and String(installation.get("item_id", "")) == definition.item_id:
			installed += 1
	return installed >= definition.max_installations

func _rotated_footprint(footprint: Vector2) -> Vector2:
	var quarter_turns := posmod(int(round(_rotation_y / (PI * 0.5))), 2)
	return Vector2(footprint.y, footprint.x) if quarter_turns == 1 else footprint

func _confirm_placement() -> void:
	_update_candidate()
	if not _candidate_valid or _definition == null:
		EventBus.feedback_requested.emit(_candidate_reason, "error")
		return
	var half_extents := _rotated_footprint(_definition.footprint_half_extents)
	var footprint := {"half_x": half_extents.x, "half_z": half_extents.y}
	var transform_data := TransformSerialization.serialize(_candidate_transform)
	var completed := GameState.move_facility_installation(_moving_installation_id, transform_data, footprint) if not _moving_installation_id.is_empty() else GameState.try_install_facility(_definition.item_id, transform_data, _definition.price, footprint)
	if completed:
		cancel_placement()
	else:
		EventBus.feedback_requested.emit("No se pudo completar la instalación.", "error")

func _restore_installations() -> void:
	EventBus.world_selection_changed.emit("", "", Vector3.ZERO)
	for visual in _rendered_installations.values():
		if visual is Node3D and is_instance_valid(visual):
			(visual as Node3D).queue_free()
	_rendered_installations.clear()
	for installation in GameState.get_facility_installations():
		_render_installation(installation)

func _render_installation(installation: Dictionary) -> void:
	var installation_id := String(installation.get("installation_id", ""))
	if installation_id.is_empty() or _rendered_installations.has(installation_id):
		return
	var item_id := String(installation.get("item_id", ""))
	for definition in facility_definitions:
		if definition == null or definition.item_id != item_id:
			continue
		var visual := definition.visual_scene.instantiate() as Node3D
		installation_container.add_child(visual)
		visual.add_to_group("world_selectable_facility")
		if definition.item_id == GameState.POINT_OF_SALE_FACILITY_ID:
			visual.add_to_group("point_of_sale_counter")
		elif definition.is_display_facility():
			visual.add_to_group("customer_display_counter")
		visual.set_meta("selection_id", installation_id)
		visual.set_meta("facility_visual_scale", definition.visual_scale)
		visual.global_transform = TransformSerialization.deserialize(installation.get("transform", {}))
		# Saves made before a model scale/pivot correction stored an older floor height.
		if visual.global_position.y < definition.floor_offset:
			visual.global_position.y = definition.floor_offset
		visual.scale = definition.visual_scale
		_add_integrated_light(visual, definition.item_id)
		_add_selection_collider(visual, installation_id, installation.get("footprint", {}))
		_rendered_installations[installation_id] = visual
		return

func _on_facility_installation_updated(installation: Dictionary) -> void:
	var installation_id := String(installation.get("installation_id", ""))
	var visual: Node3D = _rendered_installations.get(installation_id)
	if visual != null and is_instance_valid(visual):
		visual.global_transform = TransformSerialization.deserialize(installation.get("transform", {}))
		visual.scale = visual.get_meta("facility_visual_scale", Vector3.ONE)

func _on_facility_installation_removed(installation_id: String, _refund: int) -> void:
	var visual: Node3D = _rendered_installations.get(installation_id)
	if visual != null and is_instance_valid(visual):
		visual.queue_free()
	_rendered_installations.erase(installation_id)
	EventBus.world_selection_changed.emit("", "", Vector3.ZERO)

func get_rendered_installation(installation_id: String) -> Node3D:
	var visual: Node3D = _rendered_installations.get(installation_id)
	return visual if visual != null and is_instance_valid(visual) else null

func _on_world_selection_changed(selection_type: String, selection_id: String, _anchor_position: Vector3) -> void:
	_selected_installation_id = selection_id if selection_type == "facility" else ""
	_selected_displayed_watch_id = selection_id if selection_type == "displayed_watch" else ""

func _on_placement_state_changed(active: bool, _item_name: String) -> void:
	_placement_mode_active = active

func _add_selection_collider(visual: Node3D, installation_id: String, footprint: Dictionary) -> void:
	var body := StaticBody3D.new()
	# Every placed facility receives this footprint collider, even when its GLB
	# contains no collision geometry. It serves both selection and character blocking.
	body.collision_layer = FACILITY_SELECTION_MASK | 8 # FacilitySelection + WorldSolid.
	body.collision_mask = 0
	body.set_meta("installation_id", installation_id)
	# The visual can have an import correction scale; cancel it for the footprint,
	# which is already stored in world units.
	body.scale = Vector3(1.0 / visual.scale.x, 1.0 / visual.scale.y, 1.0 / visual.scale.z)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	var local_footprint := _local_footprint(footprint, visual)
	shape.size = Vector3(local_footprint.x * 2.0, 2.0, local_footprint.y * 2.0)
	collision.position.y = 1.0
	collision.shape = shape
	body.add_child(collision)
	visual.add_child(body)

func _local_footprint(footprint: Dictionary, visual: Node3D) -> Vector2:
	var half_x := float(footprint.get("half_x", 1.0))
	var half_z := float(footprint.get("half_z", 1.0))
	# Saved footprints are aligned to world axes for placement checks. Convert them
	# back to the visual's local axes before using a rotated child collider.
	var local_x_axis := visual.global_transform.basis.orthonormalized().x
	return Vector2(half_z, half_x) if absf(local_x_axis.z) > absf(local_x_axis.x) else Vector2(half_x, half_z)

func _add_integrated_light(visual: Node3D, item_id: String) -> void:
	# This is intentionally added only to completed installations, never to GhostPreview3D.
	if item_id != "counter_01":
		return
	var task_light := SpotLight3D.new()
	task_light.name = "CounterTaskLight"
	# Local to the counter so moving or rotating it also moves the integrated lamp light.
	task_light.position = Vector3(0.55, 2.6, -0.2)
	task_light.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	task_light.light_color = Color(1.0, 0.9, 0.72, 1.0)
	task_light.light_energy = 1.4
	task_light.spot_range = 4.8
	task_light.spot_attenuation = 1.35
	task_light.spot_angle = 29.0
	task_light.spot_angle_attenuation = 0.8
	task_light.shadow_enabled = true
	visual.add_child(task_light)

func _select_at_mouse() -> bool:
	var origin := camera.project_ray_origin(get_viewport().get_mouse_position())
	var end := origin + camera.project_ray_normal(get_viewport().get_mouse_position()) * 100.0
	var customer_query := PhysicsRayQueryParameters3D.create(origin, end, CUSTOMER_SELECTION_MASK)
	var customer_hit := camera.get_world_3d().direct_space_state.intersect_ray(customer_query)
	if not customer_hit.is_empty() and customer_hit.collider is CustomerVisitor:
		EventBus.world_selection_changed.emit("customer", "shop_customer", customer_hit.position + Vector3.UP * 0.9)
		return true
	# Watches have a dedicated layer and always win over their containing vitrina.
	var watch_query := PhysicsRayQueryParameters3D.create(origin, end, WATCH_SELECTION_MASK)
	var watch_hit := camera.get_world_3d().direct_space_state.intersect_ray(watch_query)
	if not watch_hit.is_empty() and watch_hit.collider is StaticBody3D and watch_hit.collider.has_meta("unit_id"):
		var unit_id := String(watch_hit.collider.get_meta("unit_id", ""))
		if unit_id == _selected_displayed_watch_id:
			# Defer mode entry until this click has finished propagating, otherwise
			# the shared slot controller could treat this same click as a placement.
			call_deferred("_request_displayed_watch_relocation", unit_id)
		else:
			EventBus.world_selection_changed.emit("displayed_watch", unit_id, watch_hit.position + Vector3.UP * 0.12)
		return true
	var query := PhysicsRayQueryParameters3D.create(origin, end, FACILITY_SELECTION_MASK)
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not hit.collider is StaticBody3D or not hit.collider.has_meta("installation_id"):
		return false
	EventBus.world_selection_changed.emit("facility", String(hit.collider.get_meta("installation_id")), hit.position + Vector3.UP * 0.2)
	return true

func _on_facility_move_requested(installation_id: String) -> void:
	for installation in GameState.get_facility_installations():
		if String(installation.get("installation_id", "")) != installation_id:
			continue
		for definition in facility_definitions:
			if definition != null and definition.item_id == String(installation.get("item_id", "")):
				_start_placement_for_installation(definition, installation_id)
				return

func _request_displayed_watch_relocation(unit_id: String) -> void:
	if unit_id == _selected_displayed_watch_id:
		EventBus.displayed_watch_relocation_requested.emit(unit_id)

func _on_facade_move_requested(_installation_id: String) -> void:
	# A window relocation takes ownership of the shared pointer and ghost.
	# Its controller publishes the active UI state for this request.
	cancel_placement(false)

func _on_facility_demolish_requested(installation_id: String) -> void:
	if GameState.is_display_counter_occupied(installation_id):
		EventBus.feedback_requested.emit("No puedes demoler una vitrina mientras tenga relojes expuestos.", "error")
		return
	var refund := GameState.demolish_facility_installation(installation_id)
	EventBus.feedback_requested.emit("Instalación demolida. Reembolso: %d €." % refund if refund > 0 else "No se pudo demoler la instalación.", "info" if refund > 0 else "error")

func _rotation_for_installation(installation_id: String) -> float:
	for installation in GameState.get_facility_installations():
		if String(installation.get("installation_id", "")) == installation_id:
			var basis: Array = (installation.get("transform", {}) as Dictionary).get("basis", [])
			if basis.size() == 9:
				return atan2(-float(basis[2]), float(basis[0]))
	return 0.0

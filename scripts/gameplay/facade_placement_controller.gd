extends Node

@export var camera_path: NodePath
@export var installation_container_path: NodePath
@export var window_definition: PlaceableDefinition
## Matches scene-authored starter windows so purchases cannot overlap them.
@export var default_window_paths: Array[NodePath]
@export var placement_collision_mask := 2

@onready var camera: Camera3D = get_node(camera_path) as Camera3D
@onready var installation_container: Node3D = get_node(installation_container_path) as Node3D

var _active := false
var _definition: PlaceableDefinition
var _ghost: GhostPreview3D
var _candidate_wall: PlacementWall
var _candidate_transform := Transform3D.IDENTITY
var _candidate_valid := false
var _candidate_reason := ""
var _rendered_installations: Dictionary = {}
var _moving_installation_id := ""
var _selected_type := ""
var _selected_id := ""
var _placement_mode_active := false
const WINDOW_SELECTION_MASK := 4
const FACILITY_SELECTION_MASK := 32
const WALL_FINISHES := {
	"ivory": Color(0.78, 0.71, 0.60),
	"graphite": Color(0.20, 0.22, 0.23),
	"deep_green": Color(0.08, 0.20, 0.16),
	"night_blue": Color(0.07, 0.12, 0.23),
	"steel": Color(0.43, 0.46, 0.47),
	"sand": Color(0.64, 0.53, 0.40),
	"terracotta": Color(0.46, 0.20, 0.14),
	"burgundy": Color(0.28, 0.07, 0.09),
	"sage": Color(0.31, 0.40, 0.32),
	"petrol": Color(0.05, 0.24, 0.29),
	"plum": Color(0.20, 0.11, 0.22),
}

func _ready() -> void:
	EventBus.facade_item_selected.connect(_on_facade_item_selected)
	EventBus.facility_item_selected.connect(_on_facility_item_selected)
	EventBus.placement_cancel_requested.connect(cancel_placement)
	EventBus.facade_installation_added.connect(_on_facade_installation_added)
	EventBus.facade_installation_updated.connect(_on_facade_installation_updated)
	EventBus.facade_installation_removed.connect(_on_facade_installation_removed)
	EventBus.facade_installations_reloaded.connect(_restore_installations)
	EventBus.facade_move_requested.connect(_on_facade_move_requested)
	EventBus.facility_move_requested.connect(_on_facility_move_requested)
	EventBus.facade_demolish_requested.connect(_on_facade_demolish_requested)
	EventBus.world_selection_changed.connect(_on_world_selection_changed)
	EventBus.placement_state_changed.connect(_on_placement_state_changed)
	EventBus.wall_finish_preview_requested.connect(_on_wall_finish_preview_requested)
	EventBus.wall_finish_apply_requested.connect(_on_wall_finish_apply_requested)
	EventBus.wall_finish_cancel_requested.connect(_on_wall_finish_cancel_requested)
	call_deferred("_restore_installations")
	call_deferred("_restore_wall_finishes")

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
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			_confirm_placement()
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("placement_cancel"):
		cancel_placement()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("placement_confirm"):
		_confirm_placement()
		get_viewport().set_input_as_handled()

func _on_facade_item_selected(item_id: String) -> void:
	if window_definition == null or item_id != window_definition.item_id:
		EventBus.feedback_requested.emit("Este elemento no está disponible.", "error")
		return
	_start_placement(window_definition)

func _on_facility_item_selected(_item_id: String) -> void:
	# Floor facilities take over the shared placement interaction.
	cancel_placement(false)

func _start_placement(definition: PlaceableDefinition) -> void:
	_start_placement_for_installation(definition, "")

func _start_placement_for_installation(definition: PlaceableDefinition, moving_installation_id: String) -> void:
	cancel_placement(false)
	EventBus.world_selection_changed.emit("", "", Vector3.ZERO)
	_definition = definition
	_moving_installation_id = moving_installation_id
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
	_active = false
	_definition = null
	_moving_installation_id = ""
	_candidate_wall = null
	_candidate_valid = false
	if emit_event and was_active:
		EventBus.placement_state_changed.emit(false, "")

func _update_candidate() -> void:
	_candidate_wall = null
	_candidate_valid = false
	_candidate_reason = "Apunta a una pared compatible para colocar la ventana."
	var mouse_position := get_viewport().get_mouse_position()
	var origin := camera.project_ray_origin(mouse_position)
	var end := origin + camera.project_ray_normal(mouse_position) * 100.0
	var query := PhysicsRayQueryParameters3D.create(origin, end, placement_collision_mask)
	query.collide_with_areas = false
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.collider is PlacementWall:
		_candidate_wall = hit.collider as PlacementWall
		_candidate_transform = _candidate_wall.get_mount_transform(hit.position, _definition)
		if not _candidate_wall.accepts(_definition):
			_candidate_reason = "Esta pared no es compatible con el elemento seleccionado."
		elif _candidate_wall.overlaps_existing(_candidate_transform, _definition, _installations_except_moving()):
			_candidate_reason = "No hay espacio: la ventana se solapa con otra instalación."
		elif _candidate_wall.overlaps_excluded_opening(_candidate_transform, _definition):
			_candidate_reason = "La ventana no puede colocarse sobre la abertura de entrada."
		elif _moving_installation_id.is_empty() and not GameState.can_make_voluntary_payment(_definition.price):
			_candidate_reason = "Fondos insuficientes para colocar esta ventana."
		else:
			_candidate_valid = true
			_candidate_reason = "Posición válida. Clic izquierdo o Enter para confirmar."
	if _ghost != null:
		_ghost.global_transform = _candidate_transform
		_ghost.visible = _candidate_wall != null
		_ghost.set_valid(_candidate_valid)
	EventBus.placement_preview_changed.emit(_candidate_valid, _candidate_reason)

func _confirm_placement() -> void:
	_update_candidate()
	if not _candidate_valid or _candidate_wall == null:
		EventBus.feedback_requested.emit(_candidate_reason, "error")
		return
	var transform_data := TransformSerialization.serialize(_candidate_transform)
	var completed := false
	if _moving_installation_id.is_empty():
		completed = GameState.try_install_facade_item(_definition.item_id, _candidate_wall.wall_id, transform_data, _definition.price, {"half_width": _definition.placement_half_width, "half_height": _definition.placement_half_height})
	else:
		completed = GameState.move_facade_installation(_moving_installation_id, _candidate_wall.wall_id, transform_data)
	if not completed:
		EventBus.feedback_requested.emit("No se pudo completar la instalación.", "error")
		_update_candidate()
		return
	cancel_placement()

func _on_facade_installation_added(installation: Dictionary) -> void:
	if String(installation.get("item_id", "")) != window_definition.item_id:
		return
	_render_installation(installation)

func _restore_installations() -> void:
	_set_selection("", "")
	for visual in _rendered_installations.values():
		if visual is Node3D and is_instance_valid(visual):
			(visual as Node3D).queue_free()
	_rendered_installations.clear()
	for installation in GameState.get_facade_installations():
		_on_facade_installation_added(installation)

func _render_installation(installation: Dictionary) -> void:
	var installation_id := String(installation.get("installation_id", ""))
	if installation_id.is_empty() or _rendered_installations.has(installation_id):
		return
	var visual := window_definition.visual_scene.instantiate() as Node3D
	installation_container.add_child(visual)
	visual.add_to_group("world_selectable_window")
	visual.set_meta("selection_id", installation_id)
	visual.global_transform = TransformSerialization.deserialize(installation.get("transform", {}))
	visual.scale = window_definition.visual_scale
	_rendered_installations[installation_id] = visual
	_add_selection_collider(visual, installation_id)

func _on_facade_installation_updated(installation: Dictionary) -> void:
	var installation_id := String(installation.get("installation_id", ""))
	var visual: Node3D = _rendered_installations.get(installation_id)
	if visual != null and is_instance_valid(visual):
		visual.global_transform = TransformSerialization.deserialize(installation.get("transform", {}))

func _on_facade_installation_removed(installation_id: String, _refund: int) -> void:
	var visual: Node3D = _rendered_installations.get(installation_id)
	if visual != null and is_instance_valid(visual):
		visual.queue_free()
	_rendered_installations.erase(installation_id)
	_set_selection("", "")

func _add_selection_collider(visual: Node3D, installation_id: String) -> void:
	var body := StaticBody3D.new()
	body.name = "WindowSelection"
	body.collision_layer = WINDOW_SELECTION_MASK | 8 # SelectionRay + WorldSolid.
	body.collision_mask = 0
	body.set_meta("installation_id", installation_id)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(window_definition.placement_half_width * 2.0, window_definition.placement_half_height * 2.0, 0.5)
	collision.shape = shape
	body.add_child(collision)
	visual.add_child(body)

func _select_at_mouse() -> bool:
	var origin := camera.project_ray_origin(get_viewport().get_mouse_position())
	var end := origin + camera.project_ray_normal(get_viewport().get_mouse_position()) * 100.0
	# Installed windows deliberately get a separate query first, so a wall behind one never wins.
	var window_query := PhysicsRayQueryParameters3D.create(origin, end, WINDOW_SELECTION_MASK)
	var window_hit := camera.get_world_3d().direct_space_state.intersect_ray(window_query)
	if not window_hit.is_empty() and window_hit.collider is StaticBody3D and window_hit.collider.has_meta("installation_id"):
		var installation_id := String(window_hit.collider.get_meta("installation_id"))
		var installation: Node3D = _rendered_installations.get(installation_id)
		var anchor: Vector3 = window_hit.position + Vector3.UP * 0.1
		if installation != null and is_instance_valid(installation):
			anchor = installation.global_position + Vector3.UP * (window_definition.placement_half_height + 0.1)
		_set_selection("window", installation_id, anchor)
		return true
	# FacilitySelection has its own controller later in the input chain. Do not
	# clear the current selection while that controller is about to select it.
	var facility_query := PhysicsRayQueryParameters3D.create(origin, end, FACILITY_SELECTION_MASK)
	var facility_hit := camera.get_world_3d().direct_space_state.intersect_ray(facility_query)
	if not facility_hit.is_empty() and facility_hit.collider is StaticBody3D and facility_hit.collider.has_meta("installation_id"):
		return false
	var wall_query := PhysicsRayQueryParameters3D.create(origin, end, placement_collision_mask)
	var wall_hit := camera.get_world_3d().direct_space_state.intersect_ray(wall_query)
	if not wall_hit.is_empty() and wall_hit.collider is PlacementWall:
		var wall := wall_hit.collider as PlacementWall
		# Collision is cut around entrance openings, but retain this guard for old
		# scenes or a ray that lands exactly on an opening edge.
		if wall.is_point_in_excluded_opening(wall_hit.position):
			_set_selection("", "")
			return true
		_set_selection("wall", wall.wall_id, wall_hit.position + Vector3.UP * 0.1)
		return true
	_set_selection("", "")
	return false

func _set_selection(selection_type: String, selection_id: String, anchor_position: Vector3 = Vector3.ZERO) -> void:
	_selected_type = selection_type
	_selected_id = selection_id
	EventBus.world_selection_changed.emit(selection_type, selection_id, anchor_position)

func _on_world_selection_changed(selection_type: String, selection_id: String, _anchor_position: Vector3) -> void:
	_selected_type = selection_type
	_selected_id = selection_id

func _on_placement_state_changed(active: bool, _item_name: String) -> void:
	_placement_mode_active = active

func _on_facade_move_requested(installation_id: String) -> void:
	for installation in GameState.get_facade_installations():
		if String(installation.get("installation_id", "")) == installation_id and String(installation.get("item_id", "")) == window_definition.item_id:
			_start_placement_for_installation(window_definition, installation_id)
			return

func _on_facility_move_requested(_installation_id: String) -> void:
	# A facility relocation takes ownership of the shared pointer and ghost.
	# Its controller publishes the active UI state for this request.
	cancel_placement(false)

func _on_facade_demolish_requested(installation_id: String) -> void:
	var refund := GameState.demolish_facade_installation(installation_id)
	if refund > 0:
		EventBus.feedback_requested.emit("Ventana demolida. Reembolso: %d €." % refund, "info")
	else:
		EventBus.feedback_requested.emit("No se pudo demoler la ventana.", "error")

func _installations_except_moving() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for path in default_window_paths:
		var window := get_node_or_null(path) as FacadeDefaultWindow
		if window == null or window.wall_id.is_empty():
			continue
		result.append({
			"installation_id": "default_%s" % window.get_path(),
			"wall_id": window.wall_id,
			"transform": TransformSerialization.serialize(window.global_transform),
			"footprint": {
				"half_width": window_definition.placement_half_width,
				"half_height": window_definition.placement_half_height,
			},
		})
	for installation in GameState.get_facade_installations():
		if String(installation.get("installation_id", "")) != _moving_installation_id:
			result.append(installation)
	return result

func _restore_wall_finishes() -> void:
	for wall_id in ["back", "front", "left", "right"]:
		_apply_wall_finish(wall_id, GameState.get_wall_finish(wall_id))

func _on_wall_finish_preview_requested(wall_id: String, finish_id: String) -> void:
	_apply_wall_finish(wall_id, finish_id)

func _on_wall_finish_apply_requested(wall_id: String, finish_id: String) -> void:
	if GameState.set_wall_finish(wall_id, finish_id):
		_apply_wall_finish(wall_id, finish_id)

func _on_wall_finish_cancel_requested(wall_id: String) -> void:
	_apply_wall_finish(wall_id, GameState.get_wall_finish(wall_id))

func _apply_wall_finish(wall_id: String, finish_id: String) -> void:
	var wall := get_node_or_null("../Architecture/%s" % _wall_node_name(wall_id)) as FacadeWall
	var color: Color = WALL_FINISHES.get(finish_id, WALL_FINISHES["ivory"])
	if wall != null:
		wall.set_finish_color(color)

func _wall_node_name(wall_id: String) -> String:
	return {"back": "BackWall", "front": "FrontWall", "left": "LeftWall", "right": "RightWall"}.get(wall_id, "")

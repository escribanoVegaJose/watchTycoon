extends Node

@export var camera_path: NodePath
@export var installation_container_path: NodePath
@export var window_definition: PlaceableDefinition
@export var placement_collision_mask := 2
@export var daylight_source_path: NodePath

@onready var camera: Camera3D = get_node(camera_path) as Camera3D
@onready var installation_container: Node3D = get_node(installation_container_path) as Node3D
@onready var daylight_source: DirectionalLight3D = get_node_or_null(daylight_source_path) as DirectionalLight3D

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
const WINDOW_SELECTION_MASK := 4
const WALL_FINISHES := {
	"ivory": Color(0.78, 0.71, 0.60),
	"graphite": Color(0.20, 0.22, 0.23),
	"deep_green": Color(0.08, 0.20, 0.16),
	"night_blue": Color(0.07, 0.12, 0.23),
	"steel": Color(0.43, 0.46, 0.47),
}

func _ready() -> void:
	EventBus.facade_item_selected.connect(_on_facade_item_selected)
	EventBus.placement_cancel_requested.connect(cancel_placement)
	EventBus.facade_installation_added.connect(_on_facade_installation_added)
	EventBus.facade_installation_updated.connect(_on_facade_installation_updated)
	EventBus.facade_installation_removed.connect(_on_facade_installation_removed)
	EventBus.facade_move_requested.connect(_on_facade_move_requested)
	EventBus.facade_demolish_requested.connect(_on_facade_demolish_requested)
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
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_select_at_mouse()
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

func _start_placement(definition: PlaceableDefinition) -> void:
	_start_placement_for_installation(definition, "")

func _start_placement_for_installation(definition: PlaceableDefinition, moving_installation_id: String) -> void:
	cancel_placement(false)
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
	if _ghost != null and is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null
	_active = false
	_definition = null
	_moving_installation_id = ""
	_candidate_wall = null
	_candidate_valid = false
	if emit_event:
		EventBus.placement_state_changed.emit(false, "")

func _update_candidate() -> void:
	_candidate_wall = null
	_candidate_valid = false
	_candidate_reason = "Apunta a una pared interior para colocar la ventana."
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
		elif _moving_installation_id.is_empty() and not GameState.can_afford(_definition.price):
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
	var transform_data := _serialize_transform(_candidate_transform)
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
	for installation in GameState.get_facade_installations():
		_on_facade_installation_added(installation)

func _render_installation(installation: Dictionary) -> void:
	var installation_id := String(installation.get("installation_id", ""))
	if installation_id.is_empty() or _rendered_installations.has(installation_id):
		return
	var visual := window_definition.visual_scene.instantiate() as Node3D
	installation_container.add_child(visual)
	visual.global_transform = _deserialize_transform(installation.get("transform", {}))
	visual.scale = window_definition.visual_scale
	_add_daylight_proxy(visual)
	_rendered_installations[installation_id] = visual
	_add_selection_collider(visual, installation_id)

func _on_facade_installation_updated(installation: Dictionary) -> void:
	var installation_id := String(installation.get("installation_id", ""))
	var visual: Node3D = _rendered_installations.get(installation_id)
	if visual != null and is_instance_valid(visual):
		visual.global_transform = _deserialize_transform(installation.get("transform", {}))

func _on_facade_installation_removed(installation_id: String, _refund: int) -> void:
	var visual: Node3D = _rendered_installations.get(installation_id)
	if visual != null and is_instance_valid(visual):
		visual.queue_free()
	_rendered_installations.erase(installation_id)
	_set_selection("", "")

func _add_selection_collider(visual: Node3D, installation_id: String) -> void:
	var body := StaticBody3D.new()
	body.name = "WindowSelection"
	body.collision_layer = WINDOW_SELECTION_MASK
	body.collision_mask = 0
	body.set_meta("installation_id", installation_id)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(window_definition.placement_half_width * 2.0, window_definition.placement_half_height * 2.0, 0.5)
	collision.shape = shape
	body.add_child(collision)
	visual.add_child(body)

func _select_at_mouse() -> void:
	var origin := camera.project_ray_origin(get_viewport().get_mouse_position())
	var end := origin + camera.project_ray_normal(get_viewport().get_mouse_position()) * 100.0
	# Installed windows deliberately get a separate query first, so a wall behind one never wins.
	var window_query := PhysicsRayQueryParameters3D.create(origin, end, WINDOW_SELECTION_MASK)
	var window_hit := camera.get_world_3d().direct_space_state.intersect_ray(window_query)
	if not window_hit.is_empty() and window_hit.collider is StaticBody3D and window_hit.collider.has_meta("installation_id"):
		_set_selection("window", String(window_hit.collider.get_meta("installation_id")))
		return
	var wall_query := PhysicsRayQueryParameters3D.create(origin, end, placement_collision_mask)
	var wall_hit := camera.get_world_3d().direct_space_state.intersect_ray(wall_query)
	if not wall_hit.is_empty() and wall_hit.collider is PlacementWall:
		_set_selection("wall", (wall_hit.collider as PlacementWall).wall_id)
		return
	_set_selection("", "")

func _set_selection(selection_type: String, selection_id: String) -> void:
	_selected_type = selection_type
	_selected_id = selection_id
	EventBus.world_selection_changed.emit(selection_type, selection_id)

func _on_facade_move_requested(installation_id: String) -> void:
	for installation in GameState.get_facade_installations():
		if String(installation.get("installation_id", "")) == installation_id and String(installation.get("item_id", "")) == window_definition.item_id:
			_start_placement_for_installation(window_definition, installation_id)
			return

func _on_facade_demolish_requested(installation_id: String) -> void:
	var refund := GameState.demolish_facade_installation(installation_id)
	if refund > 0:
		EventBus.feedback_requested.emit("Ventana demolida. Reembolso: %d €." % refund, "info")
	else:
		EventBus.feedback_requested.emit("No se pudo demoler la ventana.", "error")

func _installations_except_moving() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
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
	var wall := get_node_or_null("../Architecture/%s" % _wall_node_name(wall_id))
	var color: Color = WALL_FINISHES.get(finish_id, WALL_FINISHES["ivory"])
	if wall != null:
		_apply_wall_color_recursive(wall, color)

func _wall_node_name(wall_id: String) -> String:
	return {"back": "BackWall", "front": "FrontWall", "left": "LeftWall", "right": "RightWall"}.get(wall_id, "")

func _apply_wall_color_recursive(node: Node, color: Color) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		# Instance uniforms keep each wall independent while all walls share the plaster material.
		mesh.set_instance_shader_parameter("cream_color", color)
	for child in node.get_children():
		_apply_wall_color_recursive(child, color)

func _add_daylight_proxy(window_visual: Node3D) -> void:
	# La base -Z de la ventana ya mira hacia el interior (PlacementWall).
	# El foco se adelanta unos centimetros para no quedar dentro de la pared
	# opaca que se usa durante este alcance inicial.
	var proxy := WindowDaylightProxy.new()
	proxy.name = "WindowDaylightProxy"
	proxy.position = Vector3(0.0, 0.0, -0.24)
	proxy.configure_from_sun(daylight_source)
	window_visual.add_child(proxy)

func _serialize_transform(value: Transform3D) -> Dictionary:
	return {
		"origin": [value.origin.x, value.origin.y, value.origin.z],
		"basis": [value.basis.x.x, value.basis.x.y, value.basis.x.z, value.basis.y.x, value.basis.y.y, value.basis.y.z, value.basis.z.x, value.basis.z.y, value.basis.z.z],
	}

func _deserialize_transform(data: Dictionary) -> Transform3D:
	var origin_values: Array = data.get("origin", [])
	var basis_values: Array = data.get("basis", [])
	if origin_values.size() != 3 or basis_values.size() != 9:
		return Transform3D.IDENTITY
	var basis := Basis(Vector3(float(basis_values[0]), float(basis_values[1]), float(basis_values[2])), Vector3(float(basis_values[3]), float(basis_values[4]), float(basis_values[5])), Vector3(float(basis_values[6]), float(basis_values[7]), float(basis_values[8])))
	return Transform3D(basis, Vector3(float(origin_values[0]), float(origin_values[1]), float(origin_values[2])))

extends Node

## Shows valid vitrina slots for first placement and displayed-piece relocation.
@export var camera_path: NodePath
@export var facility_controller_path: NodePath

const SLOT_SELECTION_MASK := 128
const MARKER_COLOR := Color(0.2, 0.82, 0.62, 0.78)
const WatchDisplayController = preload("res://scripts/gameplay/watch_display_controller.gd")

@onready var camera: Camera3D = get_node(camera_path) as Camera3D
@onready var _facility_controller: Node = get_node(facility_controller_path)

var _piece_index := -1
var _piece_id := ""
var _sale_price := 0
var _relocating_displayed_piece := false
var _markers: Array[Node3D] = []

func _ready() -> void:
	EventBus.owned_watch_display_placement_requested.connect(_start)
	EventBus.displayed_watch_relocation_requested.connect(_start_relocation)
	EventBus.placement_cancel_requested.connect(_cancel)
	EventBus.watch_display_changed.connect(_on_display_changed)

func _unhandled_input(event: InputEvent) -> void:
	if not _is_active():
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_try_place_at_mouse()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("placement_cancel"):
		_cancel()
		get_viewport().set_input_as_handled()

func _start(piece_index: int, sale_price: int) -> void:
	_cancel(false)
	if piece_index < 0 or piece_index >= GameState.owned_pieces.size() or sale_price <= 0:
		EventBus.feedback_requested.emit("La pieza ya no está disponible.", "error")
		return
	_piece_index = piece_index
	_piece_id = String(GameState.owned_pieces[piece_index].get("id", ""))
	if _piece_id.is_empty():
		_cancel(false)
		EventBus.feedback_requested.emit("La pieza no tiene una identidad válida.", "error")
		return
	_sale_price = sale_price
	_build_markers()
	if _markers.is_empty():
		_cancel(false)
		EventBus.feedback_requested.emit("No hay huecos libres en las vitrinas.", "error")
		return
	EventBus.world_selection_changed.emit("", "", Vector3.ZERO)
	EventBus.display_slot_placement_state_changed.emit(true)
	EventBus.placement_state_changed.emit(true, "Colocar pieza en vitrina")
	EventBus.feedback_requested.emit("Elige un hueco iluminado de la vitrina. No necesitas llevar la pieza.", "info")

func _start_relocation(unit_id: String) -> void:
	_cancel(false)
	var displayed_piece := GameState.get_displayed_watch(unit_id)
	if displayed_piece.is_empty():
		EventBus.feedback_requested.emit("La pieza ya no está expuesta.", "error")
		return
	if GameState.is_visitor_reserved(unit_id):
		EventBus.feedback_requested.emit("No puedes mover una pieza reservada para un cliente.", "error")
		return
	_piece_id = unit_id
	_sale_price = int(displayed_piece.get("sale_price", 0))
	_relocating_displayed_piece = true
	_build_markers()
	if _markers.is_empty():
		_cancel(false)
		EventBus.feedback_requested.emit("No hay otro hueco libre en las vitrinas.", "error")
		return
	EventBus.world_selection_changed.emit("", "", Vector3.ZERO)
	EventBus.display_slot_placement_state_changed.emit(true)
	EventBus.placement_state_changed.emit(true, "Mover pieza en vitrina")
	EventBus.feedback_requested.emit("Elige un hueco iluminado para mover la pieza. Su hueco actual se conservará hasta confirmar.", "info")

func _build_markers() -> void:
	_clear_markers()
	for installation in GameState.get_facility_installations():
		if String(installation.get("item_id", "")) != "display_counter_01":
			continue
		var facility_id := String(installation.get("installation_id", ""))
		var counter := _facility_controller.call("get_rendered_installation", facility_id) as Node3D
		if counter == null:
			continue
		for slot in range(GameState.DISPLAY_CAPACITY):
			if GameState.is_display_slot_free(facility_id, slot):
				_add_marker(counter, facility_id, slot)

func _add_marker(counter: Node3D, facility_id: String, slot: int) -> void:
	var marker := Node3D.new()
	marker.name = "DisplaySlot_%s_%d" % [facility_id, slot]
	marker.position = _slot_local_position(slot)
	counter.add_child(marker)
	_markers.append(marker)
	var mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.13
	cylinder.bottom_radius = 0.13
	cylinder.height = 0.025
	mesh.mesh = cylinder
	var material := StandardMaterial3D.new()
	material.albedo_color = MARKER_COLOR
	material.emission_enabled = true
	material.emission = MARKER_COLOR
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material_override = material
	marker.add_child(mesh)
	var body := StaticBody3D.new()
	body.collision_layer = SLOT_SELECTION_MASK
	body.collision_mask = 0
	body.set_meta("facility_id", facility_id)
	body.set_meta("slot_index", slot)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.16
	shape.height = 0.10
	collision.position.y = 0.04
	collision.shape = shape
	body.add_child(collision)
	marker.add_child(body)

func _try_place_at_mouse() -> void:
	var origin := camera.project_ray_origin(get_viewport().get_mouse_position())
	var end := origin + camera.project_ray_normal(get_viewport().get_mouse_position()) * 100.0
	var query := PhysicsRayQueryParameters3D.create(origin, end, SLOT_SELECTION_MASK)
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not hit.collider is StaticBody3D:
		EventBus.feedback_requested.emit("Selecciona un hueco iluminado de una vitrina.", "error")
		return
	var facility_id := String(hit.collider.get_meta("facility_id", ""))
	var slot := int(hit.collider.get_meta("slot_index", -1))
	var placed := false
	if _relocating_displayed_piece:
		placed = GameState.move_displayed_watch(_piece_id, facility_id, slot)
	else:
		var current_index := _current_piece_index()
		placed = current_index >= 0 and GameState.display_owned_watch(current_index, facility_id, slot, _sale_price)
	if placed:
		EventBus.feedback_requested.emit("Pieza reubicada en la vitrina." if _relocating_displayed_piece else "Pieza colocada en la vitrina.", "info")
		_cancel()
		return
	_build_markers()
	EventBus.feedback_requested.emit("Ese hueco ya no está disponible.", "error")

func _on_display_changed(_snapshot: Dictionary) -> void:
	if not _is_active():
		return
	if _relocating_displayed_piece and GameState.get_displayed_watch(_piece_id).is_empty():
		EventBus.feedback_requested.emit("La pieza dejó de estar expuesta.", "error")
		_cancel()
		return
	_build_markers()

func _cancel(emit_event := true) -> void:
	var was_active := _is_active()
	_clear_markers()
	_piece_index = -1
	_piece_id = ""
	_sale_price = 0
	_relocating_displayed_piece = false
	if emit_event and was_active:
		EventBus.display_slot_placement_state_changed.emit(false)
		EventBus.placement_state_changed.emit(false, "")

func _clear_markers() -> void:
	for marker in _markers:
		if is_instance_valid(marker):
			marker.queue_free()
	_markers.clear()

func _slot_local_position(slot: int) -> Vector3:
	return WatchDisplayController.get_slot_local_position(slot)

func _current_piece_index() -> int:
	for index in GameState.owned_pieces.size():
		if String(GameState.owned_pieces[index].get("id", "")) == _piece_id:
			return index
	return -1

func _is_active() -> bool:
	return _piece_index >= 0 or _relocating_displayed_piece

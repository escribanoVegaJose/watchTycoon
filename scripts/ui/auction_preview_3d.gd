extends SubViewportContainer

const ItemModelFraming = preload("res://scripts/presentation/item_model_framing.gd")

## Isolated, presentation-only turntable for an auction catalog piece.
## The imported GLB is framed from its real bounds, so Meshy exports with
## different scale or pivot positions remain visible in the auction UI.

@onready var _rig: Node3D = $AuctionViewport/Turntable
@onready var _camera: Camera3D = $AuctionViewport/Camera3D

var _yaw := 0.0
var _pitch := 0.0
var _distance := 5.0
var _dragging := false
var _interaction_enabled := true
var _model: Node3D
var _model_path := ""
var _item_type := "watch"
var _category := ""

func _ready() -> void:
	stretch = true
	# This viewport must render its isolated turntable rather than inheriting the
	# boutique world's active camera when the auction panel opens.
	_camera.make_current()
	set_interaction_enabled(_interaction_enabled)
	if _interaction_enabled:
		gui_input.connect(_on_gui_input)
	if not _model_path.is_empty():
		_set_model()

func set_model_path(model_path: String) -> void:
	_model_path = model_path
	if is_node_ready():
		_set_model()

## Metadata is optional to preserve previews created before jewelry was added.
func set_item_context(item_type: String, category: String = "") -> void:
	_item_type = item_type if not item_type.is_empty() else "watch"
	_category = category
	if is_node_ready() and is_instance_valid(_model):
		_frame_model()

## Compact inventory cards reuse this renderer as a static catalogue thumbnail.
## Disable input before adding it to a card so it cannot capture clicks, drags,
## or wheel events intended for the inventory scroll view.
func set_interaction_enabled(enabled: bool) -> void:
	_interaction_enabled = enabled
	mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	if enabled:
		add_to_group("interactive_3d_preview")
	else:
		remove_from_group("interactive_3d_preview")

func _set_model() -> void:
	if is_instance_valid(_model):
		_model.queue_free()
		_model = null
	var scene := ResourceLoader.load(_model_path) as PackedScene
	if scene == null:
		return
	_model = scene.instantiate() as Node3D
	_rig.add_child(_model)
	call_deferred("_frame_model")

func reset_view() -> void:
	_yaw = 0.0
	_pitch = 0.0
	_distance = 5.0
	_apply_view()

func zoom_in() -> void:
	_distance = maxf(1.8, _distance - 0.35)
	_apply_view()

func zoom_out() -> void:
	_distance = minf(7.0, _distance + 0.35)
	_apply_view()

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom_in()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom_out()
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_dragging = false
			return
		_yaw += event.relative.x * 0.45
		_pitch = clampf(_pitch + event.relative.y * 0.35, -55.0, 35.0)
		_apply_view()
		accept_event()

func _apply_view() -> void:
	_rig.rotation_degrees = Vector3(_pitch, _yaw, 0.0)
	_camera.position = Vector3(0.0, 0.0, _distance)
	_camera.look_at(Vector3.ZERO)

func _frame_model() -> void:
	if not is_instance_valid(_model):
		return
	var bounds := _get_model_bounds()
	if bounds.size == Vector3.ZERO:
		_apply_view()
		return
	var display_scale := ItemModelFraming.scale_to_fit(bounds, ItemModelFraming.preview_envelope(_item_type, _category))
	if display_scale > 0.001:
		# Fit real bounds into a type-aware editorial envelope. This avoids tying
		# framing to a brand or a particular exporter scale.
		display_scale = clampf(display_scale, 0.01, 10.0)
		_model.scale *= Vector3.ONE * display_scale
		_model.position -= bounds.get_center() * display_scale
	_apply_view()

func _get_model_bounds() -> AABB:
	var has_mesh := false
	var combined := AABB()
	var inverse_rig := _rig.global_transform.affine_inverse()
	for mesh in _find_meshes(_model):
		var relative_transform := inverse_rig * mesh.global_transform
		var mesh_bounds: AABB = _transform_aabb(mesh.get_aabb(), relative_transform)
		if not has_mesh:
			combined = mesh_bounds
			has_mesh = true
		else:
			combined = combined.merge(mesh_bounds)
	return combined

func _transform_aabb(bounds: AABB, transform: Transform3D) -> AABB:
	var transformed_bounds := AABB(transform * bounds.get_endpoint(0), Vector3.ZERO)
	for corner in range(1, 8):
		transformed_bounds = transformed_bounds.expand(transform * bounds.get_endpoint(corner))
	return transformed_bounds

func _find_meshes(node: Node) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		meshes.append(node)
	for child in node.get_children():
		meshes.append_array(_find_meshes(child))
	return meshes

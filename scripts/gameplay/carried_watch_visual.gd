extends Node3D

## Presentation-only model attached to the watchmaker; it never changes state.
var _model: Node3D

func _ready() -> void:
	EventBus.carried_watch_changed.connect(_on_carried_watch_changed)
	_refresh(GameState.carried_watch)

func _on_carried_watch_changed(watch: Dictionary) -> void:
	_refresh(watch)

func _refresh(watch: Dictionary) -> void:
	if is_instance_valid(_model):
		_model.queue_free()
	_model = null
	if watch.is_empty():
		return
	var model_path := String(watch.get("model_path", ""))
	var scene := ResourceLoader.load(model_path) as PackedScene if not model_path.is_empty() else null
	if scene == null:
		return
	_model = scene.instantiate() as Node3D
	if _model == null:
		return
	add_child(_model)
	_fit_model(_model)

func _fit_model(model: Node3D) -> void:
	var bounds := _get_bounds(model)
	var side := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	if side <= 0.001:
		return
	var factor := 0.16 / side
	model.scale = Vector3.ONE * factor
	model.position = -bounds.get_center() * factor

func _get_bounds(node: Node3D) -> AABB:
	var found := false
	var combined := AABB()
	for mesh in _find_meshes(node):
		var bounds := _transform_aabb(mesh.get_aabb(), node.global_transform.affine_inverse() * mesh.global_transform)
		if found:
			combined = combined.merge(bounds)
		else:
			combined = bounds
			found = true
	return combined

func _transform_aabb(bounds: AABB, transform: Transform3D) -> AABB:
	var result := AABB(transform * bounds.get_endpoint(0), Vector3.ZERO)
	for corner in range(1, 8):
		result = result.expand(transform * bounds.get_endpoint(corner))
	return result

func _find_meshes(node: Node) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		meshes.append(node)
	for child in node.get_children():
		meshes.append_array(_find_meshes(child))
	return meshes

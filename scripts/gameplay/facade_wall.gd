class_name FacadeWall
extends Node3D

## Procedural masonry and placement collision for one façade wall. Coordinates for
## openings are local: x follows horizontal_axis and y is relative to wall centre.
@export var wall_id := ""
@export var horizontal_axis := Vector3.RIGHT
@export var interior_normal := Vector3.FORWARD
@export var half_width := 1.0
@export var half_height := 2.1
@export var thickness := 0.32
@export var wall_material: Material
@export var door_opening := Rect2()
@export var has_door_opening := false
@export var placement_inset := 0.3

const EPSILON := 0.001
const ENTRANCE_CLICK_BLOCKER_LAYER := 16

var _finish_material: StandardMaterial3D

## Every wall owns a duplicated material so selecting an finish never recolours
## the other walls that share the base plaster resource.
func set_finish_color(color: Color) -> void:
	if _finish_material == null:
		_finish_material = wall_material.duplicate() as StandardMaterial3D
	if _finish_material == null:
		return
	_finish_material.albedo_color = color
	for mesh_instance in _get_wall_meshes(self):
		mesh_instance.material_override = _finish_material

func rebuild(installations: Array[Dictionary]) -> void:
	_clear_generated()
	var openings := _get_openings(installations)
	_ensure_placement_surface()
	_ensure_entrance_click_blocker()
	var x_edges: Array[float] = [-half_width, half_width]
	var y_edges: Array[float] = [-half_height, half_height]
	for opening in openings:
		x_edges.append(opening.position.x)
		x_edges.append(opening.end.x)
		y_edges.append(opening.position.y)
		y_edges.append(opening.end.y)
	x_edges.sort()
	y_edges.sort()
	x_edges = _unique_edges(x_edges)
	y_edges = _unique_edges(y_edges)
	var meshes := Node3D.new()
	meshes.name = "ProceduralSegments"
	add_child(meshes)
	for x_index in range(x_edges.size() - 1):
		for y_index in range(y_edges.size() - 1):
			var minimum := Vector2(x_edges[x_index], y_edges[y_index])
			var maximum := Vector2(x_edges[x_index + 1], y_edges[y_index + 1])
			var size := maximum - minimum
			if size.x <= EPSILON or size.y <= EPSILON or _cell_is_open(minimum + size * 0.5, openings):
				continue
			_add_segment(meshes, minimum + size * 0.5, size)

func _get_openings(installations: Array[Dictionary]) -> Array[Rect2]:
	var openings: Array[Rect2] = []
	if has_door_opening:
		# The entrance rectangle is deliberately retained verbatim.
		openings.append(door_opening)
	for installation in installations:
		if String(installation.get("wall_id", "")) != wall_id:
			continue
		var half_opening_width := float(installation.get("opening_half_width", 0.0))
		var half_opening_height := float(installation.get("opening_half_height", 0.0))
		var transform_data: Dictionary = installation.get("transform", {})
		var origin: Array = transform_data.get("origin", [])
		if half_opening_width <= 0.0 or half_opening_height <= 0.0 or origin.size() != 3:
			continue
		var local_origin := to_local(Vector3(float(origin[0]), float(origin[1]), float(origin[2])))
		var centre := Vector2(local_origin.dot(horizontal_axis.normalized()), local_origin.y)
		var opening := Rect2(centre - Vector2(half_opening_width, half_opening_height), Vector2(half_opening_width * 2.0, half_opening_height * 2.0))
		var wall_bounds := Rect2(Vector2(-half_width, -half_height), Vector2(half_width * 2.0, half_height * 2.0))
		var clipped := opening.intersection(wall_bounds)
		if clipped.size.x > EPSILON and clipped.size.y > EPSILON:
			openings.append(clipped)
	return openings

func _add_segment(meshes: Node3D, centre: Vector2, size: Vector2) -> void:
	var segment_transform := Transform3D(Basis(horizontal_axis.normalized(), Vector3.UP, horizontal_axis.normalized().cross(Vector3.UP)), horizontal_axis.normalized() * centre.x + Vector3.UP * centre.y)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "WallSegment"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size.x, size.y, thickness)
	mesh_instance.mesh = mesh
	mesh_instance.transform = segment_transform
	mesh_instance.material_override = _finish_material if _finish_material != null else wall_material
	meshes.add_child(mesh_instance)
	var solid_body := StaticBody3D.new()
	solid_body.name = "WallSolid"
	solid_body.collision_layer = 8 # WorldSolid: blocks characters, not placement rays.
	solid_body.collision_mask = 0
	solid_body.transform = segment_transform
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x, size.y, thickness)
	collision.shape = shape
	solid_body.add_child(collision)
	meshes.add_child(solid_body)

func _ensure_placement_surface() -> void:
	var placement := get_node_or_null("PlacementSurface") as PlacementWall
	if placement == null:
		placement = PlacementWall.new()
		placement.name = "PlacementSurface"
		placement.collision_layer = 2
		placement.collision_mask = 0
		add_child(placement)
	var horizontal := horizontal_axis.normalized()
	# Windows on the entrance façade are mounted on its street-facing side.
	var placement_normal := -interior_normal.normalized() if has_door_opening else interior_normal.normalized()
	placement.transform = Transform3D(Basis(horizontal, Vector3.UP, horizontal.cross(Vector3.UP)), placement_normal * (thickness * 0.5 + EPSILON))
	placement.wall_id = wall_id
	placement.interior_normal = placement_normal
	placement.is_exterior_entrance_wall = has_door_opening
	placement.local_horizontal_axis = Vector3.RIGHT
	placement.usable_half_width = maxf(0.0, half_width - placement_inset)
	placement.local_horizontal_center = 0.0
	placement.min_mount_height = placement.global_position.y - half_height + placement_inset
	placement.max_mount_height = placement.global_position.y + half_height - placement_inset
	# The entrance is absent from both the visible masonry and the raycast plane.
	var excluded_openings: Array[Rect2] = []
	if has_door_opening:
		excluded_openings.append(door_opening)
	placement.set_excluded_openings(excluded_openings, half_width, half_height)

## The doorway is not walkable UI: clicks through its visual opening must not
## become floor destinations. This collider lives on a dedicated query layer,
## so it neither blocks characters nor alters wall/window placement.
func _ensure_entrance_click_blocker() -> void:
	var blocker := get_node_or_null("EntranceClickBlocker") as StaticBody3D
	if not has_door_opening or door_opening.size.x <= EPSILON or door_opening.size.y <= EPSILON:
		if blocker != null:
			blocker.free()
		return
	if blocker == null:
		blocker = StaticBody3D.new()
		blocker.name = "EntranceClickBlocker"
		blocker.collision_layer = ENTRANCE_CLICK_BLOCKER_LAYER
		blocker.collision_mask = 0
		# WorldClickController uses this explicit marker after its blocker raycast.
		blocker.set_meta("blocks_world_click", true)
		var collision := CollisionShape3D.new()
		collision.name = "CollisionShape3D"
		blocker.add_child(collision)
		add_child(blocker)
	var horizontal := horizontal_axis.normalized()
	var centre := door_opening.get_center()
	blocker.transform = Transform3D(
		Basis(horizontal, Vector3.UP, horizontal.cross(Vector3.UP)),
		horizontal * centre.x + Vector3.UP * centre.y
	)
	var collision := blocker.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision != null:
		var shape := BoxShape3D.new()
		shape.size = Vector3(door_opening.size.x, door_opening.size.y, 0.02)
		collision.shape = shape

func _cell_is_open(point: Vector2, openings: Array[Rect2]) -> bool:
	for opening in openings:
		if opening.has_point(point):
			return true
	return false

func _unique_edges(edges: Array[float]) -> Array[float]:
	var result: Array[float] = []
	for edge in edges:
		if result.is_empty() or absf(edge - result.back()) > EPSILON:
			result.append(edge)
	return result

func _get_wall_meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		result.append(node as MeshInstance3D)
	for child in node.get_children():
		result.append_array(_get_wall_meshes(child))
	return result

func _clear_generated() -> void:
	for child_name in ["ProceduralSegments"]:
		var child := get_node_or_null(child_name)
		if child != null:
			child.free()

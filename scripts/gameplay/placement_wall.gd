class_name PlacementWall
extends StaticBody3D

@export var wall_id: String = ""
@export var wall_tags := PackedStringArray(["interior_wall"])
@export var interior_normal := Vector3.FORWARD
## Set by FacadeWall for the wall containing the main entrance. Its placement
## surface is mounted on the exterior side only.
var is_exterior_entrance_wall := false
@export var local_horizontal_axis := Vector3.RIGHT
@export var usable_half_width := 1.0
@export var local_horizontal_center := 0.0
@export var min_mount_height := 0.3
@export var max_mount_height := 3.9
var excluded_openings: Array[Rect2] = []

const EPSILON := 0.001

## Build the raycast surface as wall cells so an entrance opening has no
## placement collider at all, rather than merely being hidden visually.
func set_excluded_openings(openings: Array[Rect2], wall_half_width: float, wall_half_height: float) -> void:
	excluded_openings.clear()
	var bounds := Rect2(Vector2(-wall_half_width, -wall_half_height), Vector2(wall_half_width * 2.0, wall_half_height * 2.0))
	for opening in openings:
		var clipped := opening.intersection(bounds)
		if clipped.size.x > EPSILON and clipped.size.y > EPSILON:
			excluded_openings.append(clipped)
	_rebuild_collision_shapes(bounds)

func is_point_in_excluded_opening(world_position: Vector3) -> bool:
	var local_position := to_local(world_position)
	var point := Vector2(local_position.x, local_position.y)
	for opening in excluded_openings:
		if opening.grow(EPSILON).has_point(point):
			return true
	return false

func overlaps_excluded_opening(transform: Transform3D, definition: PlaceableDefinition) -> bool:
	var local_position := to_local(transform.origin)
	var footprint := Rect2(
		Vector2(local_position.x - definition.placement_half_width, local_position.y - definition.placement_half_height),
		Vector2(definition.placement_half_width * 2.0, definition.placement_half_height * 2.0)
	)
	for opening in excluded_openings:
		if footprint.intersects(opening.grow(EPSILON)):
			return true
	return false

func _rebuild_collision_shapes(bounds: Rect2) -> void:
	for child in get_children():
		# PlacementWall owns only its raycast shapes. Removing every old shape also
		# migrates scenes saved before openings were excluded from this collider.
		if child is CollisionShape3D:
			child.free()
	var x_edges: Array[float] = [bounds.position.x, bounds.end.x]
	var y_edges: Array[float] = [bounds.position.y, bounds.end.y]
	for opening in excluded_openings:
		x_edges.append(opening.position.x)
		x_edges.append(opening.end.x)
		y_edges.append(opening.position.y)
		y_edges.append(opening.end.y)
	x_edges.sort()
	y_edges.sort()
	for x_index in range(x_edges.size() - 1):
		for y_index in range(y_edges.size() - 1):
			var minimum := Vector2(x_edges[x_index], y_edges[y_index])
			var size := Vector2(x_edges[x_index + 1], y_edges[y_index + 1]) - minimum
			if size.x <= EPSILON or size.y <= EPSILON or _is_excluded(minimum + size * 0.5):
				continue
			var collision := CollisionShape3D.new()
			collision.position = Vector3(minimum.x + size.x * 0.5, minimum.y + size.y * 0.5, 0.0)
			var shape := BoxShape3D.new()
			shape.size = Vector3(size.x, size.y, 0.02)
			collision.shape = shape
			add_child(collision)

func _is_excluded(point: Vector2) -> bool:
	for opening in excluded_openings:
		if opening.has_point(point):
			return true
	return false

func accepts(definition: PlaceableDefinition) -> bool:
	for tag in definition.compatible_wall_tags:
		if wall_tags.has(tag):
			return true
	return false

func get_mount_transform(hit_position: Vector3, definition: PlaceableDefinition) -> Transform3D:
	var local_hit := to_local(hit_position)
	var horizontal := local_hit.dot(local_horizontal_axis)
	var safe_half_width := maxf(0.0, usable_half_width - definition.placement_half_width)
	horizontal = clampf(horizontal, local_horizontal_center - safe_half_width, local_horizontal_center + safe_half_width)
	local_hit = local_horizontal_axis * horizontal
	local_hit.y = clampf(hit_position.y, min_mount_height + definition.placement_half_height, max_mount_height - definition.placement_half_height) - global_position.y
	var mount_position := to_global(local_hit) + interior_normal.normalized() * definition.wall_surface_offset
	var basis := Basis.looking_at(interior_normal.normalized(), Vector3.UP)
	return Transform3D(basis, mount_position)

func overlaps_existing(transform: Transform3D, definition: PlaceableDefinition, installations: Array) -> bool:
	var candidate_local := to_local(transform.origin)
	var candidate_horizontal := candidate_local.dot(local_horizontal_axis)
	for installation_variant in installations:
		var installation: Dictionary = installation_variant
		if String(installation.get("wall_id", "")) != wall_id:
			continue
		var transform_data: Dictionary = installation.get("transform", {})
		var origin_values: Array = transform_data.get("origin", [])
		if origin_values.size() != 3:
			continue
		var existing_position := Vector3(float(origin_values[0]), float(origin_values[1]), float(origin_values[2]))
		var existing_local := to_local(existing_position)
		var existing_horizontal := existing_local.dot(local_horizontal_axis)
		var footprint: Dictionary = installation.get("footprint", {})
		var existing_half_width := float(footprint.get("half_width", definition.placement_half_width))
		var existing_half_height := float(footprint.get("half_height", definition.placement_half_height))
		var horizontal_overlap := absf(candidate_horizontal - existing_horizontal) < definition.placement_half_width + existing_half_width + 0.16
		var vertical_overlap := absf(candidate_local.y - existing_local.y) < definition.placement_half_height + existing_half_height + 0.16
		if horizontal_overlap and vertical_overlap:
			return true
	return false

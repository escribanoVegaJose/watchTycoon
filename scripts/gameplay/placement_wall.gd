class_name PlacementWall
extends StaticBody3D

@export var wall_id: String = ""
@export var wall_tags := PackedStringArray(["interior_wall"])
@export var interior_normal := Vector3.FORWARD
@export var local_horizontal_axis := Vector3.RIGHT
@export var usable_half_width := 1.0
@export var local_horizontal_center := 0.0
@export var min_mount_height := 0.3
@export var max_mount_height := 3.9

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

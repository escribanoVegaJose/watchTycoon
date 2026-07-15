extends Node3D

## Presentation-only selection feedback. It listens to the shared world selection
## event and draws a restrained gold outline without coupling gameplay to the HUD.

@export var back_wall_path: NodePath
@export var front_wall_path: NodePath
@export var left_wall_path: NodePath
@export var right_wall_path: NodePath

const GOLD := Color(0.95, 0.70, 0.22, 1.0)

var _selected_type := ""
var _selected_id := ""
var _outline: MeshInstance3D
var _outline_material: StandardMaterial3D

func _ready() -> void:
	_outline = MeshInstance3D.new()
	_outline.name = "SelectionOutline"
	_outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_outline_material = StandardMaterial3D.new()
	_outline_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_outline_material.albedo_color = GOLD
	_outline_material.emission_enabled = true
	_outline_material.emission = GOLD
	_outline_material.emission_energy_multiplier = 0.35
	_outline.material_override = _outline_material
	_outline.visible = false
	add_child(_outline)
	EventBus.world_selection_changed.connect(_on_world_selection_changed)
	EventBus.facade_installation_added.connect(_refresh_if_needed)
	EventBus.facade_installation_updated.connect(_refresh_if_needed)
	EventBus.facade_installation_removed.connect(_refresh_if_needed)
	EventBus.facility_installation_added.connect(_refresh_if_needed)
	EventBus.facility_installation_updated.connect(_refresh_if_needed)
	EventBus.facility_installation_removed.connect(_refresh_if_needed)

func _on_world_selection_changed(selection_type: String, selection_id: String, _anchor: Vector3) -> void:
	_selected_type = selection_type
	_selected_id = selection_id
	_refresh_outline()

func _refresh_if_needed(_unused = null, _also_unused = null) -> void:
	if not _selected_id.is_empty():
		call_deferred("_refresh_outline")

func _refresh_outline() -> void:
	var target := _get_selected_target()
	if target == null or not is_instance_valid(target):
		_outline.visible = false
		return
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var found_mesh := false
	if _selected_type == "wall":
		# Each procedural segment receives its own outline, preserving door/window gaps.
		for child in _mesh_children(target):
			_add_mesh_bounds(mesh, child)
			found_mesh = true
	else:
		var bounds := _combined_bounds(target)
		if bounds.size.length_squared() > 0.0:
			_add_box(mesh, bounds)
			found_mesh = true
	mesh.surface_end()
	_outline.mesh = mesh
	_outline.visible = found_mesh

func _get_selected_target() -> Node3D:
	if _selected_type == "wall":
		var paths := {"back": back_wall_path, "front": front_wall_path, "left": left_wall_path, "right": right_wall_path}
		return get_node_or_null(paths.get(_selected_id, NodePath())) as Node3D
	if _selected_type != "window" and _selected_type != "facility" and _selected_type != "displayed_watch" and _selected_type != "customer":
		return null
	var group := "world_selectable_%s" % _selected_type
	for candidate in get_tree().get_nodes_in_group(group):
		if candidate is Node3D and String(candidate.get_meta("selection_id", "")) == _selected_id:
			return candidate as Node3D
	return null

func _mesh_children(root: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if root is MeshInstance3D and (root as MeshInstance3D).mesh != null:
		result.append(root as MeshInstance3D)
	for child in root.get_children():
		result.append_array(_mesh_children(child))
	return result

func _combined_bounds(target: Node3D) -> AABB:
	var has_bounds := false
	var result := AABB()
	for child in _mesh_children(target):
		var child_bounds := _bounds_in_outline_space(child)
		if not has_bounds:
			result = child_bounds
			has_bounds = true
		else:
			result = result.merge(child_bounds)
	return result

func _add_mesh_bounds(line_mesh: ImmediateMesh, mesh_instance: MeshInstance3D) -> void:
	_add_box(line_mesh, _bounds_in_outline_space(mesh_instance))

func _bounds_in_outline_space(mesh_instance: MeshInstance3D) -> AABB:
	var source := mesh_instance.get_aabb()
	var result := AABB()
	var has_point := false
	for x in [source.position.x, source.end.x]:
		for y in [source.position.y, source.end.y]:
			for z in [source.position.z, source.end.z]:
				var point := to_local(mesh_instance.to_global(Vector3(x, y, z)))
				if not has_point:
					result.position = point
					has_point = true
				else:
					result = result.expand(point)
	return result.grow(0.018)

func _add_box(line_mesh: ImmediateMesh, bounds: AABB) -> void:
	var p := bounds.position
	var e := bounds.end
	var corners := [Vector3(p.x, p.y, p.z), Vector3(e.x, p.y, p.z), Vector3(e.x, e.y, p.z), Vector3(p.x, e.y, p.z), Vector3(p.x, p.y, e.z), Vector3(e.x, p.y, e.z), Vector3(e.x, e.y, e.z), Vector3(p.x, e.y, e.z)]
	for edge in [[0, 1], [1, 2], [2, 3], [3, 0], [4, 5], [5, 6], [6, 7], [7, 4], [0, 4], [1, 5], [2, 6], [3, 7]]:
		line_mesh.surface_add_vertex(corners[edge[0]])
		line_mesh.surface_add_vertex(corners[edge[1]])

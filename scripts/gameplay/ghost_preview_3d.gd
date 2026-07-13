class_name GhostPreview3D
extends Node3D

var _ghost_material: StandardMaterial3D

func set_visual(visual: Node3D) -> void:
	add_child(visual)
	_apply_material(visual)

func set_valid(is_valid: bool) -> void:
	if _ghost_material == null:
		return
	_ghost_material.albedo_color = Color(0.83, 0.63, 0.17, 0.58) if is_valid else Color(0.82, 0.12, 0.1, 0.62)

func _apply_material(root: Node) -> void:
	if _ghost_material == null:
		_ghost_material = StandardMaterial3D.new()
		_ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ghost_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_ghost_material.albedo_color = Color(0.83, 0.63, 0.17, 0.58)
	if root is MeshInstance3D:
		(root as MeshInstance3D).material_override = _ghost_material
	for child in root.get_children():
		_apply_material(child)

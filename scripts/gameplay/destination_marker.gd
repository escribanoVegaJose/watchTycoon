class_name DestinationMarker
extends Node3D

const GOLD := Color(0.92, 0.68, 0.22, 0.9)

var _mesh: MeshInstance3D
var _base_scale := Vector3.ONE

func _ready() -> void:
	top_level = true
	_mesh = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.22
	ring.outer_radius = 0.34
	ring.rings = 24
	ring.ring_segments = 8
	_mesh.mesh = ring
	var material := StandardMaterial3D.new()
	material.albedo_color = GOLD
	material.emission_enabled = true
	material.emission = GOLD
	material.emission_energy_multiplier = 1.4
	material.roughness = 0.3
	_mesh.material_override = material
	add_child(_mesh)
	visible = false

func show_at(destination: Vector3) -> void:
	global_position = destination + Vector3.UP * 0.025
	visible = true
	_base_scale = Vector3.ONE
	scale = _base_scale * 1.25
	var tween := create_tween()
	tween.tween_property(self, "scale", _base_scale, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func clear() -> void:
	visible = false

func _process(delta: float) -> void:
	if not visible:
		return
	rotation.y += TimeManager.get_simulation_delta(delta) * 1.8

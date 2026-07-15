class_name FacadeOpeningsController
extends Node

## Translates saved installation data into façade openings without coupling either
## the placement UI or GameState to procedural scene nodes.
@export var wall_paths: Array[NodePath]
@export var placeable_definitions: Array[PlaceableDefinition]
## Scene-authored openings are starter architecture, rather than purchases in a save.
@export var default_opening_paths: Array[NodePath]

func _ready() -> void:
	EventBus.facade_installation_added.connect(_on_facade_changed)
	EventBus.facade_installation_updated.connect(_on_facade_changed)
	EventBus.facade_installation_removed.connect(_on_facade_removed)
	EventBus.facade_installations_reloaded.connect(rebuild)
	call_deferred("rebuild")

func rebuild(_ignored: Variant = null) -> void:
	var opening_definitions: Dictionary = {}
	for definition in placeable_definitions:
		if definition != null and definition.creates_wall_opening:
			opening_definitions[definition.item_id] = definition
	var openings: Array[Dictionary] = _get_default_openings()
	for installation in GameState.get_facade_installations():
		var definition: PlaceableDefinition = opening_definitions.get(String(installation.get("item_id", "")))
		if definition != null:
			# An aperture can be narrower than the exterior frame. Keep this derived
			# from the definition so older saves are repaired without changing their
			# serialized transforms.
			var opening := installation.duplicate(true)
			opening["opening_half_width"] = definition.opening_half_width if definition.opening_half_width > 0.0 else definition.placement_half_width
			opening["opening_half_height"] = definition.opening_half_height if definition.opening_half_height > 0.0 else definition.placement_half_height
			openings.append(opening)
	for path in wall_paths:
		var wall := get_node_or_null(path) as FacadeWall
		if wall != null:
			wall.rebuild(openings)

func _get_default_openings() -> Array[Dictionary]:
	var openings: Array[Dictionary] = []
	for path in default_opening_paths:
		var window := get_node_or_null(path) as FacadeDefaultWindow
		if window != null and not window.wall_id.is_empty():
			openings.append(window.get_opening_data())
	return openings

func _on_facade_changed(_installation: Dictionary) -> void:
	rebuild()

func _on_facade_removed(_installation_id: String, _refund: int) -> void:
	rebuild()

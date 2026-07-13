class_name PlaceableDefinition
extends Resource

@export var item_id: String = ""
@export var display_name: String = ""
@export var price: int = 0
@export var visual_scene: PackedScene
@export var visual_scale := Vector3.ONE
@export var compatible_wall_tags := PackedStringArray(["interior_wall"])
## Half extents used for safe wall bounds and overlap validation.
@export var placement_half_width := 1.0
@export var placement_half_height := 1.4
@export var wall_surface_offset := 0.19

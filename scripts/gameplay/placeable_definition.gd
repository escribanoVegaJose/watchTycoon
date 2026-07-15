class_name PlaceableDefinition
extends Resource

@export var item_id: String = ""
@export var display_name: String = ""
## Icon used by compact catalog cards. It does not affect placement behaviour.
@export var catalog_icon: Texture2D
@export var price: int = 0
@export var visual_scene: PackedScene
@export var visual_scale := Vector3.ONE
@export var compatible_wall_tags := PackedStringArray(["interior_wall"])
## Half extents of the installed visual, including its frame. They are the
## source of truth for placement bounds and collisions.
@export var placement_half_width := 1.0
@export var placement_half_height := 1.4
## Optional clear aperture in the wall. Leave at zero to use the full visual
## footprint, which preserves the previous behaviour for existing placeables.
@export var opening_half_width := 0.0
@export var opening_half_height := 0.0
@export var wall_surface_offset := 0.19
## Only façade elements with this flag cut a procedural wall opening.
@export var creates_wall_opening := false

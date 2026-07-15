class_name FacadeDefaultWindow
extends Node3D

## A scene-authored façade window. It is intentionally not part of GameState:
## starter architecture must neither cost money nor become selectable furniture.
@export var wall_id := ""
@export var opening_half_width := 0.75
@export var opening_half_height := 0.75

func get_opening_data() -> Dictionary:
	return {
		"wall_id": wall_id,
		"transform": TransformSerialization.serialize(global_transform),
		"opening_half_width": opening_half_width,
		"opening_half_height": opening_half_height,
	}

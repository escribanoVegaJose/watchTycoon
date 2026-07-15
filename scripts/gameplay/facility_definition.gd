class_name FacilityDefinition
extends Resource

## Floor-placeable shop infrastructure. Kept distinct from façade definitions
## so facilities never inherit wall openings or wall compatibility rules.
@export var item_id: String = ""
@export var display_name: String = ""
@export_multiline var catalog_description := ""
@export var catalog_icon: Texture2D
@export var price: int = 0
@export var visual_scene: PackedScene
@export var visual_scale := Vector3.ONE
## Offset from the model pivot to the floor. Imported GLBs often use a centred pivot.
@export var floor_offset := 0.0
@export var footprint_half_extents := Vector2(1.0, 0.5)
## Zero means unlimited. The initial point of sale is a unique facility.
@export var max_installations := 0

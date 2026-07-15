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
## Physical display layout in the facility visual's local space. Each entry keeps
## a stable slot_id so saved placements remain meaningful if the layout evolves.
## Required keys: slot_id (String), position (Vector3), scale (Vector3).
@export var display_slots: Array[Dictionary] = []

func is_display_facility() -> bool:
	return not display_slots.is_empty()

func get_display_slot(slot_index: int) -> Dictionary:
	return display_slots[slot_index].duplicate(true) if slot_index >= 0 and slot_index < display_slots.size() else {}

func get_display_slot_id(slot_index: int) -> String:
	return String(get_display_slot(slot_index).get("slot_id", ""))

func get_display_slot_index(slot_id: String) -> int:
	for index in range(display_slots.size()):
		if String(display_slots[index].get("slot_id", "")) == slot_id:
			return index
	return -1

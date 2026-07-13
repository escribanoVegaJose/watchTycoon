class_name ConstructionSlot
extends Node3D

## Ranura fija de fachada. El menú instalará en estas ranuras, nunca recortará
## paredes ni colocará modelos libremente durante el alcance inicial.
@export var slot_id := ""
@export_enum("door_standard", "window_standard") var slot_type := "window_standard"
@export var installed_item_id := ""
@export var is_installed := true
@export var visual_path: NodePath
@export var daylight_proxy_path: NodePath

@onready var visual: Node3D = get_node_or_null(visual_path) as Node3D
@onready var daylight_proxy: Node3D = get_node_or_null(daylight_proxy_path) as Node3D

func _ready() -> void:
	_apply_installation_state()

func accepts(slot_type_to_check: String) -> bool:
	return slot_type == slot_type_to_check

func set_installation(item_id: String, enabled: bool) -> void:
	installed_item_id = item_id if enabled else ""
	is_installed = enabled
	_apply_installation_state()

func _apply_installation_state() -> void:
	if visual != null:
		visual.visible = is_installed
	if daylight_proxy != null:
		daylight_proxy.visible = is_installed

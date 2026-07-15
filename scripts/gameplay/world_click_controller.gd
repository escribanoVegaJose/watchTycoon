extends Node

@export var camera_path: NodePath
@export var watchmaker_path: NodePath
@export var walkable_collision_mask := 1
@export var entrance_click_blocker_collision_mask := 16

@onready var _camera: Camera3D = get_node(camera_path) as Camera3D
@onready var _watchmaker: WatchmakerPlayer = get_node(watchmaker_path) as WatchmakerPlayer

var _placement_active := false
var _display_slot_placement_active := false

func _ready() -> void:
	EventBus.placement_state_changed.connect(_on_placement_state_changed)
	EventBus.display_slot_placement_state_changed.connect(_on_display_slot_placement_state_changed)

func _unhandled_input(event: InputEvent) -> void:
	# A watch chooses a fixed vitrina slot with left click, so right click may
	# still send the watchmaker walking while that mode is open.
	if _placement_active and not _display_slot_placement_active:
		return
	if TimeManager.is_paused:
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
		return
	var origin := _camera.project_ray_origin(get_viewport().get_mouse_position())
	var end := origin + _camera.project_ray_normal(get_viewport().get_mouse_position()) * 100.0
	var blocker_query := PhysicsRayQueryParameters3D.create(origin, end, entrance_click_blocker_collision_mask)
	var blocker_hit := _camera.get_world_3d().direct_space_state.intersect_ray(blocker_query)
	if not blocker_hit.is_empty() and _is_world_click_blocker(blocker_hit.collider):
		# Consume only the dedicated entrance aperture blocker. Do not set a
		# destination or trigger any world interaction behind the doorway.
		get_viewport().set_input_as_handled()
		return
	var query := PhysicsRayQueryParameters3D.create(origin, end, walkable_collision_mask)
	var hit := _camera.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	_watchmaker.set_destination(hit.position)
	get_viewport().set_input_as_handled()

func _on_placement_state_changed(active: bool, _item_name: String) -> void:
	_placement_active = active

func _on_display_slot_placement_state_changed(active: bool) -> void:
	_display_slot_placement_active = active

func _is_world_click_blocker(collider: Object) -> bool:
	return collider != null and collider.has_meta("blocks_world_click") and bool(collider.get_meta("blocks_world_click"))

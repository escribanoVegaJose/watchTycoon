extends Node

## World interaction only: it selects a nearby display; GameState owns the transfer.
@export var watchmaker_path: NodePath
@export var deposit_distance := 2.4

@onready var _watchmaker: Node3D = get_node(watchmaker_path) as Node3D
var _placement_active := false

func _ready() -> void:
	EventBus.placement_state_changed.connect(_on_placement_state_changed)

func _unhandled_input(event: InputEvent) -> void:
	if _placement_active or TimeManager.is_paused or _is_commerce_open() or not event.is_action_pressed("deposit_watch"):
		return
	if GameState.carried_watch.is_empty():
		return
	var counter_id := _nearest_display_counter_id()
	if counter_id.is_empty():
		EventBus.feedback_requested.emit("Acércate a una vitrina instalada para depositar el reloj.", "info")
		get_viewport().set_input_as_handled()
		return
	var price := int(GameState.carried_watch.get("sale_price", 0))
	if GameState.deposit_carried_watch(counter_id, price):
		EventBus.feedback_requested.emit("Reloj depositado en la vitrina por %d €." % price, "info")
	else:
		EventBus.feedback_requested.emit("No se pudo depositar el reloj: revisa el precio y los huecos de la vitrina.", "error")
	get_viewport().set_input_as_handled()

func _nearest_display_counter_id() -> String:
	var closest_id := ""
	var closest_distance := deposit_distance * deposit_distance
	for installation in GameState.get_facility_installations():
		if String(installation.get("item_id", "")) != "display_counter_01":
			continue
		var transform_data: Dictionary = installation.get("transform", {})
		var origin: Variant = transform_data.get("origin", [])
		if not origin is Array or origin.size() != 3:
			continue
		var position := Vector3(float(origin[0]), float(origin[1]), float(origin[2]))
		var distance := _watchmaker.global_position.distance_squared_to(position)
		if distance <= closest_distance:
			closest_distance = distance
			closest_id = String(installation.get("installation_id", ""))
	return closest_id

func _on_placement_state_changed(active: bool, _item_name: String) -> void:
	_placement_active = active

func _is_commerce_open() -> bool:
	for panel_group in ["commerce_panel", "inventory_panel"]:
		for panel in get_tree().get_nodes_in_group(panel_group):
			if panel is CanvasItem and (panel as CanvasItem).visible:
				return true
	return false

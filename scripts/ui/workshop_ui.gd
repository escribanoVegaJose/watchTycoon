extends Node3D

@onready var money_label: Label = %MoneyLabel
@onready var furniture_panel: PanelContainer = %FurniturePanel
@onready var furniture_button: Button = %FurnitureButton
@onready var buy_window_button: Button = %BuyWindowButton
@onready var furniture_status_label: Label = %FurnitureStatusLabel
@onready var placement_bar: PanelContainer = %PlacementBar
@onready var placement_instruction_label: Label = %PlacementInstructionLabel
@onready var cancel_placement_button: Button = %CancelPlacementButton
@onready var window_context_panel: PanelContainer = %WindowContextPanel
@onready var move_window_button: Button = %MoveWindowButton
@onready var demolish_window_button: Button = %DemolishWindowButton
@onready var demolition_confirm_panel: PanelContainer = %DemolitionConfirmPanel
@onready var confirm_demolish_button: Button = %ConfirmDemolishButton
@onready var cancel_demolish_button: Button = %CancelDemolishButton
@onready var wall_palette_panel: PanelContainer = %WallPalettePanel
@onready var apply_finish_button: Button = %ApplyFinishButton
@onready var cancel_finish_button: Button = %CancelFinishButton
var _selected_window_id := ""
var _selected_wall_id := ""
var _selected_finish_id := "ivory"

func _ready() -> void:
	EventBus.stats_changed.connect(_on_stats_changed)
	EventBus.placement_state_changed.connect(_on_placement_state_changed)
	EventBus.placement_preview_changed.connect(_on_placement_preview_changed)
	EventBus.feedback_requested.connect(_on_feedback_requested)
	EventBus.world_selection_changed.connect(_on_world_selection_changed)
	furniture_button.pressed.connect(_on_furniture_pressed)
	buy_window_button.pressed.connect(_on_buy_window_pressed)
	cancel_placement_button.pressed.connect(_on_cancel_placement_pressed)
	move_window_button.pressed.connect(_on_move_window_pressed)
	demolish_window_button.pressed.connect(_on_demolish_window_pressed)
	confirm_demolish_button.pressed.connect(_on_confirm_demolish_pressed)
	cancel_demolish_button.pressed.connect(_on_cancel_demolish_pressed)
	apply_finish_button.pressed.connect(_on_apply_finish_pressed)
	cancel_finish_button.pressed.connect(_on_cancel_finish_pressed)
	for button in get_tree().get_nodes_in_group("wall_finish_buttons"):
		(button as Button).pressed.connect(_on_finish_pressed.bind(String(button.get_meta("finish_id"))))
	furniture_panel.visible = false
	placement_bar.visible = false
	window_context_panel.visible = false
	demolition_confirm_panel.visible = false
	wall_palette_panel.visible = false
	_on_stats_changed(GameState.money, GameState.reputation)

func _on_stats_changed(money: int, _reputation: int) -> void:
	money_label.text = _format_money(money)

func _on_furniture_pressed() -> void:
	furniture_panel.visible = not furniture_panel.visible

func _on_buy_window_pressed() -> void:
	EventBus.facade_item_selected.emit("window_wood_01")

func _on_cancel_placement_pressed() -> void:
	EventBus.placement_cancel_requested.emit()

func _on_placement_state_changed(active: bool, item_name: String) -> void:
	placement_bar.visible = active
	if active:
		furniture_panel.visible = false
		placement_instruction_label.text = "%s · apunta a una pared interior" % item_name
		placement_instruction_label.modulate = Color(0.95, 0.78, 0.35, 1.0)
	else:
		furniture_status_label.text = "Selecciona una ventana para colocarla sobre una pared interior."
		furniture_status_label.modulate = Color.WHITE

func _on_placement_preview_changed(is_valid: bool, message: String) -> void:
	if not placement_bar.visible:
		return
	placement_instruction_label.text = message + " · Esc o clic derecho para cancelar"
	placement_instruction_label.modulate = Color(0.95, 0.78, 0.35, 1.0) if is_valid else Color(1.0, 0.38, 0.32, 1.0)

func _on_feedback_requested(message: String, severity: String) -> void:
	furniture_status_label.text = message
	furniture_status_label.modulate = Color(1.0, 0.38, 0.32, 1.0) if severity == "error" else Color.WHITE

func _on_world_selection_changed(selection_type: String, selection_id: String) -> void:
	window_context_panel.visible = selection_type == "window"
	wall_palette_panel.visible = selection_type == "wall"
	demolition_confirm_panel.visible = false
	_selected_window_id = selection_id if selection_type == "window" else ""
	_selected_wall_id = selection_id if selection_type == "wall" else ""
	if selection_type == "wall":
		_selected_finish_id = GameState.get_wall_finish(selection_id)

func _on_move_window_pressed() -> void:
	if not _selected_window_id.is_empty():
		EventBus.facade_move_requested.emit(_selected_window_id)
		window_context_panel.visible = false

func _on_demolish_window_pressed() -> void:
	demolition_confirm_panel.visible = not _selected_window_id.is_empty()

func _on_confirm_demolish_pressed() -> void:
	if not _selected_window_id.is_empty():
		EventBus.facade_demolish_requested.emit(_selected_window_id)
	demolition_confirm_panel.visible = false

func _on_cancel_demolish_pressed() -> void:
	demolition_confirm_panel.visible = false

func _on_finish_pressed(finish_id: String) -> void:
	if _selected_wall_id.is_empty():
		return
	_selected_finish_id = finish_id
	EventBus.wall_finish_preview_requested.emit(_selected_wall_id, finish_id)

func _on_apply_finish_pressed() -> void:
	if not _selected_wall_id.is_empty():
		EventBus.wall_finish_apply_requested.emit(_selected_wall_id, _selected_finish_id)
		wall_palette_panel.visible = false

func _on_cancel_finish_pressed() -> void:
	if not _selected_wall_id.is_empty():
		EventBus.wall_finish_cancel_requested.emit(_selected_wall_id)
		wall_palette_panel.visible = false

func _format_money(value: int) -> String:
	var raw: String = str(value)
	var result := ""
	var count := 0
	for index in range(raw.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "." + result
		result = raw[index] + result
		count += 1
	return "%s €" % result

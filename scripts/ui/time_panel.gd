extends PanelContainer

const TIME_PLAY_ICON := preload("res://assets/icons/time_play.svg")
const TIME_PAUSE_ICON := preload("res://assets/icons/time_pause.svg")

@onready var date_time_label: Label = %DateTimeLabel
@onready var pause_button: Button = %PauseButton
@onready var speed_buttons: Array[Button] = [%Speed1Button, %Speed2Button, %Speed3Button]

func _ready() -> void:
	pause_button.pressed.connect(_on_pause_pressed)
	for button in speed_buttons:
		button.pressed.connect(_on_speed_pressed.bind(int(button.get_meta("speed"))))
	EventBus.time_state_changed.connect(_on_time_state_changed)
	EventBus.time_snapshot_changed.connect(_on_time_snapshot_changed)
	EventBus.time_state_requested.emit()
	EventBus.time_snapshot_requested.emit()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or _is_text_input_focused() or _is_game_menu_open() or _is_commerce_open():
		return
	match event.keycode:
		KEY_SPACE:
			EventBus.time_pause_requested.emit()
		KEY_1:
			EventBus.time_speed_requested.emit(1)
		KEY_2:
			EventBus.time_speed_requested.emit(2)
		KEY_3:
			EventBus.time_speed_requested.emit(3)
		_:
			return
	get_viewport().set_input_as_handled()

func _on_pause_pressed() -> void:
	EventBus.time_pause_requested.emit()

func _on_speed_pressed(speed: int) -> void:
	EventBus.time_speed_requested.emit(speed)

func _on_time_state_changed(_current_day: int, speed_multiplier: int, is_paused: bool) -> void:
	pause_button.button_pressed = is_paused
	pause_button.icon = TIME_PLAY_ICON if is_paused else TIME_PAUSE_ICON
	pause_button.tooltip_text = "Reanudar a velocidad normal (Espacio)" if is_paused else "Pausar el tiempo (Espacio)"
	for button in speed_buttons:
		button.button_pressed = not is_paused and int(button.get_meta("speed")) == speed_multiplier

func _on_time_snapshot_changed(snapshot: Dictionary) -> void:
	date_time_label.text = "%s · %s" % [
		String(snapshot.get("date_short_text", "")),
		String(snapshot.get("time_text", "")),
	]

func _is_text_input_focused() -> bool:
	var focused_control := get_viewport().gui_get_focus_owner()
	return focused_control is LineEdit or focused_control is TextEdit

func _is_game_menu_open() -> bool:
	var menu := get_tree().get_first_node_in_group("game_menu_overlay") as Control
	return menu != null and menu.visible

func _is_commerce_open() -> bool:
	var commerce := get_tree().get_first_node_in_group("commerce_panel") as Control
	var inventory := get_tree().get_first_node_in_group("inventory_panel") as Control
	return (commerce != null and commerce.visible) or (inventory != null and inventory.visible)

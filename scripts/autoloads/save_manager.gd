extends Node

const SAVE_PATH := "user://save_01.json"
var _is_loading := false
var _last_saved_payload := ""

func _ready() -> void:
	# Load before subscribing: GameState may emit during import without rewriting the file.
	load_game()
	EventBus.stats_changed.connect(_on_state_changed)
	EventBus.facade_installation_added.connect(_on_facade_installation_added)
	EventBus.facade_installation_updated.connect(_on_facade_installation_updated)
	EventBus.facade_installation_removed.connect(_on_facade_installation_removed)
	EventBus.wall_finish_changed.connect(_on_wall_finish_changed)

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("No se pudo abrir la partida guardada.")
		return false
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
		push_warning("La partida guardada está dañada; se usarán los valores iniciales.")
		return false
	_is_loading = true
	var state: Dictionary = parser.data
	var loaded := GameState.import_state(state)
	_is_loading = false
	if loaded:
		_last_saved_payload = JSON.stringify(GameState.export_state())
	return loaded

func save_game() -> bool:
	if _is_loading:
		return false
	var payload := JSON.stringify(GameState.export_state())
	if payload == _last_saved_payload:
		return true
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("No se pudo escribir la partida guardada.")
		return false
	file.store_string(payload)
	_last_saved_payload = payload
	return true

func _on_state_changed(_money: int, _reputation: int) -> void:
	save_game()

func _on_facade_installation_added(_installation: Dictionary) -> void:
	# Kept separately so future zero-cost installations are persisted as well.
	save_game()

func _on_facade_installation_updated(_installation: Dictionary) -> void:
	save_game()

func _on_facade_installation_removed(_installation_id: String, _refund: int) -> void:
	save_game()

func _on_wall_finish_changed(_wall_id: String, _finish_id: String) -> void:
	save_game()

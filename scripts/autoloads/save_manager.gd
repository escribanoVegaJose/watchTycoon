extends Node

const SAVE_PATH := "user://save_01.json"
var _is_loading := false
var _last_saved_payload := ""

func _ready() -> void:
	# Load before subscribing: GameState may emit during import without rewriting the file.
	load_game()
	EventBus.stats_changed.connect(_save_on_mutation)
	EventBus.auction_state_changed.connect(_save_on_mutation)
	EventBus.auction_resolved.connect(_save_on_mutation)
	EventBus.auction_state_persist_requested.connect(_save_on_mutation)
	EventBus.inventory_changed.connect(_save_on_mutation)
	EventBus.purchase_history_changed.connect(_save_on_mutation)
	EventBus.watch_display_changed.connect(_save_on_mutation)
	EventBus.carried_watch_changed.connect(_save_on_mutation)
	EventBus.facade_installation_added.connect(_save_on_mutation)
	EventBus.facade_installation_updated.connect(_save_on_mutation)
	EventBus.facade_installation_removed.connect(_save_on_mutation)
	EventBus.facility_installation_added.connect(_save_on_mutation)
	EventBus.facility_installation_updated.connect(_save_on_mutation)
	EventBus.facility_installation_removed.connect(_save_on_mutation)
	EventBus.wall_finish_changed.connect(_save_on_mutation)
	EventBus.day_changed.connect(_save_on_mutation)
	EventBus.visitor_negotiation_changed.connect(_save_on_mutation)
	EventBus.customer_reviews_changed.connect(_save_on_mutation)

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
	if loaded:
		# Autoload _ready order is not a persistence contract. Explicitly refresh
		# finance after GameState has accepted the loaded data.
		FinanceManager.restore_from_game_state()
	_is_loading = false
	if loaded:
		_last_saved_payload = JSON.stringify(GameState.export_state())
		# Saves before review ratings need one write so the new independent state is
		# present even if the player does not trigger another mutation this session.
		if GameState.has_pending_display_capacity_migration() or not state.has("customer_reviews") or not state.has("next_customer_name_index") or not state.has("visitor_sales_count"):
			_last_saved_payload = ""
			if save_game():
				GameState.mark_display_capacity_migration_saved()
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

## Creates a fresh save and rebuilds the current scene from that state.
func reset_game() -> bool:
	_is_loading = true
	GameState.reset_state()
	FinanceManager.reset_finance()
	TimeManager.reset_time()
	_is_loading = false
	_last_saved_payload = ""
	if not save_game():
		push_error("No se pudo guardar la nueva partida; el reinicio se ha cancelado.")
		return false
	get_tree().reload_current_scene()
	return true

func _save_on_mutation(_first: Variant = null, _second: Variant = null) -> void:
	# All persistent-state signals have at most two arguments.
	save_game()

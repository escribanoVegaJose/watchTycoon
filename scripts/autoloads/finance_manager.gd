extends Node

## Lightweight operating-cost model. Taxation is intentionally abstracted: it is
## inspired by Spanish business obligations, not a simulation of Spanish tax law.
const CONFIG_PATH := "res://data/economy/monthly_expenses.json"
const DEFAULT_CONFIG := {
	"month_days": 30,
	"rent": 1200,
	"utilities_base": 150,
	"utilities_per_unit": 10,
	"taxes_and_fees": 250,
}

var _config: Dictionary = DEFAULT_CONFIG.duplicate()
var _last_settled_month := 0
var _monthly_history: Array[Dictionary] = []

func _ready() -> void:
	_load_config()
	restore_from_game_state()

func restore_from_game_state() -> void:
	_last_settled_month = 0
	_monthly_history.clear()
	_import_state(GameState.get_finance_state())
	_emit_preview()

func get_month_days() -> int:
	return int(_config["month_days"])

func get_days_until_settlement(current_day: int = GameState.current_day) -> int:
	return get_month_days() - posmod(current_day - 1, get_month_days())

func get_expense_preview() -> Dictionary:
	var employees := GameState.get_monthly_personnel_cost()
	var utilities := int(_config["utilities_base"]) + int(_config["utilities_per_unit"]) * GameState.units_produced_this_month
	return {
		"rent": int(_config["rent"]),
		"utilities": utilities,
		"taxes": int(_config["taxes_and_fees"]),
		"personnel": employees,
		"total": int(_config["rent"]) + utilities + int(_config["taxes_and_fees"]) + employees,
	}

## Called synchronously by TimeManager before day_changed, so the save checkpoint
## always contains the result of a monthly closing.
func process_day(current_day: int) -> void:
	if current_day <= 1 or posmod(current_day - 1, get_month_days()) != 0:
		_emit_preview()
		return
	var month := floori(float(current_day - 1) / get_month_days())
	if month <= _last_settled_month:
		return
	var settlement := get_expense_preview()
	settlement["month"] = month
	settlement["day"] = current_day
	settlement["total"] = int(settlement["total"])
	_last_settled_month = month
	_monthly_history.append(settlement.duplicate(true))
	if _monthly_history.size() > 6:
		_monthly_history.pop_front()
	GameState.apply_monthly_settlement(int(settlement["total"]), _build_state())
	if GameState.money < 0:
		EventBus.feedback_requested.emit("Tesorería negativa: las inversiones quedan suspendidas hasta recuperar liquidez.", "error")
	_emit_preview()
	EventBus.monthly_settlement_completed.emit(settlement.duplicate(true), GameState.money)

func get_latest_settlement() -> Dictionary:
	return _monthly_history.back().duplicate(true) if not _monthly_history.is_empty() else {}

func _emit_preview() -> void:
	EventBus.monthly_expense_preview_changed.emit(get_expense_preview(), get_days_until_settlement())

func _persist_state() -> void:
	GameState.set_finance_state(_build_state())

func _build_state() -> Dictionary:
	return {
		"last_settled_month": _last_settled_month,
		"monthly_history": _monthly_history.duplicate(true),
	}

func reset_finance() -> void:
	_last_settled_month = 0
	_monthly_history.clear()
	_persist_state()
	_emit_preview()

func _import_state(state: Dictionary) -> void:
	_last_settled_month = maxi(0, int(state.get("last_settled_month", 0)))
	var raw_history: Variant = state.get("monthly_history", [])
	if raw_history is Array:
		for entry in raw_history:
			if entry is Dictionary:
				_monthly_history.append(entry.duplicate(true))

func _load_config() -> void:
	if not FileAccess.file_exists(CONFIG_PATH):
		return
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	var json := JSON.new()
	if file != null and json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		for key in DEFAULT_CONFIG:
			var value: Variant = json.data.get(key, DEFAULT_CONFIG[key])
			if value is int or value is float:
				_config[key] = maxi(1, int(value))

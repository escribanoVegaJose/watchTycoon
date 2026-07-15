extends Node

## One in-game day at normal speed lasts this many real seconds.
## The solar cycle and its dependent lighting use this duration via intraday_progress.
const SECONDS_PER_DAY := 80.0
const VALID_SPEEDS := [1, 2, 3]
const START_DATE_UNIX := 857347200
const SECONDS_PER_CALENDAR_DAY := 24 * 60 * 60
const START_HOUR := 8
const DAYLIGHT_PHASE_END := 0.6
const HALF_DAY_MINUTES := 12 * 60
const WEEKDAY_NAMES := ["lunes", "martes", "miércoles", "jueves", "viernes", "sábado", "domingo"]
const MONTH_NAMES := ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"]

var speed_multiplier := 1
var is_paused := false
var _elapsed_day_seconds := 0.0

func _ready() -> void:
	EventBus.time_pause_requested.connect(toggle_pause)
	EventBus.time_speed_requested.connect(set_speed)
	EventBus.time_state_requested.connect(_emit_time_state)
	EventBus.time_snapshot_requested.connect(_emit_time_snapshot)
	_emit_time_state()
	_emit_time_snapshot()

func _process(delta: float) -> void:
	if is_paused:
		return
	_elapsed_day_seconds += get_simulation_delta(delta)
	while _elapsed_day_seconds >= SECONDS_PER_DAY:
		_elapsed_day_seconds -= SECONDS_PER_DAY
		_complete_day()
	_emit_time_snapshot()

## Converts real frame time into simulation time for gameplay systems.
func get_simulation_delta(real_delta: float) -> float:
	if is_paused:
		return 0.0
	return real_delta * speed_multiplier

## Public controls allow non-UI systems to use the same time rules.
func toggle_pause() -> void:
	if is_paused:
		# The pause control always resumes at the predictable base speed.
		set_speed(1)
		return
	set_paused(true)

func set_paused(paused: bool) -> void:
	if is_paused == paused:
		return
	is_paused = paused
	# Pausing stops the simulation clock, not the whole scene tree: the player can
	# still open commerce, construct, and manage the boutique while time is stopped.
	_emit_time_state()
	_emit_time_snapshot()

func set_speed(requested_speed: int) -> void:
	if not VALID_SPEEDS.has(requested_speed):
		return
	var changed := speed_multiplier != requested_speed or is_paused
	speed_multiplier = requested_speed
	# Selecting a speed resumes the calendar, while the pause button remains explicit.
	is_paused = false
	if changed:
		_emit_time_state()
		_emit_time_snapshot()

## A new game always begins at day one, 08:00, at normal speed.
func reset_time() -> void:
	speed_multiplier = 1
	is_paused = false
	_elapsed_day_seconds = 0.0
	_emit_time_state()
	_emit_time_snapshot()

## Kept for systems that need to resolve a calendar day immediately.
func pass_day() -> void:
	_elapsed_day_seconds = 0.0
	_complete_day()
	_emit_time_snapshot()

func _complete_day() -> void:
	var current_day := GameState.pass_day()
	FinanceManager.process_day(current_day)
	EventBus.day_changed.emit(current_day)
	_emit_time_state()

func _emit_time_state() -> void:
	EventBus.time_state_changed.emit(GameState.current_day, speed_multiplier, is_paused)

func _emit_time_snapshot() -> void:
	var intraday_progress := clampf(_elapsed_day_seconds / SECONDS_PER_DAY, 0.0, 1.0)
	# The daylight portion is deliberately longer in real time (08:00–20:00),
	# while the remaining phase represents the night (20:00–08:00).
	var elapsed_minutes := _get_elapsed_calendar_minutes(intraday_progress)
	var total_minutes := START_HOUR * 60 + elapsed_minutes
	var date_offset := floori(float(total_minutes) / (24.0 * 60.0))
	var minute_of_day := posmod(total_minutes, 24 * 60)
	var days_since_start := GameState.current_day - 1 + date_offset
	var date := Time.get_datetime_dict_from_unix_time(START_DATE_UNIX + days_since_start * SECONDS_PER_CALENDAR_DAY)
	var weekday: String = str(WEEKDAY_NAMES[posmod(days_since_start, WEEKDAY_NAMES.size())])
	var month: String = str(MONTH_NAMES[int(date["month"]) - 1])
	var date_text := "%s %d de %s de %d" % [weekday, int(date["day"]), month, int(date["year"])]
	var time_text := "%02d:%02d" % [floori(float(minute_of_day) / 60.0), minute_of_day % 60]
	EventBus.time_snapshot_changed.emit({
		"current_day": GameState.current_day,
		"date_text": date_text,
		"date_short_text": "%02d/%02d/%04d" % [int(date["day"]), int(date["month"]), int(date["year"])],
		"time_text": time_text,
		"date_time_text": "%s · %s" % [date_text, time_text],
		"intraday_progress": intraday_progress,
	})

func _get_elapsed_calendar_minutes(intraday_progress: float) -> int:
	if intraday_progress < DAYLIGHT_PHASE_END:
		return roundi(intraday_progress / DAYLIGHT_PHASE_END * HALF_DAY_MINUTES)
	var night_progress := (intraday_progress - DAYLIGHT_PHASE_END) / (1.0 - DAYLIGHT_PHASE_END)
	return HALF_DAY_MINUTES + roundi(night_progress * HALF_DAY_MINUTES)

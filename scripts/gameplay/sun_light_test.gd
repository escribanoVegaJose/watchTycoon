extends DirectionalLight3D

@export var sunrise_energy: float = 0.18
@export var noon_energy: float = 1.05
@export var moonlight_energy: float = 0.035
@export var minimum_elevation_degrees: float = 18.0
@export var maximum_elevation_degrees: float = 48.0
@export var ingress_azimuth_start_degrees: float = -55.0
@export var ingress_azimuth_end_degrees: float = -25.0

func _ready() -> void:
	EventBus.time_snapshot_changed.connect(_on_time_snapshot_changed)
	EventBus.time_snapshot_requested.emit()

func _on_time_snapshot_changed(snapshot: Dictionary) -> void:
	var intraday_progress := float(snapshot.get("intraday_progress", 0.0))
	# The first 60% represents 08:00–20:00; the remaining phase is night.
	if intraday_progress < 0.6:
		_update_sun_light(intraday_progress / 0.6)
	else:
		_update_night_light()

func _update_sun_light(progress: float) -> void:
	var daylight_curve := sin(progress * PI)
	var elevation := deg_to_rad(lerpf(minimum_elevation_degrees, maximum_elevation_degrees, daylight_curve))
	# Los rayos viajan hacia el interior desde la pared trasera y la derecha,
	# donde estan la puerta y la ventana respectivamente.
	var azimuth := lerpf(
		deg_to_rad(ingress_azimuth_start_degrees),
		deg_to_rad(ingress_azimuth_end_degrees),
		progress
	)
	var horizontal := cos(elevation)
	var shine_direction := Vector3(
		sin(azimuth) * horizontal,
		-sin(elevation),
		cos(azimuth) * horizontal
	).normalized()

	look_at(global_position + shine_direction, Vector3.UP)
	light_energy = lerpf(sunrise_energy, noon_energy, daylight_curve)
	# El sol conserva una calidez natural al amanecer y se vuelve casi blanco
	# a mediodía, sin teñir toda la tienda de naranja.
	light_color = Color(1.0, 0.84, 0.66).lerp(Color(1.0, 0.97, 0.9), daylight_curve)

func _update_night_light() -> void:
	light_energy = moonlight_energy
	light_color = Color(0.48, 0.35, 0.3)

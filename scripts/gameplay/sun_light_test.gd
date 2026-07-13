extends DirectionalLight3D

## Ciclo compacto: 60 s de luz y 60 s de noche.
@export var day_duration_seconds: float = 60.0
@export var night_duration_seconds: float = 60.0
@export var sunrise_energy: float = 0.12
@export var noon_energy: float = 1.8
@export var moonlight_energy: float = 0.035
@export var minimum_elevation_degrees: float = 8.0
@export var maximum_elevation_degrees: float = 72.0
@export var ingress_azimuth_start_degrees: float = -55.0
@export var ingress_azimuth_end_degrees: float = -25.0

var _elapsed_seconds := 30.0

func _ready() -> void:
	_update_sun_light(0.5)

func _process(delta: float) -> void:
	var safe_day_duration := maxf(day_duration_seconds, 0.1)
	var safe_night_duration := maxf(night_duration_seconds, 0.1)
	var cycle_duration := safe_day_duration + safe_night_duration
	_elapsed_seconds = fmod(_elapsed_seconds + delta, cycle_duration)

	if _elapsed_seconds < safe_day_duration:
		_update_sun_light(_elapsed_seconds / safe_day_duration)
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
	light_color = Color(1.0, 0.72, 0.48).lerp(Color(1.0, 0.96, 0.86), daylight_curve)

func _update_night_light() -> void:
	light_energy = moonlight_energy
	light_color = Color(0.42, 0.52, 0.72)

extends DirectionalLight3D

@export var cycle_duration_seconds: float = 10.0
@export var sunrise_energy: float = 0.25
@export var noon_energy: float = 1.15
@export var minimum_elevation_degrees: float = 8.0
@export var maximum_elevation_degrees: float = 72.0

var _elapsed_seconds := 0.0

func _ready() -> void:
	_update_sun_light(0.0)

func _process(delta: float) -> void:
	var safe_duration := maxf(cycle_duration_seconds, 0.1)
	_elapsed_seconds = fmod(_elapsed_seconds + delta, safe_duration)
	_update_sun_light(_elapsed_seconds / safe_duration)

func _update_sun_light(progress: float) -> void:
	var daylight_curve := sin(progress * PI)
	var elevation := deg_to_rad(lerpf(minimum_elevation_degrees, maximum_elevation_degrees, daylight_curve))
	var azimuth := lerpf(deg_to_rad(-70.0), deg_to_rad(70.0), progress)
	var horizontal := cos(elevation)
	var shine_direction := Vector3(
		sin(azimuth) * horizontal,
		-sin(elevation),
		cos(azimuth) * horizontal
	).normalized()

	look_at(global_position + shine_direction, Vector3.UP)
	light_energy = lerpf(sunrise_energy, noon_energy, daylight_curve)
	light_color = Color(1.0, 0.72, 0.48).lerp(Color(1.0, 0.96, 0.86), daylight_curve)

class_name WindowDaylightProxy
extends Node3D

## Luz localizada asociada a una ventana instalada. El foco nace justo tras el
## cristal y apunta hacia el interior; no sustituye a la iluminacion ambiental.
@export var light_energy := 2.4
@export var light_range := 5.0
@export var cone_angle := 52.0

var _daylight: SpotLight3D
var _sun_light: DirectionalLight3D

func _ready() -> void:
	_daylight = SpotLight3D.new()
	_daylight.name = "DaylightCone"
	_daylight.light_color = Color(0.78, 0.88, 1.0)
	_daylight.light_energy = light_energy
	_daylight.spot_range = light_range
	_daylight.spot_angle = cone_angle
	_daylight.spot_attenuation = 1.25
	_daylight.shadow_enabled = true
	add_child(_daylight)

func configure_from_sun(sun_light: DirectionalLight3D) -> void:
	_sun_light = sun_light

func _process(_delta: float) -> void:
	if _sun_light == null:
		return
	_daylight.light_color = _sun_light.light_color
	_daylight.light_energy = _sun_light.light_energy * light_energy

extends SpotLight3D

## Luz interior estilizada para una puerta o ventana opaca.
## Replica el color y la intensidad del sol sin exigir transparencia en el GLB.
@export var sun_light_path: NodePath
@export var ingress_direction := Vector3.FORWARD
@export var energy_multiplier := 1.0

@onready var sun_light: DirectionalLight3D = get_node_or_null(sun_light_path) as DirectionalLight3D

func _ready() -> void:
	look_at(global_position + ingress_direction.normalized(), Vector3.UP)

func _process(_delta: float) -> void:
	if sun_light == null:
		return

	# El cono sigue el mismo recorrido angular que el sol para que la mancha
	# de luz avance por el suelo desde la puerta y la ventana.
	var sun_ray_direction := sun_light.global_transform.basis * Vector3.FORWARD
	if sun_ray_direction.length_squared() > 0.0001:
		look_at(global_position + sun_ray_direction.normalized(), Vector3.UP)

	light_color = sun_light.light_color
	light_energy = sun_light.light_energy * energy_multiplier

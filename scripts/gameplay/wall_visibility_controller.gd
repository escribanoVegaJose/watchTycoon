extends Node

@export var camera_path: NodePath
@export var front_wall_path: NodePath
@export var back_wall_path: NodePath
@export var left_wall_path: NodePath
@export var right_wall_path: NodePath
@export var room_center := Vector3.ZERO
## Mantiene la envolvente del taller intacta al navegar con la cámara.
@export var keep_walls_visible := true

@onready var camera: Camera3D = get_node(camera_path) as Camera3D
@onready var front_wall: Node3D = get_node(front_wall_path) as Node3D
@onready var back_wall: Node3D = get_node(back_wall_path) as Node3D
@onready var left_wall: Node3D = get_node(left_wall_path) as Node3D
@onready var right_wall: Node3D = get_node(right_wall_path) as Node3D

func _ready() -> void:
	_set_all_walls_visible()
	set_process(not keep_walls_visible)

func _process(_delta: float) -> void:
	_update_visible_walls()

func _update_visible_walls() -> void:
	_set_all_walls_visible()
	if keep_walls_visible:
		return

	var camera_direction := camera.global_position - room_center
	if absf(camera_direction.x) > absf(camera_direction.z):
		if camera_direction.x > 0.0:
			right_wall.visible = false
		else:
			left_wall.visible = false
	else:
		if camera_direction.z > 0.0:
			front_wall.visible = false
		else:
			back_wall.visible = false

func _set_all_walls_visible() -> void:
	front_wall.visible = true
	back_wall.visible = true
	left_wall.visible = true
	right_wall.visible = true

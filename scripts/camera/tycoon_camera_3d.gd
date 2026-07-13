extends Node3D

@export var move_speed := 9.0
@export var fast_move_multiplier := 1.8
@export var rotate_speed := 0.005
@export var zoom_speed := 1.4
@export var min_zoom := 6.0
@export var max_zoom := 24.0
@export var min_pitch := deg_to_rad(-68.0)
@export var max_pitch := deg_to_rad(-28.0)
@export var bounds_min := Vector2(-14.0, -12.0)
@export var bounds_max := Vector2(14.0, 12.0)

@onready var yaw_pivot: Node3D = $YawPivot
@onready var pitch_pivot: Node3D = $YawPivot/PitchPivot
@onready var camera: Camera3D = $YawPivot/PitchPivot/Camera3D

var rotating := false
var placement_active := false

func _ready() -> void:
	camera.position.z = 14.0
	pitch_pivot.rotation.x = deg_to_rad(-48.0)
	yaw_pivot.rotation.y = deg_to_rad(45.0)
	EventBus.placement_state_changed.connect(_on_placement_state_changed)

func _process(delta: float) -> void:
	var input := Vector3.ZERO
	if Input.is_action_pressed("camera_forward"):
		input.z += 1.0
	if Input.is_action_pressed("camera_back"):
		input.z -= 1.0
	if Input.is_action_pressed("camera_left"):
		input.x -= 1.0
	if Input.is_action_pressed("camera_right"):
		input.x += 1.0

	if input == Vector3.ZERO:
		return

	input = input.normalized()
	var forward := -yaw_pivot.global_transform.basis.z
	var right := yaw_pivot.global_transform.basis.x
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()

	var speed := move_speed
	if Input.is_action_pressed("camera_fast"):
		speed *= fast_move_multiplier

	global_position += (forward * input.z + right * input.x) * speed * delta
	global_position.x = clamp(global_position.x, bounds_min.x, bounds_max.x)
	global_position.z = clamp(global_position.z, bounds_min.y, bounds_max.y)

func _input(event: InputEvent) -> void:
	if placement_active:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			rotating = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.position.z = max(min_zoom, camera.position.z - zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.position.z = min(max_zoom, camera.position.z + zoom_speed)

	if event is InputEventMouseMotion and rotating:
		yaw_pivot.rotation.y -= event.relative.x * rotate_speed
		pitch_pivot.rotation.x -= event.relative.y * rotate_speed
		pitch_pivot.rotation.x = clamp(pitch_pivot.rotation.x, min_pitch, max_pitch)

func _on_placement_state_changed(active: bool, _item_name: String) -> void:
	placement_active = active
	if active:
		rotating = false

class_name WatchmakerPlayer
extends CharacterBody3D

@export var move_speed := 2.5
@export var arrival_distance := 0.08
@export var walk_bounds_min := Vector2(-8.1, -5.6)
@export var walk_bounds_max := Vector2(8.1, 5.6)

@onready var idle_visual: Node3D = $IdleVisual
@onready var walk_visual: Node3D = $WalkVisual

var _destination := Vector3.ZERO
var _has_destination := false
var _idle_animation_player: AnimationPlayer
var _walk_animation_player: AnimationPlayer
var _marker: DestinationMarker

func _ready() -> void:
	_marker = DestinationMarker.new()
	add_child(_marker)
	_idle_animation_player = _find_animation_player(idle_visual)
	_walk_animation_player = _find_animation_player(walk_visual)
	_set_walking(false)

func set_destination(world_position: Vector3) -> void:
	_destination = world_position
	_destination.x = clampf(_destination.x, walk_bounds_min.x, walk_bounds_max.x)
	_destination.z = clampf(_destination.z, walk_bounds_min.y, walk_bounds_max.y)
	_destination.y = global_position.y
	_has_destination = true
	_marker.show_at(_destination)

func _physics_process(_delta: float) -> void:
	if TimeManager.is_paused:
		velocity = Vector3.ZERO
		_set_walking(false)
		return
	if not _has_destination:
		return
	var offset := _destination - global_position
	offset.y = 0.0
	if offset.length() <= arrival_distance:
		velocity = Vector3.ZERO
		_has_destination = false
		_marker.clear()
		_set_walking(false)
		return
	var direction := offset.normalized()
	velocity = direction * move_speed
	look_at(global_position + direction, Vector3.UP)
	var previous_position := global_position
	move_and_slide()
	if global_position.distance_squared_to(previous_position) <= 0.0001:
		velocity = Vector3.ZERO
		_has_destination = false
		_marker.clear()
		_set_walking(false)
		return
	_set_walking(true)

func _set_walking(is_walking: bool) -> void:
	idle_visual.visible = not is_walking
	walk_visual.visible = is_walking
	if is_walking:
		if _idle_animation_player != null:
			_idle_animation_player.stop()
		_play_walk_animation()
	else:
		if _walk_animation_player != null:
			_walk_animation_player.stop()
		_play_idle_animation()

func _play_idle_animation() -> void:
	_play_first_animation(_idle_animation_player)

func _play_walk_animation() -> void:
	_play_first_animation(_walk_animation_player)

func _play_first_animation(animation_player: AnimationPlayer) -> void:
	if animation_player == null or animation_player.is_playing():
		return
	for animation_name in animation_player.get_animation_list():
		if animation_name != "RESET":
			var animation := animation_player.get_animation(animation_name)
			if animation != null:
				animation.loop_mode = Animation.LOOP_LINEAR
			animation_player.play(animation_name)
			return

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null

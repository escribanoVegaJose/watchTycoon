extends Node

const DOORBELL := preload("res://assets/audio/sfx/doorbell.mp3")
var _player: AudioStreamPlayer

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.stream = DOORBELL
	_apply_volume(SettingsManager.effects_volume)
	add_child(_player)
	EventBus.visitor_doorbell_requested.connect(_on_doorbell_requested)
	AudioManager.effects_volume_changed.connect(_apply_volume)

func _on_doorbell_requested() -> void:
	_player.play()

func _apply_volume(_volume: float) -> void:
	_player.volume_db = AudioManager.get_effects_volume_db()

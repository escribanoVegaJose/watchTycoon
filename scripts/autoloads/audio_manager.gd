extends Node

## La música de ambiente es global y su preferencia no pertenece a una partida.
signal music_mute_changed(is_muted: bool)
signal music_volume_changed(volume: float)
signal effects_volume_changed(volume: float)

const MUSIC_PLAYLIST: Array[AudioStreamMP3] = [
	preload("res://assets/audio/boutique_theme.mp3"),
	preload("res://assets/audio/atelier_whimsy.mp3"),
]

var _music_player: AudioStreamPlayer
var _music_stream: AudioStreamMP3
var _current_track_index := 0

func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "BackgroundMusic"
	_music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_music_player)
	_music_player.finished.connect(_on_music_finished)
	SettingsManager.music_mute_changed.connect(_on_music_mute_changed)
	SettingsManager.music_volume_changed.connect(_on_music_volume_changed)
	SettingsManager.effects_volume_changed.connect(_on_effects_volume_changed)
	_on_music_mute_changed(SettingsManager.music_muted)
	_on_music_volume_changed(SettingsManager.music_volume)
	_play_current_track()

func toggle_music_mute() -> void:
	SettingsManager.set_music_muted(not SettingsManager.music_muted)

func _on_music_mute_changed(is_muted: bool) -> void:
	_apply_music_volume()
	music_mute_changed.emit(is_muted)

func _on_music_volume_changed(volume: float) -> void:
	_apply_music_volume()
	music_volume_changed.emit(volume)

func _on_effects_volume_changed(volume: float) -> void:
	effects_volume_changed.emit(volume)

func get_effects_volume_db() -> float:
	return _percentage_to_db(SettingsManager.effects_volume)

func _play_current_track() -> void:
	_music_stream = MUSIC_PLAYLIST[_current_track_index].duplicate() as AudioStreamMP3
	# La lista completa, no cada canción individual, es la que se repite.
	_music_stream.loop = false
	_music_player.stream = _music_stream
	_music_player.play()

func _on_music_finished() -> void:
	_current_track_index = (_current_track_index + 1) % MUSIC_PLAYLIST.size()
	_play_current_track()

func _apply_music_volume() -> void:
	if _music_player != null:
		_music_player.volume_db = -80.0 if SettingsManager.music_muted else _percentage_to_db(SettingsManager.music_volume)

func _percentage_to_db(volume: float) -> float:
	return -80.0 if volume <= 0.0 else linear_to_db(volume / 100.0)

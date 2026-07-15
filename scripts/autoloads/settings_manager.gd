extends Node

## Las preferencias pertenecen al usuario, no a la partida guardada.
signal language_changed(locale: String)
signal music_mute_changed(is_muted: bool)
signal music_volume_changed(volume: float)
signal effects_volume_changed(volume: float)

const SETTINGS_PATH := "user://settings.cfg"
const SUPPORTED_LOCALES := ["es", "en"]

var locale := "es"
var music_muted := false
var music_volume := 70.0
var effects_volume := 70.0

func _ready() -> void:
	_register_spanish_translation()
	_register_english_translation()
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		locale = String(config.get_value("preferences", "locale", "es"))
		music_muted = bool(config.get_value("preferences", "music_muted", false))
		music_volume = clampf(float(config.get_value("preferences", "music_volume", 70.0)), 0.0, 100.0)
		effects_volume = clampf(float(config.get_value("preferences", "effects_volume", 70.0)), 0.0, 100.0)
	if not locale in SUPPORTED_LOCALES:
		locale = "es"
	TranslationServer.set_locale(locale)

func set_language(new_locale: String) -> void:
	if not new_locale in SUPPORTED_LOCALES or new_locale == locale:
		return
	locale = new_locale
	TranslationServer.set_locale(locale)
	_save_preferences()
	get_tree().root.propagate_notification(NOTIFICATION_TRANSLATION_CHANGED)
	language_changed.emit(locale)

func set_music_muted(is_muted: bool) -> void:
	if music_muted == is_muted:
		return
	music_muted = is_muted
	_save_preferences()
	music_mute_changed.emit(music_muted)

func set_music_volume(volume: float) -> void:
	var clamped_volume := clampf(volume, 0.0, 100.0)
	if is_equal_approx(music_volume, clamped_volume):
		return
	music_volume = clamped_volume
	_save_preferences()
	music_volume_changed.emit(music_volume)

func set_effects_volume(volume: float) -> void:
	var clamped_volume := clampf(volume, 0.0, 100.0)
	if is_equal_approx(effects_volume, clamped_volume):
		return
	effects_volume = clamped_volume
	_save_preferences()
	effects_volume_changed.emit(effects_volume)

func _save_preferences() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("preferences", "locale", locale)
	config.set_value("preferences", "music_muted", music_muted)
	config.set_value("preferences", "music_volume", music_volume)
	config.set_value("preferences", "effects_volume", effects_volume)
	if config.save(SETTINGS_PATH) != OK:
		push_warning("No se pudieron guardar las preferencias.")

func _register_spanish_translation() -> void:
	var translation := Translation.new()
	translation.locale = "es"
	var messages := {"Premium": "Alta gama", "earrings": "Pendientes", "ring": "Anillo", "pendant": "Colgante", "skeleton": "Esqueleto"}
	for source in messages:
		translation.add_message(source, messages[source])
	TranslationServer.add_translation(translation)

func _register_english_translation() -> void:
	var translation := Translation.new()
	translation.locale = "en"
	var messages := {
		"Cancelar · Esc": "Cancel · Esc", "Pujas": "Bids", "Inventario": "Inventory", "Menú": "Menu",
		"Mobiliario": "Furniture", "Equipamiento de tienda": "Store equipment",
		"Ventana seleccionada": "Selected window", "¿Demoler? Reembolso: 80 %": "Demolish? Refund: 80%",
		"Confirmar": "Confirm", "Cancelar": "Cancel", "Acabado de pared · gratuito": "Wall finish · free",
		"Aplicar": "Apply", "Menú de partida": "Game menu", "El tiempo está en pausa.": "Time is paused.",
		"Reanudar": "Resume", "Reiniciar partida": "Restart game", "¿Reiniciar la partida?": "Restart the game?",
		"Se perderá todo el progreso guardado.": "All saved progress will be lost.", "Sí, reiniciar": "Yes, restart",
		"Idioma": "Language", "Español": "Spanish", "Inglés": "English", "Música": "Music", "Efectos": "Effects",
		"🔊 Música": "🔊 Music", "🔇 Música": "🔇 Music", "Activar música": "Enable music", "Silenciar música": "Mute music",
		"Premium": "Premium", "Funcional": "Functional", "Alta relojería": "Haute horlogerie",
		"earrings": "Earrings", "ring": "Ring", "pendant": "Pendant", "skeleton": "Skeleton"
	}
	for source in messages:
		translation.add_message(source, messages[source])
	TranslationServer.add_translation(translation)

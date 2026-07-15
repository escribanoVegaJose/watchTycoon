extends Node

## Las preferencias pertenecen al usuario, no a la partida guardada.
signal language_changed(locale: String)

const SETTINGS_PATH := "user://settings.cfg"
const SUPPORTED_LOCALES := ["es", "en"]

var locale := "es"

func _ready() -> void:
	_register_spanish_translation()
	_register_english_translation()
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		locale = String(config.get_value("preferences", "locale", "es"))
	if not locale in SUPPORTED_LOCALES:
		locale = "es"
	TranslationServer.set_locale(locale)

func set_language(new_locale: String) -> void:
	if not new_locale in SUPPORTED_LOCALES or new_locale == locale:
		return
	locale = new_locale
	TranslationServer.set_locale(locale)
	var config := ConfigFile.new()
	config.set_value("preferences", "locale", locale)
	if config.save(SETTINGS_PATH) != OK:
		push_warning("No se pudo guardar la preferencia de idioma.")
	get_tree().root.propagate_notification(NOTIFICATION_TRANSLATION_CHANGED)
	language_changed.emit(locale)

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
		"Idioma": "Language", "Español": "Spanish", "Inglés": "English",
		"Premium": "Premium", "Funcional": "Functional", "Alta relojería": "Haute horlogerie",
		"earrings": "Earrings", "ring": "Ring", "pendant": "Pendant", "skeleton": "Skeleton"
	}
	for source in messages:
		translation.add_message(source, messages[source])
	TranslationServer.add_translation(translation)

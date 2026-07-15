extends "res://scripts/ui/commerce_panel.gd"

## Standalone presentation for acquired pieces and display placement.
## Inventory mutations remain owned by GameState and placement controllers.

func _ready() -> void:
	add_to_group("inventory_panel")
	z_index = 20
	visible = false
	_build_ui()
	EventBus.inventory_changed.connect(_on_inventory_changed)
	EventBus.stats_changed.connect(_on_stats_changed)
	EventBus.purchase_history_changed.connect(_on_purchase_history_changed)
	EventBus.watch_display_changed.connect(_on_watch_display_changed)
	EventBus.carried_watch_changed.connect(_on_carried_watch_changed)
	get_node("/root/SettingsManager").connect(&"language_changed", _on_language_changed)

func open() -> void:
	_store_scroll_position()
	_active_scroll = null
	visible = true
	_active_tab = "inventory"
	_render()
	call_deferred("_focus_close_button")

func _render() -> void:
	_store_scroll_position()
	for child in _content.get_children():
		child.queue_free()
	var header := HBoxContainer.new()
	_content.add_child(header)
	var title := Label.new()
	title.text = "INVENTARIO"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.95, 0.78, 0.35))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := Button.new()
	close_button.text = "Cerrar · Esc"
	close_button.pressed.connect(close)
	header.add_child(close_button)
	_feedback_label = Label.new()
	_feedback_label.text = _feedback_message
	_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.42) if _feedback_severity == "error" else Color(0.67, 0.88, 0.65))
	_content.add_child(_feedback_label)
	_render_sell()
	_restore_scroll_position()

func _on_purchase_history_changed() -> void:
	if visible:
		_render()

func _on_inventory_changed(_owned_count: int, _listed_count: int) -> void:
	if visible:
		_render()

func _on_watch_display_changed(_snapshot: Dictionary) -> void:
	if visible:
		_render()

func _on_carried_watch_changed(_watch: Dictionary) -> void:
	if visible:
		_render()

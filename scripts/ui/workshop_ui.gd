extends Node3D

const AUCTION_PREVIEW := preload("res://scenes/ui/AuctionPreview3D.tscn")
const AUCTION_WIN_TOAST := preload("res://scripts/ui/auction_win_toast.gd")
const VISITOR_SALE_TOAST := preload("res://scripts/ui/visitor_sale_toast.gd")
const MOVE_ICON := preload("res://assets/icons/move.svg")
const DOOR_OPEN_ICON := preload("res://assets/icons/door_open.svg")

@export var furniture_definitions: Array[PlaceableDefinition] = []
@export var facility_definitions: Array[FacilityDefinition] = []

@onready var money_label: Label = %MoneyLabel
@onready var finance_label: Label = %FinanceLabel
@onready var money_button: Button = %MoneyButton
@onready var reputation_button: Button = %ReputationButton
@onready var reputation_stars_label: Label = %ReputationStarsLabel
@onready var reputation_progress: ProgressBar = %ReputationProgress
@onready var global_reputation_ring: Control = %GlobalReputationRing
@onready var global_reputation_value: Label = %GlobalReputationValue
@onready var next_visitor_label: Label = %NextVisitorLabel
@onready var furniture_panel: PanelContainer = %FurniturePanel
@onready var furniture_button: Button = %FurnitureButton
@onready var furniture_grid: GridContainer = %FurnitureGrid
@onready var facilities_panel: PanelContainer = %FacilitiesPanel
@onready var facilities_button: Button = %FacilitiesButton
@onready var auction_button: Button = %AuctionButton
@onready var commerce_panel: Control = %CommercePanel
@onready var inventory_button: Button = %InventoryButton
@onready var inventory_panel: Control = %InventoryPanel
@onready var facilities_grid: GridContainer = %FacilitiesGrid
@onready var placement_bar: PanelContainer = %PlacementBar
@onready var placement_instruction_label: Label = %PlacementInstructionLabel
@onready var cancel_placement_button: Button = %CancelPlacementButton
@onready var window_context_panel: PanelContainer = %WindowContextPanel
@onready var installation_context_title: Label = $HudLayer/WindowContextPanel/Margin/Column/Title
@onready var move_window_button: Button = %MoveWindowButton
@onready var demolish_window_button: Button = %DemolishWindowButton
@onready var demolition_confirm_panel: PanelContainer = %DemolitionConfirmPanel
@onready var confirm_demolish_button: Button = %ConfirmDemolishButton
@onready var cancel_demolish_button: Button = %CancelDemolishButton
@onready var wall_palette_panel: PanelContainer = %WallPalettePanel
@onready var palette_button: Button = %PaletteButton
@onready var finish_options: Control = %FinishOptions
@onready var finish_actions: Control = %FinishActions
@onready var apply_finish_button: Button = %ApplyFinishButton
@onready var cancel_finish_button: Button = %CancelFinishButton
@onready var game_menu_button: Button = %GameMenuButton
@onready var game_menu_overlay: Control = %GameMenuOverlay
@onready var game_menu_panel: PanelContainer = $HudLayer/GameMenuOverlay/MenuPanel
@onready var restart_confirmation: Control = %RestartConfirmation
@onready var resume_button: Button = %ResumeButton
@onready var restart_button: Button = %RestartButton
@onready var cancel_restart_button: Button = %CancelRestartButton
@onready var confirm_restart_button: Button = %ConfirmRestartButton
@onready var language_option: OptionButton = %LanguageOption
@onready var music_volume_slider: HSlider = %MusicVolumeSlider
@onready var effects_volume_slider: HSlider = %EffectsVolumeSlider
@onready var customer_attention_card: PanelContainer = %CustomerAttentionCard
@onready var customer_attention_header: Label = %CustomerAttentionHeader
@onready var customer_attention_message: Label = %CustomerAttentionMessage
@onready var selection_camera: Camera3D = get_viewport().get_camera_3d()
var _selected_installation_type := ""
var _selected_installation_id := ""
var _display_slot_placement_active := false
var _selected_wall_id := ""
var _selected_finish_id := "ivory"
var _selection_anchor := Vector3.ZERO
var _selection_panel: Control
var _purchase_buttons: Array[Button] = []
var _treasury_overlay: Control
var _treasury_content: VBoxContainer
var _watch_context_panel: PanelContainer
var _watch_context_title: Label
var _watch_context_name: Label
var _watch_context_brand: Label
var _watch_context_purchase_price: Label
var _watch_context_sale_price: Label
var _watch_context_margin: Label
var _watch_context_valuation: Label
var _watch_context_move_button: Button
var _watch_context_edit_price_button: Button
var _watch_context_preview: Control
var _watch_context_image_preview: TextureRect
var _watch_context_preview_placeholder: Control
var _watch_context_preview_controls: Control
var _selected_watch_id := ""
var _customer_context_panel: PanelContainer
var _customer_context_title: Label
var _customer_context_details: Label
var _customer_context_portrait: TextureRect
var _customer_context_portrait_fallback: Control
var _customer_context_budget: ProgressBar
var _customer_context_quality: ProgressBar
var _customer_context_patience: ProgressBar
var _selected_customer_visitor_id := ""
var _auction_win_toast: PanelContainer
var _auction_win_queue: Array[Dictionary] = []
var _auction_win_overflow := 0
var _visitor_sale_toast: PanelContainer
var _visitor_sale_queue: Array[Dictionary] = []
var _last_bottom_action_active := ""
var _visitor_offer_card_height := 0.0
var _door_admission_button: Button
var _reputation_panel: PanelContainer
var _reputation_title: Label
var _reputation_rating_value: Label
var _reputation_rating_caption: Label
var _reputation_rating_stars: Label
var _reviews_content: VBoxContainer
var _reputation_hover: PanelContainer
var _reputation_hover_progress: Label
var _reputation_hover_bar: ProgressBar
var _reputation_hover_preview: TextureRect
var _reputation_hover_profile: Label
var _reputation_hover_hint: Label

func _ready() -> void:
	EventBus.stats_changed.connect(_on_stats_changed)
	EventBus.customer_reviews_changed.connect(_on_customer_reviews_changed)
	EventBus.monthly_expense_preview_changed.connect(_on_monthly_expense_preview_changed)
	EventBus.monthly_settlement_completed.connect(_on_monthly_settlement_completed)
	EventBus.placement_state_changed.connect(_on_placement_state_changed)
	EventBus.display_slot_placement_state_changed.connect(_on_display_slot_placement_state_changed)
	EventBus.placement_preview_changed.connect(_on_placement_preview_changed)
	EventBus.world_selection_changed.connect(_on_world_selection_changed)
	EventBus.watch_display_changed.connect(_on_watch_display_changed)
	EventBus.facility_installation_added.connect(_on_facility_installations_changed)
	EventBus.facility_installation_removed.connect(_on_facility_installations_changed)
	EventBus.facility_installations_reloaded.connect(_on_facility_installations_reloaded)
	EventBus.auction_resolved.connect(_on_auction_resolved)
	EventBus.visitor_sale_completed.connect(_on_visitor_sale_completed)
	EventBus.visitor_negotiation_card_visibility_changed.connect(_on_visitor_negotiation_card_visibility_changed)
	EventBus.visitor_negotiation_changed.connect(_on_visitor_negotiation_changed)
	furniture_button.pressed.connect(_on_furniture_pressed)
	facilities_button.pressed.connect(_on_facilities_pressed)
	auction_button.pressed.connect(_on_auction_pressed)
	inventory_button.pressed.connect(_on_inventory_pressed)
	money_button.pressed.connect(_open_treasury)
	reputation_button.mouse_entered.connect(_show_reputation_hover)
	reputation_button.mouse_exited.connect(_hide_reputation_hover)
	reputation_button.pressed.connect(_toggle_reputation_panel)
	cancel_placement_button.pressed.connect(_on_cancel_placement_pressed)
	move_window_button.pressed.connect(_on_move_window_pressed)
	demolish_window_button.pressed.connect(_on_demolish_window_pressed)
	confirm_demolish_button.pressed.connect(_on_confirm_demolish_pressed)
	cancel_demolish_button.pressed.connect(_on_cancel_demolish_pressed)
	apply_finish_button.pressed.connect(_on_apply_finish_pressed)
	cancel_finish_button.pressed.connect(_on_cancel_finish_pressed)
	palette_button.pressed.connect(_on_palette_pressed)
	game_menu_button.pressed.connect(_open_game_menu)
	resume_button.pressed.connect(_on_resume_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	cancel_restart_button.pressed.connect(_on_cancel_restart_pressed)
	confirm_restart_button.pressed.connect(_on_confirm_restart_pressed)
	language_option.item_selected.connect(_on_language_selected)
	music_volume_slider.value_changed.connect(_on_music_volume_changed)
	effects_volume_slider.value_changed.connect(_on_effects_volume_changed)
	for customer_node in get_tree().get_nodes_in_group("world_selectable_customer"):
		var customer := customer_node as CustomerVisitor
		if customer != null:
			customer.attention_indicator_changed.connect(_on_customer_attention_indicator_changed)
	get_viewport().size_changed.connect(_resize_customer_attention_card)
	_settings_manager().connect(&"language_changed", _on_language_changed)
	for button in get_tree().get_nodes_in_group("wall_finish_buttons"):
		(button as Button).pressed.connect(_on_finish_pressed.bind(String(button.get_meta("finish_id"))))
	furniture_panel.visible = false
	facilities_panel.visible = false
	placement_bar.visible = false
	window_context_panel.visible = false
	demolition_confirm_panel.visible = false
	wall_palette_panel.visible = false
	finish_options.visible = false
	finish_actions.visible = false
	_create_customer_context_panel()
	_create_reputation_panel()
	_create_reputation_hover()
	game_menu_overlay.visible = false
	customer_attention_card.visible = false
	_resize_customer_attention_card()
	restart_confirmation.visible = false
	_refresh_language_option()
	music_volume_slider.value = SettingsManager.music_volume
	effects_volume_slider.value = SettingsManager.effects_volume
	game_menu_overlay.add_to_group("game_menu_overlay")
	_create_watch_context_panel()
	_create_door_admission_button()
	_refresh_bottom_action_style()
	_populate_furniture_catalog()
	_populate_facilities_catalog()
	_refresh_commerce_access()
	_on_stats_changed(GameState.money, GameState.reputation)
	_on_customer_reviews_changed(GameState.get_customer_rating(), GameState.get_customer_reviews())
	_on_monthly_expense_preview_changed(FinanceManager.get_expense_preview(), FinanceManager.get_days_until_settlement())

func _on_stats_changed(money: int, reputation: int) -> void:
	money_label.text = _format_money(money)
	money_label.add_theme_color_override("font_color", Color(0.72, 0.18, 0.18, 1.0) if money < 0 else Color(0.964706, 0.933333, 0.858824, 1))
	_refresh_purchase_buttons()
	_refresh_treasury()
	_refresh_global_reputation(reputation)

func _on_auction_resolved(result: Dictionary) -> void:
	# Only a successful player acquisition is noteworthy at HUD level. Auction
	# rules and inventory ownership remain in AuctionManager and GameState.
	if not bool(result.get("awarded", false)) or String(result.get("winner", "")) != "player":
		return
	var lot := result.get("lot", {}) as Dictionary
	if lot.is_empty():
		return
	var entry := {"lot": lot.duplicate(true), "final_price": int(result.get("final_price", 0))}
	if is_instance_valid(_auction_win_toast):
		# A round has at most four lots; retaining eight protects the HUD from
		# repeated events while still bounding memory. Further wins are grouped.
		if _auction_win_queue.size() >= 8:
			_auction_win_overflow += 1
			return
		_auction_win_queue.append(entry)
		return
	_show_auction_win_toast(entry)

func _show_auction_win_toast(entry: Dictionary) -> void:
	var toast := AUCTION_WIN_TOAST.new() as PanelContainer
	_auction_win_toast = toast
	toast.name = "AuctionWinToast"
	# Commerce and Inventory panels render at 20; the acknowledgement remains
	# reachable without taking modal ownership of the game.
	toast.z_index = 30
	toast.tooltip_text = "Lote adjudicado. El aviso se cierra automáticamente cuando no está señalado ni enfocado."
	toast.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	toast.position = Vector2(-336, 16)
	toast.size = Vector2(320, 0)
	toast.custom_minimum_size = Vector2(320, 0)
	toast.add_theme_stylebox_override("panel", _make_auction_win_toast_style())
	get_node("HudLayer").add_child(toast)
	toast.dismissed.connect(_on_auction_win_toast_dismissed)
	toast.inventory_requested.connect(_on_auction_win_inventory_requested)
	toast.present(entry["lot"] as Dictionary, int(entry["final_price"]))

func _on_auction_win_toast_dismissed() -> void:
	if is_instance_valid(_auction_win_toast):
		_auction_win_toast.queue_free()
	_auction_win_toast = null
	if not _auction_win_queue.is_empty():
		_show_auction_win_toast(_auction_win_queue.pop_front())
	elif _auction_win_overflow > 0:
		# The queue limit is defensive; this compact acknowledgement prevents a
		# burst from silently losing the fact that more acquisitions occurred.
		EventBus.feedback_requested.emit("%d adjudicaciones adicionales ya están en tu inventario." % _auction_win_overflow, "info")
		_auction_win_overflow = 0

func _on_auction_win_inventory_requested() -> void:
	commerce_panel.call("close")
	inventory_panel.call("open")
	_on_auction_win_toast_dismissed()

func _make_auction_win_toast_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.04, 0.042, 0.98)
	style.border_color = Color(0.72, 0.57, 0.32, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	return style

func _on_visitor_sale_completed(presentation: Dictionary) -> void:
	# The manager supplies an item snapshot before its GameState removal; never
	# resolve the sold unit here because it no longer belongs to the boutique.
	if is_instance_valid(_visitor_sale_toast):
		if _visitor_sale_queue.size() >= 8:
			return
		_visitor_sale_queue.append(presentation.duplicate(true))
		return
	_show_visitor_sale_toast(presentation)

func _show_visitor_sale_toast(presentation: Dictionary) -> void:
	var toast := VISITOR_SALE_TOAST.new() as PanelContainer
	_visitor_sale_toast = toast
	toast.name = "VisitorSaleToast"
	toast.z_index = 30
	toast.tooltip_text = "Venta cerrada. El aviso se cierra automáticamente cuando no está señalado ni enfocado."
	toast.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	toast.position = Vector2(16, 16)
	toast.size = Vector2(320, 0)
	toast.custom_minimum_size = Vector2(320, 0)
	toast.add_theme_stylebox_override("panel", _make_auction_win_toast_style())
	get_node("HudLayer").add_child(toast)
	toast.dismissed.connect(_on_visitor_sale_toast_dismissed)
	toast.present(presentation)

func _on_visitor_sale_toast_dismissed() -> void:
	if is_instance_valid(_visitor_sale_toast):
		_visitor_sale_toast.queue_free()
	_visitor_sale_toast = null
	if not _visitor_sale_queue.is_empty():
		_show_visitor_sale_toast(_visitor_sale_queue.pop_front())

func _on_customer_reviews_changed(rating: float, reviews: Array[Dictionary]) -> void:
	var filled := clampi(roundi(rating), 0, 5)
	reputation_stars_label.text = "CLIENTES\n" + "★".repeat(filled) + "☆".repeat(5 - filled)
	reputation_progress.value = rating
	reputation_button.tooltip_text = "Valoración de clientes: %.1f/5 · Reputación de la maison: %d REP." % [rating, GameState.reputation]
	_refresh_reputation_panel(rating, reviews)

func _refresh_global_reputation(reputation: int) -> void:
	var progress := GameState.get_reputation_progress()
	global_reputation_value.text = str(reputation)
	if bool(progress.get("is_max_level", false)):
		global_reputation_ring.call("set_progress", 1.0)
		next_visitor_label.text = "REP. MÁX."
		next_visitor_label.tooltip_text = "%d ventas a visitantes · todos los niveles desbloqueados." % int(progress.get("sales", 0))
		_refresh_reputation_hover()
		return
	var sales := int(progress.get("sales", 0))
	var current_sales := int(progress.get("current_level_sales", 0))
	var next_sales := int(progress.get("next_level_sales", 1))
	global_reputation_ring.call("set_progress", float(sales - current_sales) / float(maxi(1, next_sales - current_sales)))
	next_visitor_label.text = "Ventas %d / %d" % [sales, next_sales]
	next_visitor_label.tooltip_text = "Faltan %d ventas a visitantes para REP. %d." % [next_sales - sales, reputation + 1]
	_refresh_reputation_hover()

func _get_next_visitor_unlock(reputation: int) -> Dictionary:
	var next_profile: Dictionary = {}
	var target := 0
	for profile in DataRegistry.get_visitor_profiles():
		var threshold := int(profile.get("min_reputation", 0))
		if threshold > reputation and (next_profile.is_empty() or threshold < target):
			next_profile = profile
			target = threshold
	if next_profile.is_empty():
		return {}
	var previous_threshold := 0
	for profile in DataRegistry.get_visitor_profiles():
		var threshold := int(profile.get("min_reputation", 0))
		if threshold <= reputation:
			previous_threshold = maxi(previous_threshold, threshold)
	return {"name": String(next_profile.get("name", "Cliente")), "target": target, "previous_threshold": previous_threshold, "profile": next_profile.duplicate(true)}

func _create_reputation_hover() -> void:
	_reputation_hover = PanelContainer.new()
	_reputation_hover.name = "ReputationHover"
	_reputation_hover.visible = false
	_reputation_hover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reputation_hover.custom_minimum_size = Vector2(288, 148)
	_reputation_hover.size = Vector2(288, 148)
	_reputation_hover.z_index = 25
	_reputation_hover.add_theme_stylebox_override("panel", _make_reputation_hover_style())
	get_node("HudLayer").add_child(_reputation_hover)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	_reputation_hover.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	margin.add_child(column)
	var heading := Label.new()
	heading.text = "REPUTACIÓN DE LA MAISON"
	heading.add_theme_font_size_override("font_size", 12)
	heading.add_theme_color_override("font_color", Color(0.95, 0.78, 0.35, 1.0))
	column.add_child(heading)
	_reputation_hover_progress = Label.new()
	_reputation_hover_progress.add_theme_font_size_override("font_size", 13)
	_reputation_hover_progress.add_theme_color_override("font_color", Color(0.96, 0.91, 0.8, 1.0))
	column.add_child(_reputation_hover_progress)
	_reputation_hover_bar = ProgressBar.new()
	_reputation_hover_bar.custom_minimum_size = Vector2(0, 6)
	_reputation_hover_bar.max_value = 1.0
	_reputation_hover_bar.show_percentage = false
	_reputation_hover_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reputation_hover_bar.add_theme_stylebox_override("background", _make_reputation_progress_style(Color(0.12, 0.11, 0.09, 1.0)))
	_reputation_hover_bar.add_theme_stylebox_override("fill", _make_reputation_progress_style(Color(0.82, 0.63, 0.29, 1.0)))
	column.add_child(_reputation_hover_bar)
	var preview_row := HBoxContainer.new()
	preview_row.custom_minimum_size = Vector2(0, 48)
	preview_row.add_theme_constant_override("separation", 8)
	column.add_child(preview_row)
	_reputation_hover_preview = TextureRect.new()
	_reputation_hover_preview.custom_minimum_size = Vector2(46, 46)
	_reputation_hover_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_reputation_hover_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_row.add_child(_reputation_hover_preview)
	var preview_copy := VBoxContainer.new()
	preview_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_row.add_child(preview_copy)
	_reputation_hover_profile = Label.new()
	_reputation_hover_profile.add_theme_font_size_override("font_size", 13)
	_reputation_hover_profile.add_theme_color_override("font_color", Color(0.96, 0.91, 0.8, 1.0))
	preview_copy.add_child(_reputation_hover_profile)
	_reputation_hover_hint = Label.new()
	_reputation_hover_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reputation_hover_hint.add_theme_font_size_override("font_size", 11)
	_reputation_hover_hint.add_theme_color_override("font_color", Color(0.78, 0.75, 0.67, 1.0))
	preview_copy.add_child(_reputation_hover_hint)

func _show_reputation_hover() -> void:
	_refresh_reputation_hover()
	var button_rect := reputation_button.get_global_rect()
	_reputation_hover.global_position = Vector2(button_rect.position.x, button_rect.position.y - _reputation_hover.size.y - 8.0)
	_reputation_hover.visible = true

func _hide_reputation_hover() -> void:
	if _reputation_hover != null:
		_reputation_hover.visible = false

func _refresh_reputation_hover() -> void:
	if _reputation_hover_progress == null:
		return
	var reputation := GameState.get_reputation_level()
	var progress := GameState.get_reputation_progress()
	var unlock := _get_next_visitor_unlock(reputation)
	if bool(progress.get("is_max_level", false)):
		_reputation_hover_progress.text = "REP. 12 · %d ventas a visitantes" % int(progress.get("sales", 0))
		_reputation_hover_bar.value = 1.0
		_reputation_hover_preview.texture = null
		_reputation_hover_profile.text = "MAISON CONSOLIDADA"
		_reputation_hover_hint.text = "Todos los niveles de reputación actuales están desbloqueados."
		return
	var sales := int(progress.get("sales", 0))
	var start := int(progress.get("current_level_sales", 0))
	var target := int(progress.get("next_level_sales", 1))
	var profile := unlock.get("profile", {}) as Dictionary
	_reputation_hover_progress.text = "%d / %d ventas · REP. %d → %d" % [sales, target, reputation, reputation + 1]
	_reputation_hover_bar.value = clampf(float(sales - start) / float(maxi(1, target - start)), 0.0, 1.0)
	_reputation_hover_profile.text = "PRÓXIMO · %s" % String(unlock.get("name", "Nivel de reputación"))
	_reputation_hover_hint.text = String(profile.get("unlock_hint", "Completa ventas a visitantes para subir de nivel."))
	var preview_path := String(profile.get("preview_image_path", ""))
	_reputation_hover_preview.texture = load(preview_path) as Texture2D if not preview_path.is_empty() else null

func _make_reputation_hover_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.04, 0.042, 0.98)
	style.border_color = Color(0.72, 0.57, 0.32, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	return style

func _make_rating_summary_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.95, 0.91, 0.80, 0.48)
	style.border_color = Color(0.72, 0.57, 0.32, 0.48)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	return style

func _make_reputation_progress_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(3)
	return style

func _toggle_reputation_panel() -> void:
	_reputation_panel.visible = not _reputation_panel.visible
	if not _reputation_panel.visible:
		reputation_button.grab_focus()

func _create_reputation_panel() -> void:
	_reputation_panel = PanelContainer.new()
	_reputation_panel.name = "ReputationPanel"
	_reputation_panel.visible = false
	_reputation_panel.custom_minimum_size = Vector2(330, 0)
	_reputation_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	# Se abre sobre la tarjeta de reputación y deja libre la barra inferior.
	_reputation_panel.position = Vector2(16, -456)
	_reputation_panel.size = Vector2(330, 360)
	_reputation_panel.add_theme_stylebox_override("panel", _make_catalog_card_style())
	get_node("HudLayer").add_child(_reputation_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	_reputation_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	_reputation_title = Label.new()
	_reputation_title.text = "VALORACIÓN DE CLIENTES"
	_reputation_title.add_theme_font_size_override("font_size", 18)
	_reputation_title.add_theme_color_override("font_color", Color(0.14, 0.105, 0.078, 1.0))
	column.add_child(_reputation_title)
	var rating_summary := PanelContainer.new()
	rating_summary.custom_minimum_size = Vector2(0, 50)
	rating_summary.add_theme_stylebox_override("panel", _make_rating_summary_style())
	column.add_child(rating_summary)
	var rating_margin := MarginContainer.new()
	rating_margin.add_theme_constant_override("margin_left", 12)
	rating_margin.add_theme_constant_override("margin_top", 6)
	rating_margin.add_theme_constant_override("margin_right", 12)
	rating_margin.add_theme_constant_override("margin_bottom", 6)
	rating_summary.add_child(rating_margin)
	var rating_row := HBoxContainer.new()
	rating_row.add_theme_constant_override("separation", 12)
	rating_margin.add_child(rating_row)
	_reputation_rating_value = Label.new()
	_reputation_rating_value.custom_minimum_size = Vector2(64, 0)
	_reputation_rating_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reputation_rating_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_reputation_rating_value.add_theme_font_size_override("font_size", 24)
	_reputation_rating_value.add_theme_color_override("font_color", Color(0.55, 0.38, 0.13, 1.0))
	rating_row.add_child(_reputation_rating_value)
	var rating_details := VBoxContainer.new()
	rating_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rating_details.add_theme_constant_override("separation", 4)
	rating_row.add_child(rating_details)
	_reputation_rating_caption = Label.new()
	_reputation_rating_caption.add_theme_font_size_override("font_size", 11)
	_reputation_rating_caption.add_theme_color_override("font_color", Color(0.35, 0.29, 0.20, 1.0))
	rating_details.add_child(_reputation_rating_caption)
	_reputation_rating_stars = Label.new()
	_reputation_rating_stars.add_theme_font_size_override("font_size", 18)
	_reputation_rating_stars.add_theme_color_override("font_color", Color(0.72, 0.57, 0.32, 1.0))
	rating_details.add_child(_reputation_rating_stars)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 190)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_reviews_content = VBoxContainer.new()
	_reviews_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reviews_content.add_theme_constant_override("separation", 7)
	scroll.add_child(_reviews_content)
	var close_button := Button.new()
	close_button.text = "Cerrar"
	close_button.pressed.connect(_toggle_reputation_panel)
	column.add_child(close_button)

func _refresh_reputation_panel(rating: float, reviews: Array[Dictionary]) -> void:
	if _reputation_title == null or _reputation_rating_value == null or _reputation_rating_stars == null or _reviews_content == null:
		return
	var rating_text := str(int(rating)) if is_equal_approx(rating, roundf(rating)) else "%.1f" % rating
	_reputation_rating_value.text = "%s / 5" % rating_text
	_reputation_rating_caption.text = "VALORACIÓN MEDIA DE CLIENTES"
	var filled_stars := clampi(roundi(rating), 0, 5)
	_reputation_rating_stars.text = "★".repeat(filled_stars) + "☆".repeat(5 - filled_stars)
	for child in _reviews_content.get_children():
		child.queue_free()
	if reviews.is_empty():
		var empty := Label.new()
		empty.text = "Aún no hay reseñas. Las visitas resolverán la primera valoración."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_color_override("font_color", Color(0.14, 0.105, 0.078, 0.72))
		_reviews_content.add_child(empty)
		return
	for index in range(reviews.size() - 1, -1, -1):
		var review := reviews[index]
		_reviews_content.add_child(_make_review_card(review))

func _make_review_card(review: Dictionary) -> PanelContainer:
	var rating := clampi(int(review.get("rating", 0)), 1, 5)
	var sentiment := _review_sentiment(rating)
	var badge_color := sentiment["badge"] as Color
	var background_color := sentiment["background"] as Color
	var border_color := sentiment["border"] as Color
	var ink_color := sentiment["ink"] as Color
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _make_review_card_style(background_color, border_color))
	card.tooltip_text = "%d de 5 estrellas · %s" % [rating, String(sentiment["label"])]
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 9)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	margin.add_child(row)
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(38, 38)
	badge.add_theme_stylebox_override("panel", _make_review_badge_style(badge_color))
	row.add_child(badge)
	var face := Label.new()
	face.text = String(sentiment["face"])
	face.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	face.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	face.add_theme_font_size_override("font_size", 21)
	face.tooltip_text = String(sentiment["label"])
	badge.add_child(face)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 2)
	row.add_child(details)
	var metadata := Label.new()
	metadata.text = "%s  · %s · Día %d" % ["★".repeat(rating), String(review.get("customer_name", "Cliente")), int(review.get("day", 1))]
	metadata.add_theme_font_size_override("font_size", 12)
	metadata.add_theme_color_override("font_color", ink_color)
	details.add_child(metadata)
	var text := Label.new()
	text.text = String(review.get("text", ""))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_font_size_override("font_size", 13)
	text.add_theme_color_override("font_color", Color(0.14, 0.105, 0.078, 0.9))
	details.add_child(text)
	return card

func _review_sentiment(rating: int) -> Dictionary:
	# The face is derived from rating so older saves using ☺/☹ receive the new
	# presentation without touching their persisted review data.
	match rating:
		5:
			return {"face": "🤩", "label": "Excelente", "badge": Color(0.73, 0.55, 0.16, 1), "background": Color(0.98, 0.94, 0.82, 1), "border": Color(0.72, 0.54, 0.20, 0.6), "ink": Color(0.43, 0.29, 0.07, 1)}
		4:
			return {"face": "😊", "label": "Muy buena", "badge": Color(0.30, 0.57, 0.38, 1), "background": Color(0.91, 0.96, 0.89, 1), "border": Color(0.30, 0.57, 0.38, 0.48), "ink": Color(0.12, 0.35, 0.19, 1)}
		3:
			return {"face": "🙂", "label": "Correcta", "badge": Color(0.35, 0.49, 0.64, 1), "background": Color(0.89, 0.93, 0.96, 1), "border": Color(0.35, 0.49, 0.64, 0.45), "ink": Color(0.13, 0.27, 0.40, 1)}
		2:
			return {"face": "😕", "label": "Mejorable", "badge": Color(0.80, 0.48, 0.16, 1), "background": Color(0.98, 0.93, 0.85, 1), "border": Color(0.80, 0.48, 0.16, 0.52), "ink": Color(0.47, 0.23, 0.05, 1)}
		_:
			return {"face": "😣", "label": "Insatisfactoria", "badge": Color(0.68, 0.25, 0.22, 1), "background": Color(0.98, 0.89, 0.87, 1), "border": Color(0.68, 0.25, 0.22, 0.5), "ink": Color(0.43, 0.12, 0.10, 1)}

func _make_review_card_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	return style

func _make_review_badge_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(19)
	return style

func _on_customer_attention_indicator_changed(is_visible: bool, message: String, bubble_style: int) -> void:
	# Los pensamientos se presentan sobre el personaje en el mundo, no como una
	# tarjeta fija del HUD.
	customer_attention_card.visible = false

func _resize_customer_attention_card() -> void:
	# Conserva la tarjeta en una esquina fija sin invadir la pantalla en ventanas pequeñas.
	var viewport_width := get_viewport().get_visible_rect().size.x
	var card_width := clampf(viewport_width * 0.45, 220.0, 320.0)
	customer_attention_card.offset_left = -card_width - 16.0
	customer_attention_card.offset_right = -16.0
	customer_attention_card.offset_top = 32.0 + _visitor_offer_card_height

func _on_visitor_negotiation_card_visibility_changed(is_visible: bool, occupied_height: float) -> void:
	_visitor_offer_card_height = occupied_height + 12.0 if is_visible else 0.0
	_resize_customer_attention_card()

func _on_monthly_expense_preview_changed(preview: Dictionary, days_until_settlement: int) -> void:
	var total := int(preview.get("total", 0))
	var personnel := int(preview.get("personnel", 0))
	finance_label.text = "Cierre: −%s · %d días · personal: −%s" % [_format_money(total), days_until_settlement, _format_money(personnel)]
	finance_label.tooltip_text = "Alquiler %s · Luz y agua %s · Tributos y cuotas %s · Personal %s" % [_format_money(int(preview.get("rent", 0))), _format_money(int(preview.get("utilities", 0))), _format_money(int(preview.get("taxes", 0))), _format_money(personnel)]
	_refresh_treasury()

func _on_monthly_settlement_completed(settlement: Dictionary, resulting_balance: int) -> void:
	finance_label.text = "Cierre aplicado: −%s · saldo %s" % [_format_money(int(settlement.get("total", 0))), _format_money(resulting_balance)]
	finance_label.tooltip_text = "Alquiler %s · Luz y agua %s · Tributos y cuotas %s · Personal %s" % [_format_money(int(settlement.get("rent", 0))), _format_money(int(settlement.get("utilities", 0))), _format_money(int(settlement.get("taxes", 0))), _format_money(int(settlement.get("personnel", 0)))]
	_refresh_treasury()

func _open_treasury() -> void:
	if _treasury_overlay == null:
		_create_treasury_overlay()
	_treasury_overlay.visible = true
	_refresh_treasury()

func _close_treasury() -> void:
	if _treasury_overlay != null:
		_treasury_overlay.visible = false
	money_button.grab_focus()

func _on_treasury_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close_treasury()

func _create_treasury_overlay() -> void:
	_treasury_overlay = Control.new()
	_treasury_overlay.name = "TreasuryOverlay"
	_treasury_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_treasury_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.015, 0.012, 0.01, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(_on_treasury_dim_input)
	_treasury_overlay.add_child(dim)
	var panel := PanelContainer.new()
	# A fixed, centred document reads as a receipt rather than a generic full
	# screen settings panel. The internal scroll keeps longer financial histories
	# usable without changing the document's visual hierarchy.
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-310.0, -340.0)
	panel.size = Vector2(620.0, 680.0)
	panel.add_theme_stylebox_override("panel", _make_catalog_card_style())
	_treasury_overlay.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	_treasury_content = VBoxContainer.new()
	_treasury_content.add_theme_constant_override("separation", 12)
	_treasury_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_treasury_content)
	get_node("HudLayer").add_child(_treasury_overlay)

func _refresh_treasury() -> void:
	if _treasury_content == null:
		return
	for child in _treasury_content.get_children():
		child.queue_free()
	var summary := GameState.get_finance_summary()
	var last_summary := GameState.get_last_closed_finance_summary()
	var preview := FinanceManager.get_expense_preview()
	var ink := Color(0.137255, 0.105882, 0.0784314, 1.0)
	var muted_ink := Color(0.137255, 0.105882, 0.0784314, 0.72)
	var gold := Color(0.68, 0.53, 0.27, 0.62)
	_add_treasury_header()
	_add_treasury_separator(gold)
	var balance_card := _add_treasury_card(_make_treasury_balance_style())
	_add_treasury_label_to(balance_card, "SALDO DISPONIBLE", 12, muted_ink)
	_add_treasury_label_to(balance_card, _format_money(GameState.money), 30, Color(0.72, 0.18, 0.18, 1.0) if GameState.money < 0 else ink)
	_add_treasury_label_to(balance_card, "Resultado del período  %s" % _format_signed_money(int(summary["profit"])), 14, muted_ink)
	_add_treasury_separator(gold)
	var activity := _add_treasury_section("ACTIVIDAD DEL PERÍODO")
	_add_treasury_row(activity, "Ventas y entregas", "+%s" % _format_money(int(summary["sales"])), Color(0.22, 0.42, 0.28, 1.0))
	_add_treasury_row(activity, "Reembolsos", "+%s" % _format_money(int(summary["refunds"])), Color(0.22, 0.42, 0.28, 1.0))
	_add_treasury_row(activity, "Compras e instalaciones", "−%s" % _format_money(int(summary["purchases"])))
	_add_treasury_row(activity, "Otros gastos obligatorios", "−%s" % _format_money(int(summary["other_mandatory"])))
	if not last_summary.is_empty():
		_add_treasury_separator(gold)
		var last_close := _add_treasury_section("ÚLTIMO CIERRE")
		_add_treasury_row(last_close, "Resultado del mes", _format_signed_money(int(last_summary["profit"])))
		_add_treasury_row(last_close, "Gastos operativos", "−%s" % _format_money(int(last_summary["operating_closing"])))
	_add_treasury_separator(gold)
	var upcoming := _add_treasury_card(_make_treasury_card_style())
	_add_treasury_label_to(upcoming, "PRÓXIMO CIERRE OBLIGATORIO", 12, muted_ink)
	_add_treasury_label_to(upcoming, "En %d días" % FinanceManager.get_days_until_settlement(), 18, ink)
	_add_treasury_row(upcoming, "Alquiler", "−%s" % _format_money(int(preview["rent"])))
	_add_treasury_row(upcoming, "Luz y agua", "−%s" % _format_money(int(preview["utilities"])))
	_add_treasury_row(upcoming, "Tributos y cuotas", "−%s" % _format_money(int(preview["taxes"])))
	_add_treasury_row(upcoming, "Personal", "−%s" % _format_money(int(preview["personnel"])))
	_add_treasury_separator_to(upcoming, gold)
	_add_treasury_row(upcoming, "TOTAL A CARGAR", "−%s" % _format_money(int(preview["total"])), ink, 16)
	if GameState.money < 0:
		_add_treasury_alert("TESORERÍA NEGATIVA", "Compras e inversiones suspendidas. Vende o entrega pedidos para recuperar liquidez.", Color(0.72, 0.18, 0.18, 1.0))
	elif GameState.money < int(preview["total"]):
		_add_treasury_alert("LIQUIDEZ INSUFICIENTE", "El próximo cierre supera el saldo disponible.", Color(0.72, 0.38, 0.12, 1.0))
	var close_button := Button.new()
	close_button.text = "Cerrar · Esc"
	close_button.custom_minimum_size = Vector2(0, 40)
	close_button.pressed.connect(_close_treasury)
	_treasury_content.add_child(close_button)

func _add_treasury_header() -> void:
	var header := HBoxContainer.new()
	var title := Label.new()
	title.text = "TESORERÍA"
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", Color(0.137255, 0.105882, 0.0784314, 1.0))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var reference := Label.new()
	reference.text = "LIBRO DE CAJA"
	reference.add_theme_font_size_override("font_size", 11)
	reference.add_theme_color_override("font_color", Color(0.137255, 0.105882, 0.0784314, 0.62))
	header.add_child(reference)
	_treasury_content.add_child(header)

func _add_treasury_card(style: StyleBoxFlat) -> VBoxContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	card.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 7)
	margin.add_child(content)
	_treasury_content.add_child(card)
	return content

func _add_treasury_section(title_text: String) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)
	_add_treasury_label_to(section, title_text, 12, Color(0.137255, 0.105882, 0.0784314, 0.68))
	_treasury_content.add_child(section)
	return section

func _add_treasury_row(parent: Container, description: String, amount: String, amount_color: Color = Color(0.137255, 0.105882, 0.0784314, 0.9), amount_size: int = 14) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = description
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.137255, 0.105882, 0.0784314, 0.84))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(label)
	var value := Label.new()
	value.text = amount
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.add_theme_font_size_override("font_size", amount_size)
	value.add_theme_color_override("font_color", amount_color)
	value.custom_minimum_size = Vector2(110, 0)
	row.add_child(value)
	parent.add_child(row)

func _add_treasury_label_to(parent: Container, text: String, font_size: int, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)

func _add_treasury_separator(color: Color) -> void:
	_add_treasury_separator_to(_treasury_content, color)

func _add_treasury_separator_to(parent: Container, color: Color) -> void:
	var separator := HSeparator.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	separator.add_theme_stylebox_override("separator", style)
	parent.add_child(separator)

func _add_treasury_alert(title_text: String, message: String, color: Color) -> void:
	var alert := _add_treasury_card(_make_treasury_alert_style(color))
	_add_treasury_label_to(alert, title_text, 12, color)
	_add_treasury_label_to(alert, message, 14, Color(0.137255, 0.105882, 0.0784314, 0.9))

func _make_treasury_balance_style() -> StyleBoxFlat:
	var style := _make_treasury_card_style()
	style.bg_color = Color(0.965, 0.935, 0.855, 1.0)
	return style

func _make_treasury_card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.945, 0.91, 0.83, 1.0)
	style.border_color = Color(0.68, 0.53, 0.27, 0.52)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	return style

func _make_treasury_alert_style(color: Color) -> StyleBoxFlat:
	var style := _make_treasury_card_style()
	style.bg_color = Color(0.98, 0.93, 0.84, 1.0)
	style.border_color = Color(color.r, color.g, color.b, 0.58)
	return style

func _add_treasury_label(text: String, font_size: int, color: Color = Color(0.137255, 0.105882, 0.0784314, 0.9)) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	_treasury_content.add_child(label)

func _format_signed_money(value: int) -> String:
	return ("+" if value >= 0 else "") + _format_money(value)

func _on_furniture_pressed() -> void:
	furniture_panel.visible = not furniture_panel.visible
	facilities_panel.visible = false
	commerce_panel.call("close")
	inventory_panel.call("close")

func _on_facilities_pressed() -> void:
	facilities_panel.visible = not facilities_panel.visible
	furniture_panel.visible = false
	commerce_panel.call("close")
	inventory_panel.call("close")

func _on_auction_pressed() -> void:
	if not GameState.can_access_commerce():
		EventBus.feedback_requested.emit("Instala un Punto de venta para desbloquear las pujas.", "info")
		return
	commerce_panel.call("toggle")
	inventory_panel.call("close")
	furniture_panel.visible = false
	facilities_panel.visible = false
	_refresh_bottom_action_style()

func _on_inventory_pressed() -> void:
	if not GameState.can_access_commerce():
		EventBus.feedback_requested.emit("Instala un Punto de venta para desbloquear el inventario.", "info")
		return
	inventory_panel.call("toggle")
	commerce_panel.call("close")
	furniture_panel.visible = false
	facilities_panel.visible = false
	_refresh_bottom_action_style()

func _on_facility_installations_changed(_installation = null, _refund = null) -> void:
	_refresh_commerce_access()

func _on_facility_installations_reloaded() -> void:
	_refresh_commerce_access()

func _refresh_commerce_access() -> void:
	var commerce_unlocked := GameState.can_access_commerce()
	auction_button.disabled = not commerce_unlocked
	inventory_button.disabled = not commerce_unlocked
	auction_button.tooltip_text = "Abrir pujas del Salón de Lotes" if commerce_unlocked else "Construye un Punto de venta para desbloquear las pujas."
	inventory_button.tooltip_text = "Abrir inventario y vitrina" if commerce_unlocked else "Construye un Punto de venta para desbloquear el inventario."
	_set_bottom_action_content_disabled(auction_button, not commerce_unlocked)
	_set_bottom_action_content_disabled(inventory_button, not commerce_unlocked)
	if not commerce_unlocked:
		commerce_panel.call("close")
		inventory_panel.call("close")

func _populate_furniture_catalog() -> void:
	for child in furniture_grid.get_children():
		child.queue_free()
	_purchase_buttons.clear()
	if furniture_definitions.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No hay elementos disponibles por el momento."
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.add_theme_color_override("font_color", Color(0.137255, 0.105882, 0.0784314, 1.0))
		furniture_grid.add_child(empty_label)
		return
	for definition in furniture_definitions:
		if definition != null:
			furniture_grid.add_child(_create_catalog_card(definition, false))

func _populate_facilities_catalog() -> void:
	for child in facilities_grid.get_children():
		child.queue_free()
	for definition in facility_definitions:
		if definition != null:
			facilities_grid.add_child(_create_catalog_card(definition, true))

func _create_catalog_card(definition, is_facility: bool) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(210.0, 228.0)
	card.add_theme_stylebox_override("panel", _make_catalog_card_style())
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	margin.add_child(column)
	column.add_child(_create_model_thumbnail(definition))
	var name_label := Label.new()
	name_label.text = definition.display_name
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color(0.137255, 0.105882, 0.0784314, 1.0))
	column.add_child(name_label)
	var stats_label := Label.new()
	stats_label.text = _catalog_item_stats(definition, is_facility)
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_font_size_override("font_size", 11)
	stats_label.add_theme_color_override("font_color", Color(0.137255, 0.105882, 0.0784314, 0.82))
	column.add_child(stats_label)
	var select_button := Button.new()
	select_button.custom_minimum_size = Vector2(0.0, 36.0)
	select_button.text = "%s · %s" % ["Instalar" if is_facility else "Comprar", _format_money(definition.price)]
	if is_facility:
		select_button.tooltip_text = "Colocar %s en la tienda." % definition.display_name
	select_button.add_theme_color_override("font_color", Color(0.137255, 0.105882, 0.0784314, 1.0))
	select_button.add_theme_stylebox_override("normal", _make_catalog_button_style())
	select_button.pressed.connect(_on_catalog_item_pressed.bind(definition.item_id, is_facility))
	select_button.set_meta("price", definition.price)
	_purchase_buttons.append(select_button)
	column.add_child(select_button)
	_refresh_purchase_buttons()
	return card

func _catalog_item_stats(definition, is_facility: bool) -> String:
	if is_facility and definition is FacilityDefinition:
		var facility := definition as FacilityDefinition
		var footprint := facility.footprint_half_extents * 2.0
		var surface := "%.1f × %.1f m" % [footprint.x, footprint.y]
		if facility.is_display_facility():
			var levels: Dictionary = {}
			for slot in facility.display_slots:
				levels[snappedf((slot.get("position", Vector3.ZERO) as Vector3).y, 0.01)] = true
			return "HUECOS  %d · NIVELES  %d\nSUPERFICIE  %s" % [facility.display_slots.size(), levels.size(), surface]
		return "COMERCIO · %s\nSUPERFICIE  %s" % ["ÚNICO" if facility.max_installations == 1 else "DISPONIBLE", surface]
	if definition is PlaceableDefinition:
		var furniture := definition as PlaceableDefinition
		var opening_width := furniture.opening_half_width * 2.0
		var opening_height := furniture.opening_half_height * 2.0
		return "PARED INTERIOR · APERTURA\n%.1f × %.1f m" % [opening_width, opening_height]
	return "OBJETO DE BOUTIQUE"

func _refresh_purchase_buttons() -> void:
	for button in _purchase_buttons:
		if not is_instance_valid(button):
			continue
		var price := int(button.get_meta("price", 0))
		button.disabled = not GameState.can_make_voluntary_payment(price)
		button.tooltip_text = "Inversión suspendida: recupera liquidez con ventas o entregas." if GameState.money < 0 else "Fondos insuficientes: requiere %s." % _format_money(price) if not GameState.can_afford(price) else ""

## Each catalog card owns a small, isolated 3D world. This keeps preview-only
## cameras, lighting and model instances out of the workshop gameplay world.
func _create_model_thumbnail(definition) -> TextureRect:
	var preview := TextureRect.new()
	preview.custom_minimum_size = Vector2(0.0, 74.0)
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var thumbnail_viewport := SubViewport.new()
	thumbnail_viewport.size = Vector2i(320, 192)
	thumbnail_viewport.transparent_bg = false
	thumbnail_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	thumbnail_viewport.world_3d = World3D.new()
	preview.add_child(thumbnail_viewport)
	preview.texture = thumbnail_viewport.get_texture()

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	# Both Mobiliario and Equipamiento use this shared preview world. A light
	# neutral background keeps the product readable and consistent with its card.
	environment.background_color = Color(0.975, 0.963, 0.93, 1.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.88, 0.8, 0.67, 1.0)
	environment.ambient_light_energy = 0.75
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	thumbnail_viewport.add_child(world_environment)

	var model_root := Node3D.new()
	thumbnail_viewport.add_child(model_root)
	if definition.visual_scene != null:
		var model := definition.visual_scene.instantiate() as Node3D
		if model != null:
			model.scale = definition.visual_scale
			model_root.add_child(model)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	key_light.light_color = Color(1.0, 0.86, 0.63, 1.0)
	key_light.light_energy = 1.5
	key_light.shadow_enabled = true
	thumbnail_viewport.add_child(key_light)
	var fill_light := OmniLight3D.new()
	fill_light.position = Vector3(-2.0, 2.0, 3.0)
	fill_light.light_color = Color(0.55, 0.7, 1.0, 1.0)
	fill_light.light_energy = 1.2
	fill_light.omni_range = 12.0
	thumbnail_viewport.add_child(fill_light)
	var camera := Camera3D.new()
	camera.fov = 32.0
	thumbnail_viewport.add_child(camera)
	camera.make_current()
	# Defer until imported scenes have entered the dedicated World3D, then frame
	# their transformed mesh bounds rather than relying on authoring scale.
	_configure_thumbnail_camera.call_deferred(model_root, camera)
	return preview

func _configure_thumbnail_camera(model_root: Node3D, camera: Camera3D) -> void:
	var bounds := _get_model_bounds(model_root)
	var center := bounds.get_center()
	var radius := maxf(0.25, maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z)) * 0.5)
	var view_direction := Vector3(1.0, 0.65, 1.0).normalized()
	var distance := radius / sin(deg_to_rad(camera.fov * 0.5)) * 1.22
	camera.position = center + view_direction * distance
	camera.look_at(center, Vector3.UP)
	# Keep the isolated viewport rendering after framing. Otherwise a catalog
	# opened from a hidden state can show its blank render target instead.
	camera.get_viewport().render_target_update_mode = SubViewport.UPDATE_ALWAYS

func _get_model_bounds(model_root: Node3D) -> AABB:
	var has_mesh := false
	var bounds := AABB()
	for node in model_root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var mesh_bounds := mesh_instance.get_aabb()
		for x in [mesh_bounds.position.x, mesh_bounds.end.x]:
			for y in [mesh_bounds.position.y, mesh_bounds.end.y]:
				for z in [mesh_bounds.position.z, mesh_bounds.end.z]:
					var point := model_root.to_local(mesh_instance.global_transform * Vector3(x, y, z))
					if has_mesh:
						bounds = bounds.expand(point)
					else:
						bounds = AABB(point, Vector3.ZERO)
						has_mesh = true
	return bounds if has_mesh else AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)

func _on_catalog_item_pressed(item_id: String, is_facility: bool) -> void:
	if is_facility:
		EventBus.facility_item_selected.emit(item_id)
	else:
		EventBus.facade_item_selected.emit(item_id)

func _make_catalog_card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.92, 0.875, 0.78, 1.0)
	style.border_color = Color(0.68, 0.53, 0.27, 0.62)
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	return style

func _make_catalog_button_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.82, 0.69, 0.39, 1.0)
	style.set_corner_radius_all(6)
	return style

func _on_cancel_placement_pressed() -> void:
	EventBus.placement_cancel_requested.emit()

func _on_placement_state_changed(active: bool, item_name: String) -> void:
	placement_bar.visible = active
	if active:
		furniture_panel.visible = false
		facilities_panel.visible = false
		placement_instruction_label.text = "Elige un hueco iluminado de una vitrina · clic izquierdo para confirmar · Esc para cancelar" if _display_slot_placement_active else "%s · apunta a una pared compatible · Q/E para rotar" % item_name
		placement_instruction_label.modulate = Color(0.95, 0.78, 0.35, 1.0)
	else:
		placement_instruction_label.text = ""

func _on_display_slot_placement_state_changed(active: bool) -> void:
	_display_slot_placement_active = active

func _on_placement_preview_changed(is_valid: bool, message: String) -> void:
	if not placement_bar.visible:
		return
	placement_instruction_label.text = message + " · Esc o clic derecho para cancelar"
	placement_instruction_label.modulate = Color(0.95, 0.78, 0.35, 1.0) if is_valid else Color(1.0, 0.38, 0.32, 1.0)

func _on_world_selection_changed(selection_type: String, selection_id: String, anchor_position: Vector3) -> void:
	# A second click on the same visitor is a compact-card toggle, not a gameplay
	# action. Clear the shared selection too, so its world highlight follows suit.
	if selection_type == "customer" and selection_id == _selected_customer_visitor_id and _customer_context_panel.visible:
		_selected_customer_visitor_id = ""
		EventBus.world_selection_changed.emit("", "", Vector3.ZERO)
		return
	window_context_panel.visible = selection_type == "window" or selection_type == "facility"
	_watch_context_panel.visible = selection_type == "displayed_watch"
	_customer_context_panel.visible = selection_type == "customer"
	wall_palette_panel.visible = selection_type == "wall"
	demolition_confirm_panel.visible = false
	_selected_installation_type = selection_type if selection_type == "window" or selection_type == "facility" else ""
	_selected_installation_id = selection_id if not _selected_installation_type.is_empty() else ""
	_selected_wall_id = selection_id if selection_type == "wall" else ""
	_selected_watch_id = selection_id if selection_type == "displayed_watch" else ""
	_selected_customer_visitor_id = selection_id if selection_type == "customer" else ""
	_selection_anchor = anchor_position
	_selection_panel = null
	if selection_type == "window" or selection_type == "facility":
		installation_context_title.text = "Ventana seleccionada" if selection_type == "window" else "Instalación seleccionada"
		installation_context_title.tooltip_text = "Seleccionada · usa el botón Mover para reubicarla"
		_selection_panel = window_context_panel
	elif selection_type == "wall":
		_selection_panel = wall_palette_panel
	elif selection_type == "displayed_watch":
		_configure_watch_context(selection_id)
		_selection_panel = _watch_context_panel
	elif selection_type == "customer":
		_configure_customer_context(selection_id)
		if _customer_context_panel.visible:
			_selection_panel = _customer_context_panel
	if selection_type == "wall":
		_selected_finish_id = GameState.get_wall_finish(selection_id)
		finish_options.visible = false
		finish_actions.visible = false
	if _selection_panel != null:
		call_deferred("_resize_and_position_selection_panel")

func _create_customer_context_panel() -> void:
	_customer_context_panel = PanelContainer.new()
	_customer_context_panel.name = "CustomerContextPanel"
	_customer_context_panel.visible = false
	_customer_context_panel.custom_minimum_size = Vector2(280, 0)
	_customer_context_panel.add_theme_stylebox_override("panel", _make_catalog_card_style())
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	_customer_context_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)
	var identity_row := HBoxContainer.new()
	identity_row.add_theme_constant_override("separation", 9)
	column.add_child(identity_row)
	var portrait_frame := PanelContainer.new()
	portrait_frame.custom_minimum_size = Vector2(56, 56)
	portrait_frame.add_theme_stylebox_override("panel", _make_watch_preview_placeholder_style())
	identity_row.add_child(portrait_frame)
	_customer_context_portrait = TextureRect.new()
	_customer_context_portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 3)
	_customer_context_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_customer_context_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_customer_context_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_customer_context_portrait.visible = false
	portrait_frame.add_child(_customer_context_portrait)
	_customer_context_portrait_fallback = PanelContainer.new()
	_customer_context_portrait_fallback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 3)
	_customer_context_portrait_fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fallback_label := Label.new()
	fallback_label.text = "CLIENTE"
	fallback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fallback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fallback_label.add_theme_font_size_override("font_size", 9)
	fallback_label.add_theme_color_override("font_color", Color(0.55, 0.38, 0.13, 1.0))
	_customer_context_portrait_fallback.add_child(fallback_label)
	portrait_frame.add_child(_customer_context_portrait_fallback)
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_theme_constant_override("separation", 2)
	identity_row.add_child(identity)
	_customer_context_title = Label.new()
	_customer_context_title.add_theme_font_size_override("font_size", 18)
	_customer_context_title.add_theme_color_override("font_color", Color(0.55, 0.38, 0.13, 1.0))
	_customer_context_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	identity.add_child(_customer_context_title)
	_customer_context_details = Label.new()
	_customer_context_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_customer_context_details.add_theme_font_size_override("font_size", 13)
	_customer_context_details.add_theme_color_override("font_color", Color(0.18, 0.15, 0.1, 1.0))
	identity.add_child(_customer_context_details)
	_customer_context_budget = _add_customer_stat_bar(column, "Presupuesto", 6500)
	_customer_context_quality = _add_customer_stat_bar(column, "Calidad mínima", 100)
	_customer_context_patience = _add_customer_stat_bar(column, "Paciencia", 1)
	get_node("HudLayer").add_child(_customer_context_panel)

func _add_customer_stat_bar(column: VBoxContainer, label_text: String, maximum: int) -> ProgressBar:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	column.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(92, 0)
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.35, 0.29, 0.20, 1.0))
	row.add_child(label)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = maximum
	bar.custom_minimum_size = Vector2(0, 9)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_theme_stylebox_override("background", _make_watch_preview_placeholder_style())
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.72, 0.54, 0.25, 1.0)
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill)
	row.add_child(bar)
	var value := Label.new()
	value.name = "Value"
	value.custom_minimum_size = Vector2(48, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.add_theme_font_size_override("font_size", 10)
	value.add_theme_color_override("font_color", Color(0.35, 0.29, 0.20, 1.0))
	row.add_child(value)
	return bar

func _configure_customer_context(visitor_id: String) -> void:
	var negotiation := _negotiation_for_visitor(visitor_id)
	if negotiation.is_empty():
		_close_customer_context()
		return
	var profile := DataRegistry.get_visitor_profile(String(negotiation.get("profile_id", "")))
	if profile.is_empty():
		_close_customer_context()
		return
	_customer_context_title.text = String(negotiation.get("customer_name", "Cliente interesado")).to_upper()
	_customer_context_details.text = String(profile.get("name", "Perfil de cliente"))
	_set_customer_portrait(String(profile.get("preview_image_path", "")))
	_set_customer_stat(_customer_context_budget, clampi(int(negotiation.get("budget", 0)), 0, 6500), 6500, "%d €")
	_set_customer_stat(_customer_context_quality, clampi(int(profile.get("min_quality", 0)), 0, 100), 100, "%d")
	var max_patience := maxi(1, int(negotiation.get("max_patience", 1)))
	_set_customer_stat(_customer_context_patience, clampi(int(negotiation.get("patience", 0)), 0, max_patience), max_patience, "%d/%d")

func _negotiation_for_visitor(visitor_id: String) -> Dictionary:
	for node in get_tree().get_nodes_in_group("world_selectable_customer"):
		var visitor := node as CustomerVisitor
		if visitor == null or visitor.visitor_instance_id != visitor_id:
			continue
		for negotiation in GameState.get_visitor_negotiations():
			if int(negotiation.get("customer_slot", -1)) == visitor.customer_slot:
				return negotiation
	return {}

func _set_customer_portrait(image_path: String) -> void:
	var portrait := load(image_path) as Texture2D if not image_path.is_empty() and ResourceLoader.exists(image_path) else null
	_customer_context_portrait.texture = portrait
	_customer_context_portrait.visible = portrait != null
	_customer_context_portrait_fallback.visible = portrait == null

func _set_customer_stat(bar: ProgressBar, amount: int, maximum: int, format: String) -> void:
	bar.max_value = maximum
	bar.value = amount
	var value_label := bar.get_parent().get_node_or_null("Value") as Label
	if value_label != null:
		value_label.text = format % [amount, maximum] if format.count("%") > 1 else format % amount

func _on_visitor_negotiation_changed(_snapshot: Dictionary) -> void:
	if _selected_customer_visitor_id.is_empty() or not _customer_context_panel.visible:
		return
	_configure_customer_context(_selected_customer_visitor_id)
	if _customer_context_panel.visible:
		call_deferred("_resize_and_position_selection_panel")

func _close_customer_context() -> void:
	var had_customer_selection := not _selected_customer_visitor_id.is_empty()
	_selected_customer_visitor_id = ""
	_customer_context_panel.visible = false
	_selection_panel = null
	if had_customer_selection:
		EventBus.world_selection_changed.emit("", "", Vector3.ZERO)

func _create_watch_context_panel() -> void:
	_watch_context_panel = PanelContainer.new()
	_watch_context_panel.name = "WatchContextPanel"
	_watch_context_panel.visible = false
	# The larger interactive render remains readable at 1280×720. Positioning
	# still clamps this anchored card to the viewport.
	_watch_context_panel.custom_minimum_size = Vector2(570, 0)
	_watch_context_panel.add_theme_stylebox_override("panel", _make_catalog_card_style())
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	_watch_context_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)
	# Keep the presentation concise on a 720 px-tall viewport while giving the
	# model a useful inspection surface.
	var overview := HBoxContainer.new()
	overview.add_theme_constant_override("separation", 8)
	column.add_child(overview)
	var preview_frame := Control.new()
	preview_frame.custom_minimum_size = Vector2(208, 208)
	preview_frame.clip_contents = true
	# The frame passes events through except where its preview or buttons live.
	# This keeps rotation and wheel zoom strictly inside the rendered surface.
	preview_frame.mouse_filter = Control.MOUSE_FILTER_PASS
	# Its overlay controls are siblings of the SubViewportContainer. Mark the
	# whole inspection surface so workshop-camera wheel zoom stays suppressed
	# over both the model and these controls.
	preview_frame.add_to_group("interactive_3d_preview")
	overview.add_child(preview_frame)
	_watch_context_preview = AUCTION_PREVIEW.instantiate() as Control
	_watch_context_preview.custom_minimum_size = Vector2.ZERO
	_watch_context_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_watch_context_preview.mouse_filter = Control.MOUSE_FILTER_STOP
	preview_frame.add_child(_watch_context_preview)
	_watch_context_preview.call("set_interaction_enabled", true)
	_watch_context_image_preview = TextureRect.new()
	_watch_context_image_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_watch_context_image_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_watch_context_image_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_watch_context_image_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_watch_context_image_preview.visible = false
	preview_frame.add_child(_watch_context_image_preview)
	_watch_context_preview_placeholder = PanelContainer.new()
	_watch_context_preview_placeholder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_watch_context_preview_placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_watch_context_preview_placeholder.add_theme_stylebox_override("panel", _make_watch_preview_placeholder_style())
	var placeholder_label := Label.new()
	placeholder_label.text = "VISTA 3D\nNO DISPONIBLE"
	placeholder_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placeholder_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	placeholder_label.add_theme_font_size_override("font_size", 10)
	placeholder_label.add_theme_color_override("font_color", Color(0.38, 0.32, 0.23, 1.0))
	_watch_context_preview_placeholder.add_child(placeholder_label)
	preview_frame.add_child(_watch_context_preview_placeholder)
	_watch_context_preview_controls = HBoxContainer.new()
	_watch_context_preview_controls.anchor_left = 1.0
	_watch_context_preview_controls.anchor_top = 1.0
	_watch_context_preview_controls.anchor_right = 1.0
	_watch_context_preview_controls.anchor_bottom = 1.0
	_watch_context_preview_controls.offset_left = -196.0
	_watch_context_preview_controls.offset_top = -31.0
	_watch_context_preview_controls.offset_right = -6.0
	_watch_context_preview_controls.offset_bottom = -5.0
	_watch_context_preview_controls.add_theme_constant_override("separation", 4)
	preview_frame.add_child(_watch_context_preview_controls)
	var zoom_out := Button.new()
	zoom_out.text = "−"
	zoom_out.custom_minimum_size = Vector2(26, 26)
	zoom_out.tooltip_text = "Alejar pieza"
	zoom_out.pressed.connect(Callable(_watch_context_preview, "zoom_out"))
	_watch_context_preview_controls.add_child(zoom_out)
	var zoom_in := Button.new()
	zoom_in.text = "+"
	zoom_in.custom_minimum_size = Vector2(26, 26)
	zoom_in.tooltip_text = "Acercar pieza"
	zoom_in.pressed.connect(Callable(_watch_context_preview, "zoom_in"))
	_watch_context_preview_controls.add_child(zoom_in)
	var reset_view := Button.new()
	reset_view.text = "Restablecer vista"
	reset_view.custom_minimum_size = Vector2(128, 26)
	reset_view.tooltip_text = "Restablecer giro y zoom"
	reset_view.pressed.connect(Callable(_watch_context_preview, "reset_view"))
	_watch_context_preview_controls.add_child(reset_view)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.custom_minimum_size = Vector2(326, 0)
	details.add_theme_constant_override("separation", 3)
	overview.add_child(details)
	_watch_context_title = Label.new()
	_watch_context_title.text = "EN VITRINA"
	_watch_context_title.add_theme_font_size_override("font_size", 15)
	_watch_context_title.add_theme_color_override("font_color", Color(0.55, 0.38, 0.13, 1.0))
	details.add_child(_watch_context_title)
	_watch_context_name = _make_watch_context_label(16, Color(0.16, 0.13, 0.09, 1.0))
	_watch_context_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(_watch_context_name)
	_watch_context_brand = _make_watch_context_label(12, Color(0.38, 0.32, 0.23, 1.0))
	_watch_context_brand.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(_watch_context_brand)
	var prices_row := HBoxContainer.new()
	prices_row.add_theme_constant_override("separation", 4)
	details.add_child(prices_row)
	_watch_context_purchase_price = _create_watch_price_block("COMPRA", prices_row)
	_watch_context_sale_price = _create_watch_price_block("PRECIO VITRINA", prices_row)
	_watch_context_margin = _make_watch_context_label(12, Color(0.31, 0.25, 0.15, 1.0))
	_watch_context_margin.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(_watch_context_margin)
	_watch_context_valuation = _make_watch_context_label(12, Color(0.35, 0.27, 0.12, 1.0))
	_watch_context_valuation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(_watch_context_valuation)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	details.add_child(actions)
	_watch_context_move_button = Button.new()
	_watch_context_move_button.text = "Mover"
	_watch_context_move_button.icon = MOVE_ICON
	_watch_context_move_button.expand_icon = true
	_watch_context_move_button.custom_minimum_size = Vector2(0, 40)
	_watch_context_move_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_watch_context_move_button.add_theme_stylebox_override("normal", _make_catalog_button_style())
	_watch_context_move_button.add_theme_color_override("font_color", Color(0.14, 0.1, 0.06, 1.0))
	_watch_context_move_button.tooltip_text = "Elegir otro hueco en vitrina"
	_watch_context_move_button.pressed.connect(_on_watch_context_relocate_pressed)
	actions.add_child(_watch_context_move_button)
	_watch_context_edit_price_button = Button.new()
	_watch_context_edit_price_button.text = "Editar precio"
	_watch_context_edit_price_button.custom_minimum_size = Vector2(0, 40)
	_watch_context_edit_price_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_watch_context_edit_price_button.add_theme_stylebox_override("normal", _make_catalog_button_style())
	_watch_context_edit_price_button.add_theme_color_override("font_color", Color(0.14, 0.1, 0.06, 1.0))
	_watch_context_edit_price_button.tooltip_text = "Editar el precio de venta de esta pieza"
	_watch_context_edit_price_button.pressed.connect(_on_watch_context_edit_price_pressed)
	actions.add_child(_watch_context_edit_price_button)
	get_node("HudLayer").add_child(_watch_context_panel)

func _configure_watch_context(unit_id: String) -> void:
	var watch := GameState.get_displayed_watch(unit_id)
	var piece := _get_listed_piece(unit_id)
	var reserved := GameState.is_visitor_reserved(unit_id)
	var sale_price := int(watch.get("sale_price", piece.get("sale_price", 0)))
	var purchase_price := int(piece.get("auction_price", 0))
	_watch_context_title.text = "RESERVADO PARA CLIENTE" if reserved else "EN VITRINA"
	_watch_context_name.text = String(piece.get("name", "Pieza expuesta"))
	var preview_image_path := String(piece.get("preview_image_path", ""))
	if preview_image_path.is_empty():
		preview_image_path = DataRegistry.get_lot_preview_path(String(piece.get("lot_id", "")))
	_set_watch_context_preview(preview_image_path, String(piece.get("model_path", "")), String(piece.get("item_type", "watch")), String(piece.get("category", "")))
	var brand := String(piece.get("brand", ""))
	var segment := String(piece.get("segment", ""))
	_watch_context_brand.text = brand + (" · " if not brand.is_empty() and not segment.is_empty() else "") + tr(segment)
	_watch_context_brand.visible = not _watch_context_brand.text.is_empty()
	_watch_context_purchase_price.text = "COMPRA\n%s" % _format_watch_context_price(purchase_price)
	_watch_context_sale_price.text = "PRECIO VITRINA\n%s" % _format_watch_context_price(sale_price)
	_watch_context_margin.text = "Margen potencial  %s" % (_format_money(sale_price - purchase_price) if purchase_price > 0 else "— · compra no registrada")
	var valuation := GameState.get_watch_valuation(piece, sale_price)
	_watch_context_valuation.text = "%s  %s · Precio %s" % [String(valuation.get("stars_text", "★★★★☆")), String(valuation.get("label", "Pieza recomendable")), String(valuation.get("price_fit_label", "Revisar precio"))]
	_watch_context_move_button.disabled = reserved
	_watch_context_edit_price_button.disabled = reserved
	var reserved_tooltip := "La pieza está reservada hasta terminar la atención en caja."
	_watch_context_move_button.tooltip_text = reserved_tooltip if reserved else "Elegir otro hueco iluminado y confirmar movimiento"
	_watch_context_edit_price_button.tooltip_text = reserved_tooltip if reserved else "Editar el precio de venta de esta pieza"

func _on_watch_context_relocate_pressed() -> void:
	if not _selected_watch_id.is_empty() and not GameState.is_visitor_reserved(_selected_watch_id):
		EventBus.displayed_watch_relocation_requested.emit(_selected_watch_id)

func _on_watch_context_edit_price_pressed() -> void:
	if _selected_watch_id.is_empty() or GameState.is_visitor_reserved(_selected_watch_id):
		return
	var inventory := get_tree().get_first_node_in_group("inventory_panel")
	if inventory != null and inventory.has_method(&"_open_price_modal"):
		# The reusable modal belongs to InventoryPanel, so make its overlay visible
		# before opening it from the in-world context card.
		inventory.call("open")
		inventory.call("_open_price_modal", _get_listed_piece(_selected_watch_id))

func _set_watch_context_preview(image_path: String, model_path: String, item_type := "watch", category := "") -> void:
	# The world display and this UI only read the piece snapshot. A missing or
	# unavailable asset is represented locally instead of changing game data.
	var has_image := not image_path.is_empty() and ResourceLoader.exists(image_path)
	var has_model := not model_path.is_empty() and ResourceLoader.exists(model_path)
	_watch_context_image_preview.visible = has_image
	_watch_context_preview.visible = has_model and not has_image
	_watch_context_preview_placeholder.visible = not has_model and not has_image
	_watch_context_preview_controls.visible = has_model and not has_image
	if has_image:
		_watch_context_image_preview.texture = load(image_path) as Texture2D
	elif has_model:
		_watch_context_preview.call("set_item_context", item_type, category)
		_watch_context_preview.call("set_model_path", model_path)
		_watch_context_preview.call("reset_view")

func _make_watch_preview_placeholder_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.84, 0.8, 0.71, 1.0)
	style.border_color = Color(0.68, 0.53, 0.27, 0.45)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	return style

func _on_watch_display_changed(_snapshot: Dictionary) -> void:
	if _selected_watch_id.is_empty():
		return
	if GameState.get_displayed_watch(_selected_watch_id).is_empty():
		_selected_watch_id = ""
		_watch_context_panel.visible = false
		if _selection_panel == _watch_context_panel:
			_selection_panel = null
		return
	_configure_watch_context(_selected_watch_id)
	if _watch_context_panel.visible:
		call_deferred("_resize_and_position_selection_panel")

func _make_watch_context_label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _create_watch_price_block(title: String, parent: Container) -> Label:
	var block := PanelContainer.new()
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block.add_theme_stylebox_override("panel", _make_watch_price_block_style())
	parent.add_child(block)
	var label := Label.new()
	label.text = title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# The 320 px details area yields ~158 px per block at the final panel width.
	# Keep their short headings and values on their intended two lines.
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(0.22, 0.19, 0.14, 1.0))
	block.add_child(label)
	return label

func _make_watch_price_block_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.8, 0.72, 0.54, 0.24)
	style.border_color = Color(0.68, 0.53, 0.27, 0.45)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 4
	style.content_margin_top = 3
	style.content_margin_right = 4
	style.content_margin_bottom = 3
	return style

func _get_listed_piece(unit_id: String) -> Dictionary:
	for piece in GameState.listed_pieces:
		if String(piece.get("id", "")) == unit_id:
			return piece
	return {}

func _format_watch_context_price(value: int) -> String:
	return _format_money(value) if value > 0 else "No disponible"

func _process(_delta: float) -> void:
	if _selection_panel != null and _selection_panel.visible:
		_position_selection_panel()
	_refresh_bottom_action_style()
	_refresh_door_admission_button()
	_animate_door_admission_button()

func _create_door_admission_button() -> void:
	_door_admission_button = Button.new()
	_door_admission_button.name = "DoorAdmissionButton"
	_door_admission_button.visible = false
	_door_admission_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_door_admission_button.icon = DOOR_OPEN_ICON
	_door_admission_button.expand_icon = true
	_door_admission_button.tooltip_text = "Abrir puerta"
	_door_admission_button.add_theme_stylebox_override("normal", _make_bottom_action_button_style(false))
	_door_admission_button.add_theme_stylebox_override("hover", _make_bottom_action_button_style(true))
	_door_admission_button.size = Vector2(52, 52)
	_door_admission_button.pressed.connect(func() -> void: EventBus.visitor_door_open_requested.emit())
	get_node("HudLayer").add_child(_door_admission_button)

func _refresh_door_admission_button() -> void:
	if _door_admission_button == null:
		return
	var waiting_count := 0
	for negotiation in GameState.get_visitor_negotiations():
		if String(negotiation.get("state", "")) == "waiting_outside":
			waiting_count += 1
	var visitor_manager := get_tree().get_first_node_in_group("visitor_negotiation_manager") as VisitorNegotiationManager
	if waiting_count == 0 and visitor_manager != null and visitor_manager.has_waiting_browse_visitor():
		waiting_count = 1
	_door_admission_button.text = ""
	if waiting_count == 0:
		_door_admission_button.visible = false
		return
	var counters := get_tree().get_nodes_in_group("point_of_sale_counter")
	if not counters.is_empty() and counters[0] is Node3D and selection_camera != null:
		var counter := counters[0] as Node3D
		var anchor := counter.global_position + Vector3.UP * 1.5
		if not selection_camera.is_position_behind(anchor):
			_door_admission_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
			_door_admission_button.position = selection_camera.unproject_position(anchor) - _door_admission_button.size * 0.5
			_door_admission_button.visible = true
			return
	# El botón sigue accesible si el TPV aún no está instalado o está fuera de plano.
	_door_admission_button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_door_admission_button.position = Vector2(-_door_admission_button.size.x * 0.5, -88.0)
	_door_admission_button.visible = true

func _animate_door_admission_button() -> void:
	if _door_admission_button == null or not _door_admission_button.visible:
		return
	# El icono palpita mientras el timbre requiere una respuesta, sin mover su anclaje.
	var pulse := 0.84 + sin(Time.get_ticks_msec() * 0.008) * 0.16
	_door_admission_button.modulate = Color(1.0, 1.0, 1.0, pulse)

func _refresh_bottom_action_style() -> void:
	var active := "auction" if commerce_panel.visible else "inventory" if inventory_panel.visible else "menu" if game_menu_overlay.visible else ""
	if active == _last_bottom_action_active:
		return
	_last_bottom_action_active = active
	for entry in [[auction_button, "auction"], [inventory_button, "inventory"], [game_menu_button, "menu"]]:
		var button := entry[0] as Button
		button.add_theme_stylebox_override("normal", _make_bottom_action_button_style(String(entry[1]) == active))

func _make_bottom_action_button_style(active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	# Both states keep dark content on a light card; never reintroduce pale text
	# over cream when a panel changes the selected navigation action.
	style.bg_color = Color(0.78, 0.62, 0.3, 1.0) if active else Color(0.92549, 0.901961, 0.85098, 0.96)
	style.set_corner_radius_all(8)
	return style

func _set_bottom_action_content_disabled(button: Button, disabled: bool) -> void:
	var color := Color(0.66, 0.66, 0.62, 1.0) if disabled else Color(0.12, 0.09, 0.06, 1.0)
	for child in button.get_children():
		if child is Label:
			(child as Label).add_theme_color_override("font_color", color)
		elif child is TextureRect:
			(child as TextureRect).modulate = color

func _position_selection_panel() -> void:
	if _selection_panel == null or not _selection_panel.visible or selection_camera == null:
		return
	if selection_camera.is_position_behind(_selection_anchor):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var screen_position := selection_camera.unproject_position(_selection_anchor)
	var panel_size := _selection_panel.size
	var position := Vector2(screen_position.x - panel_size.x * 0.5, screen_position.y - panel_size.y - 12.0)
	# Keep the context actions usable at every supported viewport size.
	position.x = clampf(position.x, 8.0, maxf(8.0, viewport_size.x - panel_size.x - 8.0))
	position.y = clampf(position.y, 8.0, maxf(8.0, viewport_size.y - panel_size.y - 8.0))
	_selection_panel.position = position

func _resize_and_position_selection_panel() -> void:
	if _selection_panel == null or not _selection_panel.visible:
		return
	# The palette begins as one icon and grows only when its swatches are requested.
	_selection_panel.size = _selection_panel.get_combined_minimum_size()
	_position_selection_panel()

func _on_palette_pressed() -> void:
	var show_options := not finish_options.visible
	finish_options.visible = show_options
	finish_actions.visible = show_options
	call_deferred("_resize_and_position_selection_panel")

func _on_move_window_pressed() -> void:
	if not _selected_installation_id.is_empty():
		if _selected_installation_type == "window":
			EventBus.facade_move_requested.emit(_selected_installation_id)
		elif _selected_installation_type == "facility":
			EventBus.facility_move_requested.emit(_selected_installation_id)
		window_context_panel.visible = false

func _on_demolish_window_pressed() -> void:
	demolition_confirm_panel.visible = not _selected_installation_id.is_empty()

func _on_confirm_demolish_pressed() -> void:
	if _selected_installation_type == "window":
		EventBus.facade_demolish_requested.emit(_selected_installation_id)
	elif _selected_installation_type == "facility":
		EventBus.facility_demolish_requested.emit(_selected_installation_id)
	demolition_confirm_panel.visible = false

func _on_cancel_demolish_pressed() -> void:
	demolition_confirm_panel.visible = false

func _on_finish_pressed(finish_id: String) -> void:
	if _selected_wall_id.is_empty():
		return
	_selected_finish_id = finish_id
	EventBus.wall_finish_preview_requested.emit(_selected_wall_id, finish_id)

func _on_apply_finish_pressed() -> void:
	if not _selected_wall_id.is_empty():
		EventBus.wall_finish_apply_requested.emit(_selected_wall_id, _selected_finish_id)
		wall_palette_panel.visible = false

func _on_cancel_finish_pressed() -> void:
	if not _selected_wall_id.is_empty():
		EventBus.wall_finish_cancel_requested.emit(_selected_wall_id)
		wall_palette_panel.visible = false

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or event.keycode != KEY_ESCAPE:
		return
	if _treasury_overlay != null and _treasury_overlay.visible:
		_close_treasury()
		get_viewport().set_input_as_handled()
		return
	# Placement, including relocation, owns Escape before the game menu does.
	if placement_bar.visible:
		EventBus.placement_cancel_requested.emit()
		get_viewport().set_input_as_handled()
		return
	if game_menu_overlay.visible:
		if restart_confirmation.visible:
			_on_cancel_restart_pressed()
		else:
			_on_resume_pressed()
	else:
		_open_game_menu()
	get_viewport().set_input_as_handled()

func _open_game_menu() -> void:
	game_menu_overlay.visible = true
	game_menu_panel.visible = true
	restart_confirmation.visible = false
	TimeManager.set_paused(true)
	resume_button.grab_focus()

func _on_language_selected(index: int) -> void:
	_settings_manager().call(&"set_language", String(language_option.get_item_metadata(index)))

func _on_language_changed(_locale: String) -> void:
	_refresh_language_option()

func _refresh_language_option() -> void:
	language_option.clear()
	language_option.add_item(tr("Español"))
	language_option.set_item_metadata(0, "es")
	language_option.add_item(tr("Inglés"))
	language_option.set_item_metadata(1, "en")
	language_option.select(0 if String(_settings_manager().get("locale")) == "es" else 1)

func _on_music_volume_changed(volume: float) -> void:
	SettingsManager.set_music_volume(volume)

func _on_effects_volume_changed(volume: float) -> void:
	SettingsManager.set_effects_volume(volume)

func _settings_manager() -> Node:
	# Access through the scene tree so this UI remains valid while Godot refreshes
	# its autoload symbol table after project-settings changes.
	return get_node("/root/SettingsManager")

func _on_resume_pressed() -> void:
	game_menu_overlay.visible = false
	game_menu_panel.visible = true
	restart_confirmation.visible = false
	TimeManager.set_speed(1)

func _on_restart_pressed() -> void:
	game_menu_panel.visible = false
	restart_confirmation.visible = true
	confirm_restart_button.grab_focus()

func _on_cancel_restart_pressed() -> void:
	restart_confirmation.visible = false
	game_menu_panel.visible = true
	restart_button.grab_focus()

func _on_confirm_restart_pressed() -> void:
	if not SaveManager.reset_game():
		_on_cancel_restart_pressed()

func _format_money(value: int) -> String:
	var sign := "−" if value < 0 else ""
	var raw: String = str(absi(value))
	var result := ""
	var count := 0
	for index in range(raw.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "." + result
		result = raw[index] + result
		count += 1
	return "%s%s €" % [sign, result]

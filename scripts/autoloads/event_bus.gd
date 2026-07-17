extends Node

@warning_ignore("unused_signal")
signal stats_changed(money: int, reputation: int)

@warning_ignore("unused_signal")
signal inventory_changed(owned_count: int, listed_count: int)

## Auction domain events. The auction manager owns the rules; UI only renders these snapshots.
signal auction_state_changed(snapshot: Dictionary)
signal auction_resolved(result: Dictionary)
## Checkpoints persist a running timer without forcing presentation to rebuild.
signal auction_state_persist_requested
signal purchase_history_changed
signal watch_display_changed(snapshot: Dictionary)
## The carried watch is gameplay state; world and UI only react to this snapshot.
signal carried_watch_changed(watch: Dictionary)

## Placement commands originate in UI; the scene controller owns their execution.
signal facade_item_selected(item_id: String)
signal facility_item_selected(item_id: String)
signal placement_cancel_requested

## Placement feedback is presentation-only and has no UI node dependencies.
signal placement_state_changed(active: bool, item_name: String)
signal placement_preview_changed(is_valid: bool, message: String)
signal feedback_requested(message: String, severity: String)
signal facade_installation_added(installation: Dictionary)
signal facade_installation_updated(installation: Dictionary)
signal facade_installation_removed(installation_id: String, refund: int)
## Emitted after saved façade data replaces the current installation list.
signal facade_installations_reloaded
signal facility_installation_added(installation: Dictionary)
signal facility_installation_updated(installation: Dictionary)
signal facility_installation_removed(installation_id: String, refund: int)
signal facility_installations_reloaded

## Scene selection and editing commands. UI requests; gameplay owns raycasts and world changes.
## The anchor is world-space presentation data; UI projects it into its own canvas.
signal world_selection_changed(selection_type: String, selection_id: String, anchor_position: Vector3)
signal facade_move_requested(installation_id: String)
signal facade_demolish_requested(installation_id: String)
signal facility_move_requested(installation_id: String)
signal facility_demolish_requested(installation_id: String)
## Selecting an already selected displayed piece begins its world-slot relocation.
## The placement controller owns target selection and validation.
signal displayed_watch_relocation_requested(unit_id: String)
## Starts a direct inventory-to-vitrina placement; it never uses carried_watch.
signal owned_watch_display_placement_requested(piece_index: int, sale_price: int)
## Display-slot placement permits walking; building placement does not.
signal display_slot_placement_state_changed(active: bool)
## Selection controllers use this after consuming a secondary click so the
## camera never remains in its rotate gesture when an item starts moving.
signal camera_rotation_cancel_requested
signal wall_finish_preview_requested(wall_id: String, finish_id: String)
signal wall_finish_apply_requested(wall_id: String, finish_id: String)
signal wall_finish_cancel_requested(wall_id: String)
signal wall_finish_changed(wall_id: String, finish_id: String)

## Time commands originate in UI; TimeManager owns simulation progression.
signal time_pause_requested
signal time_speed_requested(speed_multiplier: int)
signal time_state_requested
signal time_snapshot_requested

## Time state is broadcast so gameplay and UI can react without direct references.
signal time_state_changed(current_day: int, speed_multiplier: int, is_paused: bool)
## Includes the formatted calendar instant and the 0.0–1.0 progress of the current game day.
signal time_snapshot_changed(snapshot: Dictionary)
signal day_changed(current_day: int)

## Finance is calculated by FinanceManager; UI only renders these payloads.
signal monthly_expense_preview_changed(preview: Dictionary, days_until_settlement: int)
signal monthly_settlement_completed(settlement: Dictionary, resulting_balance: int)

## Boutique visitor domain. Managers own pricing and state; UI sends intent only.
signal visitor_negotiation_changed(snapshot: Dictionary)
signal visitor_negotiation_action_requested(action: String, amount: int)
signal visitor_negotiation_resolved(result: Dictionary)
## Successful visitor sales carry an immutable item snapshot for presentation.
## The item may already have been removed from the display when UI receives this.
signal visitor_sale_completed(presentation: Dictionary)
## El HUD solicita la admisión; VisitorNegotiationManager valida la visita exterior.
signal visitor_door_open_requested
## Presentación de audio, sin reglas de negocio ni referencias a la escena.
signal visitor_doorbell_requested
## UI-only placement hint so the customer thought card can avoid this fixed offer.
signal visitor_negotiation_card_visibility_changed(is_visible: bool, occupied_height: float)
## Customer satisfaction is independent from the progression reputation integer.
signal customer_reviews_changed(rating: float, reviews: Array[Dictionary])

extends Node

@warning_ignore("unused_signal")
signal stats_changed(money: int, reputation: int)

@warning_ignore("unused_signal")
signal inventory_changed(owned_count: int, listed_count: int)

## Placement commands originate in UI; the scene controller owns their execution.
signal facade_item_selected(item_id: String)
signal placement_cancel_requested

## Placement feedback is presentation-only and has no UI node dependencies.
signal placement_state_changed(active: bool, item_name: String)
signal placement_preview_changed(is_valid: bool, message: String)
signal feedback_requested(message: String, severity: String)
signal facade_installation_added(installation: Dictionary)
signal facade_installation_updated(installation: Dictionary)
signal facade_installation_removed(installation_id: String, refund: int)

## Scene selection and editing commands. UI requests; gameplay owns raycasts and world changes.
signal world_selection_changed(selection_type: String, selection_id: String)
signal facade_move_requested(installation_id: String)
signal facade_demolish_requested(installation_id: String)
signal wall_finish_preview_requested(wall_id: String, finish_id: String)
signal wall_finish_apply_requested(wall_id: String, finish_id: String)
signal wall_finish_cancel_requested(wall_id: String)
signal wall_finish_changed(wall_id: String, finish_id: String)

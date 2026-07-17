extends Node

const ItemModelFraming = preload("res://scripts/presentation/item_model_framing.gd")

## Visual-only gallery for the shared display slots.
@export var facility_controller_path: NodePath
@onready var _facility_controller: Node = get_node(facility_controller_path)
var _galleries: Dictionary = {}
var _price_chips: Array[Node3D] = []
const WATCH_SELECTION_MASK := 64
func _ready() -> void:
	EventBus.watch_display_changed.connect(_on_display_changed)
	EventBus.visitor_negotiation_changed.connect(_on_visitor_negotiation_changed)
	EventBus.facility_installations_reloaded.connect(_restore)
	call_deferred("_restore")

func _on_display_changed(_snapshot: Dictionary) -> void:
	_restore()

func _on_visitor_negotiation_changed(_snapshot: Dictionary) -> void:
	_restore()

func _restore() -> void:
	for gallery in _galleries.values():
		if is_instance_valid(gallery): gallery.queue_free()
	_galleries.clear()
	_price_chips.clear()
	if GameState.displayed_watches.is_empty(): return
	for entry in GameState.displayed_watches:
		_add_watch(entry)

func _process(_delta: float) -> void:
	# Keep the physical tags readable while the workshop camera is rotated.
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	for chip in _price_chips:
		if is_instance_valid(chip):
			chip.look_at(camera.global_position, Vector3.UP, true)

func _add_watch(entry: Dictionary) -> void:
	var piece := _piece_for_unit(String(entry.get("unit_id", "")))
	var model_path := String(piece.get("model_path", ""))
	var scene := ResourceLoader.load(model_path) as PackedScene if not model_path.is_empty() else null
	if scene == null: return
	var facility_id := String(entry.get("facility_installation_id", ""))
	var gallery: Node3D = _galleries.get(facility_id)
	if gallery == null:
		var counter := _facility_controller.call("get_rendered_installation", facility_id) as Node3D
		if counter == null: return
		gallery = Node3D.new()
		gallery.name = "WatchDisplayGallery"
		counter.add_child(gallery)
		_galleries[facility_id] = gallery
	var slot := int(entry.get("slot_index", 0))
	var root := Node3D.new()
	root.name = "DisplayedWatch_%s" % String(entry.get("unit_id", ""))
	root.position = Vector3(GameState.get_display_slot(facility_id, slot).get("position", Vector3.ZERO))
	if String(piece.get("item_type", "watch")) == "jewelry":
		var facility_visual := gallery.get_parent() as Node3D
		var visual_scale_y := facility_visual.scale.y if facility_visual != null else 1.0
		root.position.y += 0.06 / maxf(visual_scale_y, 0.001)
	root.scale = Vector3(GameState.get_display_slot(facility_id, slot).get("scale", Vector3.ONE))
	root.rotation.y = float(entry.get("rotation_y", 0.0))
	root.add_to_group("world_selectable_displayed_watch")
	root.set_meta("selection_id", String(entry.get("unit_id", "")))
	gallery.add_child(root)
	var model := scene.instantiate() as Node3D
	root.add_child(model)
	await _fit_model(model, String(piece.get("item_type", "watch")), String(piece.get("category", "")))
	if not is_instance_valid(root):
		return
	_add_price_chip(root, int(entry.get("sale_price", 0)), GameState.is_visitor_reserved(String(entry.get("unit_id", ""))))
	_add_selection_collider(root, entry)

func _add_price_chip(root: Node3D, price: int, reserved := false) -> void:
	# Keep the tag just above the piece so it never obscures the watch. The
	# larger, depth-independent label remains legible through the vitrina glass.
	# The selectable area remains independent.
	var price_text := "%s € · RESERVADO" % price if reserved else "%s €" % price
	var chip_width := maxf(0.68, 0.152 + float(price_text.length()) * 0.092)
	var chip := Node3D.new()
	chip.name = "PriceChip"
	chip.position = Vector3(0.0, 0.40, 0.0)
	root.add_child(chip)
	_price_chips.append(chip)
	var border := _create_chip_panel(chip_width, 0.244, Color(0.82, 0.34, 0.16, 1.0) if reserved else Color(0.72, 0.54, 0.20, 1.0), 0)
	border.name = "PriceChipGoldBorder"
	chip.add_child(border)
	var background := _create_chip_panel(chip_width - 0.028, 0.216, Color(0.025, 0.022, 0.018, 1.0), 1)
	background.name = "PriceChipBackground"
	# The child planes face +Z. Positive Z is nearer to the camera after the
	# billboard pivot turns, which gives border, background and text stable depth.
	background.position.z = 0.001
	chip.add_child(background)
	var label := Label3D.new()
	label.name = "PriceChipLabel"
	label.text = price_text
	label.position.z = 0.002
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.font_size = 56
	label.pixel_size = 0.0034
	label.outline_size = 2
	label.modulate = Color(1.0, 0.77, 0.58, 1.0) if reserved else Color(1.0, 0.94, 0.76, 1.0)
	label.outline_modulate = Color(0.10, 0.07, 0.03, 1.0)
	label.no_depth_test = true
	label.render_priority = 2
	chip.add_child(label)
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		chip.look_at(camera.global_position, Vector3.UP, true)

func _create_chip_panel(width: float, height: float, color: Color, render_priority: int) -> MeshInstance3D:
	var panel := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(width, height)
	panel.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.render_priority = render_priority
	panel.material_override = material
	return panel

func _add_selection_collider(root: Node3D, entry: Dictionary) -> void:
	var body := StaticBody3D.new()
	body.name = "WatchSelectionCollider"
	body.collision_layer = WATCH_SELECTION_MASK
	body.collision_mask = 0
	body.set_meta("unit_id", String(entry.get("unit_id", "")))
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	# Larger than the model silhouette so selecting a small displayed watch remains reliable.
	shape.size = Vector3(0.30, 0.18, 0.30)
	collision.position.y = 0.06
	collision.shape = shape
	body.add_child(collision)
	root.add_child(body)

func _piece_for_unit(unit_id: String) -> Dictionary:
	for piece in GameState.listed_pieces:
		if String(piece.get("id", "")) == unit_id: return piece
	return {}

func _fit_model(model: Node3D, item_type: String, category: String) -> void:
	await get_tree().process_frame
	if not is_instance_valid(model): return
	var bounds := _get_bounds(model)
	var factor := ItemModelFraming.scale_to_fit(bounds, ItemModelFraming.display_envelope(item_type, category))
	if item_type == "jewelry":
		factor *= 1.35
	if factor > 0.001:
		# The type envelope preserves clearance between slots; real model bounds
		# still handle inconsistent pivots and exporter units.
		model.scale = Vector3.ONE * factor
		model.position = -bounds.get_center() * factor

func _get_bounds(node: Node3D) -> AABB:
	var found := false
	var combined := AABB()
	for mesh in _find_meshes(node):
		var bounds := _transform_aabb(mesh.get_aabb(), node.global_transform.affine_inverse() * mesh.global_transform)
		if found: combined = combined.merge(bounds)
		else: combined = bounds; found = true
	return combined

func _transform_aabb(bounds: AABB, transform: Transform3D) -> AABB:
	var result := AABB(transform * bounds.get_endpoint(0), Vector3.ZERO)
	for corner in range(1, 8): result = result.expand(transform * bounds.get_endpoint(corner))
	return result

func _find_meshes(node: Node) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	if node is MeshInstance3D: meshes.append(node)
	for child in node.get_children(): meshes.append_array(_find_meshes(child))
	return meshes

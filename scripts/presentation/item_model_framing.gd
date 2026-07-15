class_name ItemModelFraming
extends RefCounted

## Presentation-only framing rules. Item metadata selects a display envelope;
## the imported model bounds decide the final uniform scale inside that envelope.

static func preview_envelope(item_type: String, category: String) -> Vector3:
	if item_type == "jewelry":
		match category:
			"ring":
				return Vector3(1.45, 1.45, 1.55)
			"earrings":
				return Vector3(1.70, 1.65, 1.45)
			"pendant":
				return Vector3(1.35, 1.90, 1.30)
			"tiara":
				return Vector3(2.00, 1.45, 1.15)
			"necklace":
				return Vector3(2.05, 1.40, 0.85)
	return Vector3(1.95, 1.55, 1.75) # Watches and unknown legacy pieces.

static func display_envelope(item_type: String, category: String) -> Vector3:
	if item_type == "jewelry":
		match category:
			"ring":
				return Vector3(0.20, 0.16, 0.18)
			"earrings":
				return Vector3(0.22, 0.24, 0.14)
			"pendant":
				return Vector3(0.16, 0.29, 0.12)
			"tiara":
				return Vector3(0.29, 0.18, 0.15)
			"necklace":
				return Vector3(0.29, 0.17, 0.08)
	return Vector3(0.28, 0.18, 0.22) # Watches and unknown legacy pieces.

static func scale_to_fit(bounds: AABB, envelope: Vector3) -> float:
	var scale := INF
	for axis in 3:
		var source_size := bounds.size[axis]
		var target_size := envelope[axis]
		if source_size > 0.001 and target_size > 0.0:
			scale = minf(scale, target_size / source_size)
	return 1.0 if is_inf(scale) else scale

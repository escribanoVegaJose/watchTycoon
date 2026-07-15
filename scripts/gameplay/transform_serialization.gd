class_name TransformSerialization
extends RefCounted

## Converts placement transforms into save-safe primitive values.
static func serialize(value: Transform3D) -> Dictionary:
	return {
		"origin": [value.origin.x, value.origin.y, value.origin.z],
		"basis": [value.basis.x.x, value.basis.x.y, value.basis.x.z, value.basis.y.x, value.basis.y.y, value.basis.y.z, value.basis.z.x, value.basis.z.y, value.basis.z.z],
	}

static func deserialize(data: Dictionary) -> Transform3D:
	var origin: Variant = data.get("origin", [])
	var basis: Variant = data.get("basis", [])
	if not origin is Array or not basis is Array or origin.size() != 3 or basis.size() != 9:
		return Transform3D.IDENTITY
	for value in origin:
		if not value is int and not value is float:
			return Transform3D.IDENTITY
	for value in basis:
		if not value is int and not value is float:
			return Transform3D.IDENTITY
	return Transform3D(Basis(Vector3(float(basis[0]), float(basis[1]), float(basis[2])), Vector3(float(basis[3]), float(basis[4]), float(basis[5])), Vector3(float(basis[6]), float(basis[7]), float(basis[8]))), Vector3(float(origin[0]), float(origin[1]), float(origin[2])))

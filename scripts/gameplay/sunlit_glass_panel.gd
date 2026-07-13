extends MeshInstance3D

## Superficie de cristal para assets que incluyen marco y cristal en la misma
## malla. Recibe la luz real de la escena: sol, puntos de luz o oscuridad.
@export var sun_light_path: NodePath

func _ready() -> void:
	var glass_material := StandardMaterial3D.new()
	glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	glass_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	glass_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass_material.albedo_color = Color(0.68, 0.82, 0.9, 0.3)
	glass_material.metallic = 0.08
	glass_material.roughness = 0.12
	glass_material.specular = 0.9
	material_override = glass_material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

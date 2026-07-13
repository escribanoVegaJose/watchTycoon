shader_type spatial;
render_mode diffuse_burley;

instance uniform vec3 cream_color : source_color = vec3(0.78, 0.71, 0.60);
uniform vec3 warm_variation : source_color = vec3(0.10, 0.075, 0.045);
uniform float world_scale = 4.0;
uniform float variation_strength : hint_range(0.0, 1.0) = 0.16;

varying vec3 world_pos;

float hash31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float noise3d(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);

	return mix(
		mix(
			mix(hash31(i), hash31(i + vec3(1.0, 0.0, 0.0)), f.x),
			mix(hash31(i + vec3(0.0, 1.0, 0.0)), hash31(i + vec3(1.0, 1.0, 0.0)), f.x),
			f.y
		),
		mix(
			mix(hash31(i + vec3(0.0, 0.0, 1.0)), hash31(i + vec3(1.0, 0.0, 1.0)), f.x),
			mix(hash31(i + vec3(0.0, 1.0, 1.0)), hash31(i + vec3(1.0, 1.0, 1.0)), f.x),
			f.y
		),
		f.z
	);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 p = world_pos * world_scale;
	float macro = noise3d(p * 0.22);
	float micro = noise3d(p * 1.8);
	float plaster = (macro * 0.7 + micro * 0.3 - 0.5) * variation_strength;

	ALBEDO = cream_color + warm_variation * plaster;
	ROUGHNESS = 0.82 + micro * 0.10;
	SPECULAR = 0.18;
}

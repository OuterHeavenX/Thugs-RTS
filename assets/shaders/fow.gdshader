// Fog-of-war terrain overlay for Helios Valley.
// fow_tex: R8 texture from FogOfWar.get_texture() — 0 = unexplored,
// 128 = explored, 255 = visible. Sampled with UV = (world_xz + 64) / 128.
shader_type spatial;
render_mode fog_disabled, specular_disabled;

uniform sampler2D fow_tex : filter_nearest, repeat_disable;
uniform vec3 unexplored_color : source_color = vec3(0.008, 0.010, 0.018);

varying vec2 fow_uv;

void vertex() {
	fow_uv = (VERTEX.xz + 64.0) / 128.0;
}

void fragment() {
	float f = texture(fow_tex, fow_uv).r;
	vec3 col = COLOR.rgb;
	vec3 result;
	if (f < 0.25) {
		// Unexplored: near black.
		result = unexplored_color;
	} else if (f < 0.75) {
		// Explored but not visible: 45% brightness, desaturated.
		float lum = dot(col, vec3(0.299, 0.587, 0.114));
		result = vec3(lum) * 0.45;
	} else {
		// Visible: full color.
		result = col;
	}
	ALBEDO = result;
	ROUGHNESS = 1.0;
}

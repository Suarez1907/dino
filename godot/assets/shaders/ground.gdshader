shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 color_a : source_color = vec3(0.86, 0.70, 0.42);
uniform vec3 color_b : source_color = vec3(0.72, 0.48, 0.28);
uniform float scale = 0.22;
uniform float patch = 0.35;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float n = sin(world_pos.x * scale) * cos(world_pos.z * scale * 1.17);
	n += sin(world_pos.x * scale * 2.6 + world_pos.z * 1.4) * 0.45;
	float f = clamp(n * 0.5 + 0.5, 0.0, 1.0);
	float pebbles = smoothstep(0.72, 0.95, fract(sin(dot(floor(world_pos.xz * 3.0), vec2(12.9, 78.2))) * 43758.5));
	vec3 col = mix(color_a, color_b, f);
	col = mix(col, color_b * 0.85, pebbles * patch);
	ALBEDO = col;
	ROUGHNESS = 0.94;
	METALLIC = 0.0;
}

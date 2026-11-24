shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D heightmap : filter_linear, repeat_disable;
uniform sampler2D original_heightmap : filter_linear, repeat_disable;
uniform sampler2D dig_mask : filter_linear, repeat_disable;
uniform float terrain_size = 72.0;
uniform float heightmap_size = 61.0;

uniform sampler2D layer_texture_0 : source_color, filter_linear;
uniform sampler2D layer_texture_1 : source_color, filter_linear;
uniform sampler2D layer_texture_2 : source_color, filter_linear;
uniform sampler2D layer_texture_3 : source_color, filter_linear;
uniform sampler2D layer_texture_4 : source_color, filter_linear;
uniform sampler2D layer_texture_5 : source_color, filter_linear;

uniform vec4 layer_colors[6];
uniform float layer_props[6];
uniform int layer_count = 6;

uniform float wetness = 0.35;
uniform float fresnel_power = 3.0;
uniform vec3 edge_color : source_color = vec3(1.0, 0.85, 0.4);

varying vec3 world_position;

void vertex() {
	vec2 texel = vec2(1.0 / heightmap_size);
	float center_h = textureLod(heightmap, UV, 0.0).r;
	float h_l = textureLod(heightmap, UV - vec2(texel.x, 0.0), 0.0).r;
	float h_r = textureLod(heightmap, UV + vec2(texel.x, 0.0), 0.0).r;
	float h_d = textureLod(heightmap, UV - vec2(0.0, texel.y), 0.0).r;
	float h_u = textureLod(heightmap, UV + vec2(0.0, texel.y), 0.0).r;
	float cell = terrain_size * texel.x;
	VERTEX.y = center_h;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 n = normalize(vec3(h_l - h_r, 2.0 * cell, h_d - h_u));
	NORMAL = n;
}

vec4 layer_tex(int i, vec2 uv) {
	if (i == 0) {
		return texture(layer_texture_0, uv);
	}
	if (i == 1) {
		return texture(layer_texture_1, uv);
	}
	if (i == 2) {
		return texture(layer_texture_2, uv);
	}
	if (i == 3) {
		return texture(layer_texture_3, uv);
	}
	if (i == 4) {
		return texture(layer_texture_4, uv);
	}
	return texture(layer_texture_5, uv);
}

void fragment() {
	float h_original = texture(original_heightmap, UV).r;
	float dig = texture(dig_mask, UV).r;
	float depth = clamp(h_original - world_position.y, 0.0, 4.0);

	vec3 tri_blend = pow(abs(NORMAL), vec3(4.0));
	tri_blend /= max(tri_blend.x + tri_blend.y + tri_blend.z, 0.001);

	vec3 col = vec3(0.0);
	float weight_sum = 0.0;
	float accum = 0.0;
	for (int i = 0; i < 6; i++) {
		if (i >= layer_count) {
			break;
		}
		float thickness = max(layer_props[i] * 0.7 + 0.3, 0.3);
		float w = smoothstep(accum - 0.12, accum + 0.12, depth)
			* (1.0 - smoothstep(accum + thickness - 0.12, accum + thickness + 0.12, depth));
		vec4 tex = layer_tex(i, world_position.xz * 0.15);
		vec3 tinted = layer_colors[i].rgb * (0.4 + tex.rgb * 0.8);
		col += tinted * w;
		weight_sum += w;
		accum += thickness;
	}

	vec3 base = layer_colors[0].rgb;
	if (weight_sum > 0.001) {
		base = col / weight_sum;
	}

	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), fresnel_power);
	float edge = fres * dig;
	base = mix(base, edge_color, edge * 0.6);
	base *= mix(1.0, 1.0 - wetness, clamp(depth / 4.0, 0.0, 1.0));

	ALBEDO = base;
	ROUGHNESS = mix(0.92, 0.5, clamp(depth / 4.0, 0.0, 1.0));
	METALLIC = 0.0;
}

shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D sand_tex : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D grass_tex : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D rock_tex : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D snow_tex : source_color, repeat_enable, filter_linear_mipmap;
uniform float biome_id = 0.0;
uniform float uv_scale = 0.16;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 tuv = world_pos.xz * uv_scale;
	float slope = 1.0 - clamp(world_normal.y, 0.0, 1.0);
	vec3 albedo = texture(sand_tex, tuv).rgb;
	vec3 grass = texture(grass_tex, tuv * 1.15).rgb;
	vec3 rock = texture(rock_tex, tuv * 0.62).rgb;
	vec3 snow = texture(snow_tex, tuv).rgb;
	float grass_w = (biome_id > 0.5 && biome_id < 1.5) ? 0.82 : ((biome_id > 1.5 && biome_id < 2.5) ? 0.12 : 0.22);
	albedo = mix(albedo, grass, grass_w * (1.0 - smoothstep(0.22, 0.62, slope)) * smoothstep(-0.05, 0.28, world_pos.y));
	albedo = mix(albedo, rock, smoothstep(0.3, 0.72, slope) + (biome_id > 2.5 ? 0.28 : 0.0));
	albedo = mix(albedo, snow, ((biome_id > 1.5 && biome_id < 2.5) ? 0.78 : 0.0) * smoothstep(0.12, 0.5, world_pos.y) * (1.0 - slope));
	albedo = mix(vec3(0.34, 0.2, 0.12), albedo, smoothstep(-0.6, 0.02, world_pos.y));
	ALBEDO = albedo * COLOR.rgb;
	ROUGHNESS = mix(0.96, 0.72, slope);
	METALLIC = 0.0;
}

shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;

uniform sampler2D warp_noise : repeat_disable, filter_linear;

uniform vec3 ridge_light : source_color = vec3(0.161, 0.176, 0.231);
uniform vec3 ridge_dark : source_color = vec3(0.024, 0.024, 0.031);

// Lower reads straighter and more vertical; higher lets cracks wander and branch.
uniform float vertical_stretch : hint_range(0.02, 1.0) = 0.12;
// Side-to-side meander of a crack's path. 0 is dead straight.
uniform float wobble_amount : hint_range(0.0, 0.3) = 0.06;
uniform float crack_width : hint_range(0.0, 0.3) = 0.05;
uniform float crack_softness : hint_range(0.0, 0.3) = 0.04;

void fragment() {
	// Varies with U as well as V so neighbouring cracks drift independently
	// rather than the whole surface shearing together.
	float wobble = (texture(warp_noise, vec2(UV.x * 0.6 + 0.15, UV.y * 0.4)).r - 0.5) * 2.0 * wobble_amount;

	// Compressing V before the lookup stretches the noise field's blobs along V,
	// so the boundaries between them — where the crack sits — run lengthwise.
	vec2 crack_uv = vec2(UV.x + wobble, UV.y * vertical_stretch);
	float n = texture(warp_noise, crack_uv).r;
	float crack = 1.0 - smoothstep(crack_width, crack_width + crack_softness, abs(n - 0.5) * 2.0);

	ALBEDO = mix(ridge_light, ridge_dark, crack);
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}

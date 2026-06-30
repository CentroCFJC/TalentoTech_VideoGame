shader_type canvas_item;

uniform vec4 beam_color : source_color = vec4(1.0, 0.85, 0.2, 1.0);
uniform float alpha_scale : hint_range(0.0, 1.0) = 0.3;
uniform float time_value : hint_range(0.0, 3600.0) = 0.0;

void fragment() {
	float dist = abs(UV.x - 0.5) * 2.0;

	float core = exp(-dist * 3.0);
	float edge = 1.0 - smoothstep(0.0, 1.0, dist);
	float shimmer = sin(UV.y * 12.0 + time_value * 2.0) * 0.04 + 0.96;
	float stripe = exp(-dist * 6.0) * 0.3;

	float alpha = (core * 0.5 + edge * 0.5 + stripe) * alpha_scale * shimmer;

	COLOR = vec4(beam_color.rgb, alpha);
}

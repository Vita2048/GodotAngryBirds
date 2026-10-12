shader_type canvas_item;
uniform float hit_flash : hint_range(0.0, 1.0) = 0.0;
uniform vec2 impact_position = vec2(0.0);
uniform float impact_radius = 26.0;
varying vec2 local_position;

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	float falloff = exp(-length(local_position - impact_position) / impact_radius);
	COLOR.rgb = mix(COLOR.rgb, vec3(1.0, 0.96, 0.81), hit_flash * falloff * 0.42);
}

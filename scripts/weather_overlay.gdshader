shader_type canvas_item;

// Flat full-screen tint driven by WeatherVisual's category mapping.
// No particles, no lighting -- just a shader wash making the current
// weather visually distinct at a glance.
uniform vec4 weather_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float weather_intensity : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	COLOR = vec4(weather_tint.rgb, weather_intensity);
}

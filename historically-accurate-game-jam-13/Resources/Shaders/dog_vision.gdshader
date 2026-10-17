shader_type canvas_item;
render_mode unshaded, blend_disabled;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

void fragment() {
	vec3 scene_color = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
	float yellow = dot(scene_color.rg, vec2(0.23, 0.77));
	COLOR = vec4(yellow, yellow, scene_color.b, 1.0);
}

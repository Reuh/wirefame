return [[

# ifdef VERTEX
uniform mat4 scene_transform; // world -> view transform
uniform mat4 model_transform; // model -> world transform

vec4 position(mat4 love_transform, vec4 vertex_position) {
	return scene_transform * model_transform * vertex_position;
}
# endif

# ifdef PIXEL
uniform vec3 pick_color;

vec4 effect(vec4 color, sampler2D texture, vec2 texture_coords, vec2 screen_coords) {
	if (texture2D(texture, texture_coords).a < 0.1) discard;
	return vec4(pick_color, 1);
}
# endif

]]

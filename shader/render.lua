return [[

varying vec3 normal_world; // vertex normal in world space
varying vec4 position_world; // fragment position in world space

# ifdef VERTEX
uniform mat4 scene_transform; // world -> view transform
uniform mat4 model_transform; // model -> world transform

attribute vec3 VertexNormal;

vec4 position(mat4 love_transform, vec4 vertex_position) {
	normal_world = (model_transform * vec4(VertexNormal, 0)).xyz;
	position_world = model_transform * vertex_position;
	return scene_transform * position_world;
}
# endif

# ifdef PIXEL
# if LIGHT_COUNT > 0
	struct Light {
		int type; // 1 for ambient, 2 for directional, 3 for point
		vec3 position; // position for point lights, or direction for directional lights
		vec4 color; // diffuse color for point and directional lights, or ambient color for ambient light (alpha is intensity)
	};

	uniform Light[LIGHT_COUNT] lights;
# endif

uniform vec4 baseColorFactor;

vec4 effect(vec4 color, sampler2D texture, vec2 texture_coords, vec2 screen_coords) {
	// base color
	vec4 material_color = texture2D(texture, texture_coords) * baseColorFactor * color;
	if (material_color.a < 0.1) discard;

	# if LIGHT_COUNT > 0
		// shading
		vec4 final_color = vec4(0.0, 0.0, 0.0, material_color.a);
		for (int i = 0; i < LIGHT_COUNT; i++) {
			Light light = lights[i];

			// ambient
			if (light.type == 1) {
				final_color.rgb += material_color.rgb * light.color.rgb * light.color.a;

			// directional
			} else if (light.type == 2) {
				// diffuse lighting
				vec3 n = normalize(normal_world);
				vec3 l = normalize(-light.position);
				final_color.rgb += material_color.rgb * light.color.rgb * light.color.a * max(dot(n, l), 0.0);

			// point
			} else if (light.type == 3) {
				// diffuse lighting
				vec3 n = normalize(normal_world);
				vec3 l = normalize(light.position - position_world.xyz);
				float distance = length(light.position - position_world.xyz);
				final_color.rgb += material_color.rgb * light.color.rgb * light.color.a * max(dot(n, l), 0.0) / (distance * distance);
			}

			// no specular because i'm lazy (TODO)
		}

		// done
		return final_color;
	# else
		return material_color;
	# endif
}
# endif

]]

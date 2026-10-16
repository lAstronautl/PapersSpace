shader_type canvas_item;

// Port of StarHorizon's Resources/Textures/Shaders/paperstamp.swsl, with Robust's
// zNoise/zRandom from Robust.Client/Graphics/Clyde/Shaders/z-library.glsl.
// Object position in screen space: lets the noise keep a constant screen-space
// size, unaffected by where the stamp sits on the page.
uniform vec2 objCoord = vec2(0.0);

vec2 zRandom(vec2 uv) {
	uv = vec2(dot(uv, vec2(127.1, 311.7)), dot(uv, vec2(269.5, 183.3)));
	return -1.0 + 2.0 * fract(sin(uv) * 43758.5453123);
}

float zNoise(vec2 uv) {
	vec2 uv_index = floor(uv);
	vec2 uv_fract = fract(uv);
	vec2 blur = smoothstep(0.0, 1.0, uv_fract);
	return mix(mix(dot(zRandom(uv_index + vec2(0.0, 0.0)), uv_fract - vec2(0.0, 0.0)),
				   dot(zRandom(uv_index + vec2(1.0, 0.0)), uv_fract - vec2(1.0, 0.0)), blur.x),
			   mix(dot(zRandom(uv_index + vec2(0.0, 1.0)), uv_fract - vec2(0.0, 1.0)),
				   dot(zRandom(uv_index + vec2(1.0, 1.0)), uv_fract - vec2(1.0, 1.0)), blur.x), blur.y) * 0.5 + 0.5;
}

// Robust multiplies the shader's output by the draw modulate AFTER fragment(); Godot
// hands COLOR over already multiplied, so the stamp colour is passed explicitly.
uniform vec4 tint : source_color = vec4(1.0);

void fragment() {
	// Stamps have orientation, and the texture sampling is nearest pixel, so run
	// a bilinear filter to smooth out the edges.
	vec4 tl = texture(TEXTURE, UV);
	vec4 tr = texture(TEXTURE, UV + vec2(TEXTURE_PIXEL_SIZE.x, 0.0));
	vec4 bl = texture(TEXTURE, UV + vec2(0.0, TEXTURE_PIXEL_SIZE.y));
	vec4 br = texture(TEXTURE, UV + TEXTURE_PIXEL_SIZE);
	vec2 textureSize = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 f = fract(UV * textureSize);
	vec4 tA = mix(tl, tr, f.x);
	vec4 tB = mix(bl, br, f.x);
	vec4 sampled = mix(tA, tB, f.y);
	COLOR = vec4(sampled.rgb * tint.rgb, sampled.a * tint.a);

	// Add a bit of noise to mimic imperfect contact with the paper.
	float stampNoise = zNoise((FRAGCOORD.xy - objCoord) * vec2(0.03, 0.03)) *
			zNoise((FRAGCOORD.xy - objCoord) * vec2(0.08, 0.08));
	COLOR.a *= min(0.9, 0.4 + smoothstep(0.05, 0.3, stampNoise));
}

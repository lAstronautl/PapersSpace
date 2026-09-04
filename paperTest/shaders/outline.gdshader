shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float outline_width : hint_range(0.0, 10.0) = 1.0;

void fragment() {
    // COLOR starts out pre-multiplied by the node's modulate/self_modulate
    // before this function runs; capture it here since sampling TEXTURE
    // directly below returns the raw, unmodulated texel.
    vec4 modulated_color = COLOR;

    vec2 size = TEXTURE_PIXEL_SIZE * outline_width;
    vec4 sprite_color = texture(TEXTURE, UV);

    float outline = 0.0;
    
    // Check 8 directions around the pixel
    outline += texture(TEXTURE, UV + vec2(-size.x, 0.0)).a;
    outline += texture(TEXTURE, UV + vec2(size.x, 0.0)).a;
    outline += texture(TEXTURE, UV + vec2(0.0, -size.y)).a;
    outline += texture(TEXTURE, UV + vec2(0.0, size.y)).a;
    outline += texture(TEXTURE, UV + vec2(-size.x, -size.y)).a;
    outline += texture(TEXTURE, UV + vec2(size.x, -size.y)).a;
    outline += texture(TEXTURE, UV + vec2(-size.x, size.y)).a;
    outline += texture(TEXTURE, UV + vec2(size.x, size.y)).a;
    
    outline = min(outline, 1.0);
    
    // If current pixel is transparent but neighbors aren't, draw outline
    vec4 final_color = modulated_color;
    if (sprite_color.a == 0.0 && outline > 0.0) {
        final_color = outline_color;
    }

    COLOR = final_color;
}
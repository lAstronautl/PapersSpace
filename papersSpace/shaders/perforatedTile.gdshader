shader_type canvas_item;

uniform sampler2D tileTexture: filter_linear, repeat_enable;
uniform vec2 nodeSizePx = vec2(510.0, 660.0);
uniform vec2 tileSizePx = vec2(13.0, 13.0);
uniform float diamondScale = 1.0;
uniform vec4 paperColor: source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 holeColor: source_color = vec4(0.35, 0.35, 0.35, 1.0);
uniform float edgeMarginPx = 6.0;

void fragment() {
    vec2 tileCount = nodeSizePx / tileSizePx;
    vec2 tiledUv = fract(UV * tileCount);

    // Shrink the diamond within its own tile cell (sample from a smaller,
    // centered region of the source texture, padded with transparency)
    // instead of just spacing tiles further apart. Scaling both axes by the
    // SAME factor (not tileSizePx-relative) keeps the diamond's own aspect
    // ratio intact even when tileSizePx itself is anisotropic (e.g. denser
    // vertically than horizontally) - scaling each axis independently by
    // its own cell size would stretch/squash the diamond into an unusable
    // sliver whenever the X/Y tile periods differ.
    vec2 centered = (tiledUv - 0.5) / diamondScale + 0.5;
    float diamondAlpha = 0.0;
    if (centered.x >= 0.0 && centered.x <= 1.0 && centered.y >= 0.0 && centered.y <= 1.0) {
        diamondAlpha = texture(tileTexture, centered).a;
    }

    float pixelY = UV.y * nodeSizePx.y;
    float pixelX = UV.x * nodeSizePx.x;

    // Sharp, hard-edged sawtooth silhouette for the top/bottom torn edge -
    // NOT sampled from the (antialiased, bilinear-filtered) diamond texture,
    // which only ever produces soft/rounded transitions. A triangle wave
    // across X, one full up-down cycle per horizontal tile period, gives a
    // crisp zigzag with sharp triangular points (no smoothstep/mix blur).
    float xPhase = fract(pixelX / tileSizePx.x);
    float sawtooth = 1.0 - abs(xPhase * 2.0 - 1.0);
    float topCut = edgeMarginPx * sawtooth;
    float bottomCut = nodeSizePx.y - edgeMarginPx * sawtooth;

    if (pixelY < topCut || pixelY > bottomCut) {
        COLOR = vec4(0.0);
    } else if (pixelY < edgeMarginPx || pixelY > nodeSizePx.y - edgeMarginPx) {
        COLOR = vec4(paperColor.rgb, 1.0);
    } else {
        vec3 composited = mix(holeColor.rgb, paperColor.rgb, diamondAlpha);
        COLOR = vec4(composited, 1.0);
    }
}

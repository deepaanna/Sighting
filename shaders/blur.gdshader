// Sighting! — camera viewfinder blur pipeline
// Applied as a ShaderMaterial on the ViewportDisplay TextureRect.
//
// blur_amount  : 0 = sharp (far away), 1.5 = sweet-spot, 10 = close-up chaos
// overexposure : 0 = normal, 0.85 = completely washed out (very close)
// Grain and vignette are always on at low intensities.

shader_type canvas_item;

uniform float blur_amount    : hint_range(0.0, 12.0) = 0.0;
uniform float overexposure   : hint_range(0.0, 1.0)  = 0.0;
uniform float film_grain_str : hint_range(0.0, 0.12) = 0.028;
uniform float vignette_str   : hint_range(0.0, 2.0)  = 0.75;

// Hash for film grain — UV + TIME keeps it animated
float hash21(vec2 p) {
    p = fract(p * vec2(127.1, 311.7));
    p += dot(p, p + 34.23);
    return fract(p.x * p.y);
}

void fragment() {
    vec2 tex_sz = vec2(textureSize(TEXTURE, 0));
    vec2 px     = blur_amount / tex_sz;

    // 3×3 Gaussian blur — explicit taps for GLSL ES compatibility
    vec4 col = vec4(0.0);
    col += texture(TEXTURE, UV + vec2(-1.0, -1.0) * px) * 0.0625;
    col += texture(TEXTURE, UV + vec2( 0.0, -1.0) * px) * 0.125;
    col += texture(TEXTURE, UV + vec2( 1.0, -1.0) * px) * 0.0625;
    col += texture(TEXTURE, UV + vec2(-1.0,  0.0) * px) * 0.125;
    col += texture(TEXTURE, UV + vec2( 0.0,  0.0) * px) * 0.25;
    col += texture(TEXTURE, UV + vec2( 1.0,  0.0) * px) * 0.125;
    col += texture(TEXTURE, UV + vec2(-1.0,  1.0) * px) * 0.0625;
    col += texture(TEXTURE, UV + vec2( 0.0,  1.0) * px) * 0.125;
    col += texture(TEXTURE, UV + vec2( 1.0,  1.0) * px) * 0.0625;

    // Chromatic aberration — splits R and B channels when close
    if (overexposure > 0.12) {
        float ca   = overexposure * 5.5;
        vec2  ca_r = vec2(ca, 0.0) / tex_sz;
        vec2  ca_b = vec2(-ca, 0.0) / tex_sz;
        col.r = texture(TEXTURE, UV + ca_r).r;
        col.b = texture(TEXTURE, UV + ca_b).b;
    }

    // Overexposure — wash toward white
    col.rgb = mix(col.rgb, vec3(1.0), overexposure * 0.65);

    // Film grain — animated via TIME built-in
    float grain = (hash21(UV * tex_sz + vec2(TIME * 7.3, TIME * 11.9)) * 2.0 - 1.0);
    col.rgb    += grain * film_grain_str;

    // Vignette
    vec2  uvc = UV - 0.5;
    float vgn = 1.0 - dot(uvc, uvc) * vignette_str * 2.2;
    col.rgb   *= clamp(vgn, 0.0, 1.0);

    COLOR = clamp(col, 0.0, 1.0);
}

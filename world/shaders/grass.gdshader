shader_type spatial;
render_mode cull_disabled;
#include "res://world/shaders/weather_common.gdshaderinc"

global uniform vec2 wind_dir;
global uniform float wind_strength;
global uniform float wind_gust;
global uniform float wind_time;

uniform sampler2D albedo_tex : source_color, filter_nearest;
uniform float sway = 0.09;
// Grass interaction (scripts/tall_grass.gd). `pushers`: up to 8 walkers (the player and the party
// out with them), xz = world position, w = radius (0 = unused). Blades inside a radius bend away
// from the walker, more towards the tip. `shake`: a local shudder before a grass ambush,
// xz = centre, w = strength 0..1 (0 = calm); the radius is fixed (SHAKE_RADIUS).
uniform vec4 pushers[8];
uniform vec4 shake;
const float SHAKE_RADIUS = 2.2;

varying vec3 world_pos;

void vertex() {
    vec3 wp = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
    world_pos = wp;
    vec2 wd = normalize(wind_dir);
    // One wave: the phase travels along wind_dir, so a gust crosses the lawn.
    float ph = wind_time * 2.0 + dot(wp.xz, wd) * 0.6 + wp.x * 0.3;
    float w = sin(ph) + 0.4 * sin(ph * 2.3);
    // D77: wet grass sways harder and droops a little in heavy rain.
    float wet_grass = weather_at(wp).r;
    float amp = sway * (1.0 - UV.y) * (wind_strength + wind_gust) * (1.0 + 0.9 * wet_grass);
    VERTEX.xz += wd * amp * w;
    // Push: blades part around the walkers.
    vec2 push = vec2(0.0);
    for (int i = 0; i < 8; i++) {
        if (pushers[i].w <= 0.0) {
            continue;
        }
        vec2 d = wp.xz - pushers[i].xz;
        float dist = length(d);
        if (dist < pushers[i].w) {
            float f = 1.0 - dist / pushers[i].w;
            push += normalize(d + vec2(1e-4, 1e-4)) * f * f * pushers[i].w * 0.7;
        }
    }
    // Shudder: the patch shakes around the player, right before an ambush.
    if (shake.w > 0.0) {
        vec2 d = wp.xz - shake.xz;
        float dist = length(d);
        if (dist < SHAKE_RADIUS) {
            float f = 1.0 - dist / SHAKE_RADIUS;
            push += vec2(sin(wind_time * 34.0 + wp.x * 4.0), cos(wind_time * 30.0 + wp.z * 4.0))
                    * f * f * shake.w * 0.5;
        }
    }
    // Back into the instance's own frame (a flipped blade's local +x is world -x).
    VERTEX += inverse(mat3(MODEL_MATRIX)) * vec3(push, 0.0) * UV.y;
    VERTEX.y *= 1.0 - 0.12 * wet_grass;
    NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
    vec4 c = texture(albedo_tex, UV);
    ALBEDO = c.rgb * COLOR.rgb;
    ALPHA = c.a;
    ALPHA_SCISSOR_THRESHOLD = 0.5;
    ROUGHNESS = 1.0;
    vec4 w = weather_at(world_pos);
    // Snow on the blade TIPS (height, not the card normal), capped so the blades stay readable.
    weather_surface(ALBEDO, ROUGHNESS, smoothstep(0.2, 0.8, UV.y), w, 0.5);
}

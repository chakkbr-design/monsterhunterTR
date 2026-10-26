class_name WorldPostFx
extends CanvasLayer
## Port of the original post_fx.gd: split toning (shadow / highlight tints driven by the time of
## day), vignette and film grain over the 3D view, plus the weather grade (WorldTimeOfDay sets
## weather_desat / weather_dim from the cloud cover and the storm gloom: overcast and rainy days
## read muted and a little cool, storms darker). Sits below the HUD layers.

@export_range(0.0, 1.0) var vignette := 0.45
@export_range(0.0, 1.0) var vignette_softness := 0.55
@export_range(0.0, 0.1) var grain := 0.018
@export var shadow_tint := Color(0.36, 0.42, 0.6)
@export var highlight_tint := Color(1.0, 0.9, 0.72)
@export_range(0.0, 1.0) var toning := 0.16
@export_range(0.0, 1.0) var weather_desat := 0.0
@export_range(0.0, 1.0) var weather_dim := 0.0

const SHADER := """
shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float vignette;
uniform float softness;
uniform float grain;
uniform vec3 shadow_tint;
uniform vec3 highlight_tint;
uniform float toning;
uniform float desat;
uniform float dim;
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec3 c = texture(screen, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, l * vec3(0.93, 0.98, 1.07), desat) * (1.0 - dim);
	l *= 1.0 - dim;
	vec3 toned = mix(c * shadow_tint * 1.6, c * highlight_tint, smoothstep(0.1, 0.8, l));
	c = mix(c, toned, toning);
	vec2 d = (SCREEN_UV - 0.5) * vec2(1.0, 0.8);
	float v = smoothstep(0.75, 0.75 - softness, length(d) * 1.35);
	c *= mix(1.0 - vignette, 1.0, v);
	c += (hash(SCREEN_UV * 1000.0 + TIME) - 0.5) * grain;
	COLOR = vec4(c, 1.0);
}
"""

var _mat: ShaderMaterial


func _ready() -> void:
	layer = -1
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	rect.material = _mat
	add_child(rect)


func _process(_d: float) -> void:
	_mat.set_shader_parameter("vignette", vignette)
	_mat.set_shader_parameter("softness", vignette_softness)
	_mat.set_shader_parameter("grain", grain)
	_mat.set_shader_parameter("shadow_tint", Vector3(shadow_tint.r, shadow_tint.g, shadow_tint.b))
	_mat.set_shader_parameter(
		"highlight_tint", Vector3(highlight_tint.r, highlight_tint.g, highlight_tint.b)
	)
	_mat.set_shader_parameter("toning", toning)
	_mat.set_shader_parameter("desat", weather_desat)
	_mat.set_shader_parameter("dim", weather_dim)

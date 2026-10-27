class_name BattleHpBar
extends MeshInstance3D
## HP bar over a fighter's head (Caio, 2026-10-27). Always the same size on screen (the shader
## places the quad in pixels, so the camera zoom does not grow or shrink it), drawn over the
## scenery. Thick black rounded border with a soft shadow, green / yellow / red fill with a shine on
## top and quarter ticks. A hit flashes the bar white and shakes it, and the lost part stays yellow
## for TRAIL_WAIT s before it drains; a heal fills up through a pale green part. Low HP pulses.

## Whole bar (border included) in screen pixels, border and shadow widths, corner radius.
const SIZE_PX := Vector2(88.0, 15.0)
const BORDER_PX := 3.0
const SHADOW_PX := 4.0
const RADIUS_PX := 5.0
## Gap (m) between the top of the art and the bar.
const HEAD_GAP := 0.4
## The yellow part waits TRAIL_WAIT s, then drains at TRAIL_EASE (per second, of what is left) and
## at least TRAIL_RATE of the bar per second.
const TRAIL_WAIT := 0.45
const TRAIL_EASE := 3.5
const TRAIL_RATE := 0.25
## A heal fills the bar at this rate (fraction per second).
const HEAL_RATE := 0.8
## Hit: white flash fading at FLASH_FADE per second, shake for SHAKE_SECS (amplitude in px grows
## with the damage, SHAKE_MIN to SHAKE_MAX).
const FLASH_FADE := 6.0
const SHAKE_SECS := 0.25
const SHAKE_MIN := 1.5
const SHAKE_MAX := 5.0
## At or under LOW the bar pulses.
const LOW := 0.25

const SHADER := """
shader_type spatial;
render_mode unshaded, depth_test_disabled, cull_disabled, shadows_disabled, skip_vertex_transform;
uniform float fill = 1.0;
uniform float trail = 1.0;
uniform float heal = 1.0;
uniform float flash = 0.0;
uniform float pulse = 1.0;
uniform vec4 bar_col : source_color = vec4(0.3, 0.9, 0.35, 1.0);
uniform vec4 trail_col : source_color = vec4(1.0, 0.88, 0.25, 1.0);
uniform vec2 size_px = vec2(88.0, 15.0);
uniform vec2 shake_px = vec2(0.0);
uniform float border = 3.0;
uniform float shadow = 4.0;
uniform float radius = 5.0;

vec2 full_px() {
	return size_px + vec2(2.0 * shadow);
}

float round_box(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + vec2(r);
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

void vertex() {
	vec4 c = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0));
	vec2 off = (VERTEX.xy * full_px() + shake_px) * 2.0 / VIEWPORT_SIZE * c.w;
	POSITION = c + vec4(off, 0.0, 0.0);
}

void fragment() {
	// UV.y comes flipped on screen: p.y grows upward.
	vec2 p = (UV - vec2(0.5)) * full_px();
	float d = round_box(p, size_px * 0.5, radius);
	vec3 col = vec3(0.0);
	float a = 1.0;
	if (d > 0.0) {
		a = 0.5 * (1.0 - smoothstep(0.0, shadow, d));
	} else if (d > -border) {
		col = vec3(0.02);
	} else {
		vec2 inner = size_px - vec2(2.0 * border);
		float x = (p.x + inner.x * 0.5) / inner.x;
		float y = clamp((p.y + inner.y * 0.5) / inner.y, 0.0, 1.0);
		float shade = mix(0.7, 1.08, y);
		col = vec3(0.13, 0.13, 0.16) * mix(0.8, 1.2, y);
		if (x <= fill) {
			col = bar_col.rgb * shade * pulse;
			if (y > 0.6) {
				col = mix(col, vec3(1.0), 0.32);
			}
			col = mix(col, vec3(1.0), flash);
		} else if (x <= heal) {
			col = vec3(0.65, 1.0, 0.75) * shade;
		} else if (x <= trail) {
			col = mix(trail_col.rgb * shade, vec3(1.0), flash * 0.6);
		}
		// Quarter ticks.
		float q = x * 4.0;
		float k = round(q);
		if (k >= 1.0 && k <= 3.0 && abs(q - k) * inner.x * 0.25 < 0.6) {
			col *= 0.55;
		}
	}
	ALBEDO = col;
	ALPHA = a;
}
"""

static var _shader: Shader

var fighter: Node3D
## What the bar shows: fill (drops at once on a hit, rises with a heal), the yellow trail.
var _shown := 1.0
var _trail := 1.0
var _wait := 0.0
var _last := 1.0
var _flash := 0.0
var _shake := 0.0
var _shake_amp := 0.0
var _t := 0.0
var _mat: ShaderMaterial


func _init(f: Node3D) -> void:
	fighter = f
	name = "HpBar"
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = _shader
	_mat.render_priority = 10
	_mat.set_shader_parameter("size_px", SIZE_PX)
	_mat.set_shader_parameter("border", BORDER_PX)
	_mat.set_shader_parameter("shadow", SHADOW_PX)
	_mat.set_shader_parameter("radius", RADIUS_PX)
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	q.material = _mat
	mesh = q
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 2.0


## Per frame: dt in fight seconds; hp / max_hp from the fighter; head = height of the art (m).
func step(dt: float, hp: int, max_hp: int, head: float, show: bool) -> void:
	visible = show and hp > 0
	if not visible:
		return
	_t += dt
	var f := clampf(float(hp) / float(maxi(max_hp, 1)), 0.0, 1.0)
	if f < _last:
		_wait = TRAIL_WAIT
		_flash = 1.0
		_shake = SHAKE_SECS
		_shake_amp = clampf((_last - f) * 40.0, SHAKE_MIN, SHAKE_MAX)
	_last = f
	_shown = minf(_shown + HEAL_RATE * dt, f) if _shown < f else f
	if _trail < _shown:
		_trail = _shown
	elif _wait > 0.0:
		_wait -= dt
	else:
		var drop := maxf((_trail - _shown) * TRAIL_EASE, TRAIL_RATE) * dt
		_trail = maxf(_trail - drop, _shown)
	_flash = maxf(_flash - FLASH_FADE * dt, 0.0)
	var shake := Vector2.ZERO
	if _shake > 0.0:
		_shake = maxf(_shake - dt, 0.0)
		var k := _shake_amp * _shake / SHAKE_SECS
		shake = Vector2(sin(_t * 95.0), cos(_t * 71.0)) * k
	position = Vector3(0.0, head + HEAD_GAP, 0.0)
	var col := Color(0.3, 0.9, 0.35)
	if f <= 0.2:
		col = Color(0.95, 0.25, 0.2)
	elif f <= 0.5:
		col = Color(0.98, 0.8, 0.2)
	_mat.set_shader_parameter("fill", _shown)
	_mat.set_shader_parameter("heal", f)
	_mat.set_shader_parameter("trail", _trail)
	_mat.set_shader_parameter("flash", _flash)
	_mat.set_shader_parameter("pulse", 0.8 + 0.25 * sin(_t * 9.0) if f <= LOW else 1.0)
	_mat.set_shader_parameter("shake_px", shake)
	_mat.set_shader_parameter("bar_col", col)
	# The trail is yellow; on a yellow bar it goes pale cream so the two still read apart.
	_mat.set_shader_parameter(
		"trail_col", Color(1.0, 0.98, 0.82) if f > 0.2 and f <= 0.5 else Color(1.0, 0.88, 0.25)
	)

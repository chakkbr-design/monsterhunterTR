class_name BattleHpBar
extends MeshInstance3D
## Small HP bar over a fighter's head (Caio, 2026-10-27). Always the same size on screen (the
## shader places the quad in pixels, so the camera zoom does not grow or shrink it), drawn over
## the scenery, green / yellow / red like the HUD, with a pale trail that catches up after a hit.

const SIZE_PX := Vector2(54.0, 7.0)
## Gap (m) between the top of the art and the bar.
const HEAD_GAP := 0.35
## How fast the trail follows the bar (fraction of the bar per second), after TRAIL_WAIT s.
const TRAIL_RATE := 0.9
const TRAIL_WAIT := 0.35

const SHADER := """
shader_type spatial;
render_mode unshaded, depth_test_disabled, cull_disabled, shadows_disabled, skip_vertex_transform;
uniform float fill = 1.0;
uniform float trail = 1.0;
uniform vec4 bar_col : source_color = vec4(0.3, 0.9, 0.35, 1.0);
uniform vec2 size_px = vec2(54.0, 7.0);
void vertex() {
	vec4 c = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0));
	vec2 off = VERTEX.xy * 2.0 * size_px / VIEWPORT_SIZE * c.w;
	POSITION = c + vec4(off, 0.0, 0.0);
}
void fragment() {
	vec2 px = UV * size_px;
	float edge = min(min(px.x, size_px.x - px.x), min(px.y, size_px.y - px.y));
	vec3 col = vec3(0.12, 0.12, 0.14);
	float x = UV.x;
	if (edge >= 1.0) {
		if (x <= fill) {
			col = bar_col.rgb * (UV.y < 0.45 ? 1.0 : 0.82);
		} else if (x <= trail) {
			col = vec3(0.95, 0.55, 0.45);
		} else {
			col = vec3(0.22, 0.22, 0.25);
		}
	}
	ALBEDO = col;
}
"""

static var _shader: Shader

var fighter: Node3D
var _trail := 1.0
var _wait := 0.0
var _last := 1.0
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
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	q.material = _mat
	mesh = q
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 2.0


## Per frame: dt in real seconds; hp / max_hp from the fighter; head = height of the art (m).
func step(dt: float, hp: int, max_hp: int, head: float, show: bool) -> void:
	visible = show and hp > 0
	if not visible:
		return
	var f := clampf(float(hp) / float(maxi(max_hp, 1)), 0.0, 1.0)
	if f < _last:
		_wait = TRAIL_WAIT
	_last = f
	if _trail < f:
		_trail = f
	elif _wait > 0.0:
		_wait -= dt
	else:
		_trail = maxf(_trail - TRAIL_RATE * dt, f)
	position = Vector3(0.0, head + HEAD_GAP, 0.0)
	var col := Color(0.3, 0.9, 0.35)
	if f <= 0.2:
		col = Color(0.95, 0.25, 0.2)
	elif f <= 0.5:
		col = Color(0.98, 0.8, 0.2)
	_mat.set_shader_parameter("fill", f)
	_mat.set_shader_parameter("trail", _trail)
	_mat.set_shader_parameter("bar_col", col)

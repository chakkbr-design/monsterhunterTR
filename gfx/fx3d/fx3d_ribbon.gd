class_name Fx3DRibbon
extends MeshInstance3D
## Fita virada para a câmera por uma lista de pontos (raio elétrico, corte, rastro, chicote).
## `shape` refaz os pontos a cada quadro (ou a cada `jitter_every` s, no raio). tick(dt) -> bool.

var pts := PackedVector3Array()
var widths := PackedFloat32Array()  ## largura por ponto (vazio = width)
var alphas := PackedFloat32Array()  ## alfa por ponto (vazio = 1)
var width := 0.1
var life := 0.3
var age := 0.0
var fade_in := 0.05
var fade_out := 0.5
var col := Color.WHITE
var cam_pos := Vector3.ZERO
var cam_node: Camera3D
var shape: Callable  ## func(r: Fx3DRibbon, k: float) -> void (k = age/life), muda pts
var jitter_every := 0.0
var _jt := 0.0
var _im := ImmediateMesh.new()


static func make(mat: Material, c: Color, w: float, secs: float, cam: Camera3D) -> Fx3DRibbon:
	var r := Fx3DRibbon.new()
	r.mesh = r._im
	r.material_override = mat
	r.col = c
	r.width = w
	r.life = maxf(secs, 0.02)
	r.cam_node = cam
	r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	r.top_level = true
	r.extra_cull_margin = 16.0
	r.set_instance_shader_parameter("tint", c)
	return r


func tick(dt: float) -> bool:
	age += dt
	if age >= life or not is_inside_tree():
		return false
	var k := age / life
	if shape.is_valid():
		if jitter_every <= 0.0:
			shape.call(self, k)
		else:
			_jt -= dt
			if _jt <= 0.0:
				_jt = jitter_every
				shape.call(self, k)
	set_instance_shader_parameter("fade", Fx3D.env(k, fade_in, fade_out))
	rebuild()
	return true


func rebuild() -> void:
	_im.clear_surfaces()
	var np := pts.size()
	if np < 2:
		return
	if cam_node and is_instance_valid(cam_node) and cam_node.is_inside_tree():
		cam_pos = cam_node.global_position
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in np:
		var p := pts[i]
		var tang := pts[mini(i + 1, np - 1)] - pts[maxi(i - 1, 0)]
		var view := cam_pos - p
		var side := tang.cross(view)
		side = side.normalized() if side.length() > 0.0001 else Vector3.UP
		var w := (widths[i] if i < widths.size() else width) * 0.5
		var a := alphas[i] if i < alphas.size() else 1.0
		var u := float(i) / float(np - 1)
		_im.surface_set_color(Color(1, 1, 1, a))
		_im.surface_set_uv(Vector2(u, 0.0))
		_im.surface_add_vertex(p - side * w)
		_im.surface_set_color(Color(1, 1, 1, a))
		_im.surface_set_uv(Vector2(u, 1.0))
		_im.surface_add_vertex(p + side * w)
	_im.surface_end()


## Linha em zigue-zague de `a` até `b` (raio): `segs` pedaços, desvio `amp` (m), pontas fixas.
static func jag(
	a: Vector3, b: Vector3, segs: int, amp: float, cam_dir := Vector3.FORWARD
) -> PackedVector3Array:
	var out := PackedVector3Array()
	var d := b - a
	var side := d.cross(cam_dir)
	side = side.normalized() if side.length() > 0.001 else Vector3.RIGHT
	var up := d.cross(side).normalized()
	for i in segs + 1:
		var k := float(i) / segs
		var p := a + d * k
		if i > 0 and i < segs:
			var e := sin(k * PI)
			p += side * randf_range(-amp, amp) * e + up * randf_range(-amp, amp) * 0.5 * e
		out.append(p)
	return out

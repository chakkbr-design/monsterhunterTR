class_name BeamFx
extends Node3D
## Porte do vfx_beam.gd: raios esticados do move_fx.json ("beams") com head/body/tail de
## res://original/assets/vfx/pmd/beams/<id>/. Eixo "sky" (raio cai do céu) ou "aim" (disparo).
## Também o jato de fogo sem folha (flame_jet, shader portado). Avança só em tick(dt).

const DIR := "res://original/assets/vfx/pmd/beams/"
const FX_PIXEL_M := 0.03
const SKY_H := 6.0
const FLAME_SHADER := "res://gfx/shaders/flame_jet.gdshader"

var life := 0.6
var age := 0.0
var fade := 0.06
var auto := false
var pulse := 0.0
var travel := 0.0
var _parts: Array = []  # {spr: Sprite3D, n, fps, mat, a, base_y}
var _jets: Array = []  # {mat: ShaderMaterial, a}
var _xf := Transform3D()

static var _tex := {}  # caminho -> Texture2D (ou null)
static var _flame_shader: Shader


## Põe na árvore sob parent e aplica a transformação global calculada em make()/flame_jet().
func place_in(parent: Node) -> void:
	parent.add_child(self)
	global_transform = _xf


static func beams() -> Dictionary:
	return PmdFx.data().get("beams", {})


static func beam_for(move_id: String) -> String:
	var r = PmdFx.move_roles(move_id).get("beam", "")
	return String(r) if r is String else ""


static func axis_of(beam_id: String) -> String:
	return String(beams().get(beam_id, {}).get("axis", "aim"))


static func _part(beam_id: String, part: String, frames: int) -> Dictionary:
	var path := DIR + beam_id.to_lower() + "/" + part + ".png"
	if frames < 1:
		return {}
	if not _tex.has(path):
		_tex[path] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	var tex: Texture2D = _tex[path]
	if tex == null:
		return {}
	var fw := tex.get_width() / frames
	var fh := tex.get_height()
	return {} if fw < 1 or fh < 1 or (fw <= 1 and fh <= 1) else {"tex": tex, "fw": fw, "fh": fh}


static func _tint(v: Variant) -> Color:
	if v is Array and (v as Array).size() >= 3:
		var a := float(v[3]) if (v as Array).size() >= 4 else 1.0
		return Color(float(v[0]), float(v[1]), float(v[2]), a)
	return Color.WHITE


static func _basis(dir: Vector3, axis: int, pos: Vector3, cam: Vector3) -> Basis:
	var d := dir.normalized()
	var to_cam := cam - pos
	var n := to_cam - d * to_cam.dot(d)
	if n.length_squared() < 0.0001:
		n = Vector3.UP.cross(d)
		if n.length_squared() < 0.0001:
			n = Vector3.RIGHT
	n = n.normalized()
	return Basis(d.cross(n), d, n) if axis == Vector3.AXIS_Y else Basis(d, n.cross(d), n)


## Monta o raio (sem pôr na árvore). at/dir em coordenadas globais; cam_pos = posição da câmera.
## Coloque como filho de um nó na origem do mundo (ou ajuste com global_transform) — as peças usam
## posições relativas ao próprio BeamFx, que fica em `at`.
static func make(
	beam_id: String, at: Vector3, dir: Vector3, length: float, dur: float, cam_pos: Vector3
) -> BeamFx:
	var def: Dictionary = beams().get(beam_id, {})
	if def.is_empty():
		return null
	var n := int(def.get("frames", 1))
	var fps := maxf(float(def.get("fps", 16)), 1.0)
	var head := _part(beam_id, "head", n)
	var body := _part(beam_id, "body", n)
	if head.is_empty() or body.is_empty():
		return null
	var b := BeamFx.new()
	b.name = "BeamFx_" + beam_id
	b.set_meta("beam", beam_id)
	b.life = dur if dur > 0.0 else float(n) / fps
	b.pulse = float(def.get("pulse", 0.0))
	b._xf = Transform3D(Basis(), at)
	var tint := _tint(def.get("tint", []))
	var add := String(def.get("blend", "add")) == "add"
	var dia_px := minf(float(head.fw), float(head.fh))
	var thick := float(def.get("thickness", 0.0))
	var k := thick / (dia_px * FX_PIXEL_M) if thick > 0.0 else 1.0
	var end_k := k * float(def.get("head_scale", 1.0))
	if axis_of(beam_id) == "sky":
		b._quad(
			head,
			n,
			fps,
			Vector3(0, float(head.fh) * FX_PIXEL_M * end_k * 0.5, 0),
			Vector3.ONE * end_k,
			tint,
			add
		)
		var tile := float(body.fh) * FX_PIXEL_M
		for i in int(ceil(length / tile)):
			var t := minf(tile, length - float(i) * tile)
			b._quad(
				body,
				n,
				fps,
				Vector3(0, float(i) * tile + t * 0.5, 0),
				Vector3(dia_px / float(body.fw) * k, t / tile, 1),
				tint,
				add
			)
	else:
		var aim := dir.normalized()
		var tail := _part(beam_id, "tail", n)
		var thick_k := 1.0
		if String(def.get("style", "")) == "water":
			thick_k = 1.0
		b._aim(
			head,
			n,
			fps,
			at,
			Vector3.ZERO,
			Vector3.AXIS_Y,
			aim,
			cam_pos,
			Vector3.ONE * end_k,
			tint,
			add
		)
		var tile2 := float(body.fw) * FX_PIXEL_M
		var stretch := dia_px / float(body.fh) * k * thick_k
		var body_len := length / tile2
		b._aim(
			body,
			1,
			fps,
			at,
			aim * (length * 0.5),
			Vector3.AXIS_X,
			aim,
			cam_pos,
			Vector3(body_len, stretch, 1),
			tint,
			add
		)
		var glow_v = def.get("glow", 0.0)
		if glow_v is Array:
			b._aim(
				body,
				1,
				fps,
				at,
				aim * (length * 0.5),
				Vector3.AXIS_X,
				aim,
				cam_pos,
				Vector3(body_len, stretch * 2.0, 1),
				Color(_tint(glow_v), 0.45),
				true
			)
		elif float(glow_v) > 0.0:
			b._aim(
				body,
				1,
				fps,
				at,
				aim * (length * 0.5),
				Vector3.AXIS_X,
				aim,
				cam_pos,
				Vector3(body_len, stretch * float(glow_v), 1),
				_tint(def.get("glow_tint", [])),
				true
			)
		var core_v = def.get("core", 0.0)
		if core_v is Array:
			b._aim(
				body,
				1,
				fps,
				at,
				aim * (length * 0.5),
				Vector3.AXIS_X,
				aim,
				cam_pos,
				Vector3(body_len, stretch * 0.35, 1),
				_tint(core_v),
				true
			)
		elif float(core_v) > 0.0:
			b._aim(
				body,
				1,
				fps,
				at,
				aim * (length * 0.5),
				Vector3.AXIS_X,
				aim,
				cam_pos,
				Vector3(body_len, stretch * float(core_v), 1),
				_tint(def.get("core_tint", [])),
				true
			)
		if not tail.is_empty():
			b._aim(
				tail,
				n,
				fps,
				at,
				aim * length,
				Vector3.AXIS_Y,
				aim,
				cam_pos,
				Vector3.ONE * end_k,
				tint,
				add
			)
	return b


## Jato de fogo (flamethrower): quad orientado com o shader flame_jet portado do original.
static func flame_jet(
	at: Vector3,
	dir: Vector3,
	length: float,
	cfg: Dictionary,
	travel_s: float,
	dur: float,
	cam_pos: Vector3
) -> BeamFx:
	var b := BeamFx.new()
	b.name = "FlameJet"
	b.life = dur
	b.travel = maxf(travel_s, 0.01)
	b.fade = 0.15
	var tip := float(cfg.get("tip", 1.1))
	if _flame_shader == null:
		_flame_shader = load(FLAME_SHADER)  # em cache: recarregar recompila o shader a cada Lança-chamas
	var shader := _flame_shader
	for layer in [
		{"sq": 1.0, "dim": 1.0, "a": 1.0, "z": 0.0}, {"sq": 1.3, "dim": 0.55, "a": 0.6, "z": -0.2}
	]:
		var mesh := QuadMesh.new()
		mesh.size = Vector2(length, tip * 1.3 * float(layer.sq))
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.position = Vector3(0, 0, float(layer.z))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("length_m", length)
		mat.set_shader_parameter("half_h", tip * 0.65 * float(layer.sq))
		mat.set_shader_parameter("mouth_w", float(cfg.get("mouth", 0.2)))
		mat.set_shader_parameter("tip_w", tip)
		mat.set_shader_parameter("lobes", int(cfg.get("lobes", 11)))
		mat.set_shader_parameter("dim", float(layer.dim))
		mat.set_shader_parameter("seed", randf() * TAU)
		var cols: Array = cfg.get("colors", [])
		for i in mini(cols.size(), 4):
			mat.set_shader_parameter(["c_mouth", "c_hot", "c_mid", "c_tip"][i], _tint(cols[i]))
		mat.set_shader_parameter("front", 0.0)
		mat.set_shader_parameter("alpha_mul", 0.0)
		mi.material_override = mat
		b.add_child(mi)
		b._jets.append({"mat": mat, "a": float(layer.a)})
	var d := dir.normalized()
	var pos := at + d * length * 0.5
	b._xf = Transform3D(_basis(d, Vector3.AXIS_X, pos, cam_pos), pos)
	return b


func _sprite(part: Dictionary, n: int, tint: Color, add: bool) -> Sprite3D:
	var spr := Sprite3D.new()
	spr.texture = part.tex
	spr.hframes = maxi(1, int(part.tex.get_width() / int(part.fw)))
	spr.pixel_size = FX_PIXEL_M
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	spr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if add else BaseMaterial3D.BLEND_MODE_MIX
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(tint, 0.0)
	mat.albedo_texture = part.tex
	spr.material_override = mat
	add_child(spr)
	_parts.append({"spr": spr, "n": n, "mat": mat, "a": tint.a, "base_y": 1.0})
	return spr


func _quad(
	part: Dictionary, n: int, fps: float, off: Vector3, sc: Vector3, tint: Color, add: bool
) -> void:
	var spr := _sprite(part, n, tint, add)
	spr.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	(spr.material_override as StandardMaterial3D).billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	spr.scale = sc
	spr.position = off
	set_meta("fps", fps)


## at = posição global da origem do raio; as peças ficam relativas a este nó (que deve ficar em `at`).
func _aim(
	part: Dictionary,
	n: int,
	fps: float,
	at: Vector3,
	off: Vector3,
	axis: int,
	dir: Vector3,
	cam: Vector3,
	sc: Vector3,
	tint: Color,
	add: bool
) -> void:
	var spr := _sprite(part, n, tint, add)
	spr.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	var pos := at + off
	spr.transform = Transform3D(_basis(dir, axis, pos, cam).scaled_local(sc), off)
	_parts[-1].base_y = sc.y
	set_meta("fps", fps)


func _ready() -> void:
	set_process(auto)
	tick(0.0)


func _process(delta: float) -> void:
	if not tick(delta):
		queue_free()


func tick(dt: float) -> bool:
	age += dt
	if age >= life:
		return false
	var a := (
		clampf(age / maxf(fade, 0.001), 0.0, 1.0)
		* clampf((life - age) / maxf(fade, 0.001), 0.0, 1.0)
	)
	var fps := float(get_meta("fps", 15.0))
	for p in _parts:
		var spr: Sprite3D = p.spr
		var n: int = p.n
		spr.frame = int(age * fps) % maxi(1, mini(n, spr.hframes))
		var m: StandardMaterial3D = p.mat
		m.albedo_color.a = a * float(p.a)
	for j in _jets:
		var m2: ShaderMaterial = j.mat
		var front := 1.0 - pow(1.0 - clampf(age / travel, 0.0, 1.0), 3.0)
		m2.set_shader_parameter("front", front)
		m2.set_shader_parameter("alpha_mul", a * float(j.a))
	return true

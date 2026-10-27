class_name Fx3D
extends RefCounted
## Peças dos efeitos 3D dos golpes (gfx/fx3d): materiais, malhas e formas em cache.
## Os nós (Fx3DParticles, Fx3DMesh, Fx3DRibbon, Fx3DLight) avançam só em tick(dt) -> bool.

enum Shape { GLOW, SPARK, STAR, RING, SMOKE, TEX, EMBER, BUBBLE }
enum Mode { RIBBON, RING, SHELL, BEAM, CRACK }

const ADD := preload("res://gfx/fx3d/shaders/fx_particle_add.gdshader")
const MIX := preload("res://gfx/fx3d/shaders/fx_particle_mix.gdshader")
const MESH := preload("res://gfx/fx3d/shaders/fx_mesh.gdshader")

static var _pmats := {}
static var _mmats := {}
static var _meshes := {}


## Material das partículas: forma, aditivo ou misturado, borrão (s), textura (ProcFx.tex).
static func particle_mat(
	shape: int, add := true, stretch := 0.0, tex_name := "", boost := 2.0
) -> ShaderMaterial:
	var key := "%d|%s|%.3f|%s|%.2f" % [shape, add, stretch, tex_name, boost]
	if _pmats.has(key):
		return _pmats[key]
	var m := ShaderMaterial.new()
	m.shader = ADD if add else MIX
	m.set_shader_parameter("shape", shape)
	m.set_shader_parameter("stretch", stretch)
	m.set_shader_parameter("boost", boost)
	if tex_name != "":
		var t: Texture2D = ProcFx.tex(tex_name)
		if t:
			m.set_shader_parameter("tex", t)
	_pmats[key] = m
	return m


static func mesh_mat(mode: int, boost := 2.0, noise_k := 0.0, soft := 1.0) -> ShaderMaterial:
	var key := "%d|%.2f|%.2f|%.2f" % [mode, boost, noise_k, soft]
	if _mmats.has(key):
		return _mmats[key]
	var m := ShaderMaterial.new()
	m.shader = MESH
	m.set_shader_parameter("mode", mode)
	m.set_shader_parameter("boost", boost)
	m.set_shader_parameter("noise_k", noise_k)
	m.set_shader_parameter("soft", soft)
	_mmats[key] = m
	return m


static func quad() -> QuadMesh:
	if not _meshes.has("quad"):
		var q := QuadMesh.new()
		q.size = Vector2.ONE
		_meshes["quad"] = q
	return _meshes["quad"]


## Anel deitado (plano XZ) com raio externo 1 e interno `inner`; uv.y vai de dentro (0) para fora (1).
static func annulus(inner := 0.7, segs := 48) -> ArrayMesh:
	var key := "ann%.2f_%d" % [inner, segs]
	if _meshes.has(key):
		return _meshes[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segs:
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		var u0 := float(i) / segs
		var u1 := float(i + 1) / segs
		var p := [
			Vector3(cos(a0) * inner, 0, sin(a0) * inner),
			Vector3(cos(a0), 0, sin(a0)),
			Vector3(cos(a1), 0, sin(a1)),
			Vector3(cos(a1) * inner, 0, sin(a1) * inner)
		]
		var uv := [Vector2(u0, 0), Vector2(u0, 1), Vector2(u1, 1), Vector2(u1, 0)]
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_normal(Vector3.UP)
			st.set_uv(uv[k])
			st.add_vertex(p[k])
	var m := st.commit()
	_meshes[key] = m
	return m


static func sphere() -> SphereMesh:
	if not _meshes.has("sphere"):
		var s := SphereMesh.new()
		s.radius = 1.0
		s.height = 2.0
		s.radial_segments = 24
		s.rings = 12
		_meshes["sphere"] = s
	return _meshes["sphere"]


## Cilindro de altura 1 no eixo Y (base em y = 0), raio 1; uv.y ao longo.
static func tube(cap_top := false) -> CylinderMesh:
	var key := "tube%s" % cap_top
	if not _meshes.has(key):
		var c := CylinderMesh.new()
		c.top_radius = 1.0
		c.bottom_radius = 1.0
		c.height = 1.0
		c.radial_segments = 20
		c.rings = 1
		c.cap_top = cap_top
		c.cap_bottom = false
		_meshes[key] = c
	return _meshes[key]


## Cone aberto (redemoinho, tornado): raio 1 em cima, `bottom` embaixo, altura 1 (base em y = 0).
static func funnel(bottom := 0.25) -> CylinderMesh:
	var key := "fun%.2f" % bottom
	if not _meshes.has(key):
		var c := CylinderMesh.new()
		c.top_radius = 1.0
		c.bottom_radius = bottom
		c.height = 1.0
		c.radial_segments = 24
		c.rings = 4
		c.cap_top = false
		c.cap_bottom = false
		_meshes[key] = c
	return _meshes[key]


## Pedra/cristal de verdade (sombreada): caixa, prisma ou cristal.
static func solid(kind: String) -> Mesh:
	if _meshes.has("solid_" + kind):
		return _meshes["solid_" + kind]
	var m: Mesh
	match kind:
		"crystal":
			var p := PrismMesh.new()
			p.size = Vector3(0.5, 1.0, 0.5)
			m = p
		"shard":
			var p2 := PrismMesh.new()
			p2.size = Vector3(0.25, 1.0, 0.12)
			m = p2
		"leaf":
			var q := QuadMesh.new()
			q.size = Vector2(0.6, 1.0)
			m = q
		_:
			var b := BoxMesh.new()
			b.size = Vector3(1.0, 0.8, 0.9)
			m = b
	_meshes["solid_" + kind] = m
	return m


## Base que vira o eixo Y para `dir` (feixe, tubo, faísca alongada).
static func basis_y(dir: Vector3) -> Basis:
	var y := dir.normalized()
	if y.length() < 0.01:
		return Basis()
	var ref := Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT
	var x := ref.cross(y).normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)


static func ease_out(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return 1.0 - (1.0 - t) * (1.0 - t)


## Envelope 0..1 com subida rápida e queda no fim (fade_in e fade_out são frações da vida).
static func env(t: float, fade_in: float, fade_out: float) -> float:
	var a := 1.0
	if fade_in > 0.0 and t < fade_in:
		a = t / fade_in
	if fade_out > 0.0 and t > 1.0 - fade_out:
		a = minf(a, (1.0 - t) / fade_out)
	return clampf(a, 0.0, 1.0)

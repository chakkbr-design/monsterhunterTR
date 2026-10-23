class_name TerrainSteps
extends RefCounted


const TEXEL:= 0.05
const STEP_PX:= 7.0
const UV_W:= 32.0

const RISER_V:= Vector2(3.0 / UV_W, 0.0)
const TREAD_V:= Vector2(7.0 / UV_W, 3.0 / UV_W)

static var _mat: StandardMaterial3D

static func material() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.albedo_texture = WorldFx.tex("models/hgss/common/slope.png")
		_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_mat.roughness = 0.9
		_mat.metallic_specular = 0.2
	return _mat

static func count(rise: float, run: float) -> int:
	return maxi(1, int(round(sqrt(rise * rise + run * run) / (STEP_PX * TEXEL))))

static func height_at(rise: float, run: float, base: float, along: float) -> float:
	var n:= count(rise, run)
	var i:= clampi(int(along / (run / float(n))), 0, n)
	return base + rise * (1.0 - float(i) / float(n))

static func build(top_a: Vector3, top_b: Vector3, foot_a: Vector3, foot_b: Vector3) -> ArrayMesh:
	var rise:= top_a.y - foot_a.y
	var run:= Vector2(foot_a.x - top_a.x, foot_a.z - top_a.z).length()
	var n:= count(rise, run)
	var u:= top_a.distance_to(top_b) / (UV_W * TEXEL)
	var out:= Vector3(foot_a.x - top_a.x, 0.0, foot_a.z - top_a.z).normalized()
	var st:= SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n:
		var a0:= top_a.lerp(foot_a, float(i) / n)
		var b0:= top_b.lerp(foot_b, float(i) / n)
		var a1:= top_a.lerp(foot_a, float(i + 1) / n)
		var b1:= top_b.lerp(foot_b, float(i + 1) / n)
		var at:= Vector3(a1.x, a0.y, a1.z)
		var bt:= Vector3(b1.x, b0.y, b1.z)
		_quad(st, Vector3.UP,[[a0, Vector2(0.0, TREAD_V.y)],[at, Vector2(0.0, TREAD_V.x)],
				[bt, Vector2(u, TREAD_V.x)],[b0, Vector2(u, TREAD_V.y)]])
		_quad(st, out,[[at, Vector2(0.0, RISER_V.y)],[a1, Vector2(0.0, RISER_V.x)],
				[b1, Vector2(u, RISER_V.x)],[bt, Vector2(u, RISER_V.y)]])
	return st.commit()

static func _quad(st: SurfaceTool, n: Vector3, vs: Array) -> void:
	if (vs[1][0] - vs[0][0]).cross(vs[2][0] - vs[0][0]).dot(n) > 0.0:
		vs =[vs[0], vs[3], vs[2], vs[1]]
	for i in[0, 1, 2, 0, 2, 3]:
		st.set_normal(n)
		st.set_uv(vs[i][1])
		st.add_vertex(vs[i][0])

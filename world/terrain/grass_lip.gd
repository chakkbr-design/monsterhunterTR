class_name TerrainGrassLip
extends RefCounted




static var _mat: ShaderMaterial

static func material() -> ShaderMaterial:
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = WorldFx.shader("grass")
		_mat.set_shader_parameter("albedo_tex", WorldFx.tex("textures/grass_blade.png"))
		_mat.set_shader_parameter("sway", 0.05)
	return _mat

static func build(points: PackedVector2Array, normals: PackedVector2Array, top_at: Callable, seed: int, per_m:= 10.0) -> MultiMeshInstance3D:
	var rng:= RandomNumberGenerator.new()
	rng.seed = seed
	var xs: Array =[]
	for i in points.size() - 1:
		var a:= points[i]
		var b:= points[i + 1]
		var seg:= a.distance_to(b)
		var count:= int(round(seg * per_m))
		for j in count:
			var t:= (j + rng.randf()) / maxf(count, 1)
			var p:= a.lerp(b, t)
			var n:= normals[i].lerp(normals[i + 1], t).normalized()
			var out:= Vector3(n.x, 0.0, n.y)
			var tangent:= Vector3(-n.y, 0.0, n.x)
			var pos:= Vector3(p.x, float(top_at.call(p.x, p.y)), p.y) + out * rng.randf_range(0.0, 0.12)

			var basis:= Basis.looking_at(-out, Vector3.UP)
			var lean:= deg_to_rad(rng.randf_range(30.0, 60.0))
			basis = Basis(tangent, lean) * basis
			if basis.y.dot(out) < 0.0:
				basis = Basis(tangent, -2.0 * lean) * basis
			var s:= rng.randf_range(0.8, 1.3)
			xs.append(Transform3D(basis.scaled(Vector3(s, s, s)), pos))
	var q:= QuadMesh.new()
	q.size = Vector2(0.32, 0.42)
	q.center_offset = Vector3(0, 0.21, 0)
	var mm:= MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = q
	mm.instance_count = xs.size()
	for i in xs.size():
		mm.set_instance_transform(i, xs[i])
		var v:= rng.randf_range(0.85, 1.1)
		mm.set_instance_color(i, Color(v, v, v))
	var mmi:= MultiMeshInstance3D.new()
	mmi.name = "GrassLip"
	mmi.multimesh = mm
	mmi.material_override = material()
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	mmi.set_meta("transforms", xs)
	return mmi

class_name TerrainBoulders
extends RefCounted



const VARIANTS:= 4
const TOP:= 1.18

static var _meshes: Array =[]
static var _mat: ShaderMaterial

static func material() -> ShaderMaterial:
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = WorldFx.shader("boulder")
	return _mat

static func variants() -> Array:
	if _meshes.is_empty():
		for v in VARIANTS:
			_meshes.append(_make(v))
	return _meshes

static func _make(v: int) -> ArrayMesh:
	var sphere:= SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 14
	sphere.rings = 8
	var arr:= sphere.get_mesh_arrays()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var noise:= FastNoiseLite.new()
	noise.seed = 1000 + v
	noise.frequency = 1.1
	for i in verts.size():
		var p:= verts[i]
		p *= 1.0 + noise.get_noise_3dv(p) * 0.28
		p.y *= 0.72
		p.y = maxf(p.y, -0.45)
		verts[i] = p
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = null
	arr[Mesh.ARRAY_TANGENT] = null
	var st:= SurfaceTool.new()
	st.create_from_arrays(arr)
	st.deindex()
	st.generate_normals()
	return st.commit()

static func row(parent: Node3D, length: float, drop: float, seed: int) -> void:
	var rng:= RandomNumberGenerator.new()
	rng.seed = seed
	var meshes:= variants()
	var x:= -length / 2.0
	while x < length / 2.0:
		var s:= drop / TOP * rng.randf_range(0.85, 1.05)
		_add(parent, meshes[rng.randi() % VARIANTS], Vector3(x + s * 0.5, -drop + 0.45 * s, rng.randf_range(0.1, 0.35)), s, rng)
		if rng.randf() < 0.3:
			var s2:= s * 0.45
			_add(parent, meshes[rng.randi() % VARIANTS], Vector3(x + s * 0.5 + rng.randf_range(-0.3, 0.3), -drop + 0.45 * s2, 0.35 + s * 0.9), s2, rng)
		x += s * rng.randf_range(1.1, 1.5)

static func _add(parent: Node3D, mesh: ArrayMesh, pos: Vector3, s: float, rng: RandomNumberGenerator) -> void:
	var mi:= MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material()
	mi.transform = Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s * rng.randf_range(0.9, 1.25), s, s * rng.randf_range(0.9, 1.25))), pos)
	parent.add_child(mi)

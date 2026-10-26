class_name VoxelMesher
extends RefCounted
## Meshes a VoxelGrid (docs/VOXEL.md).
## - greedy(): merges every visible face that shares a plane, whatever its colour (voxel.gdshader
##   reads colour, material, AO and edges from the grid's 3D texture), one mesh per part. A face
##   is hidden when the neighbour is solid and belongs to the same part or to the static part 0, so
##   a part can be hidden (roof) or moved (sway) without holes in what stays.
## - colored(): small models (decor, the 1/16 m "detail" scale) with one quad per voxel face, the
##   colour and 0fps-style vertex AO baked into COLOR (voxel_detail.gdshader).
## Vertices are in the grid's model space (voxel index * VS), so a MeshInstance3D at the origin
## lines up with the world lattice. Front faces are clockwise (Godot), so for corners p, p+a, p+a+b,
## p+b the edge pair satisfies a x b == -normal.

const AO_CURVE := [0.42, 0.62, 0.82, 1.0]


class _Buf:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()


## Region = local cell box [lo, hi) (defaults to the whole grid). Returns {part_id: ArrayMesh}.
static func greedy(
	g: VoxelGrid, lo := Vector3i.ZERO, hi := Vector3i(-1, -1, -1), vs := VoxelGrid.VS
) -> Dictionary:
	if hi.x < 0:
		hi = g.size
	lo = Vector3i(maxi(lo.x, 0), maxi(lo.y, 0), maxi(lo.z, 0))
	hi = Vector3i(mini(hi.x, g.size.x), mini(hi.y, g.size.y), mini(hi.z, g.size.z))
	var tags := _tags(g)
	var out := {}  # part -> _Buf
	var dims := [g.size.x, g.size.y, g.size.z]
	var stride := [1, g.size.x * g.size.z, g.size.x]  # x, y, z
	var los := [lo.x, lo.y, lo.z]
	var his := [hi.x, hi.y, hi.z]
	for d in 3:
		var ua: int = (d + 1) % 3
		var va: int = (d + 2) % 3
		var sd: int = stride[d]
		var su: int = stride[ua]
		var sv: int = stride[va]
		var u0: int = los[ua]
		var u1: int = his[ua]
		var v0: int = los[va]
		var v1: int = his[va]
		var nu := u1 - u0
		var nv := v1 - v0
		if nu <= 0 or nv <= 0:
			continue
		var dim_d: int = dims[d]
		var mask := PackedInt32Array()
		mask.resize(nu * nv)
		for s in [-1, 1]:
			var nrm := Vector3.ZERO
			nrm[d] = s
			var eu := Vector3.ZERO
			eu[ua] = 1.0
			var ev := Vector3.ZERO
			ev[va] = 1.0
			var flip := eu.cross(ev).dot(nrm) > 0.0
			for k in range(los[d], his[d]):
				var nk: int = k + s
				var inside: bool = nk >= 0 and nk < dim_d
				var off: int = s * sd
				var any := false
				var mi := 0
				for v in range(v0, v1):
					var base: int = k * sd + v * sv + u0 * su
					for u in nu:
						var i: int = base + u * su
						var t: int = tags[i]
						var m := 0
						if t != 0:
							var n: int = tags[i + off] if inside else 0
							if n == 0 or (n != t and n != 1):
								m = t
								any = true
						mask[mi] = m
						mi += 1
				if not any:
					continue
				var plane := float(k + (1 if s > 0 else 0))
				# Greedy merge of equal tags.
				for v in nv:
					var u := 0
					while u < nu:
						var t2: int = mask[v * nu + u]
						if t2 == 0:
							u += 1
							continue
						var w := 1
						while u + w < nu and mask[v * nu + u + w] == t2:
							w += 1
						var h := 1
						var grow := true
						while v + h < nv and grow:
							var row: int = (v + h) * nu + u
							for q in w:
								if mask[row + q] != t2:
									grow = false
									break
							if grow:
								h += 1
						for hh in h:
							var row2: int = (v + hh) * nu + u
							for q in w:
								mask[row2 + q] = 0
						var p := Vector3.ZERO
						p[d] = plane
						p[ua] = u0 + u
						p[va] = v0 + v
						var a := eu * w
						var b := ev * h
						_quad(out, t2 - 1, (p + Vector3(g.origin)) * vs, a * vs, b * vs, nrm, flip)
						u += w
	var meshes := {}
	for prt in out:
		var buf: _Buf = out[prt]
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = buf.verts
		arr[Mesh.ARRAY_NORMAL] = buf.norms
		arr[Mesh.ARRAY_INDEX] = buf.idx
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		meshes[prt] = m
	return meshes


## 0 = air, otherwise part + 1.
static func _tags(g: VoxelGrid) -> PackedByteArray:
	var n := g.part.size()
	var t := PackedByteArray()
	t.resize(n)
	var dat := g.data
	var prt := g.part
	for i in n:
		if dat[i * 4 + 3] != 0:
			t[i] = mini(prt[i] + 1, 255)
	return t


static func _quad(
	out: Dictionary, prt: int, p: Vector3, a: Vector3, b: Vector3, n: Vector3, flip: bool
) -> void:
	var buf: _Buf = out.get(prt)
	if buf == null:
		buf = _Buf.new()
		out[prt] = buf
	var base := buf.verts.size()
	if flip:
		buf.verts.append_array([p, p + b, p + a + b, p + a])
	else:
		buf.verts.append_array([p, p + a, p + a + b, p + b])
	buf.norms.append_array([n, n, n, n])
	buf.idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])


## Small vertex-coloured model: one quad per visible voxel face, AO baked into the colour.
## `scale` is the voxel edge in metres (VoxelMat.DETAIL = 1/16 m for decor); `pivot` (in voxels) is
## subtracted so a model can sit on its base centre. COLOR.a carries the AO factor.
static func colored(g: VoxelGrid, scale := 0.0625, pivot := Vector3.ZERO) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for ly in g.size.y:
		for lz in g.size.z:
			for lx in g.size.x:
				var v := g.origin + Vector3i(lx, ly, lz)
				if not g.solid(v):
					continue
				var c := g.color_at(v)
				for d in 3:
					for s in [-1, 1]:
						var nv := Vector3i.ZERO
						nv[d] = s
						var q := v + nv
						if g.solid(q):
							continue
						var ua: int = (d + 1) % 3
						var va: int = (d + 2) % 3
						var eu := Vector3i.ZERO
						eu[ua] = 1
						var ev := Vector3i.ZERO
						ev[va] = 1
						var nrm := Vector3(nv)
						var flip := Vector3(eu).cross(Vector3(ev)).dot(nrm) > 0.0
						var p := Vector3(v)
						if s > 0:
							p[d] += 1.0
						var corners := [
							Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)
						]
						if flip:
							corners = [
								Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 0)
							]
						var base := verts.size()
						var aos := []
						for cn in corners:
							var du: int = cn.x * 2 - 1
							var dv: int = cn.y * 2 - 1
							var s1 := 1 if g.solid(q + eu * du) else 0
							var s2 := 1 if g.solid(q + ev * dv) else 0
							var cc := 1 if g.solid(q + eu * du + ev * dv) else 0
							var ao: float = AO_CURVE[
								0 if (s1 == 1 and s2 == 1) else 3 - (s1 + s2 + cc)
							]
							aos.append(ao)
							verts.append(
								(p + Vector3(eu) * cn.x + Vector3(ev) * cn.y - pivot) * scale
							)
							norms.append(nrm)
							cols.append(Color(c.r, c.g, c.b, ao))
						# Flip the split diagonal toward the brighter pair (removes AO anisotropy).
						if aos[0] + aos[2] < aos[1] + aos[3]:
							idx.append_array(
								[base + 1, base + 2, base + 3, base + 1, base + 3, base]
							)
						else:
							idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
	var m := ArrayMesh.new()
	if verts.is_empty():
		return m
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m

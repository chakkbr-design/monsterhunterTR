class_name VoxelGrid
extends RefCounted
## Dense voxel volume on the shared 0.25 m lattice (docs/VOXEL.md). Voxel (i, j, k) covers
## [i, i+1) x [j, j+1) x [k, k+1) * VS in the grid's model space, so a 1 m tile centred on integer
## world coordinates (tx, tz) is voxels 4*tx-2 .. 4*tx+1 and ground whose top is y = 0 is j <= -1.
## Each cell is 4 bytes: sRGB colour (r, g, b) + material id (VoxelMat, 0 = air). `part` tags a
## cell for the mesher: 0 = static scenery, any other id becomes its own mesh (a house roof that
## can be hidden, a tree crown that sways). Colour lives in a 3D texture sampled per fragment, so
## the mesh only follows solidity and stays small (VoxelMesher.greedy).

const VS := 0.25
const PER_M := 4

var origin := Vector3i.ZERO  ## voxel coordinates of local cell (0, 0, 0)
var size := Vector3i.ONE
var data := PackedByteArray()  ## 4 bytes per cell, index 4 * (x + sx * (z + sz * y))
var part := PackedByteArray()  ## 1 byte per cell
var _sx := 1
var _sxz := 1


func _init(o := Vector3i.ZERO, s := Vector3i.ONE) -> void:
	origin = o
	size = Vector3i(maxi(s.x, 1), maxi(s.y, 1), maxi(s.z, 1))
	_sx = size.x
	_sxz = size.x * size.z
	data.resize(_sxz * size.y * 4)
	part.resize(_sxz * size.y)


## Grid covering a metre box [lo, hi) (rounded outwards to whole voxels).
static func from_box(lo: Vector3, hi: Vector3) -> VoxelGrid:
	var a := vox3(lo)
	var b := Vector3i(
		ceili(hi.x * PER_M - 1e-4), ceili(hi.y * PER_M - 1e-4), ceili(hi.z * PER_M - 1e-4)
	)
	return VoxelGrid.new(a, b - a)


## Voxel index containing metre coordinate m.
static func vox(m: float) -> int:
	return floori(m * PER_M + 1e-4)


static func vox3(p: Vector3) -> Vector3i:
	return Vector3i(vox(p.x), vox(p.y), vox(p.z))


## Metre position of a voxel's centre.
static func centre(v: Vector3i) -> Vector3:
	return (Vector3(v) + Vector3(0.5, 0.5, 0.5)) * VS


## Cheap deterministic hash in [0, 1) for per-voxel variation (never use a battle RNG for looks).
static func hash01(x: int, y: int, z: int, salt := 0) -> float:
	var h := (x * 73856093) ^ (y * 19349663) ^ (z * 83492791) ^ (salt * 2654435761)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xFFFFFF) / 16777216.0


func has(v: Vector3i) -> bool:
	var l := v - origin
	return l.x >= 0 and l.y >= 0 and l.z >= 0 and l.x < size.x and l.y < size.y and l.z < size.z


func index(v: Vector3i) -> int:
	var l := v - origin
	return l.x + _sx * l.z + _sxz * l.y


func mat_at(v: Vector3i) -> int:
	return data[index(v) * 4 + 3] if has(v) else 0


func solid(v: Vector3i) -> bool:
	return mat_at(v) != 0


func color_at(v: Vector3i) -> Color:
	if not has(v):
		return Color(0, 0, 0, 0)
	var i := index(v) * 4
	return Color8(data[i], data[i + 1], data[i + 2])


func part_at(v: Vector3i) -> int:
	return part[index(v)] if has(v) else 0


## Writes one voxel (world voxel coordinates); out-of-grid writes are ignored. mat 0 clears it.
func put(v: Vector3i, c: Color, mat: int, prt := 0) -> void:
	var l := v - origin
	if l.x < 0 or l.y < 0 or l.z < 0 or l.x >= size.x or l.y >= size.y or l.z >= size.z:
		return
	var n := l.x + _sx * l.z + _sxz * l.y
	var i := n * 4
	if mat == 0:
		data[i] = 0
		data[i + 1] = 0
		data[i + 2] = 0
		data[i + 3] = 0
		part[n] = 0
		return
	data[i] = clampi(int(c.r * 255.0 + 0.5), 0, 255)
	data[i + 1] = clampi(int(c.g * 255.0 + 0.5), 0, 255)
	data[i + 2] = clampi(int(c.b * 255.0 + 0.5), 0, 255)
	data[i + 3] = mat
	part[n] = prt


func clear(v: Vector3i) -> void:
	put(v, Color.BLACK, 0)


## Fills the inclusive voxel box a..b. `paint` (optional) is called as paint.call(v) -> Color for
## per-voxel colour; otherwise c is used everywhere.
func fill(a: Vector3i, b: Vector3i, c: Color, mat: int, prt := 0, paint := Callable()) -> void:
	var lo := Vector3i(mini(a.x, b.x), mini(a.y, b.y), mini(a.z, b.z))
	var hi := Vector3i(maxi(a.x, b.x), maxi(a.y, b.y), maxi(a.z, b.z))
	lo = Vector3i(maxi(lo.x, origin.x), maxi(lo.y, origin.y), maxi(lo.z, origin.z))
	hi = Vector3i(
		mini(hi.x, origin.x + size.x - 1),
		mini(hi.y, origin.y + size.y - 1),
		mini(hi.z, origin.z + size.z - 1)
	)
	var use_paint := paint.is_valid()
	for y in range(lo.y, hi.y + 1):
		for z in range(lo.z, hi.z + 1):
			for x in range(lo.x, hi.x + 1):
				var v := Vector3i(x, y, z)
				put(v, paint.call(v) if use_paint else c, mat, prt)


## Fills the metre box [lo, hi) (voxels whose centres fall inside).
func fill_m(lo: Vector3, hi: Vector3, c: Color, mat: int, prt := 0, paint := Callable()) -> void:
	var a := Vector3i(roundi(lo.x * PER_M), roundi(lo.y * PER_M), roundi(lo.z * PER_M))
	var b := Vector3i(roundi(hi.x * PER_M) - 1, roundi(hi.y * PER_M) - 1, roundi(hi.z * PER_M) - 1)
	if b.x < a.x or b.y < a.y or b.z < a.z:
		return
	fill(a, b, c, mat, prt, paint)


## Ellipsoid centred at c (voxel space, may be fractional) with radii r (in voxels).
func ellipsoid(
	c: Vector3, r: Vector3, col: Color, mat: int, prt := 0, paint := Callable(), only_air := false
) -> void:
	var use_paint := paint.is_valid()
	for y in range(floori(c.y - r.y), ceili(c.y + r.y) + 1):
		for z in range(floori(c.z - r.z), ceili(c.z + r.z) + 1):
			for x in range(floori(c.x - r.x), ceili(c.x + r.x) + 1):
				var d := Vector3(
					(x + 0.5 - c.x) / r.x, (y + 0.5 - c.y) / r.y, (z + 0.5 - c.z) / r.z
				)
				if d.length_squared() > 1.0:
					continue
				var v := Vector3i(x, y, z)
				if only_air and solid(v):
					continue
				put(v, paint.call(v) if use_paint else col, mat, prt)


## Vertical cylinder: centre (voxel x/z, fractional ok), radius in voxels, inclusive y range.
func cylinder(
	cx: float,
	cz: float,
	r: float,
	y0: int,
	y1: int,
	col: Color,
	mat: int,
	prt := 0,
	paint := Callable()
) -> void:
	var use_paint := paint.is_valid()
	for y in range(y0, y1 + 1):
		for z in range(floori(cz - r), ceili(cz + r) + 1):
			for x in range(floori(cx - r), ceili(cx + r) + 1):
				var dx := x + 0.5 - cx
				var dz := z + 0.5 - cz
				if dx * dx + dz * dz > r * r:
					continue
				var v := Vector3i(x, y, z)
				put(v, paint.call(v) if use_paint else col, mat, prt)


## Highest solid voxel y in a column, or `none` when the column is empty.
func top_y(x: int, z: int, none := -1048576) -> int:
	if x < origin.x or z < origin.z or x >= origin.x + size.x or z >= origin.z + size.z:
		return none
	var base := (x - origin.x) + _sx * (z - origin.z)
	for ly in range(size.y - 1, -1, -1):
		if data[(base + _sxz * ly) * 4 + 3] != 0:
			return origin.y + ly
	return none


## Copies another grid in (solid cells only), offset in voxels.
func blit(g: VoxelGrid, offset := Vector3i.ZERO, prt := -1) -> void:
	for ly in g.size.y:
		for lz in g.size.z:
			for lx in g.size.x:
				var n := lx + g._sx * lz + g._sxz * ly
				var m := g.data[n * 4 + 3]
				if m == 0:
					continue
				var v := g.origin + Vector3i(lx, ly, lz) + offset
				var i := n * 4
				put(
					v,
					Color8(g.data[i], g.data[i + 1], g.data[i + 2]),
					m,
					g.part[n] if prt < 0 else prt
				)


## RGBA8 3D texture of the volume (texture x = voxel x, y = voxel z, layer = voxel y), sampled by
## voxel.gdshader with texelFetch.
func texture() -> ImageTexture3D:
	var layers: Array[Image] = []
	var n := _sxz * 4
	for y in size.y:
		layers.append(
			Image.create_from_data(
				size.x, size.z, false, Image.FORMAT_RGBA8, data.slice(y * n, (y + 1) * n)
			)
		)
	var t := ImageTexture3D.new()
	t.create(Image.FORMAT_RGBA8, size.x, size.z, size.y, false, layers)
	return t


## Column tops for weather exposure: R8 image (x, z) holding 1 + the local y of the highest solid
## voxel (0 = empty column). A face whose air cell sits at or above it sees the sky.
func tops_image() -> Image:
	var b := PackedByteArray()
	b.resize(_sxz)
	for z in size.z:
		for x in size.x:
			var base := x + _sx * z
			var t := 0
			for ly in range(size.y - 1, -1, -1):
				if data[(base + _sxz * ly) * 4 + 3] != 0:
					t = ly + 1
					break
			b[base] = mini(t, 255)
	return Image.create_from_data(size.x, size.z, false, Image.FORMAT_R8, b)


func tops_texture() -> ImageTexture:
	return ImageTexture.create_from_image(tops_image())


## Number of solid cells (tests / stats).
func count_solid() -> int:
	var n := 0
	for i in range(3, data.size(), 4):
		if data[i] != 0:
			n += 1
	return n

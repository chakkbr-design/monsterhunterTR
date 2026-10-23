class_name TerrainCliff
extends RefCounted

const ROW := 0.3
const AMP := 0.18
const LIP_IN := 0.1
const FLARE := 0.35
const SINK := 0.15

static var _mat: ShaderMaterial


static func material() -> ShaderMaterial:
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = WorldFx.shader("cliff_earth")
	return _mat


static func outline(rect: Rect2, cuts: Dictionary, radius := 0.8, step := 0.25) -> Array:
	var x0 := rect.position.x
	var z0 := rect.position.y
	var x1 := rect.end.x
	var z1 := rect.end.y
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.25)
	var pts: Array = []
	var cn: Array = cuts.get("n", [])
	var ce: Array = cuts.get("e", [])
	var cs: Array = cuts.get("s", [])
	var cw: Array = cuts.get("w", [])

	_side(pts, Vector2(x0 + r, z0), Vector2(x1 - r, z0), Vector2(0, -1), cn, true, step)
	_arc(
		pts,
		Vector2(x1 - r, z0 + r),
		r,
		-PI / 2.0,
		0.0,
		not (_hits(cn, x1 - r, x1) or _hits(ce, z0, z0 + r))
	)
	_side(pts, Vector2(x1, z0 + r), Vector2(x1, z1 - r), Vector2(1, 0), ce, false, step)
	_arc(
		pts,
		Vector2(x1 - r, z1 - r),
		r,
		0.0,
		PI / 2.0,
		not (_hits(ce, z1 - r, z1) or _hits(cs, x1 - r, x1))
	)
	_side(pts, Vector2(x1 - r, z1), Vector2(x0 + r, z1), Vector2(0, 1), cs, true, step)
	_arc(
		pts,
		Vector2(x0 + r, z1 - r),
		r,
		PI / 2.0,
		PI,
		not (_hits(cs, x0, x0 + r) or _hits(cw, z1 - r, z1))
	)
	_side(pts, Vector2(x0, z1 - r), Vector2(x0, z0 + r), Vector2(-1, 0), cw, false, step)
	_arc(
		pts,
		Vector2(x0 + r, z0 + r),
		r,
		PI,
		PI * 1.5,
		not (_hits(cw, z0, z0 + r) or _hits(cn, x0, x0 + r))
	)

	var clean: Array = []
	for e in pts:
		if clean.is_empty() or not (clean[-1][0].is_equal_approx(e[0]) and clean[-1][2] == e[2]):
			clean.append(e)
	if clean.size() > 1 and clean[0][0].is_equal_approx(clean[-1][0]):
		clean.pop_back()
	var any_cut := false
	for e in clean:
		if not e[2]:
			any_cut = true
			break
	if not any_cut:
		return [_line(clean, true)]

	var start := 0
	while clean[start][2]:
		start += 1
	var lines: Array = []
	var run: Array = []
	for k in clean.size():
		var e = clean[(start + k) % clean.size()]
		if e[2]:
			run.append(e)
		else:
			if run.size() >= 2:
				lines.append(_line(run, false))
			run = []
	if run.size() >= 2:
		lines.append(_line(run, false))
	return lines


static func _line(run: Array, closed: bool) -> Dictionary:
	var p := PackedVector2Array()
	var n := PackedVector2Array()
	for e in run:
		p.append(e[0])
		n.append(e[1])
	return {"points": p, "normals": n, "closed": closed}


static func _hits(cuts: Array, a: float, b: float) -> bool:
	var lo := minf(a, b)
	var hi := maxf(a, b)
	for c in cuts:
		if float(c[0]) < hi - 0.001 and float(c[1]) > lo + 0.001:
			return true
	return false


static func _side(
	pts: Array, a: Vector2, b: Vector2, normal: Vector2, cuts: Array, horizontal: bool, step: float
) -> void:
	var ca := a.x if horizontal else a.y
	var cb := b.x if horizontal else b.y
	var ts: Array = [0.0, 1.0]
	for c in cuts:
		for v: float in [float(c[0]), float(c[1])]:
			var t := (v - ca) / (cb - ca) if not is_equal_approx(cb, ca) else -1.0
			if t > 0.0 and t < 1.0:
				ts.append(t)
	ts.sort()
	var length := a.distance_to(b)
	for k in ts.size() - 1:
		var t0: float = ts[k]
		var t1: float = ts[k + 1]
		if t1 - t0 < 0.00001:
			continue
		var mid := lerpf(ca, cb, (t0 + t1) * 0.5)
		var kept := not _hits(cuts, mid - 0.0005, mid + 0.0005)
		var n := maxi(int(ceil(length * (t1 - t0) / step)), 1)
		for i in n + 1:
			pts.append([a.lerp(b, lerpf(t0, t1, float(i) / n)), normal, kept])


static func _arc(pts: Array, c: Vector2, r: float, a0: float, a1: float, kept: bool) -> void:
	for i in 7:
		var a := lerpf(a0, a1, i / 6.0)
		var d := Vector2(cos(a), sin(a))
		pts.append([c + d * r, d, kept])


static func build(
	points: PackedVector2Array,
	normals: PackedVector2Array,
	closed: bool,
	top_at: Callable,
	base_at: Callable,
	seed: int
) -> ArrayMesh:
	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.frequency = 0.9
	var streak := FastNoiseLite.new()
	streak.seed = seed + 1
	streak.frequency = 1.6
	var n := points.size()
	var tops := PackedFloat32Array()
	var bases := PackedFloat32Array()
	var tallest := 0.0
	for i in n:
		var p := points[i]
		var t := float(top_at.call(p.x, p.y))
		var q := p + normals[i] * 0.6
		var b := float(base_at.call(q.x, q.y)) - SINK
		tops.append(t)
		bases.append(minf(b, t - 0.05))
		tallest = maxf(tallest, t - b)
	var rows := clampi(int(ceil(tallest / ROW)), 2, 40)
	var cols := n + (1 if closed else 0)

	var grid: Array = []
	var colors: Array = []
	var uvs: Array = []
	var along := 0.0
	for c in cols:
		var i := c % n
		var p := points[i]
		var nrm := normals[i]
		if c > 0:
			along += points[(c - 1) % n].distance_to(p)
		var col: Array = []
		var ccol: Array = []
		var ucol: Array = []
		for k in rows + 1:
			var t := float(k) / rows
			var y := lerpf(tops[i], bases[i], t)
			var disp := (
				noise.get_noise_3d(p.x, y * 0.6, p.y) * AMP
				+ streak.get_noise_3d(p.x * 2.0, y * 0.15, p.y * 2.0) * AMP * 0.5
			)
			if k == 0:
				disp = -LIP_IN
			elif k == 1:
				disp = maxf(disp, 0.0) + 0.06
			elif k == rows:
				disp = FLARE + disp * 0.3
			col.append(Vector3(p.x + nrm.x * disp, y, p.y + nrm.y * disp))
			ccol.append(Color(1.0 - t, 0.0, 0.0))
			ucol.append(Vector2(along, y))
		grid.append(col)
		colors.append(ccol)
		uvs.append(ucol)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for c in cols - 1:
		var i := c % n
		var j := (c + 1) % n
		var facing := Vector3(
			(normals[i].x + normals[j].x) * 0.5, 0.0, (normals[i].y + normals[j].y) * 0.5
		)
		for k in rows:
			var a := [grid[c][k], colors[c][k], uvs[c][k]]
			var b := [grid[c + 1][k], colors[c + 1][k], uvs[c + 1][k]]
			var d := [grid[c][k + 1], colors[c][k + 1], uvs[c][k + 1]]
			var e := [grid[c + 1][k + 1], colors[c + 1][k + 1], uvs[c + 1][k + 1]]
			_tri(st, a, b, d, facing)
			_tri(st, b, e, d, facing)
	st.generate_normals()
	var mesh := st.commit()
	return mesh


static func _tri(st: SurfaceTool, a: Array, b: Array, c: Array, facing: Vector3) -> void:
	if (c[0] - a[0]).cross(b[0] - a[0]).dot(facing) < 0.0:
		var t := b
		b = c
		c = t
	for v in [a, b, c]:
		st.set_color(v[1])
		st.set_uv(v[2])
		st.add_vertex(v[0])

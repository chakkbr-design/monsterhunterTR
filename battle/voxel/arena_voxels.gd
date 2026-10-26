class_name ArenaVoxels
extends RefCounted
## Voxel looks of the energy-mode training field (docs/VOXEL.md §7). The gameplay dictionaries
## of BattleTerrain, BattleProps, BattleBiomes, BattleGround, BattleGroundExtras and BattleField
## stay the truth; everything here only builds what they describe:
## - relief (hills, peaks), pond bowls with a WaterSurface, tall grass, biome solids (pillars,
##   snow mounds), the montanha cliff, lava cells, the rune circle, flat decals (mud, marks, webs,
##   vines), log bridges, pylons, rocks and snow heaps; props and field objects: ArenaPropsVox.
## - Each object is its own small VoxelGrid meshed with VoxelMesher.greedy and voxel.gdshader (one
##   material per part, so tint / flash / emission change per object). Part CTX (0) is context:
##   cells that sit in the 3D texture for AO and hidden faces (the floor under an object) but are
##   never meshed, so every visible voxel goes in BODY or TOP (VoxelGrid.put defaults to part 0).
## - Models whose shape only depends on a few numbers are cached (_models) and reused across
##   fights, turned by quarter turns picked from the position hash. Looks never use the battle RNG
##   and nothing here runs under fast_sim (the callers check).

const VS := VoxelGrid.VS
## Voxel edge of small props and decals (crates, Voltorb, bushes, rune...).
const FINE := 0.125
const DETAIL := VoxelMat.DETAIL
const CTX := 0
const BODY := 1
const TOP := 2  ## second part (tree crown, swaying / tinted on its own)
## Cached models before the cache is flushed.
const MAX_MODELS := 320
## Decal thickness (flat things on the floor).
const DECAL_H := 0.04
## Glow of hot lava cells (voxel.gdshader emit_always).
const LAVA_GLOW := 1.3
## Pond: terraces of the bowl below the floor (fraction of the base radius -> top of the bed).
const POND_STEPS := [[1.0, -0.25], [0.8, -0.5], [0.45, -0.75], [0.0, -1.0]]
## Water level by pond radius / base radius (sun 0.8, normal 1.0, rain 1.25): the water crosses a
## terrace top halfway between two steps, so its edge is the step nearest to the gameplay radius.
const POND_LEVELS := [[0.8, -0.62], [0.9, -0.5], [1.0, -0.36], [1.125, -0.25], [1.25, -0.08]]
## Seconds for a pond to freeze over (or melt) on the water shader.
const ICE_SECS := 0.35


class Model:
	extends RefCounted
	var grid: VoxelGrid
	var meshes := {}  ## part -> ArrayMesh (no CTX)
	var tex: Texture3D
	var tops: Texture2D
	var vs := VS


static var _models := {}
static var _detail := {}

# --- Core ---


## Meshes `g` (every part but CTX) with voxel edge `vs`.
static func model(g: VoxelGrid, vs := VS) -> Model:
	var m := Model.new()
	m.grid = g
	m.vs = vs
	var meshes := VoxelMesher.greedy(g, Vector3i.ZERO, Vector3i(-1, -1, -1), vs)
	meshes.erase(CTX)
	m.meshes = meshes
	m.tex = g.texture()
	m.tops = g.tops_texture()
	return m


## Model cached under `key`; `make` returns the VoxelGrid the first time.
static func cached(key: String, make: Callable, vs := VS) -> Model:
	if _models.has(key):
		return _models[key]
	if _models.size() >= MAX_MODELS:
		_models.clear()
	var m := model(make.call(), vs)
	_models[key] = m
	return m


## Node3D with one MeshInstance3D per part of `m`, each with its own material (meta "mats":
## {part: ShaderMaterial}). `params` = {part: {uniform: value}}.
static func instance(m: Model, name: String, params := {}, shadow := true) -> Node3D:
	var root := Node3D.new()
	root.name = name
	var mats := {}
	var parts: Array = m.meshes.keys()
	parts.sort()
	for prt in parts:
		var pp := {"voxel": m.vs}
		pp.merge(params.get(prt, {}), true)
		var mat := VoxelMat.material(m.grid, m.tex, m.tops, pp)
		var mi := MeshInstance3D.new()
		mi.name = "%s%d" % [name, prt]
		mi.mesh = m.meshes[prt]
		mi.material_override = mat
		if not shadow:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
		mats[prt] = mat
	root.set_meta("mats", mats)
	return root


## Material of part `prt` of a voxel node (null if none).
static func mat_of(node, prt := BODY) -> ShaderMaterial:
	if not is_instance_valid(node) or not node.has_meta("mats"):
		return null
	return node.get_meta("mats").get(prt)


## Sets a uniform on every part of a voxel node (or only `prt`).
static func set_param(node, uniform: String, value, prt := -1) -> void:
	if not is_instance_valid(node) or not node.has_meta("mats"):
		return
	var mats: Dictionary = node.get_meta("mats")
	for p in mats:
		if prt < 0 or p == prt:
			mats[p].set_shader_parameter(uniform, value)


## Material colour multiplier for a StandardMaterial3D (albedo) or a voxel ShaderMaterial (tint).
static func tint_mat(mat, c: Color) -> void:
	if mat is StandardMaterial3D:
		mat.albedo_color = c
	elif mat is ShaderMaterial:
		mat.set_shader_parameter("tint", c)


## Quarter turn (0..3) for the looks of something at `p`.
static func quarter(p: Vector3, salt := 0) -> int:
	return int(VoxelGrid.hash01(roundi(p.x * 4.0), salt, roundi(p.z * 4.0), 77) * 4.0) % 4


## Grid for a metre box [lo, hi) at voxel edge `vs`.
static func box(lo: Vector3, hi: Vector3, vs := VS) -> VoxelGrid:
	var a := Vector3i(floori(lo.x / vs + 1e-4), floori(lo.y / vs + 1e-4), floori(lo.z / vs + 1e-4))
	var b := Vector3i(ceili(hi.x / vs - 1e-4), ceili(hi.y / vs - 1e-4), ceili(hi.z / vs - 1e-4))
	return VoxelGrid.new(a, b - a)


static func _jit(c: Color, v: Vector3i, amt := 0.06, salt := 0) -> Color:
	return ArenaPalette.jit(c, v, amt, salt)


static func _h(v: Vector3i, salt := 0) -> float:
	return VoxelGrid.hash01(v.x, v.y, v.z, salt)


# --- Relief (BattleTerrain hill / peak) ---


## Hill or peak of BattleTerrain (`o`: kind, pos, r, top, h), on the 0,25 m lattice.
static func relief(o: Dictionary, sc: String) -> Node3D:
	var key := "%s_%s_%.2f_%.2f_%.2f" % [o.kind, sc, float(o.r), float(o.top), float(o.h)]
	var m := cached(key, func() -> VoxelGrid: return _relief_grid(o, sc))
	var root := Node3D.new()
	root.name = "Terrain_%s" % o.kind
	root.position = o.pos
	var body := instance(m, "Relief", _vein_params(sc))
	body.rotation.y = PI * 0.5 * quarter(o.pos, 3)
	root.add_child(body)
	return root


static func _vein_params(sc: String) -> Dictionary:
	var vein: Color = ArenaPalette.of(sc).peak_vein
	return {BODY: {"emit_always": 1.6}} if vein.a > 0.0 else {}


## Height of the gameplay profile (BattleTerrain._height_of) at distance d.
static func _profile(d: float, r: float, top: float, h: float) -> float:
	if d >= r:
		return 0.0
	if d <= top:
		return h
	return h * (1.0 - (d - top) / maxf(r - top, 0.01))


static func _relief_grid(o: Dictionary, sc: String) -> VoxelGrid:
	var p := ArenaPalette.of(sc)
	var r := float(o.r)
	var top := float(o.top)
	var h := float(o.h)
	var peak: bool = o.kind == "peak"
	var n_max := roundi(h / VS)
	var rv := ceili(r / VS) + 1
	var g := VoxelGrid.new(Vector3i(-rv, -1, -rv), Vector3i(rv * 2, n_max + 3, rv * 2))
	var vein: Color = p.peak_vein
	var salt := hash(sc + String(o.kind)) & 0xffff
	for z in range(-rv, rv):
		for x in range(-rv, rv):
			var c := Vector2((x + 0.5) * VS, (z + 0.5) * VS)
			var d := c.length()
			if d >= r + VS:
				continue
			g.put(Vector3i(x, -1, z), Color.BLACK, VoxelMat.STONE, CTX)
			var n := roundi(_profile(d, r, top, h) / VS)
			var hv := VoxelGrid.hash01(x, 0, z, salt)
			if d > top + VS:
				# Slopes: a voxel more or less here and there (the plateau stays flat).
				if hv < (0.28 if peak else 0.16):
					n -= 1
				elif hv > (0.86 if peak else 0.93):
					n += 1
			n = clampi(n, 0, n_max)
			for j in n:
				var v := Vector3i(x, j, z)
				if peak:
					_peak_voxel(g, v, n, p, vein, d < top + VS * 1.5, salt)
				else:
					_hill_voxel(g, v, n, p, salt)
			if n > 0 and not peak and d <= top and hv > 0.975:
				# Tuft (grass) or pebble on the plateau.
				var tuft: Color = (
					Color(p.hill_top).lightened(0.12)
					if int(p.hill_top_mat) in [VoxelMat.GRASS, VoxelMat.MOSS]
					else p.stone
				)
				g.put(
					Vector3i(x, n, z), _jit(tuft, Vector3i(x, n, z), 0.1), int(p.hill_top_mat), BODY
				)
	if peak:
		_base_rocks(g, r, p, salt)
	return g


static func _hill_voxel(g: VoxelGrid, v: Vector3i, n: int, p: Dictionary, salt: int) -> void:
	var hv := _h(v, salt)
	if v.y == n - 1 or (v.y == n - 2 and hv < 0.45):
		var c: Color = p.hill_top
		if v.y == n - 2:
			c = c.darkened(0.12)
		g.put(v, _jit(c, v, 0.07, salt), int(p.hill_top_mat), BODY)
		return
	var side: Color = p.hill_side
	if v.y % 2 == 1:
		side = side.darkened(0.07)  # strata
	if hv < 0.07:
		g.put(v, _jit(p.stone, v, 0.08, salt), VoxelMat.STONE, BODY)
		return
	g.put(v, _jit(side, v, 0.06, salt), int(p.hill_side_mat), BODY)


static func _peak_voxel(
	g: VoxelGrid, v: Vector3i, n: int, p: Dictionary, vein: Color, crown: bool, salt: int
) -> void:
	var hv := _h(v, salt)
	if v.y == n - 1 and (crown or hv < 0.5):
		g.put(v, _jit(p.peak_top, v, 0.06, salt), int(p.peak_top_mat), BODY)
		return
	var c: Color = p.peak
	if (v.y + int(VoxelGrid.hash01(v.x, 0, v.z, salt) * 3.0)) % 3 == 0:
		c = c.darkened(0.1)
	elif hv > 0.88:
		c = c.lightened(0.1)
	if vein.a > 0.0 and v.y > 0 and v.y < n - 1:
		var col_h := VoxelGrid.hash01(v.x, 1, v.z, salt)
		if col_h < 0.07:
			var mat := VoxelMat.LAVA if vein.r > vein.b else VoxelMat.CRYSTAL
			g.put(v, _jit(vein, v, 0.12, salt), mat, BODY)
			return
	g.put(v, _jit(c, v, 0.05, salt), VoxelMat.STONE, BODY)


## Two or three loose rocks at the foot of a peak (looks only: inside its radius).
static func _base_rocks(g: VoxelGrid, r: float, p: Dictionary, salt: int) -> void:
	for i in 3:
		var a := TAU * (float(i) / 3.0 + VoxelGrid.hash01(i, 5, 0, salt) * 0.25)
		var d := (r - 0.3) / VS
		var c := Vector3i(roundi(cos(a) * d), 0, roundi(sin(a) * d))
		for dz in 2:
			for dx in 2:
				var v := c + Vector3i(dx, 0, dz)
				if not g.solid(v):
					g.put(v, _jit(p.peak, v, 0.08, salt), VoxelMat.STONE, BODY)
		if VoxelGrid.hash01(i, 6, 0, salt) < 0.5 and not g.solid(c + Vector3i(0, 1, 0)):
			g.put(c + Vector3i(0, 1, 0), _jit(p.peak_top, c, 0.06, salt), VoxelMat.STONE, BODY)


# --- Pond ---


## Radius of the hole a pond leaves in the floor (the rain makes it RAIN_POND x the base radius).
static func pond_hole(r0: float) -> float:
	return r0 * BattleTerrain.RAIN_POND


## Pond of BattleTerrain (`o`: pos, r, r0): voxel bowl below the floor + WaterSurface (a disc, the
## ellipse inscribed in its square) at a level set by the radius (pond_level), frozen by the water
## shader's own ice (pond_ice).
static func pond(o: Dictionary, sc: String) -> Node3D:
	var r0 := float(o.r0)
	var p := ArenaPalette.of(sc)
	var m := cached(
		"pond_%s_%.3f" % [sc, r0], func() -> VoxelGrid: return _bowl_grid(r0, p, hash(sc) & 0xfff)
	)
	var root := Node3D.new()
	root.name = "Terrain_pond"
	root.position = o.pos
	root.add_child(instance(m, "Bowl", {}, false))
	var size := (pond_hole(r0) + 0.4) * 2.0
	var w := WaterSurface.make(
		Vector2(size, size), {"kind": "pond", "shape": "ellipse", "depth": 0.9, "tint": p.water}
	)
	root.add_child(w)
	root.set_meta("water", w)
	root.set_meta("r0", r0)
	pond_level(o, root)
	return root


## Water (and ice) at the level of the pond's current radius.
static func pond_level(o: Dictionary, node) -> void:
	if not is_instance_valid(node) or not node.has_meta("water"):
		return
	var k := float(o.r) / maxf(float(o.r0), 0.01)
	var y: float = POND_LEVELS[0][1]
	for i in range(1, POND_LEVELS.size()):
		var a: Array = POND_LEVELS[i - 1]
		var b: Array = POND_LEVELS[i]
		if k >= float(a[0]):
			y = lerpf(float(a[1]), float(b[1]), clampf((k - float(a[0])) / (b[0] - a[0]), 0.0, 1.0))
	var w = node.get_meta("water")
	if is_instance_valid(w):
		w.position.y = y


## Frozen pond: the water shader's ice (frost and cracks over the whole surface) grows in quickly
## and melts back the same way.
static func pond_ice(o: Dictionary, node, on: bool) -> void:
	if not is_instance_valid(node) or not node.has_meta("water"):
		return
	var w = node.get_meta("water")
	if not is_instance_valid(w):
		return
	var to := 1.0 if on else 0.0
	var m := WaterSurface.material_of(w)
	if m == null:
		return
	var cur: Variant = m.get_shader_parameter("freeze")  # null until first set
	var now := float(cur) if cur != null else 0.0
	if is_equal_approx(now, to):
		return
	if node.has_meta("freeze_tw"):
		var old: Tween = node.get_meta("freeze_tw")
		if old and old.is_valid():
			old.kill()
	if not (node as Node).is_inside_tree():
		WaterSurface.set_freeze(w, to)
		return
	var tw := (node as Node).create_tween()
	tw.tween_method(func(v: float) -> void: WaterSurface.set_freeze(w, v), now, to, ICE_SECS)
	node.set_meta("freeze_tw", tw)
	pond_level(o, node)


static func _bowl_grid(r0: float, p: Dictionary, salt: int) -> VoxelGrid:
	var rh := pond_hole(r0)
	var rv := ceili((rh + 0.5) / VS) + 1
	var g := VoxelGrid.new(Vector3i(-rv, -6, -rv), Vector3i(rv * 2, 6, rv * 2))
	for z in range(-rv, rv):
		for x in range(-rv, rv):
			var d := Vector2((x + 0.5) * VS, (z + 0.5) * VS).length()
			if d >= rh + 0.5:
				continue
			if d >= rh:
				g.fill(Vector3i(x, -6, z), Vector3i(x, -1, z), Color.BLACK, VoxelMat.DIRT, CTX)
				continue
			var top := -1.0
			for s in POND_STEPS:
				if d >= float(s[0]) * r0:
					top = float(s[1])
					break
			var jt := roundi(top / VS) - 1  # top voxel index (top = -0.25 -> j = -2)
			var hv := VoxelGrid.hash01(x, 0, z, salt)
			for j in range(-6, jt + 1):
				var v := Vector3i(x, j, z)
				var c: Color
				var mat := VoxelMat.BED
				if top >= -0.26:
					c = _jit(p.shore, v, 0.07, salt)
					mat = int(p.shore_mat)
				elif top >= -0.51:
					c = _jit(Color(p.bed).lerp(p.shore, 0.35), v, 0.07, salt)
				elif top >= -0.76:
					c = _jit(p.bed, v, 0.07, salt)
				else:
					c = _jit(p.bed_deep, v, 0.06, salt)
				if j == jt and hv < 0.12:
					c = _jit(p.pebble, v, 0.12, salt)
				g.put(v, c, mat, BODY)
	return g


# --- Tall grass ---


## Tall-grass patch (`gr`: pos, r): tufts of detail-voxel blades in a few MultiMeshes (one per tuft
## shape), swaying in the wind. Its ground is painted in the floor (ArenaFloor).
static func grass(gr: Dictionary, sc: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Terrain_grass"
	root.position = gr.pos
	var r := float(gr.r)
	var rng := ArenaPalette.rng_at(gr.pos, "grass")
	var kinds := 4
	var n := int(10.0 + r * r * 9.0)
	var lists: Array = []
	for k in kinds:
		lists.append([])
	for i in n:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * r * 0.9
		var t := Transform3D(
			Basis(Vector3.UP, PI * 0.5 * rng.randi_range(0, 3)).scaled(
				Vector3(1.0, rng.randf_range(0.85, 1.15), 1.0)
			),
			Vector3(cos(a) * d, 0.0, sin(a) * d)
		)
		lists[i % kinds].append(t)
	var mat := VoxelMat.detail_material({"sway": 0.5, "backlight": 0.3})
	for k in kinds:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = _tuft(sc, k)
		mm.instance_count = lists[k].size()
		for i in lists[k].size():
			mm.set_instance_transform(i, lists[k][i])
			mm.set_instance_custom_data(i, Color(rng.randf(), 0, 0, 0))
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Tufts%d" % k
		mmi.multimesh = mm
		mmi.material_override = mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mmi)
	return root


## Tuft `k` of blades (detail voxels, cached per scenario).
static func _tuft(sc: String, k: int) -> ArrayMesh:
	var key := "%s_%d" % [sc, k]
	if _detail.has(key):
		return _detail[key]
	var blades: Array = ArenaPalette.of(sc).blades
	var g := VoxelGrid.new(Vector3i(-3, 0, -3), Vector3i(7, 13, 7))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("tuft_" + key)
	for i in 7 + k:
		var x := rng.randi_range(-2, 2)
		var z := rng.randi_range(-2, 2)
		var tall := rng.randi_range(6, 12)
		var lean := Vector2i(rng.randi_range(-1, 1), rng.randi_range(-1, 1))
		for y in tall:
			var off := lean * (y * 2 / tall) if y > tall / 2 else Vector2i.ZERO
			var c: int = (
				0 if y < tall * 0.3 else (1 if y < tall * 0.6 else (2 if y < tall - 1 else 3))
			)
			g.put(Vector3i(x + off.x, y, z + off.y), blades[c], VoxelMat.LEAVES)
	var m := VoxelMesher.colored(g, DETAIL, Vector3(0.5, 0.0, 0.5))
	_detail[key] = m
	return m


# --- Biome solids, cliff, lava, rune, snow ---


## Ruins pillar or snow mound of BattleBiomes (`s`: kind, pos, r, h).
static func solid(s: Dictionary, sc: String) -> Node3D:
	var variant := int(VoxelGrid.hash01(roundi(s.pos.x * 4.0), 9, roundi(s.pos.z * 4.0)) * 3.0)
	var pillar: bool = s.kind == "pillar"
	var h := float(s.h)
	var make := func() -> VoxelGrid:
		return _pillar_grid(h, variant, sc) if pillar else _mound_grid(sc, variant)
	var m := cached("%s_%s_%d_%.2f" % [s.kind, sc, variant, h], make)
	var root := instance(m, "Biome_%s" % s.kind)
	root.position = s.pos
	root.rotation.y = PI * 0.5 * quarter(s.pos, 4)
	return root


static func _pillar_grid(h: float, variant: int, sc: String) -> VoxelGrid:
	var p := ArenaPalette.of(sc)
	var n := roundi(h / VS)
	var g := VoxelGrid.new(Vector3i(-4, -1, -4), Vector3i(8, n + 3, 8))
	var stone: Color = p.peak
	var salt := 31 + variant
	g.fill(Vector3i(-4, -1, -4), Vector3i(3, -1, 3), Color.BLACK, VoxelMat.STONE, CTX)
	# Plinth, fluted shaft (corners cut), capital; variant 2 lost a chunk of the capital.
	for z in range(-3, 3):
		for x in range(-3, 3):
			var v := Vector3i(x, 0, z)
			g.put(v, _jit(stone.darkened(0.08), v, 0.06, salt), VoxelMat.STONE, BODY)
	for y in range(1, n):
		for z in range(-2, 2):
			for x in range(-2, 2):
				if (x == -2 or x == 1) and (z == -2 or z == 1):
					continue
				var v := Vector3i(x, y, z)
				var c: Color = stone
				if (x + z) % 2 == 0:
					c = c.darkened(0.06)
				if y < 3 and _h(v, salt) < 0.25:
					c = Color(p.grass_dark).lerp(stone, 0.4)  # moss at the foot
				g.put(v, _jit(c, v, 0.05, salt), VoxelMat.STONE, BODY)
	for z in range(-3, 3):
		for x in range(-3, 3):
			var v := Vector3i(x, n, z)
			if variant == 2 and x >= 1 and z >= 0:
				continue
			var c: Color = p.peak_top if _h(v, salt) > 0.2 else Color(p.grass).darkened(0.1)
			g.put(v, _jit(c, v, 0.05, salt), VoxelMat.STONE, BODY)
	return g


static func _mound_grid(sc: String, variant: int) -> VoxelGrid:
	var p := ArenaPalette.of(sc)
	var g := VoxelGrid.new(Vector3i(-4, -1, -4), Vector3i(8, 5, 8))
	g.fill(Vector3i(-4, -1, -4), Vector3i(3, -1, 3), Color.BLACK, VoxelMat.SNOW, CTX)
	var salt := 41 + variant
	for z in range(-4, 4):
		for x in range(-4, 4):
			var d := Vector2(x + 0.5, z + 0.5).length() / 3.6
			if d > 1.0:
				continue
			var n := roundi((1.0 - d * d) * 3.0 + _h(Vector3i(x, 0, z), salt) * 0.8)
			for y in n:
				var v := Vector3i(x, y, z)
				g.put(v, _jit(p.snow, v, 0.04, salt), VoxelMat.SNOW, BODY)
	return g


## Montanha cliff behind the court: a rock wall of `long` m along x (local), from z = 0 back to
## `depth`, `h` m tall, with ledges and a snow cap. Local origin = front edge middle.
static func cliff(long: float, h: float, depth: float, sc: String) -> Node3D:
	var key := "cliff_%s_%.1f_%.1f_%.1f" % [sc, long, h, depth]
	var m := cached(key, func() -> VoxelGrid: return _cliff_grid(long, h, depth, sc))
	return instance(m, "Biome_cliff")


static func _cliff_grid(long: float, h: float, depth: float, sc: String) -> VoxelGrid:
	var p := ArenaPalette.of(sc)
	var nx := roundi(long * 0.5 / VS)
	var nz := roundi(depth / VS)
	var nh := roundi(h / VS)
	var g := VoxelGrid.new(Vector3i(-nx, -1, -nz), Vector3i(nx * 2, nh + 3, nz + 1))
	var salt := 57
	for z in range(-nz, 0):
		for x in range(-nx, nx):
			g.put(Vector3i(x, -1, z), Color.BLACK, VoxelMat.STONE, CTX)
			# Front face steps back with height (ledges); the top line wanders.
			var top := nh + roundi((ArenaPalette.noise(x * 0.12, 0.5, salt) - 0.5) * 6.0)
			var fz := -1 - int(ArenaPalette.noise(x * 0.2, 3.0, salt) * 2.0)
			for y in range(0, top):
				var back := fz - y / 4 - int(_h(Vector3i(x, y / 3, 0), salt) * 1.5)
				if z > back:
					continue
				var v := Vector3i(x, y, z)
				var c: Color = p.peak
				if (y + int(VoxelGrid.hash01(x / 3, 0, 0, salt) * 3.0)) % 4 == 0:
					c = c.darkened(0.12)
				elif _h(v, salt) > 0.9:
					c = c.lightened(0.12)
				g.put(v, _jit(c, v, 0.05, salt), VoxelMat.STONE, BODY)
	# Snow on every exposed top and ledge.
	for z in range(-nz, 0):
		for x in range(-nx, nx):
			var t := g.top_y(x, z)
			if t < 0:
				continue
			var v := Vector3i(x, t, z)
			g.put(v, _jit(p.snow, v, 0.03, salt), VoxelMat.SNOW, BODY)
			if t + 1 < nh + 2 and _h(v, salt + 1) < 0.35:
				g.put(v + Vector3i(0, 1, 0), _jit(p.snow, v, 0.03, salt), VoxelMat.SNOW, BODY)
	return g


## One 1 m cell of a lava river (`c`: pos, dir), its own material so it can cool (lava_look).
static func lava_cell(c: Dictionary) -> Node3D:
	var variant := int(VoxelGrid.hash01(roundi(c.pos.x * 4.0), 3, roundi(c.pos.z * 4.0)) * 3.0)
	var m := cached("lava_%d" % variant, func() -> VoxelGrid: return _lava_grid(variant))
	var root := instance(m, "Biome_lava", {BODY: {"emit_always": LAVA_GLOW}}, false)
	root.position = c.pos + Vector3(0, -0.08, 0)
	return root


static func _lava_grid(variant: int) -> VoxelGrid:
	var g := VoxelGrid.new(Vector3i(-2, -1, -2), Vector3i(4, 1, 4))
	var cols := [Color("ffd040"), Color("ff9a1e"), Color("e8540c"), Color("b8300a")]
	for z in range(-2, 2):
		for x in range(-2, 2):
			var v := Vector3i(x, -1, z)
			var hv := _h(v, 91 + variant)
			# Mostly orange with hot yellow streaks; a dark crust voxel here and there.
			var k := 1 if hv < 0.5 else (0 if hv < 0.78 else (2 if hv < 0.96 else 3))
			g.put(v, cols[k], VoxelMat.LAVA, BODY)
	return g


## Lava cell look: hot (glowing, flickering) or cooled into dark rock.
static func lava_look(node, cool: bool, t := 0.0) -> void:
	if not is_instance_valid(node):
		return
	if cool:
		set_param(node, "tint", Color(0.2, 0.17, 0.16))
		set_param(node, "emit_always", 0.0)
		set_param(node, "flash", Vector3.ZERO)
	else:
		set_param(node, "tint", Color.WHITE)
		set_param(node, "emit_always", LAVA_GLOW)
		var f := 0.12 + 0.12 * sin(t * 3.0 + node.position.x * 1.7 + node.position.z)
		set_param(node, "flash", Vector3(f, f * 0.35, 0.0))


## Rune circle of the ruins (radius `r`): glowing glyph ring, tinted by the side that holds it.
static func rune(r: float) -> Node3D:
	var m := cached("rune_%.2f" % r, func() -> VoxelGrid: return _rune_grid(r), FINE)
	var root := instance(m, "Biome_rune", {BODY: {"emit_always": 1.2}}, false)
	root.scale = Vector3(1.0, DECAL_H / FINE, 1.0)
	return root


static func _rune_grid(r: float) -> VoxelGrid:
	var n := ceili(r / FINE)
	var g := VoxelGrid.new(Vector3i(-n, 0, -n), Vector3i(n * 2, 1, n * 2))
	for z in range(-n, n):
		for x in range(-n, n):
			# The pattern of BattleBiomes.rune_tex (64 px across the circle).
			var dx := (x + 0.5) / float(n) * 32.0
			var dy := (z + 0.5) / float(n) * 32.0
			var d := sqrt(dx * dx + dy * dy)
			var a := atan2(dy, dx)
			var on := absf(d - 30.0) < 1.6 or absf(d - 25.0) < 1.2
			if not on and d > 25.5 and d < 29.5:
				var seg := int(floor((a + PI) / TAU * 16.0))
				var off := fmod((a + PI) / TAU * 16.0, 1.0)
				on = off > 0.25 and off < 0.75 and (seg % 2 == 0 or absf(d - 27.5) < 1.0)
			elif not on and d < 12.0:
				on = absf(absf(dx) - absf(dy)) < 1.2 or absf(d - 11.0) < 1.2
			if on:
				g.put(Vector3i(x, 0, z), Color(0.92, 0.9, 1.0), VoxelMat.CRYSTAL, BODY)
	return g


## Rune look: tint (the colour of the side that holds it) and glow strength.
static func rune_look(node, col: Color, glow: float) -> void:
	set_param(node, "tint", col)
	set_param(node, "emit_always", glow)


## Deep snow cell of an avalanche (montanha).
static func snow_cell(sc: String, at: Vector3) -> Node3D:
	var variant := int(VoxelGrid.hash01(roundi(at.x * 4.0), 7, roundi(at.z * 4.0)) * 3.0)
	var m := cached(
		"snowcell_%s_%d" % [sc, variant], func() -> VoxelGrid: return _snow_cell_grid(sc, variant)
	)
	var root := instance(m, "Biome_snow", {}, false)
	root.position = at
	return root


static func _snow_cell_grid(sc: String, variant: int) -> VoxelGrid:
	var p := ArenaPalette.of(sc)
	var g := VoxelGrid.new(Vector3i(-5, 0, -5), Vector3i(10, 3, 10))
	var salt := 61 + variant
	for z in range(-5, 5):
		for x in range(-5, 5):
			var e := maxf(absf(x + 0.5), absf(z + 0.5)) / 5.0
			var n := 2 if e < 0.7 else 1
			if _h(Vector3i(x, 0, z), salt) < 0.25:
				n += 1 if e < 0.7 else -1
			for y in maxi(n, 0):
				var v := Vector3i(x, y, z)
				g.put(v, _jit(p.snow, v, 0.04, salt), VoxelMat.SNOW, BODY)
	return g


# --- Flat decals (mud, marks, webs, vines) ---


## Flat round decal of `kind` (radius `r`), DECAL_H thick, sitting on the floor (local y 0).
## Kinds: mud, mud_dry, ice, ember, puddle, web, vine, fissure (fissure: r = half length, along x).
static func decal(kind: String, r: float, sc := "", vs := VS) -> Node3D:
	var key := "decal_%s_%s_%.3f_%.3f" % [kind, sc, r, vs]
	var m := cached(key, func() -> VoxelGrid: return _decal_grid(kind, r, vs), vs)
	var params := {}
	if kind == "ember":
		params = {BODY: {"emit_always": 1.6}}
	var root := instance(m, "Decal_%s" % kind, params, false)
	root.scale = Vector3(1.0, DECAL_H / vs, 1.0)
	return root


static func _decal_grid(kind: String, r: float, vs: float) -> VoxelGrid:
	var n := ceili(r / vs)
	var nz := n if kind != "fissure" else ceili(BattleGround.FISSURE_W * 0.5 / vs)
	var g := VoxelGrid.new(Vector3i(-n, 0, -nz), Vector3i(n * 2, 1, nz * 2))
	var salt := hash(kind) & 0xffff
	for z in range(-nz, nz):
		for x in range(-n, n):
			var v := Vector3i(x, 0, z)
			var c := Vector2(x + 0.5, z + 0.5) * vs
			var d := c.length() / r
			var hv := _h(v, salt)
			if kind != "fissure" and d > 1.0 - 0.18 * hv * float(d > 0.75):
				continue
			var col := Color.BLACK
			var mat := VoxelMat.DIRT
			match kind:
				"mud":
					col = Color("45301f") if hv < 0.6 else Color("5a3f28")
					if ArenaPalette.noise(c.x * 1.6, c.y * 1.6, salt) > 0.68:
						col = Color("2e1f14")  # wet pools
						mat = VoxelMat.BED
				"mud_dry":
					col = Color("9a7a52") if hv < 0.6 else Color("ad8c60")
					var cr := ArenaPalette.noise(c.x * 2.5, c.y * 2.5, salt)
					if absf(cr - 0.5) < 0.05:
						col = Color("4a3524")  # cracks
				"ice":
					col = Color("c4e6f8") if hv < 0.7 else Color("e8f6ff")
					mat = VoxelMat.ICE
				"ember":
					col = Color("1c1410") if hv < 0.55 else Color("3a2418")
					if hv > 0.86:
						col = Color("ff8a2a") if hv > 0.94 else Color("d8400c")
						mat = VoxelMat.FIRE
				"puddle":
					col = Color("3a74c8").lerp(Color("5a94e0"), hv * 0.5)
					mat = VoxelMat.GLASS
				"web":
					var a := atan2(c.y, c.x)
					var spoke := absf(fmod(a / TAU * 8.0 + 8.0, 1.0) - 0.5) > 0.42
					var ring := absf(fmod(c.length() / r * 4.0, 1.0) - 0.5) > 0.38
					if not (spoke or ring):
						continue
					col = Color("eeeeea")
					mat = VoxelMat.CLOTH
				"vine":
					var coil := absf(fmod(c.length() / r * 3.0 + atan2(c.y, c.x) / TAU, 1.0) - 0.5)
					if coil < 0.28:
						continue
					col = Color("2f6b2a") if hv < 0.6 else Color("4f8f3e")
					mat = VoxelMat.LEAVES
				"fissure":
					var e := absf(c.y) / (BattleGround.FISSURE_W * 0.5)
					var tip := absf(c.x) / r
					if e > 1.0 - 0.6 * tip * tip:
						continue
					col = Color("120c08") if e < 0.45 else Color("3a2818")
					mat = VoxelMat.STONE
			g.put(v, col, mat, BODY)
	return g


## Flat thing on the floor at `at`: a holder node (scaled by the caller to grow or fade) with the
## decal inside.
static func flat(kind: String, r: float, at: Vector3, sc := "", vs := VS) -> Node3D:
	var root := Node3D.new()
	root.name = "Ground_%s" % kind
	root.position = Vector3(at.x, 0.0, at.z)
	root.add_child(decal(kind, r, sc, vs))
	return root


## Swaps the decal inside a flat() holder (mud drying into cracked ground and back, a puddle
## freezing).
static func flat_look(node, kind: String, r: float, sc := "", vs := VS) -> void:
	if not is_instance_valid(node):
		return
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()
	node.add_child(decal(kind, r, sc, vs))


# --- Ground extras: log bridge, pylon, rocks, snow heaps ---


## Log lying from a to b across a pond (local origin = middle, along +x before the turn).
static func log_bridge(len: float) -> Node3D:
	var n := roundi(len * 0.5 / FINE)
	var m := cached("log_%d" % n, func() -> VoxelGrid: return _log_grid(n), FINE)
	return instance(m, "Ground_bridge")


static func _log_grid(n: int) -> VoxelGrid:
	var g := VoxelGrid.new(Vector3i(-n, -3, -3), Vector3i(n * 2, 6, 6))
	var bark := [Color("3a2414"), Color("5a3a20"), Color("70492a")]
	for x in range(-n, n):
		for z in range(-3, 3):
			for y in range(-3, 3):
				var d := Vector2(y + 0.5, z + 0.5).length()
				if d > 2.9:
					continue
				var v := Vector3i(x, y, z)
				var c: Color = bark[1]
				var mat := VoxelMat.BARK
				if x == -n or x == n - 1:
					c = Color("c49a62") if d < 1.6 else Color("a07a4a")  # cut ends, rings
					mat = VoxelMat.WOOD
				elif (z + 3 + int(_h(Vector3i(x / 4, 0, z), 5) * 2.0)) % 3 == 0:
					c = bark[0]
				elif _h(v, 5) > 0.85:
					c = bark[2]
				if y >= 2 and _h(v, 6) < 0.12 and mat == VoxelMat.BARK:
					c = Color("4f8f3e")  # moss
					mat = VoxelMat.MOSS
				g.put(v, _jit(c, v, 0.05, 5), mat, BODY)
	return g


## Lightning-rod pylon (metal pole, two insulator bars, copper tip) on a concrete foot.
static func pylon() -> Node3D:
	var m := cached("pylon", func() -> VoxelGrid: return _pylon_grid(), FINE)
	return instance(m, "Ground_pylon")


static func _pylon_grid() -> VoxelGrid:
	var n := roundi(BattleGroundExtras.PYLON_H / FINE)
	var g := VoxelGrid.new(Vector3i(-4, -1, -4), Vector3i(8, n + 3, 8))
	g.fill(Vector3i(-3, -1, -3), Vector3i(2, -1, 2), Color.BLACK, VoxelMat.STONE, CTX)
	g.fill(Vector3i(-2, 0, -2), Vector3i(1, 0, 1), Color("9a9a96"), VoxelMat.SLAB, BODY)
	for y in range(1, n):
		for z in range(-1, 1):
			for x in range(-1, 1):
				var c := Color("6a717c") if (x + z + y / 3) % 2 == 0 else Color("59606a")
				g.put(Vector3i(x, y, z), c, VoxelMat.METAL, BODY)
	for k in 2:
		var y := roundi(n * (0.7 + 0.18 * k))
		var w := 3 - k
		for x in range(-w - 1, w + 1):
			g.put(Vector3i(x, y, 0), Color("5a606a"), VoxelMat.METAL, BODY)
			g.put(Vector3i(x, y, -1), Color("5a606a"), VoxelMat.METAL, BODY)
		for x in [-w - 1, w]:
			g.put(Vector3i(x, y + 1, 0), Color("e8eef2"), VoxelMat.PLASTER)  # insulators
	for y in range(n, n + 2):
		for z in range(-1, 1):
			for x in range(-1, 1):
				g.put(Vector3i(x, y, z), Color("c88040"), VoxelMat.METAL, BODY)
	g.put(Vector3i(0, n + 2, 0), Color("f0c070"), VoxelMat.METAL, BODY)
	return g


## Small loose rock (BattleGroundExtras rocks), radius `r`.
static func rock(r: float, at: Vector3) -> Node3D:
	var variant := int(VoxelGrid.hash01(roundi(at.x * 8.0), 2, roundi(at.z * 8.0)) * 3.0)
	var make := func() -> VoxelGrid:
		return _blob_grid(r, r * 0.8, BattleTerrain._palette("stone"), variant)
	var m := cached("smallrock_%.2f_%d" % [r, variant], make, FINE)
	var root := instance(m, "Ground_rock")
	root.position = at
	root.rotation.y = PI * 0.5 * quarter(at, 5)
	return root


## Snow heap (BattleGroundExtras snow), radius `r`, height `h`.
static func snow_heap(r: float, h: float, at: Vector3, sc: String) -> Node3D:
	var p := ArenaPalette.of(sc)
	var snow: Color = p.snow
	var pal := [snow.darkened(0.08), snow.darkened(0.03), snow, snow.lightened(0.1)]
	var make := func() -> VoxelGrid: return _blob_grid(r, h, pal, 0, VoxelMat.SNOW)
	var m := cached("snowheap_%s_%.2f_%.2f" % [sc, r, h], make, FINE)
	var root := instance(m, "Ground_snow")
	root.position = at
	return root


## Rounded heap of radius `r` and height `h` (FINE voxels) from a 4-tone palette (dark -> light).
static func _blob_grid(
	r: float, h: float, pal: Array, variant: int, mat := VoxelMat.STONE
) -> VoxelGrid:
	var n := ceili(r / FINE) + 1
	var nh := ceili(h / FINE) + 1
	var g := VoxelGrid.new(Vector3i(-n, -1, -n), Vector3i(n * 2, nh + 2, n * 2))
	var salt := 71 + variant
	var rr := r / FINE
	var hh := h / FINE
	for z in range(-n, n):
		for x in range(-n, n):
			var d := Vector2(x + 0.5, z + 0.5).length() / rr
			if d > 1.15:
				continue
			g.put(Vector3i(x, -1, z), Color.BLACK, mat, CTX)
			if d > 1.0:
				continue
			var k := sqrt(maxf(1.0 - d * d, 0.0))
			var top := roundi(hh * k + (_h(Vector3i(x, 0, z), salt) - 0.5) * 1.5)
			for y in maxi(top, 1):
				var v := Vector3i(x, y, z)
				var shade := 1 if y < top - 1 else 2
				var hv := _h(v, salt)
				if hv > 0.9:
					shade = 3
				elif hv < 0.12:
					shade = 0
				g.put(v, _jit(pal[shade], v, 0.04, salt), mat, BODY)
	return g

class_name ArenaDebris
extends Node3D
## Looks of a destroyed obstacle on the energy-mode field (BattleDestruction, docs/VOXEL.md §7):
## - burst(): voxel chunks that fly out with gravity, bounce on the floor (BattleTerrain.height_at),
##   spin, slide and shrink away; wood splinters and fluttering leaves for trees and bushes, stone
##   chunks for rocks / columns / peaks, earth clods for hills, planks for crates.
## - rubble(): a low voxel rubble patch left on the floor for the rest of the fight.
## - shake(): a short camera shake through Camera3D.h_offset (BattleDirector drives position and
##   v_offset and never touches h_offset).
## Pure visuals: the callers never run them under fast_sim, and nothing here uses the battle RNG.

const GRAVITY := 14.0
const BOUNCE := 0.35
const SLIDE := 0.55
const REST_V := 0.6  ## below this vertical speed a landed chunk stops bouncing
const LEAF_FALL := 0.9  ## leaves sink at most this fast (m/s)
const LEAF_DRAG := 2.2
const LIFE := Vector2(1.6, 2.6)
const FADE := 0.45  ## chunks shrink away in their last FADE s
const MIN_CHUNKS := 6
const MAX_CHUNKS := 34
const SHAKE_HZ := 31.0
const FINE := ArenaVoxels.FINE

## {node, vel, spin, life, leaf, half, base, ph}
var chunks: Array = []
var floor_at := Callable()
var arena: Node = null
var _t := 0.0
var _cam: Camera3D = null
var _shake := 0.0
var _shake_t := 0.0
var _shake_total := 0.0

static var _meshes := {}
static var _mats := {}


## Colours of a debris material (dark -> light) for scenario `sc`.
static func colours(mat: String, sc: String) -> Array:
	var p := ArenaPalette.of(sc)
	match mat:
		"earth":
			return [p.dirt_dark, p.hill_side, p.dirt, p.hill_top]
		"tree", "wood":
			return [p.bark_dark, p.bark, Color(p.bark).lightened(0.18), Color("c9a271")]
		"bush", "leaves":
			return [p.leaves_dark, p.leaves, p.leaves_light]
		"crate":
			return BattleTerrain._palette("crate")
		"snow":
			var s: Color = p.snow
			return [s.darkened(0.1), s.darkened(0.04), s, s.lightened(0.1)]
		"crystal":
			return [Color("4fb6d8"), Color("7fd8f0"), Color("b8f0ff"), Color("e8fcff")]
		"metal":
			return [Color("4a5059"), Color("6c7480"), Color("98a1ac"), Color("c27b3f")]
	return [p.stone_dark, p.peak, p.stone, p.stone_light]


static func _vmat(mat: String) -> int:
	match mat:
		"earth":
			return VoxelMat.DIRT
		"tree", "wood", "crate":
			return VoxelMat.WOOD
		"bush", "leaves":
			return VoxelMat.LEAVES
		"snow":
			return VoxelMat.SNOW
		"crystal":
			return VoxelMat.CRYSTAL
		"metal":
			return VoxelMat.METAL
	return VoxelMat.STONE


static func _box_mesh(sz: Vector3) -> BoxMesh:
	var key := "%.3f_%.3f_%.3f" % [sz.x, sz.y, sz.z]
	if not _meshes.has(key):
		var bm := BoxMesh.new()
		bm.size = sz
		_meshes[key] = bm
	return _meshes[key]


static func _mat(c: Color, glow := false) -> StandardMaterial3D:
	var key := c.to_html(false) + ("g" if glow else "")
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.9
		if glow:
			m.emission_enabled = true
			m.emission = c
			m.emission_energy_multiplier = 0.6
		_mats[key] = m
	return _mats[key]


## Chunks of `mat` bursting out of an obstacle standing at `at` (its base, arena local), `h` tall
## and `r` wide, pushed a bit along `dir` (the throw). `floor_fn(p) -> float` is the floor height.
static func burst(
	parent: Node,
	at: Vector3,
	h: float,
	r: float,
	mat: String,
	sc: String,
	dir := Vector3.ZERO,
	floor_fn := Callable()
) -> ArenaDebris:
	if parent == null or not parent.is_inside_tree():
		return null
	var d := ArenaDebris.new()
	d.name = "Debris"
	d.arena = parent
	d.floor_at = floor_fn
	parent.add_child(d)
	var rng := RandomNumberGenerator.new()
	rng.randomize()  # visual only: never the battle RNG
	var cols := colours(mat, sc)
	var leaves: Array = colours("leaves", sc) if mat == "tree" else []
	var n := clampi(int(MIN_CHUNKS + r * h * 9.0 + r * 6.0), MIN_CHUNKS, MAX_CHUNKS)
	var spread := clampf(r, 0.2, 3.0)
	var push := Vector3(dir.x, 0.0, dir.z)
	if push.length() > 0.01:
		push = push.normalized()
	for i in n:
		var leaf := false
		var c: Color = cols[rng.randi() % cols.size()]
		var sz := Vector3.ONE * FINE * float(rng.randi_range(1, 2 + mini(int(r * 1.5), 2)))
		match mat:
			"tree", "wood":
				# Splinters: long thin sticks.
				sz = Vector3(FINE * 0.6, FINE * 0.6, rng.randf_range(0.18, 0.45))
				if not leaves.is_empty() and i % 2 == 0:
					leaf = true
					c = leaves[rng.randi() % leaves.size()]
					sz = Vector3(FINE * 1.2, FINE * 0.25, FINE * 1.2)
			"crate":
				sz = Vector3(rng.randf_range(0.18, 0.4), FINE * 0.5, FINE * 1.2)
			"bush", "leaves":
				leaf = i % 4 != 0
				sz = (
					Vector3(FINE * 1.1, FINE * 0.25, FINE * 1.1)
					if leaf
					else Vector3(FINE * 0.4, FINE * 0.4, 0.2)
				)
			"snow":
				sz = Vector3.ONE * FINE * float(rng.randi_range(1, 2))
		var mi := MeshInstance3D.new()
		mi.mesh = _box_mesh(sz)
		mi.material_override = _mat(c, mat == "crystal")
		if leaf or sz.length() < FINE * 1.3:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a := rng.randf() * TAU
		var out := Vector3(cos(a), 0.0, sin(a))
		var y := rng.randf_range(0.1, maxf(h, 0.3)) * (0.6 if leaf else 1.0)
		if mat == "tree" and leaf:
			y = rng.randf_range(h * 0.55, h)  # leaves come from the crown
		mi.position = at + out * rng.randf_range(0.0, spread * 0.6) + Vector3(0, y, 0)
		mi.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)
		d.add_child(mi)
		var speed := rng.randf_range(1.2, 3.6) * (0.7 + 0.25 * spread)
		var vel := (
			out * speed + push * rng.randf_range(0.8, 3.5) + Vector3.UP * rng.randf_range(2.0, 5.5)
		)
		if leaf:
			vel *= 0.55
		(
			d
			. chunks
			. append(
				{
					"node": mi,
					"vel": vel,
					"spin":
					Vector3(rng.randf_range(-9, 9), rng.randf_range(-9, 9), rng.randf_range(-9, 9)),
					"life": rng.randf_range(LIFE.x, LIFE.y) * (1.4 if leaf else 1.0),
					"leaf": leaf,
					"half": sz.y * 0.5,
					"base": Vector3.ONE,
					"ph": rng.randf() * TAU,
				}
			)
		)
	return d


## Low voxel rubble patch (stays) where an obstacle of radius `r` stood; `at` = floor point.
static func rubble(parent: Node, at: Vector3, r: float, mat: String, sc: String) -> Node3D:
	if parent == null or not parent.is_inside_tree():
		return null
	var rr := clampf(snappedf(r * 0.9, FINE), 0.25, 3.0)
	var variant := ArenaVoxels.quarter(at, 9)
	var key := "rubble_%s_%s_%.3f_%d" % [mat, sc, rr, variant]
	var cols := colours(mat if mat != "tree" else "wood", sc)
	var vm := _vmat(mat)
	var make := func() -> VoxelGrid: return _rubble_grid(rr, cols, variant, vm)
	var m := ArenaVoxels.cached(key, make, FINE)
	var node := ArenaVoxels.instance(m, "Rubble", {}, false)
	node.set_meta("rubble", true)
	node.position = at
	node.rotation.y = PI * 0.5 * float(ArenaVoxels.quarter(at, 4))
	parent.add_child(node)
	return node


## Scattered low heap: dense in the middle, broken up towards the edge, 1-3 voxels high.
static func _rubble_grid(r: float, cols: Array, variant: int, vm: int) -> VoxelGrid:
	var n := ceili(r / FINE) + 1
	var g := VoxelGrid.new(Vector3i(-n, -1, -n), Vector3i(n * 2, 5, n * 2))
	var rr := r / FINE
	var salt := 131 + variant
	for z in range(-n, n):
		for x in range(-n, n):
			var d := Vector2(x + 0.5, z + 0.5).length() / rr
			if d > 1.1:
				continue
			g.put(Vector3i(x, -1, z), Color.BLACK, vm, ArenaVoxels.CTX)
			if d > 1.0 or VoxelGrid.hash01(x, 0, z, salt) > 0.85 - d * 0.65:
				continue
			var top := 1 + int(VoxelGrid.hash01(x, 1, z, salt) * 2.6 * (1.0 - d))
			for y in top:
				var v := Vector3i(x, y, z)
				var c: Color = cols[
					int(VoxelGrid.hash01(x, y, z, salt + 7) * cols.size()) % cols.size()
				]
				g.put(v, ArenaPalette.jit(c, v, 0.05, salt), vm, ArenaVoxels.BODY)
	return g


## Short camera shake of `amount` m for `secs` s (h_offset of the current camera).
static func shake(parent: Node, amount: float, secs := 0.3) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var cam := parent.get_viewport().get_camera_3d()
	if cam == null:
		return
	var s := ArenaDebris.new()
	s.name = "Shake"
	s.arena = parent
	s._cam = cam
	s._shake = amount
	s._shake_t = secs
	s._shake_total = maxf(secs, 0.01)
	parent.add_child(s)


func _time_scale() -> float:
	if is_instance_valid(arena) and arena.has_method("cine_scale"):
		return float(arena.cine_scale())
	return 1.0


func _floor(p: Vector3) -> float:
	if floor_at.is_valid():
		return float(floor_at.call(p))
	return 0.0


func _process(delta: float) -> void:
	_t += delta
	if _shake_t > 0.0:
		_shake_t -= delta
		if is_instance_valid(_cam):
			var k := clampf(_shake_t / _shake_total, 0.0, 1.0)
			_cam.h_offset = (
				0.0
				if _shake_t <= 0.0
				else _shake * k * (sin(_t * SHAKE_HZ * TAU) * 0.7 + sin(_t * SHAKE_HZ * 4.3) * 0.3)
			)
	var dt := delta * _time_scale()
	var alive := false
	for c in chunks:
		var mi: MeshInstance3D = c.node
		if not is_instance_valid(mi) or not mi.visible:
			continue
		c.life = float(c.life) - dt
		if float(c.life) <= 0.0:
			mi.visible = false
			continue
		alive = true
		var v: Vector3 = c.vel
		if c.leaf:
			v.y = maxf(v.y - GRAVITY * 0.4 * dt, -LEAF_FALL)
			v.x -= v.x * LEAF_DRAG * dt
			v.z -= v.z * LEAF_DRAG * dt
			mi.position.x += sin(_t * 5.0 + float(c.ph)) * 0.5 * dt
		else:
			v.y -= GRAVITY * dt
		mi.position += v * dt
		var fl := _floor(mi.position) + float(c.half)
		if mi.position.y < fl:
			mi.position.y = fl
			if v.y < 0.0:
				v.y = -v.y * (0.0 if c.leaf else BOUNCE)
				v.x *= SLIDE
				v.z *= SLIDE
				c.spin = c.spin * SLIDE
				if v.y < REST_V:
					v.y = 0.0
					c.spin = c.spin * 0.3
		c.vel = v
		mi.rotation += c.spin * dt
		if float(c.life) < FADE:
			mi.scale = c.base * maxf(float(c.life) / FADE, 0.01)
	if not alive and _shake_t <= 0.0:
		if is_instance_valid(_cam):
			_cam.h_offset = 0.0
		queue_free()

class_name VoxelBuild
extends RefCounted
## Buildings of a voxel zone (VoxelZoneGen): houses, the lab and garden sheds, built inside their
## footprint (the design's footprint letter). Walls are two voxels thick and stand inside the
## footprint, the interior is hollow with a plank floor, so a later "enter in place" mode only has
## to hide parts: every building gets its own `walls`, `roof` and (two storeys) `slab` part, listed
## in the zone metadata with the footprint rect and height (camera fader, future interiors).
## Door: the 'd' tile on the south facade, a 1 m x 2.25 m opening with the leaf set one voxel back.

const STOREY := 11  ## voxels per storey: 2.75 m (10 of room + the slab or wall plate)
const OVERHANG := 2  ## eaves / verges past the footprint (voxels)
const DOOR_H := 9  ## door opening height (2.25 m)
const WIN_W := 7  ## frame + 2 panes + mullion + 2 panes + frame
const LAB_WALL := 14  ## 3.5 m

static var _salt := 0


static func buildings(gen: VoxelZoneGen) -> void:
	for b in gen.d.buildings:
		var r := gen.d.building_rect(String(b.char))
		if r.size == Vector2i.ZERO:
			continue
		_salt = hash(String(b.get("id", "")))
		match String(b.get("style", "house")):
			"lab":
				_lab(gen, b, r)
			"shed":
				_shed(gen, b, r)
			_:
				_house(gen, b, r)


## Voxel box of a footprint: [x0, z0, x1, z1] inclusive.
static func _box(r: Rect2i) -> Array:
	return [
		VoxelZoneGen.v0(r.position.x),
		VoxelZoneGen.v0(r.position.y),
		VoxelZoneGen.v0(r.end.x) - 1,
		VoxelZoneGen.v0(r.end.y) - 1
	]


static func _rect_m(r: Rect2i) -> Rect2:
	return Rect2(Vector2(r.position) - Vector2(0.5, 0.5), Vector2(r.size))


## The building's meta entry (parts get filled in by the builders).
static func _entry(gen: VoxelZoneGen, b: Dictionary, r: Rect2i) -> Dictionary:
	var doors := gen.d.doors_of(r)
	var e := {
		"id": String(b.get("id", "")),
		"char": String(b.char),
		"style": String(b.get("style", "house")),
		"tiles": r,
		"rect": _rect_m(r),
		"map": bool(b.get("map", false)),
		"storeys": int(b.get("storeys", 1)),
		"floor_y": 0.0,
		"parts": {},
	}
	if not doors.is_empty():
		e["door"] = doors[0]
	gen.meta.buildings.append(e)
	return e


static func _part(gen: VoxelZoneGen, e: Dictionary, kind: String) -> int:
	var p := gen.new_part({"kind": kind, "building": e.id, "rect": e.rect, "height": 6.0})
	e.parts[kind] = p
	return p


# --- colours -------------------------------------------------------------------------------------


## Stone courses: one voxel high, blocks 2-4 voxels long, offset per course.
static func stone(u: int, y: int, base := VoxelPal.STONE_WALL, salt := 0) -> Color:
	var off := (y * 5 + salt) % 4
	var blk := floori((u + off) / 3.0)
	var h := VoxelGrid.hash01(blk, y, salt, 31)
	var c := base
	if h < 0.22:
		c = base.darkened(0.16)
	elif h > 0.82:
		c = base.lightened(0.12)
	elif h > 0.7:
		c = base.lerp(Color("b0a089"), 0.35)
	return VoxelPal.vary(c, VoxelGrid.hash01(blk, y, salt, 32), 0.05)


static func plaster(x: int, y: int, z: int, base: Color) -> Color:
	var n := VoxelGrid.hash01(x >> 1, y >> 1, z >> 1, 33)
	return VoxelPal.vary(base, n * 0.6 + VoxelGrid.hash01(x, y, z, 34) * 0.4, 0.035)


static func planks(u: int, y: int, base: Color, salt := 0) -> Color:
	var blk := floori((u + (y * 3) % 5) / 6.0)
	return VoxelPal.vary(base, VoxelGrid.hash01(blk, y, salt, 35), 0.08)


static func roof_tile(u: int, e: int, base: Color, salt := 0) -> Color:
	var c := base if e % 2 == 0 else base.lightened(0.07)
	var blk := floori((u + (e % 2)) / 2.0)
	return VoxelPal.vary(c, VoxelGrid.hash01(blk, e, salt, 36), 0.07)


# --- shell ---------------------------------------------------------------------------------------


## Building context: voxel box, wall height, parts, palette.
class Ctx:
	var x0 := 0
	var z0 := 0
	var x1 := 0
	var z1 := 0
	var wall_h := 11
	var walls := 0
	var roof := 0
	var slab := 0
	var stone_h := 0  ## walls below this voxel y are stone, above plaster
	var wall_c := VoxelPal.PLASTER
	var stone_c := VoxelPal.STONE_WALL
	var trim := VoxelPal.WINDOW_FRAME
	var timber := VoxelPal.TIMBER
	var door := Vector2i(-99999, 0)
	var door_c := Color("4a6f8f")
	var shutter := Color(0, 0, 0, 0)
	var window_y: Array = []  ## [glass y0, glass y1] per storey
	var flower_boxes := false
	var timber_frame := false
	var b: Dictionary = {}

	func ring(x: int, z: int) -> bool:
		return x <= x0 + 1 or x >= x1 - 1 or z <= z0 + 1 or z >= z1 - 1

	func outer(x: int, z: int) -> bool:
		return x == x0 or x == x1 or z == z0 or z == z1

	func corner(x: int, z: int) -> bool:
		return (x <= x0 + 1 or x >= x1 - 1) and (z <= z0 + 1 or z >= z1 - 1)


static func _ctx(gen: VoxelZoneGen, b: Dictionary, r: Rect2i, e: Dictionary) -> Ctx:
	var c := Ctx.new()
	var bx := _box(r)
	c.x0 = bx[0]
	c.z0 = bx[1]
	c.x1 = bx[2]
	c.z1 = bx[3]
	c.b = b
	c.wall_c = VoxelPal.hex(String(b.get("wall_color", "")), VoxelPal.PLASTER)
	c.stone_c = VoxelPal.hex(String(b.get("stone_color", "")), VoxelPal.STONE_WALL)
	c.trim = VoxelPal.hex(String(b.get("trim", "")), VoxelPal.WINDOW_FRAME)
	c.door_c = VoxelPal.hex(String(b.get("door_color", "")), c.door_c)
	c.shutter = VoxelPal.hex(String(b.get("shutter", "")), Color(0, 0, 0, 0))
	c.flower_boxes = bool(b.get("flower_boxes", false))
	c.timber_frame = bool(b.get("timber_frame", false))
	if e.has("door"):
		c.door = e.door
	c.walls = _part(gen, e, "walls")
	c.roof = _part(gen, e, "roof")
	return c


## Plank floor inside the walls (replaces the ground's top voxel).
static func _floor(gen: VoxelZoneGen, c: Ctx, col := VoxelPal.FLOOR) -> void:
	for z in range(c.z0, c.z1 + 1):
		for x in range(c.x0, c.x1 + 1):
			var v := Vector3i(x, -1, z)
			if c.ring(x, z):
				gen.g.put(v, stone(x + z, -1, VoxelPal.STONE_WALL_DARK, _salt), VoxelMat.STONE)
			else:
				gen.g.put(v, planks(x, z, col, _salt), VoxelMat.WOOD)


## Colour + material of a wall voxel.
static func _wall_voxel(c: Ctx, x: int, y: int, z: int) -> Array:
	var u := x if (z <= c.z0 + 1 or z >= c.z1 - 1) else z
	if c.corner(x, z) and y >= c.stone_h:
		if c.timber_frame:
			return [VoxelPal.vary(c.timber, VoxelGrid.hash01(x, y, z, 37), 0.05), VoxelMat.WOOD]
		# Quoins: alternating long / short light blocks.
		var q := c.stone_c.lightened(0.1)
		return [stone(u + (y % 2) * 2, y, q, _salt), VoxelMat.STONE]
	if y < 2:
		return [stone(u, y, c.stone_c.darkened(0.12), _salt), VoxelMat.STONE]
	if y < c.stone_h:
		return [stone(u, y, c.stone_c, _salt), VoxelMat.STONE]
	if c.timber_frame:
		var rel := (y - c.stone_h) % STOREY
		if rel == 0 or y == c.wall_h - 1 or (y % STOREY) == STOREY - 1:
			return [VoxelPal.vary(c.timber, VoxelGrid.hash01(x, y, z, 38), 0.05), VoxelMat.WOOD]
		# Studs every 2 m between the windows.
		if posmod(u - (c.x0 if u == x else c.z0), 8) == 0:
			return [VoxelPal.vary(c.timber, VoxelGrid.hash01(x, y, z, 39), 0.05), VoxelMat.WOOD]
	return [plaster(x, y, z, c.wall_c), VoxelMat.PLASTER]


## Walls (two voxels thick) from y 0 to wall_h - 1.
static func _walls(gen: VoxelZoneGen, c: Ctx) -> void:
	for y in range(0, c.wall_h):
		for z in range(c.z0, c.z1 + 1):
			for x in range(c.x0, c.x1 + 1):
				if not c.ring(x, z):
					continue
				var w := _wall_voxel(c, x, y, z)
				gen.g.put(Vector3i(x, y, z), w[0], w[1], c.walls)


## Upper floor slab (its own part) at the top of storey 1.
static func _slab(gen: VoxelZoneGen, c: Ctx, e: Dictionary) -> void:
	c.slab = _part(gen, e, "slab")
	var y := STOREY - 1
	for z in range(c.z0 + 2, c.z1 - 1):
		for x in range(c.x0 + 2, c.x1 - 1):
			gen.g.put(
				Vector3i(x, y, z), planks(x, z, VoxelPal.FLOOR, _salt + 1), VoxelMat.WOOD, c.slab
			)


## Window openings along one facade. side: "s", "n", "w", "e". Spans avoid the corners and door.
static func _facade_windows(gen: VoxelZoneGen, c: Ctx, side: String) -> void:
	var along_x := side == "s" or side == "n"
	var lo := (c.x0 if along_x else c.z0) + 3
	var hi := (c.x1 if along_x else c.z1) - 3
	var gaps: Array = []
	if side == "s" and c.door.x > -99999:
		var dv := VoxelZoneGen.v0(c.door.x)
		gaps.append([dv - 3, dv + 6])
	var segs: Array = [[lo, hi]]
	for gp in gaps:
		var nxt: Array = []
		for s in segs:
			if gp[1] < s[0] or gp[0] > s[1]:
				nxt.append(s)
				continue
			if gp[0] - 1 >= s[0]:
				nxt.append([s[0], gp[0] - 1])
			if gp[1] + 1 <= s[1]:
				nxt.append([gp[1] + 1, s[1]])
		segs = nxt
	for s in segs:
		var length: int = s[1] - s[0] + 1
		var n := floori((length + 4) / float(WIN_W + 4))
		if n <= 0:
			continue
		var used := n * WIN_W + (n - 1) * 4
		var start: int = s[0] + floori((length - used) / 2.0)
		for i in n:
			var u0 := start + i * (WIN_W + 4)
			for st in c.window_y.size():
				_window(gen, c, side, u0, c.window_y[st][0], c.window_y[st][1], st == 0)


## One window: trim frame in the outer layer, glass one voxel in, sill, shutters, flower box.
static func _window(
	gen: VoxelZoneGen, c: Ctx, side: String, u0: int, gy0: int, gy1: int, ground: bool
) -> void:
	var u1 := u0 + WIN_W - 1
	var mid := u0 + (WIN_W >> 1)
	for y in range(gy0 - 1, gy1 + 2):
		for u in range(u0, u1 + 1):
			var edge := u == u0 or u == u1 or y == gy0 - 1 or y == gy1 + 1
			var o := _wall_cell(c, side, u, 0)
			var i := _wall_cell(c, side, u, 1)
			if edge:
				_set_y(
					gen,
					o,
					y,
					VoxelPal.vary(c.trim, VoxelGrid.hash01(o.x, y, o.z, 40), 0.03),
					VoxelMat.WOOD,
					c.walls
				)
				_set_y(
					gen,
					i,
					y,
					VoxelPal.vary(c.trim, VoxelGrid.hash01(i.x, y, i.z, 41), 0.03),
					VoxelMat.WOOD,
					c.walls
				)
				continue
			_set_y(gen, o, y, Color.BLACK, 0, 0)
			if u == mid or y == gy0 + ((gy1 - gy0) >> 1) + 1 and (gy1 - gy0) >= 5:
				_set_y(gen, i, y, c.trim, VoxelMat.WOOD, c.walls)
			else:
				var gc := VoxelPal.vary(VoxelPal.WINDOW, VoxelGrid.hash01(u, y, 0, 42), 0.04)
				_set_y(gen, i, y, gc, VoxelMat.WINDOW, c.walls)
	# Sill: stone, one voxel proud of the facade.
	for u in range(u0 - 1, u1 + 2):
		var s := _wall_cell(c, side, u, -1)
		_set_y(
			gen,
			s,
			gy0 - 1,
			stone(u, gy0 - 1, c.stone_c.lightened(0.08), _salt),
			VoxelMat.STONE,
			c.walls
		)
	if c.shutter.a > 0.0:
		for y in range(gy0 - 1, gy1 + 2):
			for k in 2:
				var a := _wall_cell(c, side, u0 - 1 - k, 0)
				var bb := _wall_cell(c, side, u1 + 1 + k, 0)
				var sc := VoxelPal.vary(c.shutter, VoxelGrid.hash01(u0, y, k, 43), 0.05)
				if y % 3 == 1:
					sc = sc.darkened(0.15)
				_set_y(gen, a, y, sc, VoxelMat.WOOD, c.walls)
				_set_y(gen, bb, y, sc, VoxelMat.WOOD, c.walls)
	if ground and c.flower_boxes and side == "s":
		for u in range(u0, u1 + 1):
			var fb := _wall_cell(c, side, u, -1)
			for y in [gy0 - 3, gy0 - 2]:
				_set_y(gen, fb, y, planks(u, y, VoxelPal.WOOD_DARK, _salt), VoxelMat.WOOD, c.walls)
		var fbm := _wall_cell(c, side, u0, -1)
		var p0 := (
			VoxelGrid.centre(Vector3i(fbm.x, gy0 - 2, fbm.z)) + Vector3(0, VoxelGrid.VS * 0.5, 0)
		)
		var dir := Vector3(1, 0, 0) if side == "s" or side == "n" else Vector3(0, 0, 1)
		for k in range(1, WIN_W - 1):
			var p := p0 + dir * (k * VoxelGrid.VS)
			var kinds := ["flower_red", "flower_yellow", "flower_white", "flower_pink"]
			var pick: String = kinds[int(VoxelGrid.hash01(u0 + k, gy0, 3, 44) * kinds.size())]
			gen.add_decor(
				pick, Transform3D(Basis(Vector3.UP, VoxelGrid.hash01(u0, k, 1, 45) * TAU), p)
			)


## Cell of the wall at facade coordinate u; layer 0 = outer, 1 = inner, -1 = one voxel outside.
static func _wall_cell(c: Ctx, side: String, u: int, layer: int) -> Vector3i:
	match side:
		"s":
			return Vector3i(u, 0, c.z1 - layer)
		"n":
			return Vector3i(u, 0, c.z0 + layer)
		"w":
			return Vector3i(c.x0 + layer, 0, u)
	return Vector3i(c.x1 - layer, 0, u)


static func _set_y(gen: VoxelZoneGen, v: Vector3i, y: int, col: Color, m: int, prt: int) -> void:
	gen.g.put(Vector3i(v.x, y, v.z), col, m, prt)


## Door on the south facade: opening, recessed leaf with a small window, jambs, lintel, step,
## canopy and a wall lantern.
static func _door(gen: VoxelZoneGen, c: Ctx, canopy := true, lantern := true) -> void:
	if c.door.x <= -99999:
		return
	var dx := VoxelZoneGen.v0(c.door.x)
	var z := c.z1
	for y in range(0, DOOR_H):
		for x in range(dx, dx + 4):
			gen.g.put(Vector3i(x, y, z), Color.BLACK, 0)
			var leaf := c.door_c
			if x == dx or x == dx + 3 or y == DOOR_H - 1:
				leaf = c.door_c.darkened(0.25)
			elif (y == 3 or y == 6) and (x == dx + 1 or x == dx + 2):
				leaf = c.door_c.darkened(0.12)
			var m := VoxelMat.WOOD
			if y >= 6 and y <= 7 and (x == dx + 1 or x == dx + 2):
				leaf = VoxelPal.WINDOW
				m = VoxelMat.WINDOW
			gen.g.put(
				Vector3i(x, y, z - 1),
				VoxelPal.vary(leaf, VoxelGrid.hash01(x, y, z, 46), 0.03),
				m,
				c.walls
			)
	for y in range(0, DOOR_H + 1):
		for x in [dx - 1, dx + 4]:
			gen.g.put(
				Vector3i(x, y, z),
				stone(y, y, c.stone_c.lightened(0.12), _salt + 5),
				VoxelMat.STONE,
				c.walls
			)
	for x in range(dx - 1, dx + 5):
		gen.g.put(
			Vector3i(x, DOOR_H, z),
			VoxelPal.vary(c.timber, VoxelGrid.hash01(x, 9, z, 47), 0.05),
			VoxelMat.WOOD,
			c.walls
		)
	# Threshold: a worn stone slab flush with the ground in front of the door.
	for x in range(dx, dx + 4):
		gen.g.put(Vector3i(x, -1, z), stone(x, 0, VoxelPal.SLAB_DARK, _salt + 6), VoxelMat.SLAB)
		gen.g.put(Vector3i(x, -1, z + 1), stone(x, 1, VoxelPal.SLAB, _salt + 6), VoxelMat.SLAB)
	if canopy:
		var cy := DOOR_H + 1
		for x in range(dx - 2, dx + 6):
			for k in 2:
				var rc := roof_tile(
					x, k, VoxelPal.hex(String(c.b.get("roof_color", "")), VoxelPal.ROOF), _salt
				)
				gen.g.put(Vector3i(x, cy + 1 - k, z + 1 + k), rc, VoxelMat.ROOF, c.walls)
		for x in [dx - 2, dx + 5]:
			gen.g.put(Vector3i(x, cy - 1, z + 1), VoxelPal.WOOD_DARK, VoxelMat.WOOD, c.walls)
	if lantern:
		var lx := dx + 6
		var ly := DOOR_H - 1
		gen.g.put(Vector3i(lx, ly + 1, z + 1), VoxelPal.METAL, VoxelMat.METAL, c.walls)
		gen.g.put(Vector3i(lx, ly, z + 1), VoxelPal.LAMP, VoxelMat.LAMP, c.walls)
		gen.g.put(Vector3i(lx, ly - 1, z + 1), VoxelPal.METAL, VoxelMat.METAL, c.walls)
		gen.add_light(
			VoxelGrid.centre(Vector3i(lx, ly, z + 2)), "wall", Color(1.0, 0.76, 0.48), 2.2, 6.5
		)


## Gable roof. Ridge along x when `along_x`, rising one voxel every `run` voxels from the eaves.
## Gable walls fill the triangles at the ends; returns the ridge top y (voxels).
static func _gable(
	gen: VoxelZoneGen, c: Ctx, along_x: bool, run := 2, base := VoxelPal.ROOF
) -> int:
	var yb := c.wall_h
	var a0 := (c.z0 if along_x else c.x0) - OVERHANG  # across the slope
	var a1 := (c.z1 if along_x else c.x1) + OVERHANG
	var l0 := (c.x0 if along_x else c.z0) - OVERHANG  # along the ridge
	var l1 := (c.x1 if along_x else c.z1) + OVERHANG
	var emax := floori((a1 - a0) / 2.0)
	var top := yb
	for a in range(a0, a1 + 1):
		var e := mini(a - a0, a1 - a)
		var ys := yb - 1 + floori(e / float(run))
		top = maxi(top, ys + 1)
		var ridge := e >= emax - (1 if (a1 - a0) % 2 == 1 else 0)
		for l in range(l0, l1 + 1):
			var verge := l == l0 or l == l1
			for y in [ys - 1, ys]:
				var v := Vector3i(l, y, a) if along_x else Vector3i(a, y, l)
				var col := roof_tile(l, e, base, _salt)
				if e == 0 or verge:
					col = base.darkened(0.22)
				if y == ys - 1 and not verge:
					col = col.darkened(0.12)
				gen.g.put(v, col, VoxelMat.ROOF, c.roof)
			if ridge:
				var rv := Vector3i(l, ys + 1, a) if along_x else Vector3i(a, ys + 1, l)
				gen.g.put(
					rv,
					VoxelPal.vary(base.darkened(0.3), VoxelGrid.hash01(l, 0, a, 48), 0.04),
					VoxelMat.ROOF,
					c.roof
				)
	# Gable end walls (the triangle between the wall top and the roof underside).
	var ends := [l0 + OVERHANG, l0 + OVERHANG + 1, l1 - OVERHANG - 1, l1 - OVERHANG]
	var acx := (a0 + a1) / 2.0
	for a in range(a0 + OVERHANG, a1 - OVERHANG + 1):
		var e := mini(a - a0, a1 - a)
		var ys := yb - 1 + floori(e / float(run))
		for l in ends:
			for y in range(yb, ys - 1):
				var v := Vector3i(l, y, a) if along_x else Vector3i(a, y, l)
				var w := _wall_voxel(c, v.x, y, v.z)
				var col: Color = w[0]
				var m: int = w[1]
				# A small attic window in the middle of the gable.
				if absf(a + 0.5 - acx) < 1.6 and y >= yb + 2 and y <= yb + 4:
					col = VoxelPal.WINDOW if l == ends[0] or l == ends[3] else c.trim
					m = VoxelMat.WINDOW if l == ends[0] or l == ends[3] else VoxelMat.WOOD
				elif absf(a + 0.5 - acx) < 2.6 and y >= yb + 1 and y <= yb + 5:
					col = c.trim
					m = VoxelMat.WOOD
				gen.g.put(v, col, m, c.walls)
	return top


static func _chimney(gen: VoxelZoneGen, c: Ctx, x: int, z: int, top: int) -> void:
	for y in range(c.wall_h - 2, top + 3):
		for dz in 3:
			for dx in 3:
				var v := Vector3i(x + dx, y, z + dz)
				var col := stone(x + dx + z + dz, y, VoxelPal.STONE_WALL_DARK, _salt + 9)
				if y >= top + 2:
					col = VoxelPal.ROCK_DARK.darkened(0.3)
					if dx == 1 and dz == 1:
						gen.g.put(v, Color.BLACK, 0)
						continue
				gen.g.put(v, col, VoxelMat.STONE, c.roof)
	gen.meta.get_or_add("smoke", []).append(VoxelGrid.centre(Vector3i(x + 1, top + 3, z + 1)))


# --- styles --------------------------------------------------------------------------------------


static func _finish(gen: VoxelZoneGen, e: Dictionary, top_y: int) -> void:
	var h := (top_y + 1) * VoxelGrid.VS
	e["height"] = h
	for k in e.parts:
		gen.meta.parts[e.parts[k]]["height"] = h
	for t in _tiles(e.tiles):
		gen.block(t)


static func _tiles(r: Rect2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for z in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			out.append(Vector2i(x, z))
	return out


## Stone cottage: stone ground storey, plaster (optionally timber-framed) upper storey, gable roof
## with a chimney, door canopy, wall lantern, flower boxes, shutters.
static func _house(gen: VoxelZoneGen, b: Dictionary, r: Rect2i) -> void:
	var e := _entry(gen, b, r)
	var c := _ctx(gen, b, r, e)
	var storeys := int(b.get("storeys", 1))
	c.wall_h = STOREY * storeys
	c.stone_h = int(b.get("stone_h", STOREY if storeys > 1 else 2))
	for s in storeys:
		c.window_y.append([4 + s * STOREY, 7 + s * STOREY])
	_floor(gen, c)
	_walls(gen, c)
	if storeys > 1:
		_slab(gen, c, e)
	for side in ["s", "n", "w", "e"]:
		_facade_windows(gen, c, side)
	_door(gen, c)
	var roof_c := VoxelPal.hex(String(b.get("roof_color", "")), VoxelPal.ROOF)
	var top := _gable(gen, c, c.x1 - c.x0 >= c.z1 - c.z0, 2, roof_c)
	if b.has("chimney"):
		var ch: Array = b.chimney  # [tile dx from the footprint's west edge, "n" | "s"]
		var cx := c.x0 + int(ch[0]) * 4
		var cz := c.z0 + 4 if String(ch[1]) == "n" else c.z1 - 6
		_chimney(gen, c, cx, cz, top)
	if e.has("door"):
		gen.no_npc[e.door + Vector2i(0, 1)] = true
	_finish(gen, e, top + (4 if b.has("chimney") else 1))


## The lab: light plaster over a stone base, tall windows, a south gable over the entrance, slate
## roof with solar panels and an antenna whose tip blinks at night.
static func _lab(gen: VoxelZoneGen, b: Dictionary, r: Rect2i) -> void:
	var e := _entry(gen, b, r)
	var c := _ctx(gen, b, r, e)
	c.wall_h = LAB_WALL
	c.stone_h = 3
	c.window_y = [[3, 10]]
	_floor(gen, c, Color("b9b4a8"))
	_walls(gen, c)
	for side in ["s", "n", "w", "e"]:
		_facade_windows(gen, c, side)
	_door(gen, c, true, false)
	# Sidelights: tall glass either side of the door.
	if c.door.x > -99999:
		var dx := VoxelZoneGen.v0(c.door.x)
		for x in [dx - 3, dx - 2, dx + 5, dx + 6]:
			for y in range(1, DOOR_H):
				var edge: bool = x == dx - 3 or x == dx + 6 or y == 1 or y == DOOR_H - 1
				gen.g.put(
					Vector3i(x, y, c.z1),
					c.trim if edge else Color.BLACK,
					VoxelMat.WOOD if edge else 0,
					c.walls
				)
				if not edge:
					gen.g.put(Vector3i(x, y, c.z1 - 1), VoxelPal.WINDOW, VoxelMat.WINDOW, c.walls)
		for x in [dx - 4, dx + 7]:
			gen.add_light(
				VoxelGrid.centre(Vector3i(x, DOOR_H - 1, c.z1 + 2)),
				"wall",
				Color(0.9, 0.92, 1.0),
				2.4,
				7.0
			)
			gen.g.put(
				Vector3i(x, DOOR_H - 1, c.z1 + 1),
				VoxelPal.LAMP.lightened(0.3),
				VoxelMat.LAMP,
				c.walls
			)
			gen.g.put(Vector3i(x, DOOR_H, c.z1 + 1), VoxelPal.METAL, VoxelMat.METAL, c.walls)
	var roof_c := VoxelPal.hex(String(b.get("roof_color", "")), Color("5b6878"))
	var top := _gable(gen, c, false, 3, roof_c)
	# Solar panels on the east slope (dark blue glass in metal frames).
	var px0 := c.x1 - 12
	var pz0 := c.z0 + 6
	for z in range(pz0, pz0 + 16):
		for x in range(px0, px0 + 8):
			var ty := gen.g.top_y(x, z)
			if ty < c.wall_h:
				continue
			var frame := (z - pz0) % 4 == 0 or x == px0 or x == px0 + 7
			gen.g.put(
				Vector3i(x, ty + 1, z),
				VoxelPal.METAL if frame else Color("27406b"),
				VoxelMat.METAL if frame else VoxelMat.GLASS,
				c.roof
			)
	# Antenna mast near the ridge.
	var ax := (c.x0 + c.x1) / 2 + 3
	var az := c.z0 + 6
	var ay := gen.g.top_y(ax, az)
	for y in range(ay + 1, ay + 14):
		gen.g.put(Vector3i(ax, y, az), VoxelPal.METAL, VoxelMat.METAL, c.roof)
	for k in [-2, -1, 1, 2]:
		gen.g.put(Vector3i(ax + k, ay + 10, az), VoxelPal.METAL, VoxelMat.METAL, c.roof)
		gen.g.put(Vector3i(ax, ay + 7, az + k), VoxelPal.METAL, VoxelMat.METAL, c.roof)
	gen.g.put(Vector3i(ax, ay + 14, az), Color("ff4030"), VoxelMat.LAMP, c.roof)
	gen.meta.get_or_add("beacons", []).append(VoxelGrid.centre(Vector3i(ax, ay + 14, az)))
	if e.has("door"):
		gen.no_npc[e.door + Vector2i(0, 1)] = true
	_finish(gen, e, maxi(top, ay + 14))


## Garden shed: vertical planks, a lean-to roof (high side south), a painted (closed) door.
static func _shed(gen: VoxelZoneGen, b: Dictionary, r: Rect2i) -> void:
	var e := _entry(gen, b, r)
	var c := _ctx(gen, b, r, e)
	c.wall_h = 9
	var wood := VoxelPal.hex(String(b.get("wall_color", "")), VoxelPal.WOOD)
	for y in range(0, c.wall_h + 3):
		for z in range(c.z0, c.z1 + 1):
			for x in range(c.x0, c.x1 + 1):
				if not c.ring(x, z):
					continue
				var hy := c.wall_h + floori((z - c.z0) / float(maxi(c.z1 - c.z0, 1)) * 3.0)
				if y >= hy:
					continue
				var u := x if (z <= c.z0 + 1 or z >= c.z1 - 1) else z
				var col := VoxelPal.vary(wood, VoxelGrid.hash01(u, 0, 7, 49), 0.1)
				if c.corner(x, z):
					col = VoxelPal.WOOD_DARK
				gen.g.put(Vector3i(x, y, z), col, VoxelMat.WOOD, c.walls)
	if c.door.x > -99999:
		var dx := VoxelZoneGen.v0(c.door.x)
		for y in range(0, 8):
			for x in range(dx, dx + 4):
				var dc := c.door_c if (x + y) % 4 != 0 else c.door_c.darkened(0.2)
				gen.g.put(
					Vector3i(x, y, c.z1),
					VoxelPal.vary(dc, VoxelGrid.hash01(x, y, 1, 50), 0.04),
					VoxelMat.WOOD,
					c.walls
				)
	# Lean-to roof, overhanging one voxel.
	var roof_c := VoxelPal.hex(String(b.get("roof_color", "")), VoxelPal.ROOF_DARK)
	var top := 0
	for z in range(c.z0 - 1, c.z1 + 2):
		var ys := (
			c.wall_h + floori((clampi(z, c.z0, c.z1) - c.z0) / float(maxi(c.z1 - c.z0, 1)) * 3.0)
		)
		top = maxi(top, ys)
		for x in range(c.x0 - 1, c.x1 + 2):
			gen.g.put(
				Vector3i(x, ys, z), roof_tile(x, z - c.z0, roof_c, _salt), VoxelMat.ROOF, c.roof
			)
	# A tool rack / water butt by the shed.
	_finish(gen, e, top + 1)

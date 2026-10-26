class_name StadiumParts
extends RefCounted
## Voxel parts of the training stadium (ArenaStadium, docs/VOXEL.md §7), all on the 0.25 m lattice
## and meshed with VoxelMesher.greedy / voxel.gdshader through ArenaVoxels.model:
## - bank(): a straight section of stand. Local frame: x along the stand, z away from the field (the
##   front wall is at z = 0), y up. A padded front wall (the perimeter boards go on it), ROWS rows
##   of seats rising RISE_V per row, aisle stairs with yellow nosing, a vomitory, the top walkway,
##   the parapet with its orange tile cap and the stone facade outside (pilasters, windows that
##   glow at night, banners, gates).
## - corner(): the same profile around a corner (the rows are the rings of the Chebyshev distance
##   from the inner corner, with a diagonal aisle), so the four sides close into one bowl.
## - The players' tunnel (bank with `tunnel`), the floodlight mast and lamp head, the scoreboard
##   frame and the Poke Ball emblem.
## seats() lists where the crowd sits (local position + facing) for every section, from the same
## profile. Looks come from position hashes only; nothing here touches the battle.

const VS := VoxelGrid.VS
const CTX := ArenaVoxels.CTX
const BODY := ArenaVoxels.BODY
const TOP := ArenaVoxels.TOP

## Stand profile (voxels): podium (front wall), ROWS rows of ROW_V deep rising RISE_V each, top
## walkway, parapet. The row 0 tread is T0_V; the podium stands 0.5 m above it.
const ROWS := 12
const ROW_V := 4
const RISE_V := 2
const T0_V := 4
const FRONT_V := 2
const PODIUM_V := 6
const WALK_V := 6
const PARA_V := 2
const PARA_H_V := 5
const DEPTH_V := FRONT_V + ROWS * ROW_V + WALK_V + PARA_V
const TOP_V := T0_V + ROWS * RISE_V
## Section depth and height in metres (the parapet cap included).
const DEPTH := DEPTH_V * VS
const HEIGHT := (TOP_V + PARA_H_V) * VS
## Rows of the lower tier (blue seats); the rest are the upper tier (red seats).
const LOW_ROWS := 6
## Aisle width (voxels) at the start of a section and the vomitory (rows and width).
const AISLE_V := 4
const VOMIT_ROWS := Vector2i(4, 7)
const VOMIT_V := 6
## Players' tunnel: width, height (voxels), depth into the stand (voxels) and the canopy over it.
const TUNNEL_W := 12
const TUNNEL_H := 9
const TUNNEL_D := 28
const CANOPY_W := 16
const CANOPY_ROWS := 4

const C_CONC := Color("bcb5a8")
const C_RISER := Color("9e978b")
const C_UNDER := Color("8a8478")
const C_NOSE := Color("e8cf5e")
const C_PODIUM := Color("26324a")
const C_CAP := Color("eeeae0")
const C_STONE := [Color("a59c8c"), Color("978e7f"), Color("b1a796"), Color("9c9282")]
const C_PILASTER := Color("c6bca9")
const C_PLINTH := Color("7d7568")
const C_ROOF := Color("d8693a")
const C_ROOF_DARK := Color("b5532b")
const C_WINDOW := Color("f2c66c")
const C_GLASS := Color("3b4858")
const C_GATE := Color("2c2723")
const C_METAL := Color("6f7a86")
const C_METAL_DARK := Color("4b545e")
const C_TUNNEL := Color("2b2a2e")
const C_MAT := Color("3a3f48")
const SEAT_LOW := [Color("2f5fb8"), Color("3a6dcc")]
const SEAT_HIGH := [Color("cf4f39"), Color("c1442f")]
## Team colours: side 0 (Time A, -x end) red, side 1 (Time B, +x end) blue.
const TEAM := [Color("d8423a"), Color("2f6fd8")]
const TEAM_DARK := [Color("9e2a25"), Color("1f4f9e")]

# --- Profile ---


## Profile at depth voxel k: (kind, row, sub). kind 0 podium, 1 seat row, 2 top walkway,
## 3 parapet; sub is the voxel inside the row (0 = riser front .. 3 = backrest).
static func prof(k: int) -> Vector3i:
	if k < FRONT_V:
		return Vector3i(0, 0, k)
	k -= FRONT_V
	if k < ROWS * ROW_V:
		return Vector3i(1, k / ROW_V, k % ROW_V)
	k -= ROWS * ROW_V
	if k < WALK_V:
		return Vector3i(2, ROWS, k)
	return Vector3i(3, ROWS, k - WALK_V)


## Tread top (voxel count from y = 0) of row `i`.
static func tread(i: int) -> int:
	return T0_V + i * RISE_V


## Local position of the seat pan top of row `i` at depth (metres from the front face).
static func seat_depth(i: int) -> float:
	return (FRONT_V + i * ROW_V + 2.5) * VS


static func _jit(c: Color, v: Vector3i, amt := 0.04, salt := 0) -> Color:
	return ArenaPalette.jit(c, v, amt, salt)


static func _h(x: int, y: int, z: int, salt := 0) -> float:
	return VoxelGrid.hash01(x, y, z, salt)


## Fills one stand column at local voxel (x, z) whose profile depth is k; `along` indexes the seats,
## `stairs` makes it an aisle step.
static func _column(
	g: VoxelGrid, x: int, z: int, k: int, along: int, stairs: bool, salt: int
) -> void:
	var p := prof(k)
	match p.x:
		0:
			for j in PODIUM_V:
				var v := Vector3i(x, j, z)
				var c := C_PODIUM
				var m := VoxelMat.CLOTH
				if j == 0:
					c = C_PLINTH
					m = VoxelMat.STONE
				elif j == PODIUM_V - 1:
					c = C_CAP
					m = VoxelMat.PLASTER
				g.put(v, _jit(c, v, 0.03, salt), m, BODY)
		1:
			var top := tread(p.y)
			if stairs and p.z >= 2:
				top += 1
			for j in top:
				var v := Vector3i(x, j, z)
				var c := C_UNDER
				var m := VoxelMat.STONE
				if j == top - 1:
					c = C_CONC
					m = VoxelMat.SLAB
					if stairs and (p.z == 0 or p.z == 2):
						c = C_NOSE
						m = VoxelMat.PAINT
				elif j >= top - RISE_V - 1:
					c = C_RISER
				g.put(v, _jit(c, v, 0.035, salt), m, BODY)
			if stairs:
				return
			var tier: Array = SEAT_LOW if p.y < LOW_ROWS else SEAT_HIGH
			var sc: Color = tier[(along >> 1) & 1]
			if p.z == 2:
				var v := Vector3i(x, top, z)
				g.put(v, _jit(sc, v, 0.03, salt), VoxelMat.SEAT, BODY)
			elif p.z == 3:
				for j in range(top, top + 3):
					var v := Vector3i(x, j, z)
					g.put(v, _jit(sc.darkened(0.12), v, 0.03, salt), VoxelMat.SEAT, BODY)
		2:
			for j in TOP_V:
				var v := Vector3i(x, j, z)
				var c := C_CONC if j == TOP_V - 1 else C_UNDER
				g.put(
					v,
					_jit(c, v, 0.035, salt),
					VoxelMat.SLAB if j == TOP_V - 1 else VoxelMat.STONE,
					BODY
				)
		3:
			var top := TOP_V + PARA_H_V
			for j in top:
				var v := Vector3i(x, j, z)
				var c: Color = C_STONE[int(_h(x >> 2, j >> 1, z, salt) * 4.0) % 4]
				var m := VoxelMat.STONE
				if j == top - 1:
					c = C_ROOF if (x + z) % 2 == 0 else C_ROOF_DARK
					m = VoxelMat.ROOF
				elif j < TOP_V:
					c = C_UNDER
				g.put(v, _jit(c, v, 0.04, salt), m, BODY)


## Outer facade on the face at (x, z) looking along `out` (one voxel outside is the overhang
## layer): stone courses, plinth, pilasters, two bands of windows, banners, gates and the orange
## cornice. `a` runs along the facade (pattern), `salt` varies the stones.
static func _facade(g: VoxelGrid, x: int, z: int, out: Vector3i, a: int, salt: int) -> void:
	var top := TOP_V + PARA_H_V
	var pil := posmod(a, 20) < 2
	var bay := posmod(a, 40)
	var banner := bay >= 14 and bay < 20
	var gate := bay >= 30 and bay < 38
	for j in top:
		var v := Vector3i(x, j, z)
		if j == top - 1:
			g.put(v + out, _jit(C_ROOF_DARK, v + out, 0.04, salt), VoxelMat.ROOF, BODY)
			continue
		var course := j >> 1
		var block := (a + (course & 1) * 2) >> 2
		var c: Color = C_STONE[int(_h(block, course, salt, 7) * 4.0) % 4]
		var m := VoxelMat.STONE
		var w := posmod(a, 10)
		var win_row := (j >= 9 and j <= 12) or (j >= 19 and j <= 22)
		if win_row and w >= 3 and w <= 6 and not pil:
			if (j == 9 or j == 19) and (w == 3 or w == 6):
				pass  # rounded sill corners stay stone
			elif _h(a / 10, j / 10, salt, 3) < 0.7:
				c = C_WINDOW
				m = VoxelMat.WINDOW
			else:
				c = C_GLASS
				m = VoxelMat.GLASS
		if gate and j < 9:
			c = C_GATE
			m = VoxelMat.METAL
			if j == 8 or bay == 30 or bay == 37:
				c = C_PILASTER
				m = VoxelMat.STONE
		elif j < 2:
			c = C_PLINTH
		g.put(v, _jit(c, v, 0.04, salt), m, BODY)
		# Overhang layer: pilasters, plinth, cornice, banners.
		var o := v + out
		if j == top - 2:
			g.put(o, _jit(C_PILASTER, o, 0.03, salt), VoxelMat.STONE, BODY)
		elif pil or (j < 2 and not gate):
			g.put(o, _jit(C_PILASTER if pil else C_PLINTH, o, 0.04, salt), VoxelMat.STONE, BODY)
		elif banner and j >= 12 and j <= 29:
			var side := (a / 40) & 1
			var bc: Color = TEAM[side]
			if j == 29 or j == 12:
				bc = C_METAL_DARK
			elif j == 27 or (j >= 18 and j <= 19):
				bc = Color("f4efe4")
			g.put(o, _jit(bc, o, 0.03, salt), VoxelMat.CLOTH, BODY)


# --- Straight section ---


## Straight section of stand `len_v` voxels long. opts: aisle (bool, stairs at x 0..AISLE_V),
## vomit (bool, vomitory in the middle), tunnel (int side 0/1 or -1: players' tunnel in the
## middle with that side's colours), salt (int).
static func bank(len_v: int, opts := {}) -> VoxelGrid:
	var salt := int(opts.get("salt", 0))
	var aisle := bool(opts.get("aisle", true))
	var g := VoxelGrid.new(Vector3i(0, -1, 0), Vector3i(len_v, TOP_V + PARA_H_V + 2, DEPTH_V + 1))
	for x in len_v:
		var stairs := aisle and x < AISLE_V
		for k in DEPTH_V:
			_column(g, x, k, k, x - (AISLE_V if aisle else 0), stairs, salt)
		_facade(g, x, DEPTH_V - 1, Vector3i(0, 0, 1), x, salt)
	if bool(opts.get("vomit", false)):
		_vomitory(g, len_v / 2 - VOMIT_V / 2 + (AISLE_V / 2 if aisle else 0), salt)
	var side := int(opts.get("tunnel", -1))
	if side >= 0:
		_tunnel(g, len_v, side, salt)
	return g


## Vomitory: a pit over rows VOMIT_ROWS (its floor is the first row's tread) starting at x0, white
## rails on its sides and front, and a dark doorway in the riser behind it.
static func _vomitory(g: VoxelGrid, x0: int, salt: int) -> void:
	var floor_v := tread(VOMIT_ROWS.x)
	var k0 := FRONT_V + VOMIT_ROWS.x * ROW_V
	var k1 := FRONT_V + VOMIT_ROWS.y * ROW_V
	for x in range(x0 - 1, x0 + VOMIT_V + 1):
		var edge := x == x0 - 1 or x == x0 + VOMIT_V
		for k in range(k0, k1):
			var top := tread(prof(k).y)
			for j in range(top if edge else floor_v, top + 4):
				g.clear(Vector3i(x, j, k))
			if edge:
				_rail(g, x, top, k)
			else:
				var fv := Vector3i(x, floor_v - 1, k)
				g.put(fv, _jit(C_CONC, fv, 0.03, salt), VoxelMat.SLAB, BODY)
		if edge:
			continue
		_rail(g, x, floor_v, k0)
		if x > x0 and x < x0 + VOMIT_V - 1:
			for j in range(floor_v, tread(VOMIT_ROWS.y) - 1):
				var v := Vector3i(x, j, k1)
				g.put(v, _jit(C_TUNNEL, v, 0.03, salt), VoxelMat.STONE, BODY)


## Three-voxel rail (metal posts, white top) standing on y = base at (x, z).
static func _rail(g: VoxelGrid, x: int, base: int, z: int) -> void:
	for j in range(base, base + 3):
		g.put(Vector3i(x, j, z), C_CAP if j == base + 2 else C_METAL, VoxelMat.METAL, BODY)


## Players' tunnel in the middle of an end section: the opening (TUNNEL_W x TUNNEL_H + 1 voxels) in
## the front wall with a team-coloured frame, TUNNEL_D deep, dark walls with a team stripe, lamps
## on the ceiling, a rubber mat on the floor and a flat canopy over the first CANOPY_ROWS rows.
static func _tunnel(g: VoxelGrid, len_v: int, side: int, salt: int) -> void:
	var c0 := len_v / 2 - CANOPY_W / 2
	var t0 := len_v / 2 - TUNNEL_W / 2
	var t1 := t0 + TUNNEL_W
	var ctop := tread(CANOPY_ROWS)
	var team: Color = TEAM[side]
	var dark: Color = TEAM_DARK[side]
	var k_can := FRONT_V + CANOPY_ROWS * ROW_V
	for x in range(c0, c0 + CANOPY_W):
		var inside := x >= t0 and x < t1
		var wall := x == t0 - 1 or x == t1
		for k in TUNNEL_D + 1:
			var tun := inside and k < TUNNEL_D
			if k < k_can:
				for j in range(0, TOP_V + 4):
					g.clear(Vector3i(x, j, k))
				for j in ctop:
					if tun and j <= TUNNEL_H:
						continue
					var v := Vector3i(x, j, k)
					var c := C_UNDER
					var m := VoxelMat.STONE
					if k < FRONT_V:
						c = team if j <= TUNNEL_H + 1 else C_CAP
						m = VoxelMat.PAINT if j <= TUNNEL_H + 1 else VoxelMat.PLASTER
					elif j == ctop - 1:
						c = C_CONC
						m = VoxelMat.SLAB
					elif wall and j <= TUNNEL_H:
						c = dark if j == 4 else C_TUNNEL
					g.put(v, _jit(c, v, 0.03, salt), m, BODY)
			elif tun:
				for j in TUNNEL_H + 1:
					g.clear(Vector3i(x, j, k))
			elif wall and k < TUNNEL_D:
				for j in TUNNEL_H + 1:
					var v := Vector3i(x, j, k)
					g.put(
						v, _jit(dark if j == 4 else C_TUNNEL, v, 0.03, salt), VoxelMat.STONE, BODY
					)
			if tun:
				var fv := Vector3i(x, -1, k)
				g.put(fv, _jit(C_MAT, fv, 0.03, salt), VoxelMat.CLOTH, BODY)
				var lamp := k % 6 == 3 and x >= t0 + 4 and x < t1 - 4
				var cv := Vector3i(x, TUNNEL_H + 1, k)
				g.put(
					cv,
					C_WINDOW if lamp else C_TUNNEL,
					VoxelMat.LAMP if lamp else VoxelMat.STONE,
					BODY
				)
		_rail(g, x, ctop, 0)
	for x in range(t0, t1):
		for j in TUNNEL_H + 1:
			g.put(Vector3i(x, j, TUNNEL_D), Color("141416"), VoxelMat.STONE, BODY)


# --- Corner ---


## Corner piece: the stand profile on the rings of max(x, z) (x and z both point away from the
## field from the inner corner), a diagonal aisle, the facade on both outer faces.
static func corner(salt := 0) -> VoxelGrid:
	var n := DEPTH_V
	var g := VoxelGrid.new(Vector3i(0, -1, 0), Vector3i(n + 1, TOP_V + PARA_H_V + 2, n + 1))
	for z in n:
		for x in n:
			var k := maxi(x, z)
			var along := mini(x, z)
			var stairs := absi(x - z) <= 1 and prof(k).x == 1
			_column(g, x, z, k, along, stairs, salt)
	for a in n:
		_facade(g, n - 1, a, Vector3i(1, 0, 0), a, salt)
		_facade(g, a, n - 1, Vector3i(0, 0, 1), a + 7, salt)
	return g


# --- Crowd seats ---


## Seats of a straight section: Array of [Vector3 local pan-top position, float yaw] (yaw 0 =
## facing -z, the field). Same options as bank().
static func bank_seats(len_v: int, opts := {}) -> Array:
	var out: Array = []
	var aisle := bool(opts.get("aisle", true))
	var x0 := AISLE_V if aisle else 0
	var vom := bool(opts.get("vomit", false))
	var vx0 := len_v / 2 - VOMIT_V / 2 + (AISLE_V / 2 if aisle else 0)
	var tunnel := int(opts.get("tunnel", -1)) >= 0
	var c0 := len_v / 2 - CANOPY_W / 2
	for i in ROWS:
		var y := (tread(i) + 1) * VS
		var z := seat_depth(i)
		var x := x0
		while x + 2 <= len_v:
			var skip := false
			if vom and i >= VOMIT_ROWS.x and i < VOMIT_ROWS.y and x + 2 > vx0 - 1:
				skip = x < vx0 + VOMIT_V + 1
			if tunnel and i < CANOPY_ROWS and x + 2 > c0 and x < c0 + CANOPY_W:
				skip = true
			if not skip:
				out.append([Vector3((x + 1) * VS, y, z), 0.0])
			x += 2
	return out


## Seats of the corner piece (both arms of every ring, clear of the diagonal aisle).
static func corner_seats() -> Array:
	var out: Array = []
	for i in ROWS:
		var y := (tread(i) + 1) * VS
		var kd := FRONT_V + i * ROW_V + 2  # pan voxel depth
		var d := seat_depth(i)
		var a := 0
		while a + 2 <= kd - 1:
			var s := (a + 1) * VS
			out.append([Vector3(d, y, s), PI * 0.5])  # x arm: faces -x
			out.append([Vector3(s, y, d), 0.0])  # z arm: faces -z
			a += 2
	return out


# --- Floodlight tower ---


## Lattice mast `h_v` voxels tall (2.5 m square, four 0.5 m legs, cross bracing, a ladder cage),
## centred on x = z = 0, with a platform on top.
static func mast(h_v: int) -> VoxelGrid:
	var g := VoxelGrid.new(Vector3i(-6, -1, -6), Vector3i(12, h_v + 2, 12))
	for z in range(-6, 6):
		for x in range(-6, 6):
			var fv := Vector3i(x, -1, z)
			g.put(fv, Color.BLACK, VoxelMat.STONE, CTX)
	# Concrete footing.
	g.fill(Vector3i(-6, 0, -6), Vector3i(5, 1, 5), C_UNDER, VoxelMat.STONE, BODY)
	for y in range(2, h_v):
		for leg in [Vector2i(-5, -5), Vector2i(3, -5), Vector2i(-5, 3), Vector2i(3, 3)]:
			for dz in 2:
				for dx in 2:
					var v := Vector3i(leg.x + dx, y, leg.y + dz)
					g.put(v, _jit(C_METAL, v, 0.03), VoxelMat.METAL, BODY)
		# Bracing: a zig-zag on each face, 12 voxels per bay.
		var t := posmod(y, 12)
		var off := t if t < 6 else 12 - t
		for f in 4:
			var a := -3 + off
			var v: Vector3i
			match f:
				0:
					v = Vector3i(a, y, -5)
				1:
					v = Vector3i(a, y, 4)
				2:
					v = Vector3i(-5, y, a)
				_:
					v = Vector3i(4, y, a)
			g.put(v, _jit(C_METAL_DARK, v, 0.03), VoxelMat.METAL, BODY)
		if t == 0:
			for a in range(-5, 5):
				for v in [
					Vector3i(a, y, -5), Vector3i(a, y, 4), Vector3i(-5, y, a), Vector3i(4, y, a)
				]:
					g.put(v, C_METAL_DARK, VoxelMat.METAL, BODY)
	# Platform.
	g.fill(Vector3i(-6, h_v, -6), Vector3i(5, h_v, 5), C_METAL_DARK, VoxelMat.METAL, BODY)
	return g


## Lamp head: a frame of 4 x 6 lamps (FLOODLIGHT cells in dark rims) facing -z, centred on x,
## bottom at y = 0, with a catwalk below and the back plate.
static func lamp_head() -> VoxelGrid:
	var cols := 6
	var rows := 4
	var w := cols * 4 + 2
	var h := rows * 4 + 2
	var g := VoxelGrid.new(Vector3i(-w / 2, -2, -3), Vector3i(w, h + 2, 6))
	for y in h:
		for x in range(-w / 2, w - w / 2):
			var lx := x + w / 2
			# Back plate and frame.
			for z in range(0, 2):
				var v := Vector3i(x, y, z)
				g.put(v, _jit(C_METAL_DARK, v, 0.03), VoxelMat.METAL, BODY)
			var v := Vector3i(x, y, -1)
			var in_x := lx >= 1 and lx < w - 1
			var in_y := y >= 1 and y < h - 1
			var cx := (lx - 1) % 4
			var cy := (y - 1) % 4
			if in_x and in_y and cx >= 1 and cx <= 2 and cy >= 1 and cy <= 2:
				g.put(v, Color("fff6dc"), VoxelMat.FLOODLIGHT, BODY)
			elif in_x and in_y and (cx == 0 or cx == 3) and (cy == 0 or cy == 3):
				g.put(v, C_METAL_DARK, VoxelMat.METAL, BODY)
			else:
				g.put(v, _jit(C_METAL, v, 0.03), VoxelMat.METAL, BODY)
	# Back: cooling ribs and a strut per lamp column (the side the far stands see).
	for y in range(1, h - 1):
		for x in range(-w / 2 + 1, w - w / 2 - 1):
			var lx := x + w / 2
			if y % 3 == 1 or (lx - 1) % 4 == 1:
				var v := Vector3i(x, y, 2)
				var c := C_METAL if y % 3 == 1 else C_METAL_DARK.lightened(0.08)
				g.put(v, _jit(c, v, 0.04), VoxelMat.METAL, BODY)
	# Catwalk.
	for x in range(-w / 2, w - w / 2):
		for z in range(-3, 2):
			g.put(Vector3i(x, -2, z), C_METAL_DARK, VoxelMat.METAL, BODY)
		g.put(Vector3i(x, -1, -3), C_METAL, VoxelMat.METAL, BODY)
	return g


# --- Scoreboard and emblem ---


## Scoreboard frame `w_v` x `h_v` voxels facing -z: a dark SCREEN panel in a metal frame with a
## white trim, two legs `legs_v` voxels long below it. Origin: bottom middle of the legs.
static func board(w_v: int, h_v: int, legs_v: int) -> VoxelGrid:
	var g := VoxelGrid.new(Vector3i(-w_v / 2 - 1, 0, -1), Vector3i(w_v + 2, legs_v + h_v + 2, 4))
	for y in legs_v:
		for lx in [-w_v / 4, w_v / 4 - 2]:
			for dx in 2:
				for z in range(1, 3):
					var v := Vector3i(lx + dx, y, z)
					g.put(v, _jit(C_METAL, v, 0.03), VoxelMat.METAL, BODY)
	for y in range(legs_v, legs_v + h_v + 2):
		for x in range(-w_v / 2 - 1, w_v - w_v / 2 + 1):
			var edge := (
				y == legs_v or y == legs_v + h_v + 1 or x == -w_v / 2 - 1 or x == w_v - w_v / 2
			)
			for z in range(0, 3):
				var v := Vector3i(x, y, z)
				if edge:
					g.put(
						v,
						C_CAP if z == 0 else C_METAL,
						VoxelMat.PLASTER if z == 0 else VoxelMat.METAL,
						BODY
					)
				elif z == 0:
					g.put(v, _jit(Color("0e1526"), v, 0.02), VoxelMat.SCREEN, BODY)
				else:
					g.put(v, C_METAL_DARK, VoxelMat.METAL, BODY)
	return g


## Poke Ball emblem: disc of radius r_v voxels, 3 voxels thick, facing -z (red top, white bottom,
## black band, white button with a lamp ring that glows at night), centred on the origin.
static func emblem(r_v: int) -> VoxelGrid:
	var g := VoxelGrid.new(Vector3i(-r_v - 1, -r_v - 1, -2), Vector3i(r_v * 2 + 2, r_v * 2 + 2, 4))
	var band := maxi(1, r_v / 7)
	var br := r_v * 0.34
	for y in range(-r_v - 1, r_v + 1):
		for x in range(-r_v - 1, r_v + 1):
			var d := Vector2(x + 0.5, y + 0.5).length()
			if d > r_v:
				continue
			for z in range(-1, 2):
				var v := Vector3i(x, y, z)
				var c := Color("e23a2e") if y >= 0 else Color("f4f2ec")
				var m := VoxelMat.PAINT
				if d > r_v - 1.0:
					c = Color("1e1e22")
				elif absi(y) < band or (y == -band):
					c = Color("1e1e22")
				if d < br + 1.2:
					c = Color("1e1e22")
				if d < br:
					c = Color("f4f2ec")
					if d > br - 1.2 and z == -1:
						c = Color("fff1c8")
						m = VoxelMat.LAMP
				if y > r_v * 0.45 and x < -r_v * 0.2 and x > -r_v * 0.55 and y < r_v * 0.7:
					c = c.lightened(0.25)  # highlight
				g.put(v, _jit(c, v, 0.02), m, BODY)
	# The button sticks out.
	for y in range(-int(br), int(br) + 1):
		for x in range(-int(br), int(br) + 1):
			if Vector2(x + 0.5, y + 0.5).length() < br - 1.0:
				g.put(Vector3i(x, y, -2), Color("f8f6f0"), VoxelMat.PAINT, BODY)
	return g


## Small Poke Ball pixel image (`px` square, transparent outside) for the scoreboard slots.
static func ball_image(px: int, alive: bool) -> Image:
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	var r := px * 0.5 - 0.5
	for y in px:
		for x in px:
			var d := Vector2(x - r, y - r).length()
			if d > r + 0.3:
				continue
			var c := Color("e23a2e") if y < r else Color("f4f2ec")
			if d > r - 1.0 or absf(y - r) < px / 12.0:
				c = Color("1e1e22")
			if d < px * 0.2:
				c = Color("1e1e22") if d > px * 0.12 else Color("f4f2ec")
			if not alive:
				var l := c.get_luminance() * 0.35 + 0.05
				c = Color(l, l, l * 1.1)
			img.set_pixel(x, y, c)
	return img


# --- Plaza ---

const C_PALM_BARK := [Color("8c6c48"), Color("6f5337")]
const C_FRONDS := [Color("3e8a34"), Color("2f6e2a"), Color("5aa83f")]
const C_COCONUT := Color("5b3d22")


## Palm tree for the beach plaza (VS voxels, scaled up by ArenaStadium like the other trees): a thin
## ringed trunk bending to one side, a crown of drooping fronds (part TOP, it sways) and coconuts.
static func palm(variant: int) -> VoxelGrid:
	var g := VoxelGrid.new(Vector3i(-8, -1, -8), Vector3i(20, 20, 16))
	var salt := 131 + variant
	g.fill(Vector3i(-1, -1, -1), Vector3i(0, -1, 0), Color.BLACK, VoxelMat.DIRT, CTX)
	var h := 12 + variant % 3
	var bend := 2.2 + float(variant) * 0.6
	var top := Vector3i.ZERO
	for y in h + 1:
		var f := float(y) / h
		var x := roundi(bend * f * f)
		var v := Vector3i(x, y, 0)
		g.put(v, _jit(C_PALM_BARK[(y / 2) % 2], v, 0.05, salt), VoxelMat.BARK, BODY)
		if y < 2:
			for d in [Vector3i(-1, 0, 0), Vector3i(0, 0, -1), Vector3i(1, 0, 0), Vector3i(0, 0, 1)]:
				g.put(v + d, _jit(C_PALM_BARK[1], v + d, 0.05, salt), VoxelMat.BARK, BODY)
		top = v
	# Crown: fronds out and down from the top.
	var n := 7
	for k in n:
		var a := TAU * (float(k) + _h(k, 1, 0, salt) * 0.4) / n
		var dir := Vector2(cos(a), sin(a))
		var length := 5 + int(_h(k, 2, 0, salt) * 2.0)
		for i in range(1, length + 1):
			var fx := top.x + roundi(dir.x * i)
			var fz := top.z + roundi(dir.y * i)
			var fy := top.y + 1 - (i * i) / 7
			var c: Color = C_FRONDS[0] if i < length - 1 else C_FRONDS[2]
			var v := Vector3i(fx, fy, fz)
			g.put(v, _jit(c, v, 0.06, salt), VoxelMat.LEAVES, TOP)
			if i >= 2 and i < length:
				# Leaflets on both sides, a step lower.
				var side := Vector2(-dir.y, dir.x)
				for sgn in [-1, 1]:
					var w := Vector3i(fx + roundi(side.x * sgn), fy - 1, fz + roundi(side.y * sgn))
					if not g.solid(w):
						g.put(w, _jit(C_FRONDS[1], w, 0.06, salt), VoxelMat.LEAVES, TOP)
	g.put(top + Vector3i(0, 1, 0), _jit(C_FRONDS[2], top, 0.05, salt), VoxelMat.LEAVES, TOP)
	for d in [Vector3i(1, -1, 0), Vector3i(-1, -1, 0), Vector3i(0, -1, 1)]:
		if _h(d.x, d.y, d.z, salt) < 0.75:
			g.put(top + d, C_COCONUT, VoxelMat.BARK, BODY)
	return g

class_name GridMotion
extends RefCounted
## Shared pieces of the 1 m grid movement of humans (docs/VOXEL.md §6): cardinal steps, axis-aligned
## tile paths, what stands in a tile at runtime (people, signs, pets on the NPC layer), the lazy probe
## of a zone's colliders for a grid zone that has no baked TileGrid yet, and the animated tile walk of
## NPC nodes (Story actors, trainers). Pokémon never use it: followers, wild mons and pets stay free.

const MAX_RISE := 0.3  ## highest height step between neighbouring tiles you can walk (one voxel)
const PROBE_SIZE := Vector3(0.7, 1.2, 0.7)  ## box tested at a tile centre, a bit smaller than a tile
const PROBE_LIFT := 0.25  ## the box starts this high over the ground (the floor and curbs stay out)
const NPC_LAYER := 8  ## WorldNpc.LAYER (people, signs, doors, pets)
const WATER_LAYER := 16  ## MapBuilder.WATER_LAYER
const DIRS: Array[Vector2i] = [Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1)]


## Grid under a node (null = it walks freely there): Overworld.grid_at of its position.
static func grid_for(n: Node) -> TileGrid:
	if n == null or not (n is Node3D) or not n.is_inside_tree():
		return null
	var ow := Overworld.of(n)
	return ow.grid_at((n as Node3D).global_position) if ow else null


## Dominant axis of the XZ part of `v` as a tile step; ZERO when `v` is about zero.
static func card(v: Vector3) -> Vector2i:
	if absf(v.x) < 0.001 and absf(v.z) < 0.001:
		return Vector2i.ZERO
	if absf(v.x) > absf(v.z):
		return Vector2i(1 if v.x > 0.0 else -1, 0)
	return Vector2i(0, 1 if v.z > 0.0 else -1)


static func vec(d: Vector2i) -> Vector3:
	return Vector3(d.x, 0.0, d.y)


## Tile centre; off the grid (a seam into a free zone) the height is `fallback_y`.
static func center(g: TileGrid, c: Vector2i, fallback_y := 0.0) -> Vector3:
	return g.center(c) if g and g.has(c) else Vector3(c.x, fallback_y, c.y)


## Axis-aligned tile path from `a` to `b`: the cells after `a`, one axis then the other.
## last_axis 0 ends along x, 1 along z, -1 along the longer leg (ties end along z).
static func axis_path(a: Vector2i, b: Vector2i, last_axis := -1) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var d := b - a
	if last_axis < 0:
		last_axis = 0 if absi(d.x) > absi(d.y) else 1
	var c := a
	for axis in [1 - last_axis, last_axis]:
		var n: int = d.x if axis == 0 else d.y
		var step := Vector2i(signi(n), 0) if axis == 0 else Vector2i(0, signi(n))
		for i in absi(n):
			c += step
			out.append(c)
	return out


## True when the origin of `n` lies inside tile `c` (edges excluded).
static func occupies(n: Node3D, c: Vector2i) -> bool:
	var p := n.global_position
	return absf(p.x - c.x) < 0.5 and absf(p.z - c.y) < 0.5


## A body on the NPC layer standing in tile `c`: people, signs, pets, statics, attendants. Doors do
## not count (their building tile is blocked already, and pushing into one enters it).
static func blocker_at(tree: SceneTree, c: Vector2i, skip: Object = null) -> Node3D:
	for n in tree.get_nodes_in_group(WorldNpc.GROUP):
		if n == skip or n is WorldDoor or not (n is Node3D):
			continue
		var layer = n.get("collision_layer")
		if layer == null or int(layer) & NPC_LAYER == 0 or not (n as Node3D).is_visible_in_tree():
			continue
		if occupies(n, c):
			return n
	return null


## A tile a walker may be put on or step into, by the grid alone plus who stands there: in the grid,
## not a wall, water, door or ledge tile, no NPC claim and no body of the NPC layer (but `who`).
static func spot_free(g: TileGrid, c: Vector2i, who: Node) -> bool:
	if not g.has(c) or g.blocked(c) or g.has_flag(c, TileGrid.DOOR | TileGrid.LEDGE):
		return false
	if g.claimed(c, who) or not who.is_inside_tree():
		return false
	return blocker_at(who.get_tree(), c, who) == null


## Nearest tile to `c` (ring by ring, closest to `near` first) where ok.call(cell) holds; `c` when
## nothing within `radius` fits.
static func nearest(c: Vector2i, ok: Callable, near: Vector3, radius := 12) -> Vector2i:
	if ok.call(c):
		return c
	for r in range(1, radius + 1):
		var best := Vector2i.ZERO
		var best_d := INF
		for dx in range(-r, r + 1):
			for dz in [-(r - absi(dx)), r - absi(dx)]:
				var t := c + Vector2i(dx, dz)
				var dd := Vector2(t.x - near.x, t.y - near.z).length_squared()
				if dd < best_d and ok.call(t):
					best = t
					best_d = dd
		if best_d < INF:
			return best
	return c


## Walks a node (NPC, Story actor, trainer) tile by tile to the tile of `to`: axis-aligned (see
## axis_path), at `speed` m/s, facing each leg, its sheet stepping with alternating feet. Ignores
## blocking, like the Story tweens did; starts with a glide onto its own tile centre when off it.
static func walk_node(n: Node3D, to: Vector3, speed: float, last_axis := -1) -> void:
	if n == null or not n.is_inside_tree():
		return
	var g := grid_for(n)
	var y := n.global_position.y
	var a := TileGrid.cell_of(n.global_position)
	var pts: Array[Vector3] = [n.global_position]
	var own := center(g, a, y)
	if Vector2(own.x - pts[0].x, own.z - pts[0].z).length() > 0.02:
		pts.append(own)
	for c in axis_path(a, TileGrid.cell_of(to), last_axis):
		pts.append(center(g, c, y))
	var total := 0.0
	for i in range(1, pts.size()):
		total += pts[i - 1].distance_to(pts[i])
	if total < 0.02:
		return
	var spr: CharSprite = n.get("char_sprite") as CharSprite if "char_sprite" in n else null
	var tw := n.create_tween()
	tw.tween_method(
		func(s: float) -> void: _along(n, pts, s, spr), 0.0, total, total / maxf(speed, 0.1)
	)
	await tw.finished
	if is_instance_valid(spr):
		spr.step_col = -1


## Puts `n` `s` metres along the polyline `pts`, facing the current leg; feet alternate per tile.
static func _along(n: Node3D, pts: Array[Vector3], s: float, spr: CharSprite) -> void:
	if not is_instance_valid(n):
		return
	var acc := 0.0
	for i in range(1, pts.size()):
		var seg := pts[i - 1].distance_to(pts[i])
		if s <= acc + seg or i == pts.size() - 1:
			var t := clampf((s - acc) / maxf(seg, 0.0001), 0.0, 1.0)
			var dir := pts[i] - pts[i - 1]
			if n.has_method("face_toward"):
				n.face_toward(n.global_position + dir)
			elif n.has_method("face"):
				n.face(n.global_position + dir)
			n.global_position = pts[i - 1].lerp(pts[i], t)
			if is_instance_valid(spr):
				spr.step_col = (1 + i % 2) if t < 0.5 else 0
			return
		acc += seg


# --- probe of a zone's colliders -------------------------------------------------------------------


## TileGrid of a built MapBuilder zone made from its colliders, for a grid zone with no baked grid:
## every tile whose centre lies in `r` is tested with a box a bit smaller than a tile over the
## builder's ground height: walls (layer 1) block, water (layer 16) is water; each door's building
## tile becomes a door tile. Null while the zone's bodies are not in the physics space yet (Jolt
## registers new bodies at the next physics sync), so callers just ask again later.
static func probe_zone(b: MapBuilder, r: Rect2) -> TileGrid:
	if not b.is_inside_tree() or not bodies_ready(b):
		return null
	var g := probe(b.get_world_3d().direct_space_state, r, b.height_at)
	for d in b.get_children():
		if d is WorldDoor:
			var dc := door_cell(d)
			if g.has(dc):
				g.set_flag(dc, TileGrid.BLOCKED | TileGrid.DOOR)
				g.set_flag(dc - card(door_inward(d)), TileGrid.NO_NPC)
	return g


## Probes the tiles with centres in `r` (see probe_zone). height: Callable(x, z) -> float.
static func probe(space: PhysicsDirectSpaceState3D, r: Rect2, height: Callable) -> TileGrid:
	var x0 := ceili(r.position.x)
	var z0 := ceili(r.position.y)
	var x1 := ceili(r.end.x) - 1
	var z1 := ceili(r.end.y) - 1
	var g := TileGrid.new(Vector2i(x0, z0), Vector2i(x1 - x0 + 1, z1 - z0 + 1))
	g.set_meta("probed", true)
	var q := PhysicsShapeQueryParameters3D.new()
	var box := BoxShape3D.new()
	box.size = PROBE_SIZE
	q.shape = box
	for z in range(z0, z1 + 1):
		for x in range(x0, x1 + 1):
			var c := Vector2i(x, z)
			var h := float(height.call(float(x), float(z)))
			g.set_height(c, h)
			g.set_flag(c, cell_flags(space, q, Vector3(x, h, z)))
	return g


## BLOCKED / WATER of one tile centred at `at` (ground height in at.y).
static func cell_flags(
	space: PhysicsDirectSpaceState3D, q: PhysicsShapeQueryParameters3D, at: Vector3
) -> int:
	q.transform = Transform3D(Basis(), at + Vector3(0, PROBE_LIFT + PROBE_SIZE.y * 0.5, 0))
	var f := 0
	q.collision_mask = Overworld.WALL_LAYER
	if not space.intersect_shape(q, 1).is_empty():
		f |= TileGrid.BLOCKED
	q.collision_mask = WATER_LAYER
	if not space.intersect_shape(q, 1).is_empty():
		f |= TileGrid.WATER
	return f


## Live wall / water test of one tile (probed grids: cut trees and flag walls change at runtime).
static func live_blocked(space: PhysicsDirectSpaceState3D, g: TileGrid, c: Vector2i) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var box := BoxShape3D.new()
	box.size = PROBE_SIZE
	q.shape = box
	return cell_flags(space, q, g.center(c)) != 0


## True once the physics space sees the builder's colliders (a query on its first shape hits it).
static func bodies_ready(b: Node3D) -> bool:
	var cs := _first_shape(b)
	if cs == null:
		return true
	var body := cs.get_parent() as CollisionObject3D
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cs.shape
	q.transform = cs.global_transform
	q.collision_mask = body.collision_layer
	for hit in b.get_world_3d().direct_space_state.intersect_shape(q, 32):
		if hit.get("collider") == body:
			return true
	return false


static func _first_shape(n: Node) -> CollisionShape3D:
	for c in n.get_children():
		if (
			c is CollisionShape3D
			and c.shape
			and not c.disabled
			and c.get_parent() is CollisionObject3D
			and (c.get_parent() as CollisionObject3D).collision_layer != 0
		):
			return c
		var deep := _first_shape(c)
		if deep:
			return deep
	return null


## Into-the-building direction of a door (its local +Z; the face points along -Z).
static func door_inward(d: Node3D) -> Vector3:
	var v := d.global_transform.basis.z
	v.y = 0.0
	return v.normalized()


## The building tile a door sits in: just inside its face.
static func door_cell(d: Node3D) -> Vector2i:
	return TileGrid.cell_of(d.global_position + door_inward(d) * 0.45)

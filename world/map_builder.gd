class_name MapBuilder
extends Node3D
## Builds one zone at runtime from res://data/maps/<zone_id>.json with placeholder geometry
## (schema: pba-referencia/analise/03-arquitetura-mundo.md §6.4). All JSON coordinates are world
## coordinates, so this node must stay at the origin. Work is spread over frames (items_per_frame,
## 0 = everything in one call); `built` fires when the zone is walkable and populated.

signal built

const WATER_LAYER := 16
const EDGE_WALL := 1.6  ## invisible rail on plateau edges (taller than a jump)
const RAMP_SLOPE := 2.8  ## run per metre of rise
const WALL_H := 6.0

const C_GRASS := Color(0.42, 0.66, 0.32)
const C_TERRACE := Color(0.47, 0.69, 0.35)
const C_CLIFF := Color(0.58, 0.49, 0.38)
const C_RAMP := Color(0.7, 0.62, 0.5)
const C_PATH := Color(0.8, 0.7, 0.5)
const C_COURT := Color(0.72, 0.45, 0.32)
const C_WATER := Color(0.22, 0.48, 0.85, 0.72)
const C_WALLS := Color(0.93, 0.89, 0.8)
const C_TRUNK := Color(0.4, 0.27, 0.15)
const C_CROWN := Color(0.17, 0.43, 0.2)
const C_BUSH := Color(0.22, 0.52, 0.24)
const C_ROCK := Color(0.52, 0.5, 0.47)
const C_FENCE := Color(0.88, 0.86, 0.8)

## Placeholder footprint per building model: [width, height, depth, front], where `front` is the
## distance from the model origin to the door facade (+Z), read off the map path that ends at each door.
const BUILDINGS := {
	"house_player": [5.6, 3.6, 5.0, 1.8],
	"house_rival": [5.6, 3.6, 5.0, 1.8],
	"lab": [8.0, 4.0, 4.0, 1.5],
	"pokecenter": [7.0, 4.0, 5.5, 1.8],
	"pokemart": [6.0, 3.6, 6.0, 1.24],
	"school": [9.0, 4.2, 7.6, 3.8],
	"gym": [8.0, 5.0, 7.0, 1.87],
	"house": [5.0, 3.6, 5.0, 1.4],
	"house2": [4.5, 3.4, 5.0, 1.2],
	"gatehouse": [7.0, 4.0, 5.0, 2.5],
	"museum": [9.0, 5.0, 6.0, 2.0],
}
const ROOFS := {
	"pokecenter": Color(0.85, 0.26, 0.23), "pokemart": Color(0.2, 0.42, 0.8), "gym": Color(0.3, 0.55, 0.35),
	"lab": Color(0.6, 0.62, 0.68), "school": Color(0.55, 0.35, 0.25),
}
const FACING := [Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)]  ## Down, Left, Right, Up

@export var zone_id := "pallet_town"
@export var items_per_frame := 80
@export var open_rects: Array = []  ## [x,z,w,h] of neighbour zones: no boundary wall where they touch
@export var extras: Dictionary = {}  ## extra entries appended to the map arrays (trainers, heal_spots...)

var data: Dictionary = {}
var is_built := false
var rect := Rect2()
var arrivals: Dictionary = {}  ## spawn name -> Vector3
var counts: Dictionary = {}  ## what was built, for tests/debug

var _solids: StaticBody3D
var _water_body: StaticBody3D
var _batches: Dictionary = {}  ## key -> Array[Transform3D]
var _flag_walls: Array = []  ## [until_flag, StaticBody3D]
var _count := 0
var _rng := RandomNumberGenerator.new()

static var _mats: Dictionary = {}


static func mat(c: Color) -> StandardMaterial3D:
	if not _mats.has(c):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.95
		if c.a < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mats[c] = m
	return _mats[c]


static func load_map(id: String) -> Dictionary:
	var path := "res://data/maps/%s.json" % id
	if not FileAccess.file_exists(path):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if d is Dictionary else {}


static func rect_of(a: Array) -> Rect2:
	return Rect2(float(a[0]), float(a[1]), float(a[2]), float(a[3]))


func build() -> void:
	data = load_map(zone_id)
	if data.is_empty():
		push_error("MapBuilder: no map data for '%s'" % zone_id)
		is_built = true
		built.emit()
		return
	for k in extras:
		data[k] = data.get(k, []) + extras[k]
	rect = rect_of(data.get("rect", [0, 0, 10, 10]))
	_rng.seed = hash(zone_id)
	_solids = _body("Solids", Overworld.WALL_LAYER)
	_water_body = _body("Water", WATER_LAYER)
	_ground()
	await _plateaus()
	await _paths()
	_courts()
	_water()
	await _buildings()
	await _fences()
	_walls()
	_bounds()
	await _trees()
	await _props()
	_flowers()
	_flush()
	await _grass()
	await _spawn_zones()
	await _people()
	for a in data.get("arrivals", []):
		arrivals[String(a.name)] = _at(a)
	is_built = true
	built.emit()


## Terrain height (top of the highest plateau containing the point, else 0).
func height_at(x: float, z: float) -> float:
	return _height_excluding(x, z, {})


func _height_excluding(x: float, z: float, skip: Dictionary) -> float:
	var h := 0.0
	for p in data.get("plateaus", []):
		if p == skip:
			continue
		var r: Array = p.rect
		if x >= r[0] and x <= r[0] + r[2] and z >= r[1] and z <= r[1] + r[3]:
			h = maxf(h, float(p.h))
	return h


## Position of a map entry: [x, z] plus its own "y" when given, else the terrain height.
func _at(e: Dictionary) -> Vector3:
	var p: Array = e.get("pos", e.get("center", [0, 0]))
	var x := float(p[0])
	var z := float(p[1])
	return Vector3(x, float(e.y) if e.has("y") else height_at(x, z), z)


func _tick() -> void:
	_count += 1
	if items_per_frame > 0 and _count % items_per_frame == 0 and is_inside_tree():
		await get_tree().process_frame


func _bump(k: String, n := 1) -> void:
	counts[k] = int(counts.get(k, 0)) + n


# --- helpers -------------------------------------------------------------------------------------

func _body(n: String, layer: int) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = n
	b.collision_layer = layer
	b.collision_mask = 0
	add_child(b)
	return b


func _solid(xf: Transform3D, shape: Shape3D, body: StaticBody3D = null) -> void:
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.transform = xf
	(body if body else _solids).add_child(cs)


func _solid_box(center: Vector3, size: Vector3, body: StaticBody3D = null) -> void:
	var s := BoxShape3D.new()
	s.size = size
	_solid(Transform3D(Basis(), center), s, body)


func _solid_cyl(base: Vector3, r: float, h: float) -> void:
	var s := CylinderShape3D.new()
	s.radius = r
	s.height = h
	_solid(Transform3D(Basis(), base + Vector3(0, h * 0.5, 0)), s)


func _mesh(m: Mesh, c: Color, at: Vector3, n := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if n != "":
		mi.name = n
	mi.mesh = m
	mi.material_override = mat(c)
	mi.position = at
	add_child(mi)
	return mi


func _box(center: Vector3, size: Vector3, c: Color, n := "") -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	return _mesh(bm, c, center, n)


func _plane(center: Vector3, size: Vector2, c: Color, n := "") -> MeshInstance3D:
	var pm := PlaneMesh.new()
	pm.size = size
	var mi := _mesh(pm, c, center, n)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Queues one instance of a batched placeholder mesh (flushed into MultiMeshes by _flush).
func _add(key: String, xf: Transform3D) -> void:
	if not _batches.has(key):
		_batches[key] = []
	_batches[key].append(xf)


func _batch_mesh(key: String) -> Mesh:
	match key:
		"path", "court":
			var pm := PlaneMesh.new()
			pm.size = Vector2.ONE
			pm.material = mat(C_PATH if key == "path" else C_COURT)
			return pm
		"trunk":
			var cm := CylinderMesh.new()
			cm.top_radius = 0.22
			cm.bottom_radius = 0.32
			cm.height = 1.6
			cm.material = mat(C_TRUNK)
			return cm
		"crown", "bush", "rock", "bulb":
			var sm := SphereMesh.new()
			sm.radial_segments = 12
			sm.rings = 6
			sm.material = mat({"crown": C_CROWN, "bush": C_BUSH, "rock": C_ROCK, "bulb": Color(1, 0.95, 0.7)}[key])
			return sm
		"flower":
			var fm := CylinderMesh.new()
			fm.top_radius = 0.5
			fm.bottom_radius = 0.5
			fm.height = 1.0
			fm.radial_segments = 16
			fm.rings = 1
			fm.material = mat(Color(0.95, 0.55, 0.65))
			return fm
		"post":
			var pc := CylinderMesh.new()
			pc.top_radius = 0.5
			pc.bottom_radius = 0.5
			pc.height = 1.0
			pc.radial_segments = 8
			pc.rings = 1
			pc.material = mat(Color(0.3, 0.3, 0.32))
			return pc
	var bm := BoxMesh.new()  # "fence", "box", "wood"
	bm.material = mat({"fence": C_FENCE, "wood": Color(0.55, 0.38, 0.22)}.get(key, C_ROCK))
	return bm


func _flush() -> void:
	for key in _batches:
		var xfs: Array = _batches[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _batch_mesh(key)
		mm.instance_count = xfs.size()
		for i in xfs.size():
			mm.set_instance_transform(i, xfs[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Batch_%s" % key
		mmi.multimesh = mm
		if key == "path" or key == "court" or key == "flower":
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		_bump("batched", xfs.size())
	_batches.clear()


static func _scaled(at: Vector3, size: Vector3, yaw := 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(size), at)


# --- terrain -------------------------------------------------------------------------------------

func _ground() -> void:
	var g := rect.grow(1.0)
	var c := Vector3(g.get_center().x, -0.5, g.get_center().y)
	var tint := String(data.get("look", {}).get("ground", {}).get("tint_b", ""))
	var gc := C_GRASS if tint == "" else C_GRASS.lerp(Color(tint), 0.6)
	if zone_id == "pewter_city":
		gc = C_GRASS.lerp(Color(0.62, 0.62, 0.58), 0.35)  # stone-grey city
	_box(c, Vector3(g.size.x, 1.0, g.size.y), gc, "Ground")
	_solid_box(c, Vector3(g.size.x, 1.0, g.size.y))
	_bump("ground")


func _plateaus() -> void:
	for p in data.get("plateaus", []):
		var r: Array = p.rect
		var h := float(p.h)
		var c := Vector3(r[0] + r[2] / 2.0, h / 2.0, r[1] + r[3] / 2.0)
		_box(c, Vector3(r[2], h, r[3]), C_CLIFF, "Plateau_%s" % p.get("id", ""))
		_plane(Vector3(c.x, h + 0.01, c.z), Vector2(r[2], r[3]), C_TERRACE)
		_solid_box(c, Vector3(r[2], h, r[3]))
		_edge_walls(p, h)
		for s in p.get("ramps", []):
			_ramp(p, s)
		for l in p.get("ledges", []):
			_ledge(p, l)
		_bump("plateaus")
		await _tick()


## Openings on each side of a plateau: ramps, ledges and whole "open" sides.
func _cuts(p: Dictionary) -> Dictionary:
	var cuts := {}
	for s in p.get("ramps", []):
		cuts[s.side] = cuts.get(s.side, []) + [[float(s.at) - float(s.width) / 2.0, float(s.at) + float(s.width) / 2.0]]
	for l in p.get("ledges", []):
		cuts[l.side] = cuts.get(l.side, []) + [[float(l.from), float(l.to)]]
	var r: Array = p.rect
	for side in p.get("open", []):
		var hz: bool = side == "n" or side == "s"
		cuts[side] = cuts.get(side, []) + [[float(r[0] if hz else r[1]), float(r[0] + r[2] if hz else r[1] + r[3])]]
	return cuts


## [a, b] minus every [c0, c1] in cuts.
static func _subtract(a: float, b: float, cuts: Array) -> Array:
	cuts = cuts.duplicate()
	cuts.sort_custom(func(u, v): return u[0] < v[0])
	var segs: Array = []
	var cur := a
	for cut in cuts:
		if cut[0] > cur:
			segs.append([cur, minf(float(cut[0]), b)])
		cur = maxf(cur, float(cut[1]))
	if cur < b:
		segs.append([cur, b])
	return segs.filter(func(s): return s[1] - s[0] > 0.01)


func _edge_walls(p: Dictionary, h: float) -> void:
	var r: Array = p.rect
	var cuts := _cuts(p)
	for side in ["n", "s", "w", "e"]:
		var hz: bool = side == "n" or side == "s"
		var a: float = r[0] if hz else r[1]
		var b: float = r[0] + r[2] if hz else r[1] + r[3]
		var fixed: float = (r[1] if side == "n" else r[1] + r[3]) if hz else (r[0] if side == "w" else r[0] + r[2])
		for sg in _subtract(a, b, cuts.get(side, [])):
			var mid: float = (sg[0] + sg[1]) / 2.0
			var len: float = sg[1] - sg[0]
			var c := Vector3(mid, h + EDGE_WALL / 2.0, fixed) if hz else Vector3(fixed, h + EDGE_WALL / 2.0, mid)
			_solid_box(c, Vector3(len, EDGE_WALL, 0.2) if hz else Vector3(0.2, EDGE_WALL, len))


func _ramp(p: Dictionary, s: Dictionary) -> void:
	var r: Array = p.rect
	var h := float(p.h)
	var w := float(s.width)
	var at := float(s.at)
	var out: Vector3 = {"n": Vector3(0, 0, -1), "s": Vector3(0, 0, 1), "w": Vector3(-1, 0, 0), "e": Vector3(1, 0, 0)}[s.side]
	var edge: Vector3 = {"n": Vector3(at, 0, r[1]), "s": Vector3(at, 0, r[1] + r[3]),
			"w": Vector3(r[0], 0, at), "e": Vector3(r[0] + r[2], 0, at)}[s.side]
	var probe := edge + out * 0.5
	var base := _height_excluding(probe.x, probe.z, p)
	var rise := h - base
	if rise <= 0.01:
		return
	var run := rise * RAMP_SLOPE
	var lat := Vector3(absf(out.z), 0, absf(out.x))
	var top_a := edge + lat * (w / 2.0) + Vector3(0, h, 0)
	var top_b := edge - lat * (w / 2.0) + Vector3(0, h, 0)
	var foot_a := top_a + out * run + Vector3(0, -rise, 0)
	var foot_b := top_b + out * run + Vector3(0, -rise, 0)
	var under_a := top_a + Vector3(0, -rise, 0)
	var under_b := top_b + Vector3(0, -rise, 0)
	var shape := ConvexPolygonShape3D.new()
	shape.points = PackedVector3Array([top_a, top_b, foot_a, foot_b, under_a, under_b])
	_solid(Transform3D(), shape)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var up := (Vector3.UP * run + out * rise).normalized()
	_tri(st, [top_a, top_b, foot_b], up)
	_tri(st, [top_a, foot_b, foot_a], up)
	_tri(st, [top_a, foot_a, under_a], lat)
	_tri(st, [top_b, foot_b, under_b], -lat)
	var mi := MeshInstance3D.new()
	mi.name = "Ramp"
	mi.mesh = st.commit()
	mi.material_override = mat(C_RAMP)
	add_child(mi)
	_bump("ramps")


## Godot front faces are clockwise: flip the triangle so it faces n.
static func _tri(st: SurfaceTool, v: Array, n: Vector3) -> void:
	if (v[1] - v[0]).cross(v[2] - v[0]).dot(n) > 0.0:
		v = [v[0], v[2], v[1]]
	for q in v:
		st.set_normal(n)
		st.add_vertex(q)


func _ledge(p: Dictionary, l: Dictionary) -> void:
	var r: Array = p.rect
	var h := float(p.h)
	var a := float(l.from)
	var b := float(l.to)
	var pos: Vector3
	var yaw := 0.0
	match String(l.side):
		"s":
			pos = Vector3((a + b) / 2.0, h, r[1] + r[3])
		"n":
			pos = Vector3((a + b) / 2.0, h, r[1])
			yaw = PI
		"e":
			pos = Vector3(r[0] + r[2], h, (a + b) / 2.0)
			yaw = PI / 2.0
		_:
			pos = Vector3(r[0], h, (a + b) / 2.0)
			yaw = -PI / 2.0
	var probe := pos + Basis(Vector3.UP, yaw).z * 0.6
	var n := WorldLedge.new()
	n.name = "Ledge"
	n.length = b - a
	n.drop = maxf(h - _height_excluding(probe.x, probe.z, p), 0.1)
	n.position = pos
	n.rotation.y = yaw
	add_child(n)
	_bump("ledges")


## Path rects split at plateau edges so each piece lies flat on its own terrace.
func _paths() -> void:
	var cuts_x: Array = []
	var cuts_z: Array = []
	for p in data.get("plateaus", []):
		var pr: Array = p.rect
		cuts_x.append_array([float(pr[0]), float(pr[0] + pr[2])])
		cuts_z.append_array([float(pr[1]), float(pr[1] + pr[3])])
	var i := 0
	for r in data.get("paths", []):
		var xs := _splits(float(r[0]), float(r[0] + r[2]), cuts_x)
		var zs := _splits(float(r[1]), float(r[1] + r[3]), cuts_z)
		for xi in xs.size() - 1:
			for zi in zs.size() - 1:
				var cx: float = (xs[xi] + xs[xi + 1]) / 2.0
				var cz: float = (zs[zi] + zs[zi + 1]) / 2.0
				var y := height_at(cx, cz) + 0.02 + 0.002 * (i % 4)
				_add("path", _scaled(Vector3(cx, y, cz), Vector3(xs[xi + 1] - xs[xi], 1, zs[zi + 1] - zs[zi])))
		i += 1
		_bump("paths")
		await _tick()


static func _splits(a: float, b: float, cuts: Array) -> Array:
	var out := [a, b]
	for c in cuts:
		if c > a + 0.01 and c < b - 0.01 and not out.has(c):
			out.append(c)
	out.sort()
	return out


func _courts() -> void:
	for c in data.get("courts", []):
		var r := rect_of(c.rect)
		var ctr := r.get_center()
		_add("court", _scaled(Vector3(ctr.x, height_at(ctr.x, ctr.y) + 0.03, ctr.y), Vector3(r.size.x, 1, r.size.y)))
		_bump("courts")


func _water() -> void:
	for wt in data.get("water", []):
		var r := rect_of(wt.rect)
		var ctr := r.get_center()
		var y := height_at(ctr.x, ctr.y)
		_plane(Vector3(ctr.x, y + 0.3, ctr.y), r.size, C_WATER, "Water")
		_box(Vector3(ctr.x, y + 0.02, ctr.y), Vector3(r.size.x, 0.02, r.size.y), Color(0.12, 0.3, 0.5))
		_solid_box(Vector3(ctr.x, y + WALL_H / 2.0, ctr.y), Vector3(r.size.x, WALL_H, r.size.y), _water_body)
		_bump("water")


func _is_water_rect(r: Array) -> bool:
	for wt in data.get("water", []):
		var w: Array = wt.rect
		if absf(float(w[0]) - r[0]) < 0.01 and absf(float(w[1]) - r[1]) < 0.01 \
				and absf(float(w[2]) - r[2]) < 0.01 and absf(float(w[3]) - r[3]) < 0.01:
			return true
	return false


# --- structures ----------------------------------------------------------------------------------

func _buildings() -> void:
	for b in data.get("buildings", []):
		var key := String(b.get("model", "")).get_file()
		var dims: Array = BUILDINGS.get(key, [6.0, 4.0, 5.0, 2.5])
		var w: float = dims[0]
		var h: float = dims[1]
		var d: float = dims[2]
		var origin := _at(b)
		var front: float = origin.z + float(dims[3])
		var c := Vector3(origin.x, origin.y, front - d / 2.0)
		var id := String(b.get("id", key))
		_box(c + Vector3(0, h / 2.0, 0), Vector3(w, h, d), C_WALLS, "Building_%s" % id)
		var roof := PrismMesh.new()
		roof.size = Vector3(w + 0.5, 1.5, d + 0.5)
		var rc: Color = ROOFS.get(key, Color(0.75, 0.32, 0.25) if _rng.randf() < 0.5 else Color(0.35, 0.45, 0.7))
		var rm := _mesh(roof, rc, c + Vector3(0, h + 0.75, 0))
		rm.rotation.y = PI / 2.0 if w > d else 0.0
		if w > d:
			roof.size = Vector3(d + 0.5, 1.5, w + 0.5)
		_solid_box(c + Vector3(0, h / 2.0, 0), Vector3(w, h, d))
		var door := WorldDoor.new()
		door.name = "Door_%s" % id
		var msg: Dictionary = b.get("message", {})
		door.npc_name = String(msg.get("title", id.replace("_", " ").capitalize()))
		door.lines = PackedStringArray(msg.get("lines", ["Fechado."]))
		door.color = Color(0.45, 0.3, 0.2)
		door.body_height = 2.0
		var dr: Dictionary = b.get("door", {})
		door.target_scene = String(dr.get("target_scene", ""))
		door.target_spawn = String(dr.get("target_spawn", ""))
		door.position = Vector3(origin.x + float(b.get("door_dx", 0.0)), origin.y, front)
		door.rotation.y = PI
		add_child(door)
		if dr.has("spawn"):
			arrivals[String(dr.spawn)] = door.position + Vector3(0, 0, 1.2)
		var bd: Dictionary = b.get("back_door", {})
		if not bd.is_empty():  # gatehouses: a second door on the back (-Z) face
			var back := WorldDoor.new()
			back.name = "BackDoor_%s" % id
			back.npc_name = door.npc_name
			back.lines = door.lines
			back.color = door.color
			back.body_height = 2.0
			back.target_scene = String(bd.get("target_scene", ""))
			back.target_spawn = String(bd.get("target_spawn", ""))
			back.position = Vector3(door.position.x, origin.y, front - d)
			add_child(back)
			if bd.has("spawn"):
				var ba := back.position + Vector3(0, 0, -1.2)
				ba.y = height_at(ba.x, ba.z)  # the gate may sit on a terrace that ends at its back wall
				arrivals[String(bd.spawn)] = ba
		if b.has("board"):
			var lab := Label3D.new()
			lab.text = String(b.board.get("text", ""))
			lab.font_size = 96
			lab.outline_size = 12
			lab.modulate = Color(b.board.get("color", "#ffffff"))
			lab.position = Vector3(origin.x, origin.y + h - 0.7, front + 0.05)
			add_child(lab)
		_bump("buildings")
		await _tick()


func _fences() -> void:
	for f in data.get("fences", []):
		var a := Vector3(float(f.from[0]), 0, float(f.from[1]))
		var b := Vector3(float(f.to[0]), 0, float(f.to[1]))
		var mid := (a + b) / 2.0
		mid.y = height_at(mid.x, mid.z)
		var len := a.distance_to(b)
		var yaw := atan2(-(b - a).z, (b - a).x)
		var xf := Transform3D(Basis(Vector3.UP, yaw), mid + Vector3(0, 0.45, 0))
		_add("fence", xf.scaled_local(Vector3(len + 0.1, 0.9, 0.12)))
		var s := BoxShape3D.new()
		s.size = Vector3(len + 0.1, 1.4, 0.3)
		_solid(Transform3D(Basis(Vector3.UP, yaw), mid + Vector3(0, 0.7, 0)), s)
		_bump("fences")
		await _tick()


func _walls() -> void:
	for r in data.get("walls", []):
		if _is_water_rect(r):
			continue  # already a water body
		var wh := float(r[4]) if r.size() > 4 else WALL_H
		_solid_box(Vector3(r[0] + r[2] / 2.0, wh / 2.0, r[1] + r[3] / 2.0), Vector3(r[2], wh, r[3]))
		_bump("walls")
	for fw in data.get("flag_walls", []):
		var r: Array = fw.rect
		var body := _body("FlagWall", Overworld.WALL_LAYER)
		_solid_box(Vector3(r[0] + r[2] / 2.0, WALL_H / 2.0, r[1] + r[3] / 2.0), Vector3(r[2], WALL_H, r[3]), body)
		_flag_walls.append([String(fw.get("until_flag", "")), body])
		_bump("walls")
	refresh_flags()


## Flag walls (Viridian's north wall until has_pokedex) follow Game.flags while the zone is loaded.
func refresh_flags() -> void:
	for e in _flag_walls:
		var open := bool(Game.flags.get(e[0], false))
		e[1].collision_layer = 0 if open else Overworld.WALL_LAYER


func flag_wall_open(i := 0) -> bool:
	return i < _flag_walls.size() and _flag_walls[i][1].collision_layer == 0


## Invisible walls along the zone rect, except where a neighbour zone (open_rects) touches it.
func _bounds() -> void:
	var sides := {
		"n": [rect.position.y, rect.position.x, rect.end.x],
		"s": [rect.end.y, rect.position.x, rect.end.x],
		"w": [rect.position.x, rect.position.y, rect.end.y],
		"e": [rect.end.x, rect.position.y, rect.end.y],
	}
	for side in sides:
		var hz: bool = side == "n" or side == "s"
		var fixed: float = sides[side][0]
		var cuts: Array = []
		for o in open_rects:
			var orr := rect_of(o)
			var touches := false
			var span: Array
			if hz:
				touches = absf(fixed - orr.position.y) < 0.6 or absf(fixed - orr.end.y) < 0.6
				span = [orr.position.x, orr.end.x]
			else:
				touches = absf(fixed - orr.position.x) < 0.6 or absf(fixed - orr.end.x) < 0.6
				span = [orr.position.y, orr.end.y]
			if touches:
				cuts.append(span)
		var outward := -0.5 if side == "n" or side == "w" else 0.5
		for sg in _subtract(sides[side][1], sides[side][2], cuts):
			var mid: float = (sg[0] + sg[1]) / 2.0
			var len: float = sg[1] - sg[0]
			var c := Vector3(mid, WALL_H / 2.0, fixed + outward) if hz else Vector3(fixed + outward, WALL_H / 2.0, mid)
			_solid_box(c, Vector3(len, WALL_H, 1.0) if hz else Vector3(1.0, WALL_H, len))
			_bump("bounds")


# --- vegetation & props --------------------------------------------------------------------------

func _tree(at: Vector3, s: float) -> void:
	_add("trunk", _scaled(at + Vector3(0, 0.8 * s, 0), Vector3.ONE * s))
	_add("crown", _scaled(at + Vector3(0, 2.4 * s, 0), Vector3(2.4, 2.2, 2.4) * s, _rng.randf() * TAU))
	_solid_cyl(at, 0.45 * s, 3.0 * s)
	_bump("trees")


func _trees() -> void:
	for t in data.get("tree_lines", []):
		var a := Vector3(float(t.from[0]), 0, float(t.from[1]))
		var b := Vector3(float(t.to[0]), 0, float(t.to[1]))
		var o: Array = t.get("out", [0, 0])
		var out := Vector3(float(o[0]), 0, float(o[1]))
		var step := 1.9
		var n := maxi(int(a.distance_to(b) / step), 1)
		for row in int(t.get("rows", 2)):
			var off := out * (row * 1.9) + (Vector3.ZERO if row % 2 == 0 else (b - a).normalized() * 0.95)
			for i in n + 1:
				var p := a.lerp(b, float(i) / n) + off + Vector3(_rng.randf_range(-0.3, 0.3), 0, _rng.randf_range(-0.3, 0.3))
				p.y = height_at(p.x, p.z)
				_tree(p, _rng.randf_range(0.9, 1.15))
		await _tick()
	for t in data.get("trees", []):
		_tree(_at(t), _rng.randf_range(0.9, 1.1))
		await _tick()


func _props() -> void:
	for p in data.get("props", []):
		var model := String(p.get("model", "")).get_file()
		var at := _at(p)
		var s := float(p.get("scale", 1.0))
		var yaw := deg_to_rad(float(p.get("rot", 0.0)))
		var collide := String(p.get("collide", ""))
		if model == "bush":
			_add("bush", _scaled(at + Vector3(0, 0.4 * s, 0), Vector3(1.1, 0.9, 1.1) * s))
		elif model.begins_with("rock"):
			_add("rock", _scaled(at + Vector3(0, 0.1, 0), Vector3(0.6, 0.35, 0.5) * s, yaw))
		elif model == "lamp":
			_add("post", _scaled(at + Vector3(0, 1.2, 0), Vector3(0.14, 2.4, 0.14)))
			_add("bulb", _scaled(at + Vector3(0, 2.5, 0), Vector3.ONE * 0.4))
		elif model == "fountain":
			_add("box", _scaled(at + Vector3(0, 0.3, 0), Vector3(2.6, 0.6, 2.6)))
			_add("post", _scaled(at + Vector3(0, 0.9, 0), Vector3(0.4, 1.2, 0.4)))
		elif model.begins_with("prop_dummy"):
			_add("wood", _scaled(at + Vector3(0, 0.5, 0), Vector3(0.5, 1.0, 0.5), yaw))
		elif model.begins_with("camp_"):
			_add("wood", _scaled(at + Vector3(0, 0.3, 0), Vector3(1.2, 0.6, 0.5), yaw))
		else:
			_add("box", _scaled(at + Vector3(0, 0.3, 0), Vector3(0.6, 0.6, 0.6), yaw))
		match collide:
			"round":
				_solid_cyl(at, 0.45 * s, 1.2)
			"trunk":
				_solid_cyl(at, 0.15, 2.4)
			"box":
				var size := Vector3(2.6, 1.2, 2.6) if model == "fountain" else Vector3(0.6, 1.2, 0.6)
				_solid_box(at + Vector3(0, size.y / 2.0, 0), size)
		_bump("props")
		await _tick()


func _flowers() -> void:
	for f in data.get("flower_beds", []):
		var at := _at(f)
		var r := float(f.get("radius", 1.0))
		_add("flower", _scaled(at + Vector3(0, 0.03, 0), Vector3(r * 2.0, 0.05, r * 2.0)))
		_bump("flowers")


# --- encounters & people -------------------------------------------------------------------------

func _grass() -> void:
	var i := 0
	for g in data.get("tall_grass", []):
		var tg := TallGrass.new()
		tg.name = "TallGrass%d" % i
		tg.table_id = String(g.get("table", zone_id))
		var sz: Array = g.get("size", [6, 4])
		tg.size = Vector3(float(sz[0]), 1.0, float(sz[1]))
		tg.position = _at(g)
		add_child(tg)
		i += 1
		_bump("tall_grass")
		await _tick()


func _spawn_zones() -> void:
	for z in data.get("spawn_zones", []):
		var sz := SpawnZone.new()
		sz.name = String(z.get("name", "SpawnZone"))
		sz.table_id = String(z.get("table", zone_id))
		sz.radius = float(z.get("radius", 4.0))
		sz.max_alive = int(z.get("max", 3))
		sz.mode = String(z.get("mode", "visible"))
		sz.position = _at(z)
		add_child(sz)
		_bump("spawn_zones")
		await _tick()


static func facing_yaw(f) -> float:
	var d: Vector3 = FACING[clampi(int(f), 0, 3)]
	return atan2(-d.x, -d.z)


static func fill_names(lines: Array) -> PackedStringArray:
	var out := PackedStringArray()
	var pn = Game.get("player_name")
	var rn = Game.get("rival_name")
	for l in lines:
		out.append(String(l).replace("{PLAYER}", String(pn) if pn else "RED").replace("{RIVAL}", String(rn) if rn else "BLUE"))
	return out


func _people() -> void:
	for s in data.get("signs", []):
		var sp := SignPost.new()
		sp.name = String(s.get("name", "Sign"))
		sp.npc_name = String(s.get("title", "Placa"))
		sp.lines = fill_names(s.get("lines", []))
		sp.color = Color(0.55, 0.4, 0.25)
		sp.body_height = 1.2
		sp.position = _at(s)
		sp.rotation.y = facing_yaw(s.get("facing", 0))
		add_child(sp)
		_bump("signs")
		await _tick()
	for n in data.get("npcs", []):
		if n.has("requires_flag") and not bool(Game.flags.get(String(n.requires_flag), false)):
			continue
		if n.has("hidden_by_flag") and bool(Game.flags.get(String(n.hidden_by_flag), false)):
			continue
		var npc := WorldNpc.new()
		npc.name = String(n.get("node", "Npc"))
		npc.npc_name = String(n.get("name", "Villager"))
		npc.lines = fill_names(n.get("lines", ["..."]))
		npc.color = Color.from_hsv(_rng.randf(), 0.45, 0.85)
		npc.position = _at(n)
		npc.rotation.y = facing_yaw(n.get("facing", 0))
		add_child(npc)
		_bump("npcs")
		await _tick()
	for t in data.get("trainers", []):
		var tr := WorldTrainer.new()
		tr.name = String(t.get("node", "Trainer_%s" % t.id))
		tr.trainer_id = String(t.id)
		tr.color = Color(0.85, 0.55, 0.15)
		tr.position = _at(t)
		tr.rotation.y = facing_yaw(t.get("facing", 0))
		add_child(tr)
		_bump("trainers")
	for h in data.get("heal_spots", []):
		var hs := HealSpot.new()
		hs.name = String(h.get("name", "HealSpot")).replace(" ", "")
		hs.npc_name = String(h.get("name", "Ponto de cura"))
		hs.lines = PackedStringArray(h.get("lines", ["Seu time foi curado!"]))
		hs.color = Color(0.95, 0.5, 0.6)
		hs.position = _at(h)
		hs.rotation.y = facing_yaw(h.get("facing", 0))
		add_child(hs)
		_bump("heal_spots")
	for it in data.get("items", []):
		if bool(it.get("hidden", false)) or ItemBall.taken(String(it.uid)):
			continue
		var ib := ItemBall.new()
		ib.name = "Item_%s" % it.uid
		ib.npc_name = ""
		ib.uid = String(it.uid)
		ib.item_id = String(it.get("item", "potion"))
		ib.count = int(it.get("count", 1))
		ib.color = Color(0.9, 0.2, 0.2)
		ib.body_height = 0.5
		ib.position = _at(it)
		add_child(ib)
		_bump("items")

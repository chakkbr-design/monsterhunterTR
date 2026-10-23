class_name MapBuilder
extends Node3D
## Builds one zone at runtime from res://data/maps/<zone_id>.json (schema:
## pba-referencia/analise/03-arquitetura-mundo.md §6.4) with the ORIGINAL game's look, ported from
## scripts/world/world_builder.gd: pixel ground shader, organic path masks, earth cliffs with grass
## lips, stepped ramps, boulder ledges, HGSS buildings/trees/bushes/fences/lamps as the map says,
## animated HGSS flower tiles, Kenney grass scatter, the water shader, forest sun shafts.
## Collision is the port's own (invisible boxes/cylinders, unchanged); buildings collide with their
## model's footprint like the original ("collide": "box").
## All JSON coordinates are world coordinates, so this node must stay at the origin. Work is spread
## over frames (items_per_frame, 0 = everything in one call); `built` fires when the zone is
## walkable and populated.

signal built

const GROUP := "map_builder"
const WATER_LAYER := 16
const EDGE_WALL := 1.6  ## invisible rail on plateau edges (taller than a jump)
const RAMP_SLOPE := 2.8  ## run per metre of rise
const WALL_H := 6.0

const C_GRASS := Color(0.42, 0.66, 0.32)
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
## Doors and arrivals stay on these; the collision box comes from the model when it exists.
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
const FACING := [Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)]  ## Down, Left, Right, Up

## Original world_builder constants.
const HGSS_TREE_TINT := Color(0.74, 0.86, 0.72)
const HGSS_SCALE := 0.8
const HGSS_TREE := "hgss/common/tree"
const HGSS_BUSH := "hgss/common/bush"
const HGSS_BOULDER := "hgss/common/boulder"
const KENNEY_TREE_SCALE := 3.2
const BOARD_SCALE_HGSS := 0.6
## Door spawn points of the original zone scenes (scenes/world/zones/*.tscn): 1.6 m in front of the
## model's facade (its Door area 0.15 m out, the spawn 1.45 m past it). The port's door is a solid
## interactable, so it stays on the facade.
const DOOR_SPAWN := 1.6
const HGSS_FLOWER_Y := 0.03
const HGSS_FLOWER_SECONDS := 0.25
const FLOWER_KINDS := [
	"nature/flower_redA",
	"nature/flower_redB",
	"nature/flower_yellowA",
	"nature/flower_yellowB",
	"nature/flower_purpleA",
	"nature/flower_purpleB"
]
const COURT_LIFT := 0.02
const SKIRT := 40.0  ## the ground runs on under neighbouring zones / past the edges

@export var zone_id := "pallet_town"
@export var items_per_frame := 80
@export var open_rects: Array = []  ## [x,z,w,h] of neighbour zones: no boundary wall where they touch
@export var extras: Dictionary = {}  ## extra entries appended to the map arrays (trainers, heal_spots...)
@export var decorate := true  ## false: skip scatter grass / flowers / shafts (bare tests)

var data: Dictionary = {}
var is_built := false
var rect := Rect2()
var arrivals: Dictionary = {}  ## spawn name -> Vector3
var counts: Dictionary = {}  ## what was built, for tests/debug
var ground_material: ShaderMaterial  ## shared by the ground and terrace tops (time of day tints it)
var leaf_points: Array[Vector3] = []  ## tree crowns, for falling leaves

var _solids: StaticBody3D
var _water_body: StaticBody3D
var _batches: Dictionary = {}  ## key -> Array[Transform3D] (placeholder meshes)
var _models: Dictionary = {}  ## "id|opts" -> {id, opts, xfs, shadow}
var _flag_walls: Array = []  ## [until_flag, StaticBody3D]
var _count := 0
var _rng := RandomNumberGenerator.new()
var _look: Dictionary = {}

static var _mats: Dictionary = {}
static var _flower_mats: Dictionary = {}


static func mat(c: Color) -> StandardMaterial3D:
	if not _mats.has(c):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.95
		if c.a < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mats[c] = m
	return _mats[c]


static var _maps: Dictionary = {}  ## parsed map JSON per zone (re-streaming a zone skips the parse)


## A private deep copy, so callers may mutate it freely.
static func load_map(id: String) -> Dictionary:
	if not _maps.has(id):
		var path := "res://data/maps/%s.json" % id
		var d = (
			JSON.parse_string(FileAccess.get_file_as_string(path))
			if FileAccess.file_exists(path)
			else null
		)
		_maps[id] = d if d is Dictionary else {}
	return (_maps[id] as Dictionary).duplicate(true)


static func rect_of(a: Array) -> Rect2:
	return Rect2(float(a[0]), float(a[1]), float(a[2]), float(a[3]))


## Map asset path of the original ("res://assets/x") -> the extracted copy.
static func art_path(p: String) -> String:
	return p.replace("res://assets/", WorldFx.ART)


func _enter_tree() -> void:
	add_to_group(GROUP)


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
	_look = data.get("look", {})
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
	if decorate:
		_backdrop()
		await _scatter()
		_sun_shafts()
	is_built = true
	if is_inside_tree():
		var tod := get_tree().get_first_node_in_group(WorldTimeOfDay.GROUP)
		if tod:
			tod.refresh()
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


func _v(a: Array) -> Vector3:
	return Vector3(float(a[0]), height_at(float(a[0]), float(a[1])), float(a[1]))


func _tick() -> void:
	_count += 1
	if items_per_frame > 0 and _count % items_per_frame == 0 and is_inside_tree():
		await get_tree().process_frame


func _bump(k: String, n := 1) -> void:
	counts[k] = int(counts.get(k, 0)) + n


func _group(n: String) -> Node3D:
	var g := get_node_or_null(n) as Node3D
	if g == null:
		g = Node3D.new()
		g.name = n
		add_child(g)
	return g


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


func _plane_mat(
	parent: Node, center: Vector3, size: Vector2, m: Material, n := ""
) -> MeshInstance3D:
	var pm := PlaneMesh.new()
	pm.size = size
	var mi := MeshInstance3D.new()
	if n != "":
		mi.name = n
	mi.mesh = pm
	mi.material_override = m
	mi.position = center
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## Queues one instance of a batched placeholder mesh (flushed into MultiMeshes by _flush).
func _add(key: String, xf: Transform3D) -> void:
	if not _batches.has(key):
		_batches[key] = []
	_batches[key].append(xf)


## Queues one instance of an original model (all instances of a model+opts share one MultiMesh).
## Returns false when the model is missing (caller draws a placeholder).
func _add_model(id: String, xf: Transform3D, opts := {}, shadow := true) -> bool:
	if not WorldProps.exists(id):
		return false
	var key := "%s|%s" % [id, str(opts)]
	if not _models.has(key):
		_models[key] = {"id": id, "opts": opts, "xfs": [], "shadow": shadow}
	_models[key].xfs.append(xf)
	return true


func _batch_mesh(key: String) -> Mesh:
	match key:
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
			sm.material = mat(
				{"crown": C_CROWN, "bush": C_BUSH, "rock": C_ROCK, "bulb": Color(1, 0.95, 0.7)}[key]
			)
			return sm
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
		add_child(mmi)
		_bump("batched", xfs.size())
	_batches.clear()
	for key in _models:
		var e: Dictionary = _models[key]
		var bm := WorldProps.batch_mesh(e.id, e.opts)
		if bm.is_empty():
			continue
		var xfs: Array = e.xfs
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = bm[0]
		mm.instance_count = xfs.size()
		for i in xfs.size():
			mm.set_instance_transform(i, xfs[i] * (bm[1] as Transform3D))
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Batch_%s" % String(e.id).get_file()
		mmi.multimesh = mm
		if not e.shadow:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		_bump("batched", xfs.size())
	_models.clear()


static func _scaled(at: Vector3, size: Vector3, yaw := 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(size), at)


static var _boxes: Dictionary = {}  ## model id -> local AABB at scale 1, rot 0


## Local AABB of a model at scale 1 and rot 0 (empty when missing), like the original's probe
## instances (world_builder._model_width, Props.bounds).
static func model_box(id: String) -> AABB:
	if not _boxes.has(id):
		var box := AABB()
		var ps := WorldProps.scene(id)
		if ps:
			var n: Node3D = ps.instantiate()
			box = WorldProps.bounds(n, true)
			n.free()
		_boxes[id] = box
	return _boxes[id]


## Axis-aligned box of model `id` placed at the origin with scale s and yaw (rad).
static func placed_box(id: String, s: float, yaw := 0.0) -> AABB:
	return (
		Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3.ONE * s), Vector3.ZERO)
		* model_box(id)
	)


# --- terrain -------------------------------------------------------------------------------------


func _ground_mat() -> ShaderMaterial:
	if ground_material == null:
		var g: Dictionary = _look.get("ground", {})
		ground_material = WorldFx.shader_mat(
			"ground", {"albedo_tex": WorldFx.tex("textures/ground_grass.png")}
		)
		for k in WorldTimeOfDay.GROUND_TINTS:
			ground_material.set_shader_parameter(
				k, Color(String(g[k])) if g.has(k) else WorldTimeOfDay.GROUND_TINTS[k]
			)
		ground_material.set_shader_parameter("desaturate", float(g.get("desaturate", 0.0)))
	return ground_material


func _ground() -> void:
	var g := rect.grow(1.0)
	var c := Vector3(g.get_center().x, -0.5, g.get_center().y)
	var t := _group("Terrain")
	_plane_mat(
		t,
		Vector3(rect.get_center().x, 0.0, rect.get_center().y),
		rect.size,
		_ground_mat(),
		"Ground"
	)
	var sk := rect.grow(SKIRT)
	_plane_mat(
		t,
		Vector3(sk.get_center().x, -0.06, sk.get_center().y),
		sk.size,
		_ground_mat(),
		"GroundSkirt"
	)
	_solid_box(c, Vector3(g.size.x, 1.0, g.size.y))
	_bump("ground")


func _plateaus() -> void:
	var t := _group("Terraces")
	for p in data.get("plateaus", []):
		var r: Array = p.rect
		var h := float(p.h)
		var c := Vector3(r[0] + r[2] / 2.0, h / 2.0, r[1] + r[3] / 2.0)
		var block := Node3D.new()
		block.name = "Plateau_%s" % p.get("id", "")
		t.add_child(block)
		_plane_mat(block, Vector3(c.x, h + 0.002, c.z), Vector2(r[2], r[3]), _ground_mat(), "Top")
		_earth_walls(block, p, h)
		_solid_box(c, Vector3(r[2], h, r[3]))
		_edge_walls(p, h)
		for s in p.get("ramps", []):
			_ramp(block, p, s)
		for l in p.get("ledges", []):
			_ledge(p, l)
		var geoms := block.find_children("*", "GeometryInstance3D", true, false)
		block.set_meta("geoms", geoms)
		block.set_meta("height", h + 1.5)
		block.add_to_group("fade_building")
		block.set_meta("rect", Rect2(r[0], r[1], r[2], r[3]))
		WorldProps.register_fader(block, Rect2(r[0], r[1], r[2], r[3]))
		_bump("plateaus")
		await _tick()


## Original earth cliff faces with a lip of grass blades along the top edge.
func _earth_walls(block: Node3D, p: Dictionary, h: float) -> void:
	var r: Array = p.rect
	var top_at := func(_x: float, _z: float) -> float: return h
	var base_at := func(x: float, z: float) -> float: return _height_excluding(x, z, p)
	var i := 0
	for line in TerrainCliff.outline(Rect2(r[0], r[1], r[2], r[3]), _cuts(p)):
		var seed := hash(String(p.get("id", ""))) + i
		var mi := MeshInstance3D.new()
		mi.name = "Wall%d" % i
		mi.mesh = TerrainCliff.build(line.points, line.normals, line.closed, top_at, base_at, seed)
		mi.material_override = TerrainCliff.material()
		block.add_child(mi)
		var lip := TerrainGrassLip.build(line.points, line.normals, top_at, seed + 100)
		lip.remove_meta("transforms")
		block.add_child(lip)
		i += 1


## Openings on each side of a plateau: ramps, ledges and whole "open" sides.
func _cuts(p: Dictionary) -> Dictionary:
	var cuts := {}
	for s in p.get("ramps", []):
		cuts[s.side] = (
			cuts.get(s.side, [])
			+ [[float(s.at) - float(s.width) / 2.0, float(s.at) + float(s.width) / 2.0]]
		)
	for l in p.get("ledges", []):
		cuts[l.side] = cuts.get(l.side, []) + [[float(l.from), float(l.to)]]
	var r: Array = p.rect
	for side in p.get("open", []):
		var hz: bool = side == "n" or side == "s"
		cuts[side] = (
			cuts.get(side, [])
			+ [[float(r[0] if hz else r[1]), float(r[0] + r[2] if hz else r[1] + r[3])]]
		)
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
		var fixed: float = (
			(r[1] if side == "n" else r[1] + r[3]) if hz else (r[0] if side == "w" else r[0] + r[2])
		)
		for sg in _subtract(a, b, cuts.get(side, [])):
			var mid: float = (sg[0] + sg[1]) / 2.0
			var len: float = sg[1] - sg[0]
			var c := (
				Vector3(mid, h + EDGE_WALL / 2.0, fixed)
				if hz
				else Vector3(fixed, h + EDGE_WALL / 2.0, mid)
			)
			_solid_box(c, Vector3(len, EDGE_WALL, 0.2) if hz else Vector3(0.2, EDGE_WALL, len))


func _ramp(block: Node3D, p: Dictionary, s: Dictionary) -> void:
	var r: Array = p.rect
	var h := float(p.h)
	var w := float(s.width)
	var at := float(s.at)
	var out: Vector3 = {
		"n": Vector3(0, 0, -1), "s": Vector3(0, 0, 1), "w": Vector3(-1, 0, 0), "e": Vector3(1, 0, 0)
	}[s.side]
	var edge: Vector3 = {
		"n": Vector3(at, 0, r[1]),
		"s": Vector3(at, 0, r[1] + r[3]),
		"w": Vector3(r[0], 0, at),
		"e": Vector3(r[0] + r[2], 0, at)
	}[s.side]
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
	# Visual: the original's pixel steps and earth cheeks on both sides.
	var surf := MeshInstance3D.new()
	surf.name = "Ramp"
	surf.mesh = TerrainSteps.build(top_a, top_b, foot_a, foot_b)
	surf.material_override = TerrainSteps.material()
	block.add_child(surf)
	for cheek in [[top_a, foot_a, lat], [top_b, foot_b, -lat]]:
		var t0: Vector3 = cheek[0]
		var t1: Vector3 = cheek[1]
		var nrm := Vector2(cheek[2].x, cheek[2].z)
		var pts := PackedVector2Array()
		var nrms := PackedVector2Array()
		var steps := maxi(int(ceil(run / 0.25)), 1)
		for k in steps + 1:
			var q := t0.lerp(t1, float(k) / steps)
			pts.append(Vector2(q.x, q.z))
			nrms.append(nrm)
		var cheek_top := func(x: float, z: float) -> float:
			return TerrainSteps.height_at(rise, run, base, Vector2(x - t0.x, z - t0.z).length())
		var cm := MeshInstance3D.new()
		cm.name = "RampCheek"
		cm.mesh = TerrainCliff.build(
			pts,
			nrms,
			false,
			cheek_top,
			func(_x: float, _z: float) -> float: return base,
			hash(String(p.get("id", ""))) + 7
		)
		cm.material_override = TerrainCliff.material()
		block.add_child(cm)
	_bump("ramps")


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


## Organic dirt roads (original PathMask): one overlay per terrace level with its baked mask.
func _paths() -> void:
	var list: Array = data.get("paths", [])
	if list.is_empty():
		return
	var g := _group("Paths")
	var lv := TerrainPathMask.levels(list, height_at)
	var tint := Color(String(_look.get("path_tint", "#ffffff")))
	var mix := float(_look.get("path_mix", 0.0))
	var i := 0
	for level in lv:
		var rects: Array = lv[level]
		var area := TerrainPathMask.bounds(rects)
		var img := TerrainPathMask.load_mask(TerrainPathMask.mask_file(zone_id, i))
		var want := Vector2i(
			maxi(int(ceil(area.size.x * TerrainPathMask.PX_PER_M)), 1),
			maxi(int(ceil(area.size.y * TerrainPathMask.PX_PER_M)), 1)
		)
		if img == null or absi(img.get_width() - want.x) > 1 or absi(img.get_height() - want.y) > 1:
			img = TerrainPathMask.generate(rects, area, hash(zone_id) + i)  # paths changed since the bake
		g.add_child(TerrainPathMask.overlay(rects, float(level), img, tint, mix))
		i += 1
		await _tick()
	_bump("paths", list.size())


func _courts() -> void:
	for c in data.get("courts", []):
		var r := rect_of(c.rect)
		var ctr := r.get_center()
		var m := StandardMaterial3D.new()
		var tex := WorldFx.tex("textures/%s.png" % String(c.get("tex", "court_clay")))
		if tex:
			m.albedo_texture = tex
			m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		else:
			m.albedo_color = C_COURT
		m.roughness = 1.0
		_plane_mat(
			_group("Courts"),
			Vector3(ctr.x, height_at(ctr.x, ctr.y) + COURT_LIFT, ctr.y),
			r.size,
			m,
			"Court"
		)
		_bump("courts")


static var _water_mat: ShaderMaterial


static func water_material() -> ShaderMaterial:
	if _water_mat == null:
		_water_mat = (
			WorldFx
			. shader_mat(
				"water",
				{
					"sea_tex": WorldFx.tex("models/hgss/common/sea_un.png"),
					"glint_tex": WorldFx.tex("models/hgss/common/sea_on_sheet.png"),
					"shore_tex": WorldFx.tex("models/hgss/common/pond_line.png"),
					"foam_tex": WorldFx.tex("models/hgss/common/sea_line02.png"),
					"shallow_width": 1.2,
				}
			)
		)
	return _water_mat


func _water() -> void:
	var list: Array = data.get("water", [])
	if list.is_empty():
		return
	var g := _group("WaterSurface")
	var wm := water_material()
	var margin := (
		float(wm.get_shader_parameter("margin"))
		if wm.get_shader_parameter("margin") != null
		else 0.9
	)
	for wt in list:
		var r := rect_of(wt.rect)
		var ctr := r.get_center()
		var y := height_at(ctr.x, ctr.y)
		var mi := _plane_mat(
			g, Vector3(ctr.x, y + 0.04, ctr.y), r.size + Vector2.ONE * margin * 2.0, wm, "Water"
		)
		mi.set_instance_shader_parameter("centre", ctr)
		mi.set_instance_shader_parameter("half_size", r.size / 2.0)
		for k in 10:
			var p := Vector3(
				ctr.x + _rng.randf_range(-r.size.x, r.size.x) * 0.5,
				y + 0.08,
				ctr.y + _rng.randf_range(-r.size.y, r.size.y) * 0.5
			)
			_add_model(
				"nature/lily_large" if k % 2 == 0 else "nature/lily_small",
				_scaled(p, Vector3.ONE * 2.0, deg_to_rad(_rng.randi_range(0, 359))),
				{},
				false
			)
		_solid_box(
			Vector3(ctr.x, y + WALL_H / 2.0, ctr.y),
			Vector3(r.size.x, WALL_H, r.size.y),
			_water_body
		)
		_bump("water")


func _is_water_rect(r: Array) -> bool:
	for wt in data.get("water", []):
		var w: Array = wt.rect
		if (
			absf(float(w[0]) - r[0]) < 0.01
			and absf(float(w[1]) - r[1]) < 0.01
			and absf(float(w[2]) - r[2]) < 0.01
			and absf(float(w[3]) - r[3]) < 0.01
		):
			return true
	return false


# --- structures ----------------------------------------------------------------------------------


func _buildings() -> void:
	var g := _group("Buildings")
	for b in data.get("buildings", []):
		var model := String(b.get("model", ""))
		var key := model.get_file()
		var dims: Array = BUILDINGS.get(key, [6.0, 4.0, 5.0, 2.5])
		var w: float = dims[0]
		var h: float = dims[1]
		var d: float = dims[2]
		var origin := _at(b)
		var rot := float(b.get("rot", 0.0))
		var basis := Basis(Vector3.UP, deg_to_rad(rot))
		var front_l := float(dims[3])
		var back_l := front_l - d
		var spawn_l := 1.2
		var id := String(b.get("id", key))
		var inst: Node3D = null
		if WorldProps.exists(model) and is_inside_tree():
			var tex: Texture2D = null
			if b.has("tex"):
				tex = load(art_path(String(b.tex)))
			inst = WorldProps.place(
				g,
				model,
				origin,
				{
					"scale": float(b.get("scale", 5.0)),
					"rot": rot,
					"windows": true,
					"fade": "building",
					"texture": tex
				}
			)
		if inst:
			inst.name = id.to_pascal_case()
			# Doors on the model's own facade, spawns where the original zone scenes put them.
			var lb := model_box(model)
			var bs := float(b.get("scale", 5.0))
			front_l = lb.end.z * bs
			back_l = lb.position.z * bs
			spawn_l = DOOR_SPAWN
			var bb := WorldProps.bounds(inst)
			_solid_box(
				Vector3(
					bb.get_center().x, bb.position.y + maxf(bb.size.y, 1.0) / 2.0, bb.get_center().z
				),
				Vector3(bb.size.x, maxf(bb.size.y, 1.0), bb.size.z)
			)
		else:
			var c := origin + basis * Vector3(0, 0, front_l - d / 2.0)
			var bx := _box(
				c + Vector3(0, h / 2.0, 0), Vector3(w, h, d), C_WALLS, "Building_%s" % id
			)
			bx.rotation.y = deg_to_rad(rot)
			var roof := PrismMesh.new()
			roof.size = Vector3(d + 0.5, 1.5, w + 0.5) if w > d else Vector3(w + 0.5, 1.5, d + 0.5)
			var rm := _mesh(roof, Color(0.75, 0.32, 0.25), c + Vector3(0, h + 0.75, 0))
			rm.rotation.y = deg_to_rad(rot) + (PI / 2.0 if w > d else 0.0)
			var s := BoxShape3D.new()
			s.size = Vector3(w, h, d)
			_solid(Transform3D(basis, c + Vector3(0, h / 2.0, 0)), s)
		var door := WorldDoor.new()
		door.name = "Door_%s" % id
		door.drawn = inst == null
		var msg: Dictionary = b.get("message", {})
		door.npc_name = String(msg.get("title", id.replace("_", " ").capitalize()))
		door.lines = PackedStringArray(msg.get("lines", ["Fechado."]))
		door.color = Color(0.45, 0.3, 0.2)
		door.body_height = 2.0
		var dr: Dictionary = b.get("door", {})
		door.target_scene = String(dr.get("target_scene", ""))
		door.target_spawn = String(dr.get("target_spawn", ""))
		door.position = origin + basis * Vector3(float(b.get("door_dx", 0.0)), 0, front_l)
		door.rotation.y = PI + deg_to_rad(rot)
		add_child(door)
		if dr.has("spawn"):
			arrivals[String(dr.spawn)] = _arrival_pad(
				door.position + basis * Vector3(0, 0, spawn_l)
			)
		var bd: Dictionary = b.get("back_door", {})
		if not bd.is_empty():  # gatehouses: a second door on the back (-Z) face
			var back := WorldDoor.new()
			back.name = "BackDoor_%s" % id
			back.drawn = inst == null
			back.npc_name = door.npc_name
			back.lines = door.lines
			back.color = door.color
			back.body_height = 2.0
			back.target_scene = String(bd.get("target_scene", ""))
			back.target_spawn = String(bd.get("target_spawn", ""))
			back.position = origin + basis * Vector3(float(b.get("door_dx", 0.0)), 0, back_l)
			back.rotation.y = deg_to_rad(rot)
			add_child(back)
			if bd.has("spawn"):
				var ba := back.position + basis * Vector3(0, 0, -spawn_l)
				ba.y = height_at(ba.x, ba.z)  # the gate may sit on a terrace that ends at its back wall
				arrivals[String(bd.spawn)] = _arrival_pad(ba)
		if b.has("board"):
			if inst:
				_board(g, inst, b)
			else:
				var lab := Label3D.new()
				lab.text = String(b.board.get("text", ""))
				lab.font_size = 96
				lab.outline_size = 12
				lab.modulate = Color(b.board.get("color", "#ffffff"))
				lab.position = origin + basis * Vector3(0, h - 0.7, front_l + 0.05)
				add_child(lab)
		_bump("buildings")
		await _tick()


## A door spawn just past the zone edge (gatehouses whose far side opens on the next zone) gets a
## patch of this zone's ground under it, so arriving there never waits for the neighbour to stream in.
func _arrival_pad(at: Vector3) -> Vector3:
	if not rect.grow(0.6).has_point(Vector2(at.x, at.z)):
		_solid_box(at + Vector3(0, -0.5, 0), Vector3(2.0, 1.0, 2.0))
	return at


## The original's sign stand beside a building door (Pokémon Center, Mart, Museum...).
func _board(parent: Node3D, inst: Node3D, b: Dictionary) -> void:
	var bd: Dictionary = b.board
	var bs := float(
		bd.get("scale", BOARD_SCALE_HGSS if String(b.model).begins_with("hgss/") else 1.0)
	)
	var bb := WorldProps.bounds(inst)
	var col := Color(String(bd.get("color", "#d84a3a")))
	var ground := _v(b.pos).y
	var rot := float(b.get("rot", 0.0))
	var quarter := absi(int(rot) % 180) == 90
	var sd := bb.size.x if quarter else bb.size.z
	var origin := Vector2(float(b.pos[0]), float(b.pos[1]))
	var a := deg_to_rad(rot)
	var to_world := func(v: Vector2) -> Vector2:
		return Vector2(
			origin.x + v.x * cos(a) + v.y * sin(a), origin.y - v.x * sin(a) + v.y * cos(a)
		)
	var door := Vector2(float(b.get("door_dx", 0.0)), sd / 2.0)
	var step: Vector2 = to_world.call(door + Vector2(0.0, 0.6 * bs))
	_slab(
		parent,
		Vector3(step.x, ground + 0.03 * bs, step.y),
		Vector3(2.8, 0.06, 1.2) * bs,
		col.lightened(0.55),
		rot
	)
	_slab(
		parent, Vector3(step.x, ground + 0.05 * bs, step.y), Vector3(2.4, 0.06, 0.9) * bs, col, rot
	)
	var text := String(bd.text)
	var ball := bool(bd.get("ball", false))
	var lines := text.split("\n")
	var longest := 0
	for l in lines:
		longest = maxi(longest, l.length())
	var letter := float(bd.get("letter", 0.42)) * bs
	var w := longest * letter * 0.68 + ((0.95 if ball else 0.0) + 0.6) * bs
	var hgt := lines.size() * letter * 1.25 + 0.35 * bs
	var side := float(bd.get("side", 1.0))
	var sign_at: Vector2 = to_world.call(door + Vector2(side * (1.9 * bs + w / 2.0), 0.7 * bs))
	var at := Vector3(sign_at.x, ground + 0.55 * bs + hgt / 2.0, sign_at.y)
	_slab(parent, at, Vector3(w, hgt, 0.14 * bs), col, rot)
	_slab(
		parent,
		at + Vector3(0, hgt / 2.0 + 0.04 * bs, 0),
		Vector3(w + 0.12 * bs, 0.08 * bs, 0.2 * bs),
		col.lightened(0.55),
		rot
	)
	for px in [-w / 2.0 + 0.25 * bs, w / 2.0 - 0.25 * bs]:
		var post: Vector2 = to_world.call(
			door + Vector2(side * (1.9 * bs + w / 2.0) + px, 0.7 * bs)
		)
		_slab(
			parent,
			Vector3(post.x, ground + 0.3 * bs, post.y),
			Vector3(0.12, 0.6, 0.12) * bs,
			Color(0.35, 0.33, 0.32),
			rot
		)
	_solid_box(
		Vector3(at.x, ground + 0.6 * bs, at.z),
		Vector3(0.3 * bs, 1.2 * bs, w) if quarter else Vector3(w, 1.2 * bs, 0.3 * bs)
	)
	var label := Label3D.new()
	label.text = text
	label.font_size = 64
	label.pixel_size = letter / 64.0 * 1.35
	label.outline_size = 10
	label.outline_modulate = Color(0, 0, 0, 0.5)
	label.modulate = Color.WHITE
	label.shaded = false
	label.rotation_degrees.y = rot
	var lp: Vector2 = to_world.call(
		(
			door
			+ Vector2(
				side * (1.9 * bs + w / 2.0) + (0.45 * bs if ball else 0.0), 0.7 * bs + 0.08 * bs
			)
		)
	)
	label.position = Vector3(lp.x, ground + 0.55 * bs + hgt / 2.0, lp.y)
	parent.add_child(label)
	if ball:
		var spr := Sprite3D.new()
		spr.texture = _ball_texture()
		spr.pixel_size = 0.7 * bs / 64.0
		spr.shaded = false
		spr.rotation_degrees.y = rot
		var bp: Vector2 = to_world.call(
			door + Vector2(side * (1.9 * bs + w / 2.0) - w / 2.0 + 0.6 * bs, 0.7 * bs + 0.09 * bs)
		)
		spr.position = Vector3(bp.x, ground + 0.55 * bs + hgt / 2.0, bp.y)
		parent.add_child(spr)


func _slab(parent: Node3D, center: Vector3, size: Vector3, col: Color, rot_deg := 0.0) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.7
	bm.material = m
	mi.mesh = bm
	mi.position = center
	mi.rotation_degrees.y = rot_deg
	parent.add_child(mi)


static var _ball_tex: Texture2D


static func _ball_texture() -> Texture2D:
	if _ball_tex:
		return _ball_tex
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var c := Vector2(31.5, 31.5)
	for y in 64:
		for x in 64:
			var d := Vector2(x, y).distance_to(c)
			var col := Color(0, 0, 0, 0)
			if d <= 30.0:
				col = Color(0.88, 0.16, 0.16) if y < 29 else Color(0.97, 0.97, 0.95)
				if d > 27.5 or absf(y - 31.5) < 3.0:
					col = Color(0.08, 0.08, 0.1)
				if d < 9.0:
					col = Color(0.08, 0.08, 0.1)
				if d < 6.0:
					col = Color(0.97, 0.97, 0.95)
			img.set_pixel(x, y, col)
	_ball_tex = ImageTexture.create_from_image(img)
	return _ball_tex


func _fences() -> void:
	for f in data.get("fences", []):
		var a := Vector3(float(f.from[0]), 0, float(f.from[1]))
		var b := Vector3(float(f.to[0]), 0, float(f.to[1]))
		var mid := (a + b) / 2.0
		mid.y = height_at(mid.x, mid.z)
		var len := a.distance_to(b)
		var yaw := atan2(-(b - a).z, (b - a).x)
		# Original defaults: a Kenney nature/fence_simple at scale 2 (Viridian's grove fence has no model).
		var model := String(f.get("model", "nature/fence_simple"))
		var s := float(f.get("scale", 2.0))
		if WorldProps.exists(model):
			# Original: n pieces of the model's native width, stretched to fill the run exactly, each
			# re-centred on its slot (Kenney pieces have their origin on a corner).
			var lb := model_box(model)
			var native := maxf(lb.size.x * s, 0.01)
			var n := maxi(int(round(len / native)), 1)
			var k := len / n / native
			var basis := Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(s * k, s, s))
			var c := basis * Vector3(lb.get_center().x, 0.0, lb.get_center().z)
			for i in n:
				var at := a.lerp(b, (i + 0.5) / n)
				at.y = height_at(at.x, at.z)
				_add_model(model, Transform3D(basis, at - c))
		else:
			var xf := Transform3D(Basis(Vector3.UP, yaw), mid + Vector3(0, 0.45, 0))
			_add("fence", xf.scaled_local(Vector3(len + 0.1, 0.9, 0.12)))
		var sh := BoxShape3D.new()
		sh.size = Vector3(len + 0.1, 1.4, 0.3)
		_solid(Transform3D(Basis(Vector3.UP, yaw), mid + Vector3(0, 0.7, 0)), sh)
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
		_solid_box(
			Vector3(r[0] + r[2] / 2.0, WALL_H / 2.0, r[1] + r[3] / 2.0),
			Vector3(r[2], WALL_H, r[3]),
			body
		)
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
			var c := (
				Vector3(mid, WALL_H / 2.0, fixed + outward)
				if hz
				else Vector3(fixed + outward, WALL_H / 2.0, mid)
			)
			_solid_box(c, Vector3(len, WALL_H, 1.0) if hz else Vector3(1.0, WALL_H, len))
			_bump("bounds")


# --- vegetation & props --------------------------------------------------------------------------


## A tree, like the original world_builder._tree: HGSS billboard card (batched) at HGSS_SCALE, or a
## Kenney tree at KENNEY_TREE_SCALE widened 1.2-1.4x in x/z; random yaw; a trunk collider sized
## from the placed model (radius max(18% of its width, 0.3), height its own) unless `collide` is
## false (map "cover" trees). Placeholder trunk + crown if the model is missing.
func _tree(at: Vector3, s: float, model := HGSS_TREE, collide := true) -> void:
	var yaw := deg_to_rad(_rng.randi_range(0, 359))
	var hgss := model.begins_with("hgss/")
	var sc := (HGSS_SCALE if hgss else KENNEY_TREE_SCALE) * s
	var ok := false
	if hgss:
		ok = _add_model(
			model, _scaled(at, Vector3.ONE * sc, yaw), {"billboard": true, "tint": HGSS_TREE_TINT}
		)
	else:
		var wide := _rng.randf_range(1.2, 1.4)
		var pal := _palette(_look.get("tree_palette", {}))
		ok = _add_model(
			model,
			_scaled(at, Vector3(sc * wide, sc, sc * wide), yaw),
			{"palette": pal} if not pal.is_empty() else {}
		)
	if not ok:
		_placeholder_tree(at, s, yaw)
	if collide:
		if ok:
			var bb := placed_box(model, sc, yaw)
			_solid_cyl(at, maxf(bb.size.x * 0.18, 0.3), maxf(bb.size.y, 1.5))
		else:
			_solid_cyl(at, 0.45 * s, 3.0 * s)
	if leaf_points.size() < 4000:
		leaf_points.append(at)
	_bump("trees")


func _placeholder_tree(at: Vector3, s: float, yaw: float) -> void:
	_add("trunk", _scaled(at + Vector3(0, 0.8 * s, 0), Vector3.ONE * s))
	_add("crown", _scaled(at + Vector3(0, 2.4 * s, 0), Vector3(2.4, 2.2, 2.4) * s, yaw))


## Tree lines: rows of trees spaced by the first model's width (original: step and row offset 85%
## of the HGSS tree's width at HGSS_SCALE, odd rows staggered by half of it; Kenney 2.3 / 2.1 / 1.15),
## jittered +-0.4 m, a random model of the line per tree. Then the single trees of the map.
func _trees() -> void:
	for t in data.get("tree_lines", []):
		var a := Vector3(float(t.from[0]), 0, float(t.from[1]))
		var b := Vector3(float(t.to[0]), 0, float(t.to[1]))
		var o: Array = t.get("out", [0, 0])
		var out := Vector3(float(o[0]), 0, float(o[1]))
		var models: Array = t.get("models", [HGSS_TREE])
		var step := 2.3
		var row_off := 2.1
		var stagger := 1.15
		if String(models[0]).begins_with("hgss/"):
			var w := placed_box(String(models[0]), HGSS_SCALE).size.x
			if w > 0.01:
				step = w * 0.85
				row_off = w * 0.85
				stagger = w * 0.5
		var n := maxi(int(a.distance_to(b) / step), 1)
		for row in int(t.get("rows", 2)):
			var off := (
				out * (row * row_off)
				+ (Vector3.ZERO if row % 2 == 0 else (b - a).normalized() * stagger)
			)
			for i in n + 1:
				var p := (
					a.lerp(b, float(i) / n)
					+ off
					+ Vector3(_rng.randf_range(-0.4, 0.4), 0, _rng.randf_range(-0.4, 0.4))
				)
				p.y = height_at(p.x, p.z)
				_tree(p, _rng.randf_range(0.9, 1.15), String(models[_rng.randi() % models.size()]))
		await _tick()
	for t in data.get("trees", []):
		_tree(
			_at(t),
			_rng.randf_range(0.9, 1.15),
			String(t.get("model", HGSS_TREE)),
			not bool(t.get("cover", false))
		)
		await _tick()


func _props() -> void:
	var rock_pal := _palette(_look.get("rock_palette", {}))
	var tree_pal := _palette(_look.get("tree_palette", {}))
	var g := _group("Props")
	for p in data.get("props", []):
		var mid := String(p.get("model", ""))
		var model := mid.get_file()
		var at := _at(p) + Vector3(0, float(p.get("dy", 0.0)), 0)
		var s := float(p.get("scale", 2.0))  # original world_builder._props default
		var yaw := deg_to_rad(float(p.get("rot", 0.0)))
		var collide := String(p.get("collide", ""))
		var sprite := String(p.get("sprite", "")) != ""
		if bool(p.get("cave", false)):
			_cave_mouth(g, p)
		elif sprite:
			_sprite_prop(g, p)
		elif WorldProps.exists(mid):
			var opts := {}
			if mid == HGSS_TREE or mid == HGSS_BUSH or mid == "hgss/common/bush_tall":
				opts = {"billboard": true, "tint": HGSS_TREE_TINT}
			elif mid == HGSS_BOULDER:
				opts = {"billboard": true, "sway": 0.0}
			elif (
				not rock_pal.is_empty()
				and (mid.begins_with("nature/rock") or mid.begins_with("nature/cliff"))
			):
				opts = {"palette": rock_pal}
			elif not tree_pal.is_empty() and mid.begins_with("nature/"):
				opts = {"palette": tree_pal}
			var light := bool(p.get("light", false))
			var small := bool(p.get("small", false))
			if (
				light
				or mid.contains("lamp")
				or mid.contains("camp_light")
				or mid.contains("fountain")
			):
				var o := opts.duplicate()
				o.merge({"scale": s, "rot": float(p.get("rot", 0.0)), "light": light})
				if small:
					o["shadow"] = false
				WorldProps.place(g, mid, at, o)
			else:
				_add_model(mid, _scaled(at, Vector3.ONE * s, yaw), opts, not small)
			if mid == HGSS_TREE or mid == HGSS_BUSH:
				leaf_points.append(at)
		elif model == "bush":
			_add("bush", _scaled(at + Vector3(0, 0.4 * s, 0), Vector3(1.1, 0.9, 1.1) * s))
		elif model.begins_with("rock"):
			_add("rock", _scaled(at + Vector3(0, 0.1, 0), Vector3(0.6, 0.35, 0.5) * s, yaw))
		elif model == "lamp":
			_add("post", _scaled(at + Vector3(0, 1.2, 0), Vector3(0.14, 2.4, 0.14)))
			_add("bulb", _scaled(at + Vector3(0, 2.5, 0), Vector3.ONE * 0.4))
		elif model == "fountain":
			_add("box", _scaled(at + Vector3(0, 0.3, 0), Vector3(2.6, 0.6, 2.6)))
			_add("post", _scaled(at + Vector3(0, 0.9, 0), Vector3(0.4, 1.2, 0.4)))
		elif model.begins_with("camp_"):
			_add("wood", _scaled(at + Vector3(0, 0.3, 0), Vector3(1.2, 0.6, 0.5), yaw))
		else:
			_add("box", _scaled(at + Vector3(0, 0.3, 0), Vector3(0.6, 0.6, 0.6), yaw))
		if collide != "" and not sprite and not bool(p.get("cave", false)):
			if WorldProps.exists(mid):
				_prop_collider(mid, at, s, yaw, collide, p)
			else:
				match collide:
					"round":
						_solid_cyl(_at(p), 0.45 * s, 1.2)
					"trunk":
						_solid_cyl(_at(p), 0.15, 2.4)
					"box":
						var size := (
							Vector3(2.6, 1.2, 2.6)
							if model == "fountain"
							else Vector3(0.6, 1.2, 0.6)
						)
						_solid_box(_at(p) + Vector3(0, size.y / 2.0, 0), size)
		_bump("props")
		await _tick()


## Collider of a model prop sized from the placed model, like the original Props.place "collide":
## "box" = its bounds (at least 1 m tall), "trunk" = cylinder of radius max(18% of its width, 0.3),
## "round" = cylinder of radius collide_radius or half its larger side (min 0.2); cylinders are as
## tall as the model, at least 1.5 m.
func _prop_collider(
	id: String, at: Vector3, s: float, yaw: float, kind: String, p: Dictionary
) -> void:
	var bb := placed_box(id, s, yaw)
	bb.position += at
	match kind:
		"box":
			var h := maxf(bb.size.y, 1.0)
			_solid_box(
				Vector3(bb.get_center().x, bb.position.y + h / 2.0, bb.get_center().z),
				Vector3(maxf(bb.size.x, 0.2), h, maxf(bb.size.z, 0.2))  # flat cards get some depth
			)
		"trunk":
			_solid_cyl(at, maxf(bb.size.x * 0.18, 0.3), maxf(bb.size.y, 1.5))
		"round":
			var r := float(p.get("collide_radius", maxf(bb.size.x, bb.size.z) * 0.5))
			_solid_cyl(at, maxf(r, 0.2), maxf(bb.size.y, 1.5))


## Billboard prop sprite of the original (training dummies: prop_dummy_*.png).
func _sprite_prop(parent: Node3D, p: Dictionary) -> void:
	var tex := WorldFx.tex("sprites/%s.png" % String(p.sprite))
	var collide := String(p.get("collide", "")) != ""
	if tex == null:
		_add("wood", _scaled(_at(p) + Vector3(0, 0.5, 0), Vector3(0.5, 1.0, 0.5)))
		if collide:
			_solid_box(_at(p) + Vector3(0, 0.6, 0), Vector3(0.6, 1.2, 0.6))
		return
	var h := float(p.get("height", 1.3))
	var spr := Sprite3D.new()
	spr.name = String(p.sprite)
	spr.texture = tex
	spr.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	spr.shaded = true
	spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	spr.pixel_size = h / maxf(1.0, float(tex.get_height()))
	spr.position = _at(p) + Vector3(0, h / 2.0, 0)
	parent.add_child(spr)
	if collide:  # original: a wall as wide as the sprite, 0.4 m deep
		_solid_box(
			spr.position, Vector3(h * float(tex.get_width()) / float(tex.get_height()), h, 0.4)
		)


func _cave_mouth(parent: Node3D, p: Dictionary) -> void:
	var size: Array = p.get("size", [2.4, 1.9])
	var grad := Gradient.new()
	grad.set_color(0, Color(String(p.get("base", "#242428"))))
	grad.set_color(1, Color(String(p.get("top", "#060608"))))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 1)
	gt.fill_to = Vector2(0, 0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = gt
	var qm := QuadMesh.new()
	qm.size = Vector2(float(size[0]), float(size[1]))
	var mi := MeshInstance3D.new()
	mi.name = "CaveMouth"
	mi.mesh = qm
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = _v(p.pos) + Vector3(0, float(size[1]) / 2.0, 0)
	mi.rotation_degrees.y = float(p.get("rot", 0.0))
	parent.add_child(mi)


func _palette(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[k] = Color(String(d[k]))
	return out


static func _flower_material(kind: int) -> StandardMaterial3D:
	if _flower_mats.has(kind):
		return _flower_mats[kind]
	var frames := AnimatedTexture.new()
	frames.frames = 3
	for f in 3:
		frames.set_frame_texture(
			f, WorldFx.tex("models/hgss/common/flower%02d_%d.png" % [kind, f + 1])
		)
		frames.set_frame_duration(f, HGSS_FLOWER_SECONDS)
	var m := StandardMaterial3D.new()
	m.albedo_texture = frames
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.roughness = 1.0
	_flower_mats[kind] = m
	return m


## HGSS animated flower tiles (beds with "tile") or scattered Kenney flowers.
func _flowers() -> void:
	var tiles := [[], []]
	for bed in data.get("flower_beds", []):
		var c := _at(bed)
		var radius := float(bed.get("radius", 1.0))
		if bool(bed.get("tile", false)) or not decorate:
			var reach := int(ceil(radius))
			for i in range(-reach, reach + 1):
				for j in range(-reach, reach + 1):
					if Vector2(i, j).length() <= radius:
						tiles[_rng.randi() % 2].append(
							Transform3D(Basis(), Vector3(c.x + i, c.y + HGSS_FLOWER_Y, c.z + j))
						)
		else:
			for i in int(bed.get("count", 8)):
				var r := sqrt(_rng.randf()) * radius
				var a := _rng.randf() * TAU
				_add_model(
					FLOWER_KINDS[_rng.randi() % FLOWER_KINDS.size()],
					_scaled(
						c + Vector3(cos(a), 0, sin(a)) * r,
						Vector3.ONE * 2.0,
						deg_to_rad(_rng.randi_range(0, 359))
					),
					{},
					false
				)
		_bump("flowers")
	var quad := PlaneMesh.new()
	quad.size = Vector2.ONE
	for k in 2:
		if tiles[k].is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var q: PlaneMesh = quad.duplicate()
		q.material = _flower_material(k + 1)
		mm.mesh = q
		mm.instance_count = tiles[k].size()
		for i in tiles[k].size():
			mm.set_instance_transform(i, tiles[k][i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "FlowerTiles%d" % (k + 1)
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)


func _backdrop() -> void:
	var b: Variant = data.get("backdrop", null)
	if not (b is Dictionary):
		return
	var path := art_path(String(b.get("texture", "")))
	if path == "" or not ResourceLoader.exists(path):
		return
	var pos: Array = b.get("pos", [0, 0])
	var h := float(b.get("height", 0.0))
	var w := float(b.get("width", 0.0))
	if h <= 0.0 or w <= 0.0:
		return
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = load(path)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var qm := QuadMesh.new()
	qm.size = Vector2(w, h)
	var mi := MeshInstance3D.new()
	mi.name = "Backdrop"
	mi.mesh = qm
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var base_y: Variant = b.get("base_y", null)
	mi.position = Vector3(
		float(pos[0]),
		(float(base_y) if base_y != null else height_at(float(pos[0]), float(pos[1]))) + h * 0.5,
		float(pos[1])
	)
	add_child(mi)


## Kenney grass tufts scattered over the meadows (original "scatter" layers), one MultiMesh per model.
func _scatter() -> void:
	for layer in data.get("scatter", []):
		var out := {}
		for id in layer.models:
			out[id] = []
		var noise := FastNoiseLite.new()
		noise.seed = hash(String(layer.get("name", "")) + zone_id)
		noise.frequency = 0.15
		var clump := float(layer.get("clump", 0.0))
		var sc: Array = layer.get("scale", [1.4, 2.4])
		for a in layer.areas:
			for i in int(float(a[2]) * float(a[3]) * float(layer.density)):
				var p := Vector3(
					_rng.randf_range(a[0], a[0] + a[2]), 0, _rng.randf_range(a[1], a[1] + a[3])
				)
				if clump > 0.0 and noise.get_noise_2d(p.x, p.z) * 0.5 + 0.5 < clump:
					continue
				if _blocked(p):
					continue
				p.y = height_at(p.x, p.z)
				var b := Basis(Vector3.UP, _rng.randf() * TAU).scaled(
					Vector3.ONE * _rng.randf_range(float(sc[0]), float(sc[1]))
				)
				out[layer.models[_rng.randi() % layer.models.size()]].append(Transform3D(b, p))
			await _tick()
		var pal := _palette(layer.get("palette", {}))
		for id in out:
			var xs: Array = out[id]
			var bm := WorldProps.batch_mesh(id, {"palette": pal, "stylize": false})
			if xs.is_empty() or bm.is_empty():
				continue
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.mesh = bm[0]
			mm.instance_count = xs.size()
			for i in xs.size():
				mm.set_instance_transform(i, xs[i])
				var v := _rng.randf_range(0.88, 1.08)
				mm.set_instance_color(i, Color(v, v, v * 0.97))
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "%s_%s" % [String(layer.get("name", "Scatter")), String(id).get_file()]
			mmi.multimesh = mm
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.visibility_range_end = 70.0
			add_child(mmi)
			_bump("scatter", xs.size())


func _blocked(p: Vector3) -> bool:
	for r in data.get("paths", []):
		if (
			p.x > r[0] - 0.4
			and p.x < r[0] + r[2] + 0.4
			and p.z > r[1] - 0.4
			and p.z < r[1] + r[3] + 0.4
		):
			return true
	for w in data.get("water", []):
		var r: Array = w.rect
		if (
			p.x > r[0] - 1.0
			and p.x < r[0] + r[2] + 1.0
			and p.z > r[1] - 1.0
			and p.z < r[1] + r[3] + 1.0
		):
			return true
	for b in data.get("buildings", []):
		if absf(p.x - b.pos[0]) < 6.0 and absf(p.z - b.pos[1]) < 5.5:
			return true
	for g in data.get("tall_grass", []):
		var gp: Array = g.pos
		var gs: Array = g.get("size", [6, 4])
		if absf(p.x - gp[0]) < gs[0] / 2.0 + 0.5 and absf(p.z - gp[1]) < gs[1] / 2.0 + 0.5:
			return true
	for c in data.get("courts", []):
		var r: Array = c.rect
		if p.x > r[0] and p.x < r[0] + r[2] and p.z > r[1] and p.z < r[1] + r[3]:
			return true
	for pl in data.get("plateaus", []):
		var r: Array = pl.rect
		var near_x := absf(p.x - r[0]) < 0.6 or absf(p.x - (r[0] + r[2])) < 0.6
		var near_z := absf(p.z - r[1]) < 0.6 or absf(p.z - (r[1] + r[3])) < 0.6
		var in_x: bool = p.x > r[0] - 0.6 and p.x < r[0] + r[2] + 0.6
		var in_z: bool = p.z > r[1] - 0.6 and p.z < r[1] + r[3] + 0.6
		if (near_x and in_z) or (near_z and in_x):
			return true
		for s in pl.get("ramps", []):
			var run := float(pl.h) * RAMP_SLOPE + 0.5
			var half := float(s.width) / 2.0 + 0.6
			match String(s.side):
				"e":
					if (
						p.x > r[0] + r[2] - 0.5
						and p.x < r[0] + r[2] + run
						and absf(p.z - s.at) < half
					):
						return true
				"w":
					if p.x < r[0] + 0.5 and p.x > r[0] - run and absf(p.z - s.at) < half:
						return true
				"n":
					if p.z < r[1] + 0.5 and p.z > r[1] - run and absf(p.x - s.at) < half:
						return true
				"s":
					if (
						p.z > r[1] + r[3] - 0.5
						and p.z < r[1] + r[3] + run
						and absf(p.x - s.at) < half
					):
						return true
	return false


func _sun_shafts() -> void:
	for s in data.get("sun_shafts", []):
		var n := WorldSunShaft.new()
		n.radius = float(s.get("radius", 2.2))
		n.height = float(s.get("height", 9.0))
		n.tilt_deg = float(s.get("tilt", 10.0))
		n.opacity = float(s.get("opacity", 0.2))
		n.shaft_seed = int(s.get("seed", 0))
		n.position = _v(s.pos)
		_group("SunShafts").add_child(n)
		_bump("sun_shafts")


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
		out.append(
			String(l).replace("{PLAYER}", String(pn) if pn else "RED").replace(
				"{RIVAL}", String(rn) if rn else "BLUE"
			)
		)
	return out


func _people() -> void:
	for s in data.get("signs", []):
		var sp := SignPost.new()
		sp.name = String(s.get("name", "Sign"))
		sp.npc_name = String(s.get("title", "Placa"))
		sp.lines = fill_names(s.get("lines", []))
		sp.color = Color(0.55, 0.4, 0.25)
		sp.body_height = 1.2
		sp.model = String(s.get("model", "hgss/common/sign_a"))
		sp.model_scale = float(s.get("model_scale", 0.8))
		sp.model_rot = float(s.get("rot", 180.0))
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
		npc.sprite_sheet = String(n.get("sprite", ""))
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
		tr.sprite_sheet = String(t.get("sprite", ""))
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

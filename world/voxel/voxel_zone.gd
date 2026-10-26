class_name VoxelZone
extends MapBuilder
## A zone drawn in voxels (docs/VOXEL.md §5; design format in VoxelDesign): the map JSON
## (data/maps/<id>.json) stays the source of the gameplay (NPCs, signs, items, spawn zones,
## triggers, arrivals, doors) and its "voxel" entry names the design (data/voxel/<id>.json). The
## scenery comes from the bake (world/voxel/baked/<id>.res + .json, tools/voxel/bake_zone.gd): chunk
## meshes sharing one voxel material, each house's parts registered with the camera fader, instanced
## trees and decor, water surfaces, the fountain's FountainFx and the lamps' night lights. A stale
## or missing bake is regenerated in-process (slow, with a warning). Collision follows the baked
## TileGrid: merged boxes over blocked tiles (layer 1) and water tiles (the Water body), so walking
## matches the grid. When streaming (items_per_frame > 0) the bake loads on a thread and the nodes
## are added a few per frame, so walking back from Route 1 never stalls.

const FADE_GROW := 0.6  ## house fader rect past the footprint (eaves)
const TOWN_TREE_FADE := 2.6  ## half size of a town tree's fader rect
const PROP_FADE := 0.7  ## half size of a tall prop's fader rect (lamps)
const LAMP_ENERGY := 1.2  ## OmniLight energy per metadata energy unit
const GLASS_ALPHA := 0.55  ## transparency of a "glass" building part (greenhouse panes)
## Lamplight in the windows at night (voxel.gdshader window_glow): a deep orange, since AgX
## desaturates bright light (the cream window voxels came out white); on screen it reads amber.
const WINDOW_GLOW := Color("ff6e10")
const WINDOW_EMIT := 2.0  ## voxel.gdshader emit_window for the zone (brighter goes peach)
## Sky-light floor of the decor, trees and props (voxel_detail / voxel.gdshader shade_lift): in the
## shade SDFGI left the sides of grass tufts and the undersides of the bushes black.
const SHADE_LIFT := 0.1
const BUILD_STEP := 6  ## nodes added per frame while streaming
const WEATHER_GROUP := "weather"  ## WorldWeather.GROUP (by name: no compile-time dependency)
const SNOW_BURY := 0.45  ## snow cover (global snow_cover) that buries flowers and tall grass
## Decor buried by deep snow besides VoxelFlora.FLOWERS / WILD: green tufts, fallen leaves,
## petals and apples, mushrooms, pebbles and shells (dry tufts and ferns still poke through).
const SNOW_BURIES := [
	"sunflower",
	"tuft_0",
	"tuft_1",
	"tuft_2",
	"tuft_dark",
	"tuft_tall",
	"grass_clump",
	"clover",
	"iris",
	"sprout",
	"leaves",
	"petals",
	"windfall",
	"mushroom_brown",
	"mushroom_red",
	"pebble_0",
	"pebble_1",
	"pebble_2",
	"pebble_3",
	"pebble_4",
	"shell",
]
## Washing-line garments (VoxelZone._laundry): the order they are pegged in, sizes (m), tints.
const LAUNDRY := ["shirt", "towel", "sheet", "trousers", "shirt", "towel", "socks"]
const LAUNDRY_SIZE := {
	"shirt": Vector2(0.55, 0.55),
	"towel": Vector2(0.42, 0.62),
	"sheet": Vector2(0.95, 0.85),
	"trousers": Vector2(0.42, 0.72),
	"socks": Vector2(0.28, 0.26),
}
const LAUNDRY_TINTS := [
	Color("f4f1e8"),
	Color("d9534a"),
	Color("4f86c6"),
	Color("f2c14e"),
	Color("7fb069"),
	Color("e8a0b4"),
]

var bake: VoxelZoneBake
var voxel_material: ShaderMaterial
var stale := false  ## the bake did not match (regenerated in-process)
var load_ms := 0  ## time spent loading / building the scenery (tests)
var lights: Array[OmniLight3D] = []
var houses: Dictionary = {}  ## building id -> Node3D (fader, metas rect / height / geoms / parts)
var water_surfaces: Array[MeshInstance3D] = []  ## one per water body (gfx/water WaterSurface)
var fountain: FountainFx
var butterflies: GPUParticles3D  ## day-only life over the flower beds

var _tree_mats := {}
var _decor_mats := {}
var _part_of := {}  ## building part id -> building entry (bake metadata)
var _buried: Array[MultiMeshInstance3D] = []  ## decor hidden under deep snow
var _snow_on := false
var _snow_poll := 0.0


func build() -> void:
	var t0 := Time.get_ticks_msec()
	data = load_map(zone_id)
	if data.is_empty():
		push_error("VoxelZone: no map data for '%s'" % zone_id)
		is_built = true
		built.emit()
		return
	for k in extras:
		data[k] = data.get(k, []) + extras[k]
	rect = rect_of(data.get("rect", [0, 0, 10, 10]))
	_look = data.get("look", {})
	_rng.seed = hash(zone_id)
	signs_drawn = false
	_solids = _body("Solids", Overworld.WALL_LAYER)
	_water_body = _body("Water", WATER_LAYER)
	await _load_bake()
	grid = bake.tiles
	_ground_collider()
	_tile_colliders()
	await _scenery()
	_doors()
	_walls()
	_bounds()
	await _spawn_zones()
	await _people()
	for a in data.get("arrivals", []):
		arrivals[String(a.name)] = _at(a)
	load_ms = Time.get_ticks_msec() - t0
	is_built = true
	if is_inside_tree():
		var tod := get_tree().get_first_node_in_group(WorldTimeOfDay.GROUP)
		if tod:
			tod.refresh()
	built.emit()


func _design_id() -> String:
	return String(voxel_info(zone_id).get("design", zone_id))


## The baked scenery: threaded load while streaming, blocking otherwise; regenerated when stale.
func _load_bake() -> void:
	var id := _design_id()
	var path := VoxelZoneBake.res_path(id)
	var j := VoxelZoneBake.read_json(id)
	var fresh := not j.is_empty() and String(j.get("hash", "")) == VoxelZoneGen.input_hash(id)
	if fresh and ResourceLoader.exists(path):
		var res: Resource = null
		if items_per_frame > 0 and is_inside_tree():
			if ResourceLoader.load_threaded_request(path) == OK:
				while (
					ResourceLoader.load_threaded_get_status(path)
					== ResourceLoader.THREAD_LOAD_IN_PROGRESS
				):
					await get_tree().process_frame
				res = ResourceLoader.load_threaded_get(path)
		else:
			res = ResourceLoader.load(path)
		bake = res as VoxelZoneBake
		if bake:
			bake.attach_json(j)
	if bake == null:
		stale = true
		push_warning(
			(
				"VoxelZone %s: baked scenery missing or stale; generating it now (run tools/voxel/bake_zone.gd)"
				% id
			)
		)
		var gen := VoxelZoneGen.run(id)
		bake = VoxelZoneBake.from_gen(gen) if gen else VoxelZoneBake.new()
		if gen == null:
			bake.tiles = TileGrid.new(
				Vector2i(roundi(rect.position.x + 0.5), roundi(rect.position.y + 0.5)),
				Vector2i(rect.size)
			)
			bake.meta = {}
		else:
			# The in-process bake carries its metadata as live values; round-trip it like the JSON.
			bake.meta = JSON.parse_string(JSON.stringify(bake.meta))


# --- collision -----------------------------------------------------------------------------------


func _ground_collider() -> void:
	var g := rect.grow(1.0)
	_solid_box(Vector3(g.get_center().x, -0.5, g.get_center().y), Vector3(g.size.x, 1.0, g.size.y))
	_bump("ground")


## Greedy rectangles over the tile grid: blocked tiles -> wall boxes, water tiles -> Water body.
func _tile_colliders() -> void:
	var tg := grid
	var n := tg.size.x * tg.size.y
	for pass_i in 2:
		var want := TileGrid.BLOCKED if pass_i == 0 else TileGrid.WATER
		var used := PackedByteArray()
		used.resize(n)
		for z in tg.size.y:
			for x in tg.size.x:
				if used[x + z * tg.size.x] or not _is(tg, x, z, want):
					continue
				var w := 1
				while (
					x + w < tg.size.x
					and not used[x + w + z * tg.size.x]
					and _is(tg, x + w, z, want)
				):
					w += 1
				var h := 1
				var grow := true
				while z + h < tg.size.y and grow:
					for q in w:
						if used[x + q + (z + h) * tg.size.x] or not _is(tg, x + q, z + h, want):
							grow = false
							break
					if grow:
						h += 1
				for hz in h:
					for q in w:
						used[x + q + (z + hz) * tg.size.x] = 1
				var c := Vector2(tg.origin.x + x - 0.5 + w / 2.0, tg.origin.y + z - 0.5 + h / 2.0)
				var tall := VoxelZoneGen.SOLID_H if pass_i == 0 else WALL_H
				_solid_box(
					Vector3(c.x, tall / 2.0, c.y),
					Vector3(w, tall, h),
					_solids if pass_i == 0 else _water_body
				)
				_bump("tile_boxes" if pass_i == 0 else "water_boxes")


static func _is(tg: TileGrid, x: int, z: int, want: int) -> bool:
	var f := tg.flags[x + z * tg.size.x]
	if want == TileGrid.WATER:
		return f & TileGrid.WATER != 0
	return f & TileGrid.BLOCKED != 0 and f & TileGrid.WATER == 0


# --- scenery -------------------------------------------------------------------------------------


func _step() -> void:
	if items_per_frame > 0 and is_inside_tree():
		_count += 1
		if _count % BUILD_STEP == 0:
			await get_tree().process_frame


func _scenery() -> void:
	var root := _group("Voxel")
	var meta: Dictionary = bake.meta
	if bake.meshes.is_empty():
		return
	# The 3D colour texture: decompressed on a worker thread while streaming, uploaded here.
	var box: Array = []
	if items_per_frame > 0 and is_inside_tree():
		var task := WorkerThreadPool.add_task(func() -> void: box.append(bake.volume_layers()))
		while not WorkerThreadPool.is_task_completed(task):
			await get_tree().process_frame
		WorkerThreadPool.wait_for_task_completion(task)
	else:
		box.append(bake.volume_layers())
	var vol := bake.volume_from(box[0])
	voxel_material = _grid_material(vol[0], vol[1], bake.grid_origin, bake.grid_size)
	await _step()
	var part_of := _part_of
	for b in meta.get("buildings", []):
		var parts: Dictionary = b.get("parts", {})
		for k in parts:
			part_of[int(parts[k])] = b
	for i in bake.meshes.size():
		var prt := bake.mesh_parts[i]
		var mi := MeshInstance3D.new()
		mi.mesh = bake.meshes[i]
		mi.material_override = voxel_material
		if part_of.has(prt):
			var house := _house(part_of[prt])
			var pn := _part_name(part_of[prt], prt)
			mi.name = "%s%d" % [pn, i]
			house.add_child(mi)
			if pn == "Glass":
				# Greenhouse panes: always see-through (the fader leaves them alone).
				mi.transparency = GLASS_ALPHA
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			else:
				house.get_meta("geoms").append(mi)
		else:
			mi.name = "Chunk%d" % i
			root.add_child(mi)
		_bump("voxel_meshes")
		await _step()
	for h in houses.values():
		WorldProps.register_fader(h, h.get_meta("rect"))
	await _instances(root)
	_water_surfaces(meta)
	_fountains(meta)
	_lights(meta)
	_smoke(meta)
	_butterflies(meta)
	_flags(meta)
	_laundry(meta)
	_bump("voxel")


func _grid_material(tex: Texture3D, tops: Texture2D, o: Vector3i, s: Vector3i) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = VoxelMat.shader("voxel")
	m.set_shader_parameter("vox", tex)
	m.set_shader_parameter("tops", tops)
	m.set_shader_parameter("mat_lut", VoxelMat.lut())
	m.set_shader_parameter("grid_origin", o)
	m.set_shader_parameter("grid_size", s)
	m.set_shader_parameter("window_glow", WINDOW_GLOW)
	m.set_shader_parameter("emit_window", WINDOW_EMIT)
	return m


static func _part_name(b: Dictionary, prt: int) -> String:
	var parts: Dictionary = b.get("parts", {})
	for k in parts:
		if int(parts[k]) == prt:
			return String(k).capitalize()
	return "Part"


## The fader node of a building (made on first use).
func _house(b: Dictionary) -> Node3D:
	var id := String(b.id)
	if houses.has(id):
		return houses[id]
	var n := Node3D.new()
	n.name = "House_%s" % id
	var r: Array = b.rect
	var rr := Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])).grow(FADE_GROW)
	n.set_meta("rect", rr)
	n.set_meta("height", float(b.get("height", 6.0)))
	n.set_meta("geoms", [])
	n.set_meta("parts", b.get("parts", {}))
	n.add_to_group("fade_building")
	_group("Voxel").add_child(n)
	houses[id] = n
	_bump("houses")
	return n


## Trees and props (MultiMesh per model and chunk; town trees and tall props one by one so they
## fade alone) and decor.
func _instances(root: Node3D) -> void:
	var trees := _group("Trees")
	var decor := _group("Decor")
	for e in bake.multimeshes:
		var mm := bake.multimesh(e)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		var model := String(e.model)
		var part := int(e.get("part", 0))
		if part > 0 and _part_of.has(part):
			# Building furniture (gutters, wall lanterns, window-box flowers): fades with its house.
			var house := _house(_part_of[part])
			mmi.name = "%s_%d" % [model, house.get_child_count()]
			if String(e.kind) == "decor":
				mmi.material_override = _decor_mat(model)
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				_bump("decor", mm.instance_count)
			else:
				mmi.material_override = _tree_mat(model)
				_bump("props", mm.instance_count)
			house.add_child(mmi)
			house.get_meta("geoms").append(mmi)
		elif String(e.kind) == "tree":
			mmi.name = "%s_%d" % [model, trees.get_child_count()]
			mmi.material_override = _tree_mat(model)
			trees.add_child(mmi)
			var bb := mm_aabb(mm, e)
			var r := Rect2(bb.position.x, bb.position.z, bb.size.x, bb.size.z)
			if bool(e.get("town", false)) and mm.instance_count == 1:
				var p := VoxelZoneBake.entry_xf(e).origin
				r = fade_rect(bb, TOWN_TREE_FADE, TOWN_TREE_FADE)
				if not model.begins_with("bush") and not model.begins_with("shrub"):
					leaf_points.append(p + Vector3(0, 4.0, 0))
			if bb.size.y > 2.0:
				mmi.set_meta("rect", r)
				mmi.set_meta("height", bb.end.y)
				mmi.set_meta("geoms", [mmi])
				WorldProps.register_fader(mmi, r)
			_bump("trees", mm.instance_count)
		elif String(e.kind) == "prop":
			mmi.name = "%s_%d" % [model, trees.get_child_count()]
			mmi.material_override = _tree_mat(model)
			trees.add_child(mmi)
			if bool(e.get("town", false)) and mm.instance_count == 1:
				var pb := mm_aabb(mm, e)
				var r := fade_rect(pb, PROP_FADE, PROP_FADE)
				mmi.set_meta("rect", r)
				mmi.set_meta("height", pb.end.y)
				mmi.set_meta("geoms", [mmi])
				WorldProps.register_fader(mmi, r)
			_bump("props", mm.instance_count)
		else:
			mmi.name = "%s_%d" % [model.replace(":", "_"), decor.get_child_count()]
			mmi.material_override = _decor_mat(model)
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.visibility_range_end = VoxelZoneBake.DECOR_RANGE
			mmi.visibility_range_end_margin = 6.0
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			decor.add_child(mmi)
			if model in VoxelFlora.FLOWERS or model in VoxelFlora.WILD or model in SNOW_BURIES:
				_buried.append(mmi)
			_bump("decor", mm.instance_count)
		await _step()


## World AABB of an instanced chunk entry's MultiMesh: a lone instance from its baked transform
## and the mesh (exact, and also right headless, where the dummy renderer keeps no MultiMesh data).
static func mm_aabb(mm: MultiMesh, e: Dictionary) -> AABB:
	if mm.instance_count == 1 and mm.mesh:
		return VoxelZoneBake.entry_xf(e) * mm.mesh.get_aabb()
	return mm.get_aabb()


## Fader rect of a lone tree or tall prop (world AABB `bb`) for the zone's camera, which looks north
## (VoxelZone zones keep camera_yaw 0): as wide as the crown or lamp head (`half` each side of its
## centre) and from just south of its centre `reach` metres towards the camera. The rig fades a rect
## only while its near edge lies between the player and the eye, so a square around the trunk never
## faded for a player standing right behind it, under the crown; this one does.
static func fade_rect(bb: AABB, half: float, reach: float) -> Rect2:
	var c := bb.get_center()
	return Rect2(c.x - half, c.z + 0.05, half * 2.0, reach)


## Deep snow buries the flowers and tall grass (the decor shader only whitens their tops). The
## cover is read once a second from the weather node: its snow_cover() when it has one, else
## battle_cover.g (outdoors), the value it publishes as the snow_cover global
## (global_shader_parameter_get is editor-only and stalls the renderer).
func _process(delta: float) -> void:
	_snow_poll -= delta
	if _snow_poll > 0.0 or (_buried.is_empty() and butterflies == null):
		return
	_snow_poll = 1.0
	var w := get_tree().get_first_node_in_group(WEATHER_GROUP)
	if w == null:
		return
	if w.has_method("snow_cover"):  # a world weather that snows by itself
		set_snow(float(w.snow_cover()))
		return
	var cover = w.get("battle_cover")
	set_snow(0.0 if w.get("indoor") == true or not cover is Color else (cover as Color).g)


## Hides the flowers, tall grass and butterflies while the snow cover is above SNOW_BURY.
func set_snow(cover: float) -> void:
	var on := cover > SNOW_BURY
	if on == _snow_on:
		return
	_snow_on = on
	for m in _buried:
		if is_instance_valid(m):
			m.visible = not on
	if butterflies:
		butterflies.visible = not on


func _tree_mat(model: String) -> ShaderMaterial:
	if not _tree_mats.has(model):
		var m := bake.tree_material(model)
		m.set_shader_parameter("shade_lift", SHADE_LIFT)
		_tree_mats[model] = m
	return _tree_mats[model]


func _decor_mat(model: String) -> ShaderMaterial:
	if not _decor_mats.has(model):
		var e: Dictionary = bake.decor_models.get(model, {})
		var params := {
			"sway": float(e.get("sway", 0.0)) * 0.02,
			"weather": float(e.get("weather", 1.0)),
			"shade_lift": SHADE_LIFT,
		}
		if float(e.get("backlight", 0.0)) > 0.0:
			params["backlight"] = float(e.backlight)
		_decor_mats[model] = VoxelMat.detail_material(params)
	return _decor_mats[model]


static func _v3(a) -> Vector3:
	if a is Vector3:
		return a
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


static func _v2(a) -> Vector2:
	if a is Vector2:
		return a
	return Vector2(float(a[0]), float(a[1]))


## One WaterSurface per water body (never overlapping), 12 cm under its banks over the carved bed;
## each cascade between two bodies is a FountainFx sheet that ripples the lower surface.
func _water_surfaces(meta: Dictionary) -> void:
	var g := _group("WaterSurface")
	var bodies: Array[MeshInstance3D] = []
	for w in meta.get("water", []):
		var r: Array = w.rect
		var rr := Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
		var kind := String(w.get("type", "pond"))
		var opts := {
			"kind": kind,
			"flow": _v2(w.get("flow", [0, 0])),
			"depth": float(w.get("depth", 1.0)),
			"seed": float(bodies.size()) * 3.7 + 1.3,
		}
		if kind == "stream":
			opts["fish"] = 1
		var mi := WaterSurface.make(rr.size, opts)
		mi.name = "Water_%s_%d" % [kind, bodies.size()]
		mi.position = Vector3(
			rr.get_center().x, float(w.get("level", VoxelZoneGen.WATER_Y)), rr.get_center().y
		)
		g.add_child(mi)
		bodies.append(mi)
		water_surfaces.append(mi)
		var d := float(w.get("depth", 1.0))
		_rain_stop(g, mi.position, Vector3(rr.size.x, d, rr.size.y))
		_bump("water")
	for c in meta.get("cascades", []):
		var low := int(c.get("low", -1))
		var fx := FountainFx.new()
		fx.name = "Cascade%d" % g.get_child_count()
		g.add_child(fx)
		(
			fx
			. setup(
				{
					"sheets":
					[{"from": _v3(c.from), "to": _v3(c.to), "width": float(c.get("width", 1.0))}],
					"surfaces": [bodies[low]] if low >= 0 and low < bodies.size() else [],
				}
			)
		)
		_bump("cascades")


## The fountains: FountainFx water (basins, jets, sheets, curtains, light) over the voxel stone.
func _fountains(meta: Dictionary) -> void:
	for f in meta.get("fountains", []):
		var spec := {"jets": [], "basins": [], "sheets": [], "curtains": []}
		for j in f.get("jets", []):
			var e := {"pos": _v3(j.pos), "height": float(j.height), "count": int(j.count)}
			for k in ["radius", "reach", "spread"]:
				if j.has(k):
					e[k] = float(j[k])
			spec.jets.append(e)
		for b in f.get("basins", []):
			(
				spec
				. basins
				. append(
					{
						"pos": _v3(b.pos),
						"size": _v2(b.size),
						"kind": String(b.get("kind", "fountain")),
						"shape": String(b.get("shape", "ellipse")),
						"depth": float(b.get("depth", 0.4)),
					}
				)
			)
		for s in f.get("sheets", []):
			spec.sheets.append({"from": _v3(s.from), "to": _v3(s.to), "width": float(s.width)})
		for c in f.get("curtains", []):
			(
				spec
				. curtains
				. append(
					{
						"centre": _v3(c.centre),
						"radius": float(c.radius),
						"drop": float(c.drop),
						"flare": float(c.get("flare", 0.0)),
					}
				)
			)
		if f.has("light"):
			spec["light"] = Color(String(f.light))
		var fx := FountainFx.new()
		fx.name = "Fountain"
		add_child(fx)
		fx.setup(spec)
		for b in spec.basins:  # inside the rim (round basins): rain stops on the water
			var bs: Vector2 = b.size * (0.82 if b.shape == "ellipse" else 1.0)
			_rain_stop(fx, b.pos, Vector3(bs.x, b.depth, bs.y))
		fountain = fx
		_bump("fountains")


## Rain and snow stop on a water surface (`top` = its centre at the water level): the weather's
## collision heightfield only sees opaque geometry, so without this the drops fell through the
## transparent water onto the carved bed and splashed under it.
func _rain_stop(parent: Node, top: Vector3, size: Vector3) -> void:
	var c := GPUParticlesCollisionBox3D.new()
	c.name = "RainStop%d" % parent.get_child_count()
	c.size = size
	c.position = top - Vector3(0.0, size.y * 0.5, 0.0)
	c.cull_mask = WeatherKit.LAYER  # only the weather (the fountain's jets have their own catch)
	parent.add_child(c)
	_bump("rain_stops")


func _lights(meta: Dictionary) -> void:
	var g := _group("Lights")
	for l in meta.get("lights", []):
		var light := OmniLight3D.new()
		light.light_color = Color(String(l.get("color", "ffc880")))
		light.light_energy = float(l.get("energy", 3.0)) * LAMP_ENERGY
		light.omni_range = float(l.get("range", 7.0))
		light.omni_attenuation = 1.8  # pools of light, darker between the lamps
		light.shadow_enabled = false
		light.position = _v3(l.pos)
		g.add_child(light)
		var nl := NightLights.new()
		nl.light = light
		g.add_child(nl)
		lights.append(light)
		_bump("lights")


## Chimney smoke: a thin plume of soft puffs over each chimney top, drifting with the breeze.
func _smoke(meta: Dictionary) -> void:
	var pts: Array = meta.get("smoke", [])
	if pts.is_empty():
		return
	var g := _group("Smoke")
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0.25, 1.0, 0.1)
	pm.spread = 12.0
	pm.initial_velocity_min = 0.35
	pm.initial_velocity_max = 0.55
	pm.gravity = Vector3(0.18, 0.06, 0.05)
	pm.damping_min = 0.05
	pm.damping_max = 0.1
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.08
	pm.scale_min = 0.7
	pm.scale_max = 1.1
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.35))
	grow.add_point(Vector2(1.0, 1.6))
	var sc := CurveTexture.new()
	sc.curve = grow
	pm.scale_curve = sc
	var fade := Gradient.new()
	fade.set_color(0, Color(0.92, 0.9, 0.88, 0.0))
	fade.set_color(1, Color(0.85, 0.85, 0.86, 0.0))
	fade.add_point(0.12, Color(0.9, 0.88, 0.86, 0.38))
	fade.add_point(0.6, Color(0.86, 0.86, 0.87, 0.2))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	pm.color_ramp = ramp
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	var puff := Gradient.new()
	puff.set_color(0, Color(1, 1, 1, 1))
	puff.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = puff
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 32
	tex.height = 32
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = tex
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	mat.roughness = 1.0
	var quad := QuadMesh.new()
	quad.size = Vector2(0.55, 0.55)
	quad.material = mat
	for p in pts:
		var ps := GPUParticles3D.new()
		ps.name = "Chimney"
		ps.amount = 14
		ps.lifetime = 4.5
		ps.preprocess = 4.5
		ps.process_material = pm
		ps.draw_pass_1 = quad
		ps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ps.visibility_aabb = AABB(Vector3(-2, -0.5, -2), Vector3(6, 5, 6))
		ps.position = _v3(p)
		g.add_child(ps)
		_bump("smoke")


## Butterflies over the flower beds by day: one particle system fed by the beds' points (bake
## metadata), wandering on turbulence, two-frame flapping sprites in a few colours.
func _butterflies(meta: Dictionary) -> void:
	var pts: Array = meta.get("butterflies", [])
	if pts.is_empty():
		return
	var img := Image.create(pts.size(), 1, false, Image.FORMAT_RGBF)
	for i in pts.size():
		var p := _v3(pts[i])
		img.set_pixel(i, 0, Color(p.x, p.y, p.z))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINTS
	pm.emission_point_texture = ImageTexture.create_from_image(img)
	pm.emission_point_count = pts.size()
	pm.direction = Vector3(0, 0.4, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.15
	pm.initial_velocity_max = 0.35
	pm.gravity = Vector3.ZERO
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 2.0
	pm.turbulence_noise_scale = 1.2
	pm.turbulence_influence_min = 0.06
	pm.turbulence_influence_max = 0.14
	pm.anim_speed_min = 30.0
	pm.anim_speed_max = 44.0
	var life := Curve.new()
	life.add_point(Vector2(0.0, 0.0))
	life.add_point(Vector2(0.08, 1.0))
	life.add_point(Vector2(0.92, 1.0))
	life.add_point(Vector2(1.0, 0.0))
	var sc := CurveTexture.new()
	sc.curve = life
	pm.scale_curve = sc
	var cols := Gradient.new()
	cols.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	cols.set_color(0, Color(1.0, 1.0, 0.96))
	cols.set_offset(1, 0.2)
	cols.set_color(1, Color(1.0, 0.86, 0.3))
	cols.add_point(0.4, Color(1.0, 0.6, 0.22))
	cols.add_point(0.6, Color(0.55, 0.75, 1.0))
	cols.add_point(0.8, Color(1.0, 0.7, 0.85))
	var ramp := GradientTexture1D.new()
	ramp.gradient = cols
	pm.color_initial_ramp = ramp
	var tex := Image.create(16, 8, false, Image.FORMAT_RGBA8)
	for y in 8:
		for x in 8:
			var dx := absi(x * 2 - 7)  # 1, 3, 5, 7 from the body
			var open := dx > 1 and y >= 1 and y <= 6 and not (dx == 7 and (y == 1 or y == 6))
			var shut := dx > 1 and dx <= 3 and y <= 5
			var body := dx <= 1 and y >= 2 and y <= 6
			if open or body:
				tex.set_pixel(x, y, Color(0.15, 0.12, 0.1) if body else Color.WHITE)
			if shut or body:
				tex.set_pixel(8 + x, y, Color(0.15, 0.12, 0.1) if body else Color(0.85, 0.85, 0.85))
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(tex)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.particles_anim_h_frames = 2
	mat.particles_anim_v_frames = 1
	mat.particles_anim_loop = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var quad := QuadMesh.new()
	quad.size = Vector2(0.18, 0.09)
	quad.material = mat
	var bf := Butterflies.new()
	bf.name = "Butterflies"
	bf.amount = 28
	bf.lifetime = 9.0
	bf.preprocess = 9.0
	bf.process_material = pm
	bf.draw_pass_1 = quad
	bf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bf.visibility_aabb = AABB(
		Vector3(rect.position.x - 4.0, -1.0, rect.position.y - 4.0),
		Vector3(rect.size.x + 8.0, 6.0, rect.size.y + 8.0)
	)
	_group("Life").add_child(bf)
	butterflies = bf
	_bump("butterflies", pts.size())


## Flags on the flagpoles: a subdivided quad hung from the pole top, flying downwind and rippling
## with the wind globals (voxel_flag.gdshader), painted from a small pixel texture.
func _flags(meta: Dictionary) -> void:
	for f in meta.get("flags", []):
		var quad := QuadMesh.new()
		quad.size = Vector2(1.2, 0.8)
		quad.subdivide_width = 12
		quad.subdivide_depth = 2
		var m := ShaderMaterial.new()
		m.shader = load("res://world/voxel/voxel_flag.gdshader")
		m.set_shader_parameter("cloth", ImageTexture.create_from_image(flag_cloth(String(f.cloth))))
		m.set_shader_parameter("phase", _v3(f.pos).x)
		var mi := MeshInstance3D.new()
		mi.name = "Flag"
		mi.mesh = quad
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 1.4  # the shader turns it round the pole to fly downwind
		var b := Basis(Vector3.UP, int(f.rot) * PI * 0.5)
		mi.transform = Transform3D(b, _v3(f.pos) + b * Vector3(0.66, -0.4, 0.0))
		_group("Life").add_child(mi)
		_bump("flags")


## Washing lines (meta "laundry", from VoxelProps._laundry): two ropes from crossbar to crossbar
## and clothes pegged along them, each a hanging quad that sways in the breeze (voxel_flag.gdshader
## in hang mode, pixel cloth from laundry_cloth()).
func _laundry(meta: Dictionary) -> void:
	var rope := StandardMaterial3D.new()
	rope.albedo_color = Color("d8cdb4")
	rope.roughness = 1.0
	var n := 0
	for l in meta.get("laundry", []):
		var a := _v3(l.a) + Vector3(0, -0.04, 0)
		var b := _v3(l.b) + Vector3(0, -0.04, 0)
		var d := b - a
		var span := Vector2(d.x, d.z).length()
		if span < 0.5:
			continue
		var yaw := atan2(-d.z, d.x)
		var bs := Basis(Vector3.UP, yaw)
		var side := bs * Vector3(0, 0, 1)
		for k in 2:
			var off := side * (0.22 if k == 0 else -0.22)
			var line := MeshInstance3D.new()
			line.name = "Line%d" % n
			var bm := BoxMesh.new()
			bm.size = Vector3(span, 0.025, 0.025)
			line.mesh = bm
			line.material_override = rope
			line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			line.transform = Transform3D(bs, a + d * 0.5 + off)
			_group("Life").add_child(line)
			# Clothes along the line, from just past one post to just short of the other.
			var u := 0.18
			var i := 0
			while true:
				var kind: String = LAUNDRY[(n * 3 + i * 5 + k) % LAUNDRY.size()]
				var sz: Vector2 = LAUNDRY_SIZE[kind]
				if u + sz.x > span - 0.12:
					break
				var quad := QuadMesh.new()
				quad.size = sz
				quad.subdivide_width = 2
				quad.subdivide_depth = 6
				var m := ShaderMaterial.new()
				m.shader = load("res://world/voxel/voxel_flag.gdshader")
				var tint: Color = LAUNDRY_TINTS[(n * 7 + i * 3 + k * 2) % LAUNDRY_TINTS.size()]
				var img := laundry_cloth(kind, tint)
				m.set_shader_parameter("cloth", ImageTexture.create_from_image(img))
				m.set_shader_parameter("hang", 1.0)
				m.set_shader_parameter("wave", 0.06 if kind != "sheet" else 0.1)
				m.set_shader_parameter("speed", 2.2)
				m.set_shader_parameter("phase", float(n * 2 + i) * 1.3)
				var mi := MeshInstance3D.new()
				mi.name = "Cloth_%s_%d" % [kind, i]
				mi.mesh = quad
				mi.material_override = m
				var c := a + d * ((u + sz.x * 0.5) / span) + off
				mi.transform = Transform3D(bs, c + Vector3(0, -sz.y * 0.5, 0))
				_group("Life").add_child(mi)
				u += sz.x + 0.1
				i += 1
		n += 1
		_bump("laundry")


## The pixel cloth of a piece of laundry (alpha cut-out shape, hem and stripes), 16 px per metre.
static func laundry_cloth(kind: String, tint: Color) -> Image:
	var sz: Vector2 = LAUNDRY_SIZE[kind]
	var w := maxi(4, roundi(sz.x * 16.0))
	var h := maxi(4, roundi(sz.y * 16.0))
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in h:
		for x in w:
			var c := tint
			var on := true
			match kind:
				"shirt":  # sleeves on the top third, the body below
					on = y * 3 < h or (x * 4 >= w and x * 4 < w * 3)
					if x == w >> 1 and y > 0 and y < h - 1:
						c = tint.darkened(0.18)  # button placket
				"towel":
					if y == h - 3 or y == h - 4:
						c = Color("f4f1e8") if tint.v < 0.9 else Color("d9534a")
				"sheet":
					c = Color("f6f3ea") if (x + y) % 9 != 0 else Color("ebe6d8")
					if y == h - 2:
						c = tint
				"trousers":  # waistband, then two legs
					on = y < 3 or absi(x * 2 - (w - 1)) > 1
					c = Color("3d5a80") if tint.v > 0.85 else tint.darkened(0.25)
				"socks":
					on = x != w >> 1  # a pair, side by side
			if not on:
				continue
			if y == 0:
				c = c.darkened(0.12)  # the pegged hem
			if (x * 3 + y * 5) % 3 == 0:
				c = c.darkened(0.05)
			img.set_pixel(x, y, c)
	return img


## The pixel cloth of a flag ("pallet": a sky-blue field, a white band and a red-and-white disc).
static func flag_cloth(_kind: String) -> Image:
	var img := Image.create(24, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 24:
			var c := Color("3f7fc0") if (x + y) % 7 != 0 else Color("3a76b4")
			if y >= 6 and y <= 9:
				c = Color("f2f0ea")
			var d := Vector2(x - 6.5, y - 7.5).length()
			if d < 4.2:
				c = Color("d8343a") if y < 8 else Color("f2f0ea")
				if d < 1.6:
					c = Color("f2f0ea")
				elif absf(y - 7.5) < 0.6:
					c = Color("2a2a30")
			img.set_pixel(x, y, c)
	return img


## Day-only particles: WorldTimeOfDay calls set_period_mult(day) on the "day_ambient" group.
class Butterflies:
	extends GPUParticles3D

	func _ready() -> void:
		add_to_group("day_ambient")

	func set_period_mult(day: float) -> void:
		amount_ratio = clampf(day * 1.5 - 0.5, 0.0, 1.0)
		emitting = amount_ratio > 0.01


# --- doors ---------------------------------------------------------------------------------------


## Doors on the explicit tiles of the map (or the design's door tile): a WorldDoor just inside the
## facade, the arrival on the tile in front facing south.
func _doors() -> void:
	var tiles := {}
	for b in bake.meta.get("buildings", []):
		if b.has("door"):
			tiles[String(b.id)] = Vector2i(int(b.door[0]), int(b.door[1]))
	for b in data.get("buildings", []):
		var id := String(b.get("id", ""))
		var dr: Dictionary = b.get("door", {})
		var t: Vector2i = tiles.get(id, Vector2i.ZERO)
		if dr.has("tile"):
			t = Vector2i(int(dr.tile[0]), int(dr.tile[1]))
		var door := WorldDoor.new()
		door.name = "Door_%s" % id
		door.drawn = false
		var msg: Dictionary = b.get("message", {})
		door.npc_name = String(msg.get("title", id.replace("_", " ").capitalize()))
		door.lines = PackedStringArray(msg.get("lines", ["Fechado."]))
		door.color = Color(0.45, 0.3, 0.2)
		door.body_height = 2.0
		door.target_scene = String(dr.get("target_scene", ""))
		door.target_spawn = String(dr.get("target_spawn", ""))
		door.position = Vector3(t.x, 0.0, t.y + 0.1)
		door.rotation.y = PI
		add_child(door)
		if dr.has("spawn"):
			arrivals[String(dr.spawn)] = Vector3(t.x, 0.0, t.y + 1.0)
		_bump("doors")
		_bump("buildings")  # the map's buildings (the voxel houses are counted as "houses")

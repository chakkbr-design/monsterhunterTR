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
const LAMP_ENERGY := 1.7  ## OmniLight energy per metadata energy unit
const BUILD_STEP := 6  ## nodes added per frame while streaming

var bake: VoxelZoneBake
var voxel_material: ShaderMaterial
var stale := false  ## the bake did not match (regenerated in-process)
var load_ms := 0  ## time spent loading / building the scenery (tests)
var lights: Array[OmniLight3D] = []
var houses: Dictionary = {}  ## building id -> Node3D (fader, metas rect / height / geoms / parts)

var _tree_mats := {}
var _decor_mats := {}


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
	var vol := bake.volume()
	voxel_material = _grid_material(vol[0], vol[1], bake.grid_origin, bake.grid_size)
	await _step()
	var part_of := {}  # part id -> building entry
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
			mi.name = "%s%d" % [_part_name(part_of[prt], prt), i]
			house.add_child(mi)
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
	_bump("voxel")


func _grid_material(tex: Texture3D, tops: Texture2D, o: Vector3i, s: Vector3i) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = VoxelMat.shader("voxel")
	m.set_shader_parameter("vox", tex)
	m.set_shader_parameter("tops", tops)
	m.set_shader_parameter("mat_lut", VoxelMat.lut())
	m.set_shader_parameter("grid_origin", o)
	m.set_shader_parameter("grid_size", s)
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


## Trees (MultiMesh per model and chunk, town trees one by one so they fade alone) and decor.
func _instances(root: Node3D) -> void:
	var trees := _group("Trees")
	var decor := _group("Decor")
	for e in bake.multimeshes:
		var mm := bake.multimesh(e)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		var model := String(e.model)
		if String(e.kind) == "tree":
			mmi.name = "%s_%d" % [model, trees.get_child_count()]
			mmi.material_override = _tree_mat(model)
			trees.add_child(mmi)
			var bb := mm.get_aabb()
			var r := Rect2(bb.position.x, bb.position.z, bb.size.x, bb.size.z)
			if bool(e.get("town", false)) and mm.instance_count == 1:
				var p := mm.get_instance_transform(0).origin
				r = Rect2(
					p.x - TOWN_TREE_FADE,
					p.z - TOWN_TREE_FADE,
					TOWN_TREE_FADE * 2.0,
					TOWN_TREE_FADE * 2.0
				)
				if not model.begins_with("bush") and not model.begins_with("shrub"):
					leaf_points.append(p + Vector3(0, 4.0, 0))
			if bb.size.y > 2.0:
				mmi.set_meta("rect", r)
				mmi.set_meta("height", bb.end.y)
				mmi.set_meta("geoms", [mmi])
				WorldProps.register_fader(mmi, r)
			_bump("trees", mm.instance_count)
		else:
			mmi.name = "%s_%d" % [model.replace(":", "_"), decor.get_child_count()]
			mmi.material_override = _decor_mat(model)
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.visibility_range_end = VoxelZoneBake.DECOR_RANGE
			mmi.visibility_range_end_margin = 6.0
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			decor.add_child(mmi)
			_bump("decor", mm.instance_count)
		await _step()


func _tree_mat(model: String) -> ShaderMaterial:
	if not _tree_mats.has(model):
		_tree_mats[model] = bake.tree_material(model)
	return _tree_mats[model]


func _decor_mat(model: String) -> ShaderMaterial:
	if not _decor_mats.has(model):
		var e: Dictionary = bake.decor_models.get(model, {})
		var params := {"sway": float(e.get("sway", 0.0)) * 0.02}
		if model.begins_with("flower") or model.begins_with("lily") or model == "petals":
			params["backlight"] = 0.35
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


func _water_surfaces(meta: Dictionary) -> void:
	var g := _group("WaterSurface")
	for w in meta.get("water", []):
		var r: Array = w.rect
		var rr := Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
		var kind := String(w.get("type", "pond"))
		var mi := WaterSurface.make(
			rr.size,
			{"kind": kind, "flow": _v2(w.get("flow", [0, 0])), "depth": float(w.get("depth", 1.0))}
		)
		mi.name = "Water_%s_%d" % [kind, g.get_child_count()]
		mi.position = Vector3(
			rr.get_center().x, float(w.get("level", VoxelZoneGen.WATER_Y)), rr.get_center().y
		)
		g.add_child(mi)
		_bump("water")


func _fountains(meta: Dictionary) -> void:
	for f in meta.get("fountains", []):
		var spec := {"jets": [], "basins": [], "sheets": []}
		for j in f.get("jets", []):
			spec.jets.append({"pos": _v3(j.pos), "height": float(j.height), "count": int(j.count)})
		for b in f.get("basins", []):
			spec.basins.append(
				{"pos": _v3(b.pos), "size": _v2(b.size), "kind": String(b.get("kind", "fountain"))}
			)
		for s in f.get("sheets", []):
			spec.sheets.append({"from": _v3(s.from), "to": _v3(s.to), "width": float(s.width)})
		if f.has("light"):
			spec["light"] = Color(String(f.light))
		var fx := FountainFx.new()
		fx.name = "Fountain"
		add_child(fx)
		fx.setup(spec)
		_bump("fountains")


func _lights(meta: Dictionary) -> void:
	var g := _group("Lights")
	for l in meta.get("lights", []):
		var light := OmniLight3D.new()
		light.light_color = Color(String(l.get("color", "ffc880")))
		light.light_energy = float(l.get("energy", 3.0)) * LAMP_ENERGY
		light.omni_range = float(l.get("range", 7.0))
		light.omni_attenuation = 0.9
		light.shadow_enabled = false
		light.position = _v3(l.pos)
		g.add_child(light)
		var nl := NightLights.new()
		nl.light = light
		g.add_child(nl)
		lights.append(light)
		_bump("lights")


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

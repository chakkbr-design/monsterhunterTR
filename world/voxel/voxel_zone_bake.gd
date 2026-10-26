class_name VoxelZoneBake
extends Resource
## Baked output of a voxel zone (tools/voxel/bake_zone.gd writes world/voxel/baked/<zone>.res plus
## <zone>.json; VoxelZone loads them, or builds this in-process when the bake is stale):
## - the zone grid's colour volume (zstd-compressed bytes, turned back into the shared 3D texture
##   at load) and its column tops, greedy meshes per 16 m chunk and part;
## - tree / bush models (each with its own small volume) and their MultiMesh chunks;
## - detail decor meshes and their MultiMesh chunks;
## The JSON holds the metadata (lights, buildings and their parts, water, fountains), the TileGrid
## and the hashes (design + map + generator version, and the generator sources).

const DIR := "res://world/voxel/baked"
const CHUNK := 64  ## voxels per mesh chunk (16 m)
const DECOR_RANGE := 46.0  ## metres: decor chunks beyond this are not drawn
const SOURCES := [
	"res://world/voxel/voxel_zone_gen.gd",
	"res://world/voxel/voxel_build.gd",
	"res://world/voxel/voxel_props.gd",
	"res://world/voxel/voxel_trees.gd",
	"res://world/voxel/voxel_models.gd",
	"res://world/voxel/voxel_flora.gd",
	"res://world/voxel/voxel_pal.gd",
	"res://world/voxel/voxel_design.gd",
	"res://world/voxel/voxel_zone_bake.gd",
	"res://gfx/voxel/voxel_mesher.gd",
	"res://gfx/voxel/voxel_grid.gd",
]

@export var zone := ""
@export var input_hash := ""
@export var grid_origin := Vector3i.ZERO
@export var grid_size := Vector3i.ONE
@export var vox_data := PackedByteArray()  ## zstd of VoxelGrid.data
@export var vox_len := 0
@export var tops_data := PackedByteArray()  ## R8 column tops (VoxelGrid.tops_image)
@export var meshes: Array[ArrayMesh] = []  ## greedy chunks
@export var mesh_parts := PackedInt32Array()  ## part id of each mesh
## Tree and prop models: name -> {"mesh", "origin", "size", "data" (zstd), "len", "tops", "sway",
## "vs" (voxel edge: 0.25 trees, VoxelModels.PROP_VS props)}.
@export var tree_models := {}
## Instanced chunks: [{"model", "kind" ("tree" | "prop" | "decor"), "town" (one instance, faded by
## the camera), "xf", "phase"}], with "xf" 12
## floats per instance (basis columns x, y, z, then origin) and "phase" one float per instance
## (decor sway). Kept as plain arrays: a MultiMesh made under the headless (dummy) renderer saves
## without its instances; multimesh() rebuilds it at load.
@export var multimeshes: Array = []
## Decor models: name -> {"mesh", "sway", "weather", "backlight"} (voxel_detail.gdshader uniforms).
@export var decor_models := {}

var meta := {}  ## from the JSON (not serialized in the .res)
var tiles: TileGrid


static func res_path(id: String) -> String:
	return "%s/%s.res" % [DIR, id]


static func json_path(id: String) -> String:
	return "%s/%s.json" % [DIR, id]


## md5 of the generator sources: a bake made by older code is stale even when the inputs match.
static func source_hash() -> String:
	var s := ""
	for p in SOURCES:
		s += FileAccess.get_file_as_string(p) if FileAccess.file_exists(p) else ""
	return s.md5_text()


## The stored JSON (metadata + tiles + hashes), {} when missing.
static func read_json(id: String) -> Dictionary:
	var p := json_path(id)
	if not FileAccess.file_exists(p):
		return {}
	var j = JSON.parse_string(FileAccess.get_file_as_string(p))
	return j if j is Dictionary else {}


## True when the bake on disk matches the zone's current design + map + generator version.
static func is_fresh(id: String) -> bool:
	var j := read_json(id)
	return not j.is_empty() and String(j.get("hash", "")) == VoxelZoneGen.input_hash(id)


# --- building a bake from a generator run ------------------------------------------------------------


static func from_gen(gen: VoxelZoneGen) -> VoxelZoneBake:
	var b := VoxelZoneBake.new()
	b.zone = gen.zone_id
	b.input_hash = VoxelZoneGen.input_hash(gen.zone_id)
	var g := gen.g
	b.grid_origin = g.origin
	b.grid_size = g.size
	b.vox_len = g.data.size()
	b.vox_data = g.data.compress(FileAccess.COMPRESSION_ZSTD)
	b.tops_data = g.tops_image().get_data()
	_mesh_chunks(b, g)
	_trees(b, gen)
	_decor(b, gen)
	b.meta = gen.meta_json()
	b.tiles = gen.tiles
	return b


## Greedy meshes per 16 m chunk: each chunk is copied (with a one-voxel margin, only up to its
## highest voxel) into a small grid, so face culling across chunk borders stays exact.
static func _mesh_chunks(b: VoxelZoneBake, g: VoxelGrid) -> void:
	var tops := g.tops_image().get_data()
	var nx := ceili(g.size.x / float(CHUNK))
	var nz := ceili(g.size.z / float(CHUNK))
	for cz in nz:
		for cx in nx:
			var lx0 := cx * CHUNK
			var lz0 := cz * CHUNK
			var lx1 := mini(lx0 + CHUNK, g.size.x)
			var lz1 := mini(lz0 + CHUNK, g.size.z)
			var hy := 0
			for z in range(maxi(lz0 - 1, 0), mini(lz1 + 1, g.size.z)):
				for x in range(maxi(lx0 - 1, 0), mini(lx1 + 1, g.size.x)):
					hy = maxi(hy, tops[x + g.size.x * z])
			if hy == 0:
				continue
			var sub := _copy(
				g, Vector3i(lx0 - 1, 0, lz0 - 1), Vector3i(lx1 + 1, mini(hy + 1, g.size.y), lz1 + 1)
			)
			var res := VoxelMesher.greedy(
				sub, Vector3i(1, 0, 1), Vector3i(sub.size.x - 1, sub.size.y, sub.size.z - 1)
			)
			for prt in res:
				b.meshes.append(res[prt])
				b.mesh_parts.append(prt)


## Local cell box [a, b) of g copied into a new grid (cells outside g stay air).
static func _copy(g: VoxelGrid, a: Vector3i, bb: Vector3i) -> VoxelGrid:
	var s := bb - a
	var out := VoxelGrid.new(g.origin + a, s)
	var x0 := maxi(a.x, 0)
	var x1 := mini(bb.x, g.size.x)
	var run := maxi(x1 - x0, 0)
	var pre := x0 - a.x
	var post := s.x - pre - run
	var z4 := [PackedByteArray(), PackedByteArray(), PackedByteArray()]  # pre, post, empty row
	var z1 := [PackedByteArray(), PackedByteArray(), PackedByteArray()]
	for i in 3:
		var n: int = [pre, post, s.x][i]
		z4[i].resize(n * 4)
		z1[i].resize(n)
	var data := PackedByteArray()
	var part := PackedByteArray()
	var sxz := g.size.x * g.size.z
	for y in s.y:
		var gy := a.y + y
		for z in s.z:
			var gz := a.z + z
			if run == 0 or gy < 0 or gy >= g.size.y or gz < 0 or gz >= g.size.z:
				data.append_array(z4[2])
				part.append_array(z1[2])
				continue
			var src := x0 + g.size.x * gz + sxz * gy
			data.append_array(z4[0])
			data.append_array(g.data.slice(src * 4, (src + run) * 4))
			data.append_array(z4[1])
			part.append_array(z1[0])
			part.append_array(g.part.slice(src, src + run))
			part.append_array(z1[1])
	out.data = data
	out.part = part
	return out


static func _chunk_key(p: Vector3, ext: Rect2) -> Vector2i:
	return Vector2i(floori((p.x - ext.position.x) / 16.0), floori((p.z - ext.position.y) / 16.0))


static func _trees(b: VoxelZoneBake, gen: VoxelZoneGen) -> void:
	var items: Array = gen.meta.get("tree_list", []) + gen.meta.get("prop_list", [])
	var used := {}
	for e in items:
		used[String(e.model)] = true
	for m in used:
		var prop := VoxelModels.is_prop(m)
		var tg := VoxelModels.build(m) if prop else VoxelTrees.build(m)
		var vs := VoxelModels.PROP_VS if prop else VoxelTrees.model_vs(m)
		var meshes := VoxelMesher.greedy(tg, Vector3i.ZERO, Vector3i(-1, -1, -1), vs)
		if not meshes.has(0):
			continue
		b.tree_models[m] = {
			"mesh": meshes[0],
			"origin": tg.origin,
			"size": tg.size,
			"data": tg.data.compress(FileAccess.COMPRESSION_ZSTD),
			"len": tg.data.size(),
			"tops": tg.tops_image().get_data(),
			"sway": 0.0 if prop else float(VoxelTrees.SWAY.get(VoxelTrees.species_of(m), 0.0)),
			"vs": vs,
		}
	var ext := gen.d.extent_m()
	var groups := {}  # [model, chunk or tile, single] -> Array[Transform3D]
	for e in items:
		var p: Vector3 = e.pos
		var m := String(e.model)
		var t := Vector2i(roundi(p.x), roundi(p.z))
		var prop := VoxelModels.is_prop(m)
		# Town trees and tall props are drawn one by one (the camera fader sees through them).
		var part := int(e.get("part", 0))
		var single := (
			m in VoxelModels.TALL and part == 0
			if prop
			else gen.d.in_rect(t) and gen.d.thing_kind(t) != "forest"
		)
		var key := [m, _chunk_key(p, ext) if not single else Vector2(p.x, p.z), single, part]
		if not groups.has(key):
			groups[key] = []
		var xf := (
			VoxelModels.xform(p, int(e.rot))
			if prop
			else Transform3D(Basis(Vector3.UP, int(e.rot) * PI * 0.5), p)
		)
		groups[key].append(xf)
	for key in groups:
		b.multimeshes.append(
			{
				"model": key[0],
				"kind": "prop" if VoxelModels.is_prop(key[0]) else "tree",
				"town": key[2],
				"part": key[3],
				"xf": _pack(groups[key]),
				"phase": PackedFloat32Array()
			}
		)


static func _decor(b: VoxelZoneBake, gen: VoxelZoneGen) -> void:
	var ext := gen.d.extent_m()
	for key in gen.decor:
		# "model@part": instances tied to a building part (they fade with the house).
		var split := String(key).split("@")
		var m := split[0]
		var part := int(split[1]) if split.size() > 1 else 0
		if not b.decor_models.has(m):
			var info := VoxelFlora.build(m)
			var mesh := VoxelMesher.colored(info.grid, VoxelMat.DETAIL, info.pivot)
			if mesh.get_surface_count() == 0:
				continue
			b.decor_models[m] = {
				"mesh": mesh,
				"sway": info.sway,
				"weather": float(info.get("weather", 1.0)),
				"backlight": float(info.get("backlight", 0.0)),
			}
		var groups := {}
		for xf in gen.decor[key]:
			var k := _chunk_key(xf.origin, ext)
			if not groups.has(k):
				groups[k] = []
			groups[k].append(xf)
		for k in groups:
			var ph := PackedFloat32Array()
			for xf in groups[k]:
				ph.append(
					VoxelGrid.hash01(roundi(xf.origin.x * 16.0), 0, roundi(xf.origin.z * 16.0), 95)
				)
			b.multimeshes.append(
				{
					"model": m,
					"kind": "decor",
					"town": false,
					"part": part,
					"xf": _pack(groups[k]),
					"phase": ph
				}
			)


static func _pack(xfs: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(xfs.size() * 12)
	var i := 0
	for xf: Transform3D in xfs:
		var bs := xf.basis
		for v in [bs.x, bs.y, bs.z, xf.origin]:
			out[i] = v.x
			out[i + 1] = v.y
			out[i + 2] = v.z
			i += 3
	return out


## Transform of instance i of an instanced chunk entry, read from its packed "xf" (MultiMesh
## transforms live in the RenderingServer, which keeps none headless).
static func entry_xf(e: Dictionary, i := 0) -> Transform3D:
	var xf: PackedFloat32Array = e.xf
	var k := i * 12
	return Transform3D(
		Vector3(xf[k], xf[k + 1], xf[k + 2]),
		Vector3(xf[k + 3], xf[k + 4], xf[k + 5]),
		Vector3(xf[k + 6], xf[k + 7], xf[k + 8]),
		Vector3(xf[k + 9], xf[k + 10], xf[k + 11])
	)


## The MultiMesh of one instanced chunk entry (mesh from the tree / decor model).
func multimesh(e: Dictionary) -> MultiMesh:
	var xf: PackedFloat32Array = e.xf
	var ph: PackedFloat32Array = e.get("phase", PackedFloat32Array())
	var n := xf.size() / 12
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = not ph.is_empty()
	var model := String(e.model)
	mm.mesh = decor_models[model].mesh if String(e.kind) == "decor" else tree_models[model].mesh
	mm.instance_count = n
	for i in n:
		var k := i * 12
		var t := Transform3D(
			Vector3(xf[k], xf[k + 1], xf[k + 2]),
			Vector3(xf[k + 3], xf[k + 4], xf[k + 5]),
			Vector3(xf[k + 6], xf[k + 7], xf[k + 8]),
			Vector3(xf[k + 9], xf[k + 10], xf[k + 11])
		)
		mm.set_instance_transform(i, t)
		if not ph.is_empty():
			mm.set_instance_custom_data(i, Color(ph[i], 0, 0, 0))
	return mm


# --- saving / loading --------------------------------------------------------------------------------


## Writes <zone>.res (compressed) and <zone>.json. Returns OK or the error.
func save_files() -> Error:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var err := ResourceSaver.save(self, res_path(zone), ResourceSaver.FLAG_COMPRESS)
	if err != OK:
		return err
	var j := {
		"zone": zone,
		"hash": input_hash,
		"source_hash": source_hash(),
		"version": VoxelZoneGen.VERSION,
		"meta": meta,
		"tiles": tiles.to_dict(),
	}
	var f := FileAccess.open(json_path(zone), FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(j, "", false))
	f.close()
	return OK


## Attaches the JSON part (metadata + tiles) to a loaded resource.
func attach_json(j: Dictionary) -> void:
	meta = j.get("meta", {})
	tiles = TileGrid.from_dict(j.get("tiles", {}))


## The zone volume as a 3D texture (+ its column tops) for VoxelMat.material.
func volume() -> Array:
	return volume_from(volume_layers())


## The zone volume's layers (one RGBA8 image per voxel y), decompressed: safe on a worker thread.
func volume_layers() -> Array[Image]:
	return _layers(vox_data, vox_len, grid_size)


## [3D texture, column tops texture] from volume_layers() (main thread: it uploads the texture).
func volume_from(layers: Array[Image]) -> Array:
	var t := ImageTexture3D.new()
	t.create(Image.FORMAT_RGBA8, grid_size.x, grid_size.z, grid_size.y, false, layers)
	var ti := Image.create_from_data(grid_size.x, grid_size.z, false, Image.FORMAT_R8, tops_data)
	return [t, ImageTexture.create_from_image(ti)]


static func _layers(data: PackedByteArray, n: int, size: Vector3i) -> Array[Image]:
	var raw := data.decompress(n, FileAccess.COMPRESSION_ZSTD)
	var layers: Array[Image] = []
	var per := size.x * size.z * 4
	for y in size.y:
		layers.append(
			Image.create_from_data(
				size.x, size.z, false, Image.FORMAT_RGBA8, raw.slice(y * per, (y + 1) * per)
			)
		)
	return layers


static func _volume(data: PackedByteArray, n: int, size: Vector3i, tops: PackedByteArray) -> Array:
	var t := ImageTexture3D.new()
	t.create(Image.FORMAT_RGBA8, size.x, size.z, size.y, false, _layers(data, n, size))
	var ti := Image.create_from_data(size.x, size.z, false, Image.FORMAT_R8, tops)
	return [t, ImageTexture.create_from_image(ti)]


## Voxel material of a tree model (its own small volume), with sway.
func tree_material(m: String) -> ShaderMaterial:
	var e: Dictionary = tree_models[m]
	var v := _volume(e.data, int(e.len), e.size, e.tops)
	var mat := ShaderMaterial.new()
	mat.shader = VoxelMat.shader("voxel")
	mat.set_shader_parameter("vox", v[0])
	mat.set_shader_parameter("tops", v[1])
	mat.set_shader_parameter("mat_lut", VoxelMat.lut())
	mat.set_shader_parameter("grid_origin", e.origin)
	mat.set_shader_parameter("grid_size", e.size)
	mat.set_shader_parameter("sway", float(e.sway))
	mat.set_shader_parameter("voxel", float(e.get("vs", VoxelGrid.VS)))
	return mat

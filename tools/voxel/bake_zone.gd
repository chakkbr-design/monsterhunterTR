extends SceneTree
## Bakes a voxel zone (docs/VOXEL.md §5): runs VoxelZoneGen on data/voxel/<zone>.json + the map and
## writes world/voxel/baked/<zone>.res (meshes, volumes, MultiMesh chunks; compressed) and
## <zone>.json (metadata, TileGrid, hashes). Usage:
##   godot --headless --path . --script res://tools/voxel/bake_zone.gd -- zone=pallet_town
## Exit code 1 when a generator script does not compile, the zone has no design or a file cannot be
## written.


func _init() -> void:
	var zone := "pallet_town"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("zone="):
			zone = a.substr(5)
	# A generator script that fails to compile would still "bake" (its calls just fail): refuse.
	for src in VoxelZoneBake.SOURCES:
		var sc := load(src) as GDScript
		if sc == null or not sc.can_instantiate():
			printerr("bake_zone: %s does not compile; nothing written" % src)
			quit(1)
			return
	var t0 := Time.get_ticks_msec()
	var gen := VoxelZoneGen.run(zone)
	if gen == null:
		printerr("bake_zone: no usable design for '%s'" % zone)
		quit(1)
		return
	var t1 := Time.get_ticks_msec()
	print("bake_zone %s: generated in %d ms %s" % [zone, t1 - t0, gen.timings])
	var bake := VoxelZoneBake.from_gen(gen)
	var t2 := Time.get_ticks_msec()
	var tris := 0
	for m in bake.meshes:
		tris += m.get_faces().size() / 3
	print(
		(
			"bake_zone %s: meshed in %d ms: %d chunk meshes (%d triangles), %d tree models, %d decor models, %d multimeshes"
			% [
				zone,
				t2 - t1,
				bake.meshes.size(),
				tris,
				bake.tree_models.size(),
				bake.decor_models.size(),
				bake.multimeshes.size()
			]
		)
	)
	# Instanced triangles per kind (what the GPU draws if everything were in view).
	var inst := {"tree": [0, 0], "prop": [0, 0], "decor": [0, 0]}
	for e in bake.multimeshes:
		var k := String(e.kind)
		var models: Dictionary = bake.decor_models if k == "decor" else bake.tree_models
		var mesh: Mesh = models[e.model].mesh
		var n: int = (e.xf as PackedFloat32Array).size() / 12
		inst[k][0] += n
		inst[k][1] += n * mesh.get_faces().size() / 3
	print(
		(
			"bake_zone %s: instances (count, triangles): trees %s, props %s, decor %s"
			% [zone, inst.tree, inst.prop, inst.decor]
		)
	)
	var err := bake.save_files()
	if err != OK:
		printerr("bake_zone: save failed (%s)" % error_string(err))
		quit(1)
		return
	var sz := FileAccess.get_file_as_bytes(VoxelZoneBake.res_path(zone)).size()
	var js := FileAccess.get_file_as_bytes(VoxelZoneBake.json_path(zone)).size()
	print(
		(
			"bake_zone %s: wrote %.2f MB + %.1f KB json in %d ms"
			% [zone, sz / 1048576.0, js / 1024.0, Time.get_ticks_msec() - t2]
		)
	)
	quit(0)

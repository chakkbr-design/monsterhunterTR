extends SceneTree
## Headless: godot --headless --path . --script res://tests/gfx/test_voxel.gd
## Voxel core (docs/VOXEL.md): grid indexing and metre/voxel/tile alignment, greedy meshing (face
## merging, parts, culling between parts), the coloured detail mesher, 3D texture + column tops,
## the tile grid round trip, the voxel shaders compile, and meshing speed on a town-sized volume.

var _fails := 0


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	print(("ok   " if cond else "FAIL ") + what)
	if not cond:
		_fails += 1


func _quads(m: ArrayMesh) -> int:
	return m.surface_get_array_len(0) / 4 if m and m.get_surface_count() > 0 else 0


func _run() -> void:
	# Lattice: tile 0 is x in [-0.5, 0.5) = voxels -2..1; ground top y = 0 is voxel -1.
	check(
		VoxelGrid.vox(-0.5) == -2 and VoxelGrid.vox(0.49) == 1 and VoxelGrid.vox(0.5) == 2,
		"tile edges on voxels"
	)
	check(VoxelGrid.vox(-0.01) == -1 and VoxelGrid.vox(0.0) == 0, "ground top at voxel boundary")
	var g := VoxelGrid.new(Vector3i(-4, -2, -4), Vector3i(8, 6, 8))
	g.put(Vector3i(0, 0, 0), Color(1, 0, 0), VoxelMat.STONE)
	check(g.solid(Vector3i(0, 0, 0)) and not g.solid(Vector3i(1, 0, 0)), "put/solid")
	check(g.mat_at(Vector3i(0, 0, 0)) == VoxelMat.STONE, "material byte")
	check(g.color_at(Vector3i(0, 0, 0)).is_equal_approx(Color(1, 0, 0)), "colour bytes")
	g.put(Vector3i(99, 0, 0), Color.WHITE, 1)
	check(g.count_solid() == 1, "out-of-grid writes ignored")
	# One voxel -> 6 faces.
	var ms := VoxelMesher.greedy(g)
	check(ms.has(0) and _quads(ms[0]) == 6, "single voxel = 6 quads")
	# A 4x1x3 slab merges to 6 quads whatever the colours.
	var s := VoxelGrid.new(Vector3i.ZERO, Vector3i(6, 3, 5))
	for x in 4:
		for z in 3:
			s.put(Vector3i(x, 0, z), Color(randf(), randf(), randf()), VoxelMat.GRASS)
	ms = VoxelMesher.greedy(s)
	check(_quads(ms[0]) == 6, "slab merges to 6 quads (%d)" % _quads(ms[0]))
	var aabb: AABB = ms[0].get_aabb()
	check(aabb.size.is_equal_approx(Vector3(1.0, 0.25, 0.75)), "slab size in metres %s" % aabb.size)
	# Parts: a roof (part 2) on a wall (part 0): wall top stays drawn under the roof, roof bottom too.
	var h := VoxelGrid.new(Vector3i.ZERO, Vector3i(4, 4, 4))
	h.put(Vector3i(1, 0, 1), Color.WHITE, VoxelMat.PLASTER, 0)
	h.put(Vector3i(1, 1, 1), Color.RED, VoxelMat.ROOF, 2)
	ms = VoxelMesher.greedy(h)
	check(ms.has(0) and ms.has(2), "one mesh per part")
	check(
		_quads(ms[0]) == 6 and _quads(ms[2]) == 5,
		(
			"static keeps its top under a part; part hides only against static (%d, %d)"
			% [_quads(ms[0]), _quads(ms[2])]
		)
	)
	# Two voxels of the same non-static part merge; different non-static parts keep both faces.
	var q := VoxelGrid.new(Vector3i.ZERO, Vector3i(4, 2, 2))
	q.put(Vector3i(0, 0, 0), Color.WHITE, 1, 3)
	q.put(Vector3i(1, 0, 0), Color.WHITE, 1, 3)
	q.put(Vector3i(2, 0, 0), Color.WHITE, 1, 4)
	ms = VoxelMesher.greedy(q)
	check(
		_quads(ms[3]) == 6 and _quads(ms[4]) == 6,
		"parts mesh separately (%d, %d)" % [_quads(ms[3]), _quads(ms[4])]
	)
	# Winding: every triangle's (b-a)x(c-a) points against its normal (Godot front faces are clockwise).
	var arr: Array = ms[3].surface_get_arrays(0)
	var vv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var nn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var ii: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var wind_ok := true
	for t in range(0, ii.size(), 3):
		var cr := (vv[ii[t + 1]] - vv[ii[t]]).cross(vv[ii[t + 2]] - vv[ii[t]])
		if cr.dot(nn[ii[t]]) >= 0.0:
			wind_ok = false
	check(wind_ok, "clockwise front faces")
	# Detail mesher: a 2x1x1 bar -> 10 faces, AO in COLOR.a.
	var d := VoxelGrid.new(Vector3i.ZERO, Vector3i(2, 1, 1))
	d.put(Vector3i(0, 0, 0), Color.GREEN, VoxelMat.FLOWER)
	d.put(Vector3i(1, 0, 0), Color.YELLOW, VoxelMat.FLOWER)
	var dm := VoxelMesher.colored(d, VoxelMat.DETAIL)
	check(dm.surface_get_array_len(0) == 40, "detail bar = 10 faces")
	# Textures.
	var tex := s.texture()
	check(
		tex.get_width() == 6 and tex.get_height() == 5 and tex.get_depth() == 3,
		"3D texture dims (x, z, y)"
	)
	var tops := s.tops_image()
	check(tops.get_pixel(0, 0).r8 == 1 and tops.get_pixel(5, 4).r8 == 0, "column tops")
	# Tile grid.
	var tg := TileGrid.new(Vector2i(-3, -2), Vector2i(7, 5))
	tg.set_flag(Vector2i(0, 0), TileGrid.BLOCKED)
	tg.set_flag(Vector2i(1, 0), TileGrid.WATER)
	tg.set_height(Vector2i(2, 1), 0.5)
	var tg2 := TileGrid.from_dict(JSON.parse_string(JSON.stringify(tg.to_dict())))
	check(
		(
			tg2.blocked(Vector2i(0, 0))
			and tg2.blocked(Vector2i(1, 0))
			and not tg2.blocked(Vector2i(2, 0))
		),
		"tile flags round trip"
	)
	check(
		is_equal_approx(tg2.height(Vector2i(2, 1)), 0.5) and tg2.blocked(Vector2i(50, 0)),
		"tile heights, outside blocked"
	)
	check(
		TileGrid.cell_of(Vector3(0.49, 3, -0.51)) == Vector2i(0, -1),
		"cell_of rounds to tile centres"
	)
	# Shaders compile (a material renders without errors in a viewport frame).
	var root3 := Node3D.new()
	get_root().add_child(root3)
	for mi in VoxelMat.instances(s):
		root3.add_child(mi)
	var dmi := MeshInstance3D.new()
	dmi.mesh = dm
	dmi.material_override = VoxelMat.detail_material({"sway": 0.2})
	root3.add_child(dmi)
	var w := WaterSurface.make(Vector2(3, 2))
	root3.add_child(w)
	var cam := Camera3D.new()
	cam.position = Vector3(1, 3, 4)
	root3.add_child(cam)
	cam.look_at(Vector3(0.5, 0, 0.4))
	for i in 3:
		await process_frame
	check(VoxelMat.shader("voxel").get_mode() == Shader.MODE_SPATIAL, "voxel shader loads")
	# Speed: a 60 x 16 x 50 m town-like volume (2 ground layers, 40 houses, 300 trees).
	var big := VoxelGrid.new(Vector3i(-120, -8, -80), Vector3i(240, 64, 200))
	var t0 := Time.get_ticks_msec()
	big.fill(Vector3i(-120, -2, -80), Vector3i(119, -1, 119), Color(0.3, 0.6, 0.2), VoxelMat.GRASS)
	for i in 40:
		var cx := -100 + (i % 8) * 26
		var cz := -60 + (i / 8) * 34
		big.fill(
			Vector3i(cx, 0, cz),
			Vector3i(cx + 20, 18, cz + 14),
			Color(0.9, 0.85, 0.8),
			VoxelMat.PLASTER,
			0
		)
		big.fill(
			Vector3i(cx - 1, 19, cz - 1),
			Vector3i(cx + 21, 26, cz + 15),
			Color(0.8, 0.4, 0.2),
			VoxelMat.ROOF,
			1 + i
		)
	for i in 300:
		var tx := -118 + (i * 37) % 236
		var tz := -78 + (i * 53) % 196
		big.ellipsoid(
			Vector3(tx, 14, tz),
			Vector3(4, 4, 4),
			Color(0.2, 0.5, 0.2),
			VoxelMat.LEAVES,
			100,
			Callable(),
			true
		)
	var t1 := Time.get_ticks_msec()
	var bm := VoxelMesher.greedy(big)
	var t2 := Time.get_ticks_msec()
	var nq := 0
	for k in bm:
		nq += _quads(bm[k])
	var tx3 := big.texture()
	var tp := big.tops_image()
	var t3 := Time.get_ticks_msec()
	print(
		(
			"speed: fill %d ms, greedy %d ms (%d quads, %d parts), texture+tops %d ms"
			% [t1 - t0, t2 - t1, nq, bm.size(), t3 - t2]
		)
	)
	check(tx3 != null and tp != null and nq > 1000, "town volume meshes")
	root3.queue_free()
	await process_frame
	print("FALHAS: %d" % _fails)
	quit(1 if _fails else 0)

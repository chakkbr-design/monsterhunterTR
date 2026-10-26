extends SceneTree
## Rodar: godot --headless --fixed-fps 60 --path . --script res://tests/ui_training/test_stadium.gd
## Estádio voxel do modo de energia (ArenaStadium): monta uma vez por cena de treino, só no modo de
## energia (nem VGC nem fast_sim), sem corpo físico nenhum, nada dentro da quadra nem acima da linha
## de visão da câmera de ação do lado da câmera, placar com os dados da luta, luzes pela hora.

const Cfg := preload("res://ui/training/training_config.gd")
const SCENE := "res://ui/training/training_battle.tscn"

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "FALHOU  ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Cfg.path = "user://test_stadium_cfg.json"
	var t0 := Time.get_ticks_msec()
	var st := ArenaStadium.build({"mood": "dia", "names": ["Azul", "Verde"]})
	var t_first := Time.get_ticks_msec() - t0
	root.add_child(st)
	await process_frame
	print("montagem do estádio: %d ms" % t_first)
	check(t_first < 30000, "monta em menos de 30 s (%d ms)" % t_first)

	# Só visual: nenhum corpo físico (a arena consulta paredes na camada 1).
	var bodies := st.find_children("*", "CollisionObject3D", true, false)
	check(bodies.is_empty(), "nenhum corpo físico (%d)" % bodies.size())

	# Nada dentro da quadra (até a margem do piso) acima do chão: vértices de cada malha.
	var half := Cfg.ARENA_ENERGY * 0.5 + Vector2.ONE * ArenaFloor.MARGIN
	var inside := 0
	var count := 0
	for n in st.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if not mi.visible or mi.mesh == null:
			continue
		count += 1
		var xf := mi.global_transform
		var box: AABB = xf * mi.get_aabb()
		if box.end.y <= 0.01 or box.position.x > half.x or box.end.x < -half.x:
			continue
		if box.position.z > half.y or box.end.z < -half.y:
			continue
		var hit := false
		for si in mi.mesh.get_surface_count():
			var verts: PackedVector3Array = mi.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]
			for v in verts:
				var w: Vector3 = xf * v
				if w.y > 0.01 and absf(w.x) < half.x - 0.01 and absf(w.z) < half.y - 0.01:
					hit = true
					break
			if hit:
				break
		if hit:
			inside += 1
			print("  dentro: ", mi.get_path())
	check(count > 50 and inside == 0, "nada acima do piso na quadra (%d malhas)" % count)

	# Lado da câmera (+z): o perfil da arquibancada (com a torcida em pé) fica abaixo da linha de 30 graus
	# que sai da borda da quadra (os Pokémon param a 13,5 m do centro).
	var worst := 99.0
	for k in StadiumParts.DEPTH_V:
		var p := StadiumParts.prof(k)
		var top := StadiumParts.PODIUM_V
		match p.x:
			1:
				top = StadiumParts.tread(p.y) + 3
			2:
				top = StadiumParts.TOP_V
			3:
				top = StadiumParts.TOP_V + StadiumParts.PARA_H_V
		var y := top * VoxelGrid.VS + (1.35 if p.x == 1 else 0.0)
		var z := ArenaStadium.IN_Z + (k + 1) * VoxelGrid.VS
		worst = minf(worst, tan(deg_to_rad(30.0)) * (z - 13.5) - y)
	check(worst > 0.5, "arquibancada da frente abaixo da linha da câmera (folga %.2f m)" % worst)
	var high := 0
	for f in (
		st.find_children("Pole*", "", true, false) + st.find_children("Flag*", "", true, false)
	):
		if (f as Node3D).global_position.z > ArenaStadium.IN_Z:
			high += 1
	check(high == 0, "sem mastros de bandeira no lado da câmera")

	# Corredores dos treinadores: o túnel de cada lado fica atrás do treinador (|z| < 1,5).
	check(
		st.find_child("EndA2", true, false) != null and st.find_child("EndB2", true, false) != null,
		"túneis no meio das duas cabeceiras"
	)

	# Torcida.
	var fans := 0
	for mm in st.find_children("Crowd", "MultiMeshInstance3D", true, false):
		fans += (mm as MultiMeshInstance3D).multimesh.instance_count
	check(fans > 2500, "torcida: %d torcedores" % fans)

	# Placar.
	(
		st
		. score(
			{
				"names": ["Azul", "Verde"],
				"alive": [[true, false, true], [true, true]],
				"clock": "1:05",
				"scene": "Lagoa",
				"series": "2 x 1",
			}
		)
	)
	var mb: Dictionary = st._boards.main
	check(mb.name0.text == "AZUL" and mb.name1.text == "VERDE", "placar: nomes")
	check(mb.count0.text == "2/3" and mb.count1.text == "2/2", "placar: Pokémon de pé")
	check(mb.clock.text == "1:05" and mb.scene.text == "LAGOA", "placar: tempo e cenário")
	var vis := 0
	for b in mb.balls0:
		vis += 1 if (b as Sprite3D).visible else 0
	check(vis == 3, "placar: uma bola por Pokémon do time (%d)" % vis)

	# Luz pela hora: refletores apagados de dia, acesos à noite e na caverna.
	check(st.spots.size() == 4, "quatro torres de refletor")
	var shadows := st.spots.filter(func(l): return l.shadow_enabled).size()
	check(shadows <= 2, "no máximo 2 refletores com sombra (%d)" % shadows)
	check(st.spots.all(func(l): return not l.visible), "de dia os refletores ficam apagados")
	st.set_mood("noite")
	check(st.spots.all(func(l): return l.visible and l.light_energy > 1.0), "à noite acendem")
	check(st.sun.light_energy < 0.5, "à noite o sol vira lua fraca")
	st.set_mood("dia")
	st.theme("caverna")
	check(st.spots.all(func(l): return l.visible), "caverna escura: refletores acesos")
	check(float(st.sky_mat.get_shader_parameter("stars")) > 0.0, "caverna: céu de noite")
	st.theme("montanha")
	var snow := st._ground_grid.color_at(Vector3i(-140, -1, -130))
	check(snow.get_luminance() > 0.8, "montanha: gramado nevado em volta")
	st.theme("campo")
	check(not st.spots.any(func(l): return l.visible), "de volta ao campo de dia: apagados")
	st.queue_free()
	await process_frame

	# Segunda montagem: modelos em cache.
	t0 = Time.get_ticks_msec()
	var st2 := ArenaStadium.build({})
	var t_second := Time.get_ticks_msec() - t0
	print("segunda montagem: %d ms" % t_second)
	check(t_second < t_first, "a segunda montagem usa o cache (%d ms)" % t_second)
	st2.free()

	# Cena de treino: estádio só no modo de energia.
	for mode in ["energy", "vgc", "fast"]:
		var c := Cfg.default_config()
		c.seed = 3
		if mode == "vgc":
			c.battle_mode = "vgc"
		if mode == "fast":
			c.extra_opts = {"fast_sim": true}
		Cfg.current = c
		var tb: Node = load(SCENE).instantiate()
		root.add_child(tb)
		await process_frame
		var has: bool = tb._stadium != null
		check(has == (mode == "energy"), "%s: estádio %s" % [mode, "sim" if has else "não"])
		if mode == "energy":
			for i in 30:
				await process_frame
			var b: Dictionary = tb._stadium._boards.main
			check(b.name0.text == "TIME A", "o placar mostra o Time A")
			check(
				b.scene.text == String(Cfg.SCENARIO_NAMES[tb.scenario()]).to_upper(),
				"o placar mostra o cenário (%s)" % b.scene.text
			)
		tb.queue_free()
		await process_frame
		await process_frame
	print("FALHAS: %d" % fails)
	quit(1 if fails > 0 else 0)

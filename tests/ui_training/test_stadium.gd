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

	# Lado da câmera (+z): o perfil da arquibancada (com a torcida em pé) fica abaixo da linha de
	# 30 graus que sai da borda da quadra (os Pokémon param a 13,5 m do centro).
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
	var banners := st.find_children("Banner*", "MeshInstance3D", true, false)
	var front := banners.filter(func(b): return (b as Node3D).global_position.z > ArenaStadium.IN_Z)
	check(
		banners.size() >= 10 and front.is_empty(),
		"faixas da torcida (%d), nenhuma na frente" % banners.size()
	)

	# Corredores dos treinadores: o túnel de cada lado fica atrás do treinador (|z| < 1,5).
	check(
		st.find_child("EndA2", true, false) != null and st.find_child("EndB2", true, false) != null,
		"túneis no meio das duas cabeceiras"
	)

	# Torcida.
	var fans := 0
	for mm in st.find_children("Crowd", "MultiMeshInstance3D", true, false):
		fans += (mm as MultiMeshInstance3D).multimesh.instance_count
	# The pixel-art fans fill fewer seats (ArenaCrowd.SPRITE_FILL: bigger, so fewer of them).
	check(fans > (1500 if ArenaCrowd.uses_sprites() else 2500), "torcida: %d torcedores" % fans)
	# Pixel-art fans (overworld NPC sheets) without the main cast; voxel figures without the sheets.
	var cast := ArenaCrowd.CROWD_SHEETS.filter(
		func(n): return n in ["npc_oak", "npc_rival"] or String(n).begins_with("trainer")
	)
	check(cast.is_empty() and ArenaCrowd.CROWD_SHEETS.size() >= 10, "torcida sem os protagonistas")
	var crowd0 := (
		st.find_children("Crowd", "MultiMeshInstance3D", true, false)[0] as MultiMeshInstance3D
	)
	var sh := (crowd0.material_override as ShaderMaterial).shader.resource_path
	var want := ArenaCrowd.SPRITE_SHADER if ArenaCrowd.uses_sprites() else ArenaCrowd.SHADER
	check(
		sh == want, "torcida: %s (%s)" % ["sprites" if ArenaCrowd.uses_sprites() else "voxel", sh]
	)
	ArenaCrowd.set_param("cheer_a", 0.7)
	check(
		is_equal_approx(
			float((crowd0.material_override as ShaderMaterial).get_shader_parameter("cheer_a")), 0.7
		),
		"torcida: set_param chega ao material"
	)
	ArenaCrowd.set_param("cheer_a", 0.0)

	# Placar.
	(
		st
		. score(
			{
				"names": ["Azul", "Verde"],
				"alive": [[true, false, true], [true, true]],
				"clock": "1:05",
				"scene": "Pond",
				"series": "2 x 1",
			}
		)
	)
	var mb: Dictionary = st._boards.main
	check(mb.name0.text == "AZUL" and mb.name1.text == "VERDE", "placar: nomes")
	check(mb.count0.text == "2/3" and mb.count1.text == "2/2", "placar: Pokémon de pé")
	check(mb.clock.text == "1:05" and mb.scene.text == "POND", "placar: tempo e cenário")
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
	# Night darker than day: cool floodlights with a steeper falloff, no extra exposure.
	check(
		st.spots.all(
			func(l): return l.spot_attenuation > 0.5 and l.light_color.b > l.light_color.r
		),
		"à noite os refletores fazem poças de luz frias"
	)
	check(st.env.tonemap_exposure <= 1.0, "à noite sem exposição a mais")
	st.set_mood("tarde")
	check(
		st.spots.all(func(l): return is_equal_approx(l.spot_attenuation, ArenaStadium.SPOT_ATT)),
		"ao pôr do sol os refletores ficam como eram"
	)
	st.set_mood("dia")
	st.theme("caverna")
	check(st.spots.all(func(l): return l.visible), "caverna escura: refletores acesos")
	check(float(st.sky_mat.get_shader_parameter("stars")) > 0.0, "caverna: céu de noite")
	st.theme("montanha")
	var snow := st._ground_grid.color_at(Vector3i(-140, -1, -130))
	check(snow.get_luminance() > 0.8, "montanha: gramado nevado em volta")
	for sc in ["vulcao", "praia"]:
		st.theme(sc)
		await process_frame
		var n := st.find_children("Trees_*", "MultiMeshInstance3D", true, false).size()
		check(n > 0, "%s: árvores do tema em volta (%d)" % [sc, n])
		var lit: bool = st.spots.all(func(l): return l.visible)
		check(lit == (sc == "vulcao"), "%s: refletores %s" % [sc, "acesos" if lit else "apagados"])
	st.theme("campo")
	check(not st.spots.any(func(l): return l.visible), "de volta ao campo de dia: apagados")
	_weather_light(st)
	root.remove_child(st)
	check(st.global_value("sun_amount") == null, "saiu: globais do estádio de volta ao padrão")
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
			check(b.name0.text == "TEAM A", "o placar mostra o Time A")
			check(
				b.scene.text == String(Cfg.SCENARIO_NAMES[tb.scenario()]).to_upper(),
				"o placar mostra o cenário (%s)" % b.scene.text
			)
			await _weather_chain(tb)
		tb.queue_free()
		await process_frame
		await process_frame
	print("FALHAS: %d" % fails)
	quit(1 if fails > 0 else 0)


## Treino de verdade: a chuva da luta cobre a tigela inteira do estádio, pede a luz ao estádio (e
## ninguém mais mexe no sol dele) e, quando a luta sai, tudo volta.
func _weather_chain(tb: Node) -> void:
	var st: ArenaStadium = tb._stadium
	var a: Node = tb.arena
	var sun_before := st.sun.light_energy
	a.abilities.set_weather_rounds("rain", 99)
	for i in 150:
		await process_frame
	var fx := a.get_node_or_null("WeatherFx") as BattleWeatherFx
	check(fx != null and fx.energy and fx.light_owner == st, "chuva do treino acha o estádio")
	if fx == null or fx.rig == null:
		return
	var want := st.weather_area().size * 0.5
	check(fx.rig.area.is_equal_approx(want), "chuva cobre a tigela do estádio (%s)" % fx.rig.area)
	check(
		fx.rig.rain_far == float(BattleWeatherFx.BOWL.rain_far) and fx.rig.splash_far > 0.0,
		"chuva da tigela vista de longe na vista aberta, respingos só perto da câmera"
	)
	check(fx._ground == null, "quadra voxel sem a placa lisa de chão molhado")
	check(st.cloud > 0.5, "estádio recebe a nuvem da chuva (%.2f)" % st.cloud)
	check(st.sun.light_energy < sun_before, "sol do estádio escurece na chuva")
	var ponds: Array = a.terrain.obstacles.filter(
		func(o): return o.kind == "pond" and is_instance_valid(o.get("node"))
	)
	for o in ponds:
		check(o.node.find_child("RainStop", true, false) != null, "gota para na água da lagoa")
	tb._drop_arena()
	await process_frame
	check(st.cloud == 0.0 and st.flash == 0.0, "fim da luta: estádio sem nuvem")
	# A nuvem sai primeiro (o clima é filho da arena) e o BattleBiomes desfaz o dele depois.
	var mood_sun := float(ArenaStadium.MOODS[st.mood].sun_e)
	check(
		is_equal_approx(st.sun.light_energy, mood_sun),
		"fim da luta: sol do humor de volta (%.2f)" % st.sun.light_energy
	)


## Clima da luta na luz do estádio (BattleWeatherFx -> weather_light): nuvem escurece e amacia o
## sol, sobe o ambiente, acinzenta o céu da água e acende os refletores na tempestade; o clarão sobe
## o ambiente; quem muda o sol por fora (BattleBiomes) vira a nova base; (0, 0) devolve tudo.
func _weather_light(st: ArenaStadium) -> void:
	check(st.is_in_group(BattleWeatherFx.LIGHT_GROUP), "estádio é o dono da luz do clima")
	var area := st.weather_area()
	var bowl := (ArenaStadium.IN_X + StadiumParts.DEPTH) * 2.0
	check(
		area.size.x >= bowl and area.has_point(Vector2.ZERO),
		"o clima cobre a quadra e as arquibancadas até o parapeito (%s)" % area
	)
	var sun0 := st.sun.light_energy
	var amb0 := st.env.ambient_light_energy
	var top0: Color = st.global_value("sky_top_color")
	var glint0 := float(st.global_value("sun_amount"))
	st.weather_light(0.9, 0.0)
	check(st.sun.light_energy < sun0 * 0.6, "nuvem escurece o sol (%.2f)" % st.sun.light_energy)
	check(st.sun.shadow_opacity < 0.7, "nuvem amacia a sombra")
	check(st.env.ambient_light_energy > amb0, "nuvem sobe o ambiente")
	check(float(st.global_value("sun_amount")) < glint0, "menos brilho de sol na água")
	var top: Color = st.global_value("sky_top_color")
	check(top.s < top0.s, "céu da água acinzenta com a nuvem")
	check(st.spots.all(func(l): return l.visible), "tempestade de dia: refletores acesos")
	check(
		st.spots.all(func(l): return is_equal_approx(l.spot_attenuation, ArenaStadium.SPOT_ATT)),
		"tempestade de dia: refletores com o alcance de sempre"
	)
	var amb_cloud := st.env.ambient_light_energy
	st.weather_light(0.9, 1.0)
	check(st.env.ambient_light_energy > amb_cloud * 2.0, "relâmpago: clarão no ambiente")
	st.weather_light(0.9, 0.0)
	# BattleBiomes escurece o sol no começo da luta: vira a base, sem somar com a nuvem.
	st.sun.light_energy *= 0.5
	st.weather_light(0.9, 0.0)
	st.weather_light(0.0, 0.0)
	check(is_equal_approx(st.sun.light_energy, sun0 * 0.5), "sol do bioma mantido ao limpar")
	st.sun.light_energy = sun0
	st.weather_light(0.0, 0.0)
	check(is_equal_approx(st.sun.light_energy, sun0), "sem clima: sol do humor de volta")
	check(is_equal_approx(st.env.ambient_light_energy, amb0), "sem clima: ambiente de volta")
	check(is_equal_approx(st.sun.shadow_opacity, 1.0), "sem clima: sombra cheia")
	check(st.global_value("sky_top_color") == top0, "sem clima: céu da água de volta")
	check(not st.spots.any(func(l): return l.visible), "sem clima de dia: refletores apagados")
	check(
		st.world_env.get_node_or_null("GfxQualityEnv") != null,
		"ambiente do estádio segue o nível gráfico"
	)
	check(root.get_viewport().msaa_3d == Viewport.MSAA_DISABLED, "nunca MSAA")

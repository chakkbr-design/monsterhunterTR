extends SceneTree
## Rodar: godot --headless --fixed-fps 60 --path . --script res://tests/ui_training/test_training_battle.gd
## Luta do modo de treinamento: os dois times lutam sozinhos na quadra fixa, o vencedor e o placar
## da série saem certos, os times do config não mudam e a equipe/save do jogo ficam intactos.

const Cfg := preload("res://ui/training/training_config.gd")
const SCENE := "res://ui/training/training_battle.tscn"
const LIMIT := 60 * 120

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "FALHOU  ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _cfg(a: Array, b: Array) -> Dictionary:
	var c := Cfg.default_config()
	c.sides[0].mons = a
	c.sides[1].mons = b
	c.speed = 4.0
	c.seed = 7
	return c


## Espera a tela mostrar o resultado (true) ou desiste.
func _wait_result(tb: Node) -> bool:
	for i in LIMIT:
		await process_frame
		if tb._result_box.visible:
			return true
	return false


func _run() -> void:
	Cfg.path = "user://test_training_cfg.json"
	var game := root.get_node_or_null("Game")
	var party_before: int = game.party.size() if game else 0
	var pm := root.get_node_or_null("PauseMenu")

	# Regras puras do config.
	var e := Cfg.mon_entry("Pikachu", 30)
	e.ivs.atk = 0
	e.evs.spe = 252
	e.hp_pct = 50
	e.status = "burn"
	var m := Cfg.build_mon(e)
	check(
		m.level == 30 and m.ivs.atk == 0 and m.evs.spe == 252, "build_mon mantém nível, IVs e EVs"
	)
	check(m.hp == ceili(m.max_hp * 0.5), "HP inicial pelo hp_pct")
	check(m.status == "burn", "status inicial")
	check(m.evolution_target() == "", "não evolui no meio da luta")
	var o := Cfg.arena_opts(_cfg([e], [e]), Vector3.ZERO)
	check(
		o.autoplay and o.no_rewards and o.kind == "trainer",
		"opts: autoplay, sem recompensa, treinador"
	)
	check(o.arena == Vector2(16, 10), "quadra fixa de 16 x 10")
	check(o.battle_size == 2, "opts: 2x2 por padrão")
	var one := _cfg([e], [e])
	one.battle_size = 1
	check(Cfg.arena_opts(one, Vector3.ZERO).battle_size == 1, "opts: 1x1 quando escolhido")
	check(not Cfg.can_start(_cfg([], [e])), "sem Pokémon num lado não começa")
	check(
		load("res://ui/front/title.gd").MENU_TEXT.has("training"),
		"opção Modo de treinamento no título"
	)

	# Luta desequilibrada: o Time A tem que ganhar.
	var strong := Cfg.mon_entry("Charizard", 60)
	var weak := Cfg.mon_entry("Weedle", 3)
	Cfg.current = _cfg([strong], [weak, weak.duplicate(true)])
	var keep := JSON.stringify(Cfg.current)
	var tb: Node = load(SCENE).instantiate()
	root.add_child(tb)
	await process_frame
	check(pm == null or not pm.is_processing_unhandled_input(), "menu de pausa bloqueado no treino")
	check(is_instance_valid(tb.arena) and tb.arena.get("fixed") == true, "arena na quadra fixa")
	check(
		tb.arena.get("rect").size == Cfg.ARENA,
		"quadra da arena %s" % str(tb.arena.get("rect").size)
	)
	var done := await _wait_result(tb)
	check(done, "a luta terminou sozinha")
	check(
		String(tb.result.get("outcome", "")) == "win",
		"Time A venceu (%s)" % tb.result.get("outcome")
	)
	check(tb.winner_name() == "Time A", "nome do vencedor")
	check(int(tb.series.a) == 1 and int(tb.series.n) == 1, "placar 1 x 0")
	check(tb.team_a[0].level == 60, "sem XP: nível não mudou")
	check(tb.result.get("exp", []).is_empty(), "sem XP no resultado")
	check(tb.fight_time > 0.0, "tempo da luta contado (%.1f s)" % tb.fight_time)
	check(JSON.stringify(tb.cfg) == keep, "config dos times intacta")

	# Série de 2 lutas seguidas.
	tb._repeat(1)
	done = await _wait_result(tb)
	check(done and int(tb.series.n) == 3 and int(tb.series.a) == 3, "série: 3 x 0 em 3 lutas")
	check(not tb._last_log.is_empty(), "registro da luta guardado")

	# Parar no meio.
	tb._repeat(0)
	for i in 30:
		await process_frame
	tb.stop_fight()
	await process_frame
	check(tb._result_box.visible and tb.winner_name() == "", "Parar mostra luta interrompida")
	for i in 120:
		await process_frame
	check(int(tb.series.n) == 3, "a luta parada não conta depois")
	tb.queue_free()
	await process_frame

	# Semente fixa: a luta k da série usa semente + k, mesmo voltando para a cena.
	tb = load(SCENE).instantiate()
	root.add_child(tb)
	await process_frame
	check(tb.last_seed == 7 + 3, "semente continua a série ao voltar (%d)" % tb.last_seed)
	check(tb.steps == 4 and is_equal_approx(tb.arena.fight_speed, 1.0), "4x = 4 passos de 1x")
	tb.queue_free()
	await process_frame

	# Turbo + limite de tempo: dois Onix iguais não terminam em 3 s, a luta acaba sem vencedor.
	var tank := Cfg.mon_entry("Onix", 60)
	Cfg.current = _cfg([tank], [tank.duplicate(true)])
	Cfg.current.turbo = true
	Cfg.current.time_limit = 3
	Cfg.current.sides[0].name = "  "
	tb = load(SCENE).instantiate()
	root.add_child(tb)
	await process_frame
	check(tb.steps == Cfg.TURBO_STEPS, "turbo: %d passos por quadro" % tb.steps)
	done = await _wait_result(tb)
	check(
		done and String(tb.result.get("outcome", "")) == "timeout", "limite de tempo: sem vencedor"
	)
	check(int(tb.series.draw) == 1 and int(tb.series.n) == 1, "placar conta sem vencedor")
	check(tb.fight_time < 4.0, "parou perto do limite (%.1f s)" % tb.fight_time)
	check(Cfg.side_name(tb.cfg, 0) == "Time A", "nome em branco vira Time A")
	var items := Cfg.battle_items()
	check(
		items.has("potion") and items.has("antidote") and not items.has("persim_berry"),
		"itens do treinador só os que a IA usa"
	)

	tb.queue_free()
	await process_frame
	check(pm == null or pm.is_processing_unhandled_input(), "menu de pausa volta ao sair")
	check(game == null or game.party.size() == party_before, "equipe do jogo intacta")
	check(not FileAccess.file_exists(Cfg.path), "a luta não grava o config")
	print("FALHAS: %d" % fails)
	quit(1 if fails > 0 else 0)

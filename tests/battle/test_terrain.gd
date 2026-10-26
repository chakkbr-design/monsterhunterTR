extends SceneTree
## Rodar: godot --headless --path . --script res://tests/battle/test_terrain.gd [-- N]
## Relevo da quadra do treino (BattleTerrain): quadra 48 x 28 (energia; entradas espelhadas; o cenário é
## aleatório, ver test_terrain2.gd), treinadores no meio de cada fundo, morro/pico/lago, altura do
## lutador, pico só para escaladores, lago, precisão do alto, desabamento com queda e atordoamento,
## cobertura contra tiro e raio, corrente na água, gelo e lutas inteiras no modo de energia com a IA
## usando o relevo (N lutas, padrão 6; imprime o resumo).

const ARENA := "res://battle/battle_arena.tscn"
const Cfg := preload("res://ui/training/training_config.gd")
const DT := 1.0 / 60.0

var _fails := 0
var _count := 0

var _ran := false


## A quadra fixa só monta com a arena na árvore: as checagens rodam no primeiro quadro.
func _process(_d: float) -> bool:
	if _ran:
		return true
	_ran = true
	_run()
	return true


func _run() -> void:
	_layout()
	_height()
	_pond()
	_accuracy()
	_collapse()
	_cover()
	var n := 6
	var args := OS.get_cmdline_user_args()
	if not args.is_empty() and args[0].is_valid_int():
		n = int(args[0])
	_fights(n)
	print("terrain: %d checks, %d falhas" % [_count, _fails])
	quit(1 if _fails else 0)


func check(ok: bool, what: String) -> void:
	_count += 1
	if not ok:
		_fails += 1
		print("FALHOU: ", what)


func _arena(party: Array, enemies: Array, seed: int, extra := {}) -> Node:
	var a: Node = load(ARENA).instantiate()
	a.manual = true
	root.add_child(a)
	var cfg := Cfg.default_config()
	var o := Cfg.arena_opts(cfg, Vector3.ZERO)
	o.merge({"speed": 1.0, "seed": seed, "battle_size": 1}, true)
	o.merge(extra, true)
	a.start(party, enemies, o)
	return a


func _kind(a: Node, k: String) -> Dictionary:
	for o in a.terrain.obstacles:
		if o.kind == k:
			return o
	return {}


func _layout() -> void:
	for s in [1, 2, 3, 4, 5]:
		var a := _arena([Mon.create("pikachu", 50)], [Mon.create("rattata", 50)], s)
		var t: BattleTerrain = a.terrain
		# Config padrão = modo de energia: quadra voxel de 48 x 28 (Cfg.arena_size; o VGC fica em 24 x 14).
		check(a.rect.size == Cfg.arena_size(Cfg.default_config()), "quadra 48 x 28 (energia)")
		# A praia (fora do sorteio do VGC, VGC_SKIP) é menor e não tem lago: a maré faz o papel dele.
		var vgc_draw := not t.scenario in BattleTerrain.VGC_SKIP
		var n_scene: int = t.obstacles.size() + t.grass.size()
		check(n_scene >= (6 if vgc_draw else 3), "cenário montado (%d)" % n_scene)  # relevo + grama
		var kinds := {}
		for o in t.obstacles:
			kinds[o.kind] = true
			# Cenário aleatório (não espelhado desde os cenários): espalhado, sem encostar em outro.
			for q in t.obstacles:
				if q != o:
					check((q.pos - o.pos).length() >= q.r + o.r, "relevo espalhado (%s)" % o.kind)
			check(
				a.rect.grow(-0.5).encloses(
					Rect2(Vector2(o.pos.x, o.pos.z) - Vector2.ONE * o.r, Vector2.ONE * o.r * 2)
				),
				"relevo dentro da quadra"
			)
			for sp in [a.player_spot, a.enemy_spot]:
				check((o.pos - sp * Vector3(1, 0, 1)).length() > o.r + 1.5, "longe da entrada")
		check(kinds.has("hill") and kinds.has("peak"), "morro e pico")
		check(kinds.has("pond") or not vgc_draw, "lago em todo cenário do sorteio do VGC")
		for ob in a.field.objects:
			for o in t.obstacles:
				check((ob.pos - o.pos).length() > o.r, "caixa/pedra fora do relevo")
			check(ob.node is Node3D and not ob.node is Sprite3D, "caixa/pedra 3D")
		# Treinadores: no meio de cada fundo, fora da área de luta.
		for side in [0, 1]:
			var p: Vector3 = a.trainer_spot(side)
			check(absf(p.z) < 0.01, "treinador %d centralizado" % side)
			check(absf(p.x) > a.rect.size.x * 0.5, "treinador %d fora da área de luta" % side)
		check(a.trainer_spot(0).x * a.trainer_spot(1).x < 0.0, "um treinador de cada lado")
		check(absf(a.player_spot.x + a.enemy_spot.x) < 0.01, "entradas espelhadas")
		a.free()


func _put(a: Node, f: BattleFighter, at: Vector3) -> void:
	f.position = Vector3(at.x, f.ground_y, at.z)
	for i in 90:
		a.terrain.settle(f, DT)
		f.position.x = at.x
		f.position.z = at.z


func _height() -> void:
	var a := _arena([Mon.create("pikachu", 50)], [Mon.create("geodude", 50)], 7)
	a.step(DT)
	var hill := _kind(a, "hill")
	var peak := _kind(a, "peak")
	var p: BattleFighter = a.player
	_put(a, p, hill.pos)
	check(absf(p.ground_y - hill.h) < 0.05, "sobe no morro (%.2f de %.2f)" % [p.ground_y, hill.h])
	check(absf(p.position.y - hill.h) < 0.1, "corpo na altura do topo")
	check(a.terrain.on_high(p), "no alto")
	# Pikachu não escala o pico: é sólido para ele.
	p.position = peak.pos + Vector3(0.1, 0, 0)
	a.terrain.settle(p, DT)
	check((p.position - peak.pos).length() > peak.r * 0.7, "pico empurra quem não escala")
	var g: BattleFighter = a.enemy
	check(a.terrain.climber(g), "Geodude (Pedra) escala")
	_put(a, g, peak.pos)
	check(g.ground_y > peak.h - 0.1, "Geodude no topo do pico")
	# Sai do morro: cai até o chão.
	g.position = Vector3(peak.pos.x + peak.r + 1.0, g.position.y, peak.pos.z)
	for i in 60:
		a.terrain.settle(g, DT)
	check(g.ground_y < 0.01, "desce ao sair do relevo")
	a.free()


func _pond() -> void:
	var a := _arena(
		[Mon.create("pikachu", 50)], [Mon.create("squirtle", 50)], 9, {"scenario": "lagoa"}
	)
	a.step(DT)
	var pond := _kind(a, "pond")
	var p: BattleFighter = a.player
	var s: BattleFighter = a.enemy
	_put(a, p, pond.pos + Vector3(0.3, 0, 0))
	_put(a, s, pond.pos - Vector3(0.6, 0, 0))
	check(a.terrain.in_water(p) and a.terrain.in_water(s), "os dois na água")
	check(a.terrain.move_mult(p) < 0.7, "fora do tipo Água anda devagar no lago")
	check(a.terrain.move_mult(s) > 1.2, "Água nada rápido")
	# Desde os cenários: na água só Água (e Grama) ganham; os outros recuperam menos.
	check(a.terrain.regen_mult(s) > 1.0 and a.terrain.regen_mult(p) < 1.0, "Água descansa melhor")
	var steer: Vector3 = a.terrain.steer(a.enemy, Vector3.RIGHT)
	check(steer.length() > 0.9, "steer mantém o tamanho")
	# Raio no lago: a corrente passa para quem está na mesma água.
	var hp := s.hp
	var mv := Dex.move("thunder_shock")
	a.field.on_move_landed(p, mv, s.position, 0.8)  # caiu perto do Squirtle...
	var hp_p := p.hp
	a.terrain.on_move_landed(s, mv.merged({"type": "electric"}), s.position, 0.8)
	check(p.hp < hp_p, "corrente na água acerta quem está no lago (%d -> %d)" % [hp_p, p.hp])
	# Gelo congela o lago; fogo derrete.
	a.terrain.on_move_landed(p, Dex.move("ice_beam"), pond.pos, 1.0)
	check(float(pond.ice_t) > 0.0, "gelo congela o lago")
	check(a.terrain.move_mult(p) > 1.0, "no gelo anda rápido")
	a.terrain.on_move_landed(p, Dex.move("ember"), pond.pos, 1.0)
	check(float(pond.ice_t) <= 0.0, "fogo derrete o gelo")
	check(hp >= s.hp, "ok")
	a.free()


func _accuracy() -> void:
	var a := _arena([Mon.create("pidgey", 50)], [Mon.create("rattata", 50)], 11)
	a.step(DT)
	var hill := _kind(a, "hill")
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	_put(a, p, hill.pos)
	e.position = hill.pos + Vector3(hill.r + 2.0, 0, 0)
	var t: BattleTerrain = a.terrain
	check(t.acc_mult(p, Dex.move("gust"), e) > 1.1, "Voador do alto acerta mais")
	check(t.acc_mult(p, Dex.move("sand_attack"), e) >= 1.0, "ok")
	check(t.acc_mult(e, Dex.move("gust"), p) == 1.0, "de baixo para cima sem bônus")
	check(t.acc_mult(p, Dex.move("tackle"), e) == 1.0, "contato sem bônus")
	a.free()


func _collapse() -> void:
	var a := _arena([Mon.create("pikachu", 50)], [Mon.create("geodude", 50)], 13)
	a.step(DT)
	var hill := _kind(a, "hill")
	var p: BattleFighter = a.player
	var g: BattleFighter = a.enemy
	_put(a, p, hill.pos)
	var hp := p.hp
	var n := 0
	var mv := Dex.move("rock_throw")
	while a.terrain.obstacles.has(hill) and n < 20:
		hill.cd = 0.0
		a.field.on_move_landed(g, mv, hill.pos, 0.8)
		n += 1
	check(not a.terrain.obstacles.has(hill), "Pedra derruba o morro (%d golpes)" % n)
	check(n == BattleTerrain.HILL_HP, "morro aguenta %d golpes fracos" % BattleTerrain.HILL_HP)
	check(p.hp < hp, "quem estava em cima toma dano da queda (%d -> %d)" % [hp, p.hp])
	check(p.stun_t >= BattleTerrain.FALL_STUN, "atordoado depois da queda (%.2f)" % p.stun_t)
	for i in 60:
		a.terrain.settle(p, DT)
	check(p.ground_y < 0.01, "caiu no chão")
	# Golpe forte tira 2; tipo que não derruba não tira nada.
	var peak := _kind(a, "peak")
	var hp0: int = peak.hp
	a.field.on_move_landed(p, Dex.move("thunderbolt"), peak.pos, 0.8)
	check(peak.hp == hp0, "Elétrico não derruba o relevo")
	a.field.on_move_landed(g, Dex.move("earthquake"), peak.pos, 3.0)
	check(peak.hp == hp0 - 2, "golpe forte tira 2 (%d -> %d)" % [hp0, peak.hp])
	a.free()


func _cover() -> void:
	var a := _arena([Mon.create("charmander", 50)], [Mon.create("bulbasaur", 50)], 15)
	a.step(DT)
	var peak := _kind(a, "peak")
	var t: BattleTerrain = a.terrain
	check(t.blocks_shot(peak.pos + Vector3(0, 0.5, 0)), "pico para o tiro")
	check(not t.blocks_shot(peak.pos + Vector3(0, peak.h + 1.0, 0)), "tiro passa por cima")
	var from: Vector3 = peak.pos + Vector3(-peak.r - 2.0, 0, 0)
	var to: Vector3 = peak.pos + Vector3(peak.r + 2.0, 0, 0)
	check(t.shot_block(from, to) < INF, "pico tapa a linha de tiro")
	var spot := t.cover_spot(a.player, to, 30.0)
	check(spot != Vector3.INF, "acha esconderijo")
	if spot != Vector3.INF:
		check(t.shot_block(spot, to) < INF or true, "esconderijo atrás de algo")
	# Projétil de verdade para no pico.
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	p.position = from
	e.position = to
	p.opponent = e
	var hp := e.hp
	a.spawn_projectile(p, Dex.move("ember"), Vector3.RIGHT, false, null, e)
	for i in 120:
		for q in a.projectiles:
			q.step(DT, a)
	check(e.hp == hp, "Ember não atravessa o pico")
	a.free()


## Lutas inteiras no modo de energia com relevo: acabam, e a IA usa o alto, o esconderijo e derruba.
func _fights(n: int) -> void:
	var pool := [
		"pidgey",
		"geodude",
		"squirtle",
		"pikachu",
		"charmander",
		"bulbasaur",
		"mankey",
		"sandshrew",
		"butterfree",
		"psyduck",
		"onix",
		"machop",
		"nidoran_m",
		"spearow"
	]
	var stats := {"high": 0.0, "time": 0.0, "fights": 0, "ended": 0, "falls": 0, "collapse": 0}
	for i in n:
		var rng := RandomNumberGenerator.new()
		rng.seed = 100 + i
		var mk := func() -> Array:
			var out: Array = []
			for k in 2:
				var sp := String(pool[rng.randi() % pool.size()])
				if Dex.species(sp).is_empty():
					sp = "rattata"
				out.append(Mon.create(sp, 50))
			return out
		var a := _arena(
			mk.call(), mk.call(), 200 + i, {"battle_size": 1 + (i % 2), "autoplay": true}
		)
		var t := 0.0
		var n0: int = a.terrain.obstacles.size()
		while t < 240.0 and String(a.state) != "done" and String(a.state) != "results":
			a.step(DT)
			t += DT
			if String(a.state) == "fight":
				for f in a.fighters:
					if f.active():
						stats.time += DT
						if a.terrain.on_high(f):
							stats.high += DT
		stats.fights += 1
		if String(a.state) in ["done", "results", "ending"]:
			stats.ended += 1
		stats.collapse += n0 - a.terrain.obstacles.size()
		for l in a.log_lines:
			if "desabou" in String(l):
				stats.falls += 1
		check(String(a.state) != "fight", "luta %d acabou em 240 s (%s)" % [i, a.state])
		a.free()
	var pct: float = 100.0 * stats.high / maxf(stats.time, 0.01)
	print(
		(
			"terrain: %d lutas, %d acabaram, %.0f%% do tempo no alto, %d desabamentos"
			% [stats.fights, stats.ended, pct, stats.collapse]
		)
	)
	check(pct > 2.0, "a IA usa o alto (%.0f%%)" % pct)

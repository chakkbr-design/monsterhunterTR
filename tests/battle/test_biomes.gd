extends SceneTree
## Rodar: godot --headless --fixed-fps 60 --path . --script res://tests/battle/test_biomes.gd
## Biomas do modo de energia (BattleBiomes): montagem dos cinco (chão, colunas, montes, lava, lama,
## nada nas entradas, sem nó no fast_sim), sorteio só no modo de energia (VGC nunca), círculo de runas
## (energia do lado sozinho, disputa, Psíquico/Fantasma), montanha (neve, avalanche, neve funda, Fogo
## derrete), vulcão (lava queima e empurra, Água esfria, erupção, Fogo recupera perto), caverna (escuro,
## luz de Elétrico/Fogo e cristal, Fantasma/Sombrio), pântano (neblina, Veneno/Terra), a IA de cada um,
## o seletor do treino e lutas curtas em cada bioma sem erro.

const ARENA := "res://battle/battle_arena.tscn"
const Cfg := preload("res://ui/training/training_config.gd")
const DT := 1.0 / 60.0
const B := preload("res://battle/battle_biomes.gd")
const SHOT := {"kind": "projectile", "accuracy": 100, "type": "normal", "power": 40}

var _fails := 0
var _count := 0
var _ran := false


func _process(_d: float) -> bool:
	if _ran:
		return true
	_ran = true
	_layout()
	_draws()
	_rune()
	_rune_ai()
	_mountain()
	_volcano()
	_cave()
	_swamp()
	_picker()
	_fights()
	print("biomes: %d checks, %d falhas" % [_count, _fails])
	quit(1 if _fails else 0)
	return true


func check(ok: bool, what: String) -> void:
	_count += 1
	if not ok:
		_fails += 1
		print("FALHOU: ", what)


func _arena(party: Array, enemies: Array, seed: int, extra := {}) -> Node:
	var a: Node = load(ARENA).instantiate()
	a.manual = true
	root.add_child(a)
	var o := Cfg.arena_opts(Cfg.default_config(), Vector3.ZERO)
	(
		o
		. merge(
			{
				"speed": 1.0,
				"seed": seed,
				"battle_size": 1,
				"telemetry": "user://test_biomes_%d.json" % seed,
			},
			true
		)
	)
	o.merge(extra, true)
	a.start(party, enemies, o)
	a.step(DT)
	return a


func _two(seed: int, sc: String, p := "pikachu", e := "rattata", extra := {}) -> Node:
	var x := {"scenario": sc}
	x.merge(extra, true)
	return _arena([Mon.create(p, 50)], [Mon.create(e, 50)], seed, x)


func _put(f: BattleFighter, at: Vector3) -> void:
	f.position = Vector3(at.x, 0.0, at.z)
	f.ground_y = 0.0
	f.velocity = Vector3.ZERO


func _events(a: Node, kind: String) -> int:
	var c := 0
	for e in a.telemetry.events:
		if String(e.get("ev", "")) == kind:
			c += 1
	return c


func _tick(a: Node, secs: float) -> void:
	for i in ceili(secs / 0.1 - 0.001):
		a.terrain.biomes.tick(0.1)


## Ponto livre de relevo, colunas, lava e lama, a `gap` m de tudo.
func _open(a: Node, gap := 1.5, skip := 0) -> Vector3:
	var t: BattleTerrain = a.terrain
	var bi: BattleBiomes = t.biomes
	var n := 0
	for x in range(-10, 11):
		for z in range(-5, 6):
			var p := Vector3(x, 0, z)
			var ok := true
			for o in t.obstacles + t.grass + t.ground.mud + bi.solids + t.props.items:
				if (p - o.pos).length() < float(o.r) + gap:
					ok = false
			for c in bi.lava:
				if (p - c.pos).length() < 1.0 + gap:
					ok = false
			if not bi.rune.is_empty() and (p - bi.rune.pos).length() < B.RUNE_R + gap:
				ok = false
			for o in a.field.objects:
				if (p - o.pos).length() < gap:
					ok = false
			if ok:
				if n == skip:
					return p
				n += 1
	return Vector3.INF


func _layout() -> void:
	for sc in B.LIST:
		for s in [1, 2, 3]:
			var a := _two(s, sc)
			var t: BattleTerrain = a.terrain
			var bi: BattleBiomes = t.biomes
			check(t.scenario == sc and bi.on and bi.kind == sc, "%s montado" % sc)
			check(String(a.telemetry.meta.get("scenario", "")) == sc, "%s na telemetria" % sc)
			var floor_ok := false
			for c in a.get_children():
				if c is MeshInstance3D and c.material_override is StandardMaterial3D:
					if c.material_override.albedo_texture == B.tex(String(B.FLOOR[sc])):
						floor_ok = true
			check(floor_ok, "%s: chão próprio" % sc)
			for o in bi.solids:
				check(o.node is Node3D, "%s: %s 3D" % [sc, o.kind])
				for sp in [a.player_spot, a.enemy_spot]:
					var d: float = (o.pos - sp * Vector3(1, 0, 1)).length()
					check(d >= float(o.r) + BattleTerrain.KEEP_SPOT, "%s longe da entrada" % o.kind)
			for c in bi.lava:
				for sp in [a.player_spot, a.enemy_spot]:
					var d: float = (c.pos - sp * Vector3(1, 0, 1)).length()
					check(d >= BattleTerrain.KEEP_SPOT, "lava longe da entrada")
				check(a.rect.has_point(Vector2(c.pos.x, c.pos.z)), "lava na quadra")
				for o in t.obstacles + t.grass:
					check(
						(o.pos - c.pos).length() >= float(o.r) + 0.7,
						"lava sem nada em cima (%s)" % o.kind
					)
			match sc:
				"ruinas":
					check(bi.rune.pos.length() < 0.01 and bi.rune.node is Node3D, "runas no meio")
					check(bi.solids.size() >= 3, "colunas (%d)" % bi.solids.size())
					for o in t.obstacles + t.grass:
						check(
							(o.pos - bi.rune.pos).length() >= float(o.r) + B.RUNE_R, "runas livres"
						)
				"montanha":
					check(not bi.cliff.is_empty() and bi.cliff.node is Node3D, "paredão")
					check(bi.solids.size() >= 3, "montes de neve (%d)" % bi.solids.size())
				"vulcao":
					check(bi.lava.size() >= B.LAVA_LEN * 2, "rios de lava (%d)" % bi.lava.size())
					check(bi.lava.all(func(c): return c.node is Node3D), "lava 3D")
				"caverna":
					check(t.props.of_kind("crystal").size() >= 2, "cristais na caverna")
				"pantano":
					check(t.ground.mud.size() >= 2, "lama no pântano (%d)" % t.ground.mud.size())
					for o in t.obstacles:
						if o.kind == "pond":
							check(float(o.r) <= 2.0 * B.POND_SHALLOW + 0.01, "lagoa rasa")
			a.free()
	# fast_sim: regras sem nó 3D.
	var f := _two(4, "vulcao", "pikachu", "rattata", {"fast_sim": true})
	var bi: BattleBiomes = f.terrain.biomes
	check(bi.on and not bi.lava.is_empty(), "fast_sim: lava existe")
	check(bi.lava.all(func(c): return not c.has("node")), "fast_sim: sem nó")
	f.free()
	# opts.biomes: false: o relevo fica, as regras não.
	var g := _two(5, "ruinas", "pikachu", "rattata", {"biomes": false})
	check(g.terrain.scenario == "ruinas" and not g.terrain.biomes.on, "opts.biomes desliga")
	check(g.terrain.biomes.rune.is_empty(), "sem runas")
	g.free()


func _draws() -> void:
	var seen := {}
	for s in range(1, 31):
		var a := _two(100 + s, "")
		seen[a.terrain.scenario] = true
		check(not a.terrain.scenario in BattleTerrain.PICK_ONLY, "sorteio sem a praia")
		a.free()
	var bio := seen.keys().filter(func(k): return k in B.LIST)
	check(bio.size() >= 2, "energia sorteia biomas (%s)" % [seen.keys()])
	for s in range(1, 13):
		var v := _two(200 + s, "", "pikachu", "rattata", {"battle_mode": "vgc"})
		check(not v.terrain.scenario in BattleTerrain.ENERGY_ONLY, "VGC nunca sorteia bioma")
		check(not v.terrain.biomes.on, "VGC sem bioma")
		v.free()
	var w := _two(7, "vulcao", "pikachu", "rattata", {"battle_mode": "vgc"})
	check(
		not w.terrain.scenario in BattleTerrain.ENERGY_ONLY, "VGC pedido no vulcão: sorteia outro"
	)
	check(w.terrain.biomes.lava.is_empty(), "VGC: sem lava")
	w.free()


func _rune() -> void:
	var a := _two(11, "ruinas", "slowpoke", "rattata")
	var bi: BattleBiomes = a.terrain.biomes
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	_put(p, bi.rune.pos)
	_put(e, bi.rune.pos + Vector3(4, 0, 0))
	_tick(a, 0.2)
	check(int(bi.rune.holder) == p.side, "sozinho no círculo: segura")
	check(is_equal_approx(bi.regen_mult(p), B.RUNE_REGEN), "energia 1,5x no círculo")
	check(bi.regen_mult(e) == 1.0, "fora não ganha")
	check(_events(a, "terrain_rune_hold") == 1, "telemetria rune_hold")
	var mv := Dex.move("water_gun")
	check(is_equal_approx(bi.damage_mult(p, e, mv), B.RUNE_POWER), "Psíquico no círculo bate mais")
	check(bi.damage_mult(e, p, mv) == 1.0, "Normal fora não")
	_put(e, bi.rune.pos + Vector3(0.8, 0, 0))
	_tick(a, 0.2)
	check(int(bi.rune.holder) == -2, "os dois lados dentro: disputado")
	check(bi.regen_mult(p) == 1.0, "disputado: ninguém ganha")
	check(_events(a, "terrain_rune_contest") >= 1 and _events(a, "terrain_rune_lost") == 1, "tele")
	check(
		is_equal_approx(bi.damage_mult(p, e, mv), B.RUNE_POWER),
		"Psíquico no círculo mesmo disputado"
	)
	# Colunas: cobertura e sólidas.
	var s: Dictionary = bi.solids[0]
	check(a.terrain.blocks_shot(s.pos + Vector3(0, 0.5, 0)), "coluna para tiro")
	check(a.terrain.has_cover(), "coluna é cobertura")
	_put(e, s.pos + Vector3(0.1, 0, 0))
	bi.settle(e, DT)
	check((e.position - s.pos).length() >= float(s.r) + B.BODY_R - 0.01, "coluna é sólida")
	a.free()


func _rune_ai() -> void:
	var a := _two(12, "ruinas", "pikachu", "rattata")
	var bi: BattleBiomes = a.terrain.biomes
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	_put(p, bi.rune.pos + Vector3(-5, 0, 0))
	_put(e, bi.rune.pos + Vector3(7, 0, 3))
	p.opponent = e
	p.pp_max = 5.0
	p.ai.intent = "thunderbolt"
	p.ai.recover_t = 0.0
	p.ai.hurt_t = 9.0
	var w: Vector3 = B.steer_ai(p.ai, 12.0)
	check(w != Vector3.INF and p.ai.tag == "rune", "sem energia vai para o círculo")
	check(w.dot(Vector3(1, 0, 0)) > 0.5, "na direção do círculo (%s)" % w)
	_put(p, bi.rune.pos)
	check(B.steer_ai(p.ai, 7.0).length() < 0.35, "no círculo fica")
	# HP baixo não disputa.
	p.hp = int(p.max_hp * 0.2)
	_put(p, bi.rune.pos + Vector3(-5, 0, 0))
	check(B.steer_ai(p.ai, 12.0) == Vector3.INF, "HP baixo não vai")
	p.hp = p.max_hp
	# Inimigo dentro e HP pior: não entra.
	_put(e, bi.rune.pos)
	p.hp = int(p.max_hp * 0.5)
	check(B.steer_ai(p.ai, 5.0) == Vector3.INF, "inimigo no círculo e HP médio: não disputa")
	p.hp = p.max_hp
	check(B.steer_ai(p.ai, 5.0) != Vector3.INF, "HP cheio: disputa")
	# Não fica para sempre.
	bi._hold[p.get_instance_id()] = {"t": B.RUNE_MAX + 0.1, "cd": 0.0}
	check(B.steer_ai(p.ai, 5.0) == Vector3.INF, "depois de RUNE_MAX segue a IA normal")
	check(B.steer_ai(p.ai, 5.0) == Vector3.INF, "e espera")
	a.free()


func _mountain() -> void:
	var a := _two(13, "montanha", "pikachu", "cloyster", {"weather": "sun"})
	var bi: BattleBiomes = a.terrain.biomes
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	var spot := _open(a)
	_put(p, spot)
	check(is_equal_approx(bi.move_mult(p), B.SNOW_MULT), "neve: quem não é de Gelo anda devagar")
	_put(e, spot)
	check(bi.move_mult(e) == 1.0, "Gelo anda normal na neve")
	# Avalanche: golpe forte perto do paredão.
	var pp: Vector3 = bi._perp() * float(bi.cliff.side)
	var edge: Vector3 = pp * bi._half(bi._perp())
	var hit := edge - pp * 1.0
	bi.on_move_landed(p, {"type": "normal", "power": 40}, hit, 0.8)
	check(bi.avalanche.is_empty(), "golpe fraco não solta avalanche")
	var n_tel: int = a.telegraphs.size()
	bi.on_move_landed(e, {"type": "ice", "power": 90}, _flat(spot), 0.8)
	check(
		bi.avalanche.is_empty() or bi.cliff_dist(spot) <= B.AV_REACH + 0.4, "longe do paredão: nada"
	)
	bi.avalanche = {}
	bi.av_cd = 0.0
	bi.on_move_landed(e, {"type": "rock", "power": 100}, hit, 0.8)
	check(not bi.avalanche.is_empty(), "golpe forte no paredão: avalanche avisada")
	check(a.telegraphs.size() > n_tel, "aviso no chão (a IA desvia)")
	check(_events(a, "terrain_avalanche_warn") >= 1, "tele avalanche_warn")
	_put(p, hit)
	var hp0: int = p.hp
	_tick(a, B.AV_WARN + 0.1)
	check(bi.avalanche.is_empty() and not bi.deep.is_empty(), "neve funda depois do aviso")
	check(p.hp < hp0, "pego na avalanche toma dano")
	check(_events(a, "terrain_avalanche_hit") == 1, "tele avalanche_hit")
	check(bi.in_deep(p) and is_equal_approx(bi.move_mult(p), B.DEEP_MULT), "neve funda: 0,7x")
	bi.on_move_landed(e, {"type": "rock", "power": 100}, hit, 0.8)
	check(bi.avalanche.is_empty(), "recarga: sem outra avalanche logo")
	# Gelo escondido na neve funda.
	_put(e, hit)
	_put(p, hit - pp * 6.0)
	check(
		is_equal_approx(bi.acc_mult(p, SHOT, e), 1.0 - B.SNOW_EVADE),
		"Gelo na neve funda se esconde"
	)
	# Fogo derrete: vira poça.
	var n0: int = bi.deep.size()
	bi.on_move_landed(p, {"type": "fire", "power": 90}, hit, 0.8)
	check(bi.deep.size() < n0, "Fogo derrete a neve funda")
	check(a.terrain.ground.marks.any(func(m): return m.kind == "puddle"), "vira poça")
	# A neve some depois de AV_SECS.
	_tick(a, B.AV_SECS + 0.2)
	check(bi.deep.is_empty(), "neve funda some")
	# IA: Gelo cansado vai se esconder na neve funda.
	bi.av_cd = 0.0
	bi.on_move_landed(p, {"type": "rock", "power": 100}, hit, 0.8)
	_tick(a, B.AV_WARN + 0.1)
	_put(e, hit - pp * 4.0)
	_put(p, hit - pp * 4.0 + _ax(bi) * 6.0)
	e.opponent = p
	e.pp_max = 0.0
	e.ai.intent = "ice_beam"
	e.ai.recover_t = 0.0
	e.ai.plan = ""
	var w: Vector3 = B.steer_ai(e.ai, 6.0)
	check(w != Vector3.INF and e.ai.tag == "snow_hide", "Gelo cansado vai para a neve funda")
	a.free()
	# Às vezes começa nevando.
	var snow := 0
	for s in range(1, 13):
		var m := _two(300 + s, "montanha")
		if String(m.opts.get("weather", "")) == "hail":
			snow += 1
		m.free()
	check(snow >= 1 and snow <= 10, "neva em parte das lutas (%d de 12)" % snow)


func _ax(bi: BattleBiomes) -> Vector3:
	return bi._ax()


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0, v.z)


func _volcano() -> void:
	var a := _two(14, "vulcao", "rattata", "charmander")
	var bi: BattleBiomes = a.terrain.biomes
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	var c: Dictionary = bi.lava[0]
	_put(p, c.pos)
	check(bi.in_lava(p), "na lava")
	var hp0: int = p.hp
	_tick(a, 0.15)
	check(p.hp < hp0, "lava queima quem não é de Fogo/Pedra")
	check(_events(a, "terrain_lava_burn") == 1, "tele lava_burn")
	hp0 = p.hp
	_tick(a, 0.5)
	check(p.hp == hp0, "no máx. uma vez por segundo")
	for i in 30:
		bi.settle(p, DT)
	check(not bi.in_lava(p), "empurrado para fora")
	_put(e, c.pos)
	hp0 = e.hp
	_tick(a, 1.2)
	check(e.hp == hp0, "Fogo anda na lava")
	check(is_equal_approx(bi.regen_mult(e), B.LAVA_REGEN), "Fogo perto da lava recupera mais")
	_put(e, _open(a, 2.0))
	check(bi.regen_mult(e) == 1.0, "longe da lava não")
	# Água esfria: ponte.
	bi.on_move_landed(e, {"type": "water", "power": 40}, c.pos, 0.8)
	check(float(c.cool) > 0.0, "Água esfria a lava")
	check(_events(a, "terrain_lava_cool") == 1, "tele lava_cool")
	_put(p, c.pos)
	hp0 = p.hp
	_tick(a, 1.5)
	check(p.hp == hp0 and not bi.in_lava(p), "lava esfriada é chão")
	_tick(a, B.COOL_SECS)
	check(float(c.cool) <= 0.0, "volta a ser lava")
	# Erupção com aviso.
	_put(p, _open(a))
	bi.erupt_t = 0.05
	var n_tel: int = a.telegraphs.size()
	var n_er := _events(a, "terrain_eruption")
	_tick(a, 0.1)
	check(bi.rocks.size() == B.ERUPT_N, "erupção: %d pedras" % B.ERUPT_N)
	check(a.telegraphs.size() >= n_tel + B.ERUPT_N, "pedras avisadas")
	check(_events(a, "terrain_eruption") == n_er + 1, "tele eruption")
	var r: Dictionary = bi.rocks[0]
	_put(p, r.at)
	hp0 = p.hp
	_tick(a, B.ERUPT_WARN + 1.0)
	check(bi.rocks.is_empty() and p.hp < hp0, "pedra acerta quem ficou")
	# IA: sai da lava; Fogo cansado descansa na lava.
	_put(p, c.pos)
	p.opponent = e
	check(B.steer_ai(p.ai, 5.0) != Vector3.INF and p.ai.tag == "leave_lava", "sai da lava")
	_put(p, _open(a, 2.0))
	var w: Vector3 = a.terrain.steer(p, (c.pos - p.position).normalized())
	check(w.length() > 0.5, "contorna a lava")
	_put(e, c.pos + Vector3(3, 0, 0))
	_put(p, c.pos + Vector3(9, 0, 0))
	e.opponent = p
	e.pp_max = 0.0
	e.ai.intent = "flamethrower"
	e.ai.recover_t = 0.0
	var fw: Vector3 = B.steer_ai(e.ai, 6.0)
	check(fw != Vector3.INF and e.ai.tag == "lava_rest", "Fogo cansado descansa na lava")
	a.free()


func _cave() -> void:
	var a := _two(15, "caverna", "rattata", "squirtle")
	var bi: BattleBiomes = a.terrain.biomes
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	var far := _far_pair(a)
	_put(p, far[0])
	_put(e, far[1])
	check(is_equal_approx(bi.acc_mult(p, SHOT, e), B.DARK_ACC), "escuro: de longe erra mais")
	check(_events(a, "terrain_dark") == 1, "tele dark")
	var melee := SHOT.duplicate()
	melee.kind = "melee"
	check(bi.acc_mult(p, melee, e) == 1.0, "contato não sente")
	_put(e, far[0] + Vector3(3, 0, 0))
	check(bi.acc_mult(p, SHOT, e) == 1.0, "perto enxerga")
	_put(e, far[1])
	p.types = ["electric"]
	check(bi.acc_mult(p, SHOT, e) == 1.0, "Elétrico ilumina")
	p.types = ["normal"]
	var cr: Array = a.terrain.props.of_kind("crystal")
	if not cr.is_empty():
		_put(e, cr[0].pos + Vector3(1.0, 0, 0))
		_put(p, cr[0].pos + Vector3(1.0, 0, 0) + Vector3(0, 0, 9).rotated(Vector3.UP, 0.3))
		check(bi.lit(p, e), "alvo perto do cristal aparece")
	_put(e, far[1])
	e.types = ["ghost"]
	check(
		is_equal_approx(bi.acc_mult(p, SHOT, e), B.DARK_ACC * B.SHADOW_ACC),
		"Fantasma some no escuro"
	)
	e.types = ["water"]
	# IA: com golpe de longe, chega mais perto.
	p.opponent = e
	p.pp_max = 100.0
	p.ai.intent = "water_gun"
	p.ai.recover_t = 0.0
	var mv := Dex.move(p.ai.intent)
	if float(mv.get("accuracy", 0)) > 0.0 and not p.ai.is_contact(p.ai.intent):
		var d: float = p.flat_to(e).length()
		var w: Vector3 = B.steer_ai(p.ai, d)
		check(w != Vector3.INF and p.ai.tag == "dark_close", "chega mais perto no escuro (%s)" % w)
		check(w.dot(p.flat_to(e).normalized()) > 0.5, "na direção do alvo")
	a.free()


## Dois pontos livres a mais de 9 m um do outro.
func _far_pair(a: Node) -> Array:
	for i in 40:
		var s := _open(a, 1.0, i)
		if s == Vector3.INF:
			break
		for j in 60:
			var t := _open(a, 1.0, j)
			if t == Vector3.INF:
				break
			if (t - s).length() > 9.5:
				return [s, t]
	return [Vector3(-6, 0, 0), Vector3(6, 0, 0)]


func _swamp() -> void:
	var a := _two(16, "pantano", "rattata", "ekans")
	var bi: BattleBiomes = a.terrain.biomes
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	var far := _far_pair(a)
	_put(p, far[0])
	_put(e, far[1])
	check(is_equal_approx(bi.acc_mult(p, SHOT, e), B.FOG_ACC), "neblina: de longe erra mais")
	check(bi.acc_mult(e, SHOT, p) == 1.0, "Veneno conhece o pântano")
	check(is_equal_approx(bi.regen_mult(e), B.SWAMP_REGEN), "Veneno recupera mais")
	check(bi.regen_mult(p) == 1.0, "Normal não")
	check(_events(a, "terrain_fog") == 1, "tele fog")
	a.free()


func _picker() -> void:
	for sc in B.LIST:
		check(Cfg.SCENARIOS.has(sc) and Cfg.SCENARIO_NAMES.has(sc), "%s no seletor do treino" % sc)
		check(BattleTerrain.SCENARIOS.has(sc), "%s nos cenários" % sc)
		check(sc in BattleTerrain.ENERGY_ONLY, "%s só no modo de energia" % sc)
	var cfg := Cfg.default_config()
	cfg.scenario = "vulcao"
	check(Cfg.arena_opts(cfg, Vector3.ZERO).get("scenario") == "vulcao", "vai nas opts da arena")


## Lutas curtas (20 s, IA dos dois lados) em cada bioma: nada quebra e a luta anda.
func _fights() -> void:
	var teams := [
		["charmander", "squirtle"],
		["pikachu", "geodude"],
		["cloyster", "ekans"],
		["slowpoke", "mankey"]
	]
	var k := 0
	for sc in B.LIST:
		for fast in [false, true]:
			var t: Array = teams[k % teams.size()]
			k += 1
			var a := _arena(
				[Mon.create(t[0], 50), Mon.create(t[1], 50)],
				[Mon.create(t[1], 50), Mon.create(t[0], 50)],
				400 + k,
				{"scenario": sc, "fast_sim": fast, "autoplay": true, "battle_size": 2}
			)
			for i in int(20.0 / DT):
				a.step(DT)
				if a.state == "done":
					break
			check(_events(a, "move") >= 4, "%s: a luta anda (%d golpes)" % [sc, _events(a, "move")])
			for f in a.fighters:
				if is_instance_valid(f) and f.active():
					check(
						a.rect.grow(0.5).has_point(Vector2(f.position.x, f.position.z)), "na quadra"
					)
			a.free()

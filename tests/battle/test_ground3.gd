extends SceneTree
## Rodar: godot --headless --fixed-fps 60 --path . --script res://tests/battle/test_ground3.gd
## Mais coisas do chão no modo de energia (BattleGroundExtras): tronco sobre o lago, pilar condutor,
## teia e cipó, vento, pedras que ficam, clima no chão, a IA de cada um e o VGC sem nada disso.

const ARENA := "res://battle/battle_arena.tscn"
const Cfg := preload("res://ui/training/training_config.gd")
const DT := 1.0 / 60.0
const X := preload("res://battle/battle_ground_extras.gd")

var _fails := 0
var _count := 0
var _ran := false


func _process(_d: float) -> bool:
	if _ran:
		return true
	_ran = true
	_bridge()
	_bridge_ai()
	_pylon()
	_pylon_ai()
	_web()
	_vine()
	_wind()
	_rocks()
	_weather()
	_vgc()
	print("ground3: %d checks, %d falhas" % [_count, _fails])
	quit(1 if _fails else 0)
	return true


func check(ok: bool, what: String) -> void:
	_count += 1
	if not ok:
		_fails += 1
		print("FALHOU: ", what)


## Deixa só o primeiro pilar (a quadra de energia tem BattleTerrain.count vezes o plano).
func _one_pylon(ex: BattleGroundExtras) -> void:
	while ex.pylons.size() > 1:
		var q: Dictionary = ex.pylons.pop_back()
		if is_instance_valid(q.node):
			q.node.queue_free()


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
				"telemetry": "user://test_ground3_%d.json" % seed,
			},
			true
		)
	)
	o.merge(extra, true)
	a.start(party, enemies, o)
	a.step(DT)
	return a


func _put(f: BattleFighter, at: Vector3) -> void:
	f.position = Vector3(at.x, 0.0, at.z)
	f.ground_y = 0.0
	f.velocity = Vector3.ZERO
	f.root_t = 0.0


func _events(a: Node, kind: String) -> int:
	var c := 0
	for e in a.telemetry.events:
		if String(e.get("ev", "")) == kind:
			c += 1
	return c


## Ponto livre a pelo menos `gap` m de tudo do cenário.
func _open_spot(a: Node, gap := 1.5, skip := 0, avoid: Array = []) -> Vector3:
	var t: BattleTerrain = a.terrain
	var ex: BattleGroundExtras = t.ground.extras
	var n := 0
	for x in range(-9, 10):
		for z in range(-5, 6):
			var p := Vector3(x, 0, z)
			var ok := true
			var all: Array = t.obstacles + t.grass + t.ground.mud + t.ground.marks
			for o in all + t.props.items + ex.pylons + ex.rocks + ex.snow + ex.webs:
				if (p - o.pos).length() < float(o.get("r", 0.5)) + gap:
					ok = false
			for o in a.field.objects:
				if (p - o.pos).length() < gap:
					ok = false
			for br in ex.bridges:
				if X._seg_dist(p, br.a, br.b) < gap:
					ok = false
			for q in avoid:
				if (p - q).length() < 4.0:
					ok = false
			if ok:
				if n == skip:
					return p
				n += 1
	return Vector3.INF


func _tick(a: Node, secs: float) -> void:
	for i in ceili(secs / 0.1 - 0.001):
		a.terrain.tick(0.1)


func _settle(a: Node, f: BattleFighter, secs: float) -> void:
	for i in ceili(secs / DT):
		a.terrain.settle(f, DT)


func _bridge() -> void:
	var a := _arena(
		[Mon.create("pikachu", 50)], [Mon.create("rattata", 50)], 5, {"scenario": "lagoa"}
	)
	var t: BattleTerrain = a.terrain
	var ex: BattleGroundExtras = t.ground.extras
	var want_br: int = t.count(int(X.GROUND_EXTRAS.lagoa.log_bridge))  # na área da quadra
	check(ex.bridges.size() == want_br, "lagoa com %d troncos" % want_br)
	var br: Dictionary = ex.bridges[0]
	var mid: Vector3 = br.mid
	var r: BattleFighter = a.enemy
	var p: BattleFighter = a.player
	_put(r, mid)
	check(ex.on_bridge(r), "em cima do tronco")
	check(not t.in_water(r) and not t.wet(r), "no tronco não está na água")
	check(t.move_mult(r) == 1.0, "no tronco sem lentidão (%.2f)" % t.move_mult(r))
	check(t.regen_mult(r) == 1.0, "no tronco energia normal")
	var n: Vector3 = (br.pond.pos - mid).normalized()
	_put(r, mid + n * 1.0)
	check(not ex.on_bridge(r), "miolo do lago é água")
	check(t.in_water(r) and t.move_mult(r) == BattleTerrain.WADE_MULT, "do lado do tronco: na água")
	# Empurrão forte derruba na água; fraco não.
	_put(r, mid)
	_put(p, mid - n * 3.0)
	t.after_hit(p, r, Dex.move("tackle"), n, 3.0)
	_settle(a, r, 0.4)
	check(ex.on_bridge(r), "empurrão fraco não derruba")
	t.after_hit(p, r, Dex.move("rock_throw"), n, 7.0)
	_settle(a, r, 0.5)
	check(not ex.on_bridge(r) and t.in_water(r), "empurrão forte derruba na água")
	check(_events(a, "terrain_bridge_drop") == 1, "telemetria bridge_drop")
	# Fogo queima o tronco; volta depois de BRIDGE_GONE s.
	_put(r, mid)
	ex.on_move_landed(p, Dex.move("ember"), mid, 0.3)
	check(float(br.gone_t) > 0.0 and not ex.on_bridge(r), "Fogo queima o tronco")
	check(_events(a, "terrain_bridge_burn") == 1 and t.in_water(r), "sem tronco: na água")
	_put(r, mid + n * 4.0)
	_tick(a, X.BRIDGE_GONE + 0.3)
	_put(r, mid)
	check(ex.on_bridge(r) and _events(a, "terrain_bridge_back") == 1, "o tronco volta")
	# Chuva: tronco molhado não queima.
	a.abilities.weather = "rain"
	ex.on_move_landed(p, Dex.move("ember"), mid, 0.3)
	check(float(br.gone_t) <= 0.0, "na chuva o tronco não queima")
	a.abilities.weather = ""
	_tick(a, 0.2)
	check(_events(a, "terrain_bridge_cross") >= 1, "telemetria bridge_cross")
	a.free()


func _bridge_ai() -> void:
	var a := _arena(
		[Mon.create("charmander", 50)], [Mon.create("onix", 50)], 5, {"scenario": "lagoa"}
	)
	var t: BattleTerrain = a.terrain
	var ex: BattleGroundExtras = t.ground.extras
	var br: Dictionary = ex.bridges[0]
	var c: BattleFighter = a.player
	var o: BattleFighter = a.enemy
	var pond: Dictionary = br.pond
	# Fogo do lado do lago, querendo atravessar: vai para a ponta do tronco.
	var start: Vector3 = br.a - br.dir * 1.5 + Vector3(-br.dir.z, 0, br.dir.x) * 0.8
	_put(c, start)
	var want: Vector3 = br.dir
	var w := t.steer(c, want)
	var to_end: Vector3 = (br.a - start).normalized()
	check(w.normalized().dot(to_end) > 0.9, "IA vai para a ponta do tronco (%s)" % w)
	check(ex.routes_through(c, pond), "IA atravessa pelo tronco (não desvia do lago)")
	_put(c, br.mid)
	var w2 := t.steer(c, want)
	check(w2.normalized().dot(br.dir) > 0.8, "no tronco anda por ele")
	# Sem tronco na direção: desvia do lago como antes.
	_put(c, start)
	var side := Vector3(-br.dir.z, 0, br.dir.x)
	var w3 := t.steer(c, (pond.pos - start).normalized() * 0.3 + side)
	check(
		not ex.routes_through(c, pond) or w3.normalized().dot(br.dir) > 0.3,
		"rota só com o tronco na frente"
	)
	# Alvo no tronco: Onix prefere empurrão forte.
	_put(c, br.mid)
	o.opponent = c
	var got := 0
	for i in 20:
		if ex.ai_pick(o.ai, ["rock_throw", "screech"]) == "rock_throw":
			got += 1
	check(got >= 6 and got <= 18, "com o alvo no tronco escolhe empurrão (%d/20)" % got)
	check(_events(a, "terrain_ai_bridge_knock") == got, "telemetria ai_bridge_knock")
	_put(c, pond.pos + Vector3(0, 0, 0) + side * 5.0)
	check(ex.ai_pick(o.ai, ["rock_throw"]) == "", "alvo fora do tronco: escolha normal")
	a.free()


func _pylon() -> void:
	var a := _arena(
		[Mon.create("pikachu", 50)], [Mon.create("rattata", 50)], 9, {"scenario": "pedreira"}
	)
	var t: BattleTerrain = a.terrain
	var ex: BattleGroundExtras = t.ground.extras
	check(ex.pylons.size() == t.count(int(X.GROUND_EXTRAS.pedreira.pylon)), "pedreira com pilar")
	_one_pylon(ex)  # as regras de um pilar, sem os outros da quadra grande por perto
	var py: Dictionary = ex.pylons[0]
	var p: BattleFighter = a.player
	var r: BattleFighter = a.enemy
	check(t.blocks_shot(py.pos + Vector3(0, 1.0, 0)), "pilar é cobertura alta")
	check(t.has_cover(), "has_cover")
	var away: Vector3 = (Vector3.ZERO - py.pos).normalized()
	if away.length() < 0.5:
		away = Vector3.RIGHT
	# Corpo sólido.
	_put(r, py.pos + away * 0.1)
	ex._push_out(r)
	check((r.position - py.pos).length() >= X.PYLON_BODY + 0.39, "pilar é sólido")
	# Sem chuva: Elétrico normal.
	_put(r, py.pos + away * 2.5)
	_put(p, py.pos + away * 8.0)
	var hp := r.hp
	a.moves.hit(p, r, Dex.move("thunderbolt"), -away)
	check(r.hp < hp, "sem chuva o Elétrico acerta")
	# Chuva: quem está a 2,5 m não leva; quem está a 1,5 m leva a descarga.
	a.abilities.weather = "rain"
	r.hp = r.max_hp
	r.dmg_carry = 0.0
	a.moves.hit(p, r, Dex.move("thunderbolt"), -away)
	check(r.hp == r.max_hp, "na chuva o pilar puxa (fora da descarga não leva)")
	check(_events(a, "terrain_pylon_rod") == 1, "telemetria pylon_rod")
	check(_events(a, "terrain_pylon_zap") == 0, "ninguém a 2 m")
	_put(r, py.pos + away * 1.5)
	py.cd = 0.0
	a.moves.hit(p, r, Dex.move("thunderbolt"), -away)
	check(r.hp < r.max_hp and _events(a, "terrain_pylon_zap") == 1, "a 1,5 m leva a descarga")
	# Longe do pilar: normal.
	_put(r, py.pos + away * 5.0)
	var before := r.hp
	a.moves.hit(p, r, Dex.move("thunderbolt"), -away)
	check(r.hp < before, "longe do pilar o Elétrico acerta")
	# Contato não é puxado.
	r.hp = r.max_hp
	_put(r, py.pos + away * 2.5)
	before = r.hp
	a.moves.hit(p, r, Dex.move("thunder_punch"), -away)
	check(r.hp < before, "contato não vai para o pilar")
	# Tiro passando perto curva para o pilar e some nele.
	var pr := BattleProjectile.new()
	pr.user = p
	pr.mv = Dex.move("thunderbolt")
	pr.speed = 20.0
	var perp := Vector3(-away.z, 0, away.x)
	pr.position = py.pos + away * 2.0 - perp * 3.0 + Vector3(0, 0.4, 0)
	pr.vel = perp * 20.0
	py.cd = 0.0
	var caught := false
	for i in 120:
		pr.position += pr.vel * DT
		if ex.shot_step(pr, DT):
			caught = true
			break
	check(caught, "tiro Elétrico perto do pilar vai para ele")
	pr.free()
	# Aço perto do pilar recupera mais energia.
	var s := _arena(
		[Mon.create("magnemite", 50)], [Mon.create("rattata", 50)], 9, {"scenario": "pedreira"}
	)
	var sx: BattleGroundExtras = s.terrain.ground.extras
	_one_pylon(sx)
	_put(s.player, sx.pylons[0].pos + away * 1.5)
	check(absf(s.terrain.ground.regen_mult(s.player) - X.STEEL_REGEN) < 0.001, "Aço perto: 1,2x")
	_put(s.enemy, sx.pylons[0].pos + away * 1.5)
	check(s.terrain.ground.regen_mult(s.enemy) == 1.0, "Normal perto: 1x")
	sx.tick(0.1)
	check(_events(s, "terrain_pylon_steel") == 1, "telemetria pylon_steel")
	s.free()
	a.abilities.weather = ""
	a.free()


func _pylon_ai() -> void:
	var a := _arena(
		[Mon.create("pikachu", 50)], [Mon.create("rattata", 50)], 9, {"scenario": "pedreira"}
	)
	var t: BattleTerrain = a.terrain
	var ex: BattleGroundExtras = t.ground.extras
	_one_pylon(ex)
	var py: Dictionary = ex.pylons[0]
	var p: BattleFighter = a.player
	var r: BattleFighter = a.enemy
	p.moves = ["thunderbolt", "quick_attack"]
	var away: Vector3 = (Vector3.ZERO - py.pos).normalized()
	_put(r, py.pos + away * 2.0)
	_put(p, py.pos + away * 7.0)
	p.opponent = r
	r.opponent = p
	var avail := ["thunderbolt", "quick_attack"]
	check(ex.ai_filter(p.ai, avail) == avail, "sem chuva não filtra")
	a.abilities.weather = "rain"
	check(
		ex.ai_filter(p.ai, avail) == ["quick_attack"], "na chuva Elétrico não mira perto do pilar"
	)
	check(_events(a, "terrain_ai_pylon_avoid") == 1, "telemetria ai_pylon_avoid")
	check(ex.ai_filter(p.ai, ["thunderbolt"]) == ["thunderbolt"], "só Elétrico: usa assim mesmo")
	# Rattata (sem energia) se esconde no anel do pilar, do lado oposto ao Pikachu.
	_put(r, py.pos + away * 5.0 + Vector3(-away.z, 0, away.x) * 2.0)
	r.ai.intent = ""
	r.ai.recover_t = 0.0
	var w: Vector3 = BattleGround.steer_ai(r.ai, 5.0)
	check(w != Vector3.INF and r.ai.tag == "pylon_hide", "IA se esconde no pilar contra Elétrico")
	for i in 240:
		var mv: Vector3 = BattleGround.steer_ai(r.ai, 5.0)
		if mv == Vector3.INF:
			break
		r.position += mv * 3.0 * DT
	var dd: float = (r.position - py.pos).length()
	check(dd > X.ZAP_R and dd < X.ATTRACT, "fica no anel do pilar (%.2f m)" % dd)
	check(_events(a, "terrain_ai_pylon_hide") >= 1, "telemetria ai_pylon_hide")
	ex._hide[r.get_instance_id()] = X.HIDE_MAX + 0.1
	check(BattleGround.steer_ai(r.ai, 5.0) == Vector3.INF, "no máx. HIDE_MAX s")
	check(ex._hide[r.get_instance_id()] < 0.0, "depois de HIDE_MAX espera")
	# Elétrico não se esconde.
	r.opponent = p
	p.ai.intent = ""
	check(ex.steer_ai(p.ai, 5.0) == Vector3.INF, "Elétrico não se esconde")
	a.abilities.weather = ""
	a.free()


func _web() -> void:
	var a := _arena(
		[Mon.create("caterpie", 50)], [Mon.create("rattata", 50)], 13, {"scenario": "pedreira"}
	)
	var t: BattleTerrain = a.terrain
	var ex: BattleGroundExtras = t.ground.extras
	var c: BattleFighter = a.player
	var r: BattleFighter = a.enemy
	var spot := _open_spot(a, 2.0)
	_put(r, spot + Vector3(3, 0, 0))
	_put(c, spot + Vector3(-4, 0, 0))
	ex.on_move_landed(c, Dex.move("string_shot"), spot, 0.5)
	check(ex.webs.size() == 1 and _events(a, "terrain_web") == 1, "String Shot deixa teia")
	_put(r, spot)
	ex.tick(0.05)
	check(r.root_t >= X.WEB_ROOT - 0.06, "quem entra fica preso (%.2f)" % r.root_t)
	check(_events(a, "terrain_web_stick") == 1, "telemetria web_stick")
	_put(r, spot + Vector3(3, 0, 0))
	ex.tick(0.05)
	_put(r, spot)
	ex.tick(0.05)
	check(r.root_t <= 0.0, "uma vez por teia")
	_put(c, spot)
	ex.tick(0.05)
	check(c.root_t <= 0.0, "Inseto não fica preso")
	# IA contorna a teia.
	var fresh := _arena(
		[Mon.create("rattata", 50)], [Mon.create("pikachu", 50)], 13, {"scenario": "pedreira"}
	)
	var fx: BattleGroundExtras = fresh.terrain.ground.extras
	var s2 := _open_spot(fresh, 2.0)
	fx.on_move_landed(fresh.enemy, Dex.move("string_shot"), s2, 0.5)
	_put(fresh.player, s2 + Vector3(-2.0, 0, 0.1))
	var w: Vector3 = fx.steer(fresh.player, Vector3.RIGHT)
	check(absf(w.normalized().z) > 0.2, "IA contorna a teia (%s)" % w)
	fresh.free()
	# Fogo limpa a teia; teia nova vence a mais velha.
	ex.on_move_landed(r, Dex.move("ember"), spot, 0.3)
	check(ex.webs.is_empty() and _events(a, "terrain_web_burn") == 1, "Fogo queima a teia")
	for i in X.WEB_MAX + 2:
		ex.on_move_landed(c, Dex.move("electroweb"), _open_spot(a, 1.0, i * 3), 0.5)
	check(ex.webs.size() == X.WEB_MAX, "no máx. %d teias" % X.WEB_MAX)
	_tick(a, X.WEB_SECS + 0.2)
	check(ex.webs.is_empty(), "a teia some")
	a.free()


func _vine() -> void:
	var a := _arena(
		[Mon.create("bulbasaur", 50)], [Mon.create("rattata", 50)], 15, {"scenario": "pedreira"}
	)
	var ex: BattleGroundExtras = a.terrain.ground.extras
	var b: BattleFighter = a.player
	var r: BattleFighter = a.enemy
	var spot := _open_spot(a, 2.0)
	_put(r, spot)
	_put(b, spot + Vector3(-3, 0, 0))
	var held := 0
	for i in 40:
		r.root_t = 0.0
		ex._vine_cd.clear()
		ex.on_move_landed(b, Dex.move("vine_whip"), spot, 0.8)
		if r.root_t > 0.0:
			held += 1
	check(held >= 6 and held <= 24, "cipó prende às vezes (%d/40)" % held)
	check(_events(a, "terrain_vine") == held, "telemetria vine")
	r.root_t = 0.0
	ex._vine_cd.clear()
	ex._rng.seed = 1
	var tries := 0
	while r.root_t <= 0.0 and tries < 50:
		ex._vine_cd.clear()
		ex.on_move_landed(b, Dex.move("leech_seed"), spot, 0.3)
		tries += 1
	check(absf(r.root_t - X.VINE_ROOT) < 0.01, "preso VINE_ROOT s")
	ex.on_move_landed(b, Dex.move("vine_whip"), spot, 0.8)
	check(_events(a, "terrain_vine") == held + 1, "o mesmo alvo espera VINE_CD")
	ex.on_move_landed(b, Dex.move("ember"), spot, 0.3)
	check(r.root_t <= 0.0 and _events(a, "terrain_vine_burn") == 1, "Fogo solta o cipó")
	ex.on_move_landed(b, Dex.move("tackle"), spot, 0.8)
	check(_events(a, "terrain_vine") == held + 1, "golpe sem cipó não prende")
	a.free()


func _wind() -> void:
	var a := _arena(
		[Mon.create("pidgey", 50)], [Mon.create("caterpie", 50)], 17, {"scenario": "campo"}
	)
	var t: BattleTerrain = a.terrain
	var ex: BattleGroundExtras = t.ground.extras
	var pg: BattleFighter = a.player
	var c: BattleFighter = a.enemy
	var spot := _open_spot(a, 1.0)
	_put(pg, spot)
	ex.on_move_used(pg, Dex.move("gust"), Vector3.RIGHT)
	check(ex.winds.size() == 1 and _events(a, "terrain_wind") == 1, "Gust faz rajada")
	_put(c, spot + Vector3(2.0, 0, 0))
	var x0 := c.position.x
	for i in 10:
		ex._wind_on(c, 0.1)
	var moved := c.position.x - x0
	check(moved > 0.5 and moved < 1.0, "leve vai com o vento (%.2f m em 1 s)" % moved)
	check(_events(a, "terrain_wind_push") == 1, "telemetria wind_push (uma vez)")
	var x1 := pg.position.x
	ex._wind_on(pg, 0.5)
	check(pg.position.x == x1, "quem soprou não vai")
	var o := _arena([Mon.create("onix", 50)], [Mon.create("pidgey", 50)], 17, {"scenario": "campo"})
	var ox: BattleGroundExtras = o.terrain.ground.extras
	_put(o.enemy, spot)
	ox.on_move_used(o.enemy, Dex.move("gust"), Vector3.RIGHT)
	_put(o.player, spot + Vector3(2, 0, 0))
	var ox0: float = o.player.position.x
	ox._wind_on(o.player, 1.0)
	check(o.player.position.x == ox0, "pesado não vai")
	o.free()
	# Tiro leve atravessando a rajada desvia um pouco; pedra não.
	var pr := BattleProjectile.new()
	pr.user = c
	pr.mv = Dex.move("ember")
	pr.position = spot + Vector3(3, 0.4, -2)
	pr.vel = Vector3(0, 0, 14)
	for i in 20:
		pr.position += pr.vel * DT
		ex.shot_step(pr, DT)
	check(pr.vel.x > 0.3 and pr.vel.x < 3.0, "tiro leve desvia (%.2f m/s de lado)" % pr.vel.x)
	check(_events(a, "terrain_wind_deflect") == 1, "telemetria wind_deflect")
	pr.mv = Dex.move("rock_throw")
	pr.lob = 1.2
	pr.vel = Vector3(0, 0, 14)
	pr.position = spot + Vector3(3, 0.4, -2)
	for i in 20:
		pr.position += pr.vel * DT
		ex.shot_step(pr, DT)
	check(pr.vel.x == 0.0, "pedra não desvia")
	pr.free()
	# Pó no vento vai para frente.
	var at := spot + Vector3(2, 0, 0)
	var to := ex.wind_area(Dex.move("spore"), at)
	check(absf((to - at).x - X.WIND_SPORE) < 0.01, "Spore vai com o vento")
	check(ex.wind_area(Dex.move("thunder"), at) == at, "outra área não")
	# Fogo na grama a favor do vento.
	var g1 := spot + Vector3(1.5, 0, 0)
	var g2 := g1 + Vector3(3.0, 0, 0)
	t.grass.clear()
	t._add_grass(g1, 1.0)
	t._add_grass(g2, 1.0)
	var target: Dictionary = t.grass[1]
	t.ignite(t.grass[0], c)
	check(_events(a, "terrain_wind_fire") == 1, "vento leva o fogo")
	for e in a._events.duplicate():
		e.cb.call()  # o fogo pula 0,6 s depois (a arena de teste ainda está na abertura)
	check(not t.grass.has(target), "a moita a favor do vento queima")
	_tick(a, X.WIND_SECS + 0.2)
	check(ex.winds.is_empty(), "a rajada passa")
	a.free()


func _rocks() -> void:
	var a := _arena(
		[Mon.create("onix", 50)], [Mon.create("rattata", 50)], 19, {"scenario": "campo"}
	)
	var t: BattleTerrain = a.terrain
	var ex: BattleGroundExtras = t.ground.extras
	var o: BattleFighter = a.player
	var r: BattleFighter = a.enemy
	var spot := _open_spot(a, 2.0)
	check(spot != Vector3.INF, "ponto livre")
	_put(r, spot)
	_put(o, spot + Vector3(-6, 0, 0))
	ex.on_move_landed(o, Dex.move("rock_slide"), spot, 2.4)
	check(ex.rocks.size() == 2, "Rock Slide deixa 2 pedrinhas (%d)" % ex.rocks.size())
	check(_events(a, "terrain_rock_cover") == 2, "telemetria rock_cover")
	for rk in ex.rocks:
		check((rk.pos - r.position).length() >= X.ROCK_CLEAR, "pedrinha longe de quem está lá")
	var rk0: Dictionary = ex.rocks[0]
	check(t.blocks_shot(rk0.pos + Vector3(0, 0.3, 0)), "pedrinha para tiro baixo")
	check(not t.blocks_shot(rk0.pos + Vector3(0, 1.0, 0)), "não para tiro alto")
	var used: Array = [spot, o.position]
	var spots: Array = []
	for i in 4:
		var q := _open_spot(a, 1.0, 0, used)
		used.append(q)
		spots.append(q)
	check(not Vector3.INF in spots, "pontos livres %s" % [spots])
	ex.on_move_landed(o, Dex.move("rock_tomb"), spots[0], 1.8)
	check(ex.rocks.size() == 3, "Rock Tomb deixa 1")
	ex.on_move_landed(o, Dex.move("stone_edge"), spots[1], 2.0)
	ex.on_move_landed(o, Dex.move("stone_edge"), spots[2], 2.0)
	check(ex.rocks.size() == X.ROCK_MAX, "no máx. %d" % X.ROCK_MAX)
	ex.on_move_landed(o, Dex.move("rock_throw"), spots[3], 0.3)
	check(_events(a, "terrain_rock_cover") >= 6, "Stone Edge deixa 2")
	_tick(a, X.ROCK_SECS + 0.2)
	check(ex.rocks.is_empty(), "somem em ROCK_SECS s")
	o.opponent = r
	ex.on_move_used(o, Dex.move("stealth_rock"), Vector3.RIGHT)
	check(ex.rocks.size() >= 1, "Stealth Rock deixa pedrinha perto do alvo")
	for rk in ex.rocks:
		check((rk.pos - r.position).length() < 3.5, "perto do alvo")
	a.free()


func _weather() -> void:
	var a := _arena(
		[Mon.create("sandshrew", 50)], [Mon.create("rattata", 50)], 23, {"scenario": "campo"}
	)
	var t: BattleTerrain = a.terrain
	var g: BattleGround = t.ground
	var ex: BattleGroundExtras = g.extras
	var u: BattleFighter = a.player
	var r: BattleFighter = a.enemy
	_put(r, Vector3(-9, 0, -5))
	_put(u, Vector3(9, 0, 5))
	# Chuva enche a fenda.
	var spot := _open_spot(a, 2.0)
	u.facing = Vector3(1, 0, 0)
	g.on_move_landed(u, Dex.move("earthquake"), spot, 4.5)
	a.abilities.weather = "rain"
	_tick(a, X.RAIN_FILL + 0.3)
	var pd: Array = g.marks.filter(func(m): return m.kind == "puddle")
	check(pd.size() == 1 and _events(a, "terrain_rain_fill") == 1, "chuva enche a fenda")
	_tick(a, 1.0)
	check(_events(a, "terrain_rain_fill") == 1, "uma vez por fenda")
	# Cratera do BattleField.
	var s2 := _open_spot(a, 2.0, 5)
	a.field._add_mark("crater", s2, 1.0, 0)
	_tick(a, X.RAIN_FILL + 0.3)
	check(_events(a, "terrain_rain_fill") == 2, "chuva enche a cratera")
	# Granizo congela a poça e junta neve.
	a.abilities.weather = "hail"
	_tick(a, 0.2)
	check(g.marks.filter(func(m): return m.kind == "puddle").is_empty(), "granizo congela a poça")
	check(_events(a, "terrain_puddle_freeze") >= 1, "telemetria puddle_freeze")
	_tick(a, X.SNOW_EVERY + 0.2)
	check(ex.snow.size() == 1 and _events(a, "terrain_snow_mound") == 1, "montinho de neve")
	var sn: Dictionary = ex.snow[0]
	check(t.blocks_shot(sn.pos + Vector3(0, 0.3, 0)), "neve é cobertura baixa")
	ex.on_move_landed(r, Dex.move("ember"), sn.pos, 0.3)
	check(ex.snow.is_empty() and _events(a, "terrain_snow_melt") == 1, "Fogo derrete a neve")
	_tick(a, X.SNOW_EVERY * 5)
	check(ex.snow.size() <= X.SNOW_MAX, "no máx. %d montinhos" % X.SNOW_MAX)
	# Areia cobre a grama alta e as pedrinhas.
	a.abilities.weather = ""
	_tick(a, 0.2)
	var gr: Dictionary = t.grass[0]
	_put(r, gr.pos)
	check(t.in_grass(r), "na grama sem areia")
	ex.on_move_landed(u, Dex.move("rock_tomb"), _open_spot(a, 2.0, 2), 1.8)
	var rk: Dictionary = ex.rocks[-1]
	a.abilities.weather = "sand"
	_tick(a, 0.2)
	check(not t.in_grass(r) and _events(a, "terrain_sand_bury") == 1, "areia cobre a grama")
	check(not t.blocks_shot(rk.pos + Vector3(0, 0.3, 0)), "areia cobre a pedrinha")
	a.abilities.weather = ""
	_tick(a, 0.2)
	check(t.in_grass(r) and t.blocks_shot(rk.pos + Vector3(0, 0.3, 0)), "sem areia volta")
	# Sol adianta a fruta do arbusto.
	var bushes: Array = t.props.of_kind("bush")
	check(not bushes.is_empty(), "campo com arbusto")
	if not bushes.is_empty():
		var b: Dictionary = bushes[0]
		for berry in t.props.berries.duplicate():
			t.props.berries.erase(berry)
		b.grow_t = 100.0
		b.burnt_t = 0.0
		a.abilities.weather = "sun"
		_tick(a, 1.0)
		check(absf(float(b.grow_t) - (100.0 - 1.0 - X.SUN_BERRY)) < 0.05, "sol: fruta 1,5x")
		a.abilities.weather = ""
	a.free()


func _vgc() -> void:
	for sc in ["lagoa", "pedreira", "misto"]:
		var a := _arena(
			[Mon.create("pikachu", 50)],
			[Mon.create("rattata", 50)],
			3,
			{"scenario": sc, "battle_mode": "vgc"}
		)
		var ex: BattleGroundExtras = a.terrain.ground.extras
		check(ex.bridges.is_empty() and ex.pylons.is_empty(), "VGC: sem tronco nem pilar (%s)" % sc)
		ex.on_move_landed(a.player, Dex.move("rock_slide"), Vector3.ZERO, 2.4)
		ex.on_move_used(a.player, Dex.move("gust"), Vector3.RIGHT)
		check(ex.rocks.is_empty() and ex.winds.is_empty(), "VGC: sem pedrinha nem vento")
		a.free()

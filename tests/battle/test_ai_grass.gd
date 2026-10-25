extends SceneTree
## Rodar: godot --headless --fixed-fps 60 --path . --script res://tests/battle/test_ai_grass.gd
## IA do modo de energia na grama alta (BattleTerrainAI) e na mira de área (BattleAI.area_lead):
## emboscada vai para a moita perto quando convém e espera escondida; sai depois de HIDE_MAX s e não
## volta na recarga; não se esconde com o parceiro sendo atacado (2x2) e larga a moita quando ele passa
## a ser; não vai para moita longe nem além do alvo; sai atacando com o alvo chegando (contato); golpe de
## área mira à frente de quem anda (dentro da quadra e do alcance); memória do estilo do inimigo.

const ARENA := "res://battle/battle_arena.tscn"
const Cfg := preload("res://ui/training/training_config.gd")
const DT := 1.0 / 60.0

var _fails := 0
var _count := 0
var _ran := false


func _process(_d: float) -> bool:
	if _ran:
		return true
	_ran = true
	_hide_and_leave()
	_far_grass()
	_strike()
	_hold()
	_ally_focused()
	_lead()
	_memory()
	print("ai_grass: %d checks, %d falhas" % [_count, _fails])
	quit(1 if _fails else 0)
	return true


func check(ok: bool, what: String) -> void:
	_count += 1
	if not ok:
		_fails += 1
		print("FALHOU: ", what)


func _arena(party: Array, enemies: Array, size := 1) -> Node:
	var a: Node = load(ARENA).instantiate()
	a.manual = true
	root.add_child(a)
	var o := Cfg.arena_opts(Cfg.default_config(), Vector3.ZERO)
	(
		o
		. merge(
			{
				"speed": 1.0,
				"seed": 31,
				"battle_size": size,
				"battle_mode": "energy",
				"scenario": "campo",
				"autoplay": true,
			},
			true
		)
	)
	a.start(party, enemies, o)
	var t := 0.0
	while a.state == "intro" and t < 10.0:
		a.step(DT)
		t += DT
	a.tut_hold_foe = true  # só o lutador do teste anda (à mão, em _drive)
	# Uma moita só, num ponto conhecido; nada de relevo nem caixas no caminho.
	a.terrain.grass.clear()
	a.terrain.obstacles.clear()
	a.field.objects.clear()
	a.terrain._add_grass(Vector3(0, 0, 0), 1.2)
	return a


func _side(a: Node, s: int) -> Array:
	return a.fighters.filter(func(f): return f.side == s and f.on_field)


## Prepara quem se esconde: plano emboscada fixo, golpe pretendido de contato curto ou não.
func _ambusher(f: BattleFighter, contact: bool) -> void:
	f.ai.plan = BattlePlan.AMBUSH
	f.ai.plan_t = 999.0
	f.ai.idle_t = 0.0
	f.ai.recover_t = 0.0
	f.ai.think = 999.0
	for id in f.moves:
		var mv := Dex.move(String(id))
		var short: bool = f.ai.move_reach(String(id)) < 4.0  # contato curto (não o chicote)
		if float(mv.get("power", 0)) > 0.0 and (f.ai.is_contact(String(id)) and short) == contact:
			f.ai.intent = String(id)
			break


## Um passo do lutador do teste como a arena faz (IA, chão do cenário, relógios).
func _drive(a: Node, f: BattleFighter) -> Vector3:
	f.tick(DT)
	var w: Vector3 = a.terrain.steer(f, f.ai.step(DT))
	f.drive(DT, w, f.walk_speed())
	a.terrain.settle(f, DT)
	return w


func _put(f: BattleFighter, at: Vector3) -> void:
	f.position = Vector3(at.x, 0.0, at.z)
	f.velocity = Vector3.ZERO


## Bulbasaur (Grama) sem energia, alvo longe: vai à moita perto, fica escondido, sai no limite, não
## volta durante a recarga.
func _hide_and_leave() -> void:
	var a := _arena([Mon.create("bulbasaur", 50)], [Mon.create("rattata", 50)])
	var h: BattleFighter = a.player
	var foe: BattleFighter = a.enemy
	_put(h, Vector3(-3.0, 0, 0))
	_put(foe, Vector3(9.5, 0, 2.0))
	_ambusher(h, false)
	check(h.ai.intent != "", "Bulbasaur tem golpe de longe (%s)" % [h.moves])
	h.pp_max = 0.0
	var hid := 0.0
	var first_in := -1.0
	var left_at := -1.0
	var t := 0.0
	while t < 12.0:
		_drive(a, h)
		h.ai.think = 999.0
		h.ai.idle_t = 0.0  # o teste olha só o limite da moita (não o de luta parada)
		t += DT
		if h.ai.tag == "ambush_hide":
			hid += DT
			if first_in < 0.0:
				first_in = t
		if first_in >= 0.0 and left_at < 0.0 and h.ai.grass_spot.is_empty():
			left_at = t
		if left_at >= 0.0 and t > left_at + 1.0:
			break
	check(
		first_in >= 0.0 and first_in < 2.5, "chega na moita perto e se esconde (%.2f s)" % first_in
	)
	check(
		left_at >= 0.0 and hid <= BattleTerrainAI.HIDE_MAX + 0.2,
		"sai da moita no limite (%.2f s escondido)" % hid
	)
	check(h.ai.grass_cd > 0.0, "recarga da moita depois de sair")
	# Durante a recarga não volta para a moita, mesmo sem energia.
	h.pp_max = 0.0
	var back := false
	for i in 120:
		_drive(a, h)
		h.ai.idle_t = 0.0
		if h.ai.tag in ["grass_go", "ambush_hide"]:
			back = true
	check(not back, "não volta para a moita na recarga")
	a.free()


## Moita além do alvo ou longe demais: não vai; com o alvo colado também não.
func _far_grass() -> void:
	var a := _arena([Mon.create("bulbasaur", 50)], [Mon.create("rattata", 50)])
	var h: BattleFighter = a.player
	var foe: BattleFighter = a.enemy
	_ambusher(h, false)
	h.pp_max = 0.0
	_put(h, Vector3(-9.0, 0, 0))
	_put(foe, Vector3(-4.0, 0, 3.0))
	BattleTerrainAI.steer(h.ai, h.flat_to(foe).length())
	check(h.ai.grass_spot.is_empty(), "moita a 9 m (além do alvo): não vai")
	_put(h, Vector3(-3.0, 0, 0))
	_put(foe, Vector3(-4.5, 0, 0))
	BattleTerrainAI.steer(h.ai, h.flat_to(foe).length())
	check(h.ai.grass_spot.is_empty(), "alvo colado: não vai se esconder")
	# Inimigo com golpe de Fogo: nada de moita.
	a.free()
	var b := _arena([Mon.create("bulbasaur", 50)], [Mon.create("charmander", 50)])
	var h2: BattleFighter = b.player
	_ambusher(h2, false)
	h2.pp_max = 0.0
	_put(h2, Vector3(-3.0, 0, 0))
	_put(b.enemy, Vector3(9.5, 0, 2.0))
	BattleTerrainAI.steer(h2.ai, 12.0)
	check(h2.ai.grass_spot.is_empty(), "inimigo de Fogo: não se esconde na moita")
	b.free()


## Golpe de contato pronto: espera na moita e sai correndo atacando quando o alvo chega perto.
func _strike() -> void:
	var a := _arena([Mon.create("bulbasaur", 50)], [Mon.create("rattata", 50)])
	var h: BattleFighter = a.player
	var foe: BattleFighter = a.enemy
	h.moves = ["tackle", "vine_whip"]
	_ambusher(h, true)
	check(h.ai.is_contact(h.ai.intent), "Bulbasaur tem golpe de contato (%s)" % h.ai.intent)
	h.pp_max = 100.0
	_put(h, Vector3(-2.0, 0, 0))
	_put(foe, Vector3(6.0, 0, 0))  # a moita fica a até alcance + USEFUL_GAP (ou USEFUL_MIN) do alvo
	var hid := false
	for i in 120:
		_drive(a, h)
		h.ai.think = 999.0
		if h.ai.tag == "ambush_hide":
			hid = true
	check(hid, "espera escondido com o alvo longe")
	# O alvo passa perto: sai atacando.
	_put(foe, Vector3(3.5, 0, 0.5))
	var strike := false
	for i in 30:
		var w := _drive(a, h)
		if h.ai.tag == "ambush_strike" and w.dot(h.flat_to(foe).normalized()) > 0.7:
			strike = true
			break
	check(strike, "sai da moita atacando quando o alvo chega (tag %s)" % h.ai.tag)
	a.free()


## Golpe de longe pronto durante a emboscada: segura indo e logo que chega; solta com o alvo de costas,
## a barra cheia ou depois de HOLD_MIN s escondido.
func _hold() -> void:
	var a := _arena([Mon.create("bulbasaur", 50)], [Mon.create("rattata", 50)])
	var h: BattleFighter = a.player
	var foe: BattleFighter = a.enemy
	_ambusher(h, false)
	_put(h, Vector3(0.0, 0, 0))
	_put(foe, Vector3(6.0, 0, 0))
	foe.facing = Vector3(-1, 0, 0)  # olhando para a moita
	foe.pp_max = 100.0
	h.pp_max = 60.0
	h.ai.grass_spot = a.terrain.grass[0]
	h.ai.grass_t = 0.0
	h.ai.grass_go_t = 0.5
	check(BattleTerrainAI.hold_fire(h.ai, 6.0), "indo para a moita: segura o golpe")
	h.ai.grass_t = 0.5
	check(BattleTerrainAI.hold_fire(h.ai, 6.0), "acabou de chegar, alvo de frente: segura")
	foe.facing = Vector3(1, 0, 0)
	h.ai.grass_t = BattleTerrainAI.HOLD_OPEN + 0.1
	check(not BattleTerrainAI.hold_fire(h.ai, 6.0), "alvo de costas: solta")
	foe.facing = Vector3(-1, 0, 0)
	h.ai.grass_t = BattleTerrainAI.HOLD_MIN + 0.1
	check(not BattleTerrainAI.hold_fire(h.ai, 6.0), "escondido há HOLD_MIN s: solta")
	h.ai.grass_t = 0.5
	h.pp_max = 100.0
	check(not BattleTerrainAI.hold_fire(h.ai, 6.0), "barra cheia: solta")
	a.free()


## 2x2: com o parceiro sendo atacado não se esconde; se esconder e o parceiro virar alvo, larga a moita.
func _ally_focused() -> void:
	var a := _arena(
		[Mon.create("bulbasaur", 50), Mon.create("pikachu", 50)],
		[Mon.create("rattata", 50), Mon.create("geodude", 50)],
		2
	)
	var mine := _side(a, 0)
	var foes := _side(a, 1)
	check(mine.size() == 2 and foes.size() == 2, "2x2 em campo")
	var h: BattleFighter = mine[0] if "grass" in mine[0].types else mine[1]
	var p: BattleFighter = mine[1] if h == mine[0] else mine[0]
	_ambusher(h, false)
	h.pp_max = 0.0
	h.opponent = foes[0]
	_put(h, Vector3(-3.0, 0, 0))
	_put(p, Vector3(4.0, 0, -4.0))
	_put(foes[0], Vector3(6.0, 0, -3.0))
	_put(foes[1], Vector3(5.5, 0, -5.0))
	for g in foes:
		g.opponent = p
	p.ai.hurt_t = 99.0
	check(BattleTerrainAI.ally_focused(h.ai), "dois inimigos em cima do parceiro: focado")
	BattleTerrainAI.steer(h.ai, h.flat_to(foes[0]).length())
	check(h.ai.grass_spot.is_empty(), "parceiro focado: não vai para a moita")
	# Um inimigo sai do parceiro: vai se esconder.
	foes[1].opponent = h
	_put(foes[1], Vector3(9.0, 0, 4.0))
	BattleTerrainAI.steer(h.ai, h.flat_to(foes[0]).length())
	check(not h.ai.grass_spot.is_empty(), "parceiro livre: vai para a moita")
	# O parceiro toma golpe: larga a moita na hora.
	p.ai.hurt_t = 0.2
	BattleTerrainAI.steer(h.ai, h.flat_to(foes[0]).length())
	check(h.ai.grass_spot.is_empty() and h.ai.grass_cd > 0.0, "parceiro atacado: sai da moita")
	a.free()


## Golpe de área mira na posição prevista de quem anda (dentro da quadra e do alcance).
func _lead() -> void:
	var a := _arena([Mon.create("geodude", 50)], [Mon.create("rattata", 50)])
	var u: BattleFighter = a.player
	var t: BattleFighter = a.enemy
	var mv := Dex.move("rock_slide")
	_put(u, Vector3(-4.0, 0, 0))
	_put(t, Vector3(2.0, 0, -2.0))
	u.opponent = t
	var dir := u.flat_to(t).normalized()
	var still: Vector3 = a.moves._area_point(u, mv, dir, null)
	check((still - t.pos2(t.position)).length() < 0.05, "alvo parado: mira nele")
	t.velocity = Vector3(0, 0, 4.0)
	var at: Vector3 = a.moves._area_point(u, mv, dir, null)
	var later: Vector3 = t.pos2(t.position) + Vector3(0, 0, 4.0) * float(mv.windup)
	check(at.z > t.position.z + 0.8, "mira à frente de quem anda (%s)" % at)
	check(
		(at - later).length() < (t.pos2(t.position) - later).length(),
		"mais perto de onde o alvo vai estar do que de onde está"
	)
	# Andando para a parede: a mira não sai da quadra.
	var r: Rect2 = a.rect
	_put(t, Vector3(2.0, 0, r.end.y - 0.3))
	t.velocity = Vector3(0, 0, 6.0)
	var wall: Vector3 = a.moves._area_point(u, mv, u.flat_to(t).normalized(), null)
	check(wall.z <= r.end.y + 0.01, "mira dentro da quadra (%.2f)" % wall.z)
	# Longe: a mira não passa do alcance do golpe.
	_put(t, Vector3(-4.0 + float(mv.range) - 0.2, 0, 0))
	t.velocity = Vector3(8.0, 0, 0)
	var far: Vector3 = a.moves._area_point(u, mv, Vector3(1, 0, 0), null)
	check(
		(far - u.pos2(u.position)).length() <= float(mv.range) + 0.01,
		"mira dentro do alcance (%.2f m)" % (far - u.pos2(u.position)).length()
	)
	a.free()


## Memória: o estilo do inimigo sai dos golpes vistos e mexe na faixa e no plano.
func _memory() -> void:
	var a := _arena([Mon.create("pikachu", 50)], [Mon.create("rattata", 50)])
	var u: BattleFighter = a.player
	var t: BattleFighter = a.enemy
	u.opponent = t
	BattlePlan.observe(u.ai, DT)
	check(BattlePlan.foe_style(u.ai, t) == "", "sem golpes vistos: estilo vazio")
	for i in 4:
		t.cast_move = Dex.move("quick_attack")
		t.cast_n += 1
		BattlePlan.observe(u.ai, DT)
	check(BattlePlan.foe_style(u.ai, t) == "dasher", "quem investe vira dasher")
	u.ai.plan = BattlePlan.ATTRITION
	check(BattlePlan.memory_band(u.ai) > 1.0, "contra dasher fica mais longe")
	var w_d: Dictionary = BattlePlan.weights(u.ai)
	u.ai.foe_mem.clear()
	BattlePlan.observe(u.ai, DT)
	for i in 4:
		t.cast_move = Dex.move("thunderbolt")
		t.cast_n += 1
		BattlePlan.observe(u.ai, DT)
	check(BattlePlan.foe_style(u.ai, t) == "ranged", "quem só atira vira ranged")
	check(BattlePlan.memory_band(u.ai) < 1.0, "contra ranged encosta")
	var w_r: Dictionary = BattlePlan.weights(u.ai)
	check(
		float(w_r[BattlePlan.PRESS]) > float(w_d[BattlePlan.PRESS]),
		"contra ranged a pressão pesa mais que contra dasher"
	)
	# Velocidade lembrada: média que vai para a de agora.
	t.velocity = Vector3(3.0, 0, 0)
	for i in 60:
		BattlePlan.observe(u.ai, DT)
	check(
		BattlePlan.foe_velocity(u.ai, t).distance_to(Vector3(3, 0, 0)) < 0.2,
		"velocidade lembrada acompanha o alvo"
	)
	a.free()

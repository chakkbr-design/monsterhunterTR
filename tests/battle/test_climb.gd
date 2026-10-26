extends SceneTree
## Rodar: godot --headless --fixed-fps 60 --path . --script res://tests/battle/test_climb.gd
## Obstáculos do modo de energia (BattleClimb): ninguém atravessa caixa nem sobe morro andando (nem o
## voo de cruzeiro nem o pulinho de esquiva), o salto custa JUMP_COST, tem recarga JUMP_CD e sobe um
## nível por vez (também por cima da caixa), o voo custa FLY_COST, recarga FLY_CD e chega em qualquer
## altura, a IA contorna/salta com o caminho tapado, lutas com relevo acabam e o VGC não muda.

const ARENA := "res://battle/battle_arena.tscn"
const Cfg := preload("res://ui/training/training_config.gd")
const C := preload("res://battle/battle_climb.gd")
const DT := 1.0 / 60.0
const FIGHT_LIMIT := 240.0

var _fails := 0
var _count := 0
var _ran := false


func _process(_d: float) -> bool:
	if _ran:
		return true
	_ran = true
	_walls()
	_jump()
	_fly()
	_ai_route()
	_vgc()
	_fights()
	print("climb: %d checks, %d falhas" % [_count, _fails])
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
	o.merge({"speed": 1.0, "seed": seed, "battle_size": 1, "scenario": "campo"}, true)
	o.merge(extra, true)
	a.start(party, enemies, o)
	return a


## Quadra limpa (sem cenário sorteado) com um morro de 1 nível em (0, 0, 0), um pico de 2 níveis em
## (8, 0, 0) e uma caixa em (-6, 0, 5).
func _court(a: Node) -> Dictionary:
	var t: BattleTerrain = a.terrain
	t.obstacles.clear()
	t.grass.clear()
	t.props.items.clear()
	t.ground.mud.clear()
	a.field.objects.clear()
	t._add("hill", Vector3.ZERO, 2.0, 1.0)
	t._add("peak", Vector3(8, 0, 0), 1.4, 1.7)
	a.field.objects.append(
		{"node": null, "pos": Vector3(-6, 0, 5), "hp": 2, "berry": false, "rock": false, "cd": 0.0}
	)
	t.on_obstacles_changed()
	return {"hill": t.obstacles[0], "peak": t.obstacles[1], "crate": Vector3(-6, 0, 5)}


func _place(f: BattleFighter, at: Vector3) -> void:
	f.end_motion()
	f.ground_y = f.arena.terrain.height_at(at)
	f.position = Vector3(at.x, f.ground_y + f.fly_h, at.z)
	f.velocity = Vector3.ZERO
	f.knock = Vector3.ZERO


## Um lutador sozinho, como no laço da arena: tempo, corpo, caixa e chão.
func _sim(a: Node, f: BattleFighter, want: Vector3, secs: float) -> float:
	var top := 0.0
	var t := 0.0
	while t < secs:
		f.tick(DT)
		f.drive(DT, want, f.walk_speed())
		f.position += a.field.push_out(f)
		a.terrain.settle(f, DT)
		top = maxf(top, f.position.y)
		t += DT
	return top


func _until_landed(a: Node, f: BattleFighter) -> float:
	var top := 0.0
	var n := 0
	while f.motion != "" and n < 600:
		top = maxf(top, _sim(a, f, Vector3.ZERO, DT))
		n += 1
	return top


func _walls() -> void:
	var a := _arena([Mon.create("rattata", 30)], [Mon.create("pidgey", 30)], 3)
	a.step(DT)
	var c := _court(a)
	var t: BattleTerrain = a.terrain
	check(t.climb.on, "modo de energia com relevo: BattleClimb ligado")
	var hill: Dictionary = c.hill
	var peak: Dictionary = c.peak
	check(C.tiers(hill) == 1, "morro de 1 m: 1 nível (%d)" % C.tiers(hill))
	check(C.tiers(peak) == 2, "pico de 1,7 m: 2 níveis (%d)" % C.tiers(peak))
	check(absf(t.height_at(Vector3(1.8, 0, 0)) - 1.0) < 0.01, "degrau: altura cheia até a beira")
	var r: BattleFighter = a.player
	# Andando contra o morro: para na beira, no chão.
	_place(r, Vector3(-4, 0, 0))
	_sim(a, r, Vector3.RIGHT, 3.0)
	check(r.position.x < -2.0 + 0.01, "não sobe o morro andando (x %.2f)" % r.position.x)
	check(r.ground_y < 0.05, "continua no chão (%.2f)" % r.ground_y)
	# Pulinho de esquiva também não sobe.
	_place(r, Vector3(-2.3, 0, 0))
	r.start_jump()
	_sim(a, r, Vector3.RIGHT, 1.0)
	check(r.ground_y < 0.05 and r.position.x < -1.95, "pulinho de esquiva não sobe o morro")
	# Contra a caixa: não atravessa.
	_place(r, Vector3(-8, 0, 5))
	_sim(a, r, Vector3.RIGHT, 3.0)
	var lim := -6.0 - BattleField.OBJ_R - BattleField.BODY_R + 0.05
	check(r.position.x < lim, "não atravessa a caixa (x %.2f)" % r.position.x)
	# Voador no voo de cruzeiro: nem caixa nem morro de graça.
	var p: BattleFighter = a.enemy
	p.fly_h = 1.3
	p.fly_target = 1.3
	_place(p, Vector3(-8, 0, 5))
	_sim(a, p, Vector3.RIGHT, 3.0)
	check(p.position.x < lim, "voo de cruzeiro não passa por cima da caixa (x %.2f)" % p.position.x)
	_place(p, Vector3(-4, 0, 0))
	_sim(a, p, Vector3.RIGHT, 3.0)
	check(p.position.x < -1.95, "voo de cruzeiro não passa por cima do morro")
	# Descer andando da beira é de graça.
	_place(r, Vector3(1.0, 0, 0))
	check(r.ground_y > 0.9, "no topo do morro")
	var en := r.pp_max
	_sim(a, r, Vector3.RIGHT, 2.0)
	check(r.position.x > 2.0 and r.ground_y < 0.05, "desce andando da beira")
	check(r.pp_max >= en, "descer não gasta energia")
	a.free()


func _jump() -> void:
	var a := _arena([Mon.create("rattata", 30)], [Mon.create("pidgey", 30)], 4)
	a.step(DT)
	var c := _court(a)
	var t: BattleTerrain = a.terrain
	var hill: Dictionary = c.hill
	var r: BattleFighter = a.player
	_place(r, Vector3(-2.3, 0, 0))
	r.pp_max = 50.0
	r.jump_cd = 0.0
	check(t.climb.jump(r, Vector3(-1.2, 0, 0)), "salta para o morro")
	check(absf(r.pp_max - (50.0 - C.JUMP_COST)) < 0.01, "salto custa JUMP_COST (%.1f)" % r.pp_max)
	check(absf(r.jump_cd - C.JUMP_CD) < 0.01, "recarga do salto JUMP_CD")
	check(r.motion == "leap", "o salto é um arco (motion leap)")
	var top := _until_landed(a, r)
	check(top > float(hill.h) + 0.3, "o arco passa acima do degrau (%.2f)" % top)
	check(absf(r.ground_y - float(hill.h)) < 0.05, "pousou no topo (%.2f)" % r.ground_y)
	# Recarga: não salta de novo antes dela.
	_place(r, Vector3(-2.3, 0, 0))
	check(not t.climb.jump(r, Vector3(-1.2, 0, 0)), "não salta durante a recarga")
	r.jump_cd = C.JUMP_CD
	_sim(a, r, Vector3.ZERO, C.JUMP_CD - 0.5)
	check(not t.climb.jump_ready(r), "ainda na recarga (%.2f s)" % r.jump_cd)
	_sim(a, r, Vector3.ZERO, 0.6)
	r.pp_max = C.JUMP_COST - 1.0
	check(not t.climb.jump(r, Vector3(-1.2, 0, 0)), "sem JUMP_COST de energia não salta")
	r.pp_max = 50.0
	check(t.climb.jump_ready(r), "depois da recarga, com energia, pode saltar")
	# Um nível por vez: do chão não chega ao topo do pico (2 níveis), só ao primeiro degrau.
	var peak: Dictionary = c.peak
	_place(r, Vector3(8 - 1.6, 0, 0))
	check(not t.climb.jump_ok(r, Vector3(8, 0, 0)), "do chão não salta dois níveis")
	check(t.climb.jump(r, Vector3(8 - 1.0, 0, 0)), "salta um nível no pico")
	_until_landed(a, r)
	var lv1 := C.tier_h(peak, 1)
	check(absf(r.ground_y - lv1) < 0.05, "no primeiro degrau (%.2f de %.2f)" % [r.ground_y, lv1])
	_sim(a, r, Vector3.RIGHT, 1.5)
	check(absf(r.ground_y - lv1) < 0.05, "andando não sobe o segundo degrau")
	check(r.position.x < 8.0 - C.ring(peak, 2) + 0.05, "para na beira do segundo degrau")
	r.jump_cd = 0.0
	check(t.climb.jump(r, Vector3(8, 0, 0)), "do primeiro degrau salta para o topo")
	_until_landed(a, r)
	check(absf(r.ground_y - float(peak.h)) < 0.05, "no topo do pico (%.2f)" % r.ground_y)
	# Por cima da caixa.
	_place(r, Vector3(-7.4, 0, 5))
	r.jump_cd = 0.0
	check(t.climb.jump(r, Vector3(-4.7, 0, 5)), "salta por cima da caixa")
	top = _until_landed(a, r)
	check(r.position.x > -5.0, "passou a caixa (x %.2f)" % r.position.x)
	check(top > C.CRATE_H, "o arco passa acima da caixa (%.2f)" % top)
	check(not t.climb.jump_ok(r, Vector3(-6, 0, 5)), "não pousa dentro da caixa")
	a.free()


func _fly() -> void:
	var a := _arena([Mon.create("rattata", 30)], [Mon.create("pidgey", 30)], 5)
	a.step(DT)
	var c := _court(a)
	var t: BattleTerrain = a.terrain
	var peak: Dictionary = c.peak
	var r: BattleFighter = a.player
	var p: BattleFighter = a.enemy
	check(not t.climb.can_fly(r), "Rattata não voa")
	check(t.climb.can_fly(p), "Pidgey voa")
	_place(r, Vector3(2, 0, 0))
	r.pp_max = 50.0
	check(not t.climb.fly(r, Vector3(8, 0, 0)), "quem não voa não decola")
	_place(p, Vector3(2, 0, 3))
	p.pp_max = 50.0
	p.fly_cd = 0.0
	check(t.climb.fly(p, Vector3(8, 0, 0)), "Pidgey voa até o topo do pico")
	check(absf(p.pp_max - (50.0 - C.FLY_COST)) < 0.01, "voo custa FLY_COST (%.1f)" % p.pp_max)
	check(absf(p.fly_cd - C.FLY_CD) < 0.01, "recarga do voo FLY_CD")
	var top := _until_landed(a, p)
	check(top > 2.8, "voa acima de árvore e coluna (%.2f)" % top)
	check(
		absf(p.ground_y - float(peak.h)) < 0.05,
		"pousa no topo, dois níveis acima (%.2f)" % p.ground_y
	)
	_place(p, Vector3(2, 0, 3))
	check(not t.climb.fly(p, Vector3(-6, 0, 0)), "não voa de novo durante a recarga")
	p.fly_cd = C.FLY_CD
	_sim(a, p, Vector3.ZERO, C.FLY_CD - 1.0)
	check(not t.climb.fly_ready(p), "ainda na recarga do voo")
	_sim(a, p, Vector3.ZERO, 1.1)
	p.pp_max = 50.0
	check(t.climb.fly_ready(p), "depois de FLY_CD pode voar de novo")
	check(not t.climb.fly_ok(p, Vector3(-6, 0, 5)), "não pousa dentro da caixa")
	a.free()


## A IA com o alvo atrás do morro: contorna ou salta (nunca empurra direto contra a beira).
func _ai_route() -> void:
	var a := _arena([Mon.create("rattata", 30)], [Mon.create("geodude", 30)], 6)
	a.step(DT)
	_court(a)
	var t: BattleTerrain = a.terrain
	var r: BattleFighter = a.player
	var g: BattleFighter = a.enemy
	_place(r, Vector3(-4, 0, 0))
	_place(g, Vector3(4, 0, 0))
	r.opponent = g
	r.controller = "ai"
	r.pp_max = 50.0
	r.jump_cd = 0.0
	var w := t.steer(r, Vector3.RIGHT)
	var nv: Dictionary = t.climb._nav.get(r.get_instance_id(), {})
	var over := false
	for q in nv.get("pts", []):
		over = over or bool(q[1])
	check(
		r.motion == "leap" or absf(w.z) > 0.2 or over,
		"alvo atrás do morro: contorna ou salta (%s, %s)" % [w, r.motion]
	)
	# Sem nada no caminho, a direção fica como veio.
	_place(r, Vector3(-4, 0, 6))
	_place(g, Vector3(4, 0, 6))
	var w2 := t.steer(r, Vector3.RIGHT)
	check(w2.is_equal_approx(Vector3.RIGHT), "caminho livre: direção sem mudança (%s)" % w2)
	# Andando pela IA chega do outro lado do morro (contornando ou por cima).
	_place(r, Vector3(-4, 0, 0))
	_place(g, Vector3(4, 0, 0))
	r.jump_cd = 0.0
	var tt := 0.0
	while tt < 12.0 and r.position.x < 2.5:
		t.tick(DT)
		var want := t.steer(r, (g.position - r.position).normalized())
		_sim(a, r, want, DT)
		tt += DT
	check(r.position.x >= 2.5, "a IA passa o morro (%.1f s, x %.2f)" % [tt, r.position.x])
	a.free()


## VGC: nada disso (a encosta, o pico só para escaladores e o voo de cruzeiro como antes).
func _vgc() -> void:
	var a := _arena(
		[Mon.create("rattata", 30)], [Mon.create("pidgey", 30)], 7, {"battle_mode": "vgc"}
	)
	a.step(DT)
	var t: BattleTerrain = a.terrain
	check(not t.climb.on, "VGC: BattleClimb desligado")
	var hill := {}
	for o in t.obstacles:
		check(C.tiers(o) == 0, "VGC: sem degraus (%s)" % o.kind)
		if o.kind == "hill":
			hill = o
	if not hill.is_empty():
		var d := (float(hill.top) + float(hill.r)) * 0.5
		var h := t.height_at(hill.pos + Vector3(d, 0, 0))
		check(h > 0.05 and h < float(hill.h) - 0.05, "VGC: encosta (%.2f)" % h)
	var p: BattleFighter = a.enemy
	check(not p.energy_mode, "VGC: fora do modo de energia")
	check(is_equal_approx(C.pass_h(p), p.height()), "VGC: altura de sempre contra objeto")
	check(t.steer(p, Vector3.RIGHT).length() > 0.9, "VGC: steer como antes")
	a.free()


## Lutas inteiras no modo de energia com relevo (sementes fixas): todas acabam.
func _fights() -> void:
	var pool := ["rattata", "geodude", "pidgey", "machop", "squirtle", "charmander", "pikachu"]
	for i in 4:
		var rng := RandomNumberGenerator.new()
		rng.seed = 300 + i
		var mk := func() -> Array:
			var out: Array = []
			for k in 2:
				out.append(Mon.create(String(pool[rng.randi() % pool.size()]), 40))
			return out
		var sc: String = ["campo", "pedreira", "misto", "montanha"][i]
		var a := _arena(
			mk.call(),
			mk.call(),
			400 + i,
			{"battle_size": 1 + (i % 2), "autoplay": true, "scenario": sc, "fast_sim": true}
		)
		var t := 0.0
		var jumps := 0
		var flights := 0
		var cds := {}
		while t < FIGHT_LIMIT and String(a.state) in ["intro", "opening", "fight"]:
			a.step(DT)
			t += DT
			for f in a.fighters:
				if not is_instance_valid(f):
					continue
				var id := f.get_instance_id()
				var prev: Array = cds.get(id, [0.0, 0.0])
				if f.jump_cd > float(prev[0]) + 1.0:
					jumps += 1
				if f.fly_cd > float(prev[1]) + 1.0:
					flights += 1
				cds[id] = [f.jump_cd, f.fly_cd]
		print(
			"  luta %d (%s): %s em %.0f s, %d saltos, %d voos" % [i, sc, a.state, t, jumps, flights]
		)
		check(
			not String(a.state) in ["intro", "opening", "fight"],
			"luta %d acaba em %.0f s (%s)" % [i, FIGHT_LIMIT, a.state]
		)
		a.free()

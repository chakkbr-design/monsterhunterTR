extends SceneTree
## Rodar: godot --headless --path . --script res://tests/battle/test_combos.gd

const ARENA := "res://battle/battle_arena.tscn"
const DT := 1.0 / 60.0

var _fails := 0
var _count := 0


func _initialize() -> void:
	_basics()
	_duo_table()
	_coord()
	_full_fight()
	print("combos: %d checks, %d falhas" % [_count, _fails])
	quit(1 if _fails else 0)


func check(ok: bool, what: String) -> void:
	_count += 1
	if not ok:
		_fails += 1
		print("FALHOU: ", what)


func _run(a: Node, secs: float) -> void:
	for i in int(round(secs / DT)):
		a.step(DT)


func _arena(seed_v: int, auto: bool) -> Node:
	var a: Node = load(ARENA).instantiate()
	a.manual = true
	root.add_child(a)
	a.start(
		[Mon.create("charmander", 20), Mon.create("squirtle", 20)],
		[Mon.create("rattata", 20)],
		{"seed": seed_v, "kind": "wild", "battle_size": 2, "speed": 1.0, "auto_battle": auto}
	)
	return a


func _mv(id: String) -> Dictionary:
	return Dex.move(id)


func _basics() -> void:
	var a := _arena(11, false)
	_run(a, 1.5)
	var c: BattleCombos = a.combos
	var p: BattleFighter = a.player
	var al: BattleFighter = a.ally
	var foe: BattleFighter = a.enemy
	foe.controller = "none"
	check(is_instance_valid(al) and al.side == p.side, "2x1 com parceiro")
	var water := _mv("water_gun")
	var spark := _mv("thunder_shock")
	var ember := _mv("ember")
	if spark.is_empty():
		spark = {"id": "x", "type": "electric", "category": "special", "kind": "projectile"}
	# Marca
	check(c.marks_of(foe).is_empty(), "sem marcas no início")
	c.on_hit(p, foe, water, 5)
	var mk := c.marks_of(foe)
	check(mk.size() == 1 and mk[0].id == "wet" and mk[0].t > 2.5, "marca Molhado aplicada")
	check(c.damage_mult(p, foe, spark) == 1.0, "própria marca não reage")
	# Reação só com parceiro
	var m := c.damage_mult(al, foe, spark)
	check(m > 1.0 and m <= 1.5, "parceiro elétrico reage (%.2f)" % m)
	c.on_hit(al, foe, spark, 5)
	check(c.marks_of(foe).filter(func(x): return x.id == "wet").is_empty(), "marca detonou")
	# ICD
	c.on_hit(p, foe, water, 5)
	check(c.damage_mult(al, foe, spark) == 1.0, "ICD bloqueia nova reação")
	c.tick(2.6)
	c.on_hit(p, foe, water, 5)
	m = c.damage_mult(al, foe, spark)
	check(m > 1.0 and m <= 1.5, "reação volta após ICD")
	c.on_hit(al, foe, spark, 5)
	# Expira
	c.on_hit(p, foe, ember, 5)
	c.tick(BattleCombos.MARK_TIME + 0.1)
	check(c.marks_of(foe).is_empty(), "marcas expiram em MARK_TIME s")
	# Teto do multiplicador
	c.tick(3.0)
	c.on_hit(p, foe, water, 5)
	c.tick(0.2)
	var hi := c.damage_mult(al, foe, water)  # ressonância (mesmo tipo)
	check(hi >= 1.25 and hi <= 1.5, "Ressonância +25%% (%.2f)" % hi)
	c.on_hit(al, foe, water, 5)
	# Ressonância fora da janela
	c.tick(5.0)
	c.on_hit(p, foe, water, 5)
	c.tick(1.5)
	check(c.damage_mult(al, foe, water) < 1.2, "sem Ressonância fora de 1 s")
	# Golpe sintético não marca
	var syn := {"type": "water", "power": 30, "category": "special", "combo": true}
	c.tick(5.0)
	c.on_hit(p, foe, syn, 5)
	check(c.marks_of(foe).is_empty() and c.damage_mult(al, foe, syn) == 1.0, "combo não marca")
	# Sintonia sobe
	var s0 := c.sync_of(p.side)
	c.on_hit(p, foe, ember, 5)
	c.on_hit(al, foe, ember, 5)
	check(c.sync_of(p.side) > s0, "Sintonia sobe com acertos próximos")
	check(c.sync_of(1 - p.side) == 0.0, "Sintonia do outro lado intacta")
	# Golpe de dupla com Sintonia cheia
	c._sync[p.side] = 1.0
	c._duo_cd[p.side] = 0.0
	var hp0 := foe.hp
	foe.immortal = true
	c.on_move_used(p, ember)
	c.on_move_used(al, {"type": "grass", "category": "special"})
	check(c.sync_of(p.side) == 0.0, "golpe de dupla zera a Sintonia")
	_run(a, 1.5)
	check(foe.hp < hp0 or foe.immortal, "golpe de dupla causa dano")
	check(c.sync_of(p.side) < 0.5, "Sintonia depois da dupla")
	a.free()


## Tabela de duplas: pares explícitos, campos válidos, nome, desenho e cobertura dos 18 tipos.
func _duo_table() -> void:
	var a := _arena(12, false)
	var c: BattleCombos = a.combos
	var want := [
		["water", "electric", "thunderstorm"],
		["fire", "grass", "sea_of_fire"],
		["water", "ice", "deep_frost"],
		["fire", "flying", "fire_whirl"],
		["ground", "rock", "stone_wall"],
		["psychic", "fighting", "mind_fist"],
		["steel", "electric", "magnet_storm"],
		["dragon", "fire", "dragon_flame"],
		["dark", "ghost", "eclipse"],
		["fairy", "grass", "enchanted_garden"],
		["bug", "poison", "venom_swarm"],
		["ice", "ground", "permafrost"],
	]
	for w in want:
		check(c._find_duo(w[0], w[1]).get("id", "") == w[2], "dupla %s+%s = %s" % w)
		check(c._find_duo(w[1], w[0]).get("id", "") == w[2], "dupla %s+%s simétrica" % [w[1], w[0]])
	var types := {}
	var ids := {}
	for d in c._duos:
		check(not ids.has(d.id), "id único %s" % d.id)
		ids[d.id] = true
		check(String(d.name) != "" and String(d.get("vis", "")) != "", "nome e vis em %s" % d.id)
		check(d.effect in ["aoe", "field", "buff_team", "debuff_foes"], "efeito de %s" % d.id)
		check(float(d.power) <= 80.0, "dupla modesta %s" % d.id)
		for t in d.types:
			types[t] = true
	check(
		c._find_duo("normal", "fire").get("id", "") == "coordinated", "normal + qualquer = curinga"
	)
	var missing := []
	for t in [
		"normal",
		"fighting",
		"flying",
		"poison",
		"ground",
		"rock",
		"bug",
		"ghost",
		"steel",
		"fire",
		"water",
		"grass",
		"electric",
		"psychic",
		"ice",
		"dragon",
		"dark",
		"fairy"
	]:
		if not types.has(t):
			missing.append(t)
	check(missing.is_empty(), "todo tipo em alguma dupla %s" % [missing])
	# Cada dupla dispara sem erro (visual + efeito) e põe a recarga.
	var p: BattleFighter = a.player
	var al: BattleFighter = a.ally
	a.enemy.immortal = true
	for d in c._duos:
		c._duo_cd[p.side] = 0.0
		c._fire_duo(p, al, d)
		check(c._duo_cd[p.side] > 0.0, "dupla %s disparou" % d.id)
		_run(a, 0.7)
	a.free()


## Coordenação da IA do par: o golpe que fecha dupla/reação é reconhecido.
func _coord() -> void:
	var a := _arena(13, false)
	_run(a, 1.0)
	var c: BattleCombos = a.combos
	var p: BattleFighter = a.player
	var al: BattleFighter = a.ally
	var water := _mv("water_gun")
	var ember := _mv("ember")
	c._duo_cd[p.side] = 0.0
	check(not c.completes_duo(p, ember), "sem golpe do parceiro não fecha dupla")
	c.on_move_used(al, water)
	check(c.completes_duo(p, ember), "fogo fecha dupla com água do parceiro")
	check(not c.completes_duo(al, water), "o próprio golpe não conta")
	c._duo_cd[p.side] = 3.0
	check(not c.completes_duo(p, ember), "dupla em recarga não conta")
	# Marca que o parceiro detona: com Thunder Shock no kit do parceiro, água prepara.
	var keep: Array = p.moves.duplicate()
	p.moves = ["thunder_shock"]
	check(c.sets_up_reaction(al, p, water), "água prepara para o parceiro elétrico")
	p.moves = ["tackle"]
	check(not c.sets_up_reaction(al, p, water), "sem elétrico no kit não prepara")
	p.moves = keep
	a.free()


func _full_fight() -> void:
	for i in 3:
		var a := _arena(40 + i, true)
		var t := 0.0
		while a.state != "done" and t < 300.0:
			a.step(DT)
			t += DT
		check(a.state == "done", "luta 2x1 #%d termina (%.0f s)" % [i, t])
		a.free()

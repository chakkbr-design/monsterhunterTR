extends SceneTree
## Rodar: godot --headless --fixed-fps 60 --path . --script res://tests/battle/test_multihit.gd
## Um uso de golpe acerta cada alvo uma vez (jatos, nuvens, golpes de várias folhas ou socos), fora o
## multi-hit oficial (hits_range), que acerta o número sorteado de vezes, cada uma com o poder oficial.

const ARENA := "res://battle/battle_arena.tscn"
const DT := 1.0 / 60.0
## Golpes que já batiam várias vezes com o poder cheio (ou dividiam o poder em pedaços).
const ONCE := [
	"hurricane",
	"bug_buzz",
	"flamethrower",
	"petal_dance",
	"gust",
	"twister",
	"bubble_beam",
	"heat_wave",
	"razor_leaf",
	"swift",
	"air_cutter",
	"magical_leaf",
	"electroweb",
	"pay_day",
	"close_combat",
	"sand_tomb",
	"fire_spin",
	"whirlpool",
	"wrap",
]
const MULTI := {
	"fury_attack": [2, 5],
	"bullet_seed": [2, 5],
	"pin_missile": [2, 5],
	"double_kick": [2, 2],
	"twineedle": [2, 2],
}

var _count := 0
var _fails := 0


func _initialize() -> void:
	seed(5)
	_data()
	for id in ONCE:
		_hits_per_use(id, 1, 1)
	for id in MULTI:
		_hits_per_use(id, int(MULTI[id][0]), int(MULTI[id][1]))
	_ai_counts()
	print("multihit: %d checks, %d falhas" % [_count, _fails])
	quit(1 if _fails else 0)


func check(ok: bool, what: String) -> void:
	_count += 1
	if not ok:
		_fails += 1
		print("FALHOU: ", what)


func _data() -> void:
	var bad := []
	for id in Dex.all_moves():
		var mv := Dex.move(id)
		if float(mv.get("bp", 0)) > 0.0 and float(mv.get("power", 0)) > 0.0:
			if float(mv.power) != float(mv.bp):
				bad.append(id)
	check(bad.is_empty(), "poder do acerto = poder oficial %s" % str(bad))
	check(Dex.move("hurricane").get("hits_range") == null, "Hurricane não é multi-hit")
	check(
		str(Dex.move("double_kick").get("hits_range")) in ["[2, 2]", "[2.0, 2.0]"],
		"Double Kick é 2 acertos oficiais"
	)


func _arena() -> Node:
	var a: Node = load(ARENA).instantiate()
	a.manual = true
	root.add_child(a)
	var opts := {
		"seed": 3, "speed": 1.0, "auto_battle": false, "damage_pace": 1.0, "field_objects": false
	}
	a.start([Mon.create("pidgeot", 60)], [Mon.create("slowbro", 70)], opts)
	for i in 80:
		a.step(DT)
	a.enemy.controller = "none"
	a.player.controller = "none"
	for i in 90:
		a.step(DT)
	return a


func _reset(a: Node) -> void:
	for f in [a.player, a.enemy]:
		f.hp = f.max_hp
		f.pp_max = f.pp_base
		f.clear_status()
		f.confusion_t = 0.0
		f.trap_t = 0.0
		f.root_t = 0.0
		f.evasion_t = 0.0
		f.knock = Vector3.ZERO
		f.move_cd.clear()
		f.gcd_t = 0.0
		f.stun_t = 0.0
		f.impact_t = 0.0
		f.pp_max = 100.0
		for k in f.stages:
			f.stages[k] = 0
	a.player.position = Vector3(0, 0, 0)
	a.enemy.position = Vector3(0, 0, 1.6)
	a.player.facing = Vector3(0, 0, 1)


## Conta os acertos de golpe (arena.hits: só dano de golpe, sem veneno, queimadura ou preso) num uso.
func _hits_per_use(id: String, lo: int, hi: int) -> void:
	var a := _arena()
	var e: BattleFighter = a.enemy
	var seen := []
	var landed := 0
	for trial in 12:
		_reset(a)
		var h0 := int(a.hits)
		if not a.moves.use(a.player, id):
			continue
		for i in 150:
			a.step(DT)
			e.position = Vector3(0, 0, 1.6)  # o empurrão não tira o alvo do jato
			e.knock = Vector3.ZERO
		var n := int(a.hits) - h0
		if n > 0:
			landed += 1
			seen.append(n)
	check(landed > 0, "%s acertou ao menos uma vez" % id)
	var ok := true
	for n in seen:
		ok = ok and n >= lo and n <= hi
	check(ok, "%s: acertos por uso entre %d e %d %s" % [id, lo, hi, str(seen)])
	a.free()


func _ai_counts() -> void:
	check(BattleMoves.hits_of(Dex.move("close_combat")) == 1, "IA conta Close Combat como 1 acerto")
	check(BattleMoves.hits_of(Dex.move("hurricane")) == 1, "IA conta Hurricane como 1 acerto")
	check(BattleMoves.hits_of(Dex.move("bullet_seed")) == 3, "IA conta Bullet Seed como 3 acertos")
	# Modo de energia: o custo conta os acertos médios e os golpes de poder variável.
	check(
		BattleEnergy.nominal_bp(Dex.move("bullet_seed")) > 75.0,
		"Bullet Seed custa como 25 x 3,1 acertos"
	)
	check(BattleEnergy.nominal_bp(Dex.move("double_kick")) == 60.0, "Double Kick custa como 2 x 30")
	check(BattleEnergy.cost(Dex.move("low_kick")) > 20.0, "Low Kick não sai pelo custo mínimo")

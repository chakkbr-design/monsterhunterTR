extends SceneTree
## Rodar: godot --headless --fixed-fps 60 --path . --script res://tests/battle/test_revisao.gd
## Correções da revisão de fidelidade (docs/REVISAO_1025.md): contato oficial, Obstruct/Silk Trap,
## listas de som/vento/dança, Mold Breaker x Disguise, Transform e Double Shock sem tipo.

const ARENA := "res://battle/battle_arena.tscn"
const DT := 1.0 / 60.0

var _count := 0
var _fails := 0


func check(ok: bool, what: String) -> void:
	_count += 1
	if not ok:
		_fails += 1
		print("FALHOU: ", what)


func _arena(party: Array, enemies: Array) -> Node:
	var a: Node = load(ARENA).instantiate()
	a.manual = true
	root.add_child(a)
	a.start(
		party,
		enemies,
		{
			"kind": "wild",
			"speed": 1.0,
			"battle_mode": "energy",
			"battle_size": 1,
			"no_rewards": true,
			"field_objects": false,
			"seed": 11
		}
	)
	return a


func _run(a: Node, secs: float) -> void:
	for i in int(round(secs / DT)):
		a.step(DT)


func _still(me := "charmander", foe := "slowbro") -> Node:
	var a := _arena([Mon.create(me, 30)], [Mon.create(foe, 30)])
	_run(a, 1.3)
	a.enemy.controller = "none"
	a.player.controller = "none"
	_run(a, 1.5)
	for f in [a.player, a.enemy]:
		f.hp = f.max_hp
		f.clear_status()
		f.move_cd.clear()
		f.gcd_t = 0.0
		f.stun_t = 0.0
		f.pp_max = 100.0
	return a


func _fx(a: Node) -> BattleMoveEffects:
	return a.moves.effects


func _initialize() -> void:
	seed(9)
	_contact()
	_guards()
	_lists()
	_breaker()
	_typeless()
	print("revisao: %d checks, %d falhas" % [_count, _fails])
	quit(1 if _fails else 0)


## Contato oficial: o dado ("contact") vale mais que o kind.
func _contact() -> void:
	var a := _still()
	var ab: BattleAbilities = a.abilities
	check(not ab._is_contact(Dex.move("gigaton_hammer")), "Gigaton Hammer não encosta (oficial)")
	check(not ab._is_contact(Dex.move("aura_wheel")), "Aura Wheel não encosta")
	check(ab._is_contact(Dex.move("fire_lash")), "Fire Lash (chicote) encosta")
	check(ab._is_contact(Dex.move("mortal_spin")), "Mortal Spin encosta")
	check(ab._is_contact(Dex.move("tackle")), "Tackle encosta pelo kind")
	check(not BattleMoreA._contact(Dex.move("salt_cure")), "Salt Cure não ativa King's Shield")
	a.free()


## Obstruct e Silk Trap só barram golpe de dano; Spiky Shield barra tudo.
func _guards() -> void:
	var growl := {"id": "x", "power": 0, "category": "status", "kind": "projectile"}
	var tackle := Dex.move("tackle")
	for g in ["obstruct", "silk_trap", "spiky_shield"]:
		var a := _still()
		var fx := _fx(a)
		a.moves.use(a.player, g)
		_run(a, 0.4)
		check(fx.blocks_hit(a.enemy, a.player, tackle), "%s barra golpe de dano" % g)
		var st_blocked: bool = fx.blocks_hit(a.enemy, a.player, growl)
		check(st_blocked == (g == "spiky_shield"), "%s x golpe de status" % g)
		a.free()


func _lists() -> void:
	for id in ["clangorous_soul", "confide", "howl", "snarl"]:
		check(id in BattleAbilities.SOUND_MOVES, "%s é som (Soundproof)" % id)
	for id in ["clangorous_soul", "confide", "grass_whistle", "parting_shot"]:
		check(id in BattleMoveEffects.SOUND_MOVES, "%s é som (Throat Chop)" % id)
	check("aeroblast" in BattleAbilitiesMore.WIND_MOVES, "Aeroblast é vento")
	check("clangorous_soul" in BattleAbilitiesMore.DANCE_MOVES, "Clangorous Soul é dança")
	check(BattleAbilitiesMore.ATE_MULT == 1.2, "-ate valem x1,2 (Gen 7+)")
	check("hydro_steam" in BattleMoveEffects.THAW_MOVES, "Hydro Steam descongela")


## Mold Breaker passa por cima do Disguise; Moongeist Beam passa por cima da habilidade.
func _breaker() -> void:
	var a := _still("charmander", "mimikyu")
	var ab: BattleAbilities = a.abilities
	a.enemy.set_meta("ability_override", "disguise")
	check(ab._tab(a.player, a.enemy) == "disguise", "sem Mold Breaker, o Disguise vale")
	a.player.set_meta("ability_override", "mold_breaker")
	check(ab._tab(a.player, a.enemy) == "", "com Mold Breaker, o Disguise não vale")
	a.player.remove_meta("ability_override")
	a.moves.use(a.player, "moongeist_beam")
	_run(a, 0.1)
	check(
		ab.ability_of(a.player) == "mold_breaker", "Moongeist Beam: usuário vale como Mold Breaker"
	)
	_run(a, 4.0)
	check(ab.ability_of(a.player) != "mold_breaker", "e volta ao normal depois do golpe")
	a.free()


## Double Shock deixa o usuário sem tipo: nada quebra (HUD, STAB, eficácia, Transform).
func _typeless() -> void:
	var a := _still("pikachu", "slowbro")
	var p: BattleFighter = a.player
	p.types = []
	check(Dex.effectiveness("fire", p.types) == 1.0, "sem tipo: dano neutro")
	check(not "electric" in p.types, "sem tipo: sem STAB")
	p.refresh_label()
	a.moves.use(p, "judgment")
	a.moves.use(p, "multi_attack")
	a.moves.use(p, "revelation_dance")
	_run(a, 1.0)
	check(p.alive(), "golpes que seguem o tipo não quebram sem tipo")
	check(BattleTransform.apply(a, a.enemy, p), "Transform copia quem está sem tipo")
	_run(a, 0.5)
	check(a.enemy.types.is_empty(), "e a cópia também fica sem tipo")
	a.free()


func _unused() -> void:
	pass

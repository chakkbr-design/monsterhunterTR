extends SceneTree
## Rodar: godot --headless --path . --script res://tests/ui_evolution/test_evolution_sprite.gd
## Evolução no próprio Pokémon (evolution.gd do original): sem tela cheia, o CreatureSprite brilha e
## alterna as espécies; na luta de treinador o controlado evolui no meio, com a luta parada, e segue
## lutando com a forma nova. Na selvagem o fim da luta vem antes (fica para o mundo).

const ARENA := "res://battle/battle_arena.tscn"
const DT := 1.0 / 60.0

var fails := 0
var evo: Node


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("FALHOU: ", what)


func _initialize() -> void:
	_run.call_deferred()


func _game() -> Node:
	var g: Node = load("res://core/game.gd").new()
	g.save_path = "user://test_save_evo_sprite.json"
	return g


func _run() -> void:
	evo = root.get_node_or_null("Evolution")
	check(evo != null and evo.has_method("begin_on"), "autoload Evolution com begin_on")
	if evo == null:
		quit(1)
		return
	_sprite_mode()
	_trainer_mid_battle(false)
	_trainer_mid_battle(true)
	_wild_waits()
	_world_follower()
	print("ui_evolution_sprite: %d falhas" % fails)
	quit(1 if fails else 0)


## 1. No sprite: painel pequeno, brilho, troca de espécie, Parabéns, golpe aprendido, finished.
func _sprite_mode() -> void:
	var g := _game()
	var look: Node3D = load("res://gfx/creature_sprite.gd").new()
	look.manual = true
	look.species = "Charmander"
	root.add_child(look)
	var m := Mon.create("Charmander", 16)
	g.party = [m]
	var got := []
	evo.finished.connect(func(e: bool) -> void: got.append(e), CONNECT_ONE_SHOT)
	check(evo.begin_on(m, look, g, {"driven": true}), "begin_on começou")
	check(evo.state == "anim" and evo.is_open(), "no sprite vai direto para a animação")
	check(evo.message == "O quê? Charmander está evoluindo!", "texto: " + evo.message)
	check(not evo._bg.visible and not evo._stage.visible, "sem tela cheia (só o painel)")
	evo.tick(0.9)
	check(look.tint.r > 3.0, "sprite acende (tint %s)" % look.tint)
	var seen := {}
	for i in 200:
		evo.tick(0.02)  # até 4.9 s
		seen[look.species] = true
	check(seen.has("Charmander") and seen.has("Charmeleon"), "alterna as duas espécies: %s" % seen)
	check(m.species == "Charmander", "ainda não evoluiu antes dos 5 s")
	evo.tick(0.2)
	check(evo.state == "done" and m.species == "Charmeleon", "evoluiu no fim")
	check(look.species == "Charmeleon", "sprite fica com a forma nova")
	check(
		evo.message == "Parabéns! Seu Charmander evoluiu para Charmeleon!", "texto: " + evo.message
	)
	evo.tick(0.7)
	check(look.tint.r < 1.5, "brilho volta ao normal em 0,6 s (tint %s)" % look.tint)
	evo.press("ok")
	check(evo.state == "" and got == [true], "fechou e emitiu finished(true): %s" % [got])
	check(evo.look == null, "sessão do sprite limpa")
	# Golpe novo na evolução (evo_moves/learnset no nível): "X aprendeu Y!" antes de fechar.
	var b := Mon.create("Bulbasaur", 16)
	g.party = [b]
	var before: Array = b.moves.duplicate()
	look.species = "Bulbasaur"
	evo.begin_on(b, look, g, {"driven": true})
	evo.tick(5.1)
	var learned := b.moves.filter(func(id): return not before.has(id))
	evo.tick(0.5)
	evo.press("ok")
	if learned.is_empty():
		check(evo.state == "", "sem golpe novo: fecha direto")
	else:
		check(
			evo.state == "learned" and evo.message.ends_with("!"), "fala do golpe: " + evo.message
		)
		while evo.state == "learned":
			evo.tick(0.5)
			evo.press("ok")
		check(evo.state == "", "fechou depois das falas de golpe")
	# Cancelar volta a espécie antiga e trava até o próximo nível.
	var c := Mon.create("Squirtle", 16)
	g.party = [c]
	look.species = "Squirtle"
	evo.begin_on(c, look, g, {"driven": true, "auto": true})
	evo.tick(3.0)
	evo.press("back")
	check(evo.state == "cancelled" and look.species == "Squirtle", "cancelou no sprite")
	check(evo.message == "Hã? Squirtle parou de evoluir!", "texto: " + evo.message)
	check(c.evo_cancelled_level == 16 and c.evolution_target() == "", "travado até o Nv 17")
	evo.tick(0.5)  # auto: a fala passa sozinha
	check(evo.state == "", "auto confirma a fala")
	look.queue_free()
	g.free()


func _arena(party: Array, foes: Array, opts: Dictionary) -> Node:
	var a: Node = load(ARENA).instantiate()
	a.manual = true
	root.add_child(a)
	var got := {}
	a.finished.connect(func(r: Dictionary) -> void: got.merge(r), CONNECT_ONE_SHOT)
	a.set_meta("got", got)
	opts["speed"] = 1.0
	a.start(party, foes, opts)
	return a


## Charmander a 1 EXP do Nv 16 (sobe com qualquer vitória).
func _ready_to_evolve() -> Mon:
	var m := Mon.create("Charmander", 15)
	m.xp = Growth.exp_for_level(m.growth, 16) - 1
	return m


## 2. Treinador com dois Pokémon: o 1º desmaia, o controlado evolui ali com a luta parada e segue.
func _trainer_mid_battle(cancel: bool) -> void:
	var g := _game()
	var m := _ready_to_evolve()
	g.party = [m]
	var foes := [Mon.create("caterpie", 3), Mon.create("weedle", 3)]
	foes[0].hp = 1
	var a := _arena(
		[m],
		foes,
		{
			"kind": "trainer",
			"trainer_id": "bug_catcher_rick",
			"seed": 3,
			"autoplay": true,
			"game": g
		}
	)
	var t := 0.0
	while a._evo == null and a.state != "done" and t < 120.0:
		a.step(DT)
		t += DT
	var tag := " (cancelar)" if cancel else ""
	check(a._evo != null and a.state == "fight", "evoluiu no meio da luta de treinador" + tag)
	check(
		m.level == 16 and foes[0].is_fainted() and not foes[1].is_fainted(), "1º desmaiou, 2º vem"
	)
	if a._evo == null:
		a.queue_free()
		g.free()
		return
	check(a.player.evolving and evo.look == a.player.look, "no sprite do lutador controlado")
	check(not evo._bg.visible, "sem tela cheia na batalha")
	# Luta parada: os eventos (o treinador mandar o próximo) e os lutadores não andam.
	var events: int = a._events.size()
	var pos: Vector3 = a.player.position
	var foe_hp: int = foes[1].hp
	for i in 60:
		a.step(DT)
	check(a._events.size() == events and a.player.position == pos, "luta parada durante a evolução")
	check(foes[1].hp == foe_hp, "ninguém apanha durante a evolução")
	if cancel:
		evo.press("back")
	t = 0.0
	while a._evo != null and t < 30.0:
		a.step(DT)
		t += DT
	check(a._evo == null and evo.state == "","evolução terminou e a tela fechou" + tag)
	var want := "Charmander" if cancel else "Charmeleon"
	check(m.species == want and a.player.look.species == want, "espécie %s: %s" % [want, m.species])
	if not cancel:
		check(a.player.max_hp == m.max_hp and a.player.stats.atk == m.stat("atk"), "stats novos")
		check(bool(g.caught.get("Charmeleon", false)), "Pokédex marca a forma nova")
	else:
		check(m.evo_cancelled_level == 16, "cancelado até o próximo nível")
	t = 0.0
	while a.state != "done" and t < 300.0:
		a.step(DT)
		t += DT
	check(a.state == "done", "a luta continua até o fim" + tag)
	check(a._evo == null, "não tenta evoluir de novo" + tag)
	a.queue_free()
	g.free()


## 4. Mundo: a fila depois da batalha evolui o Pokémon que segue o jogador no próprio sprite; outro
## Pokémon da party (sem corpo no mundo) cai na tela cheia.
func _world_follower() -> void:
	var game: Node = root.get_node("Game")
	var old_party: Array = game.party
	var lead := Mon.create("Charmander", 16)
	var back := Mon.create("Squirtle", 16)
	game.party = [lead, back]
	var f: Node3D = load("res://world/follower.gd").new()
	root.add_child(f)
	f._process(0.0)  # cria o sprite do líder
	var body: Node3D = f.look
	check(body != null and body.species == "Charmander", "seguidor com o sprite do líder")
	game.pending_evolutions = [lead, back]
	game.evolution_requested.emit()
	check(evo.state == "anim" and evo.look == body, "evolui no sprite do seguidor")
	check(not evo._bg.visible, "sem tela cheia para o seguidor")
	evo.tick(5.1)
	check(lead.species == "Charmeleon" and body.species == "Charmeleon", "líder evoluiu no mundo")
	f._process(0.0)
	check(f.look == body, "seguidor mantém o mesmo sprite depois de evoluir")
	evo.tick(0.5)
	evo.press("ok")
	check(evo.state == "intro" and evo.mon == back and evo.look == null, "o outro cai na tela cheia")
	check(evo._bg.visible, "tela cheia de volta")
	evo.press("back")
	evo.tick(0.5)
	evo.press("ok")
	check(evo.state == "", "fila do mundo resolvida")
	f.queue_free()
	game.party = old_party
	game.pending_evolutions = []


## 3. Selvagem:o desmaio já leva ao fim, então não evolui na batalha (o mundo cuida depois).
func _wild_waits() -> void:
	var g := _game()
	var m := _ready_to_evolve()
	g.party = [m]
	var foe := Mon.create("pidgey", 2)
	foe.hp = 1
	var a := _arena([m], [foe], {"seed": 5, "autoplay": true, "game": g})
	var t := 0.0
	var started := false
	while a.state != "done" and t < 120.0:
		a.step(DT)
		started = started or a._evo != null
		t += DT
	check(a.state == "done" and m.level == 16, "venceu e subiu para o Nv 16")
	check(not started and m.species == "Charmander", "selvagem não evolui dentro da luta")
	check(m.evolution_target() == "Charmeleon", "segue pronto para evoluir no mundo")
	a.queue_free()
	g.free()

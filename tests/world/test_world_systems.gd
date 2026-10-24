extends SceneTree
## Headless: godot --headless --fixed-fps 60 --path . --script res://tests/world/test_world_systems.gd
## Rodada 6 (G2b): white-out lines like the original Game.whiteout, Escape Rope and heal_with_fade,
## Repel blocking grass rolls, the clock (MON 9:00, stops with dialogue), wandering / lying NPCs and
## pond swimmers that swim inside the water.

var _fails := 0
var game: Node
var w: Node3D
var p: CharacterBody3D
var hud: Node
var _said: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	print(("ok   " if cond else "FAIL ") + what)
	if not cond:
		_fails += 1


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	game = root.get_node("Game")
	game.save_path = "user://test_world_systems_save.json"
	game.new_game("ASH", "GARY")
	game.flags["got_starter"] = true
	game.add_mon(load("res://core/mon.gd").create("bulbasaur", 5))
	game.spawn_request = {"zone": "viridian_city", "spawn": "vc_center_door"}
	w = load("res://world/route_world.tscn").instantiate()
	w.fade_time = 0.0
	root.add_child(w)
	await frames(10)
	p = get_first_node_in_group("ow_player")
	hud = get_first_node_in_group("ow_hud")
	if hud == null:
		hud = w.hud_of(w)
	check(p != null and hud != null, "world, player and HUD up")
	await _clock()
	await _swimmers()
	await _npcs()
	_repel()
	await _whiteout()
	await _battle_loss()
	await _escape_rope()
	await _heal_with_fade()
	w.queue_free()
	await frames(2)
	print("[world systems] %d failed" % _fails)
	quit(1 if _fails > 0 else 0)


## Advances every line the HUD shows, recording them.
func _auto_advance() -> void:
	while is_instance_valid(hud):
		if hud.is_dialog_open():
			var t := String(hud._dlg.label.text)
			if _said.is_empty() or _said[-1] != t:
				_said.append(t)
				await frames(15)
				hud.advanced.emit()
		await physics_frame


func _clock() -> void:
	var tod = w.get_node("TimeOfDay")
	check(tod.clock_label() == "SEG 9:00", "clock starts MON 9:00 (%s)" % tod.clock_label())
	await frames(120)
	var t1: float = tod.total
	check(t1 > 540.0, "clock runs while the player is free (%.2f)" % t1)
	var done := [false]
	var talk := func():
		await hud.say("Teste", PackedStringArray(["linha"]))
		done[0] = true
	talk.call()
	await frames(120)
	check(absf(tod.total - t1) < 0.05, "clock stops with a dialogue open (%.2f)" % tod.total)
	hud.advanced.emit()
	await frames(5)
	check(done[0], "test dialogue closed")
	check(game.flags.get("clock_minutes", 0.0) == tod.total, "clock kept in Game.flags")


func _swimmers() -> void:
	var sw: Array = []
	for m in get_nodes_in_group("ow_wild"):
		if m.swimmer:
			sw.append([m, m.global_position])
	check(not sw.is_empty(), "Viridian pond has swimmers (%d)" % sw.size())
	await frames(60 * 8)
	var moved := 0.0
	var dry := 0
	for e in sw:
		if is_instance_valid(e[0]):
			moved = maxf(moved, e[0].global_position.distance_to(e[1]))
			if not e[0]._in_water(e[0].global_position):
				dry += 1
	check(moved > 0.5, "a swimmer swam about in 8 s (%.1f m)" % moved)
	check(dry == 0, "every swimmer is still in the water")


func _npcs() -> void:
	var vb = w.builders.get("viridian_city")
	var kid = vb.get_node_or_null("NPC_Kid") if vb else null
	var old = vb.get_node_or_null("NPC_OldManSleepy") if vb else null
	check(kid != null and kid.wander_radius == 2.0, "Viridian school kid wanders 2 m")
	if old:
		check(old.lying, "sleepy old man lies down")
		check(
			old.char_sprite == null or absf(old.char_sprite.rotation.z + PI * 0.5) < 0.01,
			"his sprite is on its side"
		)
	if kid:
		var at: Vector3 = kid.global_position
		var far := 0.0
		for i in 12:
			await frames(60)
			far = maxf(far, kid.global_position.distance_to(at))
		check(far > 0.1, "the kid moved (%.2f m)" % far)
		check(far < 2.0 * 1.5 + 0.5, "and stayed near home")


func _repel() -> void:
	if game.has_method("repel_step"):
		game.repel_steps = 2
		for i in 3:
			p._footstep(0.4, true, false)
		check(game.repel_steps == 0, "footsteps spend the Repel")
		check(String(hud._toast.text).contains("Repel"), "wore-off message (%s)" % hud._toast.text)
	var e := EncounterRate.new()
	var rng := RandomNumberGenerator.new()
	var hit := false
	for i in 2000:
		if e.walk(1.6, 25.0, rng, true):
			hit = true
	check(not hit, "Repel: 3 km of grass without a roll")


## A real lost battle (arena finished with "lose"): Game takes the money, Overworld.battle runs the
## white-out lines with the amount lost before returning.
func _battle_loss() -> void:
	await w.go_to_zone("route_1", "")
	game.flags["last_heal"] = "player_house"
	game.money = 3000
	_said = []
	var res := [null]
	var fight := func():
		res[0] = await w.battle([load("res://core/mon.gd").create("rattata", 3)], {"kind": "wild"})
	fight.call()
	await frames(5)
	var arena = game._arena
	check(arena != null, "arena started")
	if arena:
		arena.finished.emit({"outcome": "lose"})
	for i in 600:
		if res[0] != null:
			break
		await physics_frame
	check(res[0] != null, "battle() returned after the white-out")
	var lost := 3000 - int(game.money)
	check(
		_said.size() == 4 and _said[1].contains("₽%d" % lost),
		"loss lines name the money lost (₽%d: %s)" % [lost, " | ".join(_said)]
	)
	check(w.location_id == "player_house", "lost battle -> home (%s)" % w.location_id)


func _whiteout() -> void:
	_auto_advance()
	_said = []
	game.flags["last_heal"] = "player_house"
	await w._white_out(p, 1500)
	check(_said.size() == 4, "white-out shows 4 lines (%s)" % " | ".join(_said))
	check(_said.size() > 1 and _said[1].contains("₽1500"), "money lost line")
	check(_said.size() > 3 and _said[3].contains("para casa"), "home line")
	check(w.location_id == "player_house", "back home (%s)" % w.location_id)
	check(not p.locked, "player free again")
	_said = []
	game.flags["last_heal"] = "pokemon_center_pewter"
	await w._white_out(p, 0)
	check(_said.size() == 3, "no money line when nothing was lost (%d)" % _said.size())
	check(_said.size() > 2 and _said[2].contains("Centro Pokémon"), "Pokémon Center line")
	check(w.location_id == "pokemon_center_pewter", "at the Pewter center (%s)" % w.location_id)


func _escape_rope() -> void:
	game.flags["last_heal"] = "pokemon_center_viridian"
	await w.go_to_zone("route_2", "")
	if "repel_steps" in game:
		game.repel_steps = 50
	var ok: bool = await w.escape_rope()
	check(ok, "Escape Rope used")
	check(w.location_id == "pokemon_center_viridian", "rope -> last heal (%s)" % w.location_id)
	if "repel_steps" in game:
		check(game.repel_steps == 0, "rope ends the Repel")


func _heal_with_fade() -> void:
	var m = game.party[0]
	m.hp = 1
	await w.heal_with_fade()
	check(m.hp == m.max_hp, "heal_with_fade heals the party")

extends Node
## Autoload `Story`: roteiro do começo do jogo (FRLG simplificado), guiado por Game.flags.
## Cenas são corrotinas lineares: begin() trava o jogador, say/ask/walk/wait/give_item, end() devolve.
## Regras puras (o que dispara onde) ficam em StoryFlags; aqui só a encenação.
##
## Ganchos no mundo (sem editar world/): ao entrar uma RouteWorld na árvore, o Story
## - desfaz o Bulbasaur de teste que o Overworld põe numa equipe vazia (jogo novo, sem inicial);
## - cria StoryTrigger a partir dos `triggers` de data/maps/<zona>.json (oak_stop no norte de Pallet);
## - ouve `location_changed` para montar o laboratório e disparar Loja/Laboratório/Casa.

signal cutscene_started(id: String)
signal cutscene_finished(id: String)

const OAK := "Prof. Carvalho"
const MOM := "Mamãe"
const CLERK := "Vendedor"
const HANDLED_EVENTS := ["oak_stop", "pewter_east_block"]
const GYM := "pewter_gym"
const BROCK := "brock"
## Entrada sul de Pewter: o guia leva o jogador até o ginásio (uma vez, antes da insígnia).
const PEWTER_GUIDE_TRIGGER := {"node": "PewterGuideTrigger", "event": "pewter_guide", "pos": [0.0, -391.0],
		"size": [14, 3, 2.0], "blocks": ["pewter_guide_done", "badge_boulder"], "y": 0.0}
const GYM_FRONT := Vector3(-18.15, 0.0, -428.6)
const TYPE_PT := {"grass": "Planta", "fire": "Fogo", "water": "Água", "poison": "Veneno", "normal": "Normal"}
const LAB := "oak_lab"
const LAB_SPAWN := "door"

## Testes e demo: avança o diálogo sozinho, responde perguntas (null = pergunta ao jogador),
## liga autoplay na batalha e acrescenta opts (seed, speed...).
var auto_advance := false
var auto_answer: Variant = null
var auto_battle := false
var battle_extra: Dictionary = {}

var world: Node3D = null
var location_kind := "zone"
var location_id := ""
## Resultado da última batalha de roteiro.
var last_battle: Dictionary = {}

var _running := 0
var _current := ""
var _actors: Dictionary = {}  ## papel -> StoryNpc (salas)
var _balls: Dictionary = {}  ## espécie -> StarterBall
var _triggers: Array = []


func is_running() -> bool:
	return _running > 0


func current() -> String:
	return _current


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	for n in get_tree().get_nodes_in_group(Overworld.GROUP):
		if n is RouteWorld:
			attach(n)


func _process(_delta: float) -> void:
	if auto_advance:
		var h := hud()
		if h and h.is_dialog_open():
			h.advanced.emit()


# --- Ligação com o mundo ------------------------------------------------------------------------

func _on_node_added(n: Node) -> void:
	if n is RouteWorld and n != world:
		# Só um jogo novo (spawn_request) chega sem equipe; aí o Overworld não semeia e o inicial vem do Oak.
		var seeded := Game.party.is_empty() and not flag("got_starter") and not Game.spawn_request.is_empty()
		n.ready.connect(_on_world_ready.bind(n, seeded), CONNECT_ONE_SHOT)


func _on_world_ready(w: Node3D, seeded: bool) -> void:
	if seeded and not flag("got_starter") and Game.party.size() == 1:
		Game.party.clear()
		Game.seen.clear()
		Game.caught.clear()
	attach(w)


func attach(w: Node3D) -> void:
	if world == w:
		return
	world = w
	_triggers.clear()
	_actors.clear()
	_balls.clear()
	location_kind = "zone"
	location_id = ""
	if w.has_signal("location_changed"):
		w.location_changed.connect(_on_location_changed)
	for zone in (RouteWorld.ZONES if w is RouteWorld else []):
		for e in MapBuilder.load_map(String(zone)).get("triggers", []):
			if HANDLED_EVENTS.has(String(e.get("event", ""))):
				_add_trigger(w, e)
	if w is RouteWorld and RouteWorld.ZONES.has("pewter_city"):
		_add_trigger(w, PEWTER_GUIDE_TRIGGER)
	if w.has_method("set_interact_hook"):
		w.set_interact_hook("player_house", "mom", _mom_hook)
		w.set_interact_hook("mart_viridian", "clerk", _clerk_hook)
		w.set_interact_hook(GYM, BROCK, _brock_hook)
	_sync_location.call_deferred()


## Mamãe (NPC dos Interiores): antes do inicial só conversa; com a cena pendente, roda a cena.
## Devolve true quando a história tratou a conversa (o NPC não cura/fala o padrão).
func _mom_hook(_npc: Node) -> bool:
	if is_running():
		return true
	if StoryFlags.interior_event(Game.flags, "player_house") == "mom_heal":
		await mom_heal()
		return true
	if not flag("got_starter"):
		await begin("talk_mom")
		await say(MOM, StoryFlags.mom_lines(Game.flags))
		end()
		return true
	return false


func _clerk_hook(_npc: Node) -> bool:
	if is_running():
		return true
	if StoryFlags.interior_event(Game.flags, "mart_viridian") == "mart_parcel":
		await mart_parcel()
		return true
	return false


func _add_trigger(w: Node3D, e: Dictionary) -> void:
	var t := StoryTrigger.from_entry(e)
	if t.event == "oak_stop":
		# O Oak barra sempre que não há inicial (voltar do lab sem escolher também conta).
		t.blocks = PackedStringArray(["got_starter"])
		t.requires = PackedStringArray()
	elif t.event == "pewter_east_block":
		# A Rota 3 ainda não existe: o aviso vale mesmo com a insígnia.
		t.blocks = PackedStringArray()
	w.add_child(t)
	_triggers.append(t)


func triggers() -> Array:
	return _triggers.filter(func(t): return is_instance_valid(t))


## Se a RouteWorld já começou dentro de uma sala (spawn_request do novo jogo), monta-a.
func _sync_location() -> void:
	if world == null or not is_instance_valid(world):
		return
	var kind = world.get("location_kind")
	var id = world.get("location_id")
	if kind is String and id is String and id != "" and id != location_id:
		_on_location_changed(kind, id)


func _on_location_changed(kind: String, id: String) -> void:
	var was := location_id
	location_kind = kind
	location_id = id
	if kind != "interior" or id != was:
		_clear_room()
	if kind != "interior":
		return
	_populate(id)
	var ev := StoryFlags.interior_event(Game.flags, id)
	if ev != "" and not is_running():
		_run_event.call_deferred(ev)


func _run_event(ev: String) -> void:
	if is_running():
		return
	match ev:
		"mart_parcel":
			await mart_parcel()
		"parcel_deliver":
			await parcel_deliver()
		"mom_heal":
			await mom_heal()


## Dispatch dos StoryTrigger.
func trigger(event: String, _source: Node = null) -> void:
	if is_running():
		return
	match event:
		"oak_stop":
			if StoryFlags.oak_should_stop(Game.flags):
				await oak_stop()
		"pewter_east_block":
			await pewter_east_block()
		"pewter_guide":
			if StoryFlags.pewter_guide_due(Game.flags):
				await pewter_guide()


# --- API de cena --------------------------------------------------------------------------------

func flag(k: String) -> bool:
	return StoryFlags.on(Game.flags, k)


func set_flag(k: String, v: Variant = true) -> void:
	Game.flags[k] = v


func player() -> OverworldPlayer:
	return Overworld.player_of(self)


func hud() -> WorldHud:
	return Overworld.hud_of(self)


func begin(id: String) -> void:
	while Game.is_busy():
		await get_tree().process_frame
	_running += 1
	_current = id
	var p := player()
	if p:
		p.locked = true
		p.velocity = Vector3.ZERO
	cutscene_started.emit(id)


func end() -> void:
	_running = maxi(_running - 1, 0)
	if _running > 0:
		return
	var id := _current
	_current = ""
	var p := player()
	if p:
		p.locked = false
	cutscene_finished.emit(id)


func say(who: String, lines: Variant) -> void:
	var arr := PackedStringArray([lines] if lines is String else lines)
	for i in arr.size():
		arr[i] = Game.fill_names(arr[i])
	var h := hud()
	if h == null:
		return
	await h.say(Game.fill_names(who), arr)


## Pergunta Sim/Não (com cartão de espécie opcional).
func ask(question: String, species := "") -> bool:
	if auto_answer != null:
		await get_tree().process_frame
		return bool(auto_answer)
	return await StarterCard.open(self, question, species)


func wait(secs: float) -> void:
	await get_tree().create_timer(secs).timeout


## Anda em linha reta até `to` (y mantido). Funciona com StoryNpc e com o jogador.
func walk(actor: Node3D, to: Vector3, speed := StoryNpc.WALK_SPEED) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	to.y = actor.global_position.y
	await StoryNpc.move_node(actor, to, speed)


## Anda até ficar a `gap` metros de `target`, de frente para ele.
func approach(actor: Node3D, target: Node3D, gap := 1.4) -> void:
	if actor == null or target == null:
		return
	var to := actor.global_position - target.global_position
	to.y = 0.0
	if to.length() < 0.01:
		to = Vector3(0, 0, 1)
	await walk(actor, target.global_position + to.normalized() * gap)
	face_each_other(actor, target)


func face_each_other(a: Node3D, b: Node3D) -> void:
	for pair in [[a, b], [b, a]]:
		var n: Node3D = pair[0]
		if n == null:
			continue
		if n.has_method("face_toward"):
			n.face_toward(pair[1].global_position)
		elif n.has_method("face"):
			n.face(pair[1].global_position)


func give_item(id: String, n := 1, label := "") -> void:
	Game.add_item(id, n)
	if label == "":
		label = String(Dex.item(id).get("name", id))
	await say("", ["{PLAYER} recebeu %s!" % label])


# --- Atores ---------------------------------------------------------------------------------------

func marker_pos(interior: String, mname: String, fallback := Vector3.INF) -> Vector3:
	if world and world.has_method("marker"):
		var m = world.marker(interior, mname)
		if m is Node3D and is_instance_valid(m):
			return m.global_position
	if fallback != Vector3.INF:
		return fallback
	var p := player()
	return p.global_position if p else Vector3.ZERO


func spawn_npc(role: String, npc_name: String, at: Vector3, color: Color) -> StoryNpc:
	var n := StoryNpc.new()
	n.role = role
	n.npc_name = npc_name
	n.color = color
	n.name = "Story_" + role
	(world if world else self).add_child(n)
	n.global_position = at
	return n


func _spawn_role(role: String, at: Vector3) -> StoryNpc:
	var info: Array = {
		"oak": [OAK, Color(0.92, 0.92, 0.88)], "rival": ["{RIVAL}", Color(0.35, 0.3, 0.6)],
		"mom": [MOM, Color(0.85, 0.5, 0.6)], "clerk": [CLERK, Color(0.25, 0.45, 0.8)],
	}[role]
	var n := spawn_npc(role, Game.fill_names(info[0]), at, info[1])
	_actors[role] = n
	return n


func actor(role: String) -> StoryNpc:
	var n = _actors.get(role)
	return n if n != null and is_instance_valid(n) else null


func ball(species: String) -> StarterBall:
	var b = _balls.get(species)
	return b if b != null and is_instance_valid(b) and b.is_in_group(WorldNpc.GROUP) else null


func _clear_room() -> void:
	for n in _actors.values() + _balls.values():
		if is_instance_valid(n):
			n.queue_free()
	_actors.clear()
	_balls.clear()


func _populate(id: String) -> void:
	match id:
		LAB:
			var f := Game.flags
			if StoryFlags.lab_has_oak(f) and actor("oak") == null:
				_spawn_role("oak", marker_pos(LAB, "oak"))
			if StoryFlags.lab_has_rival(f) and actor("rival") == null:
				_spawn_role("rival", marker_pos(LAB, "rival"))
			var left := StoryFlags.balls_left(f, Game.STARTERS)
			for i in Game.STARTERS.size():
				var sp: String = Game.STARTERS[i]
				if not left.has(sp) or ball(sp) != null:
					continue
				var b := StarterBall.new()
				b.species = sp
				b.name = "StarterBall_" + sp
				world.add_child(b)
				b.global_position = marker_pos(LAB, "ball_%d" % (i + 1), Vector3(i - 1.0, 0, -2) + marker_pos(LAB, "oak"))
				_balls[sp] = b
		"player_house":
			_ensure_role("mom", "player_house")
		"mart_viridian":
			_ensure_role("clerk", "mart_viridian")


## NPC interagível (dos Interiores ou nosso) parado no marcador `role` da sala, ou null.
func npc_at(room: String, role: String) -> Node3D:
	var mine := actor(role)
	if mine:
		return mine
	if world == null or not world.has_method("marker"):
		return null
	var m = world.marker(room, role)
	if not (m is Node3D):
		return null
	var best: Node3D = null
	var best_d := 1.5
	for n in get_tree().get_nodes_in_group(WorldNpc.GROUP):
		if n is Node3D and not n is StarterBall:
			var d: float = n.global_position.distance_to(m.global_position)
			if d < best_d:
				best = n
				best_d = d
	return best


## Os Interiores põem Mamãe e o vendedor; só criamos um se a sala não tiver ninguém no marcador.
func _ensure_role(role: String, room: String) -> void:
	if npc_at(room, role) != null or world == null or not world.has_method("marker"):
		return
	var m = world.marker(room, role)
	if m is Node3D:
		_spawn_role(role, m.global_position)


## Falas de quem a história controla (StoryNpc.interact).
func talk(npc: StoryNpc) -> void:
	if is_running():
		return
	await begin("talk_" + npc.role)
	match npc.role:
		"oak":
			if StoryFlags.interior_event(Game.flags, LAB) == "parcel_deliver":
				end()
				await parcel_deliver()
				return
			await say(OAK, StoryFlags.oak_lines(Game.flags))
		"rival":
			await say("{RIVAL}", StoryFlags.rival_lines(Game.flags))
		"mom":
			await say(MOM, StoryFlags.mom_lines(Game.flags))
			if flag("got_starter"):
				Game.heal_party()
		_:
			await say(npc.npc_name, npc.lines)
	end()


# --- Roteiro ---------------------------------------------------------------------------------------

func _goto_interior(id: String, spawn: String) -> void:
	if world and world.has_method("go_to_interior"):
		await world.go_to_interior(id, spawn)
	await get_tree().process_frame
	if location_id != id:
		# Sem sinal (ou ainda não emitido): monta a sala mesmo assim.
		_on_location_changed("interior", id)


## 1. Pallet, mato alto do norte sem inicial: o Oak barra e leva ao laboratório.
func oak_stop() -> void:
	await begin("oak_stop")
	var p := player()
	if p == null:
		end()
		return
	p.show_alert(true)
	await wait(0.6)
	await say(OAK, ["Espere! Não vá lá fora!"])
	p.show_alert(false)
	var oak := spawn_npc("oak_out", OAK, p.global_position + Vector3(0, 0, 6.0), Color(0.92, 0.92, 0.88))
	p.face_toward(oak.global_position)
	await approach(oak, p, 1.4)
	await say(OAK, ["É perigoso! Pokémon selvagens vivem no mato alto!",
		"Você precisa do seu próprio Pokémon para se proteger.", "Já sei! Venha comigo!"])
	var dest := oak.global_position + Vector3(0, 0, 3.0)
	oak.walk_to(dest)
	await walk(p, dest - Vector3(0, 0, 1.0))
	set_flag("oak_stopped")
	await _goto_interior(LAB, LAB_SPAWN)
	oak.queue_free()
	await lab_intro()
	end()


## 2a. Chegada ao laboratório.
func lab_intro() -> void:
	await wait(0.3)
	var p := player()
	var oak := actor("oak")
	var rival := actor("rival")
	if p and oak:
		await approach(p, oak, 1.8)
	await say("{RIVAL}", ["Vovô! Cansei de esperar!"])
	await say(OAK, ["{RIVAL}? Ah, é verdade, eu pedi para você vir. Espere um pouco!",
		"Aqui, {PLAYER}. Nessa mesa há três Pokémon, dentro das Poké Balls.",
		"Quando eu era jovem, fui um treinador sério.",
		"Agora só me restam esses três. Pode ficar com um. Vamos, escolha!"])
	if rival and p:
		face_each_other(rival, p)
	await say("{RIVAL}", ["Ei, vovô! E eu?"])
	await say(OAK, ["Calma, {RIVAL}. Você também vai ganhar um!"])


static func type_label(species: String) -> String:
	var out: Array = []
	for t in Dex.species(species).get("types", []):
		out.append(TYPE_PT.get(String(t), String(t).capitalize()))
	return "/".join(out)


## 2b. Interagir com uma Poké Ball da mesa.
func pick_starter(b: StarterBall) -> void:
	if is_running():
		return
	if not StoryFlags.can_pick(Game.flags):
		await begin("ball_locked")
		await say("", ["São Poké Balls do Prof. Carvalho." if not flag("got_starter") else "É o Pokémon do {RIVAL}... melhor não mexer."])
		end()
		return
	await begin("pick_starter")
	var sp := Dex.canon(b.species)
	var nm := String(Dex.species(sp).get("name", sp))
	var yes := await ask("Então, {PLAYER}, você quer %s, o Pokémon do tipo %s?" % [nm, type_label(sp)], sp)
	if not yes:
		end()
		return
	Game.choose_starter(sp)
	set_flag("got_starter")
	set_flag("starter_chosen")
	b.take()
	await say("", ["{PLAYER} recebeu %s do Prof. Carvalho!" % nm])
	var rsp := String(Game.flags.get("rival_starter", ""))
	var rival := actor("rival")
	var rb := ball(rsp)
	if rival and rb:
		await say("{RIVAL}", ["Então eu fico com este!"])
		await approach(rival, rb, 0.9)
		rb.take()
	await say("", ["{RIVAL} recebeu %s do Prof. Carvalho!" % String(Dex.species(rsp).get("name", rsp))])
	await rival_battle()
	end()


## 2c. Primeira luta com o rival (inicial dele no Nv5). Ganhar ou perder, a história segue.
func rival_battle() -> void:
	var p := player()
	var rival := actor("rival")
	if rival and p:
		await approach(rival, p, 1.4)
	await say("{RIVAL}", ["Espere, {PLAYER}! Vamos ver qual Pokémon é mais forte!"])
	var enemies: Array = []
	for e in StoryFlags.first_rival_party(Game.flags):
		enemies.append(Mon.create(String(e[0]), int(e[1])))
	var tflag := "trainer_" + StoryFlags.RIVAL_TRAINER
	var had_tflag := Game.flags.has(tflag)
	var back := p.global_position if p else Vector3.ZERO
	var opts := {"kind": "trainer", "trainer_id": StoryFlags.RIVAL_TRAINER, "can_run": false, "scripted": true}
	if auto_battle:
		opts["autoplay"] = true
	opts.merge(battle_extra, true)
	var r: Dictionary = {}
	var ow := Overworld.of(self)
	if ow and not enemies.is_empty():
		r = await ow.battle(enemies, opts)
	last_battle = r
	# A vitória aqui não conta como vencer o rival da Rota 22.
	if not had_tflag:
		Game.flags.erase(tflag)
	var outcome := String(r.get("outcome", "win"))
	if outcome == "lose" and p:
		# Batalha de roteiro: nada de voltar ao ponto de cura (o Game já curou e não cobrou).
		p.global_position = back
		p.velocity = Vector3.ZERO
	set_flag("rival_battle_done")
	set_flag("rival_battle_won", outcome == "win")
	if outcome == "win":
		await say("{RIVAL}", ["O quê? Não acredito! Escolhi o Pokémon errado!"])
	else:
		await say("{RIVAL}", ["Isso! Meu Pokémon é demais!"])
	await say("{RIVAL}", ["Vou treinar meu Pokémon e ficar ainda mais forte.", "{PLAYER}! Vovô! Até mais!"])
	if rival:
		await walk(rival, door_pos(LAB, rival.global_position + Vector3(0, 0, 6)))
		rival.queue_free()
	await say(OAK, ["{PLAYER}, seu Pokémon deve estar cansado. Passe em casa: sua mãe cuida dele.",
		"Depois siga para o norte, pela Rota 1, até a Cidade de Viridian."])


## 3. Mamãe cura depois da primeira luta.
func mom_heal() -> void:
	await begin("mom_heal")
	var mom := npc_at("player_house", "mom")
	var p := player()
	if mom and p:
		await approach(p, mom, 1.4)
	await say(MOM, ["{PLAYER}! O Prof. Carvalho lhe deu um Pokémon? Que maravilha!", "Descanse um pouco."])
	Game.heal_party()
	await say(MOM, ["Pronto, seu time está cheio de energia!", "Vai para Viridian? Tome cuidado!"])
	set_flag("mom_healed")
	end()


## 4. Loja de Viridian: a encomenda do Oak.
func mart_parcel() -> void:
	await begin("mart_parcel")
	var p := player()
	var clerk := npc_at("mart_viridian", "clerk")
	await say(CLERK, ["Ei! Você veio de Pallet?"])
	if p:
		var at := marker_pos("mart_viridian", "clerk", p.global_position)
		var to := p.global_position - at
		to.y = 0.0
		if to.length() > 1.6:
			await walk(p, at + to.normalized() * 1.5)
		p.face_toward(at)
		if clerk:
			face_each_other(clerk, p)
	await say(CLERK, ["Você conhece o Prof. Carvalho, não é? A encomenda dele chegou.", "Pode levar para ele?"])
	await give_item(StoryFlags.PARCEL, 1, "a ENCOMENDA DO PROF. CARVALHO")
	set_flag("has_parcel")
	await say(CLERK, ["Obrigado! Mande lembranças ao Prof. Carvalho."])
	end()


## 5. Entrega da encomenda: Pokédex e Poké Balls.
func parcel_deliver() -> void:
	await begin("parcel_deliver")
	var p := player()
	var oak := actor("oak")
	if oak == null:
		oak = _spawn_role("oak", marker_pos(LAB, "oak"))
	if p:
		await approach(p, oak, 1.6)
	await say(OAK, ["Ah, {PLAYER}! Como vai o meu Pokémon?", "Parece que ele já gosta muito de você.",
		"O quê? Você tem algo para mim?"])
	Game.take_item(StoryFlags.PARCEL)
	set_flag("has_parcel", false)
	await say("", ["{PLAYER} entregou a ENCOMENDA DO PROF. CARVALHO."])
	await say(OAK, ["Ah! É a Poké Ball especial que encomendei. Obrigado!"])
	var rival := actor("rival")
	if rival == null:
		rival = _spawn_role("rival", door_pos(LAB, p.global_position + Vector3(0, 0, 4) if p else Vector3.ZERO))
	if p:
		await approach(rival, p, 1.4)
	await say("{RIVAL}", ["Vovô! Para que me chamou?"])
	await say(OAK, ["Ah, sim! Tenho um pedido para vocês dois.",
		"Esta é a minha invenção, a Pokédex! Ela registra os Pokémon que vocês virem ou capturarem.",
		"{PLAYER}, {RIVAL}: levem uma cada um."])
	await give_item(StoryFlags.POKEDEX, 1, "a POKÉDEX")
	set_flag("has_pokedex")
	await say(OAK, ["Para ter dados completos, é preciso capturar os Pokémon.",
		"Aqui estão algumas ferramentas para isso."])
	await give_item("poke_ball", StoryFlags.DEX_BALLS, "%d POKÉ BALLS" % StoryFlags.DEX_BALLS)
	await say(OAK, ["Completar um guia de todos os Pokémon do mundo era o meu sonho.",
		"Agora conto com vocês dois!"])
	await say("{RIVAL}", ["Pode deixar comigo, vovô!",
		"{PLAYER}, nem precisa se esforçar. Eu vou completar a Pokédex primeiro! Hahaha!"])
	await walk(rival, door_pos(LAB, rival.global_position + Vector3(0, 0, 6)))
	rival.queue_free()
	set_flag("parcel_delivered")
	end()


## Porta da sala (spawn "door" da InteriorRoom); `fallback` se não houver.
func door_pos(room: String, fallback: Vector3) -> Vector3:
	if world and world.has_method("interior"):
		var r = world.interior(room)
		if r and r.has_method("spawn_point") and r.has_spawn("door"):
			return r.spawn_point("door")
	return fallback


# --- Pewter -----------------------------------------------------------------------------------------

## Saída leste de Pewter: sem a Insígnia da Rocha o garoto barra; com ela, a Rota 3 está em obras.
func pewter_east_block() -> void:
	await begin("pewter_east_block")
	var p := player()
	if p:
		p.show_alert(true)
	if flag("badge_boulder"):
		await say("Aviso", ["A Rota 3 está em construção.", "Volte mais tarde!"])
	else:
		await say("Garoto", ["Você não pode ir para o leste, até a Rota 3, sem a Insígnia da Rocha.",
			"Vença o Líder Brock no Ginásio de Pewter e depois volte!"])
	if p:
		p.show_alert(false)
		await walk(p, p.global_position + Vector3(-3.0, 0, 0))
	end()


## Chegada a Pewter: um garoto leva o jogador até a porta do ginásio.
func pewter_guide() -> void:
	await begin("pewter_guide")
	var p := player()
	if p == null:
		end()
		return
	set_flag("pewter_guide_done")
	var guide := spawn_npc("pewter_guide", "Garoto", p.global_position + Vector3(2.5, 0, -2.5), Color(0.85, 0.65, 0.3))
	face_each_other(guide, p)
	await say("Garoto", ["Ei, você! Você é um treinador?",
		"O Líder do Ginásio de Pewter, Brock, está procurando desafiantes!", "Venha, eu levo você até lá!"])
	# Pelo caminho central (x = 0) até a rua do ginásio, depois a oeste até a porta.
	for wp in [Vector3(0.0, 0, -429.0), GYM_FRONT + Vector3(0, 0, 1.2)]:
		guide.walk_to(Vector3(wp.x + 0.9, guide.global_position.y, wp.z - 0.9))
		await walk(p, Vector3(wp.x, p.global_position.y, wp.z))
	face_each_other(guide, p)
	await say("Garoto", ["Aqui é o Ginásio de Pewter!", "Brock usa Pokémon do tipo Pedra. Boa sorte!"])
	if is_instance_valid(guide):
		await walk(guide, guide.global_position + Vector3(6.0, 0, 0))
		guide.queue_free()
	end()


## Brock (WorldTrainer na sala do ginásio, papel "brock"): luta, insígnia, TM39.
func _brock_hook(npc: Node) -> bool:
	if is_running():
		return true
	await brock_battle(npc)
	return true


func brock_battle(npc: Node = null) -> Dictionary:
	await begin("brock")
	var def := Dex.trainer(BROCK)
	var p := player()
	if npc is Node3D and p:
		face_each_other(npc, p)
	if flag("badge_boulder"):
		await say("Brock", TrainerText.lines(BROCK, "after", def))
		end()
		return {}
	await say("Brock", TrainerText.lines(BROCK, "intro", def))
	var enemies := WorldTrainer.build_party(def)
	var opts := {"kind": "trainer", "trainer_id": BROCK, "can_run": false}
	if auto_battle:
		opts["autoplay"] = true
	opts.merge(battle_extra, true)
	var r: Dictionary = {}
	var ow := Overworld.of(self)
	if ow and not enemies.is_empty():
		r = await ow.battle(enemies, opts)
	last_battle = r
	if String(r.get("outcome", "")) == "win":
		await say("Brock", TrainerText.lines(BROCK, "defeat", def))
		await award_badge("boulder", "INSÍGNIA DA ROCHA")
		await say("Brock", TrainerText.lines(BROCK, "badge_speech", def))
		await say("Brock", TrainerText.lines(BROCK, "gift_speech", def).slice(0, 1))
		await give_item(String(def.get("gift", "tm39")), 1, "o TM39 (TUMBA DE PEDRAS)")
		await say("Brock", TrainerText.lines(BROCK, "gift_speech", def).slice(1))
	elif String(r.get("outcome", "")) == "lose":
		await say("Brock", ["Volte quando estiver mais preparado."])
	end()
	return r


## flags.badge_<id> (e <id>_badge, usado pelos gatilhos dos mapas) + mensagem.
func award_badge(id: String, label: String) -> void:
	set_flag("badge_" + id)
	set_flag(id + "_badge")
	var h := hud()
	if h:
		h.toast("%s obtida!" % label, 3.0)
	await say("", ["{PLAYER} recebeu a %s de Brock!" % label])


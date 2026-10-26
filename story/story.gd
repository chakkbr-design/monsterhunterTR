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
const TYPE_PT := {
	"grass": "Planta", "fire": "Fogo", "water": "Água", "poison": "Veneno", "normal": "Normal"
}
const LAB := "oak_lab"
## Quadra da 1ª luta com o rival: RIVAL_ARENA do original (story.gd), centrada no marcador
## "rival_battle" do lab (o RivalBattleSpot do Lab.tscn).
const RIVAL_ARENA := Vector2(10, 6.4)
## LabExitTrigger do original (13 x 0.6, faixa inteira antes da porta, oak_stopped e sem
## rival_battle_done). Aqui fica entre o spawn "door" (z 6.2) e o tapete de saída (z 7.1).
const LAB_EXIT_TRIGGER := {
	"node": "LabExitTrigger",
	"event": "lab_exit",
	"pos": [0.0, 6.8],
	"size": [13, 3, 0.4],
	"requires": ["oak_stopped"],
	"blocks": ["rival_battle_done"]
}
const MT_MOON_B2F := "mt_moon_b2f"
const MOON_CENTER := "pokemon_center_mt_moon"
const MAGIKARP_PRICE := 500
const SALESMAN := "Vendedor"
const LAB_SPAWN := "door"
## STARTER_QUESTIONS do original (story.gd:25-29).
const STARTER_QUESTIONS := {
	"Bulbasaur":
	"Entendi! Você escolheu o BULBASAUR.\nEle é muito fácil de criar.\nEntão, {PLAYER}, você quer ficar com\no POKéMON do tipo PLANTA, BULBASAUR?",
	"Charmander":
	"Ah! Você escolheu o CHARMANDER.\nCrie-o com paciência.\nEntão, {PLAYER}, você fica com o\nPOKéMON do tipo FOGO, CHARMANDER?",
	"Squirtle":
	"Hum! Você escolheu o SQUIRTLE.\nVale a pena criá-lo.\nEntão, {PLAYER}, você decidiu pelo\nPOKéMON do tipo ÁGUA, SQUIRTLE?",
}
## Ajudante do Oak na guarita sul da Floresta (Action.GIFT do original): HM05 com 10 espécies capturadas.
const AIDE_ROOM := "forest_gate_south"
const AIDE_ROLE := "aide_hm05"
const AIDE_CAUGHT := 10
## Velhinho acordado de Viridian (NPC_OldManAwake, Action.TUTOR do original): aula de captura.
const OLD_MAN_NODE := "NPC_OldManAwake"
const OLD_MAN_ZONE := "viridian_city"
const OLD_MAN_ROLE := "old_man"
## Pokédex na mesa do fundo do lab (Lab/Props/Pokedex* do original): somem quando o Oak entrega.
const DEX_PROPS := [Vector3(0.3, 0.88, -7.4), Vector3(0.9, 0.88, -7.4)]

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
static var _trigger_cache: Dictionary = {}  ## zona -> entradas de triggers tratadas
var _cover: ColorRect  ## fade para preto antes de uma luta numa quadra fixa


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
	# Conteúdo que o MapBuilder/InteriorRoom não constroem: cavernas, porta do Monte da Lua, estáticos.
	if n is WorldNpc and n.name == OLD_MAN_NODE and not n.has_meta("role"):
		# NPC do MapBuilder (sem papel): assim o gancho dos Interiores vale para ele.
		n.set_meta("interior", OLD_MAN_ZONE)
		n.set_meta("role", OLD_MAN_ROLE)
	if n is InteriorRoom and n.def.has("cave"):
		n.ready.connect(CaveBuilder.decorate.bind(n), CONNECT_ONE_SHOT)
	elif n is MapBuilder:
		n.built.connect(CaveBuilder.decorate_zone.bind(n), CONNECT_ONE_SHOT)
	if n is RouteWorld and n != world:
		# Só um jogo novo (spawn_request) chega sem equipe; aí o Overworld não semeia e o inicial vem do Oak.
		var seeded := (
			Game.party.is_empty() and not flag("got_starter") and not Game.spawn_request.is_empty()
		)
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
	# Uma cena presa no mundo anterior (já liberado) não pode travar o jogador no novo.
	_running = 0
	_current = ""
	_triggers.clear()
	_actors.clear()
	_balls.clear()
	location_kind = "zone"
	location_id = ""
	if w.has_signal("location_changed"):
		w.location_changed.connect(_on_location_changed)
	for zone in RouteWorld.ZONES if w is RouteWorld else []:
		for e in _zone_triggers(String(zone)):
			_add_trigger(w, e)
	if w.has_method("set_interact_hook"):
		w.set_interact_hook("player_house", "mom", _mom_hook)
		w.set_interact_hook("rival_house", "daisy", _daisy_hook)
		w.set_interact_hook(LAB, "aide_1", _lab_npc_hook)
		w.set_interact_hook(LAB, "aide_2", _lab_npc_hook)
		w.set_interact_hook(AIDE_ROOM, AIDE_ROLE, _aide_hook)
		w.set_interact_hook(OLD_MAN_ZONE, OLD_MAN_ROLE, _old_man_hook)
		w.set_interact_hook("mart_viridian", "clerk", _clerk_hook)
		w.set_interact_hook(GYM, BROCK, _brock_hook)
		w.set_interact_hook(MT_MOON_B2F, "miguel", _fossil_hook)
		w.set_interact_hook(MT_MOON_B2F, "dome_fossil", _fossil_hook)
		w.set_interact_hook(MT_MOON_B2F, "helix_fossil", _fossil_hook)
		w.set_interact_hook(MOON_CENTER, "salesman", _salesman_hook)
	_sync_location.call_deferred()


## Mamãe (NPC dos Interiores): antes do inicial só conversa; depois cura como NPC comum
## (Action.HEAL do original, sem cena própria). Devolve true quando a história tratou a conversa.
func _mom_hook(_npc: Node) -> bool:
	if is_running():
		return true
	if not flag("got_starter"):
		await begin("talk_mom")
		await say(MOM, StoryFlags.mom_lines(Game.flags))
		end()
		return true
	return false


## Margarida (Daisy do original, lines_for "Daisy"): a fala muda depois da luta com o rival.
func _daisy_hook(npc: Node) -> bool:
	if is_running():
		return true
	await begin("talk_daisy")
	await say(String(npc.get("npc_name")), StoryFlags.daisy_lines(Game.flags))
	end()
	return true


## Pesquisador-chefe (aide_1) e Assistente do lab (aide_2) com as falas do original; a do chefe
## muda depois do inicial.
func _lab_npc_hook(npc: Node) -> bool:
	if is_running():
		return true
	var role := String(npc.get_meta("role", ""))
	await begin("talk_" + role)
	await say(StoryFlags.lab_npc_name(role), StoryFlags.lab_npc_lines(Game.flags, role))
	end()
	return true


## Ajudante do Oak: fala e, com 10 espécies capturadas, dá o HM05 (falas novas depois disso).
func _aide_hook(npc: Node) -> bool:
	if is_running():
		return true
	await begin("talk_aide")
	var lines: PackedStringArray = (
		StoryFlags.aide_lines() if flag("hm05_flash") else PackedStringArray(npc.get("lines"))
	)
	await say(String(npc.get("npc_name")), lines)
	end()
	await aide_reward()
	return true


## aide_reward do original (story.gd:291-300).
func aide_reward() -> void:
	if is_running() or flag("hm05_flash") or Game.caught.size() < AIDE_CAUGHT:
		return
	await begin("aide_reward")
	await give_item("hm_flash", 1, "o HM05 Flash")
	set_flag("hm05_flash")
	end()


## Velhinho de Viridian: as falas do mapa e depois a aula (Action.TUTOR do original).
func _old_man_hook(npc: Node) -> bool:
	if is_running():
		return true
	var who := String(npc.get("npc_name"))
	await begin("talk_old_man")
	await say(who, PackedStringArray(npc.get("lines")))
	end()
	await old_man_lesson(who)
	return true


## old_man_lesson do original (story.gd:261-289): cartões de captura e a TEACHY TV.
func old_man_lesson(who := "Velhinho") -> void:
	if is_running():
		return
	await begin("old_man_lesson")
	if flag("old_man_lesson"):
		await say(
			who,
			[
				"Bem, agora já tomei meu café, e era disso que eu precisava para começar o dia!",
				"Mas fiz forte demais. Me deu dor de cabeça...",
				"Aliás, você está completando a sua POKéDEX?",
				"No começo, enfraqueça o POKéMON antes de tentar capturá-lo."
			]
		)
		end()
		return
	if not await ask("Quer que eu mostre como capturar Pokémon?"):
		await say(who, ["Ah... Bem, se precisar saber, volte quando quiser."])
		end()
		return
	for card in StoryFlags.CATCH_CARDS:
		await say(String(card[0]), [String(card[1])])
	await say(who, ["Pronto! Diga, isso foi educativo, não foi?", "E tome, leve isto também."])
	await give_item("teachy_tv", 1, "a TEACHY TV")
	await say(
		who,
		[
			"Se tiver alguma coisa que você não entenda, assista a ela.",
			"Ela ensina o básico de ser um TREINADOR POKéMON."
		]
	)
	set_flag("old_man_lesson")
	end()


func _clerk_hook(_npc: Node) -> bool:
	if is_running():
		return true
	if StoryFlags.interior_event(Game.flags, "mart_viridian") == "mart_parcel":
		await mart_parcel()
		return true
	return false


## Gatilhos tratados de uma zona; o JSON do mapa (até 230 KB) é lido uma vez só por sessão.
static func _zone_triggers(zone: String) -> Array:
	if not _trigger_cache.has(zone):
		_trigger_cache[zone] = MapBuilder.load_map(zone).get("triggers", []).filter(
			func(e): return HANDLED_EVENTS.has(String(e.get("event", "")))
		)
	return _trigger_cache[zone]


func _add_trigger(w: Node3D, e: Dictionary) -> void:
	var t := StoryTrigger.from_entry(e)
	if t.event == "oak_stop":
		# O Oak barra sempre que não há inicial (voltar do lab sem escolher também conta).
		t.blocks = PackedStringArray(["got_starter"])
		t.requires = PackedStringArray()
	elif t.event == "pewter_east_block":
		# Com a insígnia (qualquer um dos dois nomes de flag) a Rota 3 está aberta.
		t.blocks = PackedStringArray(["boulder_badge", "badge_boulder"])
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
		"mt_moon_fossils":
			if not flag(CaveBuilder.FOSSIL_FLAG):
				await mt_moon_fossils()
		"mt_moon_exit":
			await mt_moon_exit()
		"lab_exit":
			await lab_exit()


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
		await p.settle()  # grade: termina o passo em andamento, a cena começa no centro de um tile
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
		p.resnap()  # grade: volta ao centro de um tile livre se a cena o deixou fora
	cutscene_finished.emit(id)
	# cutscene.gd:36 do original: toda cena termina com SaveGame.autosave().
	if world and is_instance_valid(world) and Game.has_method("autosave"):
		Game.autosave(world)


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


## Anda até ficar a `gap` metros de `target`, de frente para ele. Nas zonas de grade o gap vira tiles
## inteiros (1 = vizinho), no eixo dominante, e o último trecho anda direto para o alvo.
func approach(actor: Node3D, target: Node3D, gap := 1.4) -> void:
	if actor == null or target == null:
		return
	var to := actor.global_position - target.global_position
	to.y = 0.0
	if to.length() < 0.01:
		to = Vector3(0, 0, 1)
	if GridMotion.grid_for(actor):
		var d := GridMotion.card(to)
		var at: Vector3 = (
			target.save_position() if target.has_method("save_position") else target.global_position
		)
		var cell := TileGrid.cell_of(at) + d * maxi(1, roundi(gap))
		await StoryNpc.move_node(
			actor, Vector3(cell.x, actor.global_position.y, cell.y), StoryNpc.WALK_SPEED, absi(d.y)
		)
	else:
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
	sfx("item_get")
	await say("", ["{PLAYER} recebeu %s!" % label])


# --- Som (contrato de sons do Audio; nada acontece se a faixa ou o efeito ainda não existe) ---


func sfx(id: String) -> void:
	var au := get_node_or_null("/root/Audio")
	if au and au.has_method("has_sfx") and au.has_sfx(id):
		au.sfx(id)


## Audio.push_music("story", ...) do original: troca a faixa enquanto a cena roda.
func push_music(track: String, fade := 0.3) -> void:
	var au := get_node_or_null("/root/Audio")
	if au and au.has_method("music_stream") and au.music_stream(track) != null:
		au.music(track, fade)


## Audio.pop_music("story") do original: volta para a faixa do lugar.
func pop_music(fade := 1.5) -> void:
	var au := get_node_or_null("/root/Audio")
	if au == null or not au.has_method("music"):
		return
	var zm := String(au.get("zone_music")) if au.get("zone_music") != null else ""
	if zm != "" and not bool(au.get("in_battle")):
		au.music(zm, fade)


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
		"oak": [OAK, Color(0.92, 0.92, 0.88)],
		"rival": ["{RIVAL}", Color(0.35, 0.3, 0.6)],
		"mom": [MOM, Color(0.85, 0.5, 0.6)],
		"clerk": [CLERK, Color(0.25, 0.45, 0.8)],
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
			var room: Node = world.interior(LAB) if world.has_method("interior") else null
			if room and room.get_node_or_null(String(LAB_EXIT_TRIGGER.node)) == null:
				room.add_child(StoryTrigger.from_entry(LAB_EXIT_TRIGGER))  # vive e morre com a sala
			if room and not flag("has_pokedex"):
				_add_dex_props(room)
			var left := StoryFlags.balls_left(f, Game.STARTERS)
			for i in Game.STARTERS.size():
				var sp: String = Game.STARTERS[i]
				if not left.has(sp) or ball(sp) != null:
					continue
				var b := StarterBall.new()
				b.species = sp
				b.name = "StarterBall_" + sp
				world.add_child(b)
				b.global_position = marker_pos(
					LAB, "ball_%d" % (i + 1), Vector3(i - 1.0, 0, -2) + marker_pos(LAB, "oak")
				)
				_balls[sp] = b
		"player_house":
			_ensure_role("mom", "player_house")
		"mart_viridian":
			_ensure_role("clerk", "mart_viridian")


## Duas Pokédex (caixinhas vermelhas) na mesa do fundo do lab, como os props Pokedex* do original.
func _add_dex_props(room: Node) -> void:
	for i in DEX_PROPS.size():
		var nm: String = ["PokedexA", "PokedexB"][i]
		if room.get_node_or_null(nm) != null:
			continue
		var mi := MeshInstance3D.new()
		mi.name = nm
		var bm := BoxMesh.new()
		bm.size = Vector3(0.28, 0.06, 0.38)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.82, 0.12, 0.14)
		bm.material = mat
		mi.mesh = bm
		room.add_child(mi)
		mi.position = DEX_PROPS[i]


func _remove_dex_props() -> void:
	var room: Node = world.interior(LAB) if world and world.has_method("interior") else null
	if room == null:
		return
	for nm in ["PokedexA", "PokedexB"]:
		var n := room.get_node_or_null(nm)
		if n:
			n.queue_free()


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
	push_music("oak")
	await say(OAK, ["Espere! Não vá lá fora!"])
	p.show_alert(false)
	var oak := spawn_npc(
		"oak_out", OAK, p.global_position + Vector3(0, 0, 6.0), Color(0.92, 0.92, 0.88)
	)
	p.face_toward(oak.global_position)
	await approach(oak, p, 1.4)
	await say(
		OAK,
		[
			"É perigoso! Pokémon selvagens vivem no mato alto!",
			"Você precisa do seu próprio Pokémon para se proteger.",
			"Já sei! Venha comigo!"
		]
	)
	var dest := oak.global_position + Vector3(0, 0, 3.0)
	oak.walk_to(dest)
	await walk(p, dest - Vector3(0, 0, 1.0))
	set_flag("oak_stopped")
	await _goto_interior(LAB, LAB_SPAWN)
	push_music("oak", 0.0)  # a porta troca para a faixa do lab; a do Oak segue até o fim da cena
	oak.queue_free()
	await lab_intro()
	pop_music()
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
	await say(
		OAK,
		[
			"{RIVAL}? Ah, é verdade, eu pedi para você vir. Espere um pouco!",
			"Aqui, {PLAYER}. Nessa mesa há três Pokémon, dentro das Poké Balls.",
			"Quando eu era jovem, fui um treinador sério.",
			"Agora só me restam esses três. Pode ficar com um. Vamos, escolha!"
		]
	)
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
	var sp := Dex.canon(b.species)
	var nm := String(Dex.species(sp).get("name", sp))
	if not StoryFlags.can_pick(Game.flags):
		# story.gd:354-359 do original.
		await begin("ball_locked")
		if flag("got_starter"):
			await say(
				"Poké Ball", ["É uma Poké Ball com %s dentro." % nm, "Ela espera outro treinador."]
			)
		else:
			await say("Poké Ball", ["São POKé BALLS.\nTem POKéMON dentro delas!"])
		end()
		return
	await begin("pick_starter")
	Game.mark_seen(sp)  # o cartão já registra a espécie como vista, mesmo com NÃO
	var q: String = STARTER_QUESTIONS.get(
		sp, "Então, {PLAYER}, você quer %s, o Pokémon do tipo %s?" % [nm, type_label(sp)]
	)
	var yes := await ask(q, sp)
	if not yes:
		end()
		return
	Game.choose_starter(sp)
	set_flag("got_starter")
	set_flag("starter_chosen")
	b.take()
	await say("", ["{PLAYER} recebeu %s do Prof. Carvalho!" % nm])
	await say(OAK, ["Este POKéMON é mesmo cheio de energia!"])
	var rsp := String(Game.flags.get("rival_starter", ""))
	var rival := actor("rival")
	var rb := ball(rsp)
	if rival and rb:
		await say("{RIVAL}", ["Então eu fico com este!"])
		await approach(rival, rb, 0.9)
		rb.take()
	await say(
		"", ["{RIVAL} recebeu %s do Prof. Carvalho!" % String(Dex.species(rsp).get("name", rsp))]
	)
	end()


## 2c. Saída do laboratório (LabExitTrigger do original): sem inicial o Oak segura o jogador;
## com ele, o rival desafia na hora de sair (como o original e o FRLG, não logo depois da escolha).
func lab_exit() -> void:
	if flag("rival_battle_done"):
		return
	if not flag("got_starter"):
		await begin("lab_exit")
		await say(OAK, ["Ei! Não vá embora ainda!"])
		var p := player()
		if p:
			await walk(p, p.global_position + Vector3(0, 0, -1.5))
		end()
		return
	await rival_battle()


## 2d. Primeira luta com o rival (inicial dele no Nv5). Ganhar ou perder, a história segue.
## Como o original: os dois se viram, fade, o jogador vai para a ponta oeste da quadra do lab e o
## rival para a leste (BattleArena com opts.center/arena); depois da luta todos ficam onde estão.
func rival_battle() -> void:
	await begin("rival_battle")
	var p := player()
	var rival := actor("rival")
	if rival == null and p:
		rival = _spawn_role("rival", door_pos(LAB, p.global_position + Vector3(0, 0, 4)))
	if rival and p:
		face_each_other(rival, p)
	await say("{RIVAL}", ["Espere, {PLAYER}! Vamos ver qual Pokémon é mais forte!"])
	# story.gd:437-445 do original: com "dicas de batalha", na 1ª vez o Oak vai até a borda da quadra
	# e avisa que vai ensinar; a lição em si é o battle_tutorial.gd (opts.tutorial).
	var oak := actor("oak")
	if teaches_lesson() and oak:
		var c := marker_pos(LAB, "rival_battle", p.global_position if p else Vector3.ZERO)
		await oak_take_lesson_spot(oak, c)
		await say(
			OAK,
			[
				"{RIVAL} está sempre com tanta pressa.",
				"{PLAYER}, esta é a sua primeira batalha.\nDeixe-me mostrar como se faz."
			]
		)
	var enemies: Array = []
	for e in StoryFlags.first_rival_party(Game.flags):
		enemies.append(Mon.create(String(e[0]), int(e[1])))
	var tflag := "trainer_" + StoryFlags.RIVAL_TRAINER
	var had_tflag := Game.flags.has(tflag)
	var opts := {
		"kind": "trainer",
		"trainer_id": StoryFlags.RIVAL_TRAINER,
		"trainer_class": "rival",  # prêmio 35 x nível, como o original (não o da Rota 22)
		"can_run": false,
		"scripted": true,
		"tutorial": true  # BattleTutorial.new() do original: sempre, ele decide lição ou cartões
	}
	var spot = world.marker(LAB, "rival_battle") if world and world.has_method("marker") else null
	if spot is Node3D:
		opts["center"] = (spot as Node3D).global_position
		opts["arena"] = RIVAL_ARENA
	if rival:
		opts["trainer_node"] = rival
	if auto_battle:
		opts["autoplay"] = true
	opts.merge(battle_extra, true)
	var r: Dictionary = {}
	var ow := Overworld.of(self)
	if ow and not enemies.is_empty():
		await fade_out()
		r = await ow.battle(enemies, opts)
		uncover()
	last_battle = r
	# A vitória aqui não conta como vencer o rival da Rota 22.
	if not had_tflag:
		Game.flags.erase(tflag)
	var outcome := String(r.get("outcome", "win"))
	set_flag("rival_battle_done")
	set_flag("rival_battle_won", outcome == "win")
	if outcome == "win":
		await say("{RIVAL}", ["O quê? Não acredito! Escolhi o Pokémon errado!"])
	else:
		await say("{RIVAL}", ["Isso! Meu Pokémon é demais!"])
	# story.gd:475-484 do original: o Oak fala, cura com fade no próprio lab e o rival sai.
	await say(
		OAK,
		[
			"Se um POKéMON selvagem aparecer, o seu POKéMON pode lutar com ele.",
			"Com ele ao seu lado, você deve conseguir chegar à próxima cidade."
		]
	)
	await heal_with_fade()
	push_music("rival")
	await say(
		"{RIVAL}",
		["Vou treinar meu Pokémon e ficar ainda mais forte.", "{PLAYER}! Vovô! Até mais!"]
	)
	if rival:
		await walk(rival, door_pos(LAB, rival.global_position + Vector3(0, 0, 6)))
		rival.queue_free()
	pop_music()
	end()


## `teaches` do original (story.gd:437): dicas de batalha ligadas, sem autoplay, lição ainda não dada.
func teaches_lesson() -> bool:
	var st = load("res://ui/front/settings.gd")
	var tips: bool = bool(st.load_cfg().get("battle_tips", true)) if st else true
	return (
		tips
		and not auto_battle
		and not Game.flags.has("tut_battle_lesson")
		and not flag("rival_battle_done")
	)


## _oak_lesson_spot do original: canto de cima à direita da quadra, 0.7 m para fora no X e 1 m no Z.
static func oak_lesson_spot(centre: Vector3) -> Vector3:
	return centre + Vector3(RIVAL_ARENA.x * 0.5 + 0.7, 0, -(RIVAL_ARENA.y * 0.5 + 1.0))


## _oak_take_lesson_spot do original: anda primeiro no X (na linha em que está), depois até o ponto,
## e se vira para o centro da quadra.
func oak_take_lesson_spot(oak: Node3D, centre: Vector3) -> void:
	var top := oak_lesson_spot(centre)
	await walk(oak, Vector3(top.x, oak.global_position.y, oak.global_position.z))
	await walk(oak, top)
	if oak.has_method("face"):
		oak.face(centre)


## Game.heal_with_fade do original: pela RouteWorld (fade, cura, mensagem, jingle) quando existe.
func heal_with_fade() -> void:
	if world and is_instance_valid(world) and world.has_method("heal_with_fade"):
		await world.heal_with_fade()
		return
	Game.heal_party()
	var h := hud()
	if h:
		h.toast("Seu time foi curado!", 1.8)
	sfx("heal")


## Ida do fade do original antes de trocar os treinadores de lugar (Transitions.fade 0 -> 1 em
## 0.25 s); a arena faz a volta. O preto sai quando a luta começa (ou em uncover()).
func fade_out(secs := 0.25) -> void:
	if not is_inside_tree():
		return
	if _cover == null:
		var cl := CanvasLayer.new()
		cl.layer = 41
		add_child(cl)
		_cover = ColorRect.new()
		_cover.color = Color(0, 0, 0, 0)
		_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cl.add_child(_cover)
	var tw := create_tween()
	tw.tween_property(_cover, "color:a", 1.0, secs)
	await tw.finished
	if not Game.battle_started.is_connected(uncover):
		Game.battle_started.connect(uncover, CONNECT_ONE_SHOT)


func uncover() -> void:
	if Game.battle_started.is_connected(uncover):
		Game.battle_started.disconnect(uncover)
	if _cover:
		_cover.color.a = 0.0


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
	await say(
		CLERK,
		["Você conhece o Prof. Carvalho, não é? A encomenda dele chegou.", "Pode levar para ele?"]
	)
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
	await say(
		OAK,
		[
			"Ah, {PLAYER}! Como vai o meu velho POKéMON?",
			"Bem, parece que ele está cada vez mais apegado a você.",
			"Você deve ter talento como TREINADOR POKéMON.",
			"O que é isso? Você tem algo para mim?"
		]
	)
	Game.take_item(StoryFlags.PARCEL)
	set_flag("has_parcel", false)
	await say("", ["{PLAYER} entregou a ENCOMENDA DO PROF. CARVALHO."])
	await say(OAK, ["Ah! É a POKé BALL especial!", "Eu tinha encomendado. Obrigado!"])
	push_music("rival")
	var rival := actor("rival")
	if rival == null:
		rival = _spawn_role(
			"rival", door_pos(LAB, p.global_position + Vector3(0, 0, 4) if p else Vector3.ZERO)
		)
	if p:
		await approach(rival, p, 1.4)
	await say("{RIVAL}", ["Quase esqueci!", "Para que você me chamou?"])
	await say(
		OAK,
		[
			"Ah, sim! Tenho um pedido para vocês dois.",
			"Ali na mesa está a minha invenção, a POKéDEX!",
			"Ela registra sozinha os dados dos POKéMON que você vir ou capturar.",
			"É uma enciclopédia de alta tecnologia!",
			"{PLAYER} e {RIVAL}, levem estas com vocês."
		]
	)
	await give_item(StoryFlags.POKEDEX, 1, "a POKéDEX do PROF. CARVALHO")
	set_flag("has_pokedex")
	_remove_dex_props()
	await say(
		OAK,
		[
			"Só de ver um POKéMON não dá para ter dados detalhados sobre ele.",
			"É preciso capturá-lo para ter os dados completos.",
			"Então, aqui estão algumas ferramentas para capturar POKéMON selvagens."
		]
	)
	await give_item("poke_ball", StoryFlags.DEX_BALLS, "%d POKé BALLS" % StoryFlags.DEX_BALLS)
	await say(
		OAK,
		[
			"Fazer um guia completo de todos os POKéMON do mundo...",
			"Esse era o meu sonho!",
			"Mas estou velho demais. Não consigo mais fazer isso.",
			"Então quero que vocês dois realizem o meu sonho por mim.",
			"Vão, vocês dois.",
			"Esta é uma grande empreitada na história dos POKéMON!"
		]
	)
	push_music("rival")
	await say(
		"{RIVAL}",
		[
			"Pode deixar, vovô! Deixe tudo comigo!",
			"{PLAYER}, sinto dizer, mas você não vai ser necessário.",
			"Já sei! Vou pegar um MAPA DA CIDADE emprestado com a minha irmã!",
			"Vou dizer a ela para não emprestar um para você, {PLAYER}! Hahaha!",
			"Nem se dê ao trabalho de passar lá em casa depois disso!"
		]
	)
	await walk(rival, door_pos(LAB, rival.global_position + Vector3(0, 0, 6)))
	rival.queue_free()
	pop_music()
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


## Saída leste de Pewter: sem a Insígnia da Rocha o garoto barra; com ela, a Rota 3 está aberta.
func pewter_east_block() -> void:
	if flag("badge_boulder") or flag("boulder_badge"):
		return
	await begin("pewter_east_block")
	var p := player()
	if p:
		p.show_alert(true)
	await say(
		"Garoto",
		[
			"Você não pode ir para o leste, até a Rota 3, sem a Insígnia da Rocha.",
			"Vença o Líder Brock no Ginásio de Pewter e depois volte!"
		]
	)
	if p:
		p.show_alert(false)
		await walk(p, p.global_position + Vector3(-3.0, 0, 0))
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
	var body := npc as Node3D
	var home := body.global_position if body else Vector3.INF
	var home_yaw := body.rotation.y if body else 0.0
	if body and p:
		face_each_other(body, p)
	if flag("badge_boulder"):
		await say("Brock", TrainerText.lines(BROCK, "after", def))
		end()
		return {}
	await say("Brock", TrainerText.lines(BROCK, "intro", def))
	var enemies := WorldTrainer.build_party(def)
	# A quadra do ginásio ("center" + "arena" do trainers.json) a arena acha sozinha; como no
	# original, o Brock vai para a ponta leste e volta para o lugar dele depois (_return_home).
	var opts := {"kind": "trainer", "trainer_id": BROCK, "can_run": false}
	if body:
		opts["trainer_node"] = body
	if auto_battle:
		opts["autoplay"] = true
	opts.merge(battle_extra, true)
	var r: Dictionary = {}
	var ow := Overworld.of(self)
	if ow and not enemies.is_empty():
		await fade_out()
		r = await ow.battle(enemies, opts)
		uncover()
	last_battle = r
	if String(r.get("outcome", "")) == "win":
		await say("Brock", TrainerText.lines(BROCK, "defeat", def))
		await award_badge("boulder", "INSÍGNIA DA ROCHA")
		await say("Brock", TrainerText.lines(BROCK, "badge_speech", def))
		await say("Brock", TrainerText.lines(BROCK, "gift_speech", def).slice(0, 1))
		await give_item(String(def.get("gift", "tm39")), 1, "o TM39 (TUMBA DE PEDRAS)")
		await say("Brock", TrainerText.lines(BROCK, "gift_speech", def).slice(1))
	# Derrota: o apagão da RouteWorld já levou o jogador ao ponto de cura; o original
	# (trainer.gd:168) não diz nada depois.
	if (
		is_instance_valid(body)
		and home.is_finite()
		and body.global_position.distance_to(home) > 0.2
	):
		await walk(body, home, 8.0)
		body.rotation.y = home_yaw
	end()
	return r


## flags.badge_<id> (e <id>_badge, usado pelos gatilhos dos mapas) + mensagem.
func award_badge(id: String, label: String) -> void:
	set_flag("badge_" + id)
	set_flag(id + "_badge")
	sfx("badge")  # Audio.jingle("music/badge_get") do trainer.gd:235 do original
	var h := hud()
	if h:
		h.toast("%s obtida!" % label, 3.0)
	await say("", ["{PLAYER} recebeu a %s de Brock!" % label])


# --- Monte da Lua ------------------------------------------------------------------------------------


## Nome de banner de um treinador (display_name do trainers.json, senão "<Classe> <Nome>").
static func trainer_name(id: String, def: Dictionary) -> String:
	return String(def.get("display_name", TrainerText.display_name(id, def)))


## Luta de treinador conduzida pela história (Miguel). Vitória grava trainer_<id>.
func _trainer_fight(id: String, def: Dictionary) -> Dictionary:
	var enemies := WorldTrainer.build_party(def)
	var opts := {"kind": "trainer", "trainer_id": id, "can_run": false}
	if auto_battle:
		opts["autoplay"] = true
	opts.merge(battle_extra, true)
	var r: Dictionary = {}
	var ow := Overworld.of(self)
	if ow and not enemies.is_empty():
		r = await ow.battle(enemies, opts)
	last_battle = r
	if String(r.get("outcome", "")) == "win":
		set_flag("trainer_" + id)
	return r


func b2f_npc(role: String) -> Node3D:
	if world == null or not world.has_method("interior"):
		return null
	var room = world.interior(MT_MOON_B2F)
	if room == null:
		return null
	var n = room.npcs.get(role)
	return n if n is Node3D and is_instance_valid(n) else null


## Miguel ou um dos fósseis (gancho dos Interiores): a cena dos fósseis; depois dela, a fala de sempre.
func _fossil_hook(npc: Node) -> bool:
	if is_running():
		return true
	if flag(CaveBuilder.FOSSIL_FLAG):
		if String(npc.get_meta("role", "")) == "miguel":
			await begin("talk_miguel")
			var def := Dex.trainer(CaveBuilder.MIGUEL)
			await say(
				trainer_name(CaveBuilder.MIGUEL, def),
				TrainerText.lines(CaveBuilder.MIGUEL, "after", def)
			)
			end()
		return true
	await mt_moon_fossils()
	return true


## Monte da Lua B2F: o Supernerd Miguel guarda dois fósseis. Vencido, ele divide: o jogador escolhe
## Domo ou Hélice (flags FLAG_GOT_<DOME|HELIX>_FOSSIL, FLAG_GOT_FOSSIL_FROM_MT_MOON, mt_moon_fossil).
func mt_moon_fossils() -> Dictionary:
	await begin("mt_moon_fossils")
	var id := CaveBuilder.MIGUEL
	var def := Dex.trainer(id)
	var who := trainer_name(id, def)
	var p := player()
	var miguel := b2f_npc("miguel")
	if miguel and p:
		face_each_other(miguel, p)
	var r: Dictionary = {}
	if not flag("trainer_" + id):
		await say(who, TrainerText.lines(id, "intro", def))
		r = await _trainer_fight(id, def)
		if String(r.get("outcome", "")) != "win":
			end()
			return r
		await say(who, TrainerText.lines(id, "defeat", def))
	await say(who, ["Vamos dividir: um fóssil para cada um!", "Nada de ganância!"])
	var took := ""
	for i in 8:
		if await ask("Você quer o FÓSSIL DOMO?"):
			took = "dome"
		elif await ask("Você quer o FÓSSIL HÉLICE?"):
			took = "helix"
		if took != "":
			break
	if took == "":
		took = "dome"
	var label := "FÓSSIL DOMO" if took == "dome" else "FÓSSIL HÉLICE"
	Game.add_item(took + "_fossil", 1)
	set_flag("FLAG_GOT_%s_FOSSIL" % took.to_upper())
	set_flag(CaveBuilder.FOSSIL_FLAG)
	set_flag("mt_moon_fossil", took)
	for role in ["dome_fossil", "helix_fossil"]:
		var f := b2f_npc(role)
		if f:
			f.queue_free()
	await say("", ["{PLAYER} recebeu o %s!" % label])
	await say(who, ["Tá bom. Então este fóssil aqui é meu!"])
	await say(who, TrainerText.lines(id, "after", def))
	end()
	return r


## Saída leste do B1F (Rota 4): a demo para aqui.
func mt_moon_exit() -> void:
	await begin("mt_moon_exit")
	var first := not flag("mt_moon_cleared")
	set_flag("mt_moon_cleared")
	var h := hud()
	if h and first:
		h.toast("Monte da Lua atravessado!", 3.0)
	await say(
		"",
		[
			"Lá fora, a Rota 4 desce em direção a Cerulean...",
			"A estrada ainda está bloqueada. Esta parte da aventura termina aqui.",
			"Continua..."
		]
	)
	var p := player()
	if p and world and world.has_method("interior"):
		var room = world.interior("mt_moon_b1f")
		if room and room.has_spawn("warp_7"):
			# Um passo de volta para dentro, fora do gatilho.
			var back: Vector3 = room.spawn_point("warp_7")
			var at := p.global_position
			await walk(p, at + (back - at).normalized() * 1.6)
	end()


## Vendedor de Magikarp do Centro Pokémon do Monte da Lua (P500, uma vez).
func _salesman_hook(_npc: Node) -> bool:
	if is_running():
		return true
	await magikarp_sale()
	return true


func magikarp_sale() -> void:
	await begin("magikarp_sale")
	if flag("bought_magikarp"):
		await say(SALESMAN, ["Eu já vendi um MAGIKARP para você!", "Cuide bem dele!"])
		end()
		return
	if Game.money < MAGIKARP_PRICE:
		await say(SALESMAN, ["Desculpe, garoto. Você não tem ₽%d." % MAGIKARP_PRICE])
		end()
		return
	await say(SALESMAN, ["Ei, você aí! Tenho uma oferta imperdível!"])
	if not await ask("Vendo um MAGIKARP por apenas ₽%d. Fechado?" % MAGIKARP_PRICE, "Magikarp"):
		await say(SALESMAN, ["Que pena. É uma pechincha de verdade!"])
		end()
		return
	Game.money -= MAGIKARP_PRICE
	Game.add_mon(Mon.create("magikarp", 5))
	set_flag("bought_magikarp")
	await say(SALESMAN, ["Aqui está!"])
	await say(
		"",
		[
			(
				"{PLAYER} recebeu o MAGIKARP!"
				+ (
					""
					if (
						Game.party.size() <= Game.PARTY_MAX
						and Game.party.back().species.to_lower() == "magikarp"
					)
					else " Ele foi para o PC."
				)
			)
		]
	)
	end()

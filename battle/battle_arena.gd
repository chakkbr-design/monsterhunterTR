extends Node3D
## Arena de batalha em tempo real. Contrato: start(player_party, enemies, opts) e signal finished(result).
## opts: {kind: "wild"|"trainer", trainer_id?, can_run?, auto_battle? (padrão true: IA luta pelo jogador,
##        que ainda usa bolsa/bola/troca/pausa), autoplay? (IA e sem jogador: confirmações passam sozinhas),
##        player_think_scale?, player_item?, enemy_think_scale? (ajustes da IA por lado),
##        no_rewards? (sem XP, EVs, prêmio nem evolução), seed?, speed?,
##        battle_size? (selvagem 2 = 2x1 com aliado IA; treinador sempre 1), trainer_item?, game? (bolsa injetada),
##        center? (Vector3 global: quadra num lugar certo), arena? (Vector2 [w, d]), trainer_node? (Node3D),
##        arena_color? (Color), tutorial? (bool: cartões de dica e lição da 1ª luta, battle_tutorial.gd),
##        training? (bool: luta de treino do acampamento), card? (textura do boneco)}.
## Quadra num lugar certo (o original: Battle.start_trainer_battle com opts.center; trainers.json "center"
## + "arena" no ginásio): ver _setup_court.
## Com `manual = true` nada anda sozinho: quem chama step(dt) (testes headless).

signal finished(result: Dictionary)
## Eventos que o tutorial ouve (o original: Game.battle_started, Moves.move_used, Moves.hit_landed).
signal fight_started
signal move_used(user: BattleFighter, mv: Dictionary)
signal hit_landed(user: BattleFighter, target: BattleFighter, mv: Dictionary)
## Batalha Viva (medidas do treino): esquiva. what = "body" (saiu de lado da investida), "area"
## (saiu da área/raio/projétil avisado), "jump" (pulou), "evasion" (errou pela evasão), "under"
## (a investida passou por baixo de quem estava no ar).
signal dodged(f: BattleFighter, what: String)

const ARENA_SIZE := 12.0
const START_GAP := 6.0
const WILD_OPENING_DELAY := 0.5
const TRAINER_SWAP_HOLD := 0.5
const INTRO_TIME := 1.2
const DEFAULT_SPEED := 0.6  ## original Settings "Slow" (the default battle speed)
const FAINT_CLEAR := 1.0
const NEXT_TRAINER_MON := 1.4
const SWAP_CD := 1.0
## Folga no começo da rodada quando alguém trocou (a bola voltando e saindo) antes do 1º golpe.
const SWITCH_HOLD := 1.0
const CAM_DIST := 5.0
const CAM_HEIGHT := 3.4
const BALL_FLIGHT := 0.5
const BALL_SHAKE := 0.6
const BALL_ABSORB := 0.3
const ARENA_LINE := Color(1.0, 0.86, 0.45, 0.9)
const BALL_ORDER := ["poke_ball", "great_ball", "ultra_ball"]
const LOG_MAX := 400
const BATTLE_SIZE := 2
const ITEM_CD := 3.0
const SUPPORT_HEAL_AT := 0.5
const MODAL_SLOW := 0.2
const CONTROL_SWAP_CD := 0.3
## Comandos por Pokémon (BattleAI.ATTACK/DEFEND/SUPPORT/FREE): F muda o do aliado, G o do controlado.
const ALLY_MODE_NAMES := ["OFENSIVO", "DEFENSIVO", "SUPORTE", "LIVRE"]
const ALLY_MODE_COLORS := [
	Color(1.0, 0.5, 0.4), Color(0.5, 0.75, 1.0), Color(0.55, 1.0, 0.6), Color(0.85, 0.85, 0.85)
]
## O comando chega ao Pokémon depois de um tempo pela amizade (0,8 s com 0, 0,3 s com 255); amizade
## baixa às vezes ignora ("?") e só obedece depois de CMD_IGNORE_SECS. Novo comando só depois de CMD_CD.
const CMD_DELAY_MAX := 0.8
const CMD_DELAY_MIN := 0.3
const CMD_CD := 1.2
const CMD_IGNORE_SECS := 2.0
## Amizade ganha por vencer (cada participante de pé) e por obedecer um comando.
const FRIEND_WIN := 3
const FRIEND_OBEY := 1
## Cena de impacto (KO, combo, crítico supereficaz): a luta congela por CUT_IN_SECS, no máx. 1 a cada CUT_IN_GAP.
const CUT_IN_SECS := 0.4
const CUT_IN_GAP := 2.5
## Dupla de treinador: distância lateral entre os dois mons de cada lado.
const DOUBLES_GAP := 1.8
const BATTLE_ITEM_CATEGORIES := ["medicine", "berries"]
## Quadra fixa, valores do original (battle.gd start_trainer_battle / start_battle, battle_arena.gd):
## sem `arena` o tamanho é 10 x 6; os treinadores ficam 0.3 m fora da borda no eixo X (jogador a oeste);
## o 1º mon do adversário cai a 40% do caminho até ele e o do jogador 1.5 m à frente do jogador.
const FIXED_ARENA := Vector2(14, 8)
const TRAINER_STAND_OFF := 0.3
const FOE_THROW := 0.4
const LEAD_STEP := 1.5
const FIXED_FADE := 0.25
## Câmera de batalha do original nas salas: rig das salas (pitch 30°, fov 30°) parado no meio entre o
## treinador e o mon do adversário, a 12 + 2 m.
const FIXED_CAM_DIST := 14.0
const FIXED_CAM_PITCH := deg_to_rad(30.0)
const FIXED_CAM_FOV := 30.0
## Corpo do mon contra paredes e móveis (o original: CharacterBody3D, cápsula r 0.35, camadas 1|2).
const BODY_R := 0.35
const SOLID_MASK := 1
## Abertura do treinador (o original: "<NOME> wants to battle!" por 1.2 s antes de jogar a bola).
const TRAINER_CHALLENGE := 1.2
## Troca do treinador (o original: "Come back" e recolhe em Game.RECALL_SECS; "is about to send out" 1.4 s).
const RECALL_SECS := 0.45
## Resultado do fim (o original _results_sequence): auto-avanço sem jogador; tempo de encher um nível de EXP.
const RESULT_AUTO := 0.35
const EXP_LEVEL_SECS := 0.7
## Velocidade da batalha das opções (o original: Lento 0.6x, o padrão; Rápido 1.0x).
const BATTLE_SPEEDS := [0.6, 1.0]
const SETTINGS := "res://ui/front/settings.gd"
const TUTORIAL := preload("res://battle/battle_tutorial.gd")
## Evolução no meio da luta (progression.gd check_evolutions, a cada 0,4 s): o controlado que já pode
## evoluir evolui no próprio sprite com a luta parada (Battle.pause_for_evolution).
const EVO_CHECK := 0.4
const EVOLUTION := "/root/Evolution"

var manual := false
var rng := RandomNumberGenerator.new()
var moves: BattleMoves
var combos: BattleCombos  ## marcas de tipo, reações, golpes de dupla, Sintonia
var field: BattleField  ## terreno que muda, objetos, clones
var abilities: BattleAbilities  ## efeitos das habilidades
var turns: BattleTurns  ## rodadas pela Speed (fila de quem solta golpe)
var end_turn: BattleEndTurn  ## efeitos de fim de turno, uma vez por rodada
## IA do treinador por lado (BattleTrainerAI, opcional): round_start() no começo da rodada e
## pick_replacement(slot) -> índice de bench_of(side) (-1 = a arena escolhe).
var trainer_ai := {}
## Pedidos para o começo da próxima rodada: troca {side: {out, mon}} e itens [{side, item, target}].
var _switch_req := {}
var _item_req: Array = []
## Substituições de quem desmaiou, feitas no fim da rodada (como no oficial).
var _round_end_q: Array = []
var _turn_mark: Node3D  ## anel + seta brilhando em quem é o próximo da fila
var _turn_pulse := 0.0
var hud: BattleHUD
var vfx: BattleVfx
var fight_speed := DEFAULT_SPEED
var opts := {}
var kind := "wild"
var party: Array = []
var enemies: Array = []
var enemy_index := 0
var player: BattleFighter  # o mon que o jogador controla
var ally: BattleFighter  # 2º mon do jogador (IA), só em batalha selvagem
var ally_mode := 3  # comando do aliado: BattleAI.ATTACK / DEFEND / SUPPORT / FREE
var player_mode := 3  # comando do controlado (na batalha automática)
## Sem ninguém no teclado (autoplay, treino) os dois lados trocam de comando sozinhos (BattleAI._auto_command).
var auto_commands := false
var obey := {"player": true, "ally": true}
var _cmd_cd := {"player": 0.0, "ally": 0.0}
## Golpes avisados no chão para a IA desviar: {id, kind "disc"|"line", side, t, at, r | from, dir, len, w}.
var telegraphs: Array = []
var _tele_n := 0
var _cut_t := 0.0
var _cut_gap := 0.0
## 2x2 de treinador: os dois lados com dois em campo; enemy2 é o 2º do adversário.
var doubles := false
## Escala do dano final (ritmo da luta; BattleMoves.DAMAGE_PACE).
var damage_pace := BattleMoves.DAMAGE_PACE
var enemy2: BattleFighter
var _pending: Array = []  ## Mons do jogador já chamados para entrar (ainda não em campo)
var _enemy_pending := 0
var _enemy_reserved: Array = []  ## Mons do adversário já chamados para entrar (substituição)
var item_cd := 0.0  # cooldown global de itens (bolsa rápida e cura do SUPPORT)
var menu := ""  # "" | "bag" | "party" (abre com interact; a luta fica a MODAL_SLOW)
var menu_sel := 0
var menu_target := 0
var enemy: BattleFighter
var fighters: Array = []
var projectiles: Array = []
var state := "idle"
var result := {}
var exp_log: Array = []
var log_lines: Array = []
var hits := 0
var hit_dmg := 0  # soma do dano dos golpes (teste de ritmo)
var rect := Rect2(-ARENA_SIZE * 0.7, -ARENA_SIZE / 2.0, ARENA_SIZE * 1.4, ARENA_SIZE)
var fixed := false  ## quadra num lugar certo (opts.center ou "center" do trainers.json)
## Luta de treino (Battle.training do original): o selvagem é um boneco parado e imortal no nível do
## controlado, cada KO dá os EVs dele a quem acertou, bola não pega e só termina com FUGIR.
var training := false
var axis := Vector3(0, 0, -1)  ## do lado do jogador para o do adversário
var player_spot := Vector3(0, 0, START_GAP / 2.0)  ## onde cai o 1º mon do jogador (local)
var enemy_spot := Vector3(0, 0, -START_GAP / 2.0)  ## onde o adversário joga os mons (local)

var _state_t := 0.0
var _end_delay := 0.0
var _events: Array = []
var _fx: Array = []
var _participants := {}
var _cam: Camera3D
var _prev_cam: Camera3D
var _yaw := 0.0
var _swap_cd := 0.0
var _capture := {}
var _think_scale := 1.0
var _trainer_item := ""
var _battle_size := 1
var _f_was_down := false
var _built := false
var _court_color := ARENA_LINE
var _cam_focus := Vector3.ZERO  ## câmera parada (quadra fixa): ponto que ela olha
var _probe: PhysicsShapeQueryParameters3D
## Pausa da batalha (Esc; o original: pause_menu.gd _battle_items com a luta parada).
var pause_open := false
var pause_sel := 0
## Sequência de resultado do fim (EXP, nível, golpes, prêmio), um passo por vez.
var _results: Array = []
var _beat := {}
var _last_exp: Array = []
var _xp_shown := -1.0
var _xp_level := 0
var _revealed := true
## opts.out (índices da equipe fora da bola, que o Game passa): o líder é quem está fora, o aliado da
## selvagem só sai de quem já está fora (battle.gd:316-327 do original). Sem opts.out (testes da arena)
## vale o jeito antigo: o 2º saudável entra como aliado.
var _track_out := false
var _out: Array = []  ## Mons fora da bola agora; vai em result.out_mons
## Amizade perdida ao desmaiar (Game.FAINT_LOSS, battle.gd:1251 do original).
const FAINT_LOSS := 20
## Trava da lição do tutorial (battle.gd do original): só o golpe tut_move, andar só com tut_walk,
## a IA parada com tut_hold_foe.
var tut_locked := false
var tut_move := -1
var tut_walk := false
var tut_hold_foe := false
var tutorial: Node
## Tela Evolution tocando no lutador controlado (não nulo = luta parada) e o lutador.
var _evo: Node = null
var _evo_f: BattleFighter = null
var _evo_check_t := 0.0


func _physics_process(delta: float) -> void:
	if not manual:
		step(delta)


func _notification(what: int) -> void:
	# Arena liberada no meio da luta: solta os efeitos (StreamEmitter <-> BattleVfx é um ciclo de RefCounted).
	if what == NOTIFICATION_PREDELETE and vfx:
		vfx.nodes.clear()


func start(player_party: Array, enemy_list: Array, o: Dictionary) -> void:
	opts = o
	party = player_party
	enemies = enemy_list
	kind = String(o.get("kind", "wild"))
	training = kind == "wild" and bool(o.get("training", false))
	fight_speed = float(o.get("speed", _settings_speed()))
	if o.has("seed"):
		rng.seed = int(o.seed)
	else:
		rng.randomize()
	moves = BattleMoves.new(self, rng)
	combos = BattleCombos.new(self)
	field = BattleField.new(self)
	abilities = BattleAbilities.new(self)
	turns = BattleTurns.new(self, bool(o.get("turn_mode", true)))
	end_turn = BattleEndTurn.new(self)
	if kind == "trainer":
		var tr := Dex.trainer(String(o.get("trainer_id", "")))
		_think_scale = float(tr.get("ai_think_scale", 1.0))
		_trainer_item = String(o.get("trainer_item", tr.get("item", "")))
	_think_scale = float(o.get("enemy_think_scale", _think_scale))
	# Selvagem: até BATTLE_SIZE mons do jogador (2x1). Treinador: 2x2 com "doubles" no trainers.json
	# (o ginásio sempre) ou opts.battle_size 2 (treino); senão 1x1.
	if kind == "wild":
		_battle_size = clampi(int(o.get("battle_size", BATTLE_SIZE)), 1, BATTLE_SIZE)
	else:
		var tr2 := Dex.trainer(String(o.get("trainer_id", "")))
		var want := int(o.get("battle_size", 2 if bool(tr2.get("doubles", false)) else 1))
		_battle_size = clampi(want, 1, BATTLE_SIZE)
	if kind == "trainer" and _battle_size >= 2:
		# Dupla só com dois de pé do lado do jogador; senão é 1x1 (o adversário manda um por vez).
		var up := party.filter(func(m): return not m.is_fainted()).size()
		var foes := enemy_list.filter(func(m): return not m.is_fainted()).size()
		if up < 2 or foes < 2:
			_battle_size = 1
	doubles = kind == "trainer" and _battle_size >= 2
	# Na dupla cada um apanha de dois: o dano anda mais devagar para o Pokémon durar o mesmo tanto.
	var pace_def := BattleMoves.DAMAGE_PACE * (BattleMoves.DOUBLES_PACE if doubles else 1.0)
	damage_pace = float(o.get("damage_pace", pace_def))
	auto_commands = bool(o.get("auto_commands", o.get("autoplay", false)))
	if not InputMap.has_action("move_1"):
		load("res://core/controls.gd").register()
	_setup_court(o)
	_build()
	field.setup()
	clear_tut_lock()
	# A lição e os cartões ensinam as teclas de golpe: não valem com a batalha automática.
	if bool(o.get("tutorial", false)) and _player_ctrl() != "ai" and tutorial == null:
		tutorial = TUTORIAL.new(self)
		add_child(tutorial)
	_track_out = o.get("out") is Array
	_out = []
	if _track_out:
		for i in o.out:
			if int(i) >= 0 and int(i) < party.size():
				_out.append(party[int(i)])
	var pi := _lead_index() if _track_out else _next_healthy(-1)
	var ei := _next_enemy(-1)
	if pi < 0 or ei < 0:
		_end("lose" if pi < 0 else "win", 0.0)
		return
	if _track_out and kind != "wild":
		# Treinador: os outros fora da bola voltam para ela (start_trainer_battle do original).
		_out = _out.filter(func(m): return m == party[pi])
	var lat := _lateral()
	_send_player(pi, player_spot - lat * (DOUBLES_GAP * 0.5 if doubles else 0.0))
	if _battle_size >= 2:
		var ai_i := _out_ally(pi) if _track_out and not doubles else _next_healthy(pi)
		if ai_i >= 0:
			var at := (
				player_spot + lat * DOUBLES_GAP * 0.5
				if doubles
				else player_spot + Vector3(1.6, 0, 0.4)
			)
			_send_ally(ai_i, _nearest_free(at) if fixed else at)
	_send_enemy(ei, 0)
	if doubles:
		var ei2 := _next_enemy(ei)
		if ei2 >= 0:
			_send_enemy(ei2, 1)
	var e: Mon = enemies[ei]
	if kind == "wild":
		hud.banner("Um %s selvagem apareceu!" % e.display_name, INTRO_TIME)
	else:
		# Como o original: primeiro o desafio, depois a bola com o 1º Pokémon.
		_revealed = false
		enemy.visible = false
		if is_instance_valid(enemy2):
			enemy2.visible = false
		hud.banner("%s quer lutar!" % trainer_name(), TRAINER_CHALLENGE)
	state = "intro"
	_state_t = 0.0
	hud.intro_bars(true)
	_update_camera(1.0)


## Velocidade das opções (battle_speed 0 = Lento 0.6x, 1 = Rápido 1.0x) quando opts não traz speed.
static func _settings_speed() -> float:
	if not ResourceLoader.exists(SETTINGS):
		return DEFAULT_SPEED
	var st = load(SETTINGS)
	var cfg: Dictionary = st.load_cfg() if st else {}
	var i := clampi(int(cfg.get("battle_speed", 0)), 0, BATTLE_SPEEDS.size() - 1)
	return float(BATTLE_SPEEDS[i])


## Nome de exibição do treinador ("Caçador de Insetos Rick", "Líder Brock", o nome do rival).
func trainer_name() -> String:
	if opts.has("trainer_name"):
		return String(opts.trainer_name)
	var id := String(opts.get("trainer_id", ""))
	var def := Dex.trainer(id)
	if def.is_empty():
		return "O treinador"
	var n := TrainerText.display_name(id, def)
	var g := _game()
	if g and g.has_method("fill_names"):
		n = g.fill_names(n)
	return n.replace("{RIVAL}", "Rival")


# --- Montagem ---


func _build() -> void:
	if _built:
		return
	_built = true
	_build_court()
	vfx = BattleVfx.new(self)
	_prev_cam = get_viewport().get_camera_3d() if is_inside_tree() else null
	_cam = Camera3D.new()
	_cam.fov = FIXED_CAM_FOV if fixed else 60.0
	if _prev_cam:
		# Mesmo alcance e atributos da câmera do mundo (far curto do streaming, exposição/DOF).
		_cam.far = _prev_cam.far
		_cam.attributes = _prev_cam.attributes
	add_child(_cam)
	_cam.make_current()
	hud = BattleHUD.new()
	add_child(hud)


## Quadra do original (battle_arena.gd): quadrado dourado com cantos marcados, sobre o chão do mundo.
## Em cena sem chão (opts.floor = true) põe também um piso.
func _build_court() -> void:
	if bool(opts.get("floor", false)):
		var floor_mi := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = rect.size + Vector2(8.0, 8.0)
		var fm := StandardMaterial3D.new()
		fm.albedo_color = Color(0.42, 0.58, 0.33)
		pm.material = fm
		floor_mi.mesh = pm
		add_child(floor_mi)
	var quad := MeshInstance3D.new()
	quad.name = "ArenaQuad"
	var qm := PlaneMesh.new()
	qm.size = rect.size
	quad.mesh = qm
	quad.position = Vector3(rect.get_center().x, 0.04, rect.get_center().y)
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _court_texture()
	mat.albedo_color = _court_color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.render_priority = -1
	quad.material_override = mat
	add_child(quad)


## Quadra num lugar certo, como o original com opts.center (Battle.start_trainer_battle sem plan):
## laboratório = RivalBattleSpot 10 x 6.4 (story.gd), ginásio = "center"/"arena" do trainers.json.
## A arena vai para o centro, eixo X (jogador a oeste, adversário a leste, max(w, d)/2 + 0.3 do centro);
## o jogador e o treinador do mundo trocam de lugar sob um fade; os mons caem no ponto livre mais perto.
func _setup_court(o: Dictionary) -> void:
	if not is_inside_tree():
		return
	var def := Dex.trainer(String(o.get("trainer_id", ""))) if kind == "trainer" else {}
	var c = o.get("center")
	if not (c is Vector3):
		c = _marker_center(String(def.get("center", "")))
	if not (c is Vector3) or not c.is_finite():
		return
	var sz = o.get("arena", def.get("arena", FIXED_ARENA))
	if sz is Array and sz.size() >= 2:
		sz = Vector2(float(sz[0]), float(sz[1]))
	if not (sz is Vector2) or sz.x <= 0.0 or sz.y <= 0.0:
		sz = FIXED_ARENA
	var col = o.get("arena_color", def.get("arena_color", ""))
	if col is String and col != "":
		_court_color = Color(col)
	elif col is Color:
		_court_color = col
	fixed = true
	global_position = c
	rect = Rect2(-sz * 0.5, sz)
	if training:
		_setup_training_court()
		return
	axis = Vector3.RIGHT
	var spread: float = maxf(sz.x, sz.y) * 0.5 + TRAINER_STAND_OFF
	var me := -axis * spread
	var them := axis * spread
	enemy_spot = _nearest_free(axis * spread * FOE_THROW)
	player_spot = _nearest_free(me + axis * LEAD_STEP)
	_cam_focus = (me + enemy_spot) * 0.5
	var p := get_tree().get_first_node_in_group(OverworldPlayer.GROUP) as Node3D
	var t := _trainer_body(o)
	if p or t:
		_fade_from_black()
	if p:
		_place_body(p, me, them)
	if t:
		_place_body(t, them, me)


## Selvagem com centro fixo (wild_arena_center do original, só o treino usa): o jogador fica onde está,
## o boneco aparece no centro e o 1º mon sai a 1,5 m do jogador na direção do centro, dentro da quadra.
func _setup_training_court() -> void:
	var p := get_tree().get_first_node_in_group(OverworldPlayer.GROUP) as Node3D
	var me := to_local(p.global_position) if p else Vector3(rect.position.x, 0, 0)
	me.y = 0.0
	var to_mid := -me
	var lead := me + (to_mid.normalized() * 1.5 if to_mid.length() > 0.01 else Vector3(0, 0, 1.5))
	var inner := rect.grow(-0.5)
	lead.x = clampf(lead.x, inner.position.x, inner.end.x)
	lead.z = clampf(lead.z, inner.position.y, inner.end.y)
	player_spot = _nearest_free(lead)
	enemy_spot = _nearest_free(Vector3.ZERO)
	var d := enemy_spot - player_spot
	d.y = 0.0
	axis = d.normalized() if d.length() > 0.01 else Vector3.RIGHT
	_cam_focus = (player_spot + enemy_spot) * 0.5


## Marcador da sala atual com esse nome (o original procura o nó na cena); as salas daqui chamam o
## centro da quadra de "arena_center".
func _marker_center(marker: String) -> Variant:
	var w := get_tree().get_first_node_in_group(Overworld.GROUP)
	if marker == "" or w == null or not w.has_method("interior"):
		return null
	var room = w.interior(str(w.get("location_id")))
	if room == null:
		return null
	for nm in [marker, "arena_center"]:
		var m = room.markers.get(nm)
		if m is Node3D:
			return (m as Node3D).global_position
	return null


## O treinador no mundo: opts.trainer_node, senão o WorldTrainer desse trainer_id mais perto da quadra.
func _trainer_body(o: Dictionary) -> Node3D:
	var n = o.get("trainer_node")
	if n is Node3D and is_instance_valid(n):
		return n
	var id := String(o.get("trainer_id", ""))
	var best: Node3D = null
	var best_d := INF
	for t in get_tree().get_nodes_in_group(WorldNpc.GROUP):
		if id != "" and t is Node3D and str(t.get("trainer_id")) == id:
			var d := (t as Node3D).global_position.distance_squared_to(global_position)
			if d < best_d:
				best = t
				best_d = d
	return best


## _place_trainer do original: põe o corpo em `at` (local, mesmo y) virado para `look`.
func _place_body(n: Node3D, at: Vector3, look: Vector3) -> void:
	var g := to_global(at)
	g.y = n.global_position.y
	n.global_position = g
	if n is CharacterBody3D:
		(n as CharacterBody3D).velocity = Vector3.ZERO
	var l := to_global(look)
	l.y = g.y
	if n.has_method("face_toward"):
		n.face_toward(l)
	elif n.has_method("face"):
		n.face(l)


## A volta do fade do original (Transitions.fade 1 -> 0 em 0.25 s) por cima da troca de lugar.
func _fade_from_black() -> void:
	var cl := CanvasLayer.new()
	cl.name = "CourtFade"
	cl.layer = 41
	add_child(cl)
	var r := ColorRect.new()
	r.color = Color.BLACK
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cl.add_child(r)
	var tw := create_tween()
	tw.tween_property(r, "color:a", 0.0, FIXED_FADE)
	tw.tween_callback(cl.queue_free)


## nearest_ok do original: o ponto mais perto (anéis de 1 m) dentro da quadra e sem parede/móvel.
func _nearest_free(at: Vector3) -> Vector3:
	for r in 9:
		for i in range(-r, r + 1):
			for j in range(-r, r + 1):
				if maxi(absi(i), absi(j)) != r:
					continue
				var q := at + Vector3(i, 0, j)
				if rect.has_point(Vector2(q.x, q.z)) and not _solid_at(q):
					return q
	return at


func _space() -> PhysicsDirectSpaceState3D:
	var w := get_world_3d() if is_inside_tree() else null
	return w.direct_space_state if w else null


## Parede ou móvel (camada 1) onde o corpo de um mon ficaria com o pé em `at` (local).
func _solid_at(at: Vector3) -> bool:
	var space := _space()
	if space == null:
		return false
	if _probe == null:
		var s := SphereShape3D.new()
		s.radius = BODY_R
		_probe = PhysicsShapeQueryParameters3D.new()
		_probe.shape = s
		_probe.collision_mask = SOLID_MASK
	_probe.transform = Transform3D(Basis(), to_global(Vector3(at.x, 0.6, at.z)))
	return not space.intersect_shape(_probe, 1).is_empty()


## O mon não atravessa parede nem móvel: desliza num eixo ou fica parado (quem já está dentro pode sair).
func _block_solid(f: BattleFighter, before: Vector3) -> void:
	var now := f.position
	if not _solid_at(now) or _solid_at(before):
		return
	if not _solid_at(Vector3(now.x, now.y, before.z)):
		f.position = Vector3(now.x, now.y, before.z)
	elif not _solid_at(Vector3(before.x, now.y, now.z)):
		f.position = Vector3(before.x, now.y, now.z)
	else:
		f.position = Vector3(before.x, now.y, before.z)


static var _court_tex: ImageTexture


static func _court_texture() -> ImageTexture:
	if _court_tex:
		return _court_tex
	var n := 256
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var line := 0.022
	var inset := 0.012
	for y in n:
		for x in n:
			var u := float(x) / (n - 1)
			var v := float(y) / (n - 1)
			var edge := minf(minf(u, 1.0 - u), minf(v, 1.0 - v))
			var a := 0.0
			if edge >= inset and edge < inset + line:
				a = 0.85
			var cu := minf(u, 1.0 - u)
			var cv := minf(v, 1.0 - v)
			if (
				(cu < 0.14 and cv < inset + line * 2.6 and cv >= inset)
				or (cv < 0.14 and cu < inset + line * 2.6 and cu >= inset)
			):
				a = 1.0
			if edge >= inset + line * 2.2 and edge < inset + line * 3.0:
				var along := u if (minf(v, 1.0 - v) < minf(u, 1.0 - u)) else v
				a = maxf(a, 0.5 if fmod(along * 24.0, 1.0) < 0.5 else 0.0)
			if edge > inset:
				a = maxf(a, 0.06 + 0.08 * (1.0 - smoothstep(0.0, 0.25, edge)))
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_court_tex = ImageTexture.create_from_image(img)
	return _court_tex


## Próximo mon da party com HP que ainda não está em campo.
func _next_healthy(after: int) -> int:
	var busy := _field_mons() + _pending
	for k in party.size():
		var i := (after + 1 + k) % party.size()
		if i != after and not party[i].is_fainted() and not busy.has(party[i]):
			return i
	return -1


## Líder (Game.state.first_healthy do original): o 1º de pé fora da bola, senão o 1º de pé.
func _lead_index() -> int:
	for i in party.size():
		if _out.has(party[i]) and not party[i].is_fainted():
			return i
	return _next_healthy(-1)


## Aliado da selvagem só se o líder já está fora: o próximo de pé também fora da bola.
func _out_ally(lead: int) -> int:
	if lead < 0 or not _out.has(party[lead]):
		return -1
	for i in party.size():
		if i != lead and _out.has(party[i]) and not party[i].is_fainted():
			return i
	return -1


## Mons do jogador vivos em campo (controlado e aliado).
func _field_mons() -> Array:
	var out: Array = []
	for f in [player, ally]:
		if is_instance_valid(f) and f.active():
			out.append(f.mon)
	return out


## Batalha automática (opts.auto_battle, ligada por padrão): o mon do jogador luta com a mesma IA
## do adversário; o jogador ainda usa bolsa, bola, troca e pausa. autoplay = IA e ninguém no teclado.
func _player_ctrl() -> String:
	return "ai" if opts.get("autoplay", false) or opts.get("auto_battle", true) else "player"


## opts.no_rewards (séries de balanceamento): sem XP, EVs, prêmio nem evolução no meio da luta.
func _rewards() -> bool:
	return not bool(opts.get("no_rewards", false))


## Tem alguém no teclado (fora de testes manuais e do autoplay).
func _human() -> bool:
	return not manual and not bool(opts.get("autoplay", false))


func _next_enemy(after: int) -> int:
	var here: Array = []
	for f in fighters:
		if is_instance_valid(f) and f.side == 1 and f.on_field and f.alive():
			here.append(f.mon)
	for i in range(after + 1, enemies.size()):
		var m: Mon = enemies[i]
		if not m.is_fainted() and not here.has(m) and not _enemy_reserved.has(m):
			return i
	for i in range(0, mini(after + 1, enemies.size())):
		var m: Mon = enemies[i]
		if not m.is_fainted() and not here.has(m) and not _enemy_reserved.has(m):
			return i
	return -1


func _spawn(m: Mon, side: int, ctrl: String, at: Vector3) -> BattleFighter:
	var f := BattleFighter.new()
	f.arena = self
	f.vfx = vfx
	add_child(f)
	f.setup(m, side, ctrl)
	f.position = at
	f.facing = axis if side == 0 else -axis
	f.fainted.connect(_on_fainted)
	fighters.append(f)
	if moves:
		moves.effects.on_enter(f)
	if vfx and f.is_inside_tree():
		vfx.puff(f.to_global(Vector3(0, 0.45, 0)), 1.6)
	if abilities:
		abilities.on_enter(f)
	return f


func _send_player(i: int, at: Vector3) -> void:
	if _track_out and not _out.has(party[i]):
		_out.append(party[i])
	player = _spawn(party[i], 0, _player_ctrl(), at)
	_side_a_ai(player)
	player.set_meta("party_index", i)
	_bind()
	_sync_board_level()
	player.popup("Vai, %s!" % player.mon.display_name, Color(0.7, 0.9, 1.0), 1.0, 0.8)
	say("Vai, %s!" % player.mon.display_name)


func _send_ally(i: int, at: Vector3) -> void:
	if _track_out and not _out.has(party[i]):
		_out.append(party[i])
	ally = _spawn(party[i], 0, "ai", at)
	_side_a_ai(ally)
	ally.set_meta("party_index", i)
	_bind()
	ally.popup("Vai, %s!" % ally.mon.display_name, Color(0.7, 0.9, 1.0), 1.0, 0.8)
	say("Vai, %s!" % ally.mon.display_name)


## IA do lado do jogador igual à do adversário, com os ajustes do lado A: opts.player_think_scale e
## opts.player_item (item de uso único por mon, como o do treinador).
func _side_a_ai(f: BattleFighter) -> void:
	f.ai.think_scale = float(opts.get("player_think_scale", 1.0))
	f.trainer_item = String(opts.get("player_item", ""))


## Lado da quadra perpendicular ao eixo (para separar os dois mons de cada lado na dupla).
func _lateral() -> Vector3:
	return axis.cross(Vector3.UP).normalized()


func _send_enemy(i: int, slot := 0) -> void:
	enemy_index = maxi(enemy_index, i)
	var at := enemy_spot
	if doubles:
		at = enemy_spot + _lateral() * DOUBLES_GAP * (0.5 if slot == 1 else -0.5)
		if fixed:
			at = _nearest_free(at)
	var f := _spawn(enemies[i], 1, "ai", at)
	if slot == 1:
		enemy2 = f
	else:
		enemy = f
	f.ai.think_scale = _think_scale
	f.ai.think = WILD_OPENING_DELAY if kind == "wild" else TRAINER_SWAP_HOLD
	f.trainer_item = _trainer_item if kind == "trainer" else ""
	if slot == 1:
		_bind()
		return
	if training:  # o original: Mode.DUMMY (dummy_style 0 fica parado), sem golpes, imortal
		enemy.controller = "dummy"
		enemy.immortal = true
		var card = load(String(opts.get("card", ""))) if opts.has("card") else null
		if card is Texture2D and enemy.look:
			enemy.look.apply_card(card)
	_participants.clear()
	_bind()
	_sync_board_level()


## Boneco do treino no nível do mon controlado, curado (_sync_board_level do original).
func _sync_board_level() -> void:
	if not training or not is_instance_valid(enemy) or not is_instance_valid(player):
		return
	var lv: int = player.mon.level
	if enemy.mon.level == lv:
		return
	enemy.mon.level = lv
	enemy.mon.recalc()
	enemy.mon.heal_full()
	_sync_from_mon(enemy)


## Golpe que zerou o HP do alvo (Moves.knocked_out): no treino quem acertou o boneco ganha os EVs dele
## (Battle._on_knocked_out + gain_evs_from do original).
func on_knocked_out(user: BattleFighter, target: BattleFighter) -> void:
	if not training or target != enemy or not is_instance_valid(user) or user.side != 0:
		return
	if not _rewards():
		return
	var got := user.mon.add_evs(enemy.mon.ev_yield())
	if got.is_empty():
		return
	_sync_from_mon(user)
	var names: Dictionary = preload("res://ui/ui_kit.gd").STATS
	var parts: Array = []
	for s in got:
		parts.append("+%d EV %s" % [got[s], names.get(s, String(s).to_upper())])
	user.popup("  ".join(parts), Color(0.6, 1.0, 0.8), 0.8)


## Reaponta oponentes: os mons do jogador miram o inimigo; o inimigo mira o controlado
## (o selvagem reavalia sozinho entre os dois em BattleAI.pick_target). Na dupla cada um fica com o
## alvo atual se ele segue em campo, senão pega o mais perto (a IA reavalia depois).
func _bind() -> void:
	if not is_instance_valid(enemy) and not is_instance_valid(enemy2):
		return
	var foes: Array = [enemy, enemy2].filter(func(e): return is_instance_valid(e) and e.active())
	if foes.is_empty() and is_instance_valid(enemy):
		foes = [enemy]
	for f in [player, ally]:
		if is_instance_valid(f) and f.active():
			var cur0: BattleFighter = f.opponent
			if not doubles or not (is_instance_valid(cur0) and cur0.active() and cur0.side == 1):
				f.opponent = _nearest(f, foes)
			for e in foes:
				if e.alive():
					_participants[f.mon.get_instance_id()] = f.mon
	var mine: Array = [player, ally].filter(func(x): return is_instance_valid(x) and x.active())
	for e in [enemy, enemy2]:
		if not is_instance_valid(e):
			continue
		var cur: BattleFighter = e.opponent
		var keep: bool = is_instance_valid(cur) and cur.active() and cur.side == 0
		if doubles and keep:
			continue
		if doubles and not mine.is_empty():
			e.opponent = _nearest(e, mine)
		elif kind != "wild" or not keep:
			e.opponent = player if is_instance_valid(player) and player.active() else ally


func _nearest(f: BattleFighter, cands: Array) -> BattleFighter:
	var best: BattleFighter = null
	var bd := INF
	for c in cands:
		var d := f.flat_to(c).length()
		if d < bd:
			bd = d
			best = c
	return best


func targets_of(user: BattleFighter) -> Array:
	var out: Array = []
	for f in fighters:
		if f != user and is_instance_valid(f) and f.side != user.side and f.active():
			out.append(f)
	return out


func later(delay: float, cb: Callable) -> void:
	_events.append({"t": delay, "cb": cb})


## Registra um golpe avisado (a IA de quem está do outro lado tenta sair da área antes de ele cair).
func telegraph(e: Dictionary) -> void:
	_tele_n += 1
	e["id"] = _tele_n
	telegraphs.append(e)


## Cena de impacto: o HUD desenha a faixa e a luta congela um instante (no máx. uma a cada CUT_IN_GAP).
func cut_in(text: String, col: Color, secs := CUT_IN_SECS) -> bool:
	if _cut_gap > 0.0:
		return false
	_cut_gap = CUT_IN_GAP
	_cut_t = secs
	if hud and hud.has_method("cut_in"):
		hud.cut_in(text, col, secs)
	return true


func edge_push(f: BattleFighter) -> Vector3:
	var p := Vector3.ZERO
	var inner := rect.grow(-2.0)
	if f.position.x < inner.position.x:
		p.x = (inner.position.x - f.position.x) / 2.0
	elif f.position.x > inner.end.x:
		p.x = (inner.end.x - f.position.x) / 2.0
	if f.position.z < inner.position.y:
		p.z = (inner.position.y - f.position.z) / 2.0
	elif f.position.z > inner.end.y:
		p.z = (inner.end.y - f.position.z) / 2.0
	if fixed:
		p += _obstacle_push(f) / 2.0
	return p


## O original (combatant.gd _obstacle_push): 8 raios de 1 m na altura do corpo; o que bate empurra para longe.
func _obstacle_push(f: BattleFighter) -> Vector3:
	var space := _space()
	if space == null:
		return Vector3.ZERO
	var origin := to_global(f.position) + Vector3(0, 0.6, 0)
	var push := Vector3.ZERO
	for i in 8:
		var a := i * TAU / 8.0
		var dir := Vector3(cos(a), 0.0, sin(a))
		var q := PhysicsRayQueryParameters3D.create(origin, origin + dir, SOLID_MASK)
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			push -= dir * (1.0 - origin.distance_to(hit.position))
	return push


## Fim da rodada (BattleTurns): efeitos de fim de turno uma vez, na ordem oficial, e depois a entrada
## dos substitutos de quem desmaiou.
func end_of_round() -> void:
	if end_turn and state == "fight":
		end_turn.run()
	var q := _round_end_q
	_round_end_q = []
	for cb in q:
		cb.call()


## Começo da rodada (BattleTurns, antes de montar a fila): a IA de treinador de cada lado decide
## (round_start), depois saem as trocas (uma por lado) e os itens pedidos. Quem entrou e quem recebeu
## item ficam fora da fila nesta rodada. Devolve a folga (s) para a bola antes do 1º golpe.
func begin_of_round() -> float:
	if state != "fight":
		return 0.0
	for side in [0, 1]:
		var t = trainer_ai.get(side)
		if t != null and t.has_method("round_start"):
			t.round_start()
	var hold := 0.0
	for side in [0, 1]:
		var req: Dictionary = _switch_req.get(side, {})
		if req.is_empty():
			continue
		_switch_req.erase(side)
		if _do_switch(req.out, req.mon):
			hold = maxf(hold, SWITCH_HOLD)
	var items := _item_req
	_item_req = []
	for r in items:
		_do_trainer_item(int(r.side), String(r.item), r.target)
	return hold


## Mons do banco do lado (vivos, fora de campo, sem estar chamados). O índice é o que request_switch e
## pick_replacement usam.
func bench_of(side: int) -> Array:
	var list: Array = party if side == 0 else enemies
	var out: Array = []
	var here: Array = []
	for f in fighters:
		if is_instance_valid(f) and f.side == side and f.on_field:
			here.append(f.mon)
	for m in list:
		if m is Mon and not m.is_fainted() and not here.has(m) and not _pending.has(m):
			if side == 1 and _enemy_reserved.has(m):
				continue
			out.append(m)
	return out


## Pede a troca de `out` pelo Mon bench_of(side)[bench_idx] no começo da próxima rodada (uma por lado
## por rodada; Mean Look segura). Quem entra não ataca nessa rodada e herda os golpes mirados em `out`.
## Sem a fila de rodadas (turn_mode false) a troca sai na hora.
func request_switch(side: int, out: BattleFighter, bench_idx: int) -> bool:
	if state != "fight" or not is_instance_valid(out) or out.side != side or not out.active():
		return false
	if _switch_req.has(side):
		return false
	var bench := bench_of(side)
	if bench_idx < 0 or bench_idx >= bench.size():
		return false
	if moves.effects.cant_escape(out):
		return false
	_switch_req[side] = {"out": out, "mon": bench[bench_idx]}
	if not turns.on:
		begin_of_round()
	return true


## Troca pedida para o lado (vazio = nenhuma): {out, mon}.
func pending_switch(side: int) -> Dictionary:
	return _switch_req.get(side, {})


## Pede o item `item` (id de items.json; um por Mon por luta, como o item do treinador) em `target` no
## começo da próxima rodada; o alvo não ataca nessa rodada.
func request_trainer_item(side: int, item: String, target: BattleFighter) -> bool:
	if state != "fight" or not is_instance_valid(target) or target.side != side or target.item_used:
		return false
	if Dex.item(item).is_empty():
		return false
	for r in _item_req:
		if r.target == target:
			return false
	_item_req.append({"side": side, "item": item, "target": target})
	if not turns.on:
		begin_of_round()
	return true


func _do_trainer_item(side: int, item: String, target: BattleFighter) -> void:
	if not is_instance_valid(target) or not target.active() or target.side != side:
		return
	var e: Dictionary = Dex.item(item).get("effect", {})
	target.item_used = true
	if e.has("hp"):
		var amount: int = target.max_hp if str(e.hp) == "full" else int(e.hp)
		var before := target.hp
		target.heal(mini(amount, target.max_hp - target.hp))
		target.popup("+%d HP" % (target.hp - before), Color(0.55, 1.0, 0.6), 1.0, 0.5)
	if e.has("cure") and (String(e.cure) == "all" or target.status == String(e.cure)):
		target.clear_status()
	if turns.on:
		target.set_meta("sit_round", turns.round_n)
	item_used_by_trainer(target, String(Dex.item(item).get("name", item)))


## Troca de fato: recolhe `out`, o treinador joga a bola com `m` no mesmo lugar; os golpes mirados em
## `out` vão para quem entrou, que fica fora da fila desta rodada.
func _do_switch(out: BattleFighter, m: Mon) -> bool:
	if not is_instance_valid(out) or not out.active() or m.is_fainted():
		return false
	var side := out.side
	var at := out.position
	at.y = 0.0
	say("Volte, %s!" % out.mon.display_name, "trainer" if side == 1 else "info")
	var was_ally := out == ally
	var slot := 1 if out == enemy2 else 0
	var aimed: Array = fighters.filter(func(g): return is_instance_valid(g) and g.opponent == out)
	_recall(out)
	var nf: BattleFighter
	if side == 0:
		var i := party.find(m)
		if was_ally:
			_send_ally(i, at)
			nf = ally
		else:
			_send_player(i, at)
			nf = player
	else:
		_enemy_reserved.erase(m)
		_send_enemy(enemies.find(m), slot)
		nf = enemy2 if slot == 1 else enemy
	if is_instance_valid(nf):
		nf.position = at
		if turns.on:
			nf.set_meta("sit_round", turns.round_n)
		for g in aimed:
			if is_instance_valid(g) and g.active():
				g.opponent = nf
	return true


## Ritmo de rodadas: guarda a ação para o fim da rodada; sem a fila, faz na hora.
func at_round_end(cb: Callable) -> void:
	if turns and turns.on and state == "fight":
		_round_end_q.append(cb)
	else:
		cb.call()


## Substituto escolhido pela IA do treinador (pick_replacement) ou `fallback` (índice da equipe).
func _replacement(side: int, slot: int, fallback: int) -> int:
	var t = trainer_ai.get(side)
	if t != null and t.has_method("pick_replacement"):
		var k := int(t.pick_replacement(slot))
		var bench := bench_of(side)
		if k >= 0 and k < bench.size():
			return (party if side == 0 else enemies).find(bench[k])
	return fallback


func note_hit(
	_user: BattleFighter, _target: BattleFighter, _mv: Dictionary, _dmg: int, _hp_before: int
) -> void:
	hits += 1
	hit_dmg += _dmg


# --- Laço ---


func step(dt: float) -> void:
	if state == "idle" or state == "done":
		return
	var raw := dt
	# Pausa aberta: a luta para (o original: fight_speed 0 com _battle_paused).
	dt *= fight_speed * (0.0 if pause_open else (MODAL_SLOW if menu != "" else 1.0))
	_state_t += dt
	_tick_fx(raw)
	match state:
		"intro":
			if not _revealed and _state_t >= TRAINER_CHALLENGE:
				_reveal_trainer_mon()
			if _state_t >= INTRO_TIME + (TRAINER_CHALLENGE if kind == "trainer" else 0.0):
				state = "fight"
				hud.intro_bars(false)
				hud.fight_flash("Lutem!")
				fight_started.emit()
		"fight":
			if _evo != null:
				_evolution_step(raw)
			elif not pause_open:
				_fight_step(dt)
				_check_evolution(raw)
			elif not manual:
				_pause_input()
		"capture":
			_capture_step(dt)
		"ending":
			if _state_t >= _end_delay:
				_results = _build_results() if result.get("outcome") == "win" else []
				if _results.is_empty():
					_finish()
					return
				state = "results"
		"results":
			if _results_step(raw):
				return
	if state == "done":
		return
	_visual_step(dt)
	_update_camera(raw)
	hud.refresh(
		player,
		enemy if _revealed else null,  # o cartão do adversário só depois da bola
		raw,
		ally,
		{
			"ally_mode": ALLY_MODE_NAMES[ally_mode],
			"foe2": enemy2 if _revealed and is_instance_valid(enemy2) and enemy2.on_field else null,
			"commands": _commands_info(),
			"obey": obey,
			"sync": [combos.sync_of(0), combos.sync_of(1)] if combos else [0.0, 0.0],
			"marks": _marks_info(),
			"item_cd": item_cd,
			"menu": _menu_text() if menu != "" else "",
			"foe_tag": "SELVAGEM" if kind == "wild" else "TREINADOR",
			"show_moves": _human(),
			"foe_balls": _foe_balls(),
			"pause": _pause_text() if pause_open else "",
			"exp_script":
			(
				{"mon": _beat.get("mon"), "xp": _xp_shown, "level": _xp_level}
				if _xp_shown >= 0.0
				else {}
			)
		}
	)


func _commands_info() -> Dictionary:
	var out := {}
	for slot in ["player", "ally"]:
		var f: BattleFighter = player if slot == "player" else ally
		if not is_instance_valid(f):
			continue
		var m := ally_mode if slot == "ally" else player_mode
		if auto_commands:
			m = f.command
		out[slot] = ALLY_MODE_NAMES[clampi(m, 0, ALLY_MODE_NAMES.size() - 1)]
	return out


func _marks_info() -> Dictionary:
	var out := {}
	if combos == null:
		return out
	for f in fighters:
		if is_instance_valid(f) and f.active():
			var mk: Array = combos.marks_of(f)
			if not mk.is_empty():
				out[f.get_instance_id()] = mk
	return out


## Fim da abertura do treinador: a bola cai e o 1º Pokémon aparece ("<NOME> mandou X!").
func _reveal_trainer_mon() -> void:
	_revealed = true
	if not is_instance_valid(enemy):
		return
	enemy.visible = true
	if vfx and enemy.is_inside_tree():
		vfx.puff(enemy.to_global(Vector3(0, 0.45, 0)), 1.6)
	var line := "%s mandou %s!" % [trainer_name(), enemy.mon.display_name]
	if is_instance_valid(enemy2):
		enemy2.visible = true
		if vfx and enemy2.is_inside_tree():
			vfx.puff(enemy2.to_global(Vector3(0, 0.45, 0)), 1.6)
		line = (
			"%s mandou %s e %s!" % [trainer_name(), enemy.mon.display_name, enemy2.mon.display_name]
		)
	hud.banner(line, INTRO_TIME)
	say(line, "trainer")


## Animação dos sprites e efeitos (só visual).
func _visual_step(dt: float) -> void:
	for f in fighters:
		if is_instance_valid(f) and f.visible and not (state == "capture" and f == enemy):
			f.visual_step(dt)
	if vfx:
		vfx.tick(dt)
	_place_turn_mark(dt)


## Marcador de vez: anel no chão e seta sobre a cabeça de quem solta o próximo golpe (o alvo tem tempo
## de ver e desviar). Amarelo = lado do jogador, vermelho = adversário; brilha mais na vez de fato.
func _place_turn_mark(dt: float) -> void:
	var who: BattleFighter = turns.next_up() if turns and state == "fight" else null
	if who == null or not is_instance_valid(who) or not who.visible:
		if _turn_mark:
			_turn_mark.visible = false
		return
	if _turn_mark == null:
		_turn_mark = _build_turn_mark()
	_turn_pulse += dt
	var live := turns.can_fire(who)
	var col := Color(1.0, 0.9, 0.35) if who.side == 0 else Color(1.0, 0.4, 0.35)
	col.a = (0.95 if live else 0.55) * (0.75 + 0.25 * sin(_turn_pulse * 9.0))
	for c in _turn_mark.get_children():
		(c as MeshInstance3D).material_override.albedo_color = col
	_turn_mark.visible = true
	_turn_mark.position = Vector3(who.position.x, 0.0, who.position.z)
	var ring: Node3D = _turn_mark.get_node("Ring")
	var k := 1.0 + 0.08 * sin(_turn_pulse * 6.0)
	ring.scale = Vector3(k, 0.05, k)
	var arrow: Node3D = _turn_mark.get_node("Arrow")
	arrow.position.y = who.position.y + who.look_h + 0.55 + 0.08 * sin(_turn_pulse * 5.0)


func _build_turn_mark() -> Node3D:
	var root := Node3D.new()
	root.name = "TurnMark"
	add_child(root)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	var tm := TorusMesh.new()
	tm.inner_radius = 0.55
	tm.outer_radius = 0.66
	var ring := MeshInstance3D.new()
	ring.name = "Ring"
	ring.mesh = tm
	ring.material_override = mat
	ring.position.y = 0.05
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)
	var cm := CylinderMesh.new()
	cm.top_radius = 0.16
	cm.bottom_radius = 0.0
	cm.height = 0.3
	cm.radial_segments = 4
	var arrow := MeshInstance3D.new()
	arrow.name = "Arrow"
	arrow.mesh = cm
	arrow.material_override = mat.duplicate()
	arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(arrow)
	ring.scale = Vector3(1, 0.05, 1)
	return root


func _foe_balls() -> Array:
	if kind == "wild":
		return []
	var out: Array = []
	for m in enemies:
		out.append(not m.is_fainted())
	return out


func _fight_step(dt: float) -> void:
	_cut_gap = maxf(_cut_gap - dt, 0.0)
	if _cut_t > 0.0:
		_cut_t -= dt
		return
	for e in telegraphs.duplicate():
		e.t -= dt
		if e.t <= 0.0:
			telegraphs.erase(e)
	for k in _cmd_cd:
		_cmd_cd[k] = maxf(float(_cmd_cd[k]) - dt, 0.0)
	var evs := _events
	_events = []
	for e in evs:
		e.t -= dt
		if e.t <= 0.0:
			e.cb.call()
		else:
			_events.append(e)
	if state != "fight":
		return
	_swap_cd = maxf(_swap_cd - dt, 0.0)
	item_cd = maxf(item_cd - dt, 0.0)
	_support_heal()
	combos.tick(dt)
	field.tick(dt)
	abilities.tick(dt)
	moves.effects.tick(dt)
	turns.tick(dt)
	for f in fighters:
		if f.on_field:
			f.tick(dt)
	for f in fighters.duplicate():
		if not f.on_field or state != "fight":
			continue
		var want := Vector3.ZERO
		var speed: float = f.walk_speed()
		if f.alive():
			if f.controller == "player":
				want = _player_input(f)
			elif f.controller == "ai" and f.impact_t <= 0.0 and not tut_hold_foe:
				if f == player and _human():
					_commands(f)
				if f.controller == "ai" and f.on_field:
					want = f.ai.step(dt)
		var before: Vector3 = f.position
		f.drive(dt, want, speed)
		if field:
			f.position += field.push_out(f)
		if fixed:
			_block_solid(f, before)
		var bounds := rect.grow(-0.5)
		f.position.x = clampf(f.position.x, bounds.position.x, bounds.end.x)
		f.position.z = clampf(f.position.z, bounds.position.y, bounds.end.y)
	_separate()
	_clash()
	for p in projectiles:
		p.step(dt, self)
	for p in projectiles.filter(func(q): return q.done):
		projectiles.erase(p)
		p.queue_free()


## CLASH: duas investidas de lados opostos se encontram de frente: as duas param, os dois são
## empurrados para trás e ninguém toma dano.
func _clash() -> void:
	for a in fighters:
		if not (a.side == 0 and a.active() and a.dash_t > 0.0):
			continue
		for b in fighters:
			if b.side != 1 or not b.active() or b.dash_t <= 0.0:
				continue
			var d: Vector3 = a.flat_to(b)
			if d.length() > BattleFighter.HIT_RANGE + 0.3 or a.dash_dir.dot(b.dash_dir) > -0.5:
				continue
			a.dash_t = 0.0
			b.dash_t = 0.0
			a.dash_hit = true
			b.dash_hit = true
			var n: Vector3 = d.normalized() if d.length() > 0.01 else axis
			a.knock = -n * 7.0
			b.knock = n * 7.0
			a.stun_t = maxf(a.stun_t, 0.25)
			b.stun_t = maxf(b.stun_t, 0.25)
			var mid: Vector3 = (a.position + b.position) * 0.5
			# O aviso vai para embaixo da arena (BattleHUD.warn), sem congelar a luta nem cobrir os Pokémon.
			if hud:
				hud.warn("CLASH!", Color(1, 0.9, 0.5))
			fx_disc(mid * Vector3(1, 0, 1), 1.2, Color(1, 0.95, 0.7, 0.8), 0.3)
			PixelFx.pop(self, "impact", mid + Vector3(0, 0.9, 0), 2.4, 0.35)
			PixelFx.pop(self, "shock", mid + Vector3(0, 0.6, 0), 3.0, 0.4)
			preload("res://audio/cue.gd").sfx("hit_super")
			say("CLASH! %s e %s se chocaram!" % [a.mon.display_name, b.mon.display_name])


func _separate() -> void:
	var live: Array = fighters.filter(
		func(f): return f.active() and f.dash_t <= 0.0 and not f.is_airborne() and f.motion == ""
	)
	for i in live.size():
		for j in range(i + 1, live.size()):
			var a: BattleFighter = live[i]
			var b: BattleFighter = live[j]
			var d := b.position - a.position
			d.y = 0.0
			var min_d := 0.8
			if d.length() < min_d:
				var n := d.normalized() if d.length() > 0.001 else Vector3.FORWARD
				var push := (min_d - d.length()) * 0.5
				a.position -= n * push
				b.position += n * push


var _g_was_down := false


## G: comando do controlado (na batalha automática o controlado também é IA).
func _player_mode_pressed() -> bool:
	if InputMap.has_action("player_mode"):
		return Input.is_action_just_pressed("player_mode")
	var down := Input.is_physical_key_pressed(KEY_G)
	var hit := down and not _g_was_down
	_g_was_down = down
	return hit


## `ally_mode` (F) vem do núcleo; sem a ação, lê a tecla F direto.
func _ally_mode_pressed() -> bool:
	if InputMap.has_action("ally_mode"):
		return Input.is_action_just_pressed("ally_mode")
	var down := Input.is_physical_key_pressed(KEY_F)
	var hit := down and not _f_was_down
	_f_was_down = down
	return hit


func _player_input(f: BattleFighter) -> Vector3:
	if manual:
		return Vector3.ZERO
	if not _commands(f):
		return Vector3.ZERO
	if tut_locked:
		return _locked_input(f)
	var i := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if Input.is_action_just_pressed("jump"):
		f.start_jump()
	f.sprinting = Input.is_action_pressed("sprint") and f.can_sprint(i.length() > 0.1)
	for k in mini(f.moves.size(), 4):
		if Input.is_action_just_pressed("move_%d" % (k + 1)) and f.can_act():
			if f.out_of_pp():
				f.struggle()
			else:
				moves.use(f, String(f.moves[k]), true)
	return Vector3(i.x, 0.0, i.y).rotated(Vector3.UP, _yaw)


## Comandos do treinador, que valem também na batalha automática: pausa (Esc), bolsa (E), modo do
## aliado (F), troca (Tab) e bola (Q). false quando o quadro foi para um menu (sem andar nem golpe).
func _commands(f: BattleFighter) -> bool:
	if menu != "":
		f.sprinting = false
		_menu_input()
		return false
	if Input.is_action_just_pressed("pause"):
		open_pause()
		return false
	if tut_locked:
		return true
	if Input.is_action_just_pressed("interact"):
		open_menu("bag")
		return false
	if _ally_mode_pressed():
		cycle_ally_mode()
	if _player_mode_pressed():
		cycle_player_mode()
	if Input.is_action_just_pressed("swap_mon"):
		swap()
	# Fugir não tem tecla, como no original: é o FUGIR da pausa (Esc).
	if Input.is_action_just_pressed("throw_ball"):
		throw_ball()
	return true


## Lição do tutorial (combatant.gd read_local_intent/apply_intent do original): só o golpe liberado,
## sem pulo nem corrida, e parado a não ser que tut_walk.
func _locked_input(f: BattleFighter) -> Vector3:
	f.sprinting = false
	var k := tut_move
	if (
		k >= 0
		and k < mini(f.moves.size(), 4)
		and Input.is_action_just_pressed("move_%d" % (k + 1))
		and f.can_act()
	):
		if f.out_of_pp():
			f.struggle()
		else:
			moves.use(f, String(f.moves[k]), true)
	if not tut_walk:
		return Vector3.ZERO
	var i := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	return Vector3(i.x, 0.0, i.y).rotated(Vector3.UP, _yaw)


func clear_tut_lock() -> void:
	tut_locked = false
	tut_move = -1
	tut_walk = false
	tut_hold_foe = false


# --- Ações do jogador ---


## Tab: com aliado em campo troca qual dos dois o jogador controla (instantâneo);
## sem aliado, recolhe o controlado e manda o próximo mon saudável da party.
func swap() -> bool:
	if is_instance_valid(ally) and ally.active():
		return swap_control()
	if not is_instance_valid(player):
		return false
	var nxt := _next_healthy(int(player.get_meta("party_index", 0)))
	return nxt >= 0 and send_in(nxt)


func swap_control() -> bool:
	if (
		state != "fight"
		or _swap_cd > 0.0
		or not is_instance_valid(player)
		or not player.active()
		or not is_instance_valid(ally)
		or not ally.active()
	):
		return false
	var old := player
	player = ally
	ally = old
	_sync_board_level()
	for f in [player, ally]:
		f.sprinting = false
		f.velocity = Vector3.ZERO
	player.controller = _player_ctrl()
	ally.controller = "ai"
	ally.ai.think = maxf(ally.ai.think, 0.3)
	_swap_cd = CONTROL_SWAP_CD
	player.popup("Vai, %s!" % player.mon.display_name, Color(0.7, 0.9, 1.0), 1.0, 0.8)
	return true


## Manda o mon `i` da party para campo. as_ally = no lugar do aliado (só selvagem 2x1);
## senão substitui o controlado. Respeita o cooldown de troca.
func send_in(i: int, as_ally := false) -> bool:
	if state != "fight" or _swap_cd > 0.0 or i < 0 or i >= party.size():
		return false
	var m: Mon = party[i]
	if m.is_fainted() or _field_mons().has(m):
		return false
	# Rodadas: trocar quem está em campo só no começo da próxima rodada (request_switch).
	var out: BattleFighter = ally if as_ally else player
	if turns and turns.on and is_instance_valid(out) and out.active():
		var k := bench_of(0).find(m)
		if not request_switch(0, out, k):
			return false
		out.popup("Troca na próxima rodada", Color(0.7, 0.9, 1.0), 0.8, 0.8)
		_swap_cd = SWAP_CD
		return true
	if as_ally:
		if _battle_size < 2 or not is_instance_valid(player) or not player.active():
			return false
		var at := player.position + Vector3(1.6, 0, 0.4)
		if is_instance_valid(ally) and ally.active():
			at = ally.position
			_recall(ally)
		at.y = 0.0
		_send_ally(i, at)
	else:
		if not is_instance_valid(player) or not player.alive():
			return false
		if player.dash_t > 0.0 or player.lunge_t > 0.0 or player.root_t > 0.0:
			return false
		if moves.effects.cant_escape(player):  # Mean Look
			player.popup("Não pode sair!", Color(0.8, 0.6, 0.9))
			return false
		var at := player.position
		at.y = 0.0
		_recall(player)
		_send_player(i, at)
	_swap_cd = SWAP_CD
	return true


## Troca de golpe (Baton Pass, U-turn, Volt Switch...): recolhe `f` e manda o próximo de pé do banco no
## mesmo lugar, dos dois lados. Devolve o lutador novo (null se não há ninguém). Não usa o cooldown da troca.
func switch_out(f: BattleFighter) -> BattleFighter:
	if state != "fight" or not is_instance_valid(f) or not f.active() or not fighters.has(f):
		return null
	var at := f.position
	at.y = 0.0
	if f.side == 0:
		var i := _next_healthy(int(f.get_meta("party_index", 0)))
		if i < 0:
			return null
		var was_ally := f == ally
		_recall(f)
		if was_ally:
			_send_ally(i, at)
		else:
			_send_player(i, at)
		_swap_cd = SWAP_CD
		return ally if was_ally else player
	# Adversário: o reserva troca de lugar na lista com quem sai (quem sai volta a esperar a vez).
	var j := -1
	for k in range(enemy_index + 1, enemies.size()):
		if not enemies[k].is_fainted():
			j = k
			break
	var i_out := enemies.find(f.mon)
	if j < 0 or i_out < 0:
		return null
	var slot := 1 if f == enemy2 else 0
	_recall(f)
	enemies[i_out] = enemies[j]
	enemies[j] = f.mon
	_send_enemy(i_out, slot)
	var nf: BattleFighter = enemy2 if slot == 1 else enemy
	nf.position = at
	say("%s voltou; entrou %s!" % [f.mon.display_name, nf.mon.display_name], "trainer")
	return nf


func cycle_ally_mode() -> int:
	return order("ally", (ally_mode + 1) % ALLY_MODE_NAMES.size())


func cycle_player_mode() -> int:
	return order("player", (player_mode + 1) % ALLY_MODE_NAMES.size())


## Dá o comando `mode` ao mon do slot ("player" ou "ally"). Com alguém no teclado ele chega depois de um
## tempo pela amizade, e amizade baixa pode ignorar um pouco ("?"). Sem teclado (testes) vale na hora.
func order(slot: String, mode: int) -> int:
	var f: BattleFighter = ally if slot == "ally" else player
	var cur := ally_mode if slot == "ally" else player_mode
	if _human() and float(_cmd_cd.get(slot, 0.0)) > 0.0:
		return cur
	_cmd_cd[slot] = CMD_CD
	say("%s: %s!" % ["Aliado" if slot == "ally" else "Você", ALLY_MODE_NAMES[mode]])
	if not _human() or not is_instance_valid(f) or not f.active():
		_set_mode(slot, mode, f)
		return mode
	var fr := int(f.mon.friend)
	var delay := lerpf(CMD_DELAY_MAX, CMD_DELAY_MIN, clampf(fr / 255.0, 0.0, 1.0))
	obey[slot] = true
	if rng.randf() < ignore_chance(fr):
		obey[slot] = false
		f.popup("?", Color(1, 0.85, 0.4), 1.4, 0.9)
		say("%s não está ouvindo..." % f.mon.display_name)
		delay += CMD_IGNORE_SECS
	later(delay, func() -> void: _set_mode(slot, mode, f))
	return mode


## Chance de ignorar um comando pela amizade (Desconfiado 30%, Contente 10%, Feliz 3%, Devotado 0).
static func ignore_chance(friend: int) -> float:
	if friend < 70:
		return 0.3
	if friend < 150:
		return 0.1
	if friend < 220:
		return 0.03
	return 0.0


func _set_mode(slot: String, mode: int, f: BattleFighter) -> void:
	if slot == "ally":
		ally_mode = mode
	else:
		player_mode = mode
	var ok := bool(obey.get(slot, true))
	obey[slot] = true
	if is_instance_valid(f) and f.active():
		f.command = mode
		f.popup(ALLY_MODE_NAMES[mode], ALLY_MODE_COLORS[mode], 1.0, 0.9)
		if ok and _human() and rng.randf() < 0.25:
			f.mon.set_friend(f.mon.friend + FRIEND_OBEY)


# --- Pausa da batalha (Esc) ---


## O original (pause_menu.gd can_open): só na luta, fora da abertura, do fim e da captura.
func open_pause() -> bool:
	if state != "fight" or pause_open:
		return false
	close_menu()
	pause_open = true
	pause_sel = 0
	if is_instance_valid(player):
		player.sprinting = false
	preload("res://audio/cue.gd").sfx("ui_confirm")
	return true


func close_pause() -> void:
	if not pause_open:
		return
	pause_open = false
	preload("res://audio/cue.gd").sfx("ui_back")


## _battle_items do original: MODO DO ALIADO, CONTROLAR O OUTRO (com dois em campo), FUGIR, VOLTAR.
func pause_items() -> Array:
	var items: Array = [
		{"id": "ally_mode", "label": "MODO DO ALIADO: %s" % ALLY_MODE_NAMES[ally_mode]}
	]
	if _player_ctrl() == "ai":
		items.append({"id": "player_mode", "label": "COMANDO: %s" % ALLY_MODE_NAMES[player_mode]})
	if is_instance_valid(ally) and ally.active() and is_instance_valid(player) and player.active():
		items.append({"id": "control_other", "label": "CONTROLAR O OUTRO"})
	items.append({"id": "run", "label": "FUGIR"})
	items.append({"id": "resume", "label": "VOLTAR"})
	return items


func choose_pause(id: String) -> void:
	match id:
		"ally_mode":
			cycle_ally_mode()
		"player_mode":
			cycle_player_mode()
		"control_other":
			swap_control()
			close_pause()
		"run":
			if kind != "wild" or not opts.get("can_run", true):
				run_away()  # só o aviso: a pausa fica aberta, como no original
				return
			pause_open = false
			run_away()
		"resume":
			close_pause()


func _pause_input() -> void:
	var items := pause_items()
	pause_sel = clampi(pause_sel, 0, items.size() - 1)
	if Input.is_action_just_pressed("pause"):
		close_pause()
		return
	if Input.is_action_just_pressed("move_forward"):
		pause_sel = wrapi(pause_sel - 1, 0, items.size())
		preload("res://audio/cue.gd").sfx("ui_move")
	if Input.is_action_just_pressed("move_back"):
		pause_sel = wrapi(pause_sel + 1, 0, items.size())
		preload("res://audio/cue.gd").sfx("ui_move")
	if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("jump"):
		choose_pause(String(items[pause_sel].id))


func _pause_text() -> String:
	var items := pause_items()
	pause_sel = clampi(pause_sel, 0, items.size() - 1)
	var lines: Array = []
	for k in items.size():
		lines.append(("> " if k == pause_sel else "   ") + String(items[k].label))
	return "\n".join(lines)


# --- Itens na batalha ---


## Itens de batalha (remédios e frutas com efeito de HP/cura/revive) que existem na bolsa.
func battle_items() -> Array:
	var g := _game()
	var out: Array = []
	if g == null:
		return out
	var ids: Array = g.bag.keys()
	ids.sort()
	for id in ids:
		var it := Dex.item(String(id))
		var fx: Dictionary = it.get("effect", {})
		if (
			int(g.bag[id]) > 0
			and String(it.get("category", "")) in BATTLE_ITEM_CATEGORIES
			and (fx.has("hp") or fx.has("cure") or fx.has("revive"))
		):
			out.append(String(id))
	return out


## Lutador vivo em campo para este Mon (null se está na party ou desmaiado).
func _active_fighter_of(m: Mon) -> BattleFighter:
	for f in fighters:
		if is_instance_valid(f) and f.mon == m and f.active():
			return f
	return null


## Usa `id` da bolsa no mon `m` (padrão: o controlado). Custa o cooldown global de itens (3 s)
## e trava os golpes do controlado por 1 GCD. Bloqueado com o controlado exausto (stagger).
func use_item(id: String, m: Mon = null) -> bool:
	if state != "fight" or not is_instance_valid(player):
		return false
	if m == null:
		m = player.mon
	var g := _game()
	if g == null or int(g.bag.get(id, 0)) <= 0:
		say("Acabou %s!" % Dex.item(id).get("name", id), "item")
		return false
	if item_cd > 0.0:
		return false
	if player.stagger_t > 0.0:
		say("Exausto demais para usar item!", "item")
		return false
	var f := _active_fighter_of(m)
	var fx: Dictionary = Dex.item(id).get("effect", {})
	var text := ""
	var before := m.hp
	if f and String(fx.get("cure", "")) == "confusion" and f.confusion_t > 0.0:
		f.confusion_t = 0.0  # confusão só existe na luta: o núcleo não a vê no Mon
		g.take_item(id)
		text = "%s saiu da confusão!" % m.display_name
	else:
		if f:
			m.hp = f.hp
		text = g.use_item(id, m)
		if text == "":
			say("Não vai ter efeito.", "item")
			return false
		if f:
			f.sync_after_item()
	item_cd = ITEM_CD
	player.gcd_t = maxf(player.gcd_t, Dex.GLOBAL_COOLDOWN)
	close_menu()
	say("Usou %s! %s" % [Dex.item(id).get("name", id), text], "item")
	preload("res://audio/cue.gd").sfx("heal")
	if f:
		if m.hp > before:
			f.popup("+%d HP" % (m.hp - before), Color(0.55, 1.0, 0.6), 1.0, 0.5)
		fx_disc(f.position, 0.9, Color(0.6, 1.0, 0.65), 0.5)
	return true


## Melhor item de HP da bolsa para `missing` de HP (o menor que cobre tudo; senão o maior).
func best_heal_item(missing: int) -> String:
	var g := _game()
	if g == null:
		return ""
	var best := ""
	var best_amt := 0
	for id in g.bag:
		if int(g.bag[id]) <= 0:
			continue
		var e: Dictionary = Dex.item(String(id)).get("effect", {})
		if not e.has("hp"):
			continue
		var amt: int = 9999 if str(e.hp) == "full" else int(e.hp)
		if (
			best == ""
			or (amt >= missing and (best_amt < missing or amt < best_amt))
			or (best_amt < missing and amt > best_amt)
		):
			best = String(id)
			best_amt = amt
	return best


## SUPPORT: o aliado usa o melhor item de cura no controlado quando ele cai abaixo de 50% de HP.
func _support_heal() -> void:
	if item_cd > 0.0 or not is_instance_valid(ally) or ally.ai.ally_mode() != BattleAI.SUPPORT:
		return
	if not (
		is_instance_valid(ally)
		and ally.active()
		and ally.can_act()
		and is_instance_valid(player)
		and player.active()
	):
		return
	if float(player.hp) / maxf(player.max_hp, 1) >= SUPPORT_HEAL_AT:
		return
	var id := best_heal_item(player.max_hp - player.hp)
	if id == "":
		return
	var before := player.hp
	player.mon.hp = player.hp
	var text: String = _game().use_item(id, player.mon)
	if text == "":
		return
	player.sync_after_item()
	item_cd = ITEM_CD
	say("%s usou %s! %s" % [ally.mon.display_name, Dex.item(id).get("name", id), text], "item")
	player.popup("+%d HP" % (player.hp - before), Color(0.55, 1.0, 0.6), 1.0, 0.5)
	fx_disc(player.position, 0.9, Color(0.6, 1.0, 0.65), 0.5)


func item_used_by_trainer(f: BattleFighter, item_name: String) -> void:
	if f.side == 0:
		say("%s usou %s!" % [f.mon.display_name, item_name], "item")
		return
	say("%s usou %s em %s!" % [trainer_name(), item_name, f.mon.display_name], "trainer")


# --- Menu rápido (bolsa / party) ---


func open_menu(page: String) -> void:
	if state != "fight":
		return
	menu = page
	menu_sel = 0
	menu_target = int(player.get_meta("party_index", 0)) if is_instance_valid(player) else 0


func close_menu() -> void:
	menu = ""


func _menu_input() -> void:
	if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("pause"):
		close_menu()
		return
	if Input.is_action_just_pressed("swap_mon"):
		open_menu("party" if menu == "bag" else "bag")
		return
	var n := battle_items().size() if menu == "bag" else party.size()
	if Input.is_action_just_pressed("move_forward"):
		menu_sel = wrapi(menu_sel - 1, 0, maxi(n, 1))
	if Input.is_action_just_pressed("move_back"):
		menu_sel = wrapi(menu_sel + 1, 0, maxi(n, 1))
	if menu == "bag":
		if Input.is_action_just_pressed("move_left"):
			menu_target = wrapi(menu_target - 1, 0, maxi(party.size(), 1))
		if Input.is_action_just_pressed("move_right"):
			menu_target = wrapi(menu_target + 1, 0, maxi(party.size(), 1))
		var items := battle_items()
		for k in mini(items.size(), 4):
			if Input.is_action_just_pressed("move_%d" % (k + 1)):
				use_item(items[k], party[menu_target])
				return
		if Input.is_action_just_pressed("jump") and menu_sel < items.size():
			use_item(items[menu_sel], party[menu_target])
	else:
		if Input.is_action_just_pressed("jump") and send_in(menu_sel):
			close_menu()
		elif _ally_mode_pressed() and send_in(menu_sel, true):
			close_menu()


func _menu_text() -> String:
	var g := _game()
	var lines: Array = []
	if menu == "bag":
		var items := battle_items()
		menu_sel = clampi(menu_sel, 0, maxi(items.size() - 1, 0))
		var tgt: Mon = party[clampi(menu_target, 0, party.size() - 1)]
		lines.append(
			"BOLSA   (Tab: equipe)   alvo < %s %d/%d >" % [tgt.display_name, tgt.hp, tgt.max_hp]
		)
		if items.is_empty():
			lines.append("  (no battle items)")
		for k in items.size():
			var id: String = items[k]
			lines.append(
				(
					"%s %s%s x%d"
					% [
						">" if k == menu_sel else " ",
						("%d " % (k + 1)) if k < 4 else "  ",
						Dex.item(id).get("name", id),
						int(g.bag[id])
					]
				)
			)
		lines.append("W/S escolhe  A/D alvo  Espaço/1-4 usa  E fecha")
		if item_cd > 0.0:
			lines.append("Item em %.1fs" % item_cd)
	else:
		lines.append("EQUIPE   (Tab: bolsa)")
		for k in party.size():
			var m: Mon = party[k]
			var tag := ""
			if is_instance_valid(player) and player.mon == m and player.active():
				tag = " [control]"
			elif is_instance_valid(ally) and ally.mon == m and ally.active():
				tag = " [ally]"
			elif m.is_fainted():
				tag = " [fainted]"
			lines.append(
				(
					"%s %s Lv%d %d/%d%s"
					% [">" if k == menu_sel else " ", m.display_name, m.level, m.hp, m.max_hp, tag]
				)
			)
		lines.append(
			(
				"W/S escolhe  Espaço manda"
				+ ("  F send as ally" if _battle_size >= 2 else "")
				+ "  E close"
			)
		)
	return "\n".join(lines)


## Tira o lutador de campo (fica escondido até a arena ser liberada; callbacks pendentes seguem válidos).
func _recall(f: BattleFighter) -> void:
	if vfx and f.visible and f.is_inside_tree():
		vfx.puff(f.to_global(Vector3(0, 0.45, 0)), 1.4)
	f.write_back()
	f.on_field = false
	f.visible = false
	fighters.erase(f)
	if f.side == 0:
		_out.erase(f.mon)  # recolhido (troca ou desmaio): volta para a bola


func run_away() -> bool:
	if state != "fight":
		return false
	if kind != "wild" or not opts.get("can_run", true):
		say(
			(
				"Não! Não dá para fugir de batalha de treinador!"
				if kind != "wild"
				else "Não dá para fugir!"
			)
		)
		return false
	if is_instance_valid(player) and moves.effects.cant_escape(player):
		say("Não dá para fugir: %s está preso!" % player.mon.display_name)
		return false
	say("Fugiu em segurança!")
	preload("res://audio/cue.gd").sfx("run_away")
	_end("run", 0.6)
	return true


## Estado do jogador (bolsa). opts.game permite injetar uma instância de core/game.gd nos testes.
func _game() -> Node:
	var g = opts.get("game")
	if g is Node and is_instance_valid(g):
		return g
	return get_node_or_null("/root/Game") if is_inside_tree() else null


func _pick_ball() -> String:
	var g := _game()
	if g == null:
		return String(opts.get("ball", "poke_ball"))
	# A bola escolhida na Bolsa (Game.flags.selected_ball) vem primeiro, se ainda houver.
	var flags = g.get("flags")
	var chosen := String(flags.get("selected_ball", "")) if flags is Dictionary else ""
	if chosen != "" and int(g.bag.get(chosen, 0)) > 0:
		return chosen
	var order: Array = BALL_ORDER.duplicate()
	for id in Capture.ball_ids():
		if not order.has(id):
			order.append(id)
	for id in order:
		if int(g.bag.get(id, 0)) > 0:
			return id
	return ""


func throw_ball() -> bool:
	if training and state == "fight":
		say("É um boneco: Poké Bolas não adiantam!", "item")
		return false
	if (
		state != "fight"
		or kind != "wild"
		or not is_instance_valid(enemy)
		or not enemy.active()
		or not player.alive()
	):
		if kind != "wild" and state == "fight":
			say("O treinador bloqueou a bola! Não seja ladrão!", "trainer")
		return false
	var ball_id := _pick_ball()
	if ball_id == "":
		say("Você não tem Poké Balls!", "item")
		return false
	var g := _game()
	if g:
		g.take_item(ball_id)
	var res := Capture.throw_ball(
		enemy.max_hp, enemy.hp, enemy.mon.catch_rate(), ball_id, enemy.status, enemy.level
	)
	var ball := PokeBall3D.for_item(Dex.item(ball_id))
	add_child(ball)
	var from := player.position + Vector3(0, player.look_h, 0)
	ball.position = from
	_capture = {
		"ball": ball,
		"id": ball_id,
		"res": res,
		"from": from,
		"to": enemy.position + Vector3(0, 0.16, 0),
		"shown": mini(int(res.shakes), 3)
	}
	say("Você jogou uma %s!" % Dex.item(ball_id).get("name", "Poké Ball"), "item")
	preload("res://audio/cue.gd").sfx("ball_throw")
	state = "capture"
	_state_t = 0.0
	return true


func _capture_step(_dt: float) -> void:
	var ball: PokeBall3D = _capture.ball
	var t := _state_t
	if t < BALL_FLIGHT:
		var s := t / BALL_FLIGHT
		ball.position = (
			_capture.from.lerp(_capture.to, s) + Vector3(0, 1.2 * 4.0 * s * (1.0 - s), 0)
		)
		ball.set_spin(-s * TAU * 2.0)
		return
	ball.set_spin(0.0)
	var shake_t := t - BALL_FLIGHT
	var shown: int = _capture.shown
	if shown > 0 and shake_t < BALL_ABSORB:
		# Só visual: a bola paira, abre e puxa o Pokémon (encolhe e fica vermelho).
		var k := shake_t / BALL_ABSORB
		ball.position = _capture.to + Vector3(0, 0.35 * (1.0 - k), 0)
		ball.set_lid(1.0 - absf(k * 2.0 - 1.0))
		ball.set_glow(Color(1, 0.3, 0.3), 3.0 * (1.0 - k))
		if enemy.look:
			enemy.look.scale_mult = lerpf(1.0, 0.05, k)
			enemy.look.tint = Color(1, 1, 1).lerp(Color(3, 0.5, 0.5), k)
		if k > 0.9:
			enemy.visible = false
		return
	enemy.visible = false
	ball.position = _capture.to
	ball.set_lid(0.0)
	if shake_t < shown * BALL_SHAKE:
		var ph := fmod(shake_t, BALL_SHAKE) / BALL_SHAKE
		if ph * BALL_SHAKE < _dt:
			preload("res://audio/cue.gd").sfx("ball_shake")
		ball.set_wobble(sin(ph * TAU) * 0.45 if ph < 0.5 else 0.0)
		ball.set_glow(Color(1, 0.2, 0.15), 2.5 if ph < 0.5 else 0.0)
		return
	ball.set_wobble(0.0)
	ball.set_glow(Color.WHITE, 0.0)
	if _capture.res.caught:
		enemy.mon.ball = _capture.id
		# O original (progression.gd:94-100): com a equipe cheia avisa que foi para o PC.
		var nm := enemy.mon.display_name
		var line := "Peguei! %s foi capturado!" % nm
		if _party_full():
			line += " %s foi mandado para o PC." % nm
		hud.banner(line, 2.0)
		say(line, "catch")
		# Jingle de captura do original (music/caught); sem ele, o efeito antigo.
		var au := preload("res://audio/cue.gd").audio()
		if au and au.has_method("has_sfx") and au.has_sfx("caught"):
			au.stop_music(0.3)
			au.sfx("caught")
		else:
			preload("res://audio/cue.gd").sfx("catch_ok")
		ball.set_glow(Color(1, 1, 0.8), 4.0)
		if vfx and ball.is_inside_tree():
			var at := ball.global_position + Vector3(0, 0.25, 0)
			vfx.sparkle(at, 1.6)
			vfx.pmd("swift_star", at, Vector3.FORWARD, {"scale": 1.2, "billboard": true})
		_end("caught", 1.6, {"caught_mon": enemy.mon})
		return
	ball.queue_free()
	enemy.visible = true
	if enemy.look:
		enemy.look.scale_mult = 1.0
	if vfx and enemy.is_inside_tree():
		vfx.puff(enemy.to_global(Vector3(0, 0.5, 0)), 1.8)
	say(Capture.fail_line(int(_capture.res.shakes)), "catch")
	preload("res://audio/cue.gd").sfx("catch_fail")
	_capture = {}
	state = "fight"
	_state_t = 0.0


# --- Desmaio, XP e fim ---


func _on_fainted(f: BattleFighter) -> void:
	if state == "ending" or state == "done":
		return
	later(
		FAINT_CLEAR,
		func() -> void:
			if is_instance_valid(f) and not f.alive():
				f.on_field = false
				f.visible = false
	)
	if f.side == 1:
		_enemy_fainted(f)
	else:
		_player_fainted(f)


func _enemy_fainted(f: BattleFighter) -> void:
	var killer := f.last_hit_by
	if is_instance_valid(killer) and killer.side == 0 and _rewards():
		var got := killer.mon.add_evs(f.mon.ev_yield())
		if not got.is_empty():
			_sync_from_mon(killer)
	_award_exp(f.mon)
	var nxt := _next_enemy(enemy_index)
	var slot := 1 if f == enemy2 else 0
	if doubles and nxt >= 0:
		_enemy_reserved.append(enemies[nxt])  # reservado: o outro desmaio não manda o mesmo
		_enemy_pending += 1
		say("Volte, %s!" % f.mon.display_name, "trainer")
		later(
			RECALL_SECS,
			func() -> void:
				if fighters.has(f):
					_recall(f)
		)
		# O substituto entra no fim da rodada (oficial); a IA do treinador pode escolher outro.
		later(RECALL_SECS, func() -> void: at_round_end(_enemy_refill.bind(nxt, slot)))
		return
	if doubles and _enemy_pending == 0:
		_last_stand(f)
	if doubles and (_enemy_pending > 0 or _other_enemy_up(f)):
		say("%s de %s desmaiou!" % [f.mon.display_name, trainer_name()], "trainer")
		if f == enemy and is_instance_valid(enemy2) and enemy2.active() and _enemy_pending == 0:
			enemy = enemy2
			enemy2 = null
		_bind()
		return
	if kind == "trainer" and nxt >= 0:
		# O original (_send_trainer_mon): "Come back, X!" e recolhe; no fim da rodada
		# "<NOME> vai mandar Y!" e a bola.
		_enemy_reserved.append(enemies[nxt])
		_enemy_pending += 1
		say("Volte, %s!" % f.mon.display_name, "trainer")
		later(
			RECALL_SECS,
			func() -> void:
				if fighters.has(f):
					_recall(f)
		)
		later(RECALL_SECS, func() -> void: at_round_end(_enemy_refill.bind(nxt, 0)))
		return
	say(
		(
			("%s selvagem desmaiou!" % f.mon.display_name)
			if kind == "wild"
			else ("%s de %s desmaiou!" % [f.mon.display_name, trainer_name()])
		),
		"info" if kind == "wild" else "trainer"
	)
	_end("win", 2.0)


## Substituto do adversário (fim da rodada): o escolhido pela IA do treinador ou o reservado; anuncia
## e manda depois de NEXT_TRAINER_MON s.
func _enemy_refill(nxt: int, slot: int) -> void:
	_enemy_reserved.erase(enemies[nxt])
	var pick := _replacement(1, slot, nxt) if state == "fight" else nxt
	if pick < 0 or enemies[pick].is_fainted():
		pick = nxt
	_enemy_reserved.append(enemies[pick])
	var line := "%s vai mandar %s!" % [trainer_name(), enemies[pick].display_name]
	hud.banner(line, NEXT_TRAINER_MON)
	say(line, "trainer")
	later(
		NEXT_TRAINER_MON,
		func() -> void:
			_enemy_pending -= 1
			_enemy_reserved.erase(enemies[pick])
			if state == "fight":
				_send_enemy(pick, slot)
	)


## Dupla: quem fica sozinho em campo ganha +1 de Ataque e At. Esp. ("Última esperança!").
func _last_stand(f: BattleFighter) -> void:
	var p := f.ai.partner() if f.ai else null
	if p == null or p.has_meta("last_stand"):
		return
	p.set_meta("last_stand", true)
	moves.change_stage(p, "atk", 1)
	moves.change_stage(p, "spa", 1)
	p.popup("Última esperança!", Color(1, 0.8, 0.4), 1.2, 1.1)


func _other_enemy_up(f: BattleFighter) -> bool:
	for e in [enemy, enemy2]:
		if is_instance_valid(e) and e != f and e.active():
			return true
	return false


## EXP sem aviso na hora (o original: Progression.award_exp(..., quiet = true)); o fim da batalha mostra
## a última leva em _build_results, como o _results_sequence do original.
func _award_exp(defeated: Mon) -> void:
	_last_exp = []
	if not _rewards():
		return
	var receivers: Array = _participants.values().filter(func(m): return not m.is_fainted())
	if receivers.is_empty():
		return
	for m in receivers:
		var amount := maxi(
			1, int(defeated.exp_yield(m.level, kind == "trainer") / float(receivers.size()))
		)
		var events: Array = m.add_exp(amount)
		var entry := {"mon": m, "amount": amount, "events": events}
		exp_log.append(entry)
		_last_exp.append(entry)
		var f := _fighter_of(m)
		if f:
			_sync_from_mon(f)


# --- Evolução no meio da luta ---


## progression.gd check_evolutions (a cada 0,4 s): só o controlado evolui em batalha, fora de menu e
## captura. Na selvagem o último desmaio já leva ao fim (Battle._ending), então ela fica para o mundo;
## na de treinador, com mais Pokémon dele, evolui aqui e a luta continua com a forma nova.
func _check_evolution(raw: float) -> void:
	_evo_check_t -= raw
	if _evo_check_t > 0.0:
		return
	_evo_check_t = EVO_CHECK
	if state != "fight" or menu != "" or pause_open or not _rewards():
		return
	var f := player
	if not is_instance_valid(f) or not f.active() or f.mon.evolution_target() == "":
		return
	var g := _game()
	var ui := get_node_or_null(EVOLUTION) if is_inside_tree() else null
	if (
		g == null
		or ui == null
		or not g.has_method("resolve_evolution")
		or not ui.has_method("begin_on")
	):
		return
	var o := {"driven": true, "auto": _auto_confirm(), "popup": _evolution_popup}
	if not ui.begin_on(f.mon, f.look, g, o):
		return
	_evo = ui
	_evo_f = f
	# creature.gd com evolving: parado, sem investida; take_damage "No effect!" (aqui a luta toda para).
	f.evolving = true
	f.velocity = Vector3.ZERO
	f.sprinting = false
	f.dash_t = 0.0
	f.lunge_t = 0.0
	ui.finished.connect(_on_evolution_finished, CONNECT_ONE_SHOT)


## A luta parada (moves.gd hit e creature.gd voltam cedo com pause_for_evolution); só a evolução anda.
func _evolution_step(raw: float) -> void:
	if not is_instance_valid(_evo):
		_on_evolution_finished(false)
		return
	_evo.tick(raw)


func _evolution_popup(text: String, col: Color, k: float) -> void:
	if is_instance_valid(_evo_f):
		_evo_f.popup(text, col, k, 0.6)


func _on_evolution_finished(evolved: bool) -> void:
	var f := _evo_f
	_evo = null
	_evo_f = null
	if not is_instance_valid(f):
		return
	f.evolving = false
	if evolved:
		f.refresh_species()
		_sync_from_mon(f)


# --- Resultado do fim (EXP, nível, prêmio) ---


## Passos do _results_sequence do original para a última leva de EXP e o prêmio. Cada passo:
## {mon?, start? (xp de partida), fill? (xp alvo), level?, text?, kind?, sfx?, confirm?, end?}.
func _build_results() -> Array:
	var out: Array = []
	for r in _last_exp:
		var m: Mon = r.mon
		if _fighter_of(m) == null:
			continue  # sem cartão em campo: o original pula (card_for == null)
		var gain := int(r.amount)
		out.append(
			{
				"mon": m,
				"start": float(m.xp - gain),
				"text": "%s ganhou %d de EXP." % [m.display_name, gain],
				"kind": "exp"
			}
		)
		var evs: Array = r.events
		var ei := 0
		while ei < evs.size():
			var e: Dictionary = evs[ei]
			ei += 1
			if e.type != "level":
				continue
			var lv := int(e.level)
			out.append(
				{
					"mon": m,
					"fill": float(Growth.exp_for_level(m.growth, lv)),
					"level": lv,
					"text": "%s subiu para o Nv %d!" % [m.display_name, lv],
					"kind": "level",
					"sfx": "level_up",
					"confirm": true
				}
			)
			while ei < evs.size() and evs[ei].type == "move":
				var me: Dictionary = evs[ei]
				ei += 1
				if me.learned:
					var mv := String(Dex.move(me.move).get("name", me.move))
					out.append(
						{
							"mon": m,
							"text": "%s aprendeu %s!" % [m.display_name, mv],
							"kind": "level",
							"confirm": true
						}
					)
		out.append({"mon": m, "fill": float(m.xp), "confirm": true, "end": true})
	var prize := _prize()
	if prize > 0:
		out.append(
			{"text": "Você ganhou ₽%d pela vitória!" % prize, "kind": "money", "confirm": true}
		)
	return out


## Prêmio da vitória contra treinador (o mesmo cálculo de Game._finish, que é quem paga).
func _prize() -> int:
	if kind != "trainer" or enemies.is_empty() or not _rewards():
		return 0
	var g := _game()
	if g == null or not g.has_method("trainer_payout"):
		return 0
	return int(g.trainer_payout(String(opts.get("trainer_id", "")), int(enemies[-1].level)))


func _party_full() -> bool:
	var g := _game()
	if g == null:
		return false
	var cap := int(g.get("PARTY_MAX")) if g.get("PARTY_MAX") != null else 6
	return g.party.size() >= cap


## Sem jogador (testes, autoplay) a confirmação passa sozinha, como o original com Debug.auto_dialog.
func _auto_confirm() -> bool:
	return manual or bool(opts.get("autoplay", false))


func _confirm_pressed() -> bool:
	return (
		not manual
		and (Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_accept"))
	)


## Um quadro da sequência de resultado. true quando acabou e a batalha terminou.
func _results_step(raw: float) -> bool:
	if _beat.is_empty():
		if _results.is_empty():
			_xp_shown = -1.0
			hud.log_hint("")
			_finish()
			return true
		_beat = _results.pop_front()
	var b := _beat
	var m: Mon = b.get("mon")
	if not b.has("_go"):
		b["_go"] = true
		if b.has("start"):
			_xp_shown = float(b.start)
			_xp_level = Growth.level_for_exp(m.growth, int(_xp_shown))
		if b.has("text") and not b.has("fill"):
			say(String(b.text), String(b.get("kind", "info")))
	if b.has("fill") and not b.has("_filled"):
		var target := float(b.fill)
		var lv := Growth.level_for_exp(m.growth, int(_xp_shown))
		var span := float(
			Growth.exp_for_level(m.growth, lv + 1) - Growth.exp_for_level(m.growth, lv)
		)
		_xp_shown = minf(_xp_shown + maxf(span, 1.0) / EXP_LEVEL_SECS * raw, target)
		if _xp_shown < target and not _confirm_pressed():
			return false
		_xp_shown = target
		b["_filled"] = true
		if b.has("level"):
			_xp_level = int(b.level)
		if b.has("sfx"):
			preload("res://audio/cue.gd").sfx(String(b.sfx))
		if b.has("text"):
			say(String(b.text), String(b.get("kind", "info")))
		b["_t"] = 0.0
		return false  # o E que pulou o enchimento não confirma a linha
	if b.get("confirm", false):
		b["_t"] = float(b.get("_t", 0.0)) + raw
		hud.log_hint("E", "continuar")
		var done := (
			float(b._t) >= RESULT_AUTO
			if _auto_confirm()
			else (float(b._t) > 0.0 and _confirm_pressed())
		)
		if not done:
			return false
		hud.log_hint("")
	if b.get("end", false):
		_xp_shown = -1.0
	_beat = {}
	return false


func _fighter_of(m: Mon) -> BattleFighter:
	return _active_fighter_of(m)


## Depois de XP/EV o Mon recalcula stats; o lutador em campo acompanha.
func _sync_from_mon(f: BattleFighter) -> void:
	f.level = f.mon.level
	for k in StatCalc.STATS:
		f.stats[k] = f.mon.stat(k)
	f.max_hp = f.mon.max_hp
	f.hp = clampi(f.mon.hp, 0, f.max_hp)
	f.refresh_label()


func _player_fainted(f: BattleFighter) -> void:
	if f.mon.has_method("set_friend"):
		f.mon.set_friend(f.mon.friend - FAINT_LOSS)
	say("%s desmaiou!" % f.mon.display_name, "faint")
	if doubles and _doubles_refill(f):
		return
	if doubles:
		_last_stand(f)
	if f == ally or (f == player and is_instance_valid(ally) and ally.active()):
		# Ainda sobra um mon em campo: se era o controlado, o controle passa para o aliado. Ninguém novo entra.
		if f == player:
			player = ally
			player.controller = _player_ctrl()
			player.sprinting = false
			player.popup("Vai, %s!" % player.mon.display_name, Color(0.7, 0.9, 1.0), 1.0, 0.8)
		ally = null
		if menu != "" and not is_instance_valid(player):
			close_menu()
		_bind()
		later(
			FAINT_CLEAR,
			func() -> void:
				if is_instance_valid(f) and fighters.has(f):
					_recall(f)
		)
		return
	var nxt := _next_healthy(int(f.get_meta("party_index", 0)))
	if nxt < 0:
		say("Você não tem mais Pokémon para lutar!", "faint")
		_end("lose", 2.0)
		return
	var at := f.position
	at.y = 0.0
	var m_next: Mon = party[nxt]
	_pending.append(m_next)
	later(
		FAINT_CLEAR,
		func() -> void:
			if fighters.has(f):
				_recall(f)
			at_round_end(
				func() -> void:
					_pending.erase(m_next)
					if state != "fight":
						return
					var k := _replacement(0, 0, party.find(m_next))
					_send_player(k if not party[k].is_fainted() else party.find(m_next), at)
			)
	)


## 2x2: o lugar de quem desmaiou é preenchido pelo próximo da equipe (o outro segue lutando).
## false = ninguém para entrar (segue a regra de sempre).
func _doubles_refill(f: BattleFighter) -> bool:
	var nxt := _next_healthy(int(f.get_meta("party_index", 0)))
	if nxt < 0:
		return false
	var m: Mon = party[nxt]
	_pending.append(m)
	var as_ally := f == ally
	if f == player and is_instance_valid(ally) and ally.active():
		# O controle passa para quem ficou; o novo entra no lugar do aliado.
		player = ally
		player.controller = _player_ctrl()
		ally = null
		as_ally = true
	var at := f.position
	at.y = 0.0
	later(
		FAINT_CLEAR,
		func() -> void:
			if fighters.has(f):
				_recall(f)
			at_round_end(
				func() -> void:
					_pending.erase(m)
					if state != "fight" or m.is_fainted():
						return
					var k := _replacement(0, 1 if as_ally else 0, party.find(m))
					if party[k].is_fainted():
						k = party.find(m)
					if as_ally and is_instance_valid(player) and player.active():
						_send_ally(k, at)
					else:
						_send_player(k, at)
			)
	)
	_bind()
	return true


func _end(outcome: String, delay: float, extra := {}) -> void:
	if outcome == "win" and _rewards() and not training:
		for m in _participants.values():
			if not m.is_fainted():
				m.set_friend(m.friend + FRIEND_WIN)
	result = {"outcome": outcome}
	result.merge(extra)
	state = "ending"
	_state_t = 0.0
	_end_delay = delay


func _finish() -> void:
	state = "done"
	clear_tut_lock()
	for f in fighters:
		if is_instance_valid(f):
			f.write_back()
	for p in projectiles:
		p.queue_free()
	projectiles.clear()
	_events.clear()
	if field:
		field.clear()
	if _capture.has("ball") and is_instance_valid(_capture.ball):
		_capture.ball.queue_free()
	if vfx:
		vfx.clear()
	result["exp"] = exp_log
	if _track_out:
		result["out_mons"] = _out.filter(func(m): return not m.is_fainted())
	if is_instance_valid(_prev_cam) and _prev_cam.is_inside_tree():
		_prev_cam.make_current()
	elif _cam:
		_cam.clear_current(false)
	if hud:
		hud.visible = false
	finished.emit(result)


# --- Câmera ---


func _update_camera(dt: float) -> void:
	if _cam == null:
		return
	if fixed:
		# Como o original numa quadra fixa: câmera parada (focus_fixed), sem giro manual.
		var off := Vector3(0, sin(FIXED_CAM_PITCH), cos(FIXED_CAM_PITCH)) * FIXED_CAM_DIST
		_cam.position = _cam.position.lerp(
			_cam_focus + off.rotated(Vector3.UP, _yaw), clampf(dt * 6.0, 0.0, 1.0)
		)
		if _cam.is_inside_tree():
			_cam.look_at(to_global(_cam_focus), Vector3.UP)
		return
	if not is_instance_valid(player):
		return
	var focus := player.position * Vector3(1, 0, 1)
	var look := focus
	if is_instance_valid(enemy) and enemy.on_field:
		look = focus.lerp(enemy.position * Vector3(1, 0, 1), 0.35)
	var want := focus + Vector3(0, CAM_HEIGHT, CAM_DIST).rotated(Vector3.UP, _yaw)
	_cam.position = _cam.position.lerp(want, clampf(dt * 6.0, 0.0, 1.0))
	if _cam.position.distance_to(look) > 0.1 and _cam.is_inside_tree():
		_cam.look_at(to_global(look + Vector3(0, 0.6, 0)), Vector3.UP)


# --- Efeitos placeholder ---


## Mensagem da faixa de log da batalha (o original: battle_log.gd recebe todo Game._msg na batalha).
## kind dá a cor da marca: info, move, faint, exp, level, money, catch, item, trainer.
func say(text: String, kind_name := "info") -> void:
	log_lines.append(text)
	if log_lines.size() > LOG_MAX:
		log_lines.pop_front()
	if hud:
		hud.log_push(text, kind_name)


## O original (battle_log.gd _on_move_used): "X usou Y!" para golpe do adversário e golpe de status.
func on_move_used(user: BattleFighter, mv: Dictionary) -> void:
	if user.side == 1 or String(mv.get("category", "")) == "status":
		say(
			"%s usou %s!" % [user.mon.display_name, String(mv.get("name", mv.get("id", "")))],
			"move"
		)
	if combos:
		combos.on_move_used(user, mv)
	if hud and hud.has_method("callout"):
		hud.callout(
			user,
			String(mv.get("name", mv.get("id", ""))),
			Dex.type_color(String(mv.get("type", "normal")))
		)
	move_used.emit(user, mv)


## Popup de batalha: vai para o log e para o HUD (em tela, ancorado em `at`, local da arena).
func popup(at: Vector3, text: String, col: Color, scale_k := 1.0, style := "") -> void:
	log_lines.append(text)
	if log_lines.size() > LOG_MAX:
		log_lines.pop_front()
	if hud and is_inside_tree():
		hud.add_popup(to_global(at), text, col, scale_k, style)


func _fx_node(mesh: Mesh, xf: Transform3D, col: Color, life: float) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	col.a = minf(col.a, 0.6)
	mat.albedo_color = col
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = xf
	add_child(mi)
	_fx.append(
		{"node": mi, "t": maxf(life, 0.05), "life": maxf(life, 0.05), "mat": mat, "a": col.a}
	)


func fx_disc(center: Vector3, radius: float, col: Color, life: float) -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 0.02
	cm.radial_segments = 32
	_fx_node(cm, Transform3D(Basis(), Vector3(center.x, 0.04, center.z)), col, life)


func fx_cone(origin: Vector3, dir: Vector3, r: float, half: float, col: Color, life: float) -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = r * tan(minf(half, 1.3))
	cm.height = r
	cm.radial_segments = 16
	var yv := -dir.normalized()
	var xv := yv.cross(Vector3.UP)
	xv = xv.normalized() if xv.length() > 0.01 else Vector3.RIGHT
	var zv := xv.cross(yv)
	var b := Basis(xv, yv, zv.normalized() * 0.25)
	col.a = 0.35
	_fx_node(cm, Transform3D(b, origin + dir * r * 0.5), col, life)


func fx_beam(
	origin: Vector3, dir: Vector3, length: float, width: float, col: Color, life: float
) -> void:
	if length <= 0.01:
		return
	var bm := BoxMesh.new()
	bm.size = Vector3(width, 0.15, length)
	var b := (
		Basis.looking_at(dir.normalized(), Vector3.UP)
		if absf(dir.normalized().y) < 0.99
		else Basis()
	)
	_fx_node(bm, Transform3D(b, origin + dir.normalized() * length * 0.5), col, life)


func spawn_projectile(
	user: BattleFighter,
	mv: Dictionary,
	dir: Vector3,
	homing: bool,
	miss: BattleFighter,
	target: BattleFighter
) -> void:
	var p := BattleProjectile.new()
	add_child(p)
	p.setup(user, mv, dir, homing, miss, target)
	projectiles.append(p)


func _tick_fx(dt: float) -> void:
	for e in _fx.duplicate():
		e.t -= dt
		if e.t <= 0.0:
			e.node.queue_free()
			_fx.erase(e)
		else:
			e.mat.albedo_color.a = e.a * clampf(e.t / minf(e.life, 0.2), 0.0, 1.0)

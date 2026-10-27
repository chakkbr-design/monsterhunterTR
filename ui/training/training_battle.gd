extends Node3D
## Modo de treinamento: a luta automática entre os dois times montados em training_setup.
## Arena fixa de Cfg.ARENA (48 x 28, em voxel, com relevo), as duas IAs lutando sozinhas
## (opts.autoplay), sem mexer no save nem na equipe do jogo. Com p1_control "manual" o Time A é
## do teclado (só na luta única; a série sempre roda com IA). No fim mostra o vencedor e o
## placar da série.
## Fora do fast_sim a quadra fica dentro de um estádio voxel (ArenaStadium:
## arquibancadas com torcida, refletores, placares ao vivo, céu e luz pela hora "time_of_day"),
## montado uma vez por cena e repintado pelo cenário de cada luta.
## Esc para a luta e volta para a tela de montar.

const Cfg := preload("res://ui/training/training_config.gd")
const Kit := preload("res://ui/ui_kit.gd")
const ARENA_SCENE := "res://battle/battle_arena.tscn"
const SETUP_SCENE := "res://ui/training/training_setup.tscn"
const TITLE_SCENE := "res://ui/front/title.tscn"
## A câmera fixa da arena (14 m, fov 30) foi feita para a quadra de 10 x 6; esta é bem maior:
## a câmera abre o fov, se afasta na proporção da quadra (14 m para 16 de largura) e olha um pouco
## para cá do centro, para os quatro cantos e os treinadores caberem na tela.
const CAM_FOV := 60.0
const CAM_FOCUS := Vector3(0, 0, Cfg.ARENA.y * 0.2)
const CAM_DIST := 14.0 * Cfg.ARENA.x / 16.0
## Chão de fora da quadra voxel (até o horizonte da câmera de ação).
const GROUND_ENERGY := Vector2(420, 300)
const CAM_PITCH := deg_to_rad(30.0)
const GROUND := Color(0.36, 0.55, 0.3)
## Primeira ola da torcida (segundos de luta) e o intervalo entre as outras
## (WAVE_GAP .. +WAVE_JITTER).
const WAVE_FIRST := 12.0
const WAVE_GAP := 45.0
const WAVE_JITTER := 30.0

## Placar da série enquanto a config não muda (sobrevive a "Repeat").
## Com semente fixa, a luta k da série usa semente + k (n): nunca repete uma luta já contada.
static var series := {"key": "", "a": 0, "b": 0, "draw": 0, "n": 0}
## Série com times sorteados a cada luta (Cfg.randomize_sides, pela semente da luta).
static var random_series := false

var cfg := {}
var arena: Node3D
var team_a: Array = []
var team_b: Array = []
var result := {}
var fight_time := 0.0
## Semente da luta atual (mostrada no resultado para reproduzir a luta).
var last_seed := 0
## Passos da arena por quadro de física (velocidade acima de 1x, turbo).
var steps := 1
## Lutas que ainda faltam na série automática (0 = para no fim desta).
var auto_left := 0
## Luta da série (Rodar série): todas as lutas dela rodam com IA, mesmo com Jogador 1 manual.
var _series := false
## Esta série sorteia os times antes de cada luta.
var _random := false
var _ui: CanvasLayer
var _info: Label
var _result_box: Control
var _stop: Button
var _last_log: Array = []
var _stage_cam: Camera3D
## Quadra voxel: o piso, as linhas e a cerca vêm de ArenaFloor (BattleTerrain); aqui só o chão de fora
## e a câmera do cenário.
var _ground_mat: StandardMaterial3D
## Estádio voxel em volta da quadra (ArenaStadium: arquibancadas, torcida, refletores, placar, céu e
## luz). Nunca no fast_sim.
var _stadium: ArenaStadium
## Pokémon desmaiados de cada time (a torcida do outro lado comemora quando sobe) e segundos de luta
## até a próxima ola.
var _down := [0, 0]
var _wave_in := WAVE_FIRST
## Texto grande no telão durante a abertura da luta ("VS", "FIGHT!"; arena.opening_beat).
var _headline := ""


func _ready() -> void:
	Cfg.block_pause_menu(get_tree(), true)
	cfg = Cfg.current if not Cfg.current.is_empty() else Cfg.load_config()
	var key := JSON.stringify(cfg)
	if String(series.key) != key:
		series = {"key": key, "a": 0, "b": 0, "draw": 0, "n": 0}
	# Atrás da tela de load da preparação (janela de verdade), o estádio monta numa thread e a bola
	# continua animando; parado até lá. Headless (testes): monta aqui mesmo, como antes.
	var built: ArenaStadium = null
	var so := _stadium_opts()
	if not so.is_empty() and Loading.busy() and VoxelZone.threaded_load():
		process_mode = Node.PROCESS_MODE_DISABLED
		var box := []
		var task := WorkerThreadPool.add_task(func(): box.append(ArenaStadium.build(so)))
		while not WorkerThreadPool.is_task_completed(task):
			await get_tree().process_frame
		WorkerThreadPool.wait_for_task_completion(task)
		built = box[0]
		process_mode = Node.PROCESS_MODE_INHERIT
	_build_stage(built)
	_build_ui()
	start_fight()
	Loading.end_later("scene", 3)  # the setup screen's loading screen (see Loading)


func _exit_tree() -> void:
	Cfg.block_pause_menu(get_tree(), false)


# --- Cenário ---


## Opções do estádio (ArenaStadium.build); vazio quando não há estádio (fast_sim).
func _stadium_opts() -> Dictionary:
	var extra = cfg.get("extra_opts", {})
	var fast: bool = extra is Dictionary and bool(extra.get("fast_sim", false))
	if fast:
		return {}
	return {"mood": Cfg.time_of_day(cfg), "names": [Cfg.side_name(cfg, 0), Cfg.side_name(cfg, 1)]}


## `built`: o estádio já montado (numa thread, _ready); null monta aqui.
func _build_stage(built: ArenaStadium = null) -> void:
	var so := _stadium_opts()
	if not so.is_empty():
		# Estádio com céu, sol, ambiente (AgX, SSAO, brilho) e luzes próprios; vento para bandeiras
		# e grama.
		_stadium = built if built else ArenaStadium.build(so)
		add_child(_stadium)
		var wind := WorldWind.new()
		wind.name = "Wind"
		add_child(wind)
	else:
		var env := WorldEnvironment.new()
		env.environment = Environment.new()
		env.environment.background_mode = Environment.BG_COLOR
		env.environment.background_color = Color(0.55, 0.72, 0.92)
		env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.environment.ambient_light_color = Color(0.62, 0.62, 0.68)
		add_child(env)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-55, 30, 0)
		sun.shadow_enabled = true
		add_child(sun)
		_ground_mat = _ground_ring()
	# Câmera do cenário no mesmo ponto da câmera fixa da arena: a arena a devolve no fim da luta.
	_stage_cam = Camera3D.new()
	_stage_cam.fov = CAM_FOV
	_stage_cam.position = cam_focus() + Vector3(0, sin(CAM_PITCH), cos(CAM_PITCH)) * cam_dist()
	add_child(_stage_cam)
	_stage_cam.look_at(cam_focus(), Vector3.UP)
	_stage_cam.make_current()


## Distância e foco da câmera fixa (a do cenário e a da arena quando não há câmera de ação).
func cam_dist() -> float:
	return CAM_DIST


func cam_focus() -> Vector3:
	return CAM_FOCUS


## Chão de fora da quadra voxel: GROUND_ENERGY menos o piso voxel (a quadra e ArenaFloor.MARGIN m
## em volta). Por baixo do piso não fica nada: os lagos e canais abertos nele mostram o fundo voxel.
func _ground_ring() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = GROUND
	mat.roughness = 1.0
	var inner := Cfg.ARENA * 0.5 + Vector2.ONE * (ArenaFloor.MARGIN - 0.25)
	var outer := GROUND_ENERGY * 0.5
	# Faixas de trás e da frente (largura toda) e dos lados (entre elas).
	var strips := [
		[Vector2(0, -(outer.y + inner.y) * 0.5), Vector2(outer.x * 2.0, outer.y - inner.y)],
		[Vector2(0, (outer.y + inner.y) * 0.5), Vector2(outer.x * 2.0, outer.y - inner.y)],
		[Vector2(-(outer.x + inner.x) * 0.5, 0), Vector2(outer.x - inner.x, inner.y * 2.0)],
		[Vector2((outer.x + inner.x) * 0.5, 0), Vector2(outer.x - inner.x, inner.y * 2.0)],
	]
	for st in strips:
		var mi := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = st[1]
		pm.material = mat
		mi.mesh = pm
		mi.position = Vector3(st[0].x, -0.01, st[0].y)
		add_child(mi)
	return mat


## Nome do cenário da luta atual ("" sem relevo).
func scenario() -> String:
	if not is_instance_valid(arena) or arena.get("terrain") == null:
		return ""
	return String(arena.terrain.scenario)


## Pinta o estádio (ou o chão de fora) com as cores do cenário sorteado ou escolhido.
func _paint_stage() -> void:
	if _stadium:
		_stadium.theme(scenario())
	elif _ground_mat:
		# Em volta do piso voxel: a calçada do cenário, um pouco mais escura longe da quadra.
		var sc := scenario() if scenario() != "" else "campo"
		var p := ArenaPalette.of(sc)
		_ground_mat.albedo_color = Color(p.surround).darkened(0.12)


# --- Luta ---


func start_fight() -> void:
	_drop_arena()
	_result_box.visible = false
	result = {}
	fight_time = 0.0
	var o := Cfg.arena_opts(cfg, global_position)
	last_seed = int(o.seed) + int(series.n) if o.has("seed") else randi()
	if _random:
		var rng := RandomNumberGenerator.new()
		rng.seed = last_seed
		Cfg.randomize_sides(cfg, rng)
		Cfg.current = cfg
		series.key = JSON.stringify(cfg)
		o = Cfg.arena_opts(cfg, global_position)
	team_a = Cfg.build_side(cfg, 0)
	team_b = Cfg.build_side(cfg, 1)
	_down = [0, 0]
	_wave_in = WAVE_FIRST
	if _series:
		o.merge({"autoplay": true, "auto_battle": true, "keyboard": false}, true)
	o.seed = last_seed
	# Câmera de ação (BattleDirector): enquadra a ação, KO em câmera lenta e
	# todo mundo parado na troca. A bateria (fast_sim) não tem câmera.
	o["action_cam"] = true
	# Abertura (BattleOpening, só com a câmera de ação): os nomes no telão, a arena inteira, os
	# treinadores jogam os titulares e só então a luta começa. Sem efeito no fast_sim.
	if not o.has("opening"):
		o["opening"] = true
	o["opening_names"] = [Cfg.side_name(cfg, 0), Cfg.side_name(cfg, 1)]
	if _stadium:
		o["opening_screen"] = _stadium.screen_corners()
	_headline = ""
	# Acima de 1x a arena anda em vários passos de no máximo 1x por quadro: um passo grande faria
	# golpes rápidos atravessarem o alvo e mudaria o resultado da luta.
	var turbo := bool(cfg.get("turbo", false))
	var spd := float(o.speed)
	steps = Cfg.TURBO_STEPS if turbo else maxi(1, ceili(spd))
	o.speed = 1.0 if turbo else spd / steps
	arena = load(ARENA_SCENE).instantiate()
	arena.manual = true
	add_child(arena)
	arena.finished.connect(_on_finished)
	if arena.has_signal("opening_beat"):
		arena.opening_beat.connect(_on_opening_beat)
	arena.start(team_a, team_b, o)
	_paint_stage()
	_fit_camera()
	var help = arena.hud.get("_help") if arena.get("hud") else null
	if help is Control and not bool(o.get("keyboard", false)):
		help.visible = false  # teclas do jogador: ninguém controla nada no treino (manual: ficam)


## Solta a arena atual sem deixar ela terminar depois (Parar, Repetir).
func _drop_arena() -> void:
	if is_instance_valid(arena):
		if arena.finished.is_connected(_on_finished):
			arena.finished.disconnect(_on_finished)
		# Sai da árvore já: o que a arena mudou na luz da cena (BattleBiomes) volta antes da próxima.
		if arena.get_parent() == self:
			remove_child(arena)
		arena.queue_free()
	arena = null
	# A próxima arena guarda a câmera atual para devolver no fim: tem que ser a do cenário.
	if _stage_cam:
		_stage_cam.make_current()


## A arena roda em modo manual: aqui ela anda `steps` passos por quadro.
func _physics_process(dt: float) -> void:
	for i in steps:
		if not is_instance_valid(arena) or String(arena.get("state")) == "done":
			return
		var a := arena
		var fighting := String(a.get("state")) == "fight"
		a.step(dt)
		if fighting and is_instance_valid(a):
			fight_time += dt * float(a.get("fight_speed")) * float(a.call("cine_scale"))
			_check_time_limit()


## A câmera da arena olha o meio entre o jogador e o 1º mon do adversário; aqui olha o centro da
## quadra e abre o fov para caber a quadra inteira.
func _fit_camera() -> void:
	var cam = arena.get("_cam")
	if cam is Camera3D:
		cam.fov = CAM_FOV
	if arena.get("_cam_focus") != null:
		arena.set("_cam_focus", cam_focus())
	if arena.get("cam_dist") != null:
		arena.set("cam_dist", cam_dist())


## Limite de tempo (cfg.time_limit, segundos de jogo): a luta termina sem vencedor ("timeout").
func _check_time_limit() -> void:
	var limit := float(cfg.get("time_limit", 0))
	if limit <= 0.0 or fight_time < limit or not is_instance_valid(arena):
		return
	if String(arena.get("state")) == "fight":
		arena.say("Time's up!")
		arena.call("_end", "timeout", 0.0)


func _process(dt: float) -> void:
	_refresh_info()
	_stadium_tick(dt)


## Placar do estádio e a torcida: comemora quando um Pokémon do outro time desmaia, faz a ola de
## tempos em tempos (segundos de luta) e festeja o vencedor.
func _stadium_tick(dt: float) -> void:
	if _stadium == null:
		return
	var alive := [_alive_list(team_a), _alive_list(team_b)]
	(
		_stadium
		. score(
			{
				"names": [Cfg.side_name(cfg, 0), Cfg.side_name(cfg, 1)],
				"alive": alive,
				"clock": "%d:%02d" % [int(fight_time) / 60, int(fight_time) % 60],
				"scene": String(Cfg.SCENARIO_NAMES.get(scenario(), "")),
				"series": "%d x %d" % [series.a, series.b],
				"headline": _headline,
			}
		)
	)
	for side in 2:
		var down: int = (alive[side] as Array).count(false)
		if down > int(_down[side]):
			_stadium.cheer(1 - side, 1.0)
		_down[side] = down
	if is_instance_valid(arena) and String(arena.get("state")) == "fight":
		_wave_in -= dt * float(arena.get("fight_speed"))
		if _wave_in <= 0.0:
			_stadium.wave()
			_wave_in = WAVE_GAP + WAVE_JITTER * fposmod(fight_time * 0.618, 1.0)


## Abertura da luta: o telão mostra "VS" com os nomes e "FIGHT!", e a torcida grita.
func _on_opening_beat(beat: String) -> void:
	match beat:
		"vs":
			_headline = "VS"
			if _stadium:
				_stadium.cheer(0, 1.0)
				_stadium.cheer(1, 1.0)
		"throw":
			_headline = ""
		"fight":
			_headline = "FIGHT!"
			if _stadium:
				_stadium.cheer(0, 1.0)
				_stadium.cheer(1, 1.0)
		"done":
			_headline = ""


static func _alive_list(team: Array) -> Array:
	return team.map(func(m): return not m.is_fainted())


func _on_finished(r: Dictionary) -> void:
	result = r
	_keep_log()
	var outcome := String(r.get("outcome", ""))
	if _stadium and outcome in ["win", "lose"]:
		_stadium.cheer(0 if outcome == "win" else 1, 1.0)
	series.n = int(series.n) + 1
	match outcome:
		"win":
			series.a = int(series.a) + 1
		"lose":
			series.b = int(series.b) + 1
		_:
			series.draw = int(series.draw) + 1
	if auto_left > 0:
		auto_left -= 1
		_next_with_loading.call_deferred()
		return
	_show_result()


func stop_fight() -> void:
	auto_left = 0
	_keep_log()
	_drop_arena()
	_show_result()


## Nome do time vencedor ("" = sem vencedor).
func winner_name() -> String:
	match String(result.get("outcome", "")):
		"win":
			return Cfg.side_name(cfg, 0)
		"lose":
			return Cfg.side_name(cfg, 1)
	return ""


func _input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if _result_box.visible:
			go_setup()
		else:
			stop_fight()


func go_setup() -> void:
	Cfg.current = cfg
	get_tree().change_scene_to_file(SETUP_SCENE)


func go_title() -> void:
	load("res://ui/front/title.gd").boot_to_menu = true
	get_tree().change_scene_to_file(TITLE_SCENE)


# --- Interface ---


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 20
	add_child(_ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = Kit.ui_theme()
	_ui.add_child(root)
	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", Kit.glass(0.5, 10))
	# Embaixo, acima da barra de teclas da arena (em cima ficam os cartões dos Pokémon).
	top.anchor_top = 1.0
	top.anchor_bottom = 1.0
	top.offset_left = 12
	top.offset_top = -84
	top.offset_bottom = -36
	top.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(top)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	top.add_child(row)
	_info = Label.new()
	_info.add_theme_color_override("font_color", Color.WHITE)
	_info.add_theme_font_size_override("font_size", 16)
	row.add_child(_info)
	_stop = _button("Stop (Esc)", stop_fight)
	row.add_child(_stop)
	_build_result(root)


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b


func _build_result(root: Control) -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	_result_box = center
	center.visible = false


func _refresh_info() -> void:
	if _info == null:
		return
	var s := (
		"%s %s x %s %s   ·   %s   ·   Series: %d x %d"
		% [
			Cfg.side_name(cfg, 0),
			_alive(team_a),
			_alive(team_b),
			Cfg.side_name(cfg, 1),
			_clock(fight_time),
			series.a,
			series.b
		]
	)
	if int(series.draw) > 0:
		s += " (%d without a winner)" % series.draw
	if scenario() != "":
		s += "   ·   %s" % Cfg.SCENARIO_NAMES.get(scenario(), scenario())
	if auto_left > 0:
		s += "   ·   %d left" % auto_left
	_info.text = s
	_stop.visible = not _result_box.visible


## "2/3": Pokémon de pé no time.
static func _alive(team: Array) -> String:
	return "%d/%d" % [team.filter(func(m): return not m.is_fainted()).size(), team.size()]


static func _clock(t: float) -> String:
	return "%d:%04.1f" % [int(t) / 60, fmod(t, 60.0)]


func _show_result() -> void:
	Kit.clear(_result_box)
	var w: Array = Kit.panel("RESULT", Vector2(760, 0), 6)
	_result_box.add_child(w[0])
	var col: VBoxContainer = w[1]
	var win := winner_name()
	var head := "%s won!" % win
	if win == "":
		head = (
			"Time's up: no winner"
			if String(result.get("outcome", "")) == "timeout"
			else "Fight stopped"
		)
	col.add_child(Kit.header(head, Kit.RED, 24))
	col.add_child(
		Kit.label(
			(
				"Fight length: %s (game time) · seed %d · scenario %s"
				% [_clock(fight_time), last_seed, Cfg.SCENARIO_NAMES.get(scenario(), "flat")]
			)
		)
	)
	var line := (
		"Series: %s %d x %d %s in %d fights"
		% [Cfg.side_name(cfg, 0), series.a, series.b, Cfg.side_name(cfg, 1), series.n]
	)
	if int(series.draw) > 0:
		line += " (%d without a winner)" % series.draw
	col.add_child(Kit.label(line))
	# Os dois times lado a lado (6 x 6 cabe na tela).
	var teams := HBoxContainer.new()
	teams.add_theme_constant_override("separation", 16)
	col.add_child(teams)
	for side in 2:
		var tc := VBoxContainer.new()
		tc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		teams.add_child(tc)
		tc.add_child(Kit.header(Cfg.side_name(cfg, side), Kit.BLUE, 18))
		for m in team_a if side == 0 else team_b:
			tc.add_child(Kit.label(_mon_line(m), Kit.DIM if m.is_fainted() else Kit.INK, 15))
	var rep := HBoxContainer.new()
	rep.add_theme_constant_override("separation", 8)
	col.add_child(rep)
	rep.add_child(_button("Repeat", _repeat.bind(0, true)))
	var count := SpinBox.new()
	count.min_value = 2
	count.max_value = 200
	count.value = 10
	count.suffix = "fights"
	rep.add_child(count)
	rep.add_child(_button("Run series", func() -> void: _repeat(int(count.value) - 1, true)))
	var rnd := CheckBox.new()
	rnd.text = "Random teams every fight"
	rnd.focus_mode = Control.FOCUS_NONE
	rnd.button_pressed = random_series
	rnd.toggled.connect(func(on: bool) -> void: random_series = on)
	rep.add_child(rnd)
	rep.add_child(_button("Reset score", _reset_series))
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 8)
	col.add_child(nav)
	nav.add_child(_button("Edit teams", go_setup))
	nav.add_child(_button("Copy log", _copy_log))
	nav.add_child(_button("Back to title", go_title))
	_result_box.visible = true


func _mon_line(m: Mon) -> String:
	var st := "" if m.status == "" else " · " + String(Cfg.STATUS_NAMES.get(m.status, m.status))
	return (
		"%s Lv %d: %d/%d HP%s"
		% [
			m.display_name,
			m.level,
			BattleFighter.hp_from_mon(m.hp),
			BattleFighter.hp_from_mon(m.max_hp),
			" · fainted" if m.is_fainted() else st,
		]
	)


## extra > 0 é uma série (Rodar série): as lutas dela são todas de IA.
## Next battle of a series behind the loading screen: the old arena goes away and the new one is
## built while the ball keeps spinning (the stadium stays up). Not for the headless battery.
func _next_with_loading() -> void:
	var eo = cfg.get("extra_opts", {})
	var fast: bool = eo is Dictionary and bool(eo.get("fast_sim", false))
	if fast or not is_inside_tree():
		start_fight()
		return
	Loading.begin_now("battle")
	_drop_arena()
	await get_tree().process_frame
	await get_tree().process_frame
	if is_inside_tree():
		start_fight()
	Loading.end_later("battle", 2)


func _repeat(extra: int, loading := false) -> void:
	auto_left = extra
	_series = extra > 0
	_random = _series and random_series
	if loading:
		_next_with_loading()
	else:
		start_fight()


func _reset_series() -> void:
	series = {"key": series.key, "a": 0, "b": 0, "draw": 0, "n": 0}
	_show_result()


## Registro da última luta (faixa de log da arena) na área de transferência, para análise.
func _copy_log() -> void:
	DisplayServer.clipboard_set("\n".join(PackedStringArray(_last_log)))


func _keep_log() -> void:
	if is_instance_valid(arena) and arena.get("log_lines") is Array:
		_last_log = arena.log_lines.duplicate()
		# A faixa de log da arena guarda só as últimas LOG_MAX linhas.
		if _last_log.size() >= int(arena.LOG_MAX):
			_last_log.push_front("(log truncated: the first lines of the fight were lost)")

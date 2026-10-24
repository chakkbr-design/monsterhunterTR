extends Node3D
## Modo de treinamento: a luta automática entre os dois times montados em training_setup.
## Arena fixa de Cfg.ARENA (16 x 10), as duas IAs lutando sozinhas
## (opts.autoplay), sem mexer no save nem na equipe do jogo. No fim mostra o vencedor e o
## placar da série.
## Esc para a luta e volta para a tela de montar.

const Cfg := preload("res://ui/training/training_config.gd")
const Kit := preload("res://ui/ui_kit.gd")
const ARENA_SCENE := "res://battle/battle_arena.tscn"
const SETUP_SCENE := "res://ui/training/training_setup.tscn"
const TITLE_SCENE := "res://ui/front/title.tscn"
## A câmera fixa da arena (14 m, fov 30) foi feita para a quadra de 10 x 6; esta tem o dobro:
## a câmera olha 2 m para cá do centro e abre o fov para os quatro cantos caberem na tela.
const CAM_FOV := 60.0
const CAM_FOCUS := Vector3(0, 0, 2)
const CAM_DIST := 14.0
const CAM_PITCH := deg_to_rad(30.0)
const GROUND := Color(0.36, 0.55, 0.3)
const DIRT := Color(0.62, 0.52, 0.38)
const WOOD := Color(0.5, 0.34, 0.2)
const FENCE_GAP := 1.6
const POST_STEP := 2.0

## Placar da série enquanto a config não muda (sobrevive a "Repetir").
## Com semente fixa, a luta k da série usa semente + k (n): nunca repete uma luta já contada.
static var series := {"key": "", "a": 0, "b": 0, "draw": 0, "n": 0}

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
var _ui: CanvasLayer
var _info: Label
var _result_box: Control
var _stop: Button
var _last_log: Array = []
var _stage_cam: Camera3D


func _ready() -> void:
	Cfg.block_pause_menu(get_tree(), true)
	cfg = Cfg.current if not Cfg.current.is_empty() else Cfg.load_config()
	var key := JSON.stringify(cfg)
	if String(series.key) != key:
		series = {"key": key, "a": 0, "b": 0, "draw": 0, "n": 0}
	_build_stage()
	_build_ui()
	start_fight()


func _exit_tree() -> void:
	Cfg.block_pause_menu(get_tree(), false)


# --- Cenário ---


func _build_stage() -> void:
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
	_plane(Vector2(90, 70), GROUND, -0.01)
	_plane(Cfg.ARENA + Vector2(FENCE_GAP, FENCE_GAP) * 2.0, DIRT, 0.0)
	_build_fence(Cfg.ARENA * 0.5 + Vector2(FENCE_GAP, FENCE_GAP))
	# Câmera do cenário no mesmo ponto da câmera fixa da arena: a arena a devolve no fim da luta.
	_stage_cam = Camera3D.new()
	_stage_cam.fov = CAM_FOV
	_stage_cam.position = CAM_FOCUS + Vector3(0, sin(CAM_PITCH), cos(CAM_PITCH)) * CAM_DIST
	add_child(_stage_cam)
	_stage_cam.look_at(CAM_FOCUS, Vector3.UP)
	_stage_cam.make_current()


func _plane(sz: Vector2, col: Color, y: float) -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = sz
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 1.0
	pm.material = mat
	mi.mesh = pm
	mi.position.y = y
	add_child(mi)


## Cerca de madeira em volta da quadra (só visual: a arena já prende os Pokémon na quadra).
func _build_fence(half: Vector2) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = WOOD
	mat.roughness = 0.9
	var post := BoxMesh.new()
	post.size = Vector3(0.18, 0.9, 0.18)
	post.material = mat
	var corners := [
		Vector3(-half.x, 0, -half.y),
		Vector3(half.x, 0, -half.y),
		Vector3(half.x, 0, half.y),
		Vector3(-half.x, 0, half.y)
	]
	for i in 4:
		var a: Vector3 = corners[i]
		var b: Vector3 = corners[(i + 1) % 4]
		var length := a.distance_to(b)
		var steps := maxi(1, roundi(length / POST_STEP))
		for k in steps:
			var p := MeshInstance3D.new()
			p.mesh = post
			p.position = a.lerp(b, float(k) / steps) + Vector3(0, 0.45, 0)
			add_child(p)
		for h in [0.35, 0.7]:
			var rail := MeshInstance3D.new()
			var rm := BoxMesh.new()
			rm.size = Vector3(length, 0.08, 0.06)
			rm.material = mat
			rail.mesh = rm
			rail.position = (a + b) * 0.5 + Vector3(0, h, 0)
			rail.rotation.y = -atan2(b.z - a.z, b.x - a.x)
			add_child(rail)


# --- Luta ---


func start_fight() -> void:
	_drop_arena()
	_result_box.visible = false
	result = {}
	fight_time = 0.0
	team_a = Cfg.build_side(cfg, 0)
	team_b = Cfg.build_side(cfg, 1)
	var o := Cfg.arena_opts(cfg, global_position)
	last_seed = int(o.seed) + int(series.n) if o.has("seed") else randi()
	o.seed = last_seed
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
	arena.start(team_a, team_b, o)
	_fit_camera()
	var help = arena.hud.get("_help") if arena.get("hud") else null
	if help is Control:
		help.visible = false  # teclas do jogador: ninguém controla nada no treino


## Solta a arena atual sem deixar ela terminar depois (Parar, Repetir).
func _drop_arena() -> void:
	if is_instance_valid(arena):
		if arena.finished.is_connected(_on_finished):
			arena.finished.disconnect(_on_finished)
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
			fight_time += dt * float(a.get("fight_speed"))
			_check_time_limit()


## A câmera da arena olha o meio entre o jogador e o 1º mon do adversário; aqui olha o centro da
## quadra e abre o fov para caber a quadra inteira.
func _fit_camera() -> void:
	var cam = arena.get("_cam")
	if cam is Camera3D:
		cam.fov = CAM_FOV
	if arena.get("_cam_focus") != null:
		arena.set("_cam_focus", CAM_FOCUS)


## Limite de tempo (cfg.time_limit, segundos de jogo): a luta termina sem vencedor ("timeout").
func _check_time_limit() -> void:
	var limit := float(cfg.get("time_limit", 0))
	if limit <= 0.0 or fight_time < limit or not is_instance_valid(arena):
		return
	if String(arena.get("state")) == "fight":
		arena.say("Tempo esgotado!")
		arena.call("_end", "timeout", 0.0)


func _process(_dt: float) -> void:
	_refresh_info()


func _on_finished(r: Dictionary) -> void:
	result = r
	_keep_log()
	var outcome := String(r.get("outcome", ""))
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
		start_fight.call_deferred()
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
	_stop = _button("Parar (Esc)", stop_fight)
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
		"%s %s x %s %s   ·   %s   ·   Série: %d x %d"
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
		s += " (%d sem vencedor)" % series.draw
	if auto_left > 0:
		s += "   ·   faltam %d" % auto_left
	_info.text = s
	_stop.visible = not _result_box.visible


## "2/3": Pokémon de pé no time.
static func _alive(team: Array) -> String:
	return "%d/%d" % [team.filter(func(m): return not m.is_fainted()).size(), team.size()]


static func _clock(t: float) -> String:
	return "%d:%04.1f" % [int(t) / 60, fmod(t, 60.0)]


func _show_result() -> void:
	Kit.clear(_result_box)
	var w: Array = Kit.panel("RESULTADO", Vector2(760, 0), 6)
	_result_box.add_child(w[0])
	var col: VBoxContainer = w[1]
	var win := winner_name()
	var head := "%s venceu!" % win
	if win == "":
		head = (
			"Tempo esgotado: sem vencedor"
			if String(result.get("outcome", "")) == "timeout"
			else "Luta interrompida"
		)
	col.add_child(Kit.header(head, Kit.RED, 24))
	col.add_child(
		Kit.label(
			"Duração da luta: %s (tempo de jogo) · semente %d" % [_clock(fight_time), last_seed]
		)
	)
	var line := (
		"Série: %s %d x %d %s em %d lutas"
		% [Cfg.side_name(cfg, 0), series.a, series.b, Cfg.side_name(cfg, 1), series.n]
	)
	if int(series.draw) > 0:
		line += " (%d sem vencedor)" % series.draw
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
	rep.add_child(_button("Repetir", _repeat.bind(0)))
	var count := SpinBox.new()
	count.min_value = 2
	count.max_value = 200
	count.value = 10
	count.suffix = "lutas"
	rep.add_child(count)
	rep.add_child(_button("Rodar série", func() -> void: _repeat(int(count.value) - 1)))
	rep.add_child(_button("Zerar placar", _reset_series))
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 8)
	col.add_child(nav)
	nav.add_child(_button("Editar times", go_setup))
	nav.add_child(_button("Copiar registro", _copy_log))
	nav.add_child(_button("Voltar ao título", go_title))
	_result_box.visible = true


func _mon_line(m: Mon) -> String:
	var st := "" if m.status == "" else " · " + String(Cfg.STATUS_NAMES.get(m.status, m.status))
	return (
		"%s Nv %d: %d/%d HP%s"
		% [m.display_name, m.level, m.hp, m.max_hp, " · desmaiou" if m.is_fainted() else st]
	)


func _repeat(extra: int) -> void:
	auto_left = extra
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
			_last_log.push_front("(registro truncado: as primeiras linhas da luta se perderam)")

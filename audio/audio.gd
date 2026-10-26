extends Node
## Autoload `Audio`: efeitos e música chiptune gerados em código (audio/synth.gd), tudo original.
## API: Audio.sfx(nome, volume_db := 0.0), Audio.music(faixa, fade := 0.5), Audio.stop_music(fade := 0.5).
## Ligações automáticas (sem mexer no mundo): Game.battle_started/battle_finished (música de batalha e vitória),
## sinal location_changed(kind, id) de qualquer nó que entrar na árvore (RouteWorld) e a cena de título.
## Outras partes chamam via preload("res://audio/cue.gd"), que não quebra sem este autoload.
## Volumes: geral ("volume", barramento Master), música ("music") e efeitos ("sfx"), 0..100, do
## user://settings.cfg (ui/front/settings.gd load_cfg). Relidos quando o arquivo muda ou por refresh_volumes().

const Synth := preload("res://audio/synth.gd")
const Settings := preload("res://ui/front/settings.gd")
const TITLE_SCENE := "res://ui/front/title.tscn"
const MUSIC_DB := -8.0
const SFX_VOICES := 8
## O mesmo efeito não toca de novo antes disto (golpes em rajada).
const SFX_GAP := 0.04
## De quanto em quanto tempo olha se o settings.cfg mudou (volumes da tela de opções).
const CFG_POLL := 0.5

## Injetável nos testes; senão /root/Game.
var game: Node = null
var current_music := ""
## Faixa da zona/sala atual (volta depois da batalha).
var zone_music := ""
var in_battle := false
## Volumes de música e efeitos (0..1) das opções.
var music_vol := 1.0
var sfx_vol := 1.0

var _sfx: Dictionary = {}
var _music_cache: Dictionary = {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_next := 0
var _sfx_last: Dictionary = {}
var _cur: AudioStreamPlayer
var _old: AudioStreamPlayer
var _cur_gain := 0.0
var _old_gain := 0.0
var _fade_in := 0.0
var _fade_out := 0.0
var _resume_t := 0.0
var _last_kind := ""
var _bound_game: Node = null
var _mutex := Mutex.new()
var _prewarm_task := -1
var _quit := false
var _cfg_t := 0.0
var _cfg_mtime := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for n in Synth.SFX_NAMES:
		_sfx[n] = Synth.make_sfx(n)
	for i in SFX_VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx_players.append(p)
	_cur = AudioStreamPlayer.new()
	_old = AudioStreamPlayer.new()
	add_child(_cur)
	add_child(_old)
	_apply_volume()
	get_tree().node_added.connect(_on_node_added)
	_bind_game.call_deferred()
	# Fora do headless, as faixas são renderizadas numa thread de fundo para não travar na troca de zona.
	if DisplayServer.get_name() != "headless":
		_prewarm_task = WorkerThreadPool.add_task(_prewarm)


## Volumes do user://settings.cfg (mesmo formato do ui/front/settings.gd; só leitura).
func _apply_volume() -> void:
	refresh_volumes()


## Aplica os volumes: `cfg` como o load_cfg() devolve (vazio = lê o arquivo). A tela de opções pode chamar
## isto ao mudar um volume; sem isso o Audio percebe sozinho quando o settings.cfg é salvo.
func refresh_volumes(cfg := {}) -> void:
	var d: Dictionary = cfg if not cfg.is_empty() else Settings.load_cfg()
	var v := clampi(int(d.get("volume", 80)), 0, 100)
	AudioServer.set_bus_volume_db(0, linear_to_db(v / 100.0) if v > 0 else -80.0)
	AudioServer.set_bus_mute(0, v == 0)
	music_vol = clampi(int(d.get("music", 100)), 0, 100) / 100.0
	sfx_vol = clampi(int(d.get("sfx", 100)), 0, 100) / 100.0
	if _cur:
		_set_gain(_cur, _cur_gain)
	if _old and _old.playing:
		_set_gain(_old, _old_gain)


func _poll_cfg(dt: float) -> void:
	_cfg_t -= dt
	if _cfg_t > 0.0:
		return
	_cfg_t = CFG_POLL
	var path := String(Settings.PATH)
	var mt := FileAccess.get_modified_time(path) if FileAccess.file_exists(path) else 0
	if mt != _cfg_mtime:
		var first := _cfg_mtime < 0
		_cfg_mtime = mt
		if not first:
			refresh_volumes()


func _bind_game() -> void:
	var g := game if game else get_node_or_null("/root/Game")
	bind_game(g)


func bind_game(g: Node) -> void:
	if g == null or g == _bound_game:
		return
	_bound_game = g
	game = g
	if g.has_signal("battle_started") and not g.battle_started.is_connected(_on_battle_started):
		g.battle_started.connect(_on_battle_started)
	if g.has_signal("battle_finished") and not g.battle_finished.is_connected(_on_battle_finished):
		g.battle_finished.connect(_on_battle_finished)


# --- Efeitos ---


func has_sfx(sfx_name: String) -> bool:
	return _sfx.has(sfx_name)


func sfx_stream(sfx_name: String) -> AudioStreamWAV:
	return _sfx.get(sfx_name)


func sfx(sfx_name: String, volume_db := 0.0) -> void:
	var st: AudioStream = _sfx.get(sfx_name)
	if st == null:
		push_warning("Audio: unknown effect '%s'" % sfx_name)
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_sfx_last.get(sfx_name, -1.0)) < SFX_GAP:
		return
	_sfx_last[sfx_name] = now
	if sfx_vol <= 0.0:
		return
	# Voz livre primeiro; só corta um efeito tocando (estalo) quando todas estão ocupadas.
	var n := _sfx_players.size()
	for k in n:
		if not _sfx_players[(_sfx_next + k) % n].playing:
			_sfx_next = (_sfx_next + k) % n
			break
	var p := _sfx_players[_sfx_next]
	_sfx_next = (_sfx_next + 1) % n
	p.stream = st
	p.volume_db = volume_db + linear_to_db(sfx_vol)
	p.play()


# --- Música ---


func music_stream(track: String) -> AudioStreamWAV:
	_mutex.lock()
	var st: AudioStreamWAV = _music_cache.get(track)
	_mutex.unlock()
	if st == null:
		st = Synth.render_track(track)
		if st == null:
			return null
		_mutex.lock()
		_music_cache[track] = st
		_mutex.unlock()
	return st


func _prewarm() -> void:
	for t in Synth.TRACKS:
		if _quit:
			return
		_mutex.lock()
		var has := _music_cache.has(t)
		_mutex.unlock()
		if not has:
			var st := Synth.render_track(t)
			_mutex.lock()
			if not _music_cache.has(t):
				_music_cache[t] = st
			_mutex.unlock()


func _exit_tree() -> void:
	_quit = true
	if _prewarm_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_prewarm_task)
		_prewarm_task = -1


func music(track: String, fade := 0.5) -> void:
	_resume_t = 0.0
	if track == current_music and _cur.playing:
		return
	var st := music_stream(track)
	if st == null:
		push_warning("Audio: unknown track '%s'" % track)
		return
	_swap_out(fade)
	current_music = track
	_cur.stream = st
	_cur_gain = 0.0 if fade > 0.0 else 1.0
	_fade_in = fade
	_set_gain(_cur, _cur_gain)
	_cur.play()


func stop_music(fade := 0.5) -> void:
	_resume_t = 0.0
	_swap_out(fade)
	current_music = ""


func _swap_out(fade: float) -> void:
	if _old.playing:
		_old.stop()
	if not _cur.playing:
		return
	var t := _old
	_old = _cur
	_cur = t
	_old_gain = _cur_gain
	_fade_out = fade
	if fade <= 0.0:
		_old.stop()


func _set_gain(p: AudioStreamPlayer, g: float) -> void:
	var k := g * music_vol
	p.volume_db = MUSIC_DB + (linear_to_db(k) if k > 0.001 else -80.0)


func _process(dt: float) -> void:
	_poll_cfg(dt)
	if _cur.playing and _cur_gain < 1.0:
		_cur_gain = minf(1.0, _cur_gain + dt / maxf(_fade_in, 0.001))
		_set_gain(_cur, _cur_gain)
	if _old.playing:
		_old_gain -= dt / maxf(_fade_out, 0.001)
		if _old_gain <= 0.0:
			_old.stop()
		else:
			_set_gain(_old, _old_gain)
	if _resume_t > 0.0:
		_resume_t -= dt
		if _resume_t <= 0.0:
			_resume_t = 0.0
			_resume_zone()


func _resume_zone() -> void:
	if zone_music != "":
		music(zone_music, 1.0)
	else:
		stop_music(1.0)


# --- Ligações automáticas ---


## Faixa para um lugar da RouteWorld.
static func music_for(kind: String, id: String) -> String:
	if kind == "interior":
		if id.contains("pokemon_center") or id.contains("mart"):
			return "center"
		if id.contains("lab"):
			return "lab"
		if id.contains("gym"):
			return "gym"
		if id.begins_with("mt_moon_"):
			return "cave"  # o original: MtMoon1F/B1F/B2F -> music/cave
		if id.contains("forest"):
			return "forest"
		return "town"
	if id.contains("forest"):
		return "forest"
	if id.begins_with("route"):
		return "route"
	return "town"


func _on_node_added(n: Node) -> void:
	if n.scene_file_path == TITLE_SCENE:
		zone_music = "title"
		music("title", 0.3)
	if (
		n.has_signal("location_changed")
		and not n.is_connected("location_changed", on_location_changed)
	):
		n.connect("location_changed", on_location_changed)
	if n.name == "Game" and n.get_parent() == get_tree().root:
		bind_game(n)


func on_location_changed(kind: String, id: String) -> void:
	if _last_kind != "" and (kind == "interior" or _last_kind == "interior"):
		sfx("door")
	_last_kind = kind
	zone_music = music_for(kind, id)
	if not in_battle:
		music(zone_music, 0.6)


func _on_battle_started() -> void:
	in_battle = true
	var kind: String = game.battle_kind() if game and game.has_method("battle_kind") else "wild"
	if kind == "trainer":
		# O original (battle.gd:515-517): líder de ginásio tem tema próprio, senão o de treinador.
		music("gym_leader" if _gym_leader_battle() else "battle_trainer", 0.15)
	else:
		sfx("encounter")
		music("battle_wild", 0.15)


func _gym_leader_battle() -> bool:
	var o = game.get("_opts") if game else null
	if not (o is Dictionary) or not Synth.TRACKS.has("gym_leader"):
		return false
	var id := String(o.get("trainer_id", ""))
	return id != "" and String(Dex.trainer(id).get("class", "")) == "gym_leader"


func _on_battle_finished(result: Dictionary) -> void:
	in_battle = false
	var outcome := String(result.get("outcome", ""))
	if outcome == "win":
		music("victory", 0.1)
		_resume_t = Synth.track_secs(Synth.TRACKS.victory)
	elif outcome == "caught":
		# O original não toca vitória na captura: o jingle "caught" (já tocado na arena) e volta à zona.
		# A arena já calou a música da batalha quando a bola fechou; a zona volta logo depois do jingle.
		stop_music(0.1)
		_resume_t = 0.6
	else:
		_resume_zone()

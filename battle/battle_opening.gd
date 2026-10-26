extends RefCounted
## Abertura do treino no modo de energia (opts.opening com a câmera de ação; nunca no fast_sim):
## a arena fica no state "opening" (sem IA, energia nem golpes) e roda esta linha do tempo, em
## segundos de luta:
## 1. "vs": a câmera no telão do estádio (opts.opening_screen, os cantos globais) com
##    "<A> VS <B>" (opts.opening_names) e a faixa na tela; a torcida grita (quem ouve opening_beat);
## 2. "wide": a arena inteira com os dois treinadores;
## 3. "throw": cada treinador joga a bola dos titulares (lado A, depois o B; na dupla as duas bolas
##    do lado saem juntas, STAGGER s de diferença) com a coreografia do BattleDirector (close no
##    treinador, a bola, zoom no Pokémon);
## 4. "fight": todos enquadrados e o "Fight!" por FIGHT_SECS; então a luta começa (arena
##    _opening_done). Total ~8,6 s no 2x2 (~8,3 s no 1x1); teto MAX_SECS.
## Os titulares já foram criados por start() (as habilidades de entrada já valeram, como sem a
## abertura); aqui só ficam escondidos até a bola abrir.

const BallShow := preload("res://battle/battle_ball_show.gd")
const VS_SECS := 2.0
const WIDE_SECS := 1.1
## O treinador do lado B começa a preparar o arremesso NEXT_SIDE s depois de a bola do A abrir.
const NEXT_SIDE := 0.55
const STAGGER := 0.15
const FIGHT_SECS := 0.9
## Depois da última bola sumir, o zoom no Pokémon ainda dura isto antes do "Fight!".
const MON_TAIL := 0.3
const MAX_SECS := 16.0
const VS_PITCH := deg_to_rad(10.0)
const WIDE_PITCH := deg_to_rad(40.0)
const DEFAULT_NAMES := ["Player 1", "Player 2"]

var arena  ## a BattleArena (sem tipo: os campos dela são lidos direto)
var t := 0.0
var phase := ""
var names: Array = []
var _throws: Array = []  ## [{at, side, f}]
var _fight_at := -1.0
var _done_at := -1.0
var _announced := {}


func _init(a) -> void:
	arena = a
	var nm = arena.opts.get("opening_names", [])
	for side in 2:
		var n := String(nm[side]).strip_edges() if nm is Array and nm.size() > side else ""
		names.append(n if n != "" else DEFAULT_NAMES[side])
	for f in arena.fighters:
		if is_instance_valid(f):
			f.visible = false
	var at := VS_SECS + WIDE_SECS
	var side_len := BallShow.WINDUP + BallShow.FLIGHT + BallShow.BOUNCE
	for side in 2:
		var k := 0
		for f in arena.fighters:
			if is_instance_valid(f) and f.side == side and f.on_field:
				_throws.append({"at": at + k * STAGGER, "side": side, "f": f})
				k += 1
		if k > 0:
			at += side_len + (k - 1) * STAGGER + NEXT_SIDE
	_beat("vs")


## Passo da abertura (dt da luta). true = acabou: a luta pode começar.
func tick(dt: float) -> bool:
	t += dt
	var d: BattleDirector = arena.director
	if d:
		d.tick(dt)
	if phase == "vs" and t >= VS_SECS:
		_beat("wide")
	for e in _throws.duplicate():
		if t >= float(e.at):
			_throws.erase(e)
			_throw(e)
	if _throws.is_empty() and arena._balls.is_empty() and _fight_at < 0.0:
		_fight_at = t + (MON_TAIL if phase == "throw" else 0.0)
	if _fight_at >= 0.0 and t >= _fight_at and phase != "fight":
		_beat("fight")
		_done_at = t + FIGHT_SECS
	return (_done_at >= 0.0 and t >= _done_at) or t >= MAX_SECS


func _throw(e: Dictionary) -> void:
	var f = e.f
	if not is_instance_valid(f) or not f.on_field:
		return
	if phase != "throw":
		_beat("throw")
	var side := int(e.side)
	if not _announced.has(side):
		_announced[side] = true
		var mons: Array = []
		for o in arena.fighters:
			if is_instance_valid(o) and o.side == side and o.on_field:
				mons.append(o.mon.display_name)
		arena.hud.banner("%s: Go, %s!" % [names[side], " and ".join(mons)], 1.6)
	var show_f := func() -> void:
		if is_instance_valid(f) and f.on_field:
			f.visible = true
	arena.throw_ball_fx(side, f.position, show_f, f)


func _beat(name: String) -> void:
	phase = name
	var d: BattleDirector = arena.director
	match name:
		"vs":
			arena.hud.banner("%s  VS  %s" % [names[0], names[1]], VS_SECS + WIDE_SECS * 0.5)
			preload("res://audio/cue.gd").sfx("spotted")
			var pts: Array = []
			var scr = arena.opts.get("opening_screen", [])
			if scr is Array:
				for p in scr:
					if p is Vector3:
						pts.append(arena.to_local(p) if arena.is_inside_tree() else p)
			if d and not pts.is_empty():
				d.set_cine(pts, 1.2, VS_PITCH, 6.0)
			elif d:
				_wide(d)
		"wide":
			if d:
				_wide(d)
		"throw":
			if d:
				d.clear_cine()
		"fight":
			if d:
				d.clear_cine()
				d.shot = ""
			arena.hud.fight_flash("Fight!")
			for f in arena.fighters:
				if is_instance_valid(f) and f.on_field:
					f.visible = true
	arena.opening_beat.emit(name)


## A arena inteira (a quadra e os dois treinadores).
func _wide(d: BattleDirector) -> void:
	var r: Rect2 = arena.rect
	var pts: Array = [
		Vector3(r.position.x, 0, r.position.y),
		Vector3(r.end.x, 0, r.position.y),
		Vector3(r.position.x, 0, r.end.y),
		Vector3(r.end.x, 0, r.end.y),
		arena.trainer_spot(0),
		arena.trainer_spot(1) + Vector3(0, 1.8, 0),
	]
	d.set_cine(pts, 1.0, WIDE_PITCH, 6.0)

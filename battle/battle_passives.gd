class_name BattlePassives
extends RefCounted
## Passivas de movimento do modo de energia (não são golpes; todo Pokémon tem, cada uma com a própria
## regra e recarga). Rodam dentro da IA (BattleAI.step), só com f.energy_mode.
## - Pulo de desespero: encurralado na parede (inimigo perto por CORNER_SECS s, ou dois inimigos perto)
##   salta LEAP_DIST m para o espaço aberto, passando pelo lado do inimigo e sem sair da quadra; no ar
##   a investida passa por baixo. Ao pousar ganha Fôlego: BREATH_ENERGY de energia e a barra enche
##   BREATH_REGEN x por BREATH_SECS s. Recarga LEAP_CD s por Pokémon.
## - Segundo fôlego: uma vez por entrada, com HP abaixo de SECOND_HP e energia abaixo de SECOND_EN,
##   recupera SECOND_ENERGY de energia.
## - Contra-ataque: esquiva perfeita (a investida passou por baixo, ou saiu de lado e a investida não
##   pegou) dá COUNTER_ENERGY de energia; recarga COUNTER_ICD s.

## Encurralado: a menos de CORNER_WALL m da parede com inimigo a menos de CORNER_FOE m por CORNER_SECS
## s; com dois inimigos a menos de CORNER_PAIR m conta na hora.
const CORNER_WALL := 1.6
const CORNER_FOE := 3.2
const CORNER_SECS := 1.0
const CORNER_PAIR := 3.6
## Salto: distância, duração, altura, recarga e folga mínima da parede no pouso.
const LEAP_DIST := 4.0
const LEAP_SECS := 0.55
const LEAP_H := 1.6
const LEAP_CD := 11.0
const LEAP_MARGIN := 2.0
## Pouso a pelo menos LAND_FOE m de todo inimigo (senão a nota do ponto cai).
const LAND_FOE := 2.6
## Fôlego depois do pulo.
const BREATH_ENERGY := 15.0
const BREATH_SECS := 3.0
const BREATH_REGEN := 1.4
## Segundo fôlego.
const SECOND_HP := 0.25
const SECOND_EN := 20.0
const SECOND_ENERGY := 30.0
## Contra-ataque.
const COUNTER_ENERGY := 10.0
const COUNTER_ICD := 6.0

var f: BattleFighter
var corner_t := 0.0
var leap_cd := 0.0
var counter_cd := 0.0
var second_used := false
## Esquiva de lado em andamento: quem investiu e o HP de antes (contra-ataque se não pegar).
var _dodge_from: BattleFighter = null
var _dodge_hp := 0
var _hooked := false


func _init(fighter: BattleFighter) -> void:
	f = fighter


## Um passo: recargas, segundo fôlego, contra-ataque e o pulo. true = o pulo saiu agora.
func tick(dt: float) -> bool:
	leap_cd = maxf(leap_cd - dt, 0.0)
	counter_cd = maxf(counter_cd - dt, 0.0)
	if not f.energy_mode or not f.alive():
		return false
	if not _hooked and f.arena and f.arena.has_signal("dodged"):
		_hooked = true
		f.arena.dodged.connect(_on_dodged)
	_second_wind()
	_watch_dodge()
	if f.motion != "":
		return false
	if not cornered(dt):
		return false
	return leap()


## Encurralado agora (conta o tempo com inimigo perto da parede).
func cornered(dt: float) -> bool:
	var me := f.pos2(f.position)
	if _wall_dist(me) >= CORNER_WALL:
		corner_t = 0.0
		return false
	var near := 0
	var close := 0
	for g in f.arena.targets_of(f):
		var dd := f.flat_to(g).length()
		if dd < CORNER_FOE:
			near += 1
		if dd < CORNER_PAIR:
			close += 1
	if near == 0:
		corner_t = 0.0
		return false
	corner_t += dt
	return corner_t >= CORNER_SECS or close >= 2


## Pode pular agora (no chão, livre, sem golpe saindo).
func can_leap() -> bool:
	return (
		leap_cd <= 0.0
		and f.can_act()
		and f.motion == ""
		and f.launch_t <= 0.0
		and f.root_t <= 0.0
		and f.trap_t <= 0.0
		and f.prepare_t <= 0.0
		and f.dash_t <= 0.0
		and f.lunge_t <= 0.0
		and f.air_t <= 0.0
		and f.hidden == ""
		and not (f.arena.get("moves") and f.arena.moves.effects.no_jump())
	)


## Pulo de desespero: salta para o melhor ponto aberto; false se não dá (recarga, preso, sem ponto).
func leap() -> bool:
	if not can_leap():
		return false
	var to := landing()
	if to == Vector3.INF:
		return false
	leap_cd = LEAP_CD
	corner_t = 0.0
	var spot := Vector3(to.x, 0.0, to.z)
	f.start_motion("leap", spot, LEAP_SECS, LEAP_H, null, _land, 0.0, Callable(), f.ground_y)
	f.popup("Pulo de desespero!", Color(0.75, 0.95, 1.0), 1.0, 0.8)
	_note("pulo_desespero")
	if f.ai:
		f.ai.on_leap()
	return true


## Melhor ponto de pouso: LEAP_DIST m na direção do centro girada até ±90° (passa pelo lado do
## inimigo), dentro da quadra com LEAP_MARGIN da parede, longe dos inimigos e fora de pico que não
## escala. INF = nenhum serve.
func landing() -> Vector3:
	var me := f.pos2(f.position)
	var r: Rect2 = f.arena.rect
	var c := r.get_center()
	var to_c := Vector3(c.x, 0.0, c.y) - me
	if to_c.length() < 0.01:
		to_c = Vector3(1, 0, 0)
	to_c = to_c.normalized()
	var safe := r.grow(-LEAP_MARGIN)
	var foes: Array = f.arena.targets_of(f)
	var ter = f.arena.get("terrain")
	var best := Vector3.INF
	var best_s := -INF
	for deg in [0, 25, -25, 50, -50, 75, -75, 90, -90]:
		var dir := to_c.rotated(Vector3.UP, deg_to_rad(float(deg)))
		var p := me + dir * LEAP_DIST
		if not safe.has_point(Vector2(p.x, p.z)):
			# Encosta na margem: ainda vale se andou o bastante.
			p.x = clampf(p.x, safe.position.x, safe.end.x)
			p.z = clampf(p.z, safe.position.y, safe.end.y)
			if (p - me).length() < LEAP_DIST * 0.6:
				continue
		if ter != null and _blocked(ter, p):
			continue
		var near := INF
		for g in foes:
			near = minf(near, (f.pos2(g.position) - p).length())
		var s := minf(near, LAND_FOE * 1.5) * 1.5 + _wall_dist(p) * 0.4 - absf(float(deg)) * 0.01
		if near < LAND_FOE:
			s -= 3.0
		if s > best_s:
			best_s = s
			best = p
	return best


func _blocked(ter, p: Vector3) -> bool:
	for o in ter.obstacles:
		if o.kind == "peak" and ter.blocks(f, o) and (Vector3(p.x, 0, p.z) - o.pos).length() < o.r:
			return true
	return false


## Pousou: Fôlego (energia e recarga mais rápida por uns segundos).
func _land() -> void:
	if not is_instance_valid(f) or not f.active():
		return
	f.pp_max = minf(f.pp_max + BREATH_ENERGY, f.pp_base)
	f.breath_t = BREATH_SECS
	f.popup("Fôlego!", Color(0.6, 1.0, 0.7), 0.9, 0.6)
	PixelFx.pop(f.arena, "dust", f.pos2(f.position) + Vector3(0, 0.3, 0), 1.2, 0.35)


func _second_wind() -> void:
	if second_used or float(f.hp) > float(f.max_hp) * SECOND_HP or f.pp_max >= SECOND_EN:
		return
	second_used = true
	f.pp_max = minf(f.pp_max + SECOND_ENERGY, f.pp_base)
	f.popup("Segundo fôlego!", Color(0.6, 1.0, 0.7), 1.0, 0.8)
	_note("segundo_folego")


## Esquiva de lado começou (BattleAI._dodge): acompanha até a investida acabar.
func on_body_dodge(att: BattleFighter) -> void:
	_dodge_from = att
	_dodge_hp = f.hp


## A investida passou por baixo no pulo (sinal "dodged" com "under").
func _on_dodged(who, what: String) -> void:
	if who == f and what == "under":
		_counter()


func _watch_dodge() -> void:
	if _dodge_from == null:
		return
	if not is_instance_valid(_dodge_from) or not _dodge_from.active():
		_dodge_from = null
		return
	if _dodge_from.dash_t > 0.0 or _dodge_from.lunge_t > 0.0:
		return
	if f.hp >= _dodge_hp:
		_counter()
	_dodge_from = null


func _counter() -> void:
	if counter_cd > 0.0 or not f.energy_mode:
		return
	counter_cd = COUNTER_ICD
	f.pp_max = minf(f.pp_max + COUNTER_ENERGY, f.pp_base)
	f.popup("Contra-ataque!", Color(1.0, 0.9, 0.5), 0.9, 0.6)
	_note("contra_ataque")


func _note(p: String) -> void:
	var tel = f.arena.get("telemetry") if f.arena else null
	if tel:
		tel.note("passive", {"p": p, "who": tel.uid(f)})


func _wall_dist(p: Vector3) -> float:
	var r: Rect2 = f.arena.rect
	return minf(minf(p.x - r.position.x, r.end.x - p.x), minf(p.z - r.position.y, r.end.y - p.z))

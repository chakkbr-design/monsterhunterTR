class_name BattleRegroup
extends RefCounted
## Reagrupar depois de um nocaute no modo de energia (Caio, 2026-10-26): quando qualquer Pokémon
## desmaia a luta para para todos (arena.energy_pause = "regroup"). Os projéteis em voo somem, os
## golpes em andamento são cortados e os eventos de golpe (correntes, zonas, acertos atrasados)
## ficam congelados; só os eventos da própria arena (recolher, mandar o substituto) seguem. Quem
## está de pé volta andando para o ponto onde entrou (meta "start_at", gravada em _spawn), sem
## golpes, sem dano e sem os timers (energia, cooldowns, status) andarem. A luta volta quando todo
## lugar que pode ser preenchido (1 por lado no 1x1, 2 no 2x2, menos se o lado não tem mais
## ninguém) está em campo, com a bola aberta, e todos estão a NEAR m do ponto de entrada; ou depois
## de MAX_SECS s de luta, para nunca travar. Também roda no fast_sim (é jogo, não câmera).

## Chegou ao ponto de entrada.
const NEAR := 0.75
## Teto de segurança (segundos de luta): o reagrupar nunca segura a luta mais que isto.
const MAX_SECS := 10.0
## Sem chegar NEAR_GAIN m mais perto por STUCK_SECS s (preso num objeto, rodeando um perigo do
## chão, empurrado pelo vizinho): anda em linha reta atravessando o que houver.
const STUCK_SECS := 1.2
const NEAR_GAIN := 0.15
## Todos chegam em até uns tantos segundos, por mais longe ou lento que estejam.
const ARRIVE_SECS := 4.5
## Nem em linha reta chega mais perto por GIVE_UP_SECS s (empurrado por um sólido ou pelo
## vizinho): fica onde está e conta como chegado, para a luta não esperar o teto.
const GIVE_UP_SECS := 2.5
## Depois disto todos andam em linha reta (o desvio do relevo pode dar voltas sem chegar nunca).
const STRAIGHT_SECS := 3.0

## A arena (sem tipo: os campos dela são lidos direto).
var arena
## Segundos de luta desde o começo do reagrupar.
var t := 0.0
var _fresh := false
## Por lutador (instance id): [menor distância até o ponto, t em que ela melhorou].
var _best := {}


func _init(a) -> void:
	arena = a


## Ponto de entrada do lutador (onde a bola o soltou; na troca, o de quem saiu).
static func start_of(f: BattleFighter) -> Vector3:
	var p: Vector3 = f.get_meta("start_at", f.position)
	return Vector3(p.x, 0.0, p.z)


## Para onde o reagrupar anda: o ponto de entrada dentro da área em que _walk deixa andar.
func goal_of(f: BattleFighter) -> Vector3:
	var p := start_of(f)
	var b: Rect2 = arena.rect.grow(-0.5)
	return Vector3(clampf(p.x, b.position.x, b.end.x), 0.0, clampf(p.z, b.position.y, b.end.y))


## Um Pokémon desmaiou (a luta não acabou): começa (ou recomeça) o reagrupar.
func begin() -> void:
	arena.energy_pause = "regroup"
	t = 0.0
	_fresh = true
	_best.clear()
	if arena.telemetry:
		arena.telemetry.note("regroup_begin")


## Passo do reagrupar (dt de luta). Devolve true quando a luta volta.
func step(dt: float) -> bool:
	if _fresh:
		_fresh = false
		_halt()
	t += dt
	for f in arena.fighters.duplicate():
		if is_instance_valid(f) and f.active():
			_walk(f, dt)
	arena._separate()
	if (filled() and home()) or t >= MAX_SECS:
		_finish()
		return true
	return false


## Corta o que está no ar: projéteis somem, golpe preparando ou em movimento acaba, sem empurrão.
func _halt() -> void:
	for p in arena.projectiles:
		if is_instance_valid(p):
			p.queue_free()
	arena.projectiles.clear()
	arena.telegraphs.clear()
	for f in arena.fighters:
		if not is_instance_valid(f):
			continue
		f.clear_prepare()
		if f.motion != "":
			f.end_motion()
		f.dash_t = 0.0
		f.lunge_t = 0.0
		f.arc_step_t = 0.0
		f.launch_t = 0.0
		f.knock = Vector3.ZERO
		f.impact_knock = Vector3.ZERO
		f.sprinting = false
		f.air_t = 0.0
		f.air_h = 0.0


## Todo lugar que pode ser preenchido está em campo (bola aberta) e ninguém está para entrar.
func filled() -> bool:
	if not arena._pending.is_empty() or int(arena._enemy_pending) > 0:
		return false
	if not arena._balls.is_empty():
		return false
	var slots := 2 if arena.doubles else 1
	for side in [0, 1]:
		var list: Array = arena.party if side == 0 else arena.enemies
		var healthy := 0
		for m in list:
			if m is Mon and not m.is_fainted():
				healthy += 1
		var on := 0
		for f in arena.fighters:
			if (
				is_instance_valid(f)
				and f.side == side
				and f.active()
				and (f.visible or f.hidden == "commander")
			):  # Tatsugiri na boca do Dondozo
				on += 1
		if on < mini(slots, healthy):
			return false
	return true


## Todos de pé estão no ponto de entrada.
func home() -> bool:
	for f in arena.fighters:
		if is_instance_valid(f) and f.active():
			var d: Vector3 = goal_of(f) - f.position
			d.y = 0.0
			if d.length() > NEAR and not gave_up(f):
				return false
	return true


## Parou de chegar mais perto há GIVE_UP_SECS s.
func gave_up(f: BattleFighter) -> bool:
	var b: Array = _best.get(f.get_instance_id(), [INF, t])
	return t - float(b[1]) > GIVE_UP_SECS


func _finish() -> void:
	arena.energy_pause = ""
	if arena.telemetry:
		_report()
	for f in arena.fighters:
		if is_instance_valid(f) and f.active():
			f.velocity = Vector3.ZERO
			var foe := _nearest_foe(f)
			if foe:
				f.facing = f.flat_to(foe).normalized()
	if arena.hud and not bool(arena.opts.get("fast_sim", false)) and arena.state == "fight":
		arena.hud.fight_flash("Fight!")


## Bateria: quanto o reagrupar durou, se estourou o teto e quem ficou longe do ponto de entrada.
func _report() -> void:
	var far := []
	for f in arena.fighters:
		if is_instance_valid(f) and f.active():
			var d: Vector3 = goal_of(f) - f.position
			d.y = 0.0
			if d.length() > NEAR:
				var g := goal_of(f)
				var row := {
					"id": arena.telemetry.uid(f),
					"d": snappedf(d.length(), 0.01),
					"gave_up": gave_up(f),
					"pos": [snappedf(f.position.x, 0.01), snappedf(f.position.z, 0.01)],
					"goal": [snappedf(g.x, 0.01), snappedf(g.z, 0.01)],
					"gy": snappedf(f.ground_y, 0.01),
					"fly": snappedf(f.fly_h, 0.01),
					"hidden": f.hidden,
					"motion": f.motion,
					"best": snappedf(float(_best.get(f.get_instance_id(), [-1.0])[0]), 0.01),
					"slide": arena.terrain != null and arena.terrain.sliding(f),
				}
				far.append(row)
	arena.telemetry.note(
		"regroup_end",
		{"secs": snappedf(t, 0.01), "timeout": t >= MAX_SECS, "filled": filled(), "far": far}
	)


## Anda (passo normal, sem correr) até o ponto de entrada, contornando o relevo.
func _walk(f: BattleFighter, dt: float) -> void:
	var to := goal_of(f) - f.position
	to.y = 0.0
	var dist := to.length()
	var k := f.get_instance_id()
	var b: Array = _best.get(k, [INF, t])
	if dist < float(b[0]) - NEAR_GAIN:
		b = [dist, t]
		_best[k] = b
	var straight := t - float(b[1]) > STUCK_SECS or t > STRAIGHT_SECS
	var want := Vector3.ZERO
	if dist > 0.05:
		want = to / dist
		if arena.terrain and not straight:
			want = arena.terrain.steer(f, want)
	var before := f.position
	# Lento, na lama ou do outro lado da quadra de 48 m: apressa o passo para chegar em ARRIVE_SECS.
	var speed: float = maxf(f.walk_speed(), dist / maxf(ARRIVE_SECS - t, 0.5))
	if want.length() > 0.01:
		var stride := minf(speed * dt, dist)
		f.position += want.normalized() * stride
		f.velocity = want.normalized() * speed
		f.facing = want.normalized()
	else:
		f.velocity = Vector3.ZERO
		var foe := _nearest_foe(f)
		if foe and f.flat_to(foe).length() > 0.01:
			f.facing = f.flat_to(foe).normalized()
	f.position.y = f.ground_y + f.air_h + f.fly_h
	if arena.terrain:
		arena.terrain.settle(f, dt)
	if arena.fixed and not straight:
		arena._block_solid(f, before)
	var bounds: Rect2 = arena.rect.grow(-0.5)
	f.position.x = clampf(f.position.x, bounds.position.x, bounds.end.x)
	f.position.z = clampf(f.position.z, bounds.position.y, bounds.end.y)
	if f.facing.length() > 0.01:
		f.rotation.y = atan2(-f.facing.x, -f.facing.z)


func _nearest_foe(f: BattleFighter) -> BattleFighter:
	var best: BattleFighter = null
	var bd := INF
	for o in arena.fighters:
		if is_instance_valid(o) and o.side != f.side and o.active():
			var d := f.flat_to(o).length()
			if d < bd:
				bd = d
				best = o
	return best

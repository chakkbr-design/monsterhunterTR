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

## A arena (sem tipo: os campos dela são lidos direto).
var arena
## Segundos de luta desde o começo do reagrupar.
var t := 0.0
var _fresh := false


func _init(a) -> void:
	arena = a


## Ponto de entrada do lutador (onde a bola o soltou; na troca, o de quem saiu).
static func start_of(f: BattleFighter) -> Vector3:
	var p: Vector3 = f.get_meta("start_at", f.position)
	return Vector3(p.x, 0.0, p.z)


## Um Pokémon desmaiou (a luta não acabou): começa (ou recomeça) o reagrupar.
func begin() -> void:
	arena.energy_pause = "regroup"
	t = 0.0
	_fresh = true


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
			if is_instance_valid(f) and f.side == side and f.active() and f.visible:
				on += 1
		if on < mini(slots, healthy):
			return false
	return true


## Todos de pé estão no ponto de entrada.
func home() -> bool:
	for f in arena.fighters:
		if is_instance_valid(f) and f.active():
			var d: Vector3 = start_of(f) - f.position
			d.y = 0.0
			if d.length() > NEAR:
				return false
	return true


func _finish() -> void:
	arena.energy_pause = ""
	for f in arena.fighters:
		if is_instance_valid(f) and f.active():
			f.velocity = Vector3.ZERO
			var foe := _nearest_foe(f)
			if foe:
				f.facing = f.flat_to(foe).normalized()
	if arena.hud and not bool(arena.opts.get("fast_sim", false)) and arena.state == "fight":
		arena.hud.fight_flash("Fight!")


## Anda (passo normal, sem correr) até o ponto de entrada, contornando o relevo.
func _walk(f: BattleFighter, dt: float) -> void:
	var to := start_of(f) - f.position
	to.y = 0.0
	var dist := to.length()
	var want := Vector3.ZERO
	if dist > 0.05:
		want = to / dist
		if arena.terrain:
			want = arena.terrain.steer(f, want)
	var before := f.position
	var speed: float = f.walk_speed()
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
	if arena.fixed:
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

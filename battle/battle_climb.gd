class_name BattleClimb
extends RefCounted
## Obstáculos no modo de energia (Caio, 2026-10-26): ninguém sobe encosta andando nem atravessa objeto.
## A arena cria um por luta (terrain.climb).
##
## - Níveis: morro e pico viram degraus de ~LEVEL m (n = altura / LEVEL arredondado, mín. 1; o morro
##   pequeno e o médio têm 1, o grande e o pico 2). O degrau k vai até o raio ring(o, k) (o de baixo é o
##   raio todo, o de cima o topo) e tem altura h x k / n. Todo mundo para na beira do degrau mais alto
##   que o chão em que está (push_out). Descer andando da beira é de graça (cai como antes).
## - Objetos sólidos (caixa/pedra, árvore, cristal, Voltorb, colmeia, arbusto, pedregulho, coluna, monte,
##   pilar, pedrinhas) barram para todos: o voo de cruzeiro e o pulinho de esquiva não passam mais por
##   cima (pass_h). Lago não é obstáculo (as regras da água continuam); grama, cogumelo, gêiser, tronco
##   caído e montinho de neve continuam baixos e atravessáveis.
## - Salto (qualquer Pokémon): JUMP_COST de energia, recarga JUMP_CD s (o pulo de desespero divide os
##   dois). Sobe no máximo um degrau por vez (ou desce, ou passa por cima de objeto de até HOP_H m), até
##   JUMP_MAX m de distância, num arco com agachar/esticar/achatar e poeira no pouso.
## - Voo (tipo Voador ou perfil Voador; Levitate não voa, só flutua): FLY_COST, recarga FLY_CD s. Sobe a
##   FLY_ALT m (acima de árvore e coluna), vai até FLY_MAX m e pousa em qualquer altura.
## - IA (steer, no fim do BattleTerrain.steer): com o caminho até o objetivo (ai.nav_goal ou o alvo)
##   tapado, A* numa grade de CELL m feita dos obstáculos (refeita a cada GRID_EVERY s e quando algo
##   muda: BattleTerrain.on_obstacles_changed), com o salto custando JUMP_PEN células + a espera da
##   recarga/energia. Segue o caminho e salta nos degraus/objetos; quem voa voa quando o caminho tem dois
##   saltos ou mais, dá muita volta ou não chega.

## Altura de um nível (a caixa tem 0,85 m; o morro médio 0,9-1,15 m).
const LEVEL := 0.8
const CRATE_H := 0.85  ## caixa/pedra do BattleField (altura do visual)
const JUMP_COST := 10.0
const JUMP_CD := 5.0
const FLY_COST := 10.0
const FLY_CD := 15.0
const JUMP_MAX := 2.8  ## alcance do salto (m, no plano)
const JUMP_SECS := 0.42  ## duração do salto: JUMP_SECS + JUMP_SECS_M por metro
const JUMP_SECS_M := 0.06
const JUMP_APEX := 0.55  ## o arco passa JUMP_APEX m acima do mais alto entre saída e pouso
const HOP_H := 1.05  ## objeto sólido até HOP_H m acima do chão de saída: dá para pular por cima
const FLY_MAX := 16.0
const FLY_SPEED := 6.5
const FLY_ALT := 3.3
const FLY_RISE := 0.45  ## s subindo (e descendo) no começo/fim do voo
const EDGE := 0.1  ## folga do centro do corpo até a beira do degrau de cima
const STEP_TOL := 0.12
const LAND_IN := 0.25  ## pouso a pelo menos LAND_IN m da beira do degrau
const BODY_R := 0.4
## Grade da IA.
const CELL := 0.5
const INFLATE := 0.45  ## corpo em volta dos objetos sólidos
const GRID_EVERY := 1.0
const PATH_AGE := 1.5  ## refaz o caminho depois de PATH_AGE s ou com o objetivo PATH_MOVE m longe
const PATH_MOVE := 1.5
const LOOK := 8.0  ## olha a linha até o objetivo até LOOK m
const MAX_EXPAND := 3000
const JUMP_PEN := 4.0  ## custo do salto no A* (células de 0,5 m), mais 2 por segundo de espera
const WADE_COST := 1.7  ## célula de lago para quem não nada
const WAIT_MAX := 6.0  ## esperando a recarga na beira por mais que isso: desiste por GIVEUP s
const GIVEUP := 3.0
const FLY_DETOUR := 1.6  ## voa se o caminho a pé custa mais que FLY_DETOUR x a reta (+6 células)
const DIRS := [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
	Vector2i(1, 1),
	Vector2i(1, -1),
	Vector2i(-1, 1),
	Vector2i(-1, -1)
]

var terrain  ## BattleTerrain (dono)
var arena: Node
var on := false  ## ligado no setup do relevo
var _dirty := true
var _built_t := -INF
var _clock := 0.0
var _rev := -1
var _org := Vector2.ZERO
var _cols := 0
var _rows := 0
var _lv := PackedInt32Array()  ## degrau por célula (0 = chão)
var _ob := PackedInt32Array()  ## índice em _obs do morro/pico da célula (-1 = chão)
var _solid := PackedFloat32Array()  ## topo do objeto sólido na célula (0 = livre)
var _wet := PackedByteArray()  ## 1 = lago
var _obs: Array = []
var _hn := PackedInt32Array()  ## fila do A* (heap): célula
var _hk := PackedFloat32Array()  ## e prioridade
## id do lutador -> {goal, t, pts: [[Vector3, salto?]], i, wait0, fails, off}
var _nav := {}


func _init(t) -> void:
	terrain = t
	arena = t.arena


## No começo do setup do relevo: liga.
func prepare() -> void:
	on = true
	_dirty = true


## Morro/pico novo: guarda quantos níveis ele tem (antes do visual).
func tag(o: Dictionary) -> void:
	if on and String(o.kind) in ["hill", "peak"]:
		o["lv_n"] = maxi(1, roundi(float(o.h) / LEVEL))


## Algo mudou (obstáculo novo, destruído, rebaixado): a grade da IA é refeita no próximo uso.
func dirty() -> void:
	_dirty = true


func tick(dt: float) -> void:
	_clock += dt


# --- Níveis ---


static func tiers(o: Dictionary) -> int:
	return int(o.get("lv_n", 0))


## Raio do degrau k (1 = o de baixo, o raio todo; n = o topo).
static func ring(o: Dictionary, k: int) -> float:
	var n := tiers(o)
	var r := float(o.r)
	if n <= 1 or k <= 1:
		return r
	var top := minf(float(o.top), r)
	return r - (r - top) * float(k - 1) / float(n - 1)


## Degrau em `p` (0 = fora).
static func tier_of(o: Dictionary, p: Vector3) -> int:
	var c: Vector3 = o.pos
	return tier_at_d(o, Vector2(p.x - c.x, p.z - c.z).length())


static func tier_at_d(o: Dictionary, d: float) -> int:
	for k in range(tiers(o), 0, -1):
		if d < ring(o, k):
			return k
	return 0


static func tier_h(o: Dictionary, k: int) -> float:
	var n := tiers(o)
	if n <= 0 or k <= 0:
		return 0.0
	return float(o.h) * float(mini(k, n)) / float(n)


## Altura do chão em `p` (degraus no lugar da encosta).
static func step_height(o: Dictionary, p: Vector3) -> float:
	return tier_h(o, tier_of(o, p))


## Perfil do visual voxel (ArenaVoxels) à distância d do centro.
static func profile(o: Dictionary, d: float) -> float:
	return tier_h(o, tier_at_d(o, d))


## Altura que conta para passar por cima de objeto sólido: só no salto/voo (motion "leap"); o voo de
## cruzeiro e o pulinho de esquiva não passam.
static func pass_h(f: BattleFighter) -> float:
	return f.position.y if f.motion == "leap" else 0.0


## {o, k} do degrau em `p` ({} = chão).
func tier_at(p: Vector3) -> Dictionary:
	for o in terrain.obstacles:
		if tiers(o) > 0:
			var k := tier_of(o, p)
			if k > 0:
				return {"o": o, "k": k}
	return {}


## Deslocamento que tira o lutador de dentro de um degrau mais alto que o chão dele (para na beira).
func push_out(f: BattleFighter) -> Vector3:
	if not on or f.motion != "" or f.hidden != "":
		return Vector3.ZERO
	var out := Vector3.ZERO
	var top := f.ground_y + STEP_TOL
	for o in terrain.obstacles:
		if tiers(o) == 0:
			continue
		var k := tier_of(o, f.position)
		if k == 0 or tier_h(o, k) <= top:
			continue
		var j := k - 1
		while j > 0 and tier_h(o, j) > top:
			j -= 1
		var c: Vector3 = o.pos
		var d := Vector3(f.position.x - c.x, 0.0, f.position.z - c.z)
		if d.length() < 0.001:
			d = Vector3(0.001, 0.0, 0.0)
		out += d.normalized() * maxf(ring(o, j + 1) + EDGE - d.length(), 0.0)
	return out


## Objetos sólidos da quadra: [pos, raio do corpo, topo (m do chão)].
func solids() -> Array:
	var out: Array = []
	if arena.get("field") != null:
		for o in arena.field.objects:
			out.append([o.pos, BattleField.OBJ_R, CRATE_H])
	for o in terrain.props.items:
		if BattleProps.SOLID_R.has(o.kind):
			var top: float = float(o.get("y", 0.0)) + float(BattleProps.COVER_H.get(o.kind, 0.9))
			out.append([o.pos, float(BattleProps.SOLID_R[o.kind]), top])
	if terrain.biomes.on:
		for s in terrain.biomes.solids:
			out.append([s.pos, float(s.r), float(s.h)])
	var ex = terrain.ground.extras
	for py in ex.pylons:
		out.append([py.pos, BattleGroundExtras.PYLON_BODY, BattleGroundExtras.PYLON_H])
	if not ex.buried:
		for r in ex.rocks:
			out.append([r.pos, BattleGroundExtras.ROCK_R, BattleGroundExtras.ROCK_H])
	return out


# --- Salto e voo ---


## Livre para saltar/voar agora (no chão, sem golpe saindo, sem estar preso).
func _free(f: BattleFighter) -> bool:
	return (
		f.alive()
		and f.can_act()
		and f.status != "sleep"
		and f.motion == ""
		and f.launch_t <= 0.0
		and f.root_t <= 0.0
		and f.trap_t <= 0.0
		and f.prepare_t <= 0.0
		and f.dash_t <= 0.0
		and f.lunge_t <= 0.0
		and f.air_t <= 0.0
		and f.hidden == ""
		and not (arena.get("moves") != null and arena.moves.effects.no_jump())
	)  # Gravity


func jump_ready(f: BattleFighter) -> bool:
	return f.jump_cd <= 0.0 and f.pp_max >= JUMP_COST and _free(f)


## Voa: tipo Voador ou perfil Voador (o mesmo que cruza a ~1,3 m); Smack Down/Thousand Arrows não.
func can_fly(f: BattleFighter) -> bool:
	if not ("flying" in f.types or float(f.prof.get("fly", 0.0)) > 0.0):
		return false
	var mv = arena.get("moves")
	return not (mv != null and mv.effects.active(mv.effects.st(f), "smacked"))


func fly_ready(f: BattleFighter) -> bool:
	return can_fly(f) and f.fly_cd <= 0.0 and f.pp_max >= FLY_COST and _free(f)


## O salto até `to` vale: no máximo `reach` m, dentro da quadra, sobe no máximo um degrau, nada mais
## alto no caminho, objeto no caminho baixo o bastante e pouso fora de objeto.
func jump_ok(f: BattleFighter, to: Vector3, reach := JUMP_MAX) -> bool:
	var a := f.pos2(f.position)
	var b := f.pos2(to)
	var dist := (b - a).length()
	if dist > reach or not arena.rect.grow(-0.5).has_point(Vector2(b.x, b.z)):
		return false
	if not on:
		return true
	var from_t := tier_at(a)
	var to_t := tier_at(b)
	if not to_t.is_empty():
		var kf := 0
		if not from_t.is_empty() and is_same(from_t.o, to_t.o):
			kf = int(from_t.k)
		if int(to_t.k) > kf + 1:
			return false
	var top := maxf(f.ground_y, float(terrain.height_at(b))) + STEP_TOL
	var steps := maxi(1, ceili(dist / 0.2))
	for i in range(1, steps):
		if float(terrain.height_at(a.lerp(b, float(i) / float(steps)))) > top:
			return false
	for s in solids():
		var sp: Vector3 = s[0]
		var sr: float = s[1]
		if Vector2(b.x - sp.x, b.z - sp.z).length() < sr + BODY_R:
			return false
		if _seg_dist(a, b, sp) < sr + BODY_R * 0.5 and float(s[2]) > f.ground_y + HOP_H:
			return false
	return true


## Salta até `to` (custa JUMP_COST, recarga JUMP_CD). false se não pode ou o salto não vale.
func jump(f: BattleFighter, to: Vector3) -> bool:
	if not jump_ready(f) or not jump_ok(f, to):
		return false
	pay_jump(f)
	var b := f.pos2(to)
	var dist := (b - f.pos2(f.position)).length()
	arc(f, b, JUMP_SECS + JUMP_SECS_M * dist, _apex(f, b), "climb")
	var lv := tier_at(b)
	_note("climb_jump", f, {"lv": int(lv.get("k", 0))})
	return true


func pay_jump(f: BattleFighter) -> void:
	f.spend(JUMP_COST)
	f.jump_cd = JUMP_CD


## Altura do topo do arco até `b`: acima da saída, do pouso e do que passa por baixo.
func _apex(f: BattleFighter, b: Vector3) -> float:
	var a := f.pos2(f.position)
	var y1: float = float(terrain.height_at(b)) + f.fly_h
	var peak := maxf(f.position.y, y1) + JUMP_APEX
	for s in solids():
		var sp: Vector3 = s[0]
		if _seg_dist(a, b, sp) < float(s[1]) + BODY_R:
			peak = maxf(peak, float(s[2]) + 0.35)
	return peak


## Arco de salto (motion "leap") até `to`, com topo `peak` (m): sai da altura de agora e pousa na
## altura do chão de lá. `style` dá o agachar/esticar (BattleFighter._leap_squash); `cb` no pouso,
## `extra(f, s, dt)` a cada passo (rastro do pulo de desespero).
func arc(
	f: BattleFighter,
	to: Vector3,
	secs: float,
	peak: float,
	style: String,
	cb := Callable(),
	extra := Callable()
) -> void:
	var y0 := f.position.y
	var y1: float = float(terrain.height_at(to)) + f.air_h + f.fly_h
	f.leap_style = style
	if style != "desperate" and _visual():
		PixelFx.pop(arena, "dust", f.pos2(f.position) + Vector3(0, f.ground_y + 0.2, 0), 1.2, 0.35)
	f.start_motion(
		"leap",
		f.pos2(to),
		secs,
		0.0,
		null,
		_landed.bind(f, cb, style),
		0.0,
		_arc_tick.bind(y0, y1, maxf(peak, maxf(y0, y1) + 0.2), extra),
		f.ground_y
	)


func _arc_tick(
	who: BattleFighter, s: float, dt: float, y0: float, y1: float, peak: float, extra: Callable
) -> void:
	var mid := (y0 + y1) * 0.5
	who.position.y = lerpf(y0, y1, s) + (peak - mid) * 4.0 * s * (1.0 - s)
	if extra.is_valid():
		extra.call(who, s, dt)


## O voo até `to` vale: até FLY_MAX m, dentro da quadra e pouso fora de objeto (qualquer altura).
func fly_ok(f: BattleFighter, to: Vector3) -> bool:
	var a := f.pos2(f.position)
	var b := f.pos2(to)
	var dist := (b - a).length()
	if dist > FLY_MAX or dist < 0.3 or not arena.rect.grow(-0.5).has_point(Vector2(b.x, b.z)):
		return false
	for s in solids():
		var sp: Vector3 = s[0]
		if Vector2(b.x - sp.x, b.z - sp.z).length() < float(s[1]) + BODY_R:
			return false
	return true


## Voa até `to` (custa FLY_COST, recarga FLY_CD): sobe, cruza acima de tudo e pousa lá.
func fly(f: BattleFighter, to: Vector3) -> bool:
	if not fly_ready(f) or not fly_ok(f, to):
		return false
	f.spend(FLY_COST)
	f.fly_cd = FLY_CD
	var b := f.pos2(to)
	var dist := (b - f.pos2(f.position)).length()
	var secs := FLY_RISE * 2.0 + dist / FLY_SPEED
	var y0 := f.position.y
	var y1: float = float(terrain.height_at(b)) + f.air_h + f.fly_h
	var alt := maxf(FLY_ALT, maxf(y0, y1) + 1.0)
	f.leap_style = "fly"
	if _visual():
		PixelFx.pop(arena, "wind", f.pos2(f.position) + Vector3(0, f.ground_y + 0.3, 0), 1.4, 0.4)
	f.start_motion(
		"leap",
		b,
		secs,
		0.0,
		null,
		_landed.bind(f, Callable(), "fly"),
		0.0,
		_fly_tick.bind(y0, y1, alt, clampf(FLY_RISE / secs, 0.1, 0.4)),
		f.ground_y
	)
	_note("climb_fly", f, {"m": snappedf(dist, 0.1)})
	return true


func _fly_tick(
	who: BattleFighter, s: float, _dt: float, y0: float, y1: float, alt: float, a: float
) -> void:
	var y := alt
	if s < a:
		y = lerpf(y0, alt, smoothstep(0.0, 1.0, s / a))
	elif s > 1.0 - a:
		y = lerpf(alt, y1, smoothstep(0.0, 1.0, (s - (1.0 - a)) / a))
	who.position.y = y
	# Sobe quase no lugar, cruza e desce quase no lugar (não raspa no que está do lado).
	var hs := clampf((s - a * 0.6) / maxf(1.0 - a * 1.2, 0.01), 0.0, 1.0)
	var p := who.motion_from.lerp(who.motion_to, hs)
	who.position.x = p.x
	who.position.z = p.z


## Pousou: o chão é o de lá na hora (não para na beira) e achata o corpo.
func _landed(f: BattleFighter, cb: Callable, style: String) -> void:
	if not is_instance_valid(f) or not f.active():
		return
	terrain.land(f)
	f.position.y = f.ground_y + f.air_h + f.fly_h
	if style != "desperate":
		f.squash_t = 0.16
		if _visual():
			var at := f.pos2(f.position) + Vector3(0, f.ground_y + 0.15, 0)
			PixelFx.pop(arena, "dust", at, 1.6 if style == "climb" else 1.3, 0.4)
	if cb.is_valid():
		cb.call()


## Tecla de pulo do jogador: com algo tapando a frente, salta para o degrau/por cima
## do objeto na direção `dir`; quem voa, sem salto que sirva, voa. false = pulinho normal.
func player_jump(f: BattleFighter, dir: Vector3) -> bool:
	if not on or dir.length() < 0.1:
		return false
	_ensure()
	var d := f.pos2(dir).normalized()
	var p := f.pos2(f.position)
	if _line_ok(f, p, p + d * 1.0):
		return false
	for dist in [1.2, 1.6, 2.0, 2.4, 2.8, 0.8]:
		if jump(f, _landing(p + d * float(dist))):
			return true
	for dist in [6.0, 4.5, 3.0, 8.0]:
		if fly(f, p + d * float(dist)):
			return true
	return false


func _visual() -> bool:
	return arena.is_inside_tree() and not bool(arena.opts.get("fast_sim", false))


func _note(kind: String, f: BattleFighter, data: Dictionary) -> void:
	var tel = arena.get("telemetry")
	if tel:
		data["who"] = tel.uid(f)
		tel.note(kind, data)


static func _seg_dist(a: Vector3, b: Vector3, p: Vector3) -> float:
	var ab := Vector2(b.x - a.x, b.z - a.z)
	var ap := Vector2(p.x - a.x, p.z - a.z)
	var t := clampf(ap.dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return (ap - ab * t).length()


# --- IA: grade e A* ---


func _ensure() -> void:
	# obstacles_rev: contador do BattleTerrain (destruição) quando existe.
	var rev = terrain.get("obstacles_rev")
	if rev != null and int(rev) != _rev:
		_rev = int(rev)
		_dirty = true
	if _dirty or _cols == 0 or _clock - _built_t >= GRID_EVERY:
		_build()


func _idx(cx: int, cz: int) -> int:
	return cz * _cols + cx


func _cell_of(p: Vector3) -> Vector2i:
	return Vector2i(
		clampi(floori((p.x - _org.x) / CELL), 0, _cols - 1),
		clampi(floori((p.z - _org.y) / CELL), 0, _rows - 1)
	)


func _center(i: int) -> Vector3:
	var cz := floori(float(i) / float(_cols))
	var cx := i - cz * _cols
	return Vector3(_org.x + (float(cx) + 0.5) * CELL, 0.0, _org.y + (float(cz) + 0.5) * CELL)


func _cell_h(i: int) -> float:
	var k := _ob[i]
	return 0.0 if k < 0 or k >= _obs.size() else tier_h(_obs[k], _lv[i])


func _build() -> void:
	_dirty = false
	_built_t = _clock
	var rc: Rect2 = arena.rect
	_org = rc.position
	_cols = maxi(1, ceili(rc.size.x / CELL))
	_rows = maxi(1, ceili(rc.size.y / CELL))
	var n := _cols * _rows
	_lv.resize(n)
	_lv.fill(0)
	_ob.resize(n)
	_ob.fill(-1)
	_solid.resize(n)
	_solid.fill(0.0)
	_wet.resize(n)
	_wet.fill(0)
	_obs.clear()
	for o in terrain.obstacles:
		var pond: bool = o.kind == "pond"
		if not pond and tiers(o) == 0:
			continue
		var c: Vector3 = o.pos
		var r := float(o.r)
		var idx := _obs.size()
		if not pond:
			_obs.append(o)
		var lo := _cell_of(c - Vector3(r, 0.0, r))
		var hi := _cell_of(c + Vector3(r, 0.0, r))
		for cz in range(lo.y, hi.y + 1):
			for cx in range(lo.x, hi.x + 1):
				var i := _idx(cx, cz)
				var q := _center(i)
				if pond:
					if Vector2(q.x - c.x, q.z - c.z).length() < r:
						_wet[i] = 1
					continue
				var k := tier_of(o, q)
				if k > 0:
					_lv[i] = k
					_ob[i] = idx
	for s in solids():
		var sp: Vector3 = s[0]
		var rr: float = float(s[1]) + INFLATE
		var top: float = s[2]
		var lo := _cell_of(sp - Vector3(rr, 0.0, rr))
		var hi := _cell_of(sp + Vector3(rr, 0.0, rr))
		for cz in range(lo.y, hi.y + 1):
			for cx in range(lo.x, hi.x + 1):
				var i := _idx(cx, cz)
				var q := _center(i)
				if Vector2(q.x - sp.x, q.z - sp.z).length() < rr:
					_solid[i] = maxf(_solid[i], maxf(top, 0.05))


## Dá para andar em linha reta de `a` até `b` sem degrau mais alto nem objeto (pela grade).
func _line_ok(f: BattleFighter, a: Vector3, b: Vector3) -> bool:
	var top := f.ground_y + STEP_TOL
	var d := (b - a).length()
	var steps := maxi(1, ceili(d / 0.25))
	for i in range(1, steps + 1):
		var q := a.lerp(b, float(i) / float(steps))
		if (q - a).length() < 0.35:
			continue
		var c := _cell_of(q)
		var j := _idx(c.x, c.y)
		if _solid[j] > 0.0 or _cell_h(j) > top:
			return false
	return true


## Célula livre (sem objeto) mais perto de `i` (até 3 anéis); a própria se já é livre.
func _free_near(i: int) -> int:
	if _solid[i] <= 0.0:
		return i
	var c := _center(i)
	var cc := _cell_of(c)
	for r in range(1, 4):
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dz)) != r:
					continue
				var x := cc.x + dx
				var z := cc.y + dz
				if x < 0 or z < 0 or x >= _cols or z >= _rows:
					continue
				var j := _idx(x, z)
				if _solid[j] <= 0.0:
					return j
	return i


func _hdist(i: int, t: int) -> float:
	var iz := floori(float(i) / float(_cols))
	var tz := floori(float(t) / float(_cols))
	var dx := absi((i - iz * _cols) - (t - tz * _cols))
	var dz := absi(iz - tz)
	return float(maxi(dx, dz)) + 0.4142 * float(mini(dx, dz))


func _hpush(node: int, key: float) -> void:
	_hn.append(node)
	_hk.append(key)
	var i := _hn.size() - 1
	while i > 0:
		var p := (i - 1) >> 1
		if _hk[p] <= _hk[i]:
			break
		_hswap(i, p)
		i = p


func _hpop() -> int:
	var top := _hn[0]
	var last := _hn.size() - 1
	_hn[0] = _hn[last]
	_hk[0] = _hk[last]
	_hn.resize(last)
	_hk.resize(last)
	var i := 0
	while true:
		var l := i * 2 + 1
		if l >= last:
			break
		var m := l
		if l + 1 < last and _hk[l + 1] < _hk[l]:
			m = l + 1
		if _hk[i] <= _hk[m]:
			break
		_hswap(i, m)
		i = m
	return top


func _hswap(a: int, b: int) -> void:
	var n := _hn[a]
	_hn[a] = _hn[b]
	_hn[b] = n
	var k := _hk[a]
	_hk[a] = _hk[b]
	_hk[b] = k


## Anda de (ob_a, lv_a) para (ob_b, lv_b): chão ou o mesmo morro sem subir.
static func _walks(ob_a: int, lv_a: int, ob_b: int, lv_b: int) -> bool:
	return ob_b < 0 or (ob_b == ob_a and lv_b <= lv_a)


## Salto que sobe um degrau (do chão/outro morro só para o primeiro).
static func _climbs(ob_a: int, lv_a: int, ob_b: int, lv_b: int) -> bool:
	return (ob_b == ob_a and lv_b == lv_a + 1) or (ob_b != ob_a and lv_b == 1)


## Caminho de `from` até `goal`: {pts: [[ponto, salto?]], cost, jumps, reached}. Sem chegar (limite
## de expansão), vai até a célula mais perto do objetivo.
func _astar(f: BattleFighter, from: Vector3, goal: Vector3, jumps_ok := true) -> Dictionary:
	var n := _cols * _rows
	var g := PackedFloat32Array()
	g.resize(n)
	g.fill(INF)
	var par := PackedInt32Array()
	par.resize(n)
	par.fill(-1)
	var how := PackedByteArray()
	how.resize(n)
	how.fill(0)
	var closed := PackedByteArray()
	closed.resize(n)
	closed.fill(0)
	var sc := _cell_of(from)
	var s := _idx(sc.x, sc.y)
	var gc := _cell_of(goal)
	var t := _free_near(_idx(gc.x, gc.y))
	# O nível de saída é o do chão em que o lutador está (a célula pode estar na beira).
	var s_lv := 0
	var s_ob := -1
	var st := tier_at(from)
	if not st.is_empty():
		s_lv = int(st.k)
		for k in _obs.size():
			if is_same(_obs[k], st.o):
				s_ob = k
	var swim: bool = terrain.swimmer(f)
	var wait := maxf(f.jump_cd, 0.0) + maxf(JUMP_COST - f.pp_max, 0.0) / BattleEnergy.REGEN
	var jpen := JUMP_PEN + wait * 2.0
	if not jumps_ok:
		jpen = INF  # só andando (o salto nunca sai mais barato)
	var hop_cells := floori(JUMP_MAX / CELL)
	_hn.resize(0)
	_hk.resize(0)
	g[s] = 0.0
	var best := s
	var best_h := _hdist(s, t)
	_hpush(s, best_h)
	var expanded := 0
	while not _hn.is_empty() and expanded < MAX_EXPAND:
		var i := _hpop()
		if closed[i] == 1:
			continue
		closed[i] = 1
		expanded += 1
		var hh := _hdist(i, t)
		if hh < best_h:
			best_h = hh
			best = i
		if i == t:
			break
		var iz := floori(float(i) / float(_cols))
		var ix := i - iz * _cols
		var lv_i := s_lv if i == s else _lv[i]
		var ob_i := s_ob if i == s else _ob[i]
		var h_i := 0.0
		if ob_i >= 0:
			h_i = tier_h(_obs[ob_i], lv_i)
		for dv in DIRS:
			var dx: int = dv.x
			var dz: int = dv.y
			var nx := ix + dx
			var nz := iz + dz
			if nx < 0 or nz < 0 or nx >= _cols or nz >= _rows:
				continue
			var j := _idx(nx, nz)
			var step := 1.4142 if dx != 0 and dz != 0 else 1.0
			var cost := 0.0
			var kind := 0
			var to := j
			if _solid[j] > 0.0:
				# Objeto: só pulando por cima, até a primeira célula livre do outro lado.
				if _solid[j] > h_i + HOP_H:
					continue
				to = -1
				for k in range(2, hop_cells + 1):
					var mx := ix + dx * k
					var mz := iz + dz * k
					if mx < 0 or mz < 0 or mx >= _cols or mz >= _rows:
						break
					var m := _idx(mx, mz)
					if _solid[m] > 0.0:
						if _solid[m] > h_i + HOP_H:
							break
						continue
					if (
						float(k) * step * CELL <= JUMP_MAX
						and (
							_walks(ob_i, lv_i, _ob[m], _lv[m])
							or _climbs(ob_i, lv_i, _ob[m], _lv[m])
						)
					):
						to = m
						cost = float(k) * step + jpen
						kind = 1
					break
				if to < 0:
					continue
			elif _walks(ob_i, lv_i, _ob[j], _lv[j]):
				cost = step * (WADE_COST if _wet[j] == 1 and not swim else 1.0)
			elif _climbs(ob_i, lv_i, _ob[j], _lv[j]):
				cost = step + jpen
				kind = 1
			else:
				continue
			if closed[to] == 1 or cost == INF:
				continue
			var ng := g[i] + cost
			if ng < g[to]:
				g[to] = ng
				par[to] = i
				how[to] = kind
				_hpush(to, ng + _hdist(to, t))
	var pts: Array = []
	var jumps := 0
	var c := best
	while c != s and c >= 0:
		pts.push_front([_center(c), how[c] == 1])
		if how[c] == 1:
			jumps += 1
		c = par[c]
	return {
		"pts": pts, "cost": g[best], "jumps": jumps, "reached": best == t, "straight": _hdist(s, t)
	}


## Ponto de pouso no degrau: puxa para dentro da faixa do degrau (LAND_IN da beira) pelo raio.
func _landing(raw: Vector3) -> Vector3:
	var lv := tier_at(raw)
	if lv.is_empty():
		return raw
	var o: Dictionary = lv.o
	var k: int = lv.k
	var c: Vector3 = o.pos
	var off := Vector3(raw.x - c.x, 0.0, raw.z - c.z)
	if off.length() < 0.01:
		return raw
	var outer := ring(o, k)
	var inner := 0.0 if k >= tiers(o) else ring(o, k + 1)
	var want := clampf(off.length(), inner + LAND_IN, outer - LAND_IN)
	if inner + LAND_IN > outer - LAND_IN:
		want = (inner + outer) * 0.5
	return c + off.normalized() * want


## Objetivo da IA: o ponto que ela pediu (nav_goal: alto, esconderijo) ou o alvo, se ela vai para ele.
## INF = só uma direção (rodear, recuar): segue sem caminho.
func _goal(f: BattleFighter, want: Vector3) -> Vector3:
	var ng: Vector3 = f.ai.nav_goal
	if ng != Vector3.INF:
		return f.pos2(ng)
	var opp := f.opponent
	if is_instance_valid(opp) and opp.active():
		var to := f.pos2(opp.position - f.position)
		if to.length() > 0.5 and want.normalized().dot(to.normalized()) > 0.5:
			return f.pos2(opp.position)
	return Vector3.INF


## Pouso do voo perto de `goal`: no próprio ponto, ou em volta (do mesmo nível, se der).
func _fly_spot(f: BattleFighter, goal: Vector3) -> Vector3:
	var p := f.pos2(f.position)
	var to := goal - p
	if to.length() > FLY_MAX - 0.2:
		goal = p + to.normalized() * (FLY_MAX - 0.2)
	var back := -to.normalized() if to.length() > 0.01 else Vector3.RIGHT
	var gh: float = terrain.height_at(goal)
	var any := Vector3.INF
	for deg in [0, 45, -45, 90, -90, 135, -135, 180]:
		for dist in [1.0, 0.0, 1.6]:
			var q: Vector3 = goal + back.rotated(Vector3.UP, deg_to_rad(float(deg))) * float(dist)
			if not fly_ok(f, q):
				continue
			if float(terrain.height_at(q)) >= gh - 0.2:
				return q
			if any == Vector3.INF:
				any = q
	return any


## IA (fim do BattleTerrain.steer): com o caminho até o objetivo tapado por degrau ou objeto, contorna
## pela grade, salta ou voa. Sem nada no caminho devolve `want` como veio.
func steer(f: BattleFighter, want: Vector3) -> Vector3:
	if not on or f.motion != "" or want.length() < 0.05:
		return want
	# Reagrupar depois do nocaute (BattleRegroup._walk, luta parada): volta andando ao ponto de
	# entrada contornando, sem salto nem voo (o movimento do salto não anda com a luta parada).
	var regroup: bool = str(arena.get("energy_pause")) == "regroup"
	if not regroup and (f.ai == null or f.controller != "ai" or not f.can_act()):
		return want
	var goal := Vector3.INF
	if regroup:
		var st: Vector3 = f.get_meta("start_at", f.position)
		goal = f.pos2(st)
	else:
		goal = _goal(f, want)
	var id := f.get_instance_id()
	if goal == Vector3.INF:
		_nav.erase(id)
		return want
	var nv: Dictionary = _nav.get(id, {})
	if float(nv.get("off", -INF)) > _clock:
		return want  # desistiu há pouco (salto que não vale, espera longa)
	_ensure()
	var p := f.pos2(f.position)
	var gd := (goal - p).length()
	# A linha para um pouco antes do objetivo (o alvo colado num objeto fica numa célula cheia).
	if gd < 1.1 or _line_ok(f, p, p + (goal - p) / gd * (minf(gd, LOOK) - 0.6)):
		_nav.erase(id)
		return want
	var fresh := (
		nv.is_empty()
		or not nv.has("pts")
		or _clock - float(nv.t) > PATH_AGE
		or (goal - Vector3(nv.goal)).length() > PATH_MOVE
	)
	if fresh or regroup != bool(nv.get("walk", false)):
		var res := _astar(f, p, goal, not regroup)
		nv = {
			"goal": goal,
			"t": _clock,
			"pts": res.pts,
			"i": 0,
			"wait0": -1.0,
			"fails": int(nv.get("fails", 0)),
			"walk": regroup
		}
		_nav[id] = nv
		var detour: bool = float(res.cost) > float(res.straight) * FLY_DETOUR + 6.0
		if not regroup and fly_ready(f) and (not res.reached or int(res.jumps) >= 2 or detour):
			var spot := _fly_spot(f, goal)
			if spot != Vector3.INF and fly(f, spot):
				_nav.erase(id)
				return Vector3.ZERO
	var pts: Array = nv.pts
	var i: int = nv.i
	while i < pts.size() and not bool(pts[i][1]):
		var q: Vector3 = pts[i][0]
		if (q - p).length() >= 0.4:
			break
		i += 1
	nv["i"] = i
	if i >= pts.size():
		# Fim do caminho (ou nenhum): segue como estava e só procura de novo daqui a pouco.
		nv.erase("pts")
		nv["off"] = _clock + 0.6
		return want
	if bool(pts[i][1]):
		var take: Vector3 = p if i == 0 else Vector3(pts[i - 1][0])
		if (take - p).length() > 0.45 and _line_ok(f, p, take):
			return (take - p).normalized() * maxf(want.length(), 0.8)
		if jump_ready(f):
			var raw: Vector3 = pts[i][0]
			if jump(f, _landing(raw)) or jump(f, raw):
				nv["i"] = i + 1
				nv["wait0"] = -1.0
				return Vector3.ZERO
			nv["fails"] = int(nv.fails) + 1
			if int(nv.fails) >= 3:
				nv["fails"] = 0
				nv["off"] = _clock + GIVEUP
			nv["t"] = -INF  # refaz o caminho
			return want
		# Esperando a recarga/energia na beira.
		if float(nv.wait0) < 0.0:
			nv["wait0"] = _clock
		elif _clock - float(nv.wait0) > WAIT_MAX:
			nv["off"] = _clock + GIVEUP
			nv["wait0"] = -1.0
			return want
		return Vector3.ZERO
	# Anda até o ponto mais longe do caminho que dá para ir em linha reta (antes de um salto).
	var j := i
	for k in range(i, mini(i + 7, pts.size())):
		if bool(pts[k][1]):
			break
		if _line_ok(f, p, Vector3(pts[k][0])):
			j = k
	var dst: Vector3 = pts[j][0]
	var dv := dst - p
	if dv.length() < 0.01:
		return want
	return dv.normalized() * maxf(want.length(), 0.8)

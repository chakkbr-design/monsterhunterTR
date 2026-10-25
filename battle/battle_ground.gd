class_name BattleGround
extends RefCounted
## Chão do cenário no modo de energia (só com opts.terrain e o modo de energia; o VGC não muda): lama,
## marcas de golpe no chão e a maré da praia. O BattleTerrain cria um (terrain.ground) e repassa os
## ganchos (setup, tick, settle, move_mult, regen_mult, acc_mult, damage_mult, on_move_landed, shot_block,
## steer). A IA tem um gancho só, BattleGround.steer_ai, no começo de BattleAI._energy_steer.
##
## - Lama (discos baixos, 0 a 2 por cenário, MUD_COUNT): quem pisa anda 0,6x, menos Terra, Água e Veneno.
##   Quem sai dela fica "enlameado" por MUDDY_SECS s (golpe à distância com precisão 0,9x). Golpe de Terra
##   que cai no chão abre uma poça de lama nova (no máx. MUD_NEW_MAX, somem em MUD_LIFE s). Sol seca a
##   lama até virar chão rachado (sem efeito); chuva espalha (raio até MUD_RAIN x) e segura a nova.
## - Marcas de golpe (temporárias, com limite por tipo):
##   fenda (Earthquake, Dig ou Terra com poder >= 80): vala de FISSURE_LEN m; quem está dentro fica
##   escondido de tiro e raio como atrás de cobertura baixa (FISSURE_SECS s);
##   gelo (golpe de Gelo no chão): escorrega, quem pisa mantém o embalo (ICE_SECS s, derrete no sol e
##   com Fogo); brasas (Fogo no chão): quem não é de Fogo e pisa toma um pouco e pode ficar queimado
##   (EMBER_SECS s, chuva apaga); poça (Água no chão): conduz Elétrico como o lago (PUDDLE_SECS s; chuva
##   alonga, sol seca). Água ou Terra numa poça a transforma em lama.
## - Praia (cenário "praia"): a maré enche meia quadra (a faixa de um lado comprido, alternando) a cada
##   ~30 s por TIDE_IN s, com TIDE_WARN s de aviso, e depois baixa. A água rasa segue as regras do lago
##   (Elétrico 1,3x, energia de Água/Grama maior, de Fogo menor), sem o dano no Fogo e só com o andar
##   na água rasa (TIDE_WADE). Na areia seca, quem é de Terra fica camuflado (golpe à distância x0,85).

## Lama por cenário (as outras coisas do cenário ficam em BattleTerrain.SCENARIOS).
const MUD_COUNT := {"campo": 1, "lagoa": 1, "misto": 2, "praia": 2}
const MUD_R := [1.2, 1.6]  ## raio da lama do cenário
const MUD_GAP := 0.3  ## distância mínima da borda da lama até a dos outros
const MUD_MULT := 0.6  ## andar na lama (quem não é imune)
const MUD_TYPES := ["ground", "water", "poison"]  ## não atolam
const MUDDY_SECS := 3.0  ## enlameado depois de sair da lama
const MUDDY_ACC := 0.9  ## precisão do golpe à distância de quem está enlameado
const MUD_NEW_R := 0.9
const MUD_NEW_MAX := 3  ## poças de lama novas ao mesmo tempo
const MUD_LIFE := 25.0
const MUD_DRY_SECS := 10.0  ## no sol a lama vira chão rachado em MUD_DRY_SECS s
const MUD_WET_SECS := 30.0  ## sem sol o chão rachado volta a ser lama em MUD_WET_SECS s (chuva 4x)
const MUD_RAIN := 1.3  ## chuva espalha a lama até MUD_RAIN x o raio
const MUD_GROW := 0.1  ## m/s
## Marcas de golpe.
const FISSURE_MOVES := ["earthquake", "dig"]
const FISSURE_POWER := 80.0
const FISSURE_LEN := 3.0
const FISSURE_W := 0.9  ## largura da vala
const FISSURE_SECS := 15.0
const FISSURE_EVADE := 0.5  ## tiro de longe contra quem está na fenda (precisão x0,5); raio para nela
const FISSURE_SEE := 2.0  ## colado (até FISSURE_SEE m) ou dentro da mesma fenda enxerga
const ICE_R := 1.0
const ICE_SECS := 10.0
const ICE_GRIP := 1.5  ## no gelo a velocidade muda devagar (embalo): fração por segundo
const EMBER_R := 0.8
const EMBER_SECS := 4.0
const EMBER_FRAC := 1.0 / 32.0  ## dano de quem pisa nas brasas (uma vez por brasa)
const EMBER_BURN := 0.08  ## chance de ficar queimado
const PUDDLE_R := 1.0
const PUDDLE_SECS := 8.0
const MARK_MAX := {"fissure": 2, "ice": 3, "ember": 4, "puddle": 4}
const SUN_FAST := 2.5  ## sol: poça e gelo somem SUN_FAST x mais rápido
const RAIN_SLOW := 0.4  ## chuva: poça dura mais (o tempo corre a RAIN_SLOW)
## Maré da praia: primeira enchente depois de TIDE_FIRST s; seco TIDE_DRY s, aviso TIDE_WARN s,
## cheia TIDE_IN s (ciclo de ~30 s).
const TIDE_FIRST := 12.0
const TIDE_DRY := 15.0
const TIDE_WARN := 3.0
const TIDE_IN := 12.0
const TIDE_WADE := 0.85  ## andar na água rasa (quem não é de Água)
const TIDE_SWIM := 1.1  ## Água na água rasa
const TIDE_CONDUCT := 3.5  ## Elétrico na maré passa a corrente a até TIDE_CONDUCT m
const SAND_EVADE := 0.15  ## Terra na areia seca: golpe à distância x0,85
## IA: Terra procura a lama (a até MUD_SEEK m) se dali alcança o alvo; no máx. MUD_HOLD s seguidos.
const MUD_SEEK := 6.0
const MUD_HOLD := 8.0
const MUD_HOLD_CD := 5.0

var terrain: BattleTerrain  ## dono
var arena: Node
var on := false  ## energia + cenário
var visual := true  ## sem opts.fast_sim
## Lama: {pos, r, r0, t (vida, INF = do cenário), dry (0..1), cracked, node}
var mud: Array = []
## Marcas: {kind, pos, r, t, a, b (fenda), node, hit}
var marks: Array = []
## Maré: {phase: dry/warn/in, t, side, node}. Vazio fora da praia.
var tide := {}
var muddy := {}  ## id do lutador -> segundos enlameado
var _was_mud := {}  ## id -> estava na lama no quadro anterior
var _slide_v := {}  ## id -> velocidade no gelo (embalo)
var _hold := {}  ## id -> segundos lutando na lama (IA); negativo = espera
var _t := 0.0

static var _tex := {}


func _init(ter: BattleTerrain) -> void:
	terrain = ter
	arena = ter.arena


func _tele(kind: String, data := {}) -> void:
	terrain._tele("terrain_" + kind, data)


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


## Monta a lama do cenário e a maré (praia). Só no modo de energia (opts.ground: false desliga tudo).
func setup() -> void:
	on = (
		terrain.scenario != ""
		and arena.has_method("energy_on")
		and arena.energy_on()
		and bool(arena.opts.get("ground", true))
	)
	if not on:
		return
	visual = not bool(arena.opts.get("fast_sim", false))
	var rng: RandomNumberGenerator = arena.rng
	var n := int(MUD_COUNT.get(terrain.scenario, 0))
	for i in n:
		var r := rng.randf_range(MUD_R[0], MUD_R[1])
		var at := _place_mud(rng, r, 1 if i % 2 == 0 else -1)
		if at != Vector3.INF:
			_add_mud(at, r, INF)
	if terrain.scenario == "praia":
		tide = {"phase": "dry", "t": TIDE_FIRST - TIDE_WARN, "side": 1 if rng.randf() < 0.5 else -1}
		_build_beach()


## Ponto para a lama do cenário: chão livre (ela é baixa: pode encostar no resto, só não em cima),
## longe das entradas e das paredes, na metade `side` da quadra (as lamas alternam as metades).
func _place_mud(rng: RandomNumberGenerator, r: float, side: int) -> Vector3:
	var rc: Rect2 = arena.rect.grow(-(r + BattleTerrain.KEEP_WALL))
	var ax: Vector3 = _flat(arena.axis).normalized()
	if ax.length() < 0.5:
		ax = Vector3.RIGHT
	for _try in BattleTerrain.PLACE_TRIES:
		var at := Vector3(
			rng.randf_range(rc.position.x, rc.end.x), 0.0, rng.randf_range(rc.position.y, rc.end.y)
		)
		if signf(at.dot(ax)) != float(side):
			at -= ax * 2.0 * at.dot(ax)
		if _mud_free(at, r):
			return at
	return Vector3.INF


func _mud_free(at: Vector3, r: float) -> bool:
	for s in [arena.player_spot, arena.enemy_spot]:
		if _flat(at - s).length() < r + BattleTerrain.KEEP_SPOT:
			return false
	for o in terrain.obstacles + terrain.grass + mud:
		if _flat(at - o.pos).length() < r + float(o.r) + MUD_GAP:
			return false
	for c in terrain.crate_spots:
		if _flat(at - c).length() < r + BattleField.OBJ_R + MUD_GAP:
			return false
	return true


# --- Consultas ---


func _grounded(f: BattleFighter) -> bool:
	return terrain._grounded(f) and f.ground_y < 0.1 and f.motion != "tunnel"


func _mud_at(p: Vector3, pad := 0.0) -> Dictionary:
	for m in mud:
		if _flat(p - m.pos).length() < float(m.r) + pad:
			return m
	return {}


## Na lama mole (não rachada), no chão.
func in_mud(f: BattleFighter) -> bool:
	if not on or mud.is_empty() or not is_instance_valid(f) or not _grounded(f):
		return false
	var m := _mud_at(f.position)
	return not m.is_empty() and not m.cracked


func mud_immune(f: BattleFighter) -> bool:
	for t in f.types:
		if t in MUD_TYPES:
			return true
	return false


func _mark_at(kind: String, p: Vector3, pad := 0.0) -> Dictionary:
	for m in marks:
		if m.kind != kind:
			continue
		if kind == "fissure":
			if _seg_dist(p, m) < FISSURE_W * 0.5 + pad:
				return m
		elif _flat(p - m.pos).length() < float(m.r) + pad:
			return m
	return {}


func _seg_dist(p: Vector3, m: Dictionary) -> float:
	var a: Vector3 = m.a
	var ab: Vector3 = m.b - a
	var t := clampf(_flat(p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
	return _flat(p - (a + ab * t)).length()


## Fenda onde o lutador está (no chão, sem voar). {} se nenhuma.
func fissure_of(f: BattleFighter) -> Dictionary:
	if not on or not is_instance_valid(f) or not _grounded(f):
		return {}
	return _mark_at("fissure", f.position)


func on_mark(f: BattleFighter, kind: String) -> bool:
	if not on or marks.is_empty() or not is_instance_valid(f) or not _grounded(f):
		return false
	return not _mark_at(kind, f.position).is_empty()


## Vetor perpendicular ao eixo da quadra (a maré enche o lado `tide.side` dele).
func _perp() -> Vector3:
	var ax: Vector3 = _flat(arena.axis).normalized()
	if ax.length() < 0.5:
		ax = Vector3.RIGHT
	return Vector3(-ax.z, 0.0, ax.x)


func tide_up() -> bool:
	return not tide.is_empty() and tide.phase == "in"


## Ponto `p` dentro da faixa da maré (cheia ou não) e no chão baixo (morro e pico ficam de fora).
func in_band(p: Vector3) -> bool:
	if tide.is_empty():
		return false
	return _flat(p).dot(_perp()) * float(tide.side) > 0.0 and terrain.height_at(p) < 0.3


## Na água rasa da maré cheia.
func in_tide(f: BattleFighter) -> bool:
	return tide_up() and is_instance_valid(f) and _grounded(f) and in_band(f.position)


# --- Ganchos do BattleTerrain ---


## Andar: lama 0,6x (menos Terra/Água/Veneno), água rasa da maré. 1.0 fora daqui.
func move_mult(f: BattleFighter) -> float:
	if not on:
		return 1.0
	if in_mud(f):
		return 1.0 if mud_immune(f) else MUD_MULT
	if in_tide(f):
		return TIDE_SWIM if terrain.swimmer(f) else TIDE_WADE
	return 1.0


## Energia na água rasa da maré: as regras do lago (sem o dano no Fogo).
func regen_mult(f: BattleFighter) -> float:
	if not in_tide(f):
		return 1.0
	if terrain.swimmer(f) or "grass" in f.types:
		return BattleTerrain.SWIM_REGEN
	return BattleTerrain.FIRE_WATER_REGEN if "fire" in f.types else BattleTerrain.WADE_REGEN


## Precisão: enlameado erra mais de longe; quem está na fenda fica escondido de tiro de longe; Terra
## na areia seca da praia se camufla.
func acc_mult(user: BattleFighter, mv: Dictionary, target: BattleFighter) -> float:
	if not on or not is_instance_valid(user) or not is_instance_valid(target):
		return 1.0
	if not String(mv.get("kind", "")) in BattleTerrain.RANGED_KINDS:
		return 1.0
	if float(mv.get("accuracy", 0)) <= 0.0:
		return 1.0
	var k := 1.0
	if float(muddy.get(user.get_instance_id(), 0.0)) > 0.0:
		k *= MUDDY_ACC
	var fz := fissure_of(target)
	if hidden_in_fissure(user.position, target):
		k *= 1.0 - FISSURE_EVADE
		_tele("fissure_cover", {"who": terrain._uid(target), "by": terrain._uid(user)})
	elif fz.is_empty() and _sand_camo(target):
		k *= 1.0 - SAND_EVADE
		_tele("sand_cover", {"who": terrain._uid(target), "by": terrain._uid(user), "beach": true})
	return k


## `target` está numa fenda e quem atira de `from` está fora dela e longe.
func hidden_in_fissure(from: Vector3, target: BattleFighter) -> bool:
	var fz := fissure_of(target)
	if fz.is_empty():
		return false
	if _flat(from - target.position).length() <= FISSURE_SEE:
		return false
	return _seg_dist(from, fz) >= FISSURE_W * 0.5


func _sand_camo(f: BattleFighter) -> bool:
	if tide.is_empty() or not "ground" in f.types or not _grounded(f):
		return false
	if terrain._weather() == "sand" or terrain.in_grass(f):
		return false  # na tempestade de areia o BattleTerrain já camufla
	if in_tide(f) or in_mud(f) or on_mark(f, "puddle"):
		return false
	return terrain.height_at(f.position) < 0.3


## Dano: Elétrico em quem está na água rasa da maré bate 1,3x (como no lago).
func damage_mult(user: BattleFighter, target: BattleFighter, mv: Dictionary) -> float:
	if not on or String(mv.get("type", "")) != "electric" or not in_tide(target):
		return 1.0
	target.popup("Eletrocutado na água!", Dex.type_color("electric"), 0.9, 0.8)
	_tele("tide_shock", {"who": terrain._uid(target), "by": terrain._uid(user)})
	return BattleTerrain.ELEC_WATER


## Linha de tiro de `a` até `b`: alvo dentro de uma fenda, visto de fora e de longe, fica coberto
## (raios param na beira). Distância até a beira ou INF.
func shot_cover(a: Vector3, b: Vector3) -> float:
	if not on or marks.is_empty() or b.y > 0.4:
		return INF
	var d := _flat(b - a).length()
	if d <= FISSURE_SEE:
		return INF
	var fz := _mark_at("fissure", b)
	if fz.is_empty() or _seg_dist(a, fz) < FISSURE_W * 0.5:
		return INF
	return maxf(d - FISSURE_W, 0.1)


## Um golpe chegou no chão em `at`: lama, fenda, gelo, brasas, poça; Elétrico corre pela poça e pela
## maré; Fogo derrete o gelo; Gelo apaga as brasas.
func on_move_landed(user: BattleFighter, mv: Dictionary, at: Vector3, radius: float) -> void:
	if not on:
		return
	var type := String(mv.get("type", ""))
	var power := float(mv.get("power", 0))
	var id := String(mv.get("id", ""))
	if power <= 0.0:
		return
	at = _flat(at)
	if not arena.rect.has_point(Vector2(at.x, at.z)):
		return
	if terrain.height_at(at) > 0.1 or not terrain.pond_at(at).is_empty():
		return  # no alto ou no lago (o lago tem as regras dele)
	var wx := terrain._weather()
	var flooded := tide_up() and in_band(at)
	if id in FISSURE_MOVES or (type == "ground" and power >= FISSURE_POWER):
		_add_fissure(user, at)
	match type:
		"ground":
			var pd := _mark_at("puddle", at)
			if not pd.is_empty():
				_drop(pd)
			_new_mud(at)
		"water":
			if flooded:
				return
			var pd := _mark_at("puddle", at)
			if not pd.is_empty():
				_drop(pd)
				_new_mud(at)  # água em cima da poça: vira lama
				return
			var m := _mud_at(at)
			if not m.is_empty():
				m.dry = 0.0
				_set_cracked(m, false)
				return
			_drop_kind_at("ember", at, PUDDLE_R)
			_add_mark("puddle", at, PUDDLE_R, PUDDLE_SECS, user)
		"ice":
			if flooded:
				return
			_drop_kind_at("ember", at, ICE_R)
			_add_mark("ice", at, ICE_R, ICE_SECS, user)
		"fire":
			var ic := _mark_at("ice", at)
			if not ic.is_empty():
				_drop(ic)  # derrete
				return
			if wx == "rain" or flooded:
				return
			_drop_kind_at("puddle", at, EMBER_R)
			_add_mark("ember", at, EMBER_R, EMBER_SECS, user)
		"electric":
			if mv.get("conducted", false):
				return
			var pd := _mark_at("puddle", at)
			if not pd.is_empty():
				terrain._conduct(
					user, mv, pd, at, func(f: BattleFighter) -> bool: return _in_area(f, pd)
				)
			elif flooded:
				var area := {"pos": at, "r": TIDE_CONDUCT}
				terrain._conduct(
					user,
					mv,
					area,
					at,
					func(f: BattleFighter) -> bool:
						return in_tide(f) and _flat(f.position - at).length() < TIDE_CONDUCT
				)


func _in_area(f: BattleFighter, m: Dictionary) -> bool:
	return _grounded(f) and _flat(f.position - m.pos).length() < float(m.r)


## Por quadro, depois de andar: o gelo mantém o embalo (a velocidade muda devagar).
func settle(f: BattleFighter, dt: float) -> void:
	if not on or marks.is_empty():
		return
	var id := f.get_instance_id()
	var free_move: bool = (
		f.motion == "" and f.dash_t <= 0.0 and f.lunge_t <= 0.0 and not terrain.sliding(f)
	)
	if not free_move or not on_mark(f, "ice"):
		_slide_v.erase(id)
		return
	var v := Vector3(f.velocity.x, 0.0, f.velocity.z)
	var s: Vector3 = _slide_v.get(id, v)
	s = s.lerp(v, clampf(ICE_GRIP * dt, 0.0, 1.0))
	f.position += (s - v) * dt
	_slide_v[id] = s


## Desvia a direção da IA da lama (quem atola) e das brasas (quem não é de Fogo).
func steer(f: BattleFighter, want: Vector3) -> Vector3:
	if not on or want.length() < 0.05 or not _grounded(f):
		return want
	var dir := want.normalized()
	var out := want
	var avoid: Array = []
	if not mud_immune(f) and not in_mud(f):
		for m in mud:
			if not m.cracked:
				avoid.append(m)
	if not "fire" in f.types:
		for m in marks:
			if m.kind == "ember" and _flat(f.position - m.pos).length() >= float(m.r):
				avoid.append(m)
	for m in avoid:
		var to := _flat(m.pos - f.position)
		var ahead := to.dot(dir)
		if ahead <= 0.0 or ahead > float(m.r) + 1.4:
			continue
		var side := to - dir * ahead
		var clear := float(m.r) + 0.4
		if side.length() >= clear:
			continue
		var tangent := Vector3(-dir.z, 0.0, dir.x)
		if side.dot(tangent) > 0.0:
			tangent = -tangent
		out += tangent * (1.0 - side.length() / clear) * 1.2 * want.length()
	return out.normalized() * want.length() if out.length() > 0.001 else want


# --- Tempo ---


func tick(dt: float) -> void:
	if not on:
		return
	_t += dt
	var wx := terrain._weather()
	_tick_tide(dt)
	_tick_mud(dt, wx)
	_tick_marks(dt, wx)
	_tick_hold(dt)
	for f in arena.fighters:
		if not is_instance_valid(f):
			continue
		var id: int = f.get_instance_id()
		if not f.active():
			muddy.erase(id)
			_was_mud.erase(id)
			_slide_v.erase(id)
			continue
		if muddy.has(id):
			muddy[id] = float(muddy[id]) - dt
			if muddy[id] <= 0.0:
				muddy.erase(id)
		var now := in_mud(f) and not mud_immune(f)
		if bool(_was_mud.get(id, false)) and not now:
			muddy[id] = MUDDY_SECS
			f.popup("Enlameado!", Color(0.55, 0.4, 0.25), 0.8, 0.5)
			_tele("muddy", {"who": terrain._uid(f)})
		_was_mud[id] = now
		_embers_on(f)


func _tick_mud(dt: float, wx: String) -> void:
	for m in mud.duplicate():
		if float(m.t) != INF:
			if wx != "rain":
				m.t = float(m.t) - dt
			if float(m.t) <= 0.0:
				_drop_mud(m)
				continue
		if wx == "sun":
			m.dry = minf(float(m.dry) + dt / MUD_DRY_SECS, 1.0)
			if float(m.dry) >= 1.0 and not m.cracked:
				_set_cracked(m, true)
				_tele("mud_dry", {})
		elif float(m.dry) > 0.0:
			var k := 4.0 if wx == "rain" else 1.0
			m.dry = maxf(float(m.dry) - dt * k / MUD_WET_SECS, 0.0)
			if float(m.dry) <= 0.0 and m.cracked:
				_set_cracked(m, false)
		var want: float = float(m.r0) * (MUD_RAIN if wx == "rain" else 1.0)
		if not is_equal_approx(float(m.r), want):
			m.r = move_toward(float(m.r), want, MUD_GROW * dt)
			if is_instance_valid(m.get("node")):
				var s: float = float(m.r) / float(m.r0)
				m.node.scale = Vector3(s, 1.0, s)


func _tick_marks(dt: float, wx: String) -> void:
	for m in marks.duplicate():
		var k := 1.0
		match String(m.kind):
			"puddle":
				k = RAIN_SLOW if wx == "rain" else (SUN_FAST if wx == "sun" else 1.0)
			"ice":
				k = SUN_FAST if wx == "sun" else 1.0
			"ember":
				if wx == "rain":
					k = 100.0  # a chuva apaga
		if tide_up() and m.kind != "fissure" and in_band(m.pos):
			k = 100.0  # a maré leva poça, gelo e brasas
		m.t = float(m.t) - dt * k
		if float(m.t) <= 0.0:
			_drop(m)
		elif float(m.t) < 1.0 and is_instance_valid(m.get("node")):
			m.node.scale = Vector3(1.0, 1.0, 1.0) * maxf(float(m.t), 0.2)


## Brasas: quem não é de Fogo e pisa toma EMBER_FRAC do HP e pode ficar queimado (uma vez por brasa).
func _embers_on(f: BattleFighter) -> void:
	if "fire" in f.types or not _grounded(f):
		return
	var id := f.get_instance_id()
	for m in marks:
		if m.kind != "ember" or m.hit.has(id) or not _in_area(f, m):
			continue
		m.hit[id] = true
		var n := maxi(1, int(float(f.max_hp) * EMBER_FRAC * f.dot_scale()))
		n = f.residual_damage(n, "brasas", Dex.type_color("fire"))
		var burned := false
		if f.alive() and f.status == "" and arena.rng.randf() < EMBER_BURN:
			var ab = arena.get("abilities")
			if not (ab and ab.blocks_status(f, "burn")):
				burned = f.apply_status("burn", null)
		_tele("ember_hit", {"who": terrain._uid(f), "dmg": n, "burned": burned})


func _tick_tide(dt: float) -> void:
	if tide.is_empty():
		return
	tide.t = float(tide.t) - dt
	if float(tide.t) <= 0.0:
		match String(tide.phase):
			"dry":
				tide.phase = "warn"
				tide.t = TIDE_WARN
				arena.say("A maré está subindo!")
			"warn":
				tide.phase = "in"
				tide.t = TIDE_IN
				_tele("tide_in", {"side": tide.side})
				for f in arena.fighters:
					if is_instance_valid(f) and f.active():
						_slide_v.erase(f.get_instance_id())
			"in":
				tide.phase = "dry"
				tide.t = TIDE_DRY
				tide.side = -int(tide.side)
				_tele("tide_out", {})
	_tide_look()


# --- Criação e remoção ---


func _add_mud(at: Vector3, r: float, life: float) -> Dictionary:
	var m := {
		"pos": _flat(at), "r": r, "r0": r, "t": life, "dry": 0.0, "cracked": false, "node": null
	}
	if visual and arena.is_inside_tree():
		m.node = _disc_node(at, r, tex("mud"), 0.016)
	mud.append(m)
	return m


## Lama nova onde caiu golpe de Terra (ou Água numa poça): renova a que já está ali.
func _new_mud(at: Vector3) -> void:
	if tide_up() and in_band(at):
		return
	var m := _mud_at(at, 0.3)
	if not m.is_empty():
		m.dry = 0.0
		_set_cracked(m, false)
		if float(m.t) != INF:
			m.t = MUD_LIFE
		return
	var fresh := mud.filter(func(x): return float(x.t) != INF)
	if fresh.size() >= MUD_NEW_MAX:
		_drop_mud(fresh[0])
	_add_mud(at, MUD_NEW_R, MUD_LIFE)
	_tele("mud_new", {})


func _drop_mud(m: Dictionary) -> void:
	mud.erase(m)
	if is_instance_valid(m.get("node")):
		m.node.queue_free()


func _set_cracked(m: Dictionary, v: bool) -> void:
	if bool(m.cracked) == v:
		return
	m.cracked = v
	if is_instance_valid(m.get("node")):
		m.node.material_override = BattleTerrain._mat(tex("mud_dry" if v else "mud"), 1.2)


func _add_mark(kind: String, at: Vector3, r: float, life: float, user: BattleFighter) -> void:
	var old := _mark_at(kind, at, 0.3)
	if not old.is_empty():
		old.t = life  # renova em vez de empilhar
		return
	var same := marks.filter(func(x): return x.kind == kind)
	if same.size() >= int(MARK_MAX[kind]):
		_drop(same[0])
	var m := {"kind": kind, "pos": _flat(at), "r": r, "t": life, "node": null, "hit": {}}
	if kind == "ember":
		# Quem já está em cima quando a brasa cai não "pisa" nela.
		for f in arena.fighters:
			if is_instance_valid(f) and f.active() and _in_area(f, m):
				m.hit[f.get_instance_id()] = true
	if visual and arena.is_inside_tree():
		var look := {"ice": "ice_slick", "ember": "ember", "puddle": "puddle"}
		m.node = _disc_node(at, r, tex(String(look[kind])), 0.024 + 0.002 * marks.size())
	marks.append(m)
	_tele("mark_" + kind, {"by": terrain._uid(user)})


## Fenda: vala de FISSURE_LEN m atravessada na direção do golpe, presa dentro da quadra.
func _add_fissure(user: BattleFighter, at: Vector3) -> void:
	var dir := Vector3.FORWARD
	if is_instance_valid(user):
		var fc: Vector3 = _flat(user.facing)
		if fc.length() > 0.1:
			dir = Vector3(-fc.z, 0.0, fc.x).normalized()
	var inner: Rect2 = arena.rect.grow(-0.6)
	var a := at - dir * FISSURE_LEN * 0.5
	var b := at + dir * FISSURE_LEN * 0.5
	a.x = clampf(a.x, inner.position.x, inner.end.x)
	a.z = clampf(a.z, inner.position.y, inner.end.y)
	b.x = clampf(b.x, inner.position.x, inner.end.x)
	b.z = clampf(b.z, inner.position.y, inner.end.y)
	for m in marks:
		if m.kind == "fissure" and _flat(m.pos - at).length() < 1.0:
			m.t = FISSURE_SECS
			return
	var same := marks.filter(func(x): return x.kind == "fissure")
	if same.size() >= int(MARK_MAX.fissure):
		_drop(same[0])
	var m := {
		"kind": "fissure",
		"pos": (a + b) * 0.5,
		"a": a,
		"b": b,
		"r": FISSURE_W * 0.5,
		"t": FISSURE_SECS,
		"node": null,
		"hit": {},
	}
	if visual and arena.is_inside_tree():
		var mi := BattleTerrain._box(Vector3((b - a).length(), 0.03, FISSURE_W), tex("fissure"))
		mi.position = m.pos + Vector3(0, 0.02, 0)
		mi.rotation.y = -atan2((b - a).z, (b - a).x)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		arena.add_child(mi)
		m.node = mi
	marks.append(m)
	_tele("mark_fissure", {"by": terrain._uid(user)})


func _drop(m: Dictionary) -> void:
	marks.erase(m)
	if is_instance_valid(m.get("node")):
		m.node.queue_free()


func _drop_kind_at(kind: String, at: Vector3, r: float) -> void:
	var m := _mark_at(kind, at, r)
	if not m.is_empty():
		_drop(m)


# --- IA ---


## Gancho da IA de energia (começo de BattleAI._energy_steer, depois do BattleTerrainAI): Fogo sai da
## maré; quem é de Terra luta de dentro da lama quando dali alcança o alvo. INF = segue a IA normal.
static func steer_ai(ai, d: float) -> Vector3:
	var f: BattleFighter = ai.f
	var ter = f.arena.get("terrain") if f.arena else null
	if ter == null or ter.get("ground") == null or not ter.ground.on:
		return Vector3.INF
	var g: BattleGround = ter.ground
	if "fire" in f.types and g.in_tide(f):
		ai.tag = "leave_tide"
		f.sprinting = f.can_sprint(true)
		return (g._perp() * -float(g.tide.side) + f.arena.edge_push(f) * 0.5).limit_length(1.0)
	if not "ground" in f.types or g.mud.is_empty():
		return Vector3.INF
	var id := f.get_instance_id()
	var held := float(g._hold.get(id, 0.0))
	var spot := g.mud_spot(ai)
	if spot.is_empty() or held < 0.0 or held > MUD_HOLD:
		if held > MUD_HOLD:
			g._hold[id] = -MUD_HOLD_CD
		elif held > 0.0:
			g._hold[id] = 0.0
		return Vector3.INF
	var to: Vector3 = spot.pos - f.pos2(f.position)
	ai.tag = "mud_fight"
	ai._fly(d)
	if to.length() < float(spot.r) * 0.6:
		return (to * 0.5).limit_length(0.3)
	f.sprinting = to.length() > 3.0 and f.can_sprint(true)
	return to.normalized() * clampf(to.length(), 0.3, 1.0)


## Lama (mole) a até MUD_SEEK m de onde o golpe pretendido alcança o alvo, para quem é de Terra lutar
## de dentro dela. {} se não há ou se agora é hora de descansar.
func mud_spot(ai) -> Dictionary:
	var f: BattleFighter = ai.f
	var opp: BattleFighter = f.opponent
	if not is_instance_valid(opp) or not opp.active() or ai.intent == "" or ai.recover_t > 0.0:
		return {}
	if BattleTerrainAI._needs_rest(ai):
		return {}
	var reach: float = ai.move_reach(ai.intent)
	if reach == INF:
		reach = 0.0
	var best := {}
	var best_d := MUD_SEEK
	for m in mud:
		if m.cracked:
			continue
		var d := _flat(f.position - m.pos).length()
		if d >= best_d:
			continue
		var to_opp := _flat(opp.position - m.pos).length()
		if to_opp > maxf(reach * 0.9, float(m.r) + 1.2):
			continue
		best_d = d
		best = m
	return best


## Conta o tempo lutando na lama (chamado pelo tick com a tag da IA).
func _tick_hold(dt: float) -> void:
	for f in arena.fighters:
		if not is_instance_valid(f) or f.get("ai") == null:
			continue
		var id: int = f.get_instance_id()
		var h := float(_hold.get(id, 0.0))
		if h < 0.0:
			_hold[id] = minf(h + dt, 0.0)
		elif String(f.ai.get("tag")) == "mud_fight":
			_hold[id] = h + dt


# --- Visual (barato; nada com opts.fast_sim) ---


func _disc_node(at: Vector3, r: float, t: Texture2D, y: float) -> MeshInstance3D:
	var mi: MeshInstance3D = terrain._disc(r, t, 1.2)
	mi.position = Vector3(at.x, y, at.z)
	arena.add_child(mi)
	return mi


## Areia na quadra toda e a água da maré (uma placa só, que acende no aviso e enche na cheia).
func _build_beach() -> void:
	if not visual or not arena.is_inside_tree():
		return
	var rc: Rect2 = arena.rect
	var sand := BattleTerrain._box(Vector3(rc.size.x, 0.01, rc.size.y), BattleTerrain.tex("sand"))
	sand.material_override.uv1_scale = Vector3.ONE * 0.6
	sand.position = Vector3(rc.get_center().x, 0.004, rc.get_center().y)
	sand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arena.add_child(sand)
	var perp := _perp()
	var long := rc.size.x if absf(perp.z) > 0.5 else rc.size.y
	var wide := rc.size.y if absf(perp.z) > 0.5 else rc.size.x
	var water := BattleTerrain._box(Vector3(long, 0.02, wide * 0.5), BattleTerrain.tex("water"))
	if absf(perp.x) > 0.5:
		water.rotation.y = PI * 0.5
	var mat: StandardMaterial3D = water.material_override
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1, 1, 1, 0.0)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.visible = false
	arena.add_child(water)
	tide.node = water
	tide.wide = wide


func _tide_look() -> void:
	var node = tide.get("node")
	if not is_instance_valid(node):
		return
	var rc: Rect2 = arena.rect
	var c := Vector3(rc.get_center().x, 0.0, rc.get_center().y)
	node.position = c + _perp() * float(tide.side) * float(tide.wide) * 0.25 + Vector3(0, 0.03, 0)
	var mat: StandardMaterial3D = node.material_override
	match String(tide.phase):
		"warn":
			node.visible = true
			mat.albedo_color.a = 0.15 + 0.15 * sin(_t * 12.0)
		"in":
			node.visible = true
			var k := clampf((TIDE_IN - float(tide.t)) / 0.8, 0.0, 1.0)
			k = minf(k, clampf(float(tide.t) / 0.8, 0.0, 1.0))
			mat.albedo_color.a = 0.75 * k
			mat.uv1_offset = Vector3(_t * 0.04, _t * 0.025, 0.0)
		_:
			node.visible = false


## Texturas de pixel art (32 x 32, geradas uma vez).
static func tex(kind: String) -> Texture2D:
	if _tex.has(kind):
		return _tex[kind]
	if kind in ["sand", "water", "earth"]:
		return BattleTerrain.tex(kind)
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("ground_" + kind)
	var pal: Array = _palette(kind)
	for y in 32:
		for x in 32:
			var n := rng.randf()
			var c := 1 if n < 0.5 else (2 if n < 0.85 else 0)
			match kind:
				"mud_dry":
					# Rachaduras: linhas escuras em zigue-zague.
					if (
						(x + int(sin(y * 0.5) * 3.0)) % 10 == 0
						or (y + int(cos(x * 0.4) * 2.0)) % 11 == 0
					):
						c = 0
					elif n < 0.1:
						c = 3
				"ember":
					c = 0 if n < 0.6 else (1 if n < 0.85 else (2 if n < 0.96 else 3))
				"fissure":
					c = 0 if absi(y - 16) < 7 else (1 if n < 0.7 else 2)
				"ice_slick":
					if (x + y) % 9 == 0 and n < 0.8:
						c = 3
				_:
					if n < 0.06:
						c = 3
			img.set_pixel(x, y, pal[c])
	var t := ImageTexture.create_from_image(img)
	_tex[kind] = t
	return t


static func _palette(kind: String) -> Array:
	match kind:
		"mud":
			return [Color("2e1f14"), Color("45301f"), Color("5a3f28"), Color("7a5a3a")]
		"mud_dry":
			return [Color("4a3524"), Color("9a7a52"), Color("ad8c60"), Color("c2a274")]
		"ember":
			return [Color("1c1410"), Color("8a2a10"), Color("e0601c"), Color("ffc040")]
		"fissure":
			return [Color("120c08"), Color("3a2818"), Color("5a4028"), Color("7a5a3a")]
		"ice_slick":
			return [Color("a8d8f0"), Color("c4e6f8"), Color("e0f4ff"), Color("ffffff")]
		"puddle":
			return [Color("2a5aa8"), Color("3a74c8"), Color("5a94e0"), Color("b0d8ff")]
	return [Color.BLACK, Color.DIM_GRAY, Color.GRAY, Color.WHITE]

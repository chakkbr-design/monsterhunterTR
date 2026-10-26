class_name BattleGroundExtras
extends RefCounted
## Mais coisas do chão no modo de energia (só com cenário; o VGC não muda). O BattleGround cria um
## (ground.extras) e repassa os ganchos dele; o resto do jogo fala com ele por lá (terrain.ground).
##
## - Tronco sobre o lago (GROUND_EXTRAS "log_bridge"): ponte de tronco atravessando um lago. Em cima não
##   vale nada da água (sem lentidão, energia, corrente nem dano no Fogo). Empurrão forte (>= BRIDGE_KNOCK)
##   em quem está nele derruba de lado na água. Fogo queima o tronco: some por BRIDGE_GONE s e volta.
##   IA: quem não nada usa o tronco como caminho quando o lago está na frente; com o alvo no tronco
##   prefere golpe de empurrão forte (BRIDGE_PICK).
## - Pilar condutor (GROUND_EXTRAS "pylon"): poste de metal, cobertura alta. Na chuva puxa golpe Elétrico
##   à distância que cai ou passa a até ATTRACT m (tiro curva para ele; raio, jato e área em quem está
##   perto vão para ele) e descarrega em todos a até ZAP_R m (ZAP_POWER do golpe). Aço perto
##   (STEEL_NEAR) recupera energia STEEL_REGEN x. IA: Elétrico não mira perto dele na chuva; os outros
##   se escondem no anel entre ZAP_R e ATTRACT contra inimigo Elétrico na chuva.
## - Teia e cipó: golpe de teia (WEB_MOVES) que chega no chão deixa uma teia (WEB_SECS s): quem entra
##   fica preso WEB_ROOT s (uma vez por teia; Inseto e quem voa não). Golpe de cipó (VINE_MOVES) pode
##   (VINE_CHANCE) prender o alvo VINE_ROOT s. Fogo limpa os dois. IA contorna a teia.
## - Vento (WIND_MOVES): rajada de WIND_SECS s na direção do golpe (WIND_LEN x 2*WIND_HALF m). Desvia um
##   pouco tiro leve, leva pó (Spore, Sleep Powder...) para frente, espalha fogo na grama a favor do
##   vento e empurra devagar quem é leve (pelo peso, abaixo de WIND_LIGHT kg).
## - Pedras que ficam (ROCK_MOVES): 1 ou 2 pedrinhas (cobertura baixa e sólida) onde o golpe cai, por
##   ROCK_SECS s, no máx. ROCK_MAX. Stealth Rock deixa perto do alvo.
## - Clima: chuva enche fenda, cratera e buraco (vira poça, que conduz Elétrico); sol acelera a fruta do
##   arbusto; tempestade de areia cobre a grama alta (não esconde nem dá energia) e as pedrinhas (não
##   cobrem); granizo/neve congela a poça (vira gelo que escorrega) e junta montinhos de neve
##   (cobertura baixa, SNOW_MAX) que derretem no sol e com Fogo.

## Objetos por cenário (as outras coisas ficam em BattleTerrain.SCENARIOS e BattleGround.MUD_COUNT).
const GROUND_EXTRAS := {
	"campo": {"log_bridge": 1},
	"lagoa": {"log_bridge": 2},
	"misto": {"log_bridge": 1, "pylon": 1},
	"pedreira": {"pylon": 1},
	"praia": {"pylon": 1},
}
## Tronco.
const BRIDGE_HALF := 0.4  ## meia largura do tronco
const BRIDGE_PAD := 0.6  ## o tronco passa da beira do lago
const BRIDGE_OFF := 0.45  ## o tronco atravessa a BRIDGE_OFF x raio do meio do lago
const BRIDGE_KNOCK := 6.0  ## empurrão efetivo que derruba do tronco
const BRIDGE_DROP := 1.0  ## cai a BRIDGE_DROP m do tronco
const BRIDGE_DROP_SECS := 0.3
const BRIDGE_STUN := 0.4
const BRIDGE_GONE := 20.0  ## queimado: some por BRIDGE_GONE s
const BRIDGE_ROUTE := 5.0  ## IA: usa o tronco com a ponta a até BRIDGE_ROUTE m
const BRIDGE_PICK := 0.6  ## IA: chance de escolher empurrão forte com o alvo no tronco
## Pilar.
const PYLON_BODY := 0.3
const PYLON_SHOT := 0.35
const PYLON_H := 2.4
const PYLON_SPACE := 0.6  ## raio de espaço no cenário
const ATTRACT := 3.0
const ZAP_R := 2.0
const ZAP_POWER := 0.75
const ZAP_CD := 0.6  ## uma descarga por golpe (área e jato acertam vários)
const CATCH := 0.5  ## tiro puxado some a CATCH m do pilar
const PULL_TURN := 10.0
const ROD_KINDS := ["projectile", "homing", "beam", "stream", "aoe_target", "zone", "whip"]
const STEEL_NEAR := 2.5
const STEEL_REGEN := 1.2
const HIDE_RING := 2.5  ## IA: fica a HIDE_RING m do pilar (fora da descarga, dentro do para-raios)
const HIDE_SEEK := 7.0
const HIDE_MAX := 6.0
const HIDE_CD := 6.0
## Teia e cipó.
const WEB_MOVES := ["string_shot", "sticky_web", "electroweb", "struggle_bug", "spider_web"]
const WEB_R := 0.9
const WEB_SECS := 12.0
const WEB_ROOT := 1.0
const WEB_MAX := 4
const VINE_MOVES := [
	"vine_whip", "grass_knot", "leech_seed", "power_whip", "frenzy_plant", "trailblaze"
]
const VINE_CHANCE := 0.35
const VINE_ROOT := 0.8
const VINE_CD := 5.0  ## o mesmo alvo só é preso de novo depois de VINE_CD s
## Vento.
const WIND_MOVES := [
	"hurricane",
	"gust",
	"twister",
	"air_cutter",
	"tailwind",
	"whirlwind",
	"defog",
	"bleakwind_storm",
	"fairy_wind"
]
const WIND_SECS := 4.0
const WIND_LEN := 6.0
const WIND_HALF := 1.5
const WIND_MAX := 2
const WIND_SHOT := 6.0  ## m/s² de lado no tiro leve
const WIND_SHOT_POWER := 75.0  ## tiro leve: poder até isso, sem arco (pedra não)
const WIND_LIGHT := 40.0  ## kg: abaixo disso o vento empurra
const WIND_DRIFT := 1.0  ## m/s para quem não pesa nada (cai com o peso)
const POWDER_MOVES := ["spore", "sleep_powder", "stun_spore", "poison_powder", "cotton_spore"]
const WIND_SPORE := 1.2  ## pó que cai no vento vai WIND_SPORE m para frente
const WIND_GRASS_GAP := 3.0  ## fogo pula para moitas a favor do vento a até isso (borda a borda)
## Pedras.
const ROCK_MOVES := ["rock_slide", "stone_edge", "rock_tomb", "stealth_rock", "diamond_storm"]
const ROCK_R := 0.35
const ROCK_H := 0.6
const ROCK_SECS := 15.0
const ROCK_MAX := 4
const ROCK_CLEAR := 0.95  ## longe de quem está no chão
## Clima.
const RAIN_FILL := 2.0  ## s de chuva até a fenda/cratera virar poça
const HOLLOWS := ["crater", "hole"]  ## marcas do BattleField que a chuva enche
const SUN_BERRY := 0.5  ## sol: a fruta do arbusto cresce 1,5x mais rápido
const SNOW_EVERY := 9.0
const SNOW_R := 0.4
const SNOW_H := 0.55
const SNOW_LIFE := 20.0
const SNOW_MAX := 2
const SNOW_SUN := 4.0  ## sol derrete SNOW_SUN x mais rápido

var ground  ## BattleGround (dono)
var terrain  ## BattleTerrain
var arena: Node
var on := false
var visual := true
## Tronco: {pond, a, b, dir, gone_t, node}
var bridges: Array = []
## Pilar: {pos, cd, node}
var pylons: Array = []
## Teia: {pos, r, t, hit, node}; cipó: {who, t, node}
var webs: Array = []
var vines: Array = []
## Rajada: {from, dir, t, user, pushed}
var winds: Array = []
## Pedrinha / montinho de neve: {pos, t, node}
var rocks: Array = []
var snow: Array = []
var buried := false  ## areia cobrindo grama e pedrinhas
var _rng := RandomNumberGenerator.new()
var _on_log := {}  ## id -> _t da última vez no tronco
var _route := {}  ## id -> lago que a IA atravessa pelo tronco
var _vine_cd := {}  ## id -> _t em que pode ser preso de novo
var _near_steel := {}  ## id -> estava perto do pilar (telemetria)
var _hide := {}  ## id -> s escondido no pilar (IA); negativo = espera
var _ai_note := {}  ## id -> _t do último aviso de telemetria da IA
var _snow_t := 0.0
var _t := 0.0
var _off: PackedStringArray = []  ## partes desligadas (opts.ground_off)

static var _tex := {}


func _init(g) -> void:
	ground = g
	terrain = g.terrain
	arena = g.arena


func _tele(kind: String, data := {}) -> void:
	ground._tele(kind, data)


func _uid(f) -> String:
	return terrain._uid(f)


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


static func _seg(p: Vector3, a: Vector3, b: Vector3) -> Vector3:
	var ab := _flat(b - a)
	var t := clampf(_flat(p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
	return a + ab * t


static func _seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	return _flat(p - _seg(p, a, b)).length()


func _vis() -> bool:
	return visual and arena.is_inside_tree()


# --- Montagem ---


## Tronco e pilar do cenário (BattleGround.setup, depois da lama). Sorteio com rng própria (semeada pela
## da arena sem gastá-la).
func setup() -> void:
	on = ground.on and bool(arena.opts.get("ground_extras", true))
	if not on:
		return
	_off = String(arena.opts.get("ground_off", "")).split(",", false)
	visual = ground.visual
	_rng.seed = hash("ground3_%d" % int(arena.rng.seed))
	var plan := {}  # GROUND_EXTRAS na área desta quadra (BattleTerrain.count)
	for k in GROUND_EXTRAS.get(terrain.scenario, {}):
		plan[k] = terrain.count(int(GROUND_EXTRAS[terrain.scenario][k]))
	var ponds: Array = terrain.obstacles.filter(func(o): return o.kind == "pond")
	ponds.sort_custom(func(x, y): return float(x.r) > float(y.r))
	for i in mini(int(plan.get("log_bridge", 0)) * int(not "bridge" in _off), ponds.size()):
		_place_bridge(ponds[i])
	for i in int(plan.get("pylon", 0)) * int(not "pylon" in _off):
		var at := Vector3.INF
		for side in [1, -1]:  # fora da faixa do meio (no meio tapava a linha de tiro: lutas 1x1 +10 s)
			for _try in 4:
				at = terrain._place(_rng, PYLON_SPACE, side, BattleTerrain.GAP)
				if at != Vector3.INF and ground._mud_at(at, PYLON_SPACE + 0.3).is_empty():
					break
				at = Vector3.INF
			if at != Vector3.INF:
				break
		if at != Vector3.INF:
			_add_pylon(at)


func _place_bridge(pond: Dictionary) -> void:
	var ax: Vector3 = _flat(arena.axis).normalized()
	if ax.length() < 0.5:
		ax = Vector3.RIGHT
	var inner: Rect2 = arena.rect.grow(-0.5)
	var wide := float(pond.r0) * 1.25  # a chuva aumenta o lago até 1,25x
	for _try in 12:
		var d := ax.rotated(Vector3.UP, _rng.randf_range(-0.6, 0.6))
		var n := Vector3(-d.z, 0.0, d.x) * (1.0 if _rng.randf() < 0.5 else -1.0)
		# Corda fora do meio do lago (BRIDGE_OFF x raio): o miolo continua sendo água.
		var c: Vector3 = pond.pos + n * float(pond.r0) * BRIDGE_OFF
		var half := sqrt(wide * wide - pow(float(pond.r0) * BRIDGE_OFF, 2.0)) + BRIDGE_PAD
		var a: Vector3 = c - d * half
		var b: Vector3 = c + d * half
		if not inner.has_point(Vector2(a.x, a.z)) or not inner.has_point(Vector2(b.x, b.z)):
			continue
		if terrain.height_at(a) > 0.05 or terrain.height_at(b) > 0.05:
			continue
		var br := {"pond": pond, "a": a, "b": b, "dir": d, "mid": c, "gone_t": 0.0, "node": null}
		bridges.append(br)
		_build_bridge(br)
		return


func _add_pylon(at: Vector3) -> void:
	var p := {"pos": _flat(at), "cd": 0.0, "node": null, "r": PYLON_SPACE}
	pylons.append(p)
	if _vis() and terrain.lattice:
		p.node = ArenaVoxels.pylon()
		p.node.position = p.pos
		arena.add_child(p.node)
	elif _vis():
		var root := Node3D.new()
		root.name = "Ground_pylon"
		root.position = p.pos
		var pole := BattleTerrain._box(Vector3(0.22, PYLON_H, 0.22), tex("metal"))
		pole.position.y = PYLON_H * 0.5
		root.add_child(pole)
		for k in 2:
			var bar := BattleTerrain._box(Vector3(0.9 - k * 0.3, 0.08, 0.08), tex("metal"))
			bar.position.y = PYLON_H * (0.7 + 0.18 * k)
			root.add_child(bar)
		var cap := BattleTerrain._rock_mesh(0.16, tex("copper"))
		cap.position.y = PYLON_H + 0.08
		root.add_child(cap)
		arena.add_child(root)
		p.node = root


# --- Consultas ---


func _bridge_at(p: Vector3, pad := 0.0) -> Dictionary:
	for br in bridges:
		if float(br.gone_t) <= 0.0 and _seg_dist(p, br.a, br.b) < BRIDGE_HALF + pad:
			return br
	return {}


## Em cima do tronco (no chão, sem voar).
func on_bridge(f: BattleFighter) -> bool:
	if bridges.is_empty() or not is_instance_valid(f) or f.motion == "tunnel":
		return false
	if f.ground_y > 0.1 or f.height() > 0.5 or not terrain._grounded(f):
		return false
	return not _bridge_at(f.position, 0.1).is_empty()


## A IA está atravessando o lago `o` pelo tronco (BattleTerrain.steer não desvia dele).
func routes_through(f: BattleFighter, o: Dictionary) -> bool:
	return is_same(_route.get(f.get_instance_id(), {}), o)


func _pylon_near(p: Vector3, r: float) -> Dictionary:
	var best := {}
	var best_d := r
	for py in pylons:
		var d := _flat(p - py.pos).length()
		if d < best_d:
			best_d = d
			best = py
	return best


func _raining() -> bool:
	return terrain._weather() == "rain"


## Tiro em `p` parou no pilar, numa pedrinha ou num montinho de neve.
func blocks_shot(p: Vector3) -> bool:
	for py in pylons:
		if p.y < PYLON_H and _flat(p - py.pos).length() < PYLON_SHOT:
			return true
	if not buried:
		for r in rocks:
			if p.y < ROCK_H and _flat(p - r.pos).length() < ROCK_R + 0.05:
				return true
	for s in snow:
		if p.y < SNOW_H and _flat(p - s.pos).length() < SNOW_R:
			return true
	return false


func has_cover() -> bool:
	return not pylons.is_empty() or (not rocks.is_empty() and not buried) or not snow.is_empty()


## Grama alta coberta pela areia (BattleTerrain.in_grass).
func grass_buried() -> bool:
	return on and buried


## Aço perto do pilar recupera mais energia.
func regen_mult(f: BattleFighter) -> float:
	if pylons.is_empty() or not "steel" in f.types:
		return 1.0
	return STEEL_REGEN if not _pylon_near(f.position, STEEL_NEAR).is_empty() else 1.0


# --- Golpes ---


## Golpe usado (BattleMoves.deliver): vento e Stealth Rock.
func on_move_used(user: BattleFighter, mv: Dictionary, dir: Vector3) -> void:
	if not on or not is_instance_valid(user):
		return
	var id := String(mv.get("id", ""))
	if id in WIND_MOVES and not "wind" in _off:
		var d := _flat(dir)
		if d.length() < 0.1:
			d = _flat(user.facing)
		if d.length() < 0.1:
			return
		d = d.normalized()
		if winds.size() >= WIND_MAX:
			winds.pop_front()
		winds.append(
			{"from": _flat(user.position), "dir": d, "t": WIND_SECS, "user": user, "pushed": {}}
		)
		_tele("wind", {"by": _uid(user), "move": id})
		if _vis():
			for k in 3:
				var p: Vector3 = _flat(user.position) + d * (1.5 + k * 1.6) + Vector3(0, 0.6, 0)
				PixelFx.pop(arena, "wind", p, 1.6, 0.5)
	elif id == "stealth_rock" and not "rock" in _off:
		var opp: BattleFighter = user.opponent
		if is_instance_valid(opp) and opp.active():
			var back := _flat(user.position - opp.position).normalized()
			_add_rocks(_flat(opp.position) + back * 1.6, 1.4, 2, user)


## Um golpe chegou no chão em `at` (BattleGround.on_move_landed; também status, poder 0).
func on_move_landed(user: BattleFighter, mv: Dictionary, at: Vector3, radius: float) -> void:
	if not on:
		return
	at = _flat(at)
	if not arena.rect.has_point(Vector2(at.x, at.z)):
		return
	var id := String(mv.get("id", ""))
	var type := String(mv.get("type", ""))
	var power := float(mv.get("power", 0))
	if type == "fire" and power > 0.0:
		_burn(user, at, radius)
	if id in WEB_MOVES and not "web" in _off:
		_add_web(at, user)
	if id in VINE_MOVES and not "web" in _off:
		_vine(user, at, radius)
	if id in ROCK_MOVES and power > 0.0 and not "rock" in _off:
		_add_rocks(at, radius * 0.6, 2 if power >= 75.0 else 1, user)


## Fogo: queima o tronco, a teia e o cipó, derrete o montinho de neve.
func _burn(user: BattleFighter, at: Vector3, radius: float) -> void:
	var reach := radius * 0.5 + 0.3
	if not _raining():
		for br in bridges:
			if float(br.gone_t) <= 0.0 and _seg_dist(at, br.a, br.b) < BRIDGE_HALF + reach:
				br.gone_t = BRIDGE_GONE
				_tele("bridge_burn", {"by": _uid(user)})
				arena.popup(br.mid + Vector3(0, 0.8, 0), "The log burned!", Dex.type_color("fire"))
				if is_instance_valid(br.get("node")):
					br.node.visible = false
					if _vis():
						PixelFx.pop(arena, "fire", br.mid + Vector3(0, 0.4, 0), 2.0, 0.6)
	for w in webs.duplicate():
		if _flat(at - w.pos).length() < float(w.r) + reach:
			_drop(webs, w)
			_tele("web_burn", {"by": _uid(user)})
	for v in vines.duplicate():
		var f: BattleFighter = v.who
		if is_instance_valid(f) and _flat(at - f.position).length() < 0.8 + reach:
			if f.prepare_t <= 0.0:
				f.root_t = 0.0
			_drop(vines, v)
			_tele("vine_burn", {"by": _uid(user)})
	for s in snow.duplicate():
		if _flat(at - s.pos).length() < SNOW_R + reach:
			_drop(snow, s)
			_tele("snow_melt", {})


func _add_web(at: Vector3, user: BattleFighter, sticky := false) -> void:
	if not terrain.pond_at(at).is_empty() or terrain.height_at(at) > 0.1:
		return
	for w in webs:
		if _flat(at - w.pos).length() < 0.6:
			w.t = WEB_SECS  # renova
			w["sticky"] = bool(w.get("sticky", false)) or sticky
			return
	if webs.size() >= WEB_MAX:
		_drop(webs, webs[0])
	var w := {"pos": at, "r": WEB_R, "t": WEB_SECS, "hit": {}, "node": null, "sticky": sticky}
	for f in arena.fighters:
		if is_instance_valid(f) and f.active() and _flat(f.position - at).length() < WEB_R:
			w.hit[f.get_instance_id()] = true  # quem já está em cima não "entra"
	if _vis() and terrain.lattice:
		w.node = ArenaVoxels.flat("web", WEB_R, at, "", ArenaVoxels.FINE)
		w.node.position.y = 0.006
		arena.add_child(w.node)
	elif _vis():
		w.node = ground._disc_node(at, WEB_R, tex("web"), 0.03)
	webs.append(w)
	_tele("web", {"by": _uid(user)})


## Cipó: o inimigo mais perto de `at` (no chão) pode ficar preso VINE_ROOT s.
func _vine(user: BattleFighter, at: Vector3, radius: float) -> void:
	var best: BattleFighter = null
	var best_d := 0.8 + radius * 0.3
	for f in arena.fighters:
		if not is_instance_valid(f) or not f.active() or f == user:
			continue
		if is_instance_valid(user) and f.side == user.side:
			continue
		var d := _flat(f.position - at).length()
		if d < best_d and ground._grounded(f):
			best_d = d
			best = f
	if best == null:
		return
	var id := best.get_instance_id()
	if _t < float(_vine_cd.get(id, -INF)) or _rng.randf() >= VINE_CHANCE:
		return
	_vine_cd[id] = _t + VINE_CD
	for old in vines.duplicate():
		if old.who == best:
			_drop(vines, old)
	best.root_t = maxf(best.root_t, VINE_ROOT)
	best.popup("Caught in the vines!", Dex.type_color("grass"), 0.9, 0.6)
	var v := {"who": best, "t": VINE_ROOT, "node": null}
	if _vis() and terrain.lattice:
		v.node = ArenaVoxels.flat("vine", 0.55, best.position, "", ArenaVoxels.FINE)
		v.node.position.y = 0.01
		arena.add_child(v.node)
	elif _vis():
		v.node = ground._disc_node(best.position, 0.55, tex("vine"), 0.035)
	vines.append(v)
	_tele("vine", {"who": _uid(best), "by": _uid(user)})


## Pedrinhas onde o golpe de Pedra caiu (`n`, espalhadas até `spread` m do centro).
func _add_rocks(center: Vector3, spread: float, n: int, user: BattleFighter) -> void:
	for i in n:
		for _try in 10:
			var a := _rng.randf() * TAU
			var p := center + Vector3(cos(a), 0.0, sin(a)) * sqrt(_rng.randf()) * maxf(spread, 0.5)
			if not _free(p, ROCK_R, ROCK_CLEAR):
				continue
			if rocks.size() >= ROCK_MAX:
				_drop(rocks, rocks[0])
			var r := {"pos": _flat(p), "t": ROCK_SECS, "node": null}
			if _vis() and terrain.lattice:
				r.node = ArenaVoxels.rock(ROCK_R, r.pos)
				arena.add_child(r.node)
			elif _vis():
				var mi := BattleTerrain._rock_mesh(ROCK_R, BattleTerrain.tex("stone"))
				mi.position = r.pos + Vector3(0, ROCK_R * 0.55, 0)
				mi.rotation.y = a
				arena.add_child(mi)
				r.node = mi
			rocks.append(r)
			_tele("rock_cover", {"by": _uid(user)})
			break


## Chão livre para uma pedrinha/montinho de raio `r`: dentro da quadra, plano, fora do lago, longe dos
## lutadores (`clear` m), dos objetos e do tronco.
func _free(p: Vector3, r: float, clear: float) -> bool:
	if not arena.rect.grow(-0.8).has_point(Vector2(p.x, p.z)):
		return false
	if terrain.height_at(p) > 0.05 or not terrain.pond_at(p).is_empty():
		return false
	for f in arena.fighters:
		if is_instance_valid(f) and f.active() and _flat(f.position - p).length() < clear:
			return false
	if not terrain.props.spot_free(p, r, 0.1):
		return false
	if arena.field:
		for o in arena.field.objects:
			if _flat(p - o.pos).length() < BattleField.OBJ_R + r + 0.2:
				return false
	for o in rocks + snow + pylons:
		if _flat(p - o.pos).length() < r + 0.6:
			return false
	for br in bridges:
		if _seg_dist(p, br.a, br.b) < BRIDGE_HALF + r + 0.2:
			return false
	return true


## Para-raios (BattleMoves.hit): golpe Elétrico à distância na chuva em quem está a até ATTRACT m do
## pilar vai para ele (descarga em volta). true = o alvo não leva o golpe.
func rod(user: BattleFighter, target: BattleFighter, mv: Dictionary) -> bool:
	if pylons.is_empty() or not on or not _rod_move(mv) or not _raining():
		return false
	var py := _pylon_near(target.position, ATTRACT)
	if py.is_empty():
		return false
	_tele("pylon_rod", {"by": _uid(user), "who": _uid(target), "kind": mv.get("kind", "")})
	_zap(py, user, mv)
	return true


static func _rod_move(mv: Dictionary) -> bool:
	return (
		String(mv.get("type", "")) == "electric"
		and float(mv.get("power", 0)) > 0.0
		and not mv.get("conducted", false)
		and String(mv.get("kind", "")) in ROD_KINDS
	)


## Descarga do pilar: todos a até ZAP_R m (menos quem usou) levam ZAP_POWER do golpe.
func _zap(py: Dictionary, user: BattleFighter, mv: Dictionary) -> void:
	if float(py.cd) > 0.0:
		return
	py.cd = ZAP_CD
	arena.popup(py.pos + Vector3(0, PYLON_H, 0), "Lightning rod!", Dex.type_color("electric"))
	if _vis():
		PixelFx.pop(arena, "electric", py.pos + Vector3(0, 1.2, 0), ZAP_R * 1.6, 0.5)
	if not is_instance_valid(user):
		return
	var m := mv.duplicate()
	m.erase("_cast")
	m["conducted"] = true
	for f in arena.fighters:
		if not is_instance_valid(f) or not f.active() or f == user:
			continue
		var to := _flat(f.position - py.pos)
		if to.length() >= ZAP_R:
			continue
		_tele("pylon_zap", {"who": _uid(f), "by": _uid(user)})
		arena.moves.hit(
			user, f, m, to.normalized() if to.length() > 0.05 else Vector3.RIGHT, ZAP_POWER
		)


## Projétil a cada quadro (BattleProjectile.step): o vento desvia tiro leve; na chuva o pilar puxa o
## Elétrico. true = o tiro acabou (descarregou no pilar).
func shot_step(proj, dt: float) -> bool:
	if not on:
		return false
	var mv: Dictionary = proj.mv
	var p: Vector3 = proj.position
	var power := float(mv.get("power", 0))
	if not winds.is_empty() and proj.lob == 0.0 and power <= WIND_SHOT_POWER:
		var w := _wind_at(p)
		if not w.is_empty() and String(mv.get("type", "")) != "rock":
			var v: Vector3 = proj.vel
			var fl := Vector3(v.x, 0.0, v.z)
			var spd := fl.length()
			if spd > 0.1:
				var lat: Vector3 = w.dir - fl / spd * w.dir.dot(fl / spd)
				if lat.length() > 0.05:
					fl = (fl + lat * WIND_SHOT * dt).normalized() * spd
					proj.vel = Vector3(fl.x, v.y, fl.z)
					if not proj.has_meta("wind"):
						proj.set_meta("wind", true)
						_tele("wind_deflect", {"by": _uid(proj.user)})
	if pylons.is_empty() or not _rod_move(mv) or not _raining():
		return false
	var py := _pylon_near(p, ATTRACT)
	if py.is_empty():
		return false
	var to := _flat(py.pos - p)
	if to.length() < CATCH:
		_tele("pylon_rod", {"by": _uid(proj.user), "kind": "projectile"})
		_zap(py, proj.user, mv)
		return true
	proj.homing = false
	var want: Vector3 = to.normalized() * float(proj.speed)
	proj.vel = proj.vel.lerp(Vector3(want.x, 0.0, want.z), clampf(PULL_TURN * dt, 0.0, 1.0))
	return false


func _wind_at(p: Vector3) -> Dictionary:
	for w in winds:
		var loc := _flat(p - w.from)
		var along: float = loc.dot(w.dir)
		if along > 0.0 and along < WIND_LEN and (loc - w.dir * along).length() < WIND_HALF:
			return w
	return {}


## Ponto de área (BattleMoves._area_point): pó que cai no vento vai para frente.
func wind_area(mv: Dictionary, at: Vector3) -> Vector3:
	if not on or winds.is_empty() or not String(mv.get("id", "")) in POWDER_MOVES:
		return at
	var w := _wind_at(at)
	if w.is_empty():
		return at
	var to: Vector3 = at + w.dir * WIND_SPORE
	var inner: Rect2 = arena.rect.grow(-0.5)
	to.x = clampf(to.x, inner.position.x, inner.end.x)
	to.z = clampf(to.z, inner.position.y, inner.end.y)
	_tele("wind_spore", {"move": mv.get("id", "")})
	return to


## A moita `g` pegou fogo (BattleTerrain.ignite): no vento o fogo pula para a moita a favor dele.
func on_grass_burn(g: Dictionary, user: BattleFighter) -> void:
	if not on or winds.is_empty():
		return
	var w := _wind_at(g.pos)
	if w.is_empty():
		for x in winds:
			if _flat(g.pos - x.from).length() < WIND_LEN + float(g.r):
				w = x
	if w.is_empty():
		return
	for o in terrain.grass.duplicate():
		if o == g:
			continue
		var to := _flat(o.pos - g.pos)
		if to.length() < 0.01 or to.normalized().dot(w.dir) < 0.6:
			continue
		if to.length() - float(o.r) - float(g.r) > WIND_GRASS_GAP:
			continue
		_tele("wind_fire", {"by": _uid(user)})
		arena.later(0.6, func() -> void: terrain.ignite(o, user, true))


## Depois do acerto (BattleTerrain.after_hit): empurrão forte em quem está no tronco derruba na água.
## true = derrubou (o resto do after_hit não roda).
func after_hit(
	user: BattleFighter, target: BattleFighter, _mv: Dictionary, dir: Vector3, knock: float
) -> bool:
	if bridges.is_empty() or knock < BRIDGE_KNOCK or not on_bridge(target):
		return false
	var br := _bridge_at(target.position, 0.1)
	var n := Vector3(-br.dir.z, 0.0, br.dir.x)
	var c := _seg(target.position, br.a, br.b)
	var s := _flat(dir).dot(n)
	if absf(s) < 0.15:
		s = _flat(target.position - c).dot(n)
		if absf(s) < 0.01:
			s = 1.0 if _rng.randf() < 0.5 else -1.0
	var to: Vector3 = c + n * signf(s) * BRIDGE_DROP
	if terrain.pond_at(to).is_empty():
		return false  # na ponta do tronco: cai em terra firme, sem nada
	var id := target.get_instance_id()
	terrain._shove_at[id] = terrain._water_t
	terrain._slide(target, to, BRIDGE_DROP_SECS)
	target.interrupt_prepare()
	target.stun_t = maxf(target.stun_t, BRIDGE_STUN)
	target.popup("Fell into the water!", Dex.type_color("water"), 1.0, 0.7)
	_tele("bridge_drop", {"who": _uid(target), "by": _uid(user)})
	return true


# --- Tempo ---


func tick(dt: float) -> void:
	if not on:
		return
	_t += dt
	var wx: String = terrain._weather()
	for br in bridges:
		if float(br.gone_t) > 0.0:
			br.gone_t = float(br.gone_t) - dt
			if float(br.gone_t) <= 0.0:
				br.gone_t = 0.0
				_tele("bridge_back", {})
				if is_instance_valid(br.get("node")):
					br.node.visible = true
	for py in pylons:
		py.cd = maxf(float(py.cd) - dt, 0.0)
	_tick_list(webs, dt)
	_tick_list(vines, dt)
	_tick_list(rocks, dt)
	_tick_list(snow, dt * (SNOW_SUN if wx == "sun" else 1.0))
	for w in winds.duplicate():
		w.t = float(w.t) - dt
		if float(w.t) <= 0.0:
			winds.erase(w)
	if not "weather" in _off:
		_weather_tick(dt, wx)
	for f in arena.fighters:
		if not is_instance_valid(f):
			continue
		var id: int = f.get_instance_id()
		if not f.active():
			_on_log.erase(id)
			_route.erase(id)
			continue
		if on_bridge(f):
			if _t - float(_on_log.get(id, -INF)) > 1.0:  # pisar na beira várias vezes conta uma
				_tele("bridge_cross", {"who": _uid(f), "ai": f.controller == "ai"})
			_on_log[id] = _t
		if not pylons.is_empty() and "steel" in f.types:
			var near := not _pylon_near(f.position, STEEL_NEAR).is_empty()
			if near and not bool(_near_steel.get(id, false)):
				_tele("pylon_steel", {"who": _uid(f)})
			_near_steel[id] = near
		_webs_on(f)
		_wind_on(f, dt)
		_push_out(f)
	_tick_hide(dt)


func _tick_list(list: Array, dt: float) -> void:
	for o in list.duplicate():
		o.t = float(o.t) - dt
		if float(o.t) <= 0.0:
			_drop(list, o)


func _drop(list: Array, o: Dictionary) -> void:
	list.erase(o)
	if is_instance_valid(o.get("node")):
		o.node.queue_free()


## Teia: quem entra (no chão, não Inseto) fica preso WEB_ROOT s, uma vez por teia.
func _webs_on(f: BattleFighter) -> void:
	if webs.is_empty() or "bug" in f.types or not ground._grounded(f):
		return
	var id := f.get_instance_id()
	for w in webs:
		if w.hit.has(id) or _flat(f.position - w.pos).length() >= float(w.r):
			continue
		w.hit[id] = true
		f.root_t = maxf(f.root_t, WEB_ROOT)
		f.popup("Caught in the web!", Dex.type_color("bug"), 0.9, 0.6)
		if bool(w.get("sticky", false)):
			arena.moves.change_stage(f, "spe", -1)  # Sticky Web
		_tele("web_stick", {"who": _uid(f)})


## Rajada: quem é leve (e não usou o golpe) vai devagar a favor do vento.
func _wind_on(f: BattleFighter, dt: float) -> void:
	if winds.is_empty() or f.motion != "" or arena.moves.effects.rooted(f):
		return
	var w := _wind_at(f.position)
	if w.is_empty() or w.user == f:
		return
	var kg := BattlePhysics.weight_of(f)
	if kg >= WIND_LIGHT:
		return
	var k := WIND_DRIFT * (1.0 - kg / WIND_LIGHT)
	var p: Vector3 = f.position + w.dir * k * dt
	var inner: Rect2 = arena.rect.grow(-0.6)
	f.position.x = clampf(p.x, inner.position.x, inner.end.x)
	f.position.z = clampf(p.z, inner.position.y, inner.end.y)
	var id := f.get_instance_id()
	if not w.pushed.has(id):
		w.pushed[id] = true
		_tele("wind_push", {"who": _uid(f), "kg": kg})


## Corpo sólido do pilar e das pedrinhas (enterradas na areia não).
func _push_out(f: BattleFighter) -> void:
	if f.motion == "tunnel":
		return
	var solid: Array = []
	for py in pylons:
		solid.append([py.pos, PYLON_BODY, PYLON_H])
	if not buried:
		for r in rocks:
			solid.append([r.pos, ROCK_R, ROCK_H])
	for s in solid:
		if f.height() > float(s[2]):
			continue
		var d := _flat(f.position - s[0])
		var lim: float = float(s[1]) + BattleProps.BODY_R
		if d.length() >= lim:
			continue
		if d.length() < 0.001:
			d = Vector3.RIGHT
		f.position += d.normalized() * (lim - d.length())


## Clima no chão: chuva enche fenda/cratera/buraco (poça); sol adianta a fruta; areia cobre grama e
## pedrinhas; granizo/neve congela a poça e junta montinhos de neve.
func _weather_tick(dt: float, wx: String) -> void:
	if wx == "rain":
		for m in ground.marks:
			if m.kind == "fissure" and not m.get("filled", false):
				m.rain_t = float(m.get("rain_t", 0.0)) + dt
				if float(m.rain_t) >= RAIN_FILL:
					m.filled = true
					_fill(
						m.pos,
						BattleGround.PUDDLE_R,
						maxf(float(m.t), BattleGround.PUDDLE_SECS),
						"fissure"
					)
		if arena.field:
			for m in arena.field.marks:
				if m.kind in HOLLOWS and not m.get("filled", false):
					m.rain_t = float(m.get("rain_t", 0.0)) + dt
					if float(m.rain_t) >= RAIN_FILL:
						m.filled = true
						var r := clampf(float(m.r) * 0.8, 0.8, 1.3)
						_fill(m.pos, r, BattleGround.PUDDLE_SECS, String(m.kind))
	elif wx == "sun":
		var props = terrain.props
		for o in props.of_kind("bush"):
			if float(o.get("burnt_t", 0.0)) > 0.0 or not o.has("grow_t"):
				continue
			if props.berries.any(func(b): return b.owner == o):
				continue
			o.grow_t = float(o.grow_t) - dt * SUN_BERRY
	var sand := wx == "sand"
	if sand != buried:
		buried = sand
		if sand:
			_tele("sand_bury", {"grass": terrain.grass.size(), "rocks": rocks.size()})
		_bury_look()
	if wx in ["hail", "snow"]:
		for m in ground.marks:
			if m.kind == "puddle":
				m.kind = "ice"
				m.t = BattleGround.ICE_SECS
				m.hit = {}
				if is_instance_valid(m.get("node")) and terrain.lattice:
					ArenaVoxels.flat_look(m.node, "ice", float(m.r), "", ArenaVoxels.FINE)
				elif is_instance_valid(m.get("node")):
					m.node.material_override = BattleTerrain._mat(
						BattleGround.tex("ice_slick"), 1.2
					)
				_tele("puddle_freeze", {})
		_snow_t += dt
		if _snow_t >= SNOW_EVERY:
			_snow_t = 0.0
			_add_snow()
	else:
		_snow_t = 0.0


func _fill(at: Vector3, r: float, life: float, what: String) -> void:
	if ground.tide_up() and ground.in_band(at):
		return
	ground._add_mark("puddle", at, r, life, null)
	_tele("rain_fill", {"what": what})


func _add_snow() -> void:
	if snow.size() >= SNOW_MAX:
		return
	var rc: Rect2 = arena.rect.grow(-1.2)
	for _try in 20:
		var p := Vector3(
			_rng.randf_range(rc.position.x, rc.end.x),
			0.0,
			_rng.randf_range(rc.position.y, rc.end.y)
		)
		if not _free(p, SNOW_R, 1.5):
			continue
		var s := {"pos": p, "t": SNOW_LIFE, "node": null}
		if _vis() and terrain.lattice:
			s.node = ArenaVoxels.snow_heap(SNOW_R * 1.2, SNOW_H, p, terrain.scenario)
			arena.add_child(s.node)
		elif _vis():
			var mi := BattleTerrain._rock_mesh(SNOW_R * 1.2, tex("snow"))
			mi.position = p + Vector3(0, SNOW_H * 0.35, 0)
			arena.add_child(mi)
			s.node = mi
		snow.append(s)
		_tele("snow_mound", {})
		return


## Areia: a grama alta e as pedrinhas ficam baixas (só visual).
func _bury_look() -> void:
	if not _vis():
		return
	var k := 0.25 if buried else 1.0
	for g in terrain.grass:
		if is_instance_valid(g.get("node")):
			g.node.scale.y = k
	for r in rocks:
		if is_instance_valid(r.get("node")):
			r.node.scale.y = 0.35 if buried else 1.0


# --- IA ---


## Andar da IA (BattleGround.steer_ai): na chuva, contra inimigo com golpe Elétrico de longe, quem
## precisa esperar a energia fica no anel do pilar (puxa o golpe, longe da descarga). INF = segue.
func steer_ai(ai, d: float) -> Vector3:
	var f: BattleFighter = ai.f
	if pylons.is_empty() or not _raining() or "electric" in f.types or "ground" in f.types:
		return Vector3.INF
	var id := f.get_instance_id()
	var held := float(_hide.get(id, 0.0))
	if held < 0.0:
		return Vector3.INF
	if held > HIDE_MAX:
		_hide[id] = -HIDE_CD
		return Vector3.INF
	var waiting: bool = (
		ai.intent == ""
		or BattleEnergy.secs_to(f, f.pp_cost_of(Dex.move(String(ai.intent)))) > BattleAI.ENERGY_WAIT
	)
	var foe := _electric_foe(f)
	if not waiting or foe == null:
		if held > 0.0:
			_hide[id] = 0.0
		return Vector3.INF
	var py := _pylon_near(f.position, HIDE_SEEK)
	if py.is_empty():
		return Vector3.INF
	var away := _flat(py.pos - foe.position)
	if away.length() < 0.1:
		away = _flat(py.pos - f.position)
	var spot: Vector3 = py.pos + away.normalized() * HIDE_RING
	if not arena.rect.grow(-0.8).has_point(Vector2(spot.x, spot.z)):
		var side := Vector3(-away.z, 0.0, away.x).normalized()
		spot = py.pos + side * HIDE_RING
		if not arena.rect.grow(-0.8).has_point(Vector2(spot.x, spot.z)):
			spot = py.pos - side * HIDE_RING
	if held == 0.0:
		_tele("ai_pylon_hide", {"who": _uid(f)})
	ai.tag = "pylon_hide"
	ai._fly(d)
	var to := _flat(spot - f.position)
	if to.length() < 0.4:
		return to * 0.5
	f.sprinting = to.length() > 3.0 and f.can_sprint(true)
	return to.normalized() * clampf(to.length(), 0.3, 1.0)


## Inimigo mais perto com golpe Elétrico de longe (o que o pilar puxa).
func _electric_foe(f: BattleFighter) -> BattleFighter:
	var best: BattleFighter = null
	var best_d := INF
	for g in arena.targets_of(f):
		var has := false
		for mid in g.moves:
			if _rod_move(Dex.move(String(mid))):
				has = true
				break
		if not has:
			continue
		var d := _flat(g.position - f.position).length()
		if d < best_d:
			best_d = d
			best = g
	return best


func _tick_hide(dt: float) -> void:
	if pylons.is_empty():
		return
	for f in arena.fighters:
		if not is_instance_valid(f) or f.get("ai") == null:
			continue
		var id: int = f.get_instance_id()
		var h := float(_hide.get(id, 0.0))
		if h < 0.0:
			_hide[id] = minf(h + dt, 0.0)
		elif String(f.ai.get("tag")) == "pylon_hide":
			_hide[id] = h + dt


## Escolha do golpe (BattleAI.pick): com o alvo no tronco, golpe de empurrão forte (derruba na água).
## "" = segue a escolha normal.
func ai_pick(ai, avail: Array) -> String:
	var f: BattleFighter = ai.f
	if bridges.is_empty() or not on_bridge(f.opponent) or _rng.randf() >= BRIDGE_PICK:
		return ""
	var strong: Array = avail.filter(
		func(id):
			var mv := Dex.move(String(id))
			return (
				float(mv.get("power", 0)) > 0.0
				and float(mv.get("knockback", 0)) >= BRIDGE_KNOCK
				and ai._dmg(String(id)) > 0.0
			)
	)
	if strong.is_empty():
		return ""
	ai.why = "bridge_knock"
	_tele("ai_bridge_knock", {"who": _uid(f)})
	return String(strong[_rng.randi() % strong.size()])


## Filtro da escolha (BattleAI.pick): na chuva, com o pilar perto da linha até o alvo, Elétrico de
## longe sai (o pilar puxaria) quando sobra golpe de dano.
func ai_filter(ai, avail: Array) -> Array:
	var f: BattleFighter = ai.f
	var opp: BattleFighter = f.opponent
	if pylons.is_empty() or not is_instance_valid(opp) or not _raining():
		return avail
	var near := false
	for py in pylons:
		if _seg_dist(py.pos, f.position, opp.position) < ATTRACT:
			near = true
	if not near:
		return avail
	var elec: Array = avail.filter(func(id): return _rod_move(Dex.move(String(id))))
	if elec.is_empty():
		return avail
	var rest: Array = avail.filter(
		func(id):
			return (
				not id in elec
				and float(Dex.move(String(id)).get("power", 0)) > 0.0
				and ai._dmg(String(id)) > 0.0
			)
	)
	if rest.is_empty():
		return avail
	var id := f.get_instance_id()
	if _t - float(_ai_note.get(id, -INF)) > 3.0:
		_ai_note[id] = _t
		_tele("ai_pylon_avoid", {"who": _uid(f)})
	return avail.filter(func(x): return not x in elec)


## Desvia a IA: atravessa o lago pelo tronco (quem não nada) e contorna a teia (quem não é Inseto).
func steer(f: BattleFighter, want: Vector3) -> Vector3:
	var id := f.get_instance_id()
	if not on or want.length() < 0.05:
		_route.erase(id)
		return want
	var out := _bridge_route(f, want)
	if out != Vector3.INF:
		return out
	_route.erase(id)
	if webs.is_empty() or "bug" in f.types or not ground._grounded(f):
		return want
	var dir := want.normalized()
	out = want
	for w in webs:
		if w.hit.has(id):
			continue
		var to := _flat(w.pos - f.position)
		if to.length() < float(w.r):
			continue
		var ahead := to.dot(dir)
		if ahead <= 0.0 or ahead > float(w.r) + 1.4:
			continue
		var side := to - dir * ahead
		var clear := float(w.r) + 0.4
		if side.length() >= clear:
			continue
		var tangent := Vector3(-dir.z, 0.0, dir.x)
		if side.dot(tangent) > 0.0:
			tangent = -tangent
		out += tangent * (1.0 - side.length() / clear) * 1.2 * want.length()
	return out.normalized() * want.length() if out.length() > 0.001 else want


## Caminho pelo tronco: com o lago na frente e o tronco na mesma direção, vai até a ponta mais perto e
## anda por cima dele. INF = sem tronco no caminho.
func _bridge_route(f: BattleFighter, want: Vector3) -> Vector3:
	if bridges.is_empty() or terrain.swimmer(f) or not ground._grounded(f):
		return Vector3.INF
	var id := f.get_instance_id()
	var dir := want.normalized()
	var me := _flat(f.position)
	for br in bridges:
		if float(br.gone_t) > 0.0:
			continue
		var pond: Dictionary = br.pond
		if float(pond.get("ice_t", 0.0)) > 0.0:
			continue  # congelado: anda por cima do gelo
		var along: float = dir.dot(br.dir)
		if on_bridge(f):
			if absf(along) < 0.3:
				continue
			var s := signf(along)
			var c := _seg(me, br.a, br.b)
			_route[id] = pond
			var v: Vector3 = br.dir * s + (c - me) * 2.0
			return v.normalized() * want.length()
		if absf(along) < 0.5:
			continue
		var to_c: Vector3 = _flat(pond.pos - me)
		var ahead := to_c.dot(dir)
		if ahead <= 0.0 or ahead > float(pond.r) + 3.0:
			continue
		if (to_c - dir * ahead).length() > float(pond.r) + 0.3:
			continue
		var near: Vector3 = br.a if along > 0.0 else br.b
		var far: Vector3 = br.b if along > 0.0 else br.a
		if _flat(near - me).length() > BRIDGE_ROUTE or _flat(far - near).dot(dir) <= 0.0:
			continue
		_route[id] = pond
		var to_n := _flat(near - me)
		if to_n.length() < 0.35:
			return br.dir * signf(along) * want.length()
		return to_n.normalized() * want.length()
	return Vector3.INF


# --- Visual (barato; nada com opts.fast_sim) ---


func _build_bridge(br: Dictionary) -> void:
	if not _vis():
		return
	if terrain.lattice:
		var vn := ArenaVoxels.log_bridge(_flat(br.b - br.a).length())
		vn.position = (br.a + br.b) * 0.5 + Vector3(0, -0.15, 0)
		vn.rotation.y = -atan2(br.dir.z, br.dir.x)
		arena.add_child(vn)
		br.node = vn
		return
	var len := _flat(br.b - br.a).length()
	var mi := BattleTerrain._box(Vector3(len, 0.2, BRIDGE_HALF * 1.6), tex("log"))
	mi.material_override.uv1_triplanar = false
	mi.material_override.uv1_scale = Vector3(len * 0.8, 1.0, 1.0)
	mi.position = (br.a + br.b) * 0.5 + Vector3(0, 0.1, 0)
	mi.rotation.y = -atan2(br.dir.z, br.dir.x)
	arena.add_child(mi)
	br.node = mi


## Texturas de pixel art (32 x 32, geradas uma vez).
static func tex(kind: String) -> Texture2D:
	if _tex.has(kind):
		return _tex[kind]
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("ground3_" + kind)
	var pal: Array = _palette(kind)
	for y in 32:
		for x in 32:
			var n := rng.randf()
			var c := 1 if n < 0.5 else (2 if n < 0.85 else 0)
			match kind:
				"log":
					# Casca: listras ao comprido, nós escuros.
					c = 0 if y % 6 == 0 else (1 if (y + int(n * 3.0)) % 6 < 3 else 2)
					if n < 0.04:
						c = 3
				"metal", "copper":
					c = 3 if x % 8 == 1 else (0 if x % 8 == 7 else (1 if n < 0.6 else 2))
				"web":
					var cx := x - 16
					var cy := y - 16
					var r := sqrt(float(cx * cx + cy * cy))
					var radial := absi(cx) == absi(cy) or cx == 0 or cy == 0
					c = 3 if radial or int(r) % 5 == 0 else (0 if n < 0.7 else 1)
				"vine":
					c = 3 if (x + int(sin(y * 0.5) * 3.0)) % 7 == 0 else (0 if n < 0.4 else 1)
				"snow":
					c = 3 if n < 0.5 else (2 if n < 0.9 else 1)
			img.set_pixel(x, y, pal[c])
	var t := ImageTexture.create_from_image(img)
	_tex[kind] = t
	return t


static func _palette(kind: String) -> Array:
	match kind:
		"log":
			return [Color("3a2414"), Color("5a3a20"), Color("70492a"), Color("a07a4a")]
		"metal":
			return [Color("3c4048"), Color("5a606a"), Color("7a828c"), Color("b4bcc6")]
		"copper":
			return [Color("6a3a1a"), Color("a0602c"), Color("c88040"), Color("f0c070")]
		"web":
			return [Color("3a4a2a"), Color("4a5a36"), Color("9aa090"), Color("f0f0f0")]
		"vine":
			return [Color("1f4a1f"), Color("2f6b2a"), Color("4f8f3e"), Color("7cc25a")]
		"snow":
			return [Color("a8c8e0"), Color("d0e4f4"), Color("e8f4ff"), Color("ffffff")]
	return [Color.BLACK, Color.DIM_GRAY, Color.GRAY, Color.WHITE]

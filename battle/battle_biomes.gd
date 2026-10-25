class_name BattleBiomes
extends RefCounted
## Biomas do modo de energia: cinco cenários com chão, regra e IA próprios (ruínas, montanha nevada,
## vulcão, caverna escura e pântano). Só no modo de energia (o VGC não sorteia nem monta: ENERGY_ONLY em
## BattleTerrain). O BattleTerrain cria um (terrain.biomes) e chama os ganchos abaixo (pre_setup, setup,
## spot_free, move_mult, regen_mult, acc_mult, damage_mult, on_move_landed, blocks_shot, cover_cands,
## steer, settle, tick). A IA tem um gancho só, BattleBiomes.steer_ai, em BattleAI._energy_steer.
## opts.biomes: false desliga as regras (o relevo do cenário fica).
##
## - Ruínas: chão de pedra antiga, colunas (cobertura alta) e um círculo de runas no meio. Um lado sozinho
##   dentro dele recupera energia RUNE_REGEN x (com os dois lados dentro, ninguém). Psíquico e Fantasma
##   dentro do círculo batem RUNE_POWER x. IA: disputa o círculo quando é seguro (falta energia ou dali
##   o golpe alcança o alvo), no máx. RUNE_MAX s seguidos, depois RUNE_CD s sem voltar.
## - Montanha nevada: chão de neve (quem não é de Gelo anda SNOW_MULT x), montes de neve (cobertura
##   baixa) e um paredão num lado comprido. Golpe forte (poder >= AV_POWER) que cai perto do paredão
##   solta uma avalanche: faixa avisada por AV_WARN s, depois neve funda por AV_SECS s (quem não é de
##   Gelo anda DEEP_MULT x; Gelo dentro fica escondido de tiro de longe). Quem fica na faixa leva AV_FRAC
##   do HP. Fogo derrete a neve funda em poça. Às vezes começa nevando (SNOW_CHANCE).
## - Vulcão: chão de rocha escura e rios de lava (faixas finas). Quem não é de Fogo/Pedra e pisa na lava
##   toma LAVA_FRAC do HP por segundo e é empurrado para fora. Golpe de Água esfria a lava em rocha
##   (ponte) por COOL_SECS s. A cada ERUPT_EVERY s uma erupção joga ERUPT_N pedras com aviso. Fogo perto da
##   lava recupera energia LAVA_REGEN x.
## - Caverna escura: luz baixa. Golpe de longe (com precisão) contra alvo a mais de DARK_SEE m acerta
##   DARK_ACC x, a não ser que quem atira seja Elétrico/Fogo (iluminam) ou o alvo esteja perto de um
##   cristal (CRYSTAL_LIGHT) ou seja ele mesmo Elétrico/Fogo. Fantasma e Sombrio se escondem no escuro
##   (golpe de longe x SHADOW_ACC). Cristais do BattleProps fazem parte do cenário.
## - Pântano: lama do BattleGround, lagoas rasas, neblina (golpe de longe contra alvo a mais de FOG_SEE m
##   acerta FOG_ACC x, menos para Veneno/Terra, que conhecem o pântano). Veneno e Terra recuperam energia
##   SWAMP_REGEN x (e a lama já não atola os dois).

## Cenários deste arquivo (todos só do modo de energia).
const LIST := ["ruinas", "montanha", "vulcao", "caverna", "pantano"]
## Coisas próprias de cada bioma, além do SCENARIOS do BattleTerrain.
const EXTRAS := {
	"ruinas": {"pillar": 4},
	"montanha": {"mound": 4},
	"vulcao": {"lava": 3},
	"caverna": {},
	"pantano": {"mud": 3},
}
const FLOOR := {
	"ruinas": "ruin_stone",
	"montanha": "snow",
	"vulcao": "dark_rock",
	"caverna": "cave_rock",
	"pantano": "swamp",
}
const BODY_R := 0.4
const POP_CD := 2.5  ## o mesmo aviso no mesmo lutador no máx. a cada POP_CD s
## Sólidos: [raio do corpo, altura] (cobertura até a altura).
const SOLIDS := {"pillar": [0.45, 2.4], "mound": [0.6, 0.75]}
## Ruínas.
const RUNE_R := 1.7
const RUNE_REGEN := 1.5
const RUNE_POWER := 1.1
const RUNE_TYPES := ["psychic", "ghost"]
const RUNE_SEEK := 8.0  ## IA: vai ao círculo a até isso
const RUNE_MAX := 7.0
const RUNE_CD := 6.0
const RUNE_HP := 0.4  ## IA: com HP abaixo disso não disputa
const RUNE_CONTEST_HP := 0.55  ## IA: só entra com inimigo dentro com HP acima disso
## Montanha.
const SNOW_MULT := 0.93
const DEEP_MULT := 0.7
const SNOW_EVADE := 0.3  ## Gelo na neve funda: golpe de longe x0,7 (de mais de SNOW_SEE m)
const SNOW_SEE := 1.5
const AV_POWER := 80.0
const AV_REACH := 2.5  ## golpe a até isso da beira do paredão solta a avalanche
const AV_WARN := 2.0
const AV_SECS := 15.0
const AV_LEN := 8.0
const AV_DEPTH := 4.0
const AV_CD := 20.0
const AV_FRAC := 1.0 / 10.0
const CELL := 1.2  ## lado da célula da neve funda
const CELL_R := 0.85  ## raio da célula (cobre a grade)
const SNOW_CHANCE := 0.35  ## começa nevando (sem clima pedido)
const SNOW_SEEK := 7.0  ## IA de Gelo: vai se esconder na neve funda a até isso
const SNOW_MAX := 6.0
## Vulcão.
const LAVA_LEN := 4  ## células de 1 m por rio
const LAVA_W := 0.45  ## meia largura do rio
const LAVA_KEEP := 0.6  ## folga do rio até o resto do cenário (além do GAP)
const LAVA_FRAC := 1.0 / 16.0
const LAVA_PUSH := 4.0  ## m/s para fora da lava
const LAVA_TYPES := ["fire", "rock"]
const LAVA_NEAR := 1.5
const LAVA_REGEN := 1.3
const COOL_SECS := 20.0
const ERUPT_FIRST := 15.0
const ERUPT_EVERY := 20.0
const ERUPT_N := 3
const ERUPT_WARN := 1.5
const ERUPT_R := 1.2
const ERUPT_FRAC := 1.0 / 12.0
const ERUPT_KNOCK := 5.0
const ERUPT_AIM := 0.6  ## chance de cada pedra mirar perto de um lutador
const LAVA_SEEK := 8.0  ## IA de Fogo: descansa na lava a até isso
const LAVA_MAX := 8.0
## Caverna.
const DARK_SEE := 7.0
const DARK_ACC := 0.8
const LIGHT_TYPES := ["electric", "fire"]
const CRYSTAL_LIGHT := 2.5
const SHADOW_TYPES := ["ghost", "dark"]
const SHADOW_ACC := 0.9
const SHADOW_SEE := 2.0
## Pântano.
const FOG_SEE := 8.0
const FOG_ACC := 0.85
const SWAMP_TYPES := ["poison", "ground"]
const SWAMP_REGEN := 1.2
const POND_SHALLOW := 0.8  ## lagoas rasas: raio x isso
## IA: com golpe de longe e o alvo além do que dá para ver, chega mais perto (até VISION_IN x a visão).
const VISION_IN := 0.85
## IA: segundos seguidos no círculo/neve/lava; passou do limite espera o mesmo tanto x HOLD_CD_K.
const HOLD_CD_K := 1.0

var terrain  ## BattleTerrain
var arena: Node
var kind := ""  ## bioma desta luta ("" = nenhum)
var on := false  ## energia + bioma (+ opts.biomes)
var visual := true
## Colunas e montes: {kind, pos, r, h, node}
var solids: Array = []
## Círculo de runas: {pos, r, holder (lado; -1 vazio, -2 disputado), held, node, mat}
var rune := {}
## Paredão (montanha): {side} (lado do perp da quadra).
var cliff := {}
## Neve funda: {pos, t, node}
var deep: Array = []
## Avalanche avisada: {along, t}
var avalanche := {}
var av_cd := 0.0
## Lava: {pos, dir, cool, node, mat}
var lava: Array = []
## Erupção: relógio e pedras avisadas {at, t}
var erupt_t := ERUPT_FIRST
var rocks: Array = []
var _t := 0.0
var _pop := {}  ## "id:chave" -> _t do último aviso
var _burn := {}  ## id -> recarga do dano da lava
var _hold := {}  ## id -> {tag, t, cd}
var _env_undo: Array = []  ## [nó, propriedade, valor antigo] (luz da caverna/pântano)

static var _tex := {}


func _init(ter) -> void:
	terrain = ter
	arena = ter.arena


func _tele(k: String, data := {}) -> void:
	terrain._tele("terrain_" + k, data)


func _uid(f) -> String:
	return terrain._uid(f)


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _energy() -> bool:
	return arena.has_method("energy_on") and arena.energy_on()


func _dmg(f: BattleFighter, frac: float) -> int:
	return maxi(1, int(float(f.max_hp) * frac * f.dot_scale()))


func _pop_ok(f, key: String) -> bool:
	var k := "%d:%s" % [f.get_instance_id(), key]
	if _t - float(_pop.get(k, -100.0)) < POP_CD:
		return false
	_pop[k] = _t
	return true


func _has_type(f: BattleFighter, types: Array) -> bool:
	for t in f.types:
		if t in types:
			return true
	return false


# --- Eixos da quadra ---


func _ax() -> Vector3:
	var ax: Vector3 = _flat(arena.axis).normalized()
	return ax if ax.length() > 0.5 else Vector3.RIGHT


func _perp() -> Vector3:
	var ax := _ax()
	return Vector3(-ax.z, 0.0, ax.x)


func _centre() -> Vector3:
	var c: Vector2 = arena.rect.get_center()
	return Vector3(c.x, 0.0, c.y)


## Meia extensão da quadra na direção `v` (eixo ou perpendicular).
func _half(v: Vector3) -> float:
	var s: Vector2 = arena.rect.size
	return absf(v.x) * s.x * 0.5 + absf(v.z) * s.y * 0.5


# --- Montagem ---


## Antes do relevo: o círculo de runas no meio e os rios de lava (o resto do cenário desvia deles).
func pre_setup() -> void:
	kind = terrain.scenario if terrain.scenario in LIST else ""
	on = kind != "" and _energy() and bool(arena.opts.get("biomes", true))
	if not on:
		kind = ""
		return
	visual = arena.is_inside_tree() and not bool(arena.opts.get("fast_sim", false))
	match kind:
		"ruinas":
			rune = {"pos": _centre(), "r": RUNE_R, "holder": -1, "held": 0.0}
		"vulcao":
			_place_lava()


## Depois do relevo: colunas, montes, lama, paredão, chão, luz e clima.
func setup() -> void:
	if not on:
		return
	var rng: RandomNumberGenerator = arena.rng
	var plan: Dictionary = EXTRAS.get(kind, {})
	for k in ["pillar", "mound"]:
		for i in int(plan.get(k, 0)):
			var r: float = float(SOLIDS[k][0]) + 0.25
			var at := Vector3.INF
			for side in [1 if i % 2 == 0 else -1, -1 if i % 2 == 0 else 1]:
				at = terrain._place(rng, r, side, BattleTerrain.GAP * BattleTerrain.TIGHT_GAP)
				if at != Vector3.INF:
					break
			if at != Vector3.INF:
				_add_solid(k, at)
	if int(plan.get("mud", 0)) > 0 and terrain.ground.on:
		for i in int(plan.mud):
			var r := rng.randf_range(BattleGround.MUD_R[0], BattleGround.MUD_R[1])
			var at: Vector3 = terrain.ground._place_mud(rng, r, 1 if i % 2 == 0 else -1)
			if at != Vector3.INF:
				terrain.ground._add_mud(at, r, INF)
	match kind:
		"montanha":
			cliff = {"side": 1 if rng.randf() < 0.5 else -1}
			if String(arena.opts.get("weather", "")) == "" and rng.randf() < SNOW_CHANCE:
				arena.opts = arena.opts.duplicate()
				arena.opts["weather"] = "hail"
				var tel = arena.get("telemetry")
				if tel:
					tel.meta["weather"] = "hail"
				_tele("snowfall")
		"pantano":
			for o in terrain.obstacles:
				if o.kind == "pond":
					o.r = float(o.r) * POND_SHALLOW
					o.r0 = o.r
					o.top = o.r
					if is_instance_valid(o.get("node")):
						o.node.scale = Vector3(POND_SHALLOW, 1.0, POND_SHALLOW)
	if visual:
		_build()


func spot_free(at: Vector3, r: float, gap: float) -> bool:
	if not on:
		return true
	if not rune.is_empty() and _flat(at - rune.pos).length() < r + RUNE_R + gap:
		return false
	for s in solids:
		if _flat(at - s.pos).length() < r + float(s.r) + gap:
			return false
	for c in lava:
		if _flat(at - c.pos).length() < r + 0.7 + LAVA_KEEP + gap * 0.5:
			return false
	return true


func _add_solid(k: String, at: Vector3) -> void:
	solids.append({"kind": k, "pos": _flat(at), "r": float(SOLIDS[k][0]), "h": float(SOLIDS[k][1])})


## Rios de lava: LAVA_LEN células de 1 m em linha, atravessados (perpendicular ao eixo) ou ao longo
## dele, alternando as metades da quadra (o terceiro no meio), longe das entradas e uns dos outros.
func _place_lava() -> void:
	var rng: RandomNumberGenerator = arena.rng
	var ax := _ax()
	var pp := _perp()
	var c0 := _centre()
	var n := int(EXTRAS.vulcao.lava)
	for i in n:
		var side := 0 if i == n - 1 and n % 2 == 1 else (1 if i % 2 == 0 else -1)
		for _try in BattleTerrain.PLACE_TRIES:
			var dir := pp if rng.randf() < 0.6 else ax
			var half := float(LAVA_LEN) * 0.5
			var lim_a := _half(ax) - (half if dir == ax else LAVA_W) - BattleTerrain.KEEP_WALL - 0.4
			var lim_p := _half(pp) - (half if dir == pp else LAVA_W) - BattleTerrain.KEEP_WALL - 0.4
			var along := rng.randf_range(-lim_a, lim_a)
			if side == 0:
				along = rng.randf_range(-1.5, 1.5)
			elif signf(along) != float(side) or absf(along) < 2.5:
				continue
			var mid := c0 + ax * along + pp * rng.randf_range(-lim_p, lim_p)
			var cells: Array = []
			for k in LAVA_LEN:
				cells.append(mid + dir * (float(k) - half + 0.5))
			if not _lava_ok(cells):
				continue
			for p in cells:
				lava.append({"pos": p, "dir": dir, "cool": 0.0, "strip": i})
			break


func _lava_ok(cells: Array) -> bool:
	for p in cells:
		for s in [arena.player_spot, arena.enemy_spot]:
			if _flat(p - s).length() < BattleTerrain.KEEP_SPOT + 1.2:
				return false
		for c in lava:
			if _flat(p - c.pos).length() < 3.0:
				return false
	return true


# --- Consultas ---


func _grounded(f: BattleFighter) -> bool:
	return terrain._grounded(f) and f.ground_y < 0.1 and f.motion != "tunnel" and f.hidden == ""


func in_rune(f: BattleFighter) -> bool:
	if rune.is_empty() or not is_instance_valid(f) or not f.active() or f.hidden != "":
		return false
	return _flat(f.position - rune.pos).length() < float(rune.r) and f.height() < 1.5


## Célula de lava quente sob `p` (contando `pad` m de folga). {} se nenhuma.
func lava_at(p: Vector3, pad := 0.0, hot := true) -> Dictionary:
	for c in lava:
		if hot and float(c.cool) > 0.0:
			continue
		var rel := _flat(p - c.pos)
		var d: Vector3 = c.dir
		var n := Vector3(-d.z, 0.0, d.x)
		if absf(rel.dot(d)) <= 0.5 + pad and absf(rel.dot(n)) <= LAVA_W + pad:
			return c
	return {}


func lava_immune(f: BattleFighter) -> bool:
	return _has_type(f, LAVA_TYPES)


func in_lava(f: BattleFighter) -> bool:
	if lava.is_empty() or not is_instance_valid(f) or not _grounded(f):
		return false
	return not lava_at(f.position).is_empty()


func deep_at(p: Vector3) -> Dictionary:
	for c in deep:
		if _flat(p - c.pos).length() < CELL_R:
			return c
	return {}


func in_deep(f: BattleFighter) -> bool:
	if deep.is_empty() or not is_instance_valid(f) or not _grounded(f):
		return false
	return not deep_at(f.position).is_empty()


## Distância de `p` até a beira do paredão (montanha); INF sem paredão.
func cliff_dist(p: Vector3) -> float:
	if cliff.is_empty():
		return INF
	var pp := _perp() * float(cliff.side)
	return _half(_perp()) - _flat(p - _centre()).dot(pp)


## O alvo está visível de longe na caverna (luz própria, de quem atira ou de um cristal).
func lit(user: BattleFighter, target: BattleFighter) -> bool:
	if _has_type(user, LIGHT_TYPES) or _has_type(target, LIGHT_TYPES):
		return true
	for o in terrain.props.of_kind("crystal"):
		if _flat(target.position - o.pos).length() <= CRYSTAL_LIGHT:
			return true
	return false


## Até onde `user` enxerga `target` sem errar mais (INF = sem limite).
func sight(user: BattleFighter, target: BattleFighter) -> float:
	match kind:
		"caverna":
			return INF if lit(user, target) else DARK_SEE
		"pantano":
			return INF if _has_type(user, SWAMP_TYPES) else FOG_SEE
	return INF


# --- Ganchos do BattleTerrain ---


func move_mult(f: BattleFighter) -> float:
	if kind != "montanha" or not is_instance_valid(f) or "ice" in f.types or not _grounded(f):
		return 1.0
	return DEEP_MULT if in_deep(f) else SNOW_MULT


func regen_mult(f: BattleFighter) -> float:
	if not on or not is_instance_valid(f):
		return 1.0
	match kind:
		"ruinas":
			if int(rune.holder) == f.side and in_rune(f):
				return RUNE_REGEN
		"vulcao":
			if "fire" in f.types and not lava_at(f.position, LAVA_NEAR).is_empty():
				return LAVA_REGEN
		"pantano":
			if _has_type(f, SWAMP_TYPES):
				return SWAMP_REGEN
	return 1.0


## Precisão: escuro da caverna, Fantasma/Sombrio no escuro, neblina do pântano, Gelo na neve funda.
func acc_mult(user: BattleFighter, mv: Dictionary, target: BattleFighter) -> float:
	if not on or not is_instance_valid(user) or not is_instance_valid(target):
		return 1.0
	if not String(mv.get("kind", "")) in BattleTerrain.RANGED_KINDS:
		return 1.0
	if float(mv.get("accuracy", 0)) <= 0.0:
		return 1.0
	var d := user.flat_to(target).length()
	var k := 1.0
	match kind:
		"caverna":
			if d > DARK_SEE and not lit(user, target):
				k *= DARK_ACC
				_tele("dark", {"who": _uid(target), "by": _uid(user)})
				if _pop_ok(target, "dark"):
					target.popup("No escuro!", Color(0.55, 0.5, 0.75), 0.8, 0.4)
			if d > SHADOW_SEE and _has_type(target, SHADOW_TYPES):
				k *= SHADOW_ACC
				_tele("shadow", {"who": _uid(target), "by": _uid(user)})
		"pantano":
			if d > FOG_SEE and not _has_type(user, SWAMP_TYPES):
				k *= FOG_ACC
				_tele("fog", {"who": _uid(target), "by": _uid(user)})
				if _pop_ok(target, "fog"):
					target.popup("Neblina!", Color(0.7, 0.78, 0.7), 0.8, 0.4)
		"montanha":
			if "ice" in target.types and in_deep(target) and d > SNOW_SEE:
				k *= 1.0 - SNOW_EVADE
				_tele("snow_cover", {"who": _uid(target), "by": _uid(user)})
	return k


## Dano: Psíquico e Fantasma dentro do círculo de runas batem mais.
func damage_mult(user: BattleFighter, target: BattleFighter, mv: Dictionary) -> float:
	if kind != "ruinas" or not is_instance_valid(user) or float(mv.get("power", 0)) <= 0.0:
		return 1.0
	if not _has_type(user, RUNE_TYPES) or not in_rune(user):
		return 1.0
	_tele("rune_power", {"by": _uid(user), "who": _uid(target)})
	if _pop_ok(user, "rune_power"):
		user.popup("Poder das runas!", Color(0.8, 0.55, 1.0), 0.9, 0.5)
	return RUNE_POWER


## Golpe que caiu em `at`: avalanche (forte perto do paredão), Fogo derrete a neve funda, Água esfria a
## lava (Fogo derrete de novo a rocha esfriada).
func on_move_landed(user: BattleFighter, mv: Dictionary, at: Vector3, radius: float) -> void:
	if not on:
		return
	var type := String(mv.get("type", ""))
	var power := float(mv.get("power", 0))
	if power <= 0.0:
		return
	at = _flat(at)
	match kind:
		"montanha":
			if type == "fire":
				_melt(user, at, radius * 0.5 + 0.9)
			if (
				power >= AV_POWER
				and avalanche.is_empty()
				and av_cd <= 0.0
				and cliff_dist(at) <= AV_REACH + radius * 0.5
			):
				_warn_avalanche(user, at)
		"vulcao":
			if type in ["water", "fire"]:
				_cool(user, at, radius * 0.5 + 0.8, type == "water")


func blocks_shot(p: Vector3) -> bool:
	for s in solids:
		if p.y < float(s.h) and _flat(p - s.pos).length() < float(s.r):
			return true
	return false


func has_cover() -> bool:
	return not solids.is_empty()


func cover_cands() -> Array:
	var out: Array = []
	for s in solids:
		out.append({"pos": s.pos, "r": float(s.r)})
	return out


## Desvia a IA das colunas e montes, da lava (quem queima) e da neve funda (quem atola).
func steer(f: BattleFighter, want: Vector3) -> Vector3:
	if not on or want.length() < 0.05 or not is_instance_valid(f):
		return want
	var avoid: Array = []
	if f.height() < 0.6:
		for s in solids:
			avoid.append({"pos": s.pos, "r": float(s.r) + 0.15})
	if _grounded(f):
		if not lava_immune(f) and not in_lava(f):
			for c in lava:
				if float(c.cool) <= 0.0:
					avoid.append({"pos": c.pos, "r": 0.75})
		if not "ice" in f.types and not in_deep(f):
			for c in deep:
				avoid.append({"pos": c.pos, "r": CELL_R})
	if avoid.is_empty():
		return want
	var dir := want.normalized()
	var out := want
	for m in avoid:
		var to := _flat(m.pos - f.position)
		var ahead := to.dot(dir)
		if ahead <= 0.0 or ahead > float(m.r) + 1.4:
			continue
		var side := to - dir * ahead
		var clear := float(m.r) + 0.45
		if side.length() >= clear:
			continue
		var tangent := Vector3(-dir.z, 0.0, dir.x)
		if side.dot(tangent) > 0.0:
			tangent = -tangent
		out += tangent * (1.0 - side.length() / clear) * 1.3 * want.length()
	return out.normalized() * want.length() if out.length() > 0.001 else want


## Por quadro, depois de andar: colunas e montes são sólidos; a lava empurra para fora quem queima.
func settle(f: BattleFighter, dt: float) -> void:
	if not on or not f.active() or f.motion == "tunnel":
		return
	for s in solids:
		if f.height() > float(s.h):
			continue
		var d := _flat(f.position - s.pos)
		var lim := float(s.r) + BODY_R
		if d.length() >= lim:
			continue
		if d.length() < 0.001:
			d = Vector3.RIGHT
		f.position += d.normalized() * (lim - d.length())
	if lava.is_empty() or lava_immune(f) or not _grounded(f):
		return
	var c := lava_at(f.position)
	if c.is_empty():
		return
	var dv: Vector3 = c.dir
	var n := Vector3(-dv.z, 0.0, dv.x)
	var off := _flat(f.position - c.pos).dot(n)
	f.position += n * (1.0 if off >= 0.0 else -1.0) * LAVA_PUSH * dt


# --- Tempo ---


func tick(dt: float) -> void:
	if not on:
		return
	_t += dt
	av_cd = maxf(av_cd - dt, 0.0)
	match kind:
		"ruinas":
			_tick_rune(dt)
		"montanha":
			_tick_snow(dt)
		"vulcao":
			_tick_lava(dt)
	_tick_hold(dt)


func _tick_rune(dt: float) -> void:
	var sides := {}
	for f in arena.fighters:
		if is_instance_valid(f) and in_rune(f):
			sides[f.side] = true
	var holder := -1
	if sides.size() == 1:
		holder = int(sides.keys()[0])
	elif sides.size() > 1:
		holder = -2
	var was := int(rune.holder)
	if holder != was:
		if was >= 0:
			_tele("rune_lost", {"side": was, "secs": snappedf(float(rune.held), 0.1)})
		rune.holder = holder
		rune.held = 0.0
		if holder >= 0:
			_tele("rune_hold", {"side": holder})
			for f in arena.fighters:
				if is_instance_valid(f) and f.side == holder and in_rune(f) and _pop_ok(f, "rune"):
					f.popup("Runas: energia!", Color(0.8, 0.55, 1.0), 0.9, 0.5)
		elif holder == -2:
			_tele("rune_contest", {})
		_rune_look()
	if holder >= 0:
		rune.held = float(rune.held) + dt
	if is_instance_valid(rune.get("mat")) and holder >= 0:
		rune.mat.emission_energy_multiplier = 0.9 + 0.5 * absf(sin(_t * 3.0))


func _tick_snow(dt: float) -> void:
	if not avalanche.is_empty():
		avalanche.t = float(avalanche.t) - dt
		if float(avalanche.t) <= 0.0:
			_avalanche(avalanche)
			avalanche = {}
	for c in deep.duplicate():
		c.t = float(c.t) - dt
		if float(c.t) <= 0.0:
			_drop_cell(c)
		elif float(c.t) < 1.0 and is_instance_valid(c.get("node")):
			c.node.scale = Vector3(1.0, maxf(float(c.t), 0.1), 1.0)


func _tick_lava(dt: float) -> void:
	for c in lava:
		if float(c.cool) > 0.0:
			c.cool = float(c.cool) - dt
			if float(c.cool) <= 0.0:
				c.cool = 0.0
				_lava_look(c)
	for f in arena.fighters:
		if not is_instance_valid(f) or not f.active():
			continue
		var id: int = f.get_instance_id()
		var cd := float(_burn.get(id, 0.0)) - dt
		if cd <= 0.0 and in_lava(f) and not lava_immune(f):
			cd = 1.0
			var n: int = f.residual_damage(_dmg(f, LAVA_FRAC), "lava", Dex.type_color("fire"))
			if n > 0:
				_tele("lava_burn", {"who": _uid(f), "dmg": n})
				if visual:
					PixelFx.pop(arena, "fire", f.position + Vector3(0, 0.3, 0), 0.9, 0.3)
		_burn[id] = maxf(cd, 0.0)
	erupt_t -= dt
	if erupt_t <= 0.0:
		erupt_t = ERUPT_EVERY
		_erupt()
	for r in rocks.duplicate():
		r.t = float(r.t) - dt
		if float(r.t) <= 0.0:
			rocks.erase(r)
			_rock_hit(r)
		elif is_instance_valid(r.get("node")):
			r.node.material_override.albedo_color.a = 0.2 + 0.25 * absf(sin(_t * 12.0))
	if visual and fmod(_t, 0.25) < dt:
		for c in lava:
			if is_instance_valid(c.get("mat")) and float(c.cool) <= 0.0:
				c.mat.uv1_offset = Vector3(_t * 0.05, _t * 0.03, 0.0)


## Relógios da IA (círculo, neve, lava): conta enquanto a tag está ativa; passou do limite, espera.
func _tick_hold(dt: float) -> void:
	for f in arena.fighters:
		if not is_instance_valid(f) or f.get("ai") == null:
			continue
		var id: int = f.get_instance_id()
		var h: Dictionary = _hold.get(id, {"t": 0.0, "cd": 0.0})
		_hold[id] = h
		if float(h.cd) > 0.0:
			h.cd = maxf(float(h.cd) - dt, 0.0)
			continue
		if String(f.ai.get("tag")) in ["rune", "snow_hide", "lava_rest"]:
			h.t = float(h.t) + dt
		elif float(h.t) > 0.0:
			h.t = maxf(float(h.t) - dt * 0.5, 0.0)


# --- Montanha ---


func _warn_avalanche(user: BattleFighter, at: Vector3) -> void:
	var ax := _ax()
	var along := clampf(
		_flat(at - _centre()).dot(ax), -_half(ax) + AV_LEN * 0.5, _half(ax) - AV_LEN * 0.5
	)
	avalanche = {"along": along, "t": AV_WARN, "by": user}
	av_cd = AV_CD
	var pp := _perp() * float(cliff.side)
	var edge := _centre() + ax * along + pp * _half(_perp())
	var from := edge - pp * AV_DEPTH * 0.5 - ax * AV_LEN * 0.5
	arena.telegraph(
		{
			"kind": "line",
			"side": -1,
			"t": AV_WARN + 0.1,
			"from": from,
			"dir": ax,
			"len": AV_LEN,
			"w": AV_DEPTH
		}
	)
	_tele("avalanche_warn", {"by": _uid(user)})
	arena.say("O paredão tremeu: avalanche!")
	if visual:
		arena.fx_beam(
			from + Vector3(0, 0.05, 0), ax, AV_LEN, AV_DEPTH, Color(0.9, 0.95, 1.0, 0.3), AV_WARN
		)


func _avalanche(av: Dictionary) -> void:
	var ax := _ax()
	var pp := _perp() * float(cliff.side)
	var hw := _half(_perp())
	var base := _centre() + ax * float(av.along)
	var na := int(round(AV_LEN / CELL))
	var nd := int(round(AV_DEPTH / CELL))
	for i in na:
		for j in nd:
			var p: Vector3 = (
				base
				+ ax * ((float(i) + 0.5) * CELL - AV_LEN * 0.5)
				+ pp * (hw - (float(j) + 0.5) * CELL)
			)
			var old := deep_at(p)
			if not old.is_empty() and _flat(old.pos - p).length() < 0.3:
				old.t = AV_SECS
				continue
			var c := {"pos": p, "t": AV_SECS}
			if visual:
				c.node = _snow_cell(p)
			deep.append(c)
	var by: BattleFighter = av.by if is_instance_valid(av.get("by")) else null
	var hits: Array = []
	for f in arena.fighters:
		if not is_instance_valid(f) or not f.active() or "ice" in f.types or not _grounded(f):
			continue
		var rel := _flat(f.position - base)
		if absf(rel.dot(ax)) > AV_LEN * 0.5 or rel.dot(pp) < hw - AV_DEPTH:
			continue
		var n := _dmg(f, AV_FRAC)
		if by:
			f.last_hit_by = by
		f.popup("-%d Avalanche!" % n, Color(0.85, 0.92, 1.0), 1.1, 0.7)
		f.take_damage(n, -pp, 3.0)
		hits.append(_uid(f))
		_tele(
			"avalanche_hit",
			{
				"who": _uid(f),
				"by": _uid(by),
				"dmg": n,
				"frac": snappedf(float(n) / maxf(f.max_hp, 1), 0.001)
			}
		)
	_tele("avalanche", {"by": _uid(by), "hits": hits})
	arena.say("Avalanche!")
	if visual:
		PixelFx.pop(arena, "dust", base + pp * (hw - AV_DEPTH * 0.5) + Vector3(0, 0.6, 0), 4.0, 0.7)
		if not hits.is_empty() and arena.has_method("cut_in"):
			arena.cut_in("AVALANCHE!", Color(0.85, 0.92, 1.0))


## Fogo derrete a neve funda perto de `at`: vira poça (BattleGround).
func _melt(user: BattleFighter, at: Vector3, r: float) -> void:
	var n := 0
	for c in deep.duplicate():
		if _flat(c.pos - at).length() > r:
			continue
		_drop_cell(c)
		n += 1
		if terrain.ground.on:
			terrain.ground._add_mark(
				"puddle", c.pos, BattleGround.PUDDLE_R, BattleGround.PUDDLE_SECS, user
			)
	if n > 0:
		_tele("snow_melt", {"by": _uid(user), "n": n})
		arena.popup(at + Vector3(0, 0.8, 0), "A neve derreteu!", Dex.type_color("fire"))


func _drop_cell(c: Dictionary) -> void:
	deep.erase(c)
	if is_instance_valid(c.get("node")):
		c.node.queue_free()


# --- Vulcão ---


## Água esfria a lava perto de `at` em rocha por COOL_SECS s; Fogo derrete a rocha esfriada.
func _cool(user: BattleFighter, at: Vector3, r: float, water: bool) -> void:
	var n := 0
	for c in lava:
		if _flat(c.pos - at).length() > r:
			continue
		if water:
			n += 1 if float(c.cool) <= 0.0 else 0
			c.cool = COOL_SECS
		elif float(c.cool) > 0.0:
			c.cool = 0.0
			n += 1
		_lava_look(c)
	if n <= 0:
		return
	if water:
		_tele("lava_cool", {"by": _uid(user), "n": n})
		arena.popup(at + Vector3(0, 0.8, 0), "A lava esfriou!", Dex.type_color("water"))
		if visual:
			PixelFx.pop(arena, "wind", at + Vector3(0, 0.5, 0), 1.6, 0.5)
	else:
		_tele("lava_remelt", {"by": _uid(user), "n": n})


## Erupção: ERUPT_N pedras com aviso no chão (as duas equipes desviam), a maioria perto de alguém.
func _erupt() -> void:
	var rng: RandomNumberGenerator = arena.rng
	var inner: Rect2 = arena.rect.grow(-1.0)
	var live: Array = arena.fighters.filter(func(f): return is_instance_valid(f) and f.active())
	for i in ERUPT_N:
		var at := Vector3(
			rng.randf_range(inner.position.x, inner.end.x),
			0.0,
			rng.randf_range(inner.position.y, inner.end.y)
		)
		if not live.is_empty() and rng.randf() < ERUPT_AIM:
			var f: BattleFighter = live[rng.randi() % live.size()]
			var a := rng.randf() * TAU
			at = _flat(f.position) + Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.3, 1.4)
			at.x = clampf(at.x, inner.position.x, inner.end.x)
			at.z = clampf(at.z, inner.position.y, inner.end.y)
		var r := {"at": at, "t": ERUPT_WARN + 0.25 * i}
		arena.telegraph({"kind": "disc", "side": -1, "t": float(r.t), "at": at, "r": ERUPT_R})
		if visual:
			r.node = _ring(at, ERUPT_R, Color(1.0, 0.35, 0.1, 0.3))
		rocks.append(r)
	_tele("eruption", {})
	arena.say("O vulcão entrou em erupção!")


func _rock_hit(r: Dictionary) -> void:
	if is_instance_valid(r.get("node")):
		r.node.queue_free()
	for f in arena.fighters:
		if not is_instance_valid(f) or not f.active() or f.hidden != "" or f.motion == "tunnel":
			continue
		var rel := _flat(f.position - r.at)
		if rel.length() > ERUPT_R + 0.2 or f.height() > 2.0:
			continue
		var n := _dmg(f, ERUPT_FRAC)
		f.popup("-%d Pedra vulcânica!" % n, Color(1.0, 0.5, 0.25), 1.0, 0.6)
		f.take_damage(n, rel.normalized() if rel.length() > 0.05 else Vector3.RIGHT, ERUPT_KNOCK)
		_tele(
			"eruption_hit",
			{"who": _uid(f), "dmg": n, "frac": snappedf(float(n) / maxf(f.max_hp, 1), 0.001)}
		)
	if visual:
		PixelFx.pop(arena, "stone", r.at + Vector3(0, 0.4, 0), ERUPT_R * 1.6, 0.4)
		PixelFx.pop(arena, "fire", r.at + Vector3(0, 0.3, 0), ERUPT_R * 1.2, 0.3)


# --- IA ---


## Gancho da IA de energia (BattleAI._energy_steer, depois do BattleGround): sai da lava e da neve funda,
## disputa o círculo de runas, Gelo se esconde na neve funda, Fogo descansa na lava, chega mais perto no
## escuro e na neblina. INF = segue a IA normal.
static func steer_ai(ai, d: float) -> Vector3:
	var f: BattleFighter = ai.f
	var ter = f.arena.get("terrain") if f.arena else null
	if ter == null or ter.get("biomes") == null or not ter.biomes.on:
		return Vector3.INF
	return ter.biomes._steer_ai(ai, d)


func _steer_ai(ai, d: float) -> Vector3:
	var f: BattleFighter = ai.f
	if in_lava(f) and not lava_immune(f):
		ai.tag = "leave_lava"
		var c := lava_at(f.position)
		var dv: Vector3 = c.dir
		var n := Vector3(-dv.z, 0.0, dv.x)
		return n * (1.0 if _flat(f.position - c.pos).dot(n) >= 0.0 else -1.0)
	if in_deep(f) and not "ice" in f.types and ai.intent == "":
		ai.tag = "leave_snow"
		return -_perp() * float(cliff.get("side", 1))
	var h: Dictionary = _hold.get(f.get_instance_id(), {"t": 0.0, "cd": 0.0})
	var cap := {"ruinas": RUNE_MAX, "montanha": SNOW_MAX, "vulcao": LAVA_MAX}
	if float(h.t) > float(cap.get(kind, INF)):
		h.cd = float(cap[kind]) * HOLD_CD_K
		h.t = 0.0
		_tele("ai_hold_cap", {"who": _uid(f), "kind": kind})
		return Vector3.INF
	if float(h.cd) > 0.0:
		return Vector3.INF
	match kind:
		"ruinas":
			return _rune_steer(ai, d)
		"montanha":
			if "ice" in f.types and _short(ai):
				return _go_spot(ai, d, _nearest_deep(f), "snow_hide", SNOW_SEEK)
		"vulcao":
			if "fire" in f.types and _short(ai):
				return _go_spot(ai, d, _nearest_lava(f), "lava_rest", LAVA_SEEK)
		"caverna", "pantano":
			return _vision_steer(ai, d)
	return Vector3.INF


## Falta energia para o golpe pretendido (mesmo para quem não costuma recuar: descansar no círculo,
## na neve ou na lava é ficar na luta).
static func _short(ai) -> bool:
	if ai.intent == "" or ai.recover_t > 0.0:
		return false
	var f: BattleFighter = ai.f
	return BattleEnergy.secs_to(f, f.pp_cost_of(Dex.move(ai.intent))) > BattleAI.ENERGY_WAIT


func _go_spot(ai, d: float, spot: Vector3, tag: String, seek: float) -> Vector3:
	var f: BattleFighter = ai.f
	if spot == Vector3.INF:
		return Vector3.INF
	var to: Vector3 = spot - f.pos2(f.position)
	if to.length() > seek:
		return Vector3.INF
	if not _safe(f, spot):
		return Vector3.INF
	if ai.tag != tag:
		_tele("ai_" + tag, {"who": _uid(f)})
	ai.tag = tag
	ai._fly(d)
	if to.length() < 0.35:
		return Vector3.ZERO
	f.sprinting = to.length() > 3.0 and f.can_sprint(true)
	return to.normalized() * clampf(to.length(), 0.3, 1.0)


## Nenhum inimigo a menos de 2 m do ponto (nem mais perto dele que eu, a menos de 3 m).
func _safe(f: BattleFighter, spot: Vector3) -> bool:
	var mine := _flat(f.position - spot).length()
	for g in arena.targets_of(f):
		var gd := _flat(g.position - spot).length()
		if gd < 2.0 or (gd < mine and gd < 3.0):
			return false
	return true


func _nearest_deep(f: BattleFighter) -> Vector3:
	var best := Vector3.INF
	var bd := INF
	for c in deep:
		var dd := _flat(c.pos - f.position).length()
		if dd < bd and float(c.t) > 3.0:
			bd = dd
			best = c.pos
	return best


func _nearest_lava(f: BattleFighter) -> Vector3:
	var best := Vector3.INF
	var bd := INF
	for c in lava:
		var dd := _flat(c.pos - f.position).length()
		if dd < bd and float(c.cool) <= 0.0:
			bd = dd
			best = c.pos
	return best


## Rei do morro: vai ao círculo quando falta energia ou quando dali o golpe pretendido alcança o alvo;
## sem disputar com HP baixo, com o parceiro já lá ou com inimigo dentro e HP pior.
func _rune_steer(ai, d: float) -> Vector3:
	var f: BattleFighter = ai.f
	if rune.is_empty() or ai.recover_t > 0.0 or f.mood_state == "fury":
		return Vector3.INF
	var hp := float(f.hp) / maxf(f.max_hp, 1)
	if hp < RUNE_HP or (ai.hurt_t < 1.0 and not in_rune(f)):
		return Vector3.INF
	var to: Vector3 = rune.pos - f.pos2(f.position)
	if to.length() > RUNE_SEEK:
		return Vector3.INF
	var foes_in := false
	for g in arena.fighters:
		if not is_instance_valid(g) or not in_rune(g):
			continue
		if g.side != f.side:
			foes_in = true
		elif g != f and not in_rune(f):
			return Vector3.INF  # o parceiro já segura o círculo
	if foes_in and hp < RUNE_CONTEST_HP:
		return Vector3.INF
	var want := _short(ai) or f.pp_max < BattleEnergy.MAX * 0.6
	var opp: BattleFighter = f.opponent
	if not want and ai.intent != "" and is_instance_valid(opp):
		var reach: float = ai.move_reach(ai.intent)
		if reach != INF and _flat(opp.position - rune.pos).length() <= reach * 0.9:
			want = true  # dali o golpe alcança: briga de dentro do círculo
	if not want:
		return Vector3.INF
	if ai.tag != "rune":
		_tele("ai_rune", {"who": _uid(f), "contest": foes_in})
	ai.tag = "rune"
	ai._fly(d)
	if to.length() < float(rune.r) * 0.45:
		return Vector3.ZERO
	f.sprinting = to.length() > 3.0 and f.can_sprint(true)
	return to.normalized() * clampf(to.length(), 0.3, 1.0)


## Caverna e pântano: com golpe de longe pronto e o alvo além do que dá para ver, chega mais perto.
func _vision_steer(ai, d: float) -> Vector3:
	var f: BattleFighter = ai.f
	var opp: BattleFighter = f.opponent
	if ai.intent == "" or ai.recover_t > 0.0 or not is_instance_valid(opp) or not opp.active():
		return Vector3.INF
	if ai.is_contact(ai.intent) or BattleTerrainAI._needs_rest(ai):
		return Vector3.INF
	var mv := Dex.move(ai.intent)
	if float(mv.get("accuracy", 0)) <= 0.0:
		return Vector3.INF
	var see := sight(f, opp)
	if see == INF or d <= see * VISION_IN:
		return Vector3.INF
	var tag := "dark_close" if kind == "caverna" else "fog_close"
	if ai.tag != tag:
		_tele("ai_close", {"who": _uid(f), "kind": kind})
	ai.tag = tag
	ai._fly(d)
	return (f.flat_to(opp).normalized() + f.arena.edge_push(f) * 0.5).limit_length(1.0)


# --- Visual (barato; nada com opts.fast_sim) ---


func _build() -> void:
	var rc: Rect2 = arena.rect
	var fl := BattleTerrain._box(Vector3(rc.size.x, 0.01, rc.size.y), tex(String(FLOOR[kind])))
	fl.material_override.uv1_scale = Vector3.ONE * 0.6
	fl.position = Vector3(rc.get_center().x, 0.004, rc.get_center().y)
	fl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arena.add_child(fl)
	for s in solids:
		s.node = _solid_node(s)
	_retint()
	match kind:
		"ruinas":
			var mi := MeshInstance3D.new()
			var pm := PlaneMesh.new()
			pm.size = Vector2(RUNE_R * 2.0, RUNE_R * 2.0)
			mi.mesh = pm
			var mat := StandardMaterial3D.new()
			mat.albedo_texture = rune_tex()
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.emission_enabled = true
			mat.emission_texture = rune_tex()
			mat.emission_energy_multiplier = 0.6
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.position = rune.pos + Vector3(0, 0.02, 0)
			arena.add_child(mi)
			rune.node = mi
			rune.mat = mat
		"montanha":
			_build_cliff()
		"vulcao":
			for c in lava:
				_lava_node(c)
			_env({"ambient": Color(0.75, 0.5, 0.42), "sun": 0.85})
		"caverna":
			_env({"ambient": Color(0.2, 0.2, 0.3), "bg": Color(0.04, 0.04, 0.07), "sun": 0.18})
			for o in terrain.props.of_kind("crystal"):
				if is_instance_valid(o.get("node")):
					var l := OmniLight3D.new()
					l.light_color = Color(0.55, 0.9, 1.0)
					l.light_energy = 1.6
					l.omni_range = CRYSTAL_LIGHT + 0.8
					l.position = Vector3(0, 1.0, 0)
					o.node.add_child(l)
		"pantano":
			_env(
				{
					"ambient": Color(0.5, 0.56, 0.48),
					"bg": Color(0.5, 0.56, 0.5),
					"sun": 0.6,
					"fog": Color(0.55, 0.62, 0.55)
				}
			)


## Luz da cena (caverna escura, neblina do pântano, brilho da lava): muda o WorldEnvironment e o sol da
## tela e desfaz quando a arena sai da árvore.
func _env(want: Dictionary) -> void:
	var root: Node = arena.get_tree().root
	for we in root.find_children("*", "WorldEnvironment", true, false):
		var env: Environment = we.environment
		if env == null:
			continue
		if want.has("ambient"):
			_set_undo(env, "ambient_light_color", want.ambient)
		if want.has("bg"):
			_set_undo(env, "background_color", want.bg)
		if want.has("fog"):
			_set_undo(env, "fog_enabled", true)
			_set_undo(env, "fog_light_color", want.fog)
			_set_undo(env, "fog_density", 0.035)
	for sun in root.find_children("*", "DirectionalLight3D", true, false):
		_set_undo(sun, "light_energy", float(sun.light_energy) * float(want.get("sun", 1.0)))
	if not _env_undo.is_empty() and not arena.tree_exiting.is_connected(_restore_env):
		arena.tree_exiting.connect(_restore_env)


func _set_undo(obj: Object, prop: String, v) -> void:
	_env_undo.append([obj, prop, obj.get(prop)])
	obj.set(prop, v)


func _restore_env() -> void:
	for i in range(_env_undo.size() - 1, -1, -1):
		var u: Array = _env_undo[i]
		if is_instance_valid(u[0]):
			u[0].set(u[1], u[2])
	_env_undo.clear()


## Relevo com a cara do bioma: neve no topo na montanha, rocha escura no vulcão e na caverna.
func _retint() -> void:
	var look := {"montanha": "snow", "vulcao": "dark_rock", "caverna": "cave_rock"}
	if not look.has(kind):
		return
	var t := tex(String(look[kind]))
	for o in terrain.obstacles:
		if o.kind == "pond" or not is_instance_valid(o.get("node")):
			continue
		var kids: Array = o.node.get_children()
		for i in kids.size():
			if not kids[i] is MeshInstance3D:
				continue
			if kind == "montanha" and i == 0:
				continue  # a encosta fica; topo e tufos viram neve
			kids[i].material_override = BattleTerrain._mat(t, 1.2)


func _solid_node(s: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Biome_%s" % s.kind
	root.position = s.pos
	match String(s.kind):
		"pillar":
			root.add_child(terrain._frustum(s.r, s.r * 0.85, s.h, tex("ruin_stone"), 8, 1.0))
			var cap := BattleTerrain._box(Vector3(s.r * 2.4, 0.22, s.r * 2.4), tex("ruin_stone"))
			cap.position.y = s.h + 0.11
			root.add_child(cap)
		"mound":
			var mi := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = s.r + 0.1
			sm.height = s.h * 2.0
			sm.radial_segments = 10
			sm.rings = 4
			mi.mesh = sm
			mi.material_override = BattleTerrain._mat(tex("snow"), 1.2)
			root.add_child(mi)
	arena.add_child(root)
	return root


func _build_cliff() -> void:
	var ax := _ax()
	var pp := _perp() * float(cliff.side)
	var long := _half(ax) * 2.0 + 4.0
	var wall := BattleTerrain._box(Vector3(long, 4.0, 2.0), tex("cliff"))
	wall.position = _centre() + pp * (_half(_perp()) + 1.4) + Vector3(0, 2.0, 0)
	wall.rotation.y = -atan2(ax.z, ax.x)
	arena.add_child(wall)
	var top := BattleTerrain._box(Vector3(long, 0.3, 2.2), tex("snow"))
	top.position = wall.position + Vector3(0, 2.1, 0)
	top.rotation.y = wall.rotation.y
	arena.add_child(top)
	cliff.node = wall


func _snow_cell(p: Vector3) -> MeshInstance3D:
	var mi := BattleTerrain._box(Vector3(CELL, 0.25, CELL), tex("snow_deep"))
	mi.position = p + Vector3(0, 0.12, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arena.add_child(mi)
	return mi


func _lava_node(c: Dictionary) -> void:
	var mi := BattleTerrain._box(Vector3(1.0, 0.03, LAVA_W * 2.0), tex("lava"))
	var d: Vector3 = c.dir
	mi.rotation.y = -atan2(d.z, d.x)
	mi.position = c.pos + Vector3(0, 0.02, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat: StandardMaterial3D = mi.material_override
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.4, 0.1)
	mat.emission_energy_multiplier = 0.8
	arena.add_child(mi)
	c.node = mi
	c.mat = mat


func _lava_look(c: Dictionary) -> void:
	if not is_instance_valid(c.get("mat")):
		return
	var cool := float(c.cool) > 0.0
	c.mat.albedo_texture = tex("lava_cool" if cool else "lava")
	c.mat.emission_enabled = not cool


func _rune_look() -> void:
	if not is_instance_valid(rune.get("mat")):
		return
	var h := int(rune.holder)
	var col := Color(0.6, 0.45, 0.9)
	if h == 0:
		col = Color(0.4, 0.75, 1.0)
	elif h == 1:
		col = Color(1.0, 0.45, 0.4)
	rune.mat.albedo_color = Color(col.r, col.g, col.b, 1.0)
	rune.mat.emission = col
	rune.mat.emission_energy_multiplier = 0.6 if h < 0 else 1.2


func _ring(at: Vector3, r: float, col: Color) -> MeshInstance3D:
	var ring := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = 0.02
	cm.radial_segments = 24
	ring.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = col
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position = at + Vector3(0, 0.03, 0)
	arena.add_child(ring)
	return ring


## Círculo de runas (64 x 64, fundo transparente): anel duplo e marcas em volta, em tons claros (a cor
## vem do material: de quem segura o círculo).
static func rune_tex() -> Texture2D:
	if _tex.has("_rune"):
		return _tex["_rune"]
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in 64:
		for x in 64:
			var dx := x - 31.5
			var dy := y - 31.5
			var r := sqrt(dx * dx + dy * dy)
			var a := atan2(dy, dx)
			var c := Color(0, 0, 0, 0)
			if absf(r - 30.0) < 1.2 or absf(r - 25.0) < 0.8:
				c = Color(1, 1, 1, 0.95)
			elif r > 25.5 and r < 29.5:
				# Glifos: blocos curtos entre os anéis.
				var seg := int(floor((a + PI) / TAU * 16.0))
				var off := fmod((a + PI) / TAU * 16.0, 1.0)
				if off > 0.25 and off < 0.75 and (seg % 2 == 0 or absf(r - 27.5) < 0.8):
					c = Color(1, 1, 1, 0.8)
			elif r < 12.0 and (absi(int(dx)) == absi(int(dy)) or absf(r - 11.0) < 0.8):
				c = Color(1, 1, 1, 0.7)
			img.set_pixel(x, y, c)
	var t := ImageTexture.create_from_image(img)
	_tex["_rune"] = t
	return t


## Texturas de pixel art (32 x 32, geradas uma vez).
static func tex(k: String) -> Texture2D:
	if _tex.has(k):
		return _tex[k]
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("biome_" + k)
	var pal: Array = _palette(k)
	for y in 32:
		for x in 32:
			img.set_pixel(x, y, pal[_shade(k, x, y, rng)])
	var t := ImageTexture.create_from_image(img)
	_tex[k] = t
	return t


static func _palette(k: String) -> Array:
	match k:
		"ruin_stone":
			return [Color("5e5648"), Color("8a806c"), Color("a39880"), Color("c2b89c")]
		"snow":
			return [Color("9fb4c8"), Color("d6e2ee"), Color("e8f0f8"), Color("ffffff")]
		"snow_deep":
			return [Color("b8cce0"), Color("e4eef8"), Color("f2f8ff"), Color("ffffff")]
		"cliff":
			return [Color("2e3238"), Color("4a5058"), Color("666d76"), Color("dfe8f0")]
		"dark_rock":
			return [Color("1a1614"), Color("2c2522"), Color("3e3430"), Color("5a4a42")]
		"lava":
			return [Color("8a1c08"), Color("d8400c"), Color("ff7a1a"), Color("ffd040")]
		"lava_cool":
			return [Color("1c1612"), Color("3a2c26"), Color("54423a"), Color("a0401a")]
		"cave_rock":
			return [Color("16161c"), Color("24242e"), Color("33333f"), Color("4a4a5a")]
		"swamp":
			return [Color("24301c"), Color("34442a"), Color("465a36"), Color("5e7044")]
	return [Color.BLACK, Color.DIM_GRAY, Color.GRAY, Color.WHITE]


static func _shade(k: String, x: int, y: int, rng: RandomNumberGenerator) -> int:
	var n := rng.randf()
	match k:
		"ruin_stone":
			# Lajes: juntas escuras a cada 8 px, deslocadas a cada fileira.
			var row := int(y / 8)
			if y % 8 == 0 or (x + (4 if row % 2 else 0)) % 16 == 0:
				return 0
			if n < 0.08:
				return 3
			return 1 if n < 0.55 else 2
		"snow", "snow_deep":
			if (x * 3 + y * 5) % 23 == 0 and n < 0.7:
				return 0
			if n < 0.15:
				return 3
			return 1 if n < 0.45 else 2
		"cliff":
			if y < 3:
				return 3
			if (x + y * 2) % 9 == 0 and n < 0.7:
				return 0
			return 1 if n < 0.5 else 2
		"dark_rock", "cave_rock":
			if (x * 2 + int(sin(y * 0.7) * 3.0)) % 11 == 0 and n < 0.7:
				return 0
			if n < 0.06:
				return 3
			return 1 if n < 0.55 else 2
		"lava":
			if int(x + sin(y * 0.5) * 4.0) % 8 == 0 and n < 0.8:
				return 3
			return 1 if n < 0.45 else (2 if n < 0.85 else 0)
		"lava_cool":
			if (x + y) % 13 == 0 and n < 0.4:
				return 3
			return 1 if n < 0.5 else (2 if n < 0.85 else 0)
		"swamp":
			if n < 0.05:
				return 3
			if (x * 5 + y * 3) % 17 == 0:
				return 0
			return 1 if n < 0.6 else 2
	return 1

class_name BattleTerrain
extends RefCounted
## Relevo da quadra (opts.terrain, o treino liga): morros, picos, lagos e grama alta como objetos 3D de
## verdade, com texturas de pixel art. A arena cria um por luta (arena.terrain) e chama os ganchos abaixo.
##
## - Cenário (opts.scenario; sem ele, sorteado): quantos morros, picos, lagos, moitas e caixas/pedras
##   aparecem (SCENARIOS). Posições aleatórias, espalhadas (GAP entre bordas), longe das paredes e das
##   entradas, alternando as metades da quadra (o ímpar de cada tipo vai para a faixa do meio).
## - Morro: tronco de cone baixo com topo de grama; qualquer um sobe pela encosta (mais devagar).
## - Pico: alto e estreito; só sobem os escaladores (Pedra, Terra, Lutador, Voador, Inseto ou Speed alta);
##   para os outros é sólido.
## - Lago: quem não é de Água anda devagar dentro. Energia: Água e Grama recuperam mais, os outros menos,
##   Fogo bem menos e ainda toma dano por segundo. Elétrico contra quem está na água bate mais forte.
##   Chuva aumenta o lago, sol diminui, granizo/neve congela.
## - Grama alta: baixa e atravessável. Quem está dentro fica escondido (golpe à distância erra mais) e
##   quem é de Grama recupera energia mais rápido. Fogo queima a moita: todos dentro tomam dano alto e
##   podem ficar queimados, e ela vira chão queimado. Com sol o fogo pula para as moitas vizinhas; com
##   chuva a grama molhada não pega fogo.
##
## No alto (ground_y >= HIGH), golpe à distância ou Voador contra quem está mais baixo acerta mais
## (HIGH_ACC). Golpe de Terra, Pedra ou Lutador que cai num morro ou pico tira vida dele; quando ele
## desaba, quem está em cima cai, toma dano e fica atordoado. Empurrão forte em quem está no alto o
## derruba de lá; golpe de Água com empurrão perto do lago puxa o alvo para dentro. Picos, caixas e
## pedras são cobertura: param projéteis e raios. Raio no lago passa a corrente para quem está na mesma
## água; gelo congela o lago.

const HIGH := 0.6  ## altura do chão a partir da qual o lutador está "no alto"
const HIGH_ACC := 1.2  ## precisão de golpe à distância/Voador de cima para baixo
const HIGH_DIFF := 0.4  ## desnível mínimo para o bônus
const RANGED_KINDS := ["projectile", "homing", "beam", "stream", "aoe_target", "zone", "whip"]
const BREAKERS := ["ground", "rock", "fighting"]
const CLIMB_TYPES := ["rock", "ground", "fighting", "flying", "bug"]
const CLIMB_SPEED := 115.0  ## Speed (stat no Nv da luta) a partir da qual qualquer um escala o pico
const HILL_HP := 4
const PEAK_HP := 3
const STRONG := 80.0  ## poder a partir do qual o golpe tira 2 de vida do relevo
const FALL_FRAC := 0.125  ## dano da queda (fração do HP máximo)
const FALL_STUN := 1.5  ## atordoado depois de cair (s), + FALL_STUN_H por metro
const FALL_STUN_H := 0.4
const UPHILL_MULT := 0.8
const WADE_MULT := 0.6
const SWIM_MULT := 1.3
const ICE_MULT := 1.15
const SWIM_REGEN := 1.3  ## energia de quem é de Água ou de Grama dentro do lago
const WADE_REGEN := 0.6  ## energia dos outros tipos dentro do lago
const FIRE_WATER_REGEN := 0.35  ## energia de quem é de Fogo dentro do lago
const FIRE_WATER_DOT := 1.0 / 32.0  ## dano por segundo de Fogo dentro do lago (fração do HP máximo)
const ELEC_WATER := 1.3  ## dano de golpe Elétrico em quem está na água (lago não congelado)
const RISE := 6.0  ## m/s que o chão sobe sob o lutador (encosta)
const FALL_G := 14.0
const CONDUCT := 0.75  ## poder da corrente que passa pela água (o 0,75x oficial do golpe em área)
const FREEZE_SECS := 10.0
const KEEP_SPOT := 1.8  ## longe dos pontos de entrada
const KEEP_WALL := 1.0
const GAP := 1.2  ## distância mínima entre as bordas de dois obstáculos (espalha o cenário)
const HIT_CD := 0.35
## VGC: meia largura do corredor livre entre as posições dos dois lados (m).
const VGC_LANE := 2.8
## Cenários (opts.scenario; sem ele, sorteado pela rng da arena): quantos de cada obstáculo aparecem.
## "crate" são as caixas/pedras do BattleField. Todo cenário sorteável tem ao menos um morro, um pico e
## um lago (a praia não tem lago: a maré faz o papel dele).
const SCENARIOS := {
	"campo": {"pond": 1, "hill": 2, "peak": 1, "grass": 5, "crate": 2},
	"lagoa": {"pond": 3, "hill": 1, "peak": 1, "grass": 3, "crate": 1},
	"pedreira": {"pond": 1, "hill": 2, "peak": 3, "grass": 1, "crate": 4},
	"misto": {"pond": 2, "hill": 2, "peak": 2, "grass": 3, "crate": 2},
	"praia": {"pond": 0, "hill": 1, "peak": 1, "grass": 1, "crate": 3},
}
## Cenários fora do sorteio: só quando escolhidos (opts.scenario). A praia (maré e lama, BattleGround) não
## tem lago e é do modo de energia.
const PICK_ONLY := ["praia"]
const PLACE_ORDER := ["pond", "hill", "peak", "grass", "crate"]  ## os grandes primeiro
## Tamanho por tipo: [raio mín., raio máx., altura mín., altura máx.].
const SIZES := {
	"pond": [1.5, 2.0, 0.0, 0.0],
	"hill": [1.7, 2.2, 0.9, 1.15],
	"peak": [1.2, 1.45, 1.6, 1.9],
	"grass": [1.0, 1.4, 0.0, 0.0],
	"crate": [0.55, 0.55, 0.0, 0.0],
}
const MID_BAND := 2.5  ## o ímpar de cada tipo fica a até MID_BAND m da linha do meio; os outros além
const TIGHT_GAP := 0.5  ## sem lugar com GAP, tenta de novo com GAP x TIGHT_GAP
const PLACE_TRIES := 150
## Grama alta.
const GRASS_H := 0.65  ## altura das lâminas (só visual; quem voa não se esconde)
const GRASS_EVADE := 0.3  ## golpe à distância contra quem está na grama erra mais (precisão x 0,7)
const GRASS_SEE := 1.5  ## colado (até GRASS_SEE m) o atacante enxerga: sem evasão
const GRASS_REGEN := 1.3  ## energia de quem é de Grama dentro da moita
const GRASS_BURN_FRAC := 1.0 / 6.0  ## dano de quem está na moita quando ela queima (fração do HP)
const GRASS_BURN_STATUS := 0.3  ## chance de ficar queimado na moita em chamas
const SUN_BURN_MULT := 1.25  ## com sol a moita queima mais forte
const SPREAD_GAP := 2.5  ## com sol o fogo pula para moitas a até SPREAD_GAP m (borda a borda)
const SPREAD_DELAY := 0.5
## Rebrota: a moita queimada volta depois de REGROW_DELAY s (chuva conta REGROW_RAIN x mais rápido; com
## sol/seca não conta) e cresce em REGROW_SECS s (escala de REGROW_FROM até 1).
const REGROW_DELAY := 20.0
const REGROW_RAIN := 2.0
const REGROW_SECS := 4.0
const REGROW_FROM := 0.3
## Granizo: o aviso "O lago congelou!" (log e telemetria) sai no máximo a cada FREEZE_SAY_CD s por lago.
const FREEZE_SAY_CD := 12.0
## Areia: na tempestade de areia, Pedra/Terra/Aço se camuflam (golpe à distância x 0,85).
const SAND_TYPES := ["rock", "ground", "steel"]
const SAND_EVADE := 0.15
## Clima no lago: chuva aumenta o raio, sol diminui (POND_GROW m/s até o alvo); granizo/neve congela.
const RAIN_POND := 1.25
const SUN_POND := 0.8
const POND_GROW := 0.15
## Puxado para a água: golpe de Água de PULL_MOVES (ou empurrão efetivo >= PULL_KNOCK) em quem está a
## até PULL_RANGE m da beira do lago (e não é de Água nem voa) leva o alvo para dentro em PULL_SECS s.
const PULL_MOVES := [
	"surf",
	"hydro_pump",
	"hydro_cannon",
	"water_pulse",
	"whirlpool",
	"aqua_tail",
	"liquidation",
	"muddy_water",
	"water_spout",
	"wave_crash",
	"waterfall",
	"dive",
	"razor_shell",
]
const PULL_KNOCK := 6.0
const PULL_RANGE := 2.0
const PULL_SECS := 0.35
## Derrubado do alto: empurrão efetivo >= DROP_KNOCK em quem está em cima de morro/pico, fora do miolo
## do topo (DROP_EDGE x raio do topo; no pico vale qualquer ponto), joga o alvo para fora: DROP_FRAC do
## HP e atordoado DROP_STUN s + DROP_STUN_H s por metro de altura.
const DROP_KNOCK := 8.0
const DROP_EDGE := 0.5
const DROP_OUT := 0.5
const DROP_SECS := 0.3
const DROP_FRAC := 1.0 / 16.0
const DROP_STUN := 0.6
const DROP_STUN_H := 0.3
const SHOVE_CD := 3.0  ## o mesmo lutador só é puxado/derrubado de novo depois de SHOVE_CD s

var arena: Node
## {kind: "hill"/"peak"/"pond", pos, r, top, h, hp, max_hp, node, cd, ice_t, top_node, mat}
var obstacles: Array = []
var _fall_v := {}  ## id do lutador -> velocidade da queda (m/s)
var _water_t := 0.0
var scenario := ""  ## cenário desta luta ("" = sem relevo)
## Moitas de grama alta: {kind: "grass", pos, r, node}
var grass: Array = []
## Moitas queimadas esperando rebrotar: {pos, r, t}
var burnt: Array = []
## Onde o BattleField põe as caixas/pedras do cenário (locais, planos).
var crate_spots: Array = []
var _slides := {}  ## id do lutador -> {from, to, t, dur} (puxado/derrubado)
var _shove_at := {}  ## id do lutador -> _water_t do último puxão/derrubada
var _fire_t := {}  ## id do lutador de Fogo -> segundos acumulados dentro do lago
## Chão do modo de energia: lama, marcas de golpe e a maré da praia (BattleGround).
var ground: BattleGround

static var _tex := {}


func _init(a: Node) -> void:
	arena = a
	ground = BattleGround.new(self)


func _tele(kind: String, data: Dictionary) -> void:
	var tel = arena.get("telemetry")
	if tel:
		tel.note(kind, data)


func _uid(f) -> String:
	var tel = arena.get("telemetry")
	return tel.uid(f) if tel and is_instance_valid(f) else ""


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


## Monta o cenário: tipo sorteado (ou opts.scenario) e obstáculos em posições aleatórias, espalhados e
## divididos entre as duas metades da quadra.
func setup() -> void:
	if not bool(arena.opts.get("terrain", false)):
		return
	var rng: RandomNumberGenerator = arena.rng
	scenario = String(arena.opts.get("scenario", ""))
	if not SCENARIOS.has(scenario):
		var names: Array = SCENARIOS.keys()
		names = names.filter(func(n): return not n in PICK_ONLY)
		names.sort()
		scenario = String(names[rng.randi() % names.size()])
	var tel = arena.get("telemetry")
	if tel:
		tel.meta["scenario"] = scenario
	var plan: Dictionary = SCENARIOS[scenario]
	# Cada obstáculo vai para a metade com menos coisa; o ímpar de cada tipo tenta a faixa do meio.
	var count := {1: 0, -1: 0}
	for kind in PLACE_ORDER:
		var n := int(plan.get(kind, 0))
		var sz: Array = SIZES[kind]
		for i in n:
			var r := rng.randf_range(sz[0], sz[1])
			var h := rng.randf_range(sz[2], sz[3])
			var light := 1 if count[1] < count[-1] else -1
			if count[1] == count[-1]:
				light = 1 if rng.randf() < 0.5 else -1
			var sides := [light, -light]
			if n % 2 == 1 and i == n - 1:
				sides.push_front(0)
			var at := Vector3.INF
			for gap in [GAP, GAP * TIGHT_GAP]:  # sem lugar: aperta um pouco antes de desistir
				for side in sides:
					at = _place(rng, r, side, gap)
					if at != Vector3.INF:
						if side != 0:
							count[side] += 1
						break
				if at != Vector3.INF:
					break
			if at == Vector3.INF:
				continue
			match String(kind):
				"grass":
					_add_grass(at, r)
				"crate":
					crate_spots.append(at)
				_:
					_add(String(kind), at, r, h)
	ground.setup()  # lama e maré (só no modo de energia)


## Ponto livre para um obstáculo de raio `r` na metade `side` (1 = lado de arena.axis, -1 = o outro,
## além da faixa do meio; 0 = faixa do meio), a `gap` m das bordas dos outros. INF se não coube.
func _place(rng: RandomNumberGenerator, r: float, side: int, gap: float) -> Vector3:
	var rc: Rect2 = arena.rect.grow(-(r + KEEP_WALL))
	if rc.size.x <= 0.0 or rc.size.y <= 0.0:
		return Vector3.INF
	var ax: Vector3 = _flat(arena.axis).normalized()
	if ax.length() < 0.5:
		ax = Vector3.RIGHT
	for _try in PLACE_TRIES:
		var at := Vector3(
			rng.randf_range(rc.position.x, rc.end.x), 0.0, rng.randf_range(rc.position.y, rc.end.y)
		)
		var along := at.dot(ax)
		if side == 0:
			at += ax * (rng.randf_range(-MID_BAND, MID_BAND) - along)
		elif signf(along) != float(side):
			at -= ax * 2.0 * along  # reflete para a metade pedida
		if side != 0 and absf(along) <= MID_BAND:
			continue
		if not rc.has_point(Vector2(at.x, at.z)):
			continue
		if _spot_free(at, r, gap):
			return at
	return Vector3.INF


func _spot_free(at: Vector3, r: float, gap: float) -> bool:
	if _in_vgc_lane(at, r):
		return false
	for s in [arena.player_spot, arena.enemy_spot]:
		if _flat(at - s).length() < r + KEEP_SPOT:
			return false
	for o in obstacles + grass:
		if _flat(at - o.pos).length() < r + float(o.r) + gap:
			return false
	for c in crate_spots:
		if _flat(at - c).length() < r + BattleField.OBJ_R + gap:
			return false
	return true


## VGC (posições fixas): nada entre as duas posições dos lados, senão tiro e raio de casa batem na
## cobertura e a luta se arrasta (bateria 5: empates no 1x1 do VGC subiram com os cenários).
func _in_vgc_lane(at: Vector3, r: float) -> bool:
	if not arena.has_method("energy_on") or arena.energy_on():
		return false
	var a: Vector3 = _flat(arena.player_spot)
	var b: Vector3 = _flat(arena.enemy_spot)
	var ab := b - a
	var t := clampf((_flat(at) - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
	return _flat(at - (a + ab * t)).length() < VGC_LANE + r


func _add(kind: String, at: Vector3, r: float, h: float) -> void:
	var o := {
		"kind": kind,
		"pos": _flat(at),
		"r": r,
		"top": r * 0.55 if kind == "hill" else 0.42,
		"h": h,
		"hp": HILL_HP if kind == "hill" else PEAK_HP,
		"cd": 0.0,
		"ice_t": 0.0,
	}
	o.max_hp = o.hp
	o.h0 = h
	o.r0 = r
	if kind == "pond":
		o.hp = 0
		o.top = r
	_build_node(o)
	obstacles.append(o)


func _add_grass(at: Vector3, r: float) -> void:
	var g := {"kind": "grass", "pos": _flat(at), "r": r}
	_build_grass(g)
	grass.append(g)


# --- Altura e movimento ---


## Altura do chão (sem o lago) em `p` (local, plano).
func height_at(p: Vector3) -> float:
	var best := 0.0
	for o in obstacles:
		if o.kind == "pond":
			continue
		best = maxf(best, _height_of(o, p))
	return best


func _height_of(o: Dictionary, p: Vector3) -> float:
	var d := _flat(p - o.pos).length()
	if d >= o.r:
		return 0.0
	if d <= o.top:
		return o.h
	return o.h * (1.0 - (d - o.top) / maxf(o.r - o.top, 0.01))


func obstacle_under(f: BattleFighter) -> Dictionary:
	for o in obstacles:
		if o.kind != "pond" and _flat(f.position - o.pos).length() < o.r and f.ground_y > 0.25:
			return o
	return {}


func pond_at(p: Vector3) -> Dictionary:
	for o in obstacles:
		if o.kind == "pond" and _flat(p - o.pos).length() < o.r:
			return o
	return {}


func in_water(f: BattleFighter) -> bool:
	return not pond_at(f.position).is_empty() and _grounded(f) and f.ground_y < 0.1


## Dentro da água de verdade (lago não congelado).
func wet(f: BattleFighter) -> bool:
	return in_water(f) and float(pond_at(f.position).ice_t) <= 0.0


func grass_at(p: Vector3) -> Dictionary:
	for g in grass:
		if _flat(p - g.pos).length() < g.r:
			return g
	return {}


## Escondido na grama alta: dentro de uma moita, no chão (quem voa ou está no ar aparece).
func in_grass(f: BattleFighter) -> bool:
	if grass.is_empty() or not is_instance_valid(f) or f.motion == "tunnel":
		return false
	return not grass_at(f.position).is_empty() and _grounded(f) and f.ground_y < 0.1


## Tem cenário (relevo ou grama) nesta luta.
func has_scenery() -> bool:
	return not obstacles.is_empty() or not grass.is_empty()


func _grounded(f: BattleFighter) -> bool:
	if arena.get("moves") and arena.moves.effects.has_method("grounded"):
		return arena.moves.effects.grounded(f)
	return f.height() < 0.3 and not "flying" in f.types


## Sobe no pico: Pedra, Terra, Lutador, Voador, Inseto ou Speed alta.
func climber(f: BattleFighter) -> bool:
	for t in f.types:
		if t in CLIMB_TYPES:
			return true
	return float(f.stats.get("spe", 0)) >= CLIMB_SPEED


func swimmer(f: BattleFighter) -> bool:
	return "water" in f.types


## Para o pico não escalável: o lutador vale como sólido nele.
func blocks(f: BattleFighter, o: Dictionary) -> bool:
	return o.kind == "peak" and not climber(f) and f.height() < o.h


func on_high(f: BattleFighter) -> bool:
	return f.ground_y >= HIGH


## Multiplicador do andar pelo relevo (encosta, água, gelo).
func move_mult(f: BattleFighter) -> float:
	var gm := ground.move_mult(f)  # lama e maré (fora do relevo)
	if gm != 1.0:
		return gm
	var pond := pond_at(f.position)
	if not pond.is_empty() and _grounded(f):
		if float(pond.ice_t) > 0.0:
			return ICE_MULT
		return SWIM_MULT if swimmer(f) else WADE_MULT
	for o in obstacles:
		if o.kind == "pond":
			continue
		var d := _flat(f.position - o.pos).length()
		if d > o.top and d < o.r:
			var down := _flat(f.position - o.pos).normalized()
			if f.velocity.dot(down) < -0.1:
				return UPHILL_MULT
	return 1.0


## Energia pelo chão: no lago Água e Grama enchem mais, os outros menos e Fogo bem menos; na grama alta
## quem é de Grama enche mais.
func regen_mult(f: BattleFighter) -> float:
	var gr := ground.regen_mult(f)  # água rasa da maré
	if gr != 1.0:
		return gr
	if wet(f):
		if swimmer(f) or "grass" in f.types:
			return SWIM_REGEN
		return FIRE_WATER_REGEN if "fire" in f.types else WADE_REGEN
	if "grass" in f.types and in_grass(f):
		return GRASS_REGEN
	return 1.0


## Deslocamento que tira o lutador de dentro de um pico que ele não escala.
func push_out(f: BattleFighter) -> Vector3:
	var out := Vector3.ZERO
	for o in obstacles:
		if not blocks(f, o):
			continue
		var d := _flat(f.position - o.pos)
		var lim: float = o.r * 0.8 + BattleField.BODY_R
		if d.length() < lim:
			if d.length() < 0.001:
				d = Vector3(1, 0, 0)
			out += d.normalized() * (lim - d.length())
	return out


## Por quadro, depois de cada lutador andar: puxão/derrubada em curso, chão sob ele, queda e o pico
## sólido.
func settle(f: BattleFighter, dt: float) -> void:
	if f.active():
		ground.settle(f, dt)  # embalo no gelo
	if obstacles.is_empty() or not f.active():
		return
	_slide_step(f, dt)
	f.position += push_out(f)
	if f.motion == "tunnel" or f.hidden != "":
		f.ground_y = 0.0
		return
	var want := height_at(f.position)
	var id := f.get_instance_id()
	if want >= f.ground_y:
		f.ground_y = move_toward(f.ground_y, want, RISE * dt)
		_fall_v.erase(id)
	else:
		var v: float = float(_fall_v.get(id, 0.0)) + FALL_G * dt
		_fall_v[id] = v
		f.ground_y = maxf(f.ground_y - v * dt, want)
	if f.motion == "":
		f.position.y = f.ground_y + f.air_h + f.fly_h


# --- Golpes ---


## Precisão pelo cenário: de cima, golpe à distância ou Voador contra quem está mais baixo acerta mais;
## contra quem está escondido na grama alta (ou camuflado na areia) erra mais.
func acc_mult(user: BattleFighter, mv: Dictionary, target: BattleFighter) -> float:
	if not has_scenery() or not is_instance_valid(target) or not is_instance_valid(user):
		return 1.0
	var kind := String(mv.get("kind", ""))
	var ranged := kind in RANGED_KINDS or String(mv.get("type", "")) == "flying"
	var k := 1.0
	if ranged and on_high(user) and user.ground_y - target.ground_y >= HIGH_DIFF:
		k *= HIGH_ACC
	k *= ground.acc_mult(user, mv, target)  # enlameado, fenda, areia da praia
	if not kind in RANGED_KINDS or float(mv.get("accuracy", 0)) <= 0.0:
		return k
	if in_grass(target) and user.flat_to(target).length() > GRASS_SEE:
		k *= 1.0 - GRASS_EVADE
		_tele("terrain_grass_cover", {"who": _uid(target), "by": _uid(user)})
	elif _weather() == "sand" and target.types.any(func(t): return t in SAND_TYPES):
		k *= 1.0 - SAND_EVADE
		_tele("terrain_sand_cover", {"who": _uid(target), "by": _uid(user)})
	return k


## Dano pelo cenário (BattleMoves.extra_mult): Elétrico em quem está dentro da água bate mais forte.
func damage_mult(user: BattleFighter, target: BattleFighter, mv: Dictionary) -> float:
	var gd := ground.damage_mult(user, target, mv)  # Elétrico na maré
	if gd != 1.0:
		return gd
	if obstacles.is_empty() or not is_instance_valid(target):
		return 1.0
	if String(mv.get("type", "")) == "electric" and wet(target):
		target.popup("Eletrocutado na água!", Dex.type_color("electric"), 0.9, 0.8)
		_tele("terrain_shock_water", {"who": _uid(target), "by": _uid(user)})
		return ELEC_WATER
	return 1.0


func _weather() -> String:
	var mv = arena.get("moves")
	if mv and mv.effects and mv.effects.has_method("weather"):
		return String(mv.effects.weather())
	return ""


## Um golpe chegou em `at` (BattleField.on_move_landed): Terra/Pedra/Lutador tiram vida do relevo,
## raio passa pela água, gelo congela o lago.
func on_move_landed(user: BattleFighter, mv: Dictionary, at: Vector3, radius: float) -> void:
	ground.on_move_landed(user, mv, at, radius)  # lama, fenda, gelo, brasas, poça
	var type := String(mv.get("type", ""))
	var power := float(mv.get("power", 0))
	if power <= 0.0 or not has_scenery():
		return
	if type == "fire":
		for g in grass.duplicate():
			if _flat(at - g.pos).length() <= float(g.r) + radius * 0.5:
				ignite(g, user)
	if obstacles.is_empty():
		return
	if type in BREAKERS:
		for o in obstacles.duplicate():
			if o.kind == "pond" or o.cd > 0.0:
				continue
			if _flat(at - o.pos).length() <= o.r + radius * 0.5:
				o.cd = HIT_CD
				damage(o, 2 if power >= STRONG else 1, user)
	var pond := pond_at(at)
	if pond.is_empty():
		return
	if type == "ice":
		freeze(pond)
	elif type == "electric" and not mv.get("conducted", false) and float(pond.ice_t) <= 0.0:
		_conduct(user, mv, pond, at)
	elif type == "fire":
		_steam(pond, at)


## Tira `n` de vida do morro/pico; em 0 ele desaba.
func damage(o: Dictionary, n: int, user: BattleFighter = null) -> void:
	if not obstacles.has(o):
		return
	o.hp -= n
	if o.hp <= 0:
		collapse(o, user)
		return
	# Cada golpe rebaixa um pouco (até 70% da altura no último ponto de vida).
	var k := 0.7 + 0.3 * float(o.hp) / float(o.max_hp)
	o.h = float(o.h0) * k
	if is_instance_valid(o.node):
		o.node.scale = Vector3(1.0, k, 1.0)
	_crumbs(o, 4)
	if arena.vfx and arena.is_inside_tree():
		PixelFx.pop(arena, "dust", o.pos + Vector3(0, o.h * 0.6, 0), 1.6, 0.4)


## O relevo desaba: quem está em cima cai, toma dano e fica atordoado.
func collapse(o: Dictionary, user: BattleFighter = null) -> void:
	obstacles.erase(o)
	_crumbs(o, 10)
	if is_instance_valid(o.node):
		o.node.queue_free()
	if arena.is_inside_tree():
		PixelFx.pop(arena, "dust", o.pos + Vector3(0, 0.6, 0), o.r * 1.6, 0.6)
		PixelFx.pop(arena, "stone", o.pos + Vector3(0, 0.3, 0), o.r * 1.4, 0.5)
	if arena.field:
		arena.field._add_mark("crater", o.pos, clampf(o.r, 0.8, 2.5), 0)
	preload("res://audio/cue.gd").sfx("hit_super")
	var who := "" if user == null else " (%s)" % user.mon.display_name
	_tele("terrain_collapse", {"kind": o.kind, "by": _uid(user)})
	arena.say("O %s desabou!%s" % ["morro" if o.kind == "hill" else "pico", who])
	for f in arena.fighters:
		if not is_instance_valid(f) or not f.active():
			continue
		if _flat(f.position - o.pos).length() >= o.r or f.ground_y < 0.25:
			continue
		if not _grounded(f):
			f.popup("Saiu voando!", Color(0.8, 0.9, 1.0), 0.9, 0.6)
			continue
		var n := maxi(1, int(float(f.max_hp) * FALL_FRAC * f.dot_scale()))
		f.stun_t = maxf(f.stun_t, FALL_STUN + FALL_STUN_H * f.ground_y)
		f.interrupt_prepare()
		f.popup("-%d Caiu!" % n, Color(1.0, 0.75, 0.45), 1.1, 0.7)
		_tele("terrain_fall", {"who": _uid(f), "dmg": n})
		f.take_damage(n, Vector3.ZERO, 0.0)
		if arena.has_method("cut_in"):
			arena.cut_in("DESABOU!", Color(0.85, 0.65, 0.4))


## Corrente pela água de `pond` ({pos, r}); `inside` diz quem está nela (padrão: dentro do lago).
func _conduct(
	user: BattleFighter, mv: Dictionary, pond: Dictionary, at: Vector3, inside := Callable()
) -> void:
	var m := mv.duplicate()
	m.erase("_cast")
	m["conducted"] = true
	var hit_any := false
	for f in arena.fighters:
		if not is_instance_valid(f) or not f.active() or f == user:
			continue
		if inside.is_valid():
			if not inside.call(f):
				continue
		elif not in_water(f) or _flat(f.position - pond.pos).length() >= pond.r:
			continue
		if _flat(f.position - at).length() < 0.6:
			continue  # o próprio alvo do golpe
		hit_any = true
		f.popup("Choque na água!", Dex.type_color("electric"), 0.9, 0.8)
		_tele("terrain_conduct", {"who": _uid(f), "by": _uid(user)})
		arena.moves.hit(user, f, m, _flat(f.position - at).normalized(), CONDUCT)
	if hit_any and arena.is_inside_tree():
		PixelFx.pop(arena, "electric", pond.pos + Vector3(0, 0.2, 0), pond.r * 1.6, 0.5)


## Congela o lago. O aviso só sai se ele não estava congelado e passou FREEZE_SAY_CD desde o último
## (no granizo o gelo derrete e congela de novo: não enche o log). `quiet` congela sem aviso.
func freeze(pond: Dictionary, quiet := false) -> void:
	var was := float(pond.ice_t) > 0.0
	pond.ice_t = FREEZE_SECS
	if was:
		return
	_set_water_look(pond)
	if quiet or _water_t - float(pond.get("said_t", -1000.0)) < FREEZE_SAY_CD:
		return
	pond.said_t = _water_t
	_tele("terrain_freeze", {})
	arena.say("O lago congelou!")


func _steam(pond: Dictionary, at: Vector3) -> void:
	if float(pond.ice_t) > 0.0:
		pond.ice_t = 0.0  # fogo derrete o gelo
		_set_water_look(pond)
		arena.say("O gelo do lago derreteu!")
	if arena.is_inside_tree():
		PixelFx.pop(arena, "wind", _flat(at) + Vector3(0, 0.5, 0), 1.8, 0.6)


## Fogo na moita: com chuva não pega; senão queima todos dentro (menos Fogo), pode deixar queimado,
## some e vira chão queimado. Com sol queima mais forte e pula para as moitas vizinhas.
func ignite(g: Dictionary, user: BattleFighter = null, spread := false) -> void:
	if not grass.has(g):
		return
	var wx := _weather()
	if wx == "rain":
		if not g.get("wet_said", false):
			g.wet_said = true
			_tele("terrain_grass_wet", {"by": _uid(user)})
			arena.popup(g.pos + Vector3(0, 0.8, 0), "Grama molhada!", Dex.type_color("water"))
		return
	grass.erase(g)
	burnt.append({"pos": g.pos, "r": g.r, "t": 0.0})
	if is_instance_valid(g.get("node")):
		g.node.queue_free()
	var sun := wx == "sun"
	var frac := GRASS_BURN_FRAC * (SUN_BURN_MULT if sun else 1.0)
	_tele("terrain_grass_burn", {"by": _uid(user), "sun": sun, "spread": spread})
	arena.say("A grama alta pegou fogo!")
	if arena.field:
		var side: int = user.side if is_instance_valid(user) else 0
		arena.field._add_mark("scorch", g.pos, clampf(g.r, 0.8, 2.5), side)
	if arena.is_inside_tree():
		PixelFx.pop(arena, "fire", g.pos + Vector3(0, 0.5, 0), g.r * 2.0, 0.6)
	for f in arena.fighters:
		if not is_instance_valid(f) or not f.active() or "fire" in f.types:
			continue
		if _flat(f.position - g.pos).length() >= g.r or not _grounded(f) or f.ground_y > 0.1:
			continue
		var n := maxi(1, int(float(f.max_hp) * frac * f.dot_scale()))
		var burned := false
		if f.status == "" and arena.rng.randf() < GRASS_BURN_STATUS:
			var ab = arena.get("abilities")
			if not (ab and ab.blocks_status(f, "burn")):
				burned = f.apply_status("burn", user)
		f.popup("-%d Grama em chamas!" % n, Dex.type_color("fire"), 1.0, 0.7)
		_tele(
			"terrain_grass_burn_hit", {"who": _uid(f), "by": _uid(user), "dmg": n, "burned": burned}
		)
		f.take_damage(n, Vector3.ZERO, 0.0)
	if not sun:
		return
	for o in grass.duplicate():
		if _flat(o.pos - g.pos).length() <= float(o.r) + float(g.r) + SPREAD_GAP:
			arena.later(SPREAD_DELAY, func() -> void: ignite(o, user, true))


## Depois do acerto com empurrão (`knock` = força efetiva, já com eficácia/crítico/peso): golpe de Água
## perto do lago puxa o alvo para dentro; empurrão forte em quem está no alto o derruba.
func after_hit(
	user: BattleFighter, target: BattleFighter, mv: Dictionary, dir: Vector3, knock: float
) -> void:
	if obstacles.is_empty() or not is_instance_valid(target) or not target.alive():
		return
	if not _grounded(target) or target.motion != "":
		return
	var id := target.get_instance_id()
	if _shove_at.has(id) and _water_t - float(_shove_at[id]) < SHOVE_CD:
		return
	var type := String(mv.get("type", ""))
	var strong_water := String(mv.get("id", "")) in PULL_MOVES or knock >= PULL_KNOCK
	if type == "water" and strong_water and not swimmer(target) and not in_water(target):
		var pond := _pond_near(target.position)
		if not pond.is_empty():
			var away := _flat(target.position - pond.pos)
			if away.length() < 0.01:
				away = Vector3.RIGHT
			_shove_at[id] = _water_t
			_slide(target, pond.pos + away.normalized() * float(pond.r) * 0.5, PULL_SECS)
			target.interrupt_prepare()
			target.popup("Puxado para a água!", Dex.type_color("water"), 1.0, 0.7)
			_tele("terrain_pull", {"who": _uid(target), "by": _uid(user), "move": mv.get("id", "")})
			return
	if knock < DROP_KNOCK:
		return
	var o := obstacle_under(target)
	if o.is_empty() or not on_high(target):
		return
	var off := _flat(target.position - o.pos)
	if o.kind != "peak" and off.length() < float(o.top) * DROP_EDGE:
		return  # no miolo do topo: segura firme
	var d := _flat(dir)
	if d.length() < 0.1:
		d = off if off.length() > 0.01 else Vector3.RIGHT
	d = d.normalized()
	# Onde a reta do empurrão sai do pé do relevo (+ DROP_OUT).
	var big: float = float(o.r) + DROP_OUT
	var b := off.dot(d)
	var t := -b + sqrt(maxf(b * b - (off.length_squared() - big * big), 0.0))
	var to: Vector3 = o.pos + off + d * t
	var inner: Rect2 = arena.rect.grow(-0.6)
	to.x = clampf(to.x, inner.position.x, inner.end.x)
	to.z = clampf(to.z, inner.position.y, inner.end.y)
	if _flat(to - o.pos).length() < float(o.r):
		return  # a parede segura: não tem para onde cair
	var h := target.ground_y
	_shove_at[id] = _water_t
	_slide(target, to, DROP_SECS)
	var n := maxi(1, int(float(target.max_hp) * DROP_FRAC * target.dot_scale()))
	target.stun_t = maxf(target.stun_t, DROP_STUN + DROP_STUN_H * h)
	target.interrupt_prepare()
	target.popup("-%d Derrubado!" % n, Color(1.0, 0.75, 0.45), 1.1, 0.7)
	_tele("terrain_knock_off", {"who": _uid(target), "by": _uid(user), "dmg": n, "kind": o.kind})
	target.take_damage(n, Vector3.ZERO, 0.0)


## Lago (não congelado) a até PULL_RANGE m da beira de `p`.
func _pond_near(p: Vector3) -> Dictionary:
	for o in obstacles:
		if o.kind == "pond" and float(o.ice_t) <= 0.0:
			if _flat(p - o.pos).length() < float(o.r) + PULL_RANGE:
				return o
	return {}


func _slide(f: BattleFighter, to: Vector3, secs: float) -> void:
	f.knock = Vector3.ZERO
	f.impact_knock = Vector3.ZERO
	_slides[f.get_instance_id()] = {
		"from": _flat(f.position), "to": _flat(to), "t": 0.0, "dur": secs
	}


func _slide_step(f: BattleFighter, dt: float) -> void:
	var id := f.get_instance_id()
	if not _slides.has(id):
		return
	var s: Dictionary = _slides[id]
	s.t = float(s.t) + dt
	var k := clampf(float(s.t) / maxf(float(s.dur), 0.01), 0.0, 1.0)
	var p: Vector3 = s.from.lerp(s.to, k)
	f.position.x = p.x
	f.position.z = p.z
	f.knock = Vector3.ZERO
	if k >= 1.0:
		_slides.erase(id)


func sliding(f: BattleFighter) -> bool:
	return is_instance_valid(f) and _slides.has(f.get_instance_id())


## Um projétil parou no relevo ou num objeto em `p`: o objeto/relevo leva o golpe.
func on_shot_blocked(user: BattleFighter, mv: Dictionary, p: Vector3) -> void:
	if arena.field:
		arena.field.on_move_landed(user, mv, _flat(p), 0.3)
	if arena.is_inside_tree():
		PixelFx.pop(arena, "dust", p, 0.9, 0.3)


## Projétil em `p` (local) bateu no relevo? Caixas e pedras do campo também param o tiro.
func blocks_shot(p: Vector3) -> bool:
	if p.y < height_at(p) - 0.05:
		return true
	if arena.field:
		for o in arena.field.objects:
			if _flat(p - o.pos).length() < BattleField.OBJ_R and p.y < 0.9:
				return true
	return false


## Linha de tiro de `a` até `b` (locais) tapada por pico, morro ou caixa/pedra (raios param nela).
## Devolve a distância até o bloqueio ou INF.
func shot_block(a: Vector3, b: Vector3) -> float:
	var from := a + Vector3(0, 0.5, 0)
	var to := b + Vector3(0, 0.5, 0)
	var dist := _flat(to - from).length()
	var n := maxi(2, int(dist / 0.3))
	for i in range(1, n):
		var p := from.lerp(to, float(i) / n)
		if blocks_shot(p):
			return _flat(p - from).length()
	return ground.shot_cover(a, b)  # alvo escondido na fenda


func has_cover() -> bool:
	if not obstacles.is_empty():
		return true
	return arena.field != null and not arena.field.objects.is_empty()


func tick(dt: float) -> void:
	_water_t += dt
	ground.tick(dt)
	var wx := _weather() if has_scenery() or not burnt.is_empty() else ""
	_regrow(dt, wx)
	for o in obstacles:
		o.cd = maxf(float(o.cd) - dt, 0.0)
		if o.kind == "pond":
			_pond_weather(o, wx, dt)
			if float(o.ice_t) > 0.0:
				o.ice_t = float(o.ice_t) - dt
				if o.ice_t <= 0.0:
					o.ice_t = 0.0
					_set_water_look(o)
			elif o.get("mat") is StandardMaterial3D:
				o.mat.uv1_offset = Vector3(_water_t * 0.04, _water_t * 0.025, 0.0)
	for f in arena.fighters:
		if not is_instance_valid(f):
			continue
		if not f.active():
			_fall_v.erase(f.get_instance_id())
			_slides.erase(f.get_instance_id())
			continue
		_fire_in_water(f, dt)


## Grama queimada rebrota: conta REGROW_DELAY s (x REGROW_RAIN na chuva, parada com sol/seca), a moita
## volta pequena e cresce em REGROW_SECS s. Moita brotando já esconde e queima como as outras.
func _regrow(dt: float, wx: String) -> void:
	for b in burnt.duplicate():
		if wx == "sun":
			continue
		b.t = float(b.t) + dt * (REGROW_RAIN if wx == "rain" else 1.0)
		if float(b.t) < REGROW_DELAY:
			continue
		burnt.erase(b)
		_add_grass(b.pos, float(b.r))
		var g: Dictionary = grass[-1]
		g.grow = 0.0
		_tele("terrain_grass_regrow", {})
	for g in grass:
		if not g.has("grow") or float(g.grow) >= 1.0:
			continue
		g.grow = minf(float(g.grow) + dt / REGROW_SECS, 1.0)
		if is_instance_valid(g.get("node")):
			var k := lerpf(REGROW_FROM, 1.0, float(g.grow))
			g.node.scale = Vector3(k, k, k)


## Fogo dentro do lago: FIRE_WATER_DOT do HP por segundo (cobrado de segundo em segundo).
func _fire_in_water(f: BattleFighter, dt: float) -> void:
	var id := f.get_instance_id()
	if not "fire" in f.types or not wet(f):
		_fire_t.erase(id)
		return
	var t: float = float(_fire_t.get(id, 0.0)) + dt
	if t >= 1.0:
		t -= 1.0
		var n := maxi(1, int(float(f.max_hp) * FIRE_WATER_DOT * f.dot_scale()))
		n = f.residual_damage(n, "água", Dex.type_color("water"))
		if n > 0:
			_tele("terrain_fire_water", {"who": _uid(f), "dmg": n})
	_fire_t[id] = t


## Clima no lago: chuva enche, sol seca (o raio anda POND_GROW m/s até o alvo), granizo/neve congela.
func _pond_weather(o: Dictionary, wx: String, dt: float) -> void:
	if wx == "hail":
		if float(o.ice_t) <= 0.0:
			# Congela de novo sem aviso: só a mudança (sem granizo -> granizo) vai para o log.
			freeze(o, bool(o.get("hail_ice", false)))
			o.hail_ice = true
	else:
		o.hail_ice = false
	var want: float = (
		float(o.r0) * (RAIN_POND if wx == "rain" else (SUN_POND if wx == "sun" else 1.0))
	)
	if is_equal_approx(float(o.r), want):
		return
	if String(o.get("wx", "")) != wx and wx in ["rain", "sun"]:
		_tele("terrain_pond_" + ("grow" if wx == "rain" else "shrink"), {})
	o.wx = wx
	o.r = move_toward(float(o.r), want, POND_GROW * dt)
	o.top = o.r
	if is_instance_valid(o.get("node")):
		var k: float = float(o.r) / float(o.r0)
		o.node.scale = Vector3(k, 1.0, k)


# --- IA ---


## Ponto no alto para atirar: o topo de morro/pico mais perto (que o lutador alcança) de onde o alvo
## fica ao alcance `reach`. INF se não há (ou já está lá).
func high_spot(f: BattleFighter, target: BattleFighter, reach: float) -> Vector3:
	if not is_instance_valid(target):
		return Vector3.INF
	var best := Vector3.INF
	var best_d := 7.0
	for o in obstacles:
		if o.kind == "pond" or blocks(f, o) or o.hp <= 1:
			continue
		if _flat(target.position - o.pos).length() > reach * 0.9:
			continue
		if _flat(target.position - o.pos).length() < o.r + 0.8:
			continue  # o alvo está em cima / colado nele
		var d := _flat(f.position - o.pos).length()
		if d < best_d:
			best_d = d
			best = o.pos
	return best


## Esconderijo: ponto atrás de um pico/caixa/pedra (do lado oposto a `from`), perto do lutador.
func cover_spot(f: BattleFighter, from: Vector3, max_d := 7.0) -> Vector3:
	var cands: Array = []
	for o in obstacles:
		if o.kind == "peak" or (o.kind == "hill" and blocks(f, o)):
			cands.append({"pos": o.pos, "r": o.r * 0.8})
	if arena.field:
		for o in arena.field.objects:
			cands.append({"pos": o.pos, "r": BattleField.OBJ_R})
	var best := Vector3.INF
	var best_d := max_d
	for c in cands:
		var away := _flat(c.pos - from)
		if away.length() < 0.5:
			continue
		var spot: Vector3 = c.pos + away.normalized() * (float(c.r) + 0.9)
		if not arena.rect.grow(-0.8).has_point(Vector2(spot.x, spot.z)):
			continue
		var d := _flat(spot - f.position).length()
		if d < best_d:
			best_d = d
			best = spot
	return best


## Desvia a direção desejada da IA de picos que ela não escala e (quem não é de Água) do lago.
func steer(f: BattleFighter, want: Vector3) -> Vector3:
	want = ground.steer(f, want)  # contorna a lama e as brasas
	if obstacles.is_empty() or want.length() < 0.05:
		return want
	var dir := want.normalized()
	var out := want
	for o in obstacles:
		var avoid := blocks(f, o)
		if o.kind == "pond":
			avoid = (
				not swimmer(f)
				and float(o.ice_t) <= 0.0
				and _grounded(f)
				and pond_at(f.position).is_empty()
			)
		if not avoid:
			continue
		var to := _flat(o.pos - f.position)
		var ahead := to.dot(dir)
		if ahead <= 0.0 or ahead > o.r + 1.6:
			continue
		var side := to - dir * ahead
		var clear: float = o.r * (0.8 if o.kind == "peak" else 1.0) + 0.5
		if side.length() >= clear:
			continue
		var tangent := Vector3(-dir.z, 0.0, dir.x)
		if side.dot(tangent) > 0.0:
			tangent = -tangent
		out += tangent * (1.0 - side.length() / clear) * 1.4 * want.length()
	return out.normalized() * want.length() if out.length() > 0.001 else want


## O alvo está em cima de morro/pico (golpe de Terra/Pedra/Lutador derruba).
func topple_target(target: BattleFighter) -> bool:
	return is_instance_valid(target) and not obstacle_under(target).is_empty() and _grounded(target)


# --- Visual ---


func _build_node(o: Dictionary) -> void:
	var root := Node3D.new()
	root.name = "Terrain_%s" % o.kind
	root.position = o.pos
	match String(o.kind):
		"hill":
			root.add_child(_frustum(o.r, o.top, o.h, tex("earth"), 10, 1.0))
			var cap := _disc(o.top + 0.02, tex("grass"), 1.2)
			cap.position.y = o.h + 0.01
			root.add_child(cap)
			for i in 5:
				var a := TAU * i / 5.0 + 0.4
				var tuft := _box(Vector3(0.18, 0.12, 0.18), tex("grass"))
				tuft.position = Vector3(cos(a), 0, sin(a)) * o.top * 0.7 + Vector3(0, o.h + 0.06, 0)
				root.add_child(tuft)
		"peak":
			root.add_child(_frustum(o.r, o.top, o.h, tex("stone"), 7, 0.9))
			var cap := _frustum(o.top + 0.05, o.top * 0.6, 0.18, tex("stone_light"), 7, 1.5)
			cap.position.y = o.h - 0.02
			root.add_child(cap)
			for i in 3:
				var a := TAU * i / 3.0 + 1.1
				var b := _rock_mesh(0.35, tex("stone"))
				b.position = Vector3(cos(a), 0, sin(a)) * o.r * 0.9 + Vector3(0, 0.15, 0)
				root.add_child(b)
		"pond":
			var sand := _disc(o.r + 0.3, tex("sand"), 1.2)
			sand.position.y = 0.012
			root.add_child(sand)
			var water := _disc(o.r, tex("water"), 0.9)
			water.position.y = 0.03
			var mat: StandardMaterial3D = water.material_override
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color = Color(1, 1, 1, 0.9)
			o.mat = mat
			o.water = water
			root.add_child(water)
	o.node = root
	arena.add_child(root)


## Moita de grama alta: chão de grama escura e tufos de lâminas (quadros cruzados com transparência).
func _build_grass(g: Dictionary) -> void:
	var root := Node3D.new()
	root.name = "Terrain_grass"
	root.position = g.pos
	var floor_ := _disc(g.r, tex("grass_dark"), 1.4)
	floor_.position.y = 0.014
	root.add_child(floor_)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(int(g.pos.x * 100.0), int(g.pos.z * 100.0)))
	var mat := _blades_mat()
	var n := int(6 + g.r * 6.0)
	for i in n:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * float(g.r) * 0.85
		var h := GRASS_H * rng.randf_range(0.75, 1.15)
		var tuft := Node3D.new()
		tuft.position = Vector3(cos(a) * d, h * 0.5, sin(a) * d)
		tuft.rotation.y = rng.randf() * PI
		for k in 2:
			var q := MeshInstance3D.new()
			var qm := QuadMesh.new()
			qm.size = Vector2(h * 0.9, h)
			q.mesh = qm
			q.material_override = mat
			q.rotation.y = PI * 0.5 * k
			q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			tuft.add_child(q)
		root.add_child(tuft)
	g.node = root
	arena.add_child(root)


static func _blades_mat() -> StandardMaterial3D:
	if _tex.has("_blades_mat"):
		return _tex["_blades_mat"]
	var m := StandardMaterial3D.new()
	m.albedo_texture = blades_tex()
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 1.0
	_tex["_blades_mat"] = m
	return m


## Lâminas de grama em pixel art (32 x 32, fundo transparente): traços verdes do chão para cima,
## inclinados, mais claros na ponta.
static func blades_tex() -> Texture2D:
	if _tex.has("_blades"):
		return _tex["_blades"]
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var pal: Array = _palette("grass")
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("blades")
	for i in 11:
		var x0 := 2.0 + i * 2.7 + rng.randf_range(-0.8, 0.8)
		var tall := rng.randi_range(16, 31)
		var lean := rng.randf_range(-0.25, 0.25)
		for y in tall:
			var x := int(round(x0 + lean * y))
			if x < 0 or x > 31:
				break
			var c: int = (
				0 if y < tall * 0.3 else (1 if y < tall * 0.65 else (2 if y < tall - 2 else 3))
			)
			img.set_pixel(x, 31 - y, pal[c])
			if y < tall * 0.5 and x + 1 <= 31:
				img.set_pixel(x + 1, 31 - y, pal[maxi(c - 1, 0)])
	var t := ImageTexture.create_from_image(img)
	_tex["_blades"] = t
	return t


func _set_water_look(pond: Dictionary) -> void:
	if not (pond.get("mat") is StandardMaterial3D):
		return
	pond.mat.albedo_texture = tex("ice" if float(pond.ice_t) > 0.0 else "water")


static func _mat(t: Texture2D, scale: float, triplanar := true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = t
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.roughness = 1.0
	if triplanar:
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE * scale
	return m


func _frustum(
	r: float, top: float, h: float, t: Texture2D, segs: int, scale: float
) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.bottom_radius = r
	cm.top_radius = top
	cm.height = h
	cm.radial_segments = segs
	cm.rings = 1
	mi.mesh = cm
	mi.position.y = h * 0.5
	mi.material_override = _mat(t, scale)
	return mi


func _disc(r: float, t: Texture2D, scale: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.bottom_radius = r
	cm.top_radius = r
	cm.height = 0.02
	cm.radial_segments = 20
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = _mat(t, scale)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _box(sz: Vector3, t: Texture2D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = sz
	mi.mesh = b
	mi.material_override = _mat(t, 1.0)
	return mi


## Pedra low-poly (esfera achatada de poucos lados).
static func _rock_mesh(r: float, t: Texture2D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 1.4
	s.radial_segments = 7
	s.rings = 3
	mi.mesh = s
	mi.material_override = _mat(t, 1.6)
	return mi


func _crumbs(o: Dictionary, n: int) -> void:
	if not arena.field or not arena.is_inside_tree():
		return
	var t := tex("stone" if o.kind == "peak" else "earth")
	for i in n:
		var mi := _box(Vector3.ONE * arena.rng.randf_range(0.12, 0.22), t)
		mi.position = o.pos + Vector3(0, o.h * 0.7, 0)
		arena.add_child(mi)
		var v := Vector3(
			arena.rng.randf_range(-2.5, 2.5),
			arena.rng.randf_range(2, 4.5),
			arena.rng.randf_range(-2.5, 2.5)
		)
		arena.field.shards.append({"node": mi, "vel": v, "t": 0.8})


# --- Texturas de pixel art (32 x 32, geradas uma vez; caixa e pedra com a paleta da arte delas) ---


static func tex(kind: String) -> Texture2D:
	if _tex.has(kind):
		return _tex[kind]
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind)
	var pal: Array = _palette(kind)
	for y in 32:
		for x in 32:
			img.set_pixel(x, y, pal[_shade(kind, x, y, rng)])
	var t := ImageTexture.create_from_image(img)
	_tex[kind] = t
	return t


## Paleta (escura -> clara). Caixa e pedra saem das artes objects/crate.png e rock.png quando existem.
static func _palette(kind: String) -> Array:
	match kind:
		"grass":
			return [Color("2f6b2a"), Color("3f8a34"), Color("58a843"), Color("7cc25a")]
		"grass_dark":
			return [Color("1f4a1f"), Color("2a5e27"), Color("357330"), Color("4f8f3e")]
		"earth":
			return [Color("4f3220"), Color("6b452b"), Color("87603b"), Color("a27a4e")]
		"water":
			return [Color("1f4f9a"), Color("2d6bc2"), Color("4a8fe0"), Color("a8d4ff")]
		"ice":
			return [Color("8cc4e8"), Color("b4dcf4"), Color("d6eefa"), Color("ffffff")]
		"sand":
			return [Color("b49563"), Color("c8aa74"), Color("dcc28c"), Color("eedaa6")]
		"crate":
			return _art_palette(
				"objects/crate.png",
				[Color("5a3a1e"), Color("7a5230"), Color("9a6c40"), Color("c09060")]
			)
		"stone":
			return _art_palette(
				"objects/rock.png",
				[Color("4a4a50"), Color("66666e"), Color("85858c"), Color("a6a6ac")]
			)
		"stone_light":
			var p := _palette("stone")
			return [p[1], p[2], p[3], p[3].lightened(0.2)]
	return [Color.BLACK, Color.DIM_GRAY, Color.GRAY, Color.WHITE]


static func _art_palette(file: String, fallback: Array) -> Array:
	var path := PixelFx.DIR + file
	if not ResourceLoader.exists(path):
		return fallback
	var t = load(path)
	if not (t is Texture2D):
		return fallback
	var img: Image = (t as Texture2D).get_image()
	if img == null:
		return fallback
	if img.is_compressed():
		img.decompress()
	var cols: Array = []
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.9:
				cols.append(c)
	if cols.size() < 8:
		return fallback
	cols.sort_custom(func(a: Color, b: Color) -> bool: return a.get_luminance() < b.get_luminance())
	# Quatro tons pelos quantis (sem os extremos: contorno preto e brilho).
	var out: Array = []
	for q in [0.15, 0.4, 0.65, 0.88]:
		out.append(cols[int(q * (cols.size() - 1))])
	return out


static func _shade(kind: String, x: int, y: int, rng: RandomNumberGenerator) -> int:
	var n := rng.randf()
	match kind:
		"grass", "grass_dark":
			if n < 0.08:
				return 3
			if (x * 7 + y * 3) % 11 == 0:
				return 0
			return 1 if n < 0.55 else 2
		"earth":
			var band := (y / 5) % 3
			if n < 0.06:
				return 3
			if y % 5 == 0 and n < 0.6:
				return 0
			return clampi(band, 1, 2) if n < 0.85 else 0
		"stone", "stone_light":
			if (x + y * 2) % 13 == 0 and n < 0.7:
				return 0
			if n < 0.1:
				return 3
			return 1 if n < 0.5 else 2
		"crate":
			if x < 2 or x > 29 or y < 2 or y > 29:
				return 0
			if abs(x - y) < 2 or abs(x + y - 31) < 2:
				return 1
			if y % 8 == 0:
				return 0
			if (x == 4 or x == 27) and y % 8 == 4:
				return 3
			return 2 if n < 0.8 else 1
		"water", "ice":
			if int(x + sin(y * 0.6) * 3.0) % 9 == 0 and n < 0.8:
				return 3
			return 1 if n < 0.5 else (2 if n < 0.85 else 0)
		"sand":
			return 2 if n < 0.6 else (1 if n < 0.9 else 3)
	return 1


## Caixa e pedra do campo (BattleField) como objetos 3D com textura.
static func crate_node() -> Node3D:
	var mi := _box(Vector3(0.85, 0.85, 0.85), tex("crate"))
	mi.material_override.uv1_triplanar = false
	var root := Node3D.new()
	mi.position.y = 0.425
	root.add_child(mi)
	return root


static func rock_node() -> Node3D:
	var root := Node3D.new()
	var a := _rock_mesh(0.55, tex("stone"))
	a.position.y = 0.3
	a.rotation.y = 0.4
	root.add_child(a)
	var b := _rock_mesh(0.28, tex("stone_light"))
	b.position = Vector3(0.35, 0.18, 0.25)
	root.add_child(b)
	return root

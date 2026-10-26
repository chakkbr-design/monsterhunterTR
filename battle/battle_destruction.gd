class_name BattleDestruction
extends RefCounted
## Obstáculos destrutíveis (só no modo de energia; o VGC não muda). O BattleTerrain cria um
## (terrain.destruction); o BattlePhysics chama crash_target/impact quando um lutador arremessado bate
## em algo, e todo caminho que tira um obstáculo do jogo passa por broken() (que dispara o sinal
## BattleTerrain.obstacles_changed).
##
## Impacto (pontos) de um lutador arremessado contra um obstáculo:
##
##   impacto = IMPACT_K x (poder / POWER_REF) x (velocidade / SPEED_REF) x sqrt(peso / WEIGHT_REF)
##
## - poder: o poder base do golpe que arremessou (sem poder, como Whirlwind/Roar: PUSH_POWER);
## - velocidade: m/s do arremesso no momento da batida (BattleFighter.launch_v x o que falta);
## - peso: kg do lutador arremessado (BattlePhysics.weight_of: Autotomize, Heavy/Light Metal).
##
## Exemplos: Snorlax (460 kg) com Double-Edge (120) bate a ~6,7 m/s: ~42 pontos (quebra tudo);
## um lutador de 40 kg com Whirlwind a ~12 m/s: ~11; Rattata (3,5 kg) com golpe de 40 a ~5 m/s: ~0,9.
##
## Cada obstáculo tem uma resistência (TOUGH). Impacto >= resistência: destruído. Impacto >= CHIP_MIN x
## resistência: lascado (acumula CHIP_K x impacto em o.wear; quebra quando o desgaste chega na
## resistência). Abaixo disso só poeira. Morro e pico perdem um degrau (1 de vida, BattleTerrain.damage)
## por batida forte, nunca mais; o montinho baixo (altura < BattleTerrain.HIGH) desaba de uma vez.
## Reações próprias: a árvore é derrubada na direção do arremesso (vira tronco, como o golpe forte),
## o Voltorb acorda (e explode), o pedregulho rola (BOULDER_ROLL) ou se despedaça (resistência).
## O dano no lutador que bateu continua o de sempre (BattlePhysics._crash, CRASH_FRAC).
##
## Apoio: o que está em cima de um obstáculo destruído cai e quebra (ligação explícita no dicionário,
## "hill", "on" ou "parent" = o apoio; ou pela pegada: y > 0 dentro do topo do apoio). Quem está em cima
## do morro/pico cai como antes (BattleTerrain.collapse: 1/8 do HP e atordoado).
##
## Visual (nunca com fast_sim, nunca com arena.rng): pedaços de voxel voando com gravidade, quicando e
## sumindo, poeira, tremida curta da câmera e um monte baixo de entulho em voxel que fica no chão
## (ArenaDebris).

const POWER_REF := 80.0
const SPEED_REF := 8.0
const WEIGHT_REF := 40.0
const IMPACT_K := 10.0
const PUSH_POWER := 60.0  ## arremesso sem poder (Whirlwind, Roar): vale como este poder
const CHIP_MIN := 0.35
const CHIP_K := 0.5
## Resistência (pontos de impacto) por tipo. "pebble" = pedrinha do BattleGroundExtras; "rock"/"crate"
## = do BattleField; "hill"/"peak" = por degrau (1 de vida).
const TOUGH := {
	"bush": 2.0,
	"snow": 2.0,
	"voltorb": 2.0,
	"crate": 4.0,
	"pebble": 4.0,
	"hive": 4.0,
	"mound": 5.0,
	"rock": 7.0,
	"stone": 7.0,
	"crystal": 9.0,
	"hill": 10.0,
	"tree": 12.0,
	"boulder": 12.0,
	"peak": 12.0,
	"pillar": 16.0,
	"pylon": 16.0,
}
const BOULDER_ROLL := 5.0  ## impacto que faz o pedregulho rolar (sem quebrar)
const TREE_SNAP := 0.15  ## árvore quebrada pelo impacto: cai depois disso (s)
const SIDE_STEP := 0.3  ## a encosta à frente do corpo sobe mais que isso: bateu no morro/pico
const BODY_R := 0.4
const FALL_BREAK := 0.3  ## o que cai de pelo menos isso (m) quebra
## Material dos pedaços (ArenaDebris) por tipo.
const MAT := {
	"tree": "tree",
	"log": "wood",
	"bush": "bush",
	"crate": "crate",
	"rock": "stone",
	"stone": "stone",
	"boulder": "stone",
	"pebble": "stone",
	"crystal": "crystal",
	"voltorb": "metal",
	"hive": "wood",
	"pillar": "stone",
	"mound": "snow",
	"snow": "snow",
	"pylon": "metal",
	"hill": "earth",
	"peak": "stone",
}
## Pegada [raio, altura] dos que não guardam a deles.
const SIZE := {
	"tree": [0.5, 2.6],
	"bush": [0.5, 0.7],
	"crate": [0.5, 0.8],
	"rock": [0.5, 0.7],
	"stone": [0.32, 0.6],
	"boulder": [0.5, 1.0],
	"crystal": [0.45, 1.4],
	"voltorb": [0.42, 0.8],
	"hive": [0.4, 1.0],
	"pylon": [0.3, 2.4],
	"pebble": [0.35, 0.6],
	"snow": [0.4, 0.55],
}
const WORDS := {
	"tree": "Hit the tree!",
	"bush": "Hit the bush!",
	"crystal": "Hit the crystal!",
	"voltorb": "Hit the Voltorb!",
	"hive": "Hit the hive!",
	"boulder": "Hit the boulder!",
	"stone": "Hit the stone!",
	"pillar": "Hit the column!",
	"mound": "Hit the mound!",
	"pylon": "Hit the pylon!",
	"pebble": "Hit the rock!",
	"hill": "Hit the hill!",
	"peak": "Hit the peak!",
}

var terrain  ## BattleTerrain
var arena: Node


func _init(t) -> void:
	terrain = t
	arena = t.arena


## Destruição ligada: modo de energia (opts.destruction: false desliga).
func on() -> bool:
	if not bool(arena.opts.get("destruction", true)):
		return false
	return arena.has_method("energy_on") and arena.energy_on()


func _vis() -> bool:
	return arena.is_inside_tree() and not bool(arena.opts.get("fast_sim", false))


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


## Texto do aviso da batida para os tipos novos (BattlePhysics._crash).
static func crash_word(what: String) -> String:
	return String(WORDS.get(what, "Crash!"))


## Pontos de impacto (fórmula no topo do arquivo).
static func impact_of(power: float, speed: float, kg: float) -> float:
	var p := power if power > 0.0 else PUSH_POWER
	return (
		IMPACT_K
		* (p / POWER_REF)
		* (maxf(speed, 0.0) / SPEED_REF)
		* sqrt(maxf(kg, 0.1) / WEIGHT_REF)
	)


# --- Onde está cada obstáculo ---


func _extras():
	return terrain.ground.extras if terrain.ground else null


## Lista de onde `o` vem: "relief", "field", "props", "biome", "pylon", "pebble", "snow" ou "".
func source_of(o: Dictionary) -> String:
	if terrain.obstacles.has(o) and String(o.get("kind", "")) != "pond":
		return "relief"
	if arena.field and arena.field.objects.has(o):
		return "field"
	if terrain.props and terrain.props.items.has(o):
		return "props"
	if terrain.biomes and terrain.biomes.solids.has(o):
		return "biome"
	var ex = _extras()
	if ex:
		if ex.pylons.has(o):
			return "pylon"
		if ex.rocks.has(o):
			return "pebble"
		if ex.snow.has(o):
			return "snow"
	return ""


func kind_of(o: Dictionary, src: String) -> String:
	match src:
		"field":
			return "rock" if bool(o.get("rock", false)) else "crate"
		"pylon", "pebble", "snow":
			return src
	return String(o.get("kind", ""))


## Todos os obstáculos (menos o relevo): [dicionário, lista].
func _all() -> Array:
	var out: Array = []
	if terrain.props:
		for o in terrain.props.items:
			out.append([o, "props"])
	if arena.field:
		for o in arena.field.objects:
			out.append([o, "field"])
	if terrain.biomes:
		for o in terrain.biomes.solids:
			out.append([o, "biome"])
	var ex = _extras()
	if ex:
		for o in ex.pylons:
			out.append([o, "pylon"])
		for o in ex.rocks:
			out.append([o, "pebble"])
		for o in ex.snow:
			out.append([o, "snow"])
	return out


## [raio, altura] de `o`.
func _size_of(o: Dictionary, kind: String) -> Vector2:
	if kind in ["hill", "peak", "pillar", "mound"]:
		return Vector2(float(o.get("r", 0.5)), float(o.get("h", 1.0)))
	var s: Array = SIZE.get(kind, [0.5, 0.8])
	return Vector2(float(s[0]), float(s[1]))


func toughness(kind: String) -> float:
	return float(TOUGH.get(kind, 6.0))


# --- Batida do arremesso ---


## Obstáculo do cenário que o lutador arremessado acerta indo para `next` (local): {what, o} ou {}.
## Caixas/pedras do BattleField e a cerca ficam no BattlePhysics.crash_check, como antes.
func crash_target(f: BattleFighter, next: Vector3) -> Dictionary:
	if not on() or not is_instance_valid(f):
		return {}
	var base: float = f.ground_y + f.height()
	for e in _all():
		var o: Dictionary = e[0]
		var src: String = e[1]
		if src == "field" or bool(o.get("_gone", false)):
			continue
		var kind := kind_of(o, src)
		var lim := -1.0
		var top := 0.0
		var y := float(o.get("y", 0.0))
		match src:
			"props":
				if not BattleProps.SOLID_R.has(kind):
					continue
				if kind == "boulder" and String(o.get("state", "")) != "":
					continue  # rolando
				lim = float(BattleProps.SOLID_R[kind]) + BODY_R
				top = y + float(BattleProps.COVER_H.get(kind, 0.9))
			"biome":
				lim = float(o.r) + BODY_R
				top = float(o.h)
			"pylon":
				lim = BattleGroundExtras.PYLON_BODY + BODY_R
				top = BattleGroundExtras.PYLON_H
			"pebble":
				if _extras().buried:
					continue
				lim = BattleGroundExtras.ROCK_R + BODY_R
				top = BattleGroundExtras.ROCK_H
			_:
				continue
		if base > top or base < y - 0.5:
			continue
		var dn := _flat(next - o.pos).length()
		if dn < lim and dn < _flat(f.position - o.pos).length() - 0.001:
			return {"what": kind, "o": o}
	# Morro/pico: pico sólido para quem não escala; para os outros, a encosta que sobe mais de SIDE_STEP
	# logo à frente do corpo (bateu de lado, em vez de subir).
	var fwd := _flat(f.launch_v)
	var ahead := next + (fwd.normalized() * BODY_R if fwd.length() > 0.01 else Vector3.ZERO)
	for o in terrain.obstacles:
		if o.kind == "pond":
			continue
		var dn := _flat(next - o.pos).length()
		if dn >= _flat(f.position - o.pos).length() - 0.001:
			continue
		if terrain.blocks(f, o) and dn < float(o.r) * 0.8 + BODY_R:
			return {"what": String(o.kind), "o": o}
		if dn < float(o.r) + BODY_R and terrain._height_of(o, ahead) - f.ground_y > SIDE_STEP:
			return {"what": String(o.kind), "o": o}
	return {}


## Lutador `f` arremessado bateu em `o` (`what` = tipo) a `speed` m/s na direção `dir`. `info` =
## {power, by} do arremesso (BattlePhysics.launch).
func impact(
	f: BattleFighter, what: String, o, speed: float, dir: Vector3, info: Dictionary
) -> float:
	if not on() or not (o is Dictionary) or bool(o.get("_gone", false)):
		return 0.0
	var by: BattleFighter = info.get("by") if is_instance_valid(info.get("by")) else null
	var imp := impact_of(float(info.get("power", 0.0)), speed, BattlePhysics.weight_of(f))
	terrain._tele(
		"obstacle_impact",
		{
			"kind": what,
			"who": terrain._uid(f),
			"by": terrain._uid(by),
			"imp": snappedf(imp, 0.1),
			"tough": toughness(what)
		}
	)
	hit(o, imp, by, _flat(dir).normalized(), f)
	return imp


## Aplica `imp` pontos de impacto em `o` (de qualquer lista). `f` = o corpo que bateu (pedregulho rola
## para longe dele).
func hit(
	o: Dictionary, imp: float, by: BattleFighter = null, dir := Vector3.ZERO, f = null
) -> void:
	var src := source_of(o)
	if src == "":
		return
	var kind := kind_of(o, src)
	var tough := toughness(kind)
	match kind:
		"hill", "peak":
			_hit_relief(o, imp, tough, by)
			return
		"voltorb":
			_fx_chip(o, kind, dir)
			if String(o.get("state", "")) == "" and imp >= tough:
				terrain.props._wake(o, by)
			return
		"boulder":
			if imp >= tough:
				destroy(o, by, dir, "impact")
			elif imp >= BOULDER_ROLL and String(o.get("state", "")) == "":
				_fx_chip(o, kind, dir)
				terrain.props._push_boulder(o, f if is_instance_valid(f) else by, {"id": "impact"})
				o.by = by
			else:
				_fx_chip(o, kind, dir)
			return
		"tree":
			if not _wear(o, imp, tough):
				_fx_chip(o, kind, dir)
				return
			if String(o.get("state", "")) in ["", "burn"]:
				_fx_chip(o, kind, dir, 2.0)
				if dir.length() > 0.1:
					o.fall_dir = dir
				terrain.props._tip_tree(o, by, TREE_SNAP, "impact")
			return
	if _wear(o, imp, tough):
		destroy(o, by, dir, "impact")
	else:
		_fx_chip(o, kind, dir)


## Quebra com este impacto? Abaixo da resistência acumula o desgaste (lascas).
func _wear(o: Dictionary, imp: float, tough: float) -> bool:
	if imp >= tough:
		return true
	if imp < tough * CHIP_MIN:
		return false
	o["wear"] = float(o.get("wear", 0.0)) + imp * CHIP_K
	return float(o.wear) >= tough


## Morro/pico: um degrau por batida forte (o montinho baixo desaba de uma vez).
func _hit_relief(o: Dictionary, imp: float, tough: float, by: BattleFighter) -> void:
	if not terrain.obstacles.has(o):
		return
	var tier := imp >= tough
	if not tier and imp >= tough * CHIP_MIN:
		o["wear"] = float(o.get("wear", 0.0)) + imp * CHIP_K
		if float(o.wear) >= tough:
			o.wear = float(o.wear) - tough
			tier = true
	if not tier:
		_fx_chip(o, String(o.kind), Vector3.ZERO)
		return
	if imp >= tough and float(o.get("h0", o.h)) < BattleTerrain.HIGH:
		terrain.collapse(o, by)
		return
	o.cd = BattleTerrain.HIT_CD
	_fx_chip(o, String(o.kind), Vector3.ZERO, 3.0)
	if _vis():
		ArenaDebris.shake(arena, 0.12, 0.25)
	terrain.damage(o, 1, by)


# --- Destruir ---


## Tira `o` do jogo (qualquer lista) com o efeito de quebra; o que está em cima cai. false se `o` não
## é um obstáculo (ou já foi). É o BattleTerrain.remove_obstacle.
func destroy(o: Dictionary, by: BattleFighter = null, dir := Vector3.ZERO, cause := "") -> bool:
	if bool(o.get("_gone", false)):
		return false
	var src := source_of(o)
	if src == "":
		return false
	var kind := kind_of(o, src)
	match src:
		"relief":
			terrain.collapse(o, by)  # chama broken()
			return true
		"field":
			arena.field._break(o, dir)  # chama broken()
			return true
	o["_gone"] = true
	match src:
		"props":
			if kind == "hive" and float(o.get("rest_t", 0.0)) <= 0.0:
				terrain.props._release_swarm(o, by)
			terrain.props._remove(o)
		"biome":
			terrain.biomes.solids.erase(o)
			if is_instance_valid(o.get("node")):
				o.node.queue_free()
		"pylon":
			_extras().pylons.erase(o)
			if is_instance_valid(o.get("node")):
				o.node.queue_free()
		"pebble":
			_extras()._drop(_extras().rocks, o)
		"snow":
			_extras()._drop(_extras().snow, o)
	broken(o, kind, by, dir, cause)
	return true


## Um obstáculo acabou de sair do jogo (já fora da lista dele): avisa (obstacles_changed), telemetria
## e, no modo de energia, efeito de quebra, entulho e o que estava em cima cai.
func broken(
	o: Dictionary, kind: String, by: BattleFighter = null, dir := Vector3.ZERO, cause := ""
) -> void:
	o["_gone"] = true
	terrain.notify_obstacles(kind, _flat(o.get("pos", Vector3.ZERO)))
	if not on():
		return
	terrain._tele("obstacle_break", {"kind": kind, "by": terrain._uid(by), "cause": cause})
	_fx_break(o, kind, dir)
	_fall_on_top(o, kind, by)


## O que estava em cima de `o` cai: de FALL_BREAK m ou mais quebra (em cascata), senão só desce.
func _fall_on_top(o: Dictionary, kind: String, by: BattleFighter) -> void:
	var sz := _size_of(o, kind)
	var top_r := sz.x + 0.3
	var top_h := sz.y
	if kind in ["crate", "rock"]:
		top_r = BattleField.OBJ_R + 0.2
	for e in _all():
		var d: Dictionary = e[0]
		if is_same(d, o) or bool(d.get("_gone", false)):
			continue
		if String(d.get("kind", "")) == "boulder" and String(d.get("state", "")) != "":
			continue  # rolando: já saiu de cima
		var linked := (
			is_same(d.get("hill"), o) or is_same(d.get("on"), o) or is_same(d.get("parent"), o)
		)
		var y := float(d.get("y", 0.0))
		var over := y > 0.05 and _flat(d.pos - o.pos).length() <= top_r and y >= top_h * 0.5 - 0.05
		if not linked and not over:
			continue
		for k in ["hill", "on", "parent"]:
			if is_same(d.get(k), o):
				d.erase(k)
		if y >= FALL_BREAK or linked:
			destroy(d, by, Vector3.ZERO, "fall")
		else:
			d["y"] = 0.0
			if is_instance_valid(d.get("node")):
				d.node.position.y -= y


# --- Visual (nunca com fast_sim) ---


func _fx_break(o: Dictionary, kind: String, dir: Vector3) -> void:
	if not _vis():
		return
	var sz := _size_of(o, kind)
	var mat := String(MAT.get(kind, "stone"))
	var base: Vector3 = _flat(o.pos) + Vector3(0, float(o.get("y", 0.0)), 0)
	ArenaDebris.burst(
		arena, base, sz.y, sz.x, mat, terrain.scenario, dir, Callable(terrain, "height_at")
	)
	PixelFx.pop(arena, "dust", base + Vector3(0, minf(sz.y, 1.2) * 0.4, 0), sz.x * 2.6 + 0.9, 0.55)
	if mat in ["stone", "earth", "crate"]:
		PixelFx.pop(arena, "stone", base + Vector3(0, 0.3, 0), sz.x * 1.8 + 0.6, 0.4)
	if terrain.lattice and not kind in ["snow", "pebble"]:
		var floor_y: float = terrain.height_at(o.pos) if kind != "hill" and kind != "peak" else 0.0
		ArenaDebris.rubble(arena, Vector3(o.pos.x, floor_y, o.pos.z), sz.x, mat, terrain.scenario)
	ArenaDebris.shake(arena, clampf(0.04 + sz.x * sz.y * 0.05, 0.05, 0.3), 0.3)
	if not kind in ["hill", "peak"]:  # o desabamento já toca o dele
		preload("res://audio/cue.gd").sfx("hit_super")


## Lasca: poucos pedaços e poeira (o objeto fica).
func _fx_chip(o: Dictionary, kind: String, dir: Vector3, k := 1.0) -> void:
	if not _vis():
		return
	var sz := _size_of(o, kind)
	var mat := String(MAT.get(kind, "stone"))
	var base: Vector3 = _flat(o.pos) + Vector3(0, float(o.get("y", 0.0)), 0)
	if kind in ["hill", "peak"]:
		base.y = terrain.height_at(o.pos) * 0.4
	ArenaDebris.burst(
		arena,
		base,
		minf(sz.y, 1.0),
		0.25 * k,
		mat,
		terrain.scenario,
		dir,
		Callable(terrain, "height_at")
	)
	PixelFx.pop(arena, "dust", base + Vector3(0, 0.4, 0), 1.0 + 0.4 * k, 0.35)

class_name BattleProps
extends RefCounted
## Objetos vivos do cenário (só no modo de energia): árvore, Voltorb dormindo, arbusto de frutas e
## cristal. Quem cria é o BattleTerrain (terrain.props); ele chama os ganchos abaixo (setup, tick,
## golpe que caiu, tiro parado, raio) e o resto do jogo fala com ele por lá.
##
## - Árvore: cobertura alta (para tiro e raio como um pico). Grama perto dela (TREE_NEAR) recupera
##   energia TREE_REGEN x. Fogo põe fogo nela: queima TREE_BURN s e cai para longe de quem pôs fogo;
##   golpe de Pedra/Lutador forte (poder >= STRONG) derruba na hora (TREE_TIP s de aviso). A queda
##   acerta quem está na linha (TREE_FRAC do HP e empurrão) e a árvore vira tronco no chão: baixo, não
##   para tiro, anda devagar em cima (LOG_SLOW) e para investida. Outro golpe nela derruba uma Oran
##   (uma por TREE_BERRY_CD s por árvore).
## - Voltorb dormindo: como uma caixa (cobertura baixa). Fogo, Elétrico ou golpe forte acorda: anel de
##   aviso no chão por VOLT_WARN s e explode (raio VOLT_R, VOLT_FRAC do HP, empurrão) e some.
## - Arbusto de frutas: a cada BUSH_EVERY s nasce uma Oran do lado dele (uma por vez). Grama e Inseto
##   pegam de mais longe. Fogo queima o arbusto: sem fruta por BUSH_BURN s, depois rebrota.
## - Cristal: cobertura que reflete raio (kind "beam") no ângulo espelhado; o raio refletido acerta quem
##   estiver do outro lado com REFLECT x do poder. Elétrico carrega: por CHARGE s solta faísca em quem
##   está a até SPARK_R m. Pedra/Lutador quebram (CRYSTAL_HP).
##
## - Pedregulho (boulder): pedra redonda no topo de um morro. Pedra/Terra/Lutador (ou golpe forte) o
##   empurra: treme BOULDER_WARN s (linha de aviso) e rola morro abaixo na direção do golpe até bater em
##   algo (parede, pico, caixa, objeto, subida); quem está no caminho toma BOULDER_FRAC do HP, cai e é
##   empurrado. Bater em árvore derruba, em Voltorb acorda, no cristal quebra, na colmeia solta o enxame;
##   no lago afunda. Parado vira pedra pequena (stone): cobertura baixa.
## - Gêiser: a cada GEYSER_EVERY s solta vapor (GEYSER_WARN s de aviso) e explode: quem está em cima, no
##   chão, sobe (GEYSER_AIR s no ar: investida passa por baixo, Voador acerta GEYSER_FLY x) e o vapor
##   para tiro e raio por STEAM_SECS s. Água ou Fogo nele adianta a erupção (GEYSER_EARLY s de aviso).
## - Colmeia de Beedrill: golpe nela solta o enxame (SWARM_SECS s) atrás de quem estiver mais perto dela
##   entre quem bateu e os inimigos dele (Inseto não: o enxame ignora). Ferroada a cada SWARM_TICK s
##   (SWARM_FRAC do HP, SWARM_POISON de envenenar). Fogo perto do enxame o espalha; Fogo na colmeia a
##   queima (some sem enxame). Depois do enxame, HIVE_CD s quieta.
## - Cogumelos de esporo: mancha baixa no chão. Quem pisa (ou golpe nela) solta uma nuvem SPORE_SECS s
##   (raio SPORE_R): cada um dentro (menos Grama) sorteia uma vez sono (SPORE_SLEEP) ou veneno
##   (SPORE_POISON). Chuva molha os esporos (nada sai). Recarrega em SPORE_CD s.
##
## Oran: cura BERRY_HEAL do HP ou dá BERRY_EN de energia (o que faltar mais; no 1x1 só energia).
## IA (estáticos, chamados de BattleAI): ai_shot (tiro no objeto: Voltorb perto do inimigo, derrubar a
## árvore em cima dele, tabela no cristal, carregar o cristal, rolar o pedregulho, soltar o enxame,
## adiantar o gêiser, estourar os esporos) e steer (ir na fruta com HP/energia baixa); avoid (pelo
## BattleTerrain.steer) contorna os esporos, sai do gêiser perto da erupção e foge do enxame. Os avisos
## entram em arena.telegraph com side -1 (os dois lados desviam).

## Colocados depois do relevo (SCENARIOS); o pedregulho vai para o topo de um morro.
const ORDER := ["tree", "crystal", "voltorb", "bush", "geyser", "hive", "mushroom", "boulder"]
## Tamanho por tipo, como BattleTerrain.SIZES: [raio mín., raio máx., altura mín., altura máx.]. O raio
## aqui é o de espaço no cenário (copa, brilho); o corpo sólido é SOLID_R.
const SIZES := {
	"tree": [0.9, 0.9, 0.0, 0.0],
	"crystal": [0.6, 0.6, 0.0, 0.0],
	"voltorb": [0.5, 0.5, 0.0, 0.0],
	"bush": [0.7, 0.7, 0.0, 0.0],
	"geyser": [0.75, 0.75, 0.0, 0.0],
	"hive": [0.6, 0.6, 0.0, 0.0],
	"mushroom": [0.85, 0.85, 0.0, 0.0],
	"boulder": [0.55, 0.55, 0.0, 0.0],
}
## Corpo sólido (lutador não atravessa), raio contra tiro e altura da cobertura (0 = não cobre). A
## altura conta do chão do objeto (o pedregulho fica no topo do morro: o.y).
const SOLID_R := {
	"tree": 0.4,
	"crystal": 0.45,
	"voltorb": 0.42,
	"bush": 0.5,
	"hive": 0.4,
	"boulder": 0.5,
	"stone": 0.32
}
const SHOT_R := {
	"tree": 0.55, "crystal": 0.45, "voltorb": 0.42, "hive": 0.4, "boulder": 0.5, "stone": 0.32
}
const COVER_H := {
	"tree": 2.6, "crystal": 1.4, "voltorb": 0.85, "hive": 0.95, "boulder": 1.0, "stone": 0.6
}
const BODY_R := 0.4
const STRONG := 80.0
const HIT_CD := 0.3
const BREAKERS := ["rock", "fighting"]
## Árvore.
const TREE_H := 2.6
const TREE_NEAR := 2.0
const TREE_REGEN := 1.2
const TREE_BURN := 2.0
const TREE_WARN := 1.0  ## aviso (linha no chão) no fim da queima
const TREE_TIP := 0.7  ## golpe forte: aviso até cair
const TREE_STRONG := 60.0  ## Pedra/Lutador com poder >= TREE_STRONG derruba
const TREE_FRAC := 1.0 / 8.0
const TREE_KNOCK := 7.0
const TREE_W := 0.55  ## meia largura da linha da queda (+ 0,35 na ponta, a copa)
const TREE_BERRY_CD := 20.0
const LOG_R := 0.3
const LOG_SLOW := 0.6
const LOG_LIFE := 45.0
## Voltorb.
const VOLT_R := 2.2
const VOLT_WARN := 1.0
const VOLT_FRAC := 1.0 / 6.0
const VOLT_KNOCK := 9.0
## Arbusto e frutas.
const BUSH_EVERY := Vector2(20.0, 25.0)
const BUSH_BURN := 30.0
const BERRY_OFF := 0.95
const BERRY_HEAL := 1.0 / 10.0  ## 1/8 alongava o 1x1 (bateria: 126 s contra 117 s sem frutas)
const BERRY_EN := 20.0
const PICK_R := 0.7
const PICK_FAR := 1.4  ## Grama e Inseto
const PICK_TYPES := ["grass", "bug"]
const TREE_BERRY_LIFE := 20.0
## Cristal.
const CRYSTAL_HP := 2
const REFLECT := 0.7
const CHARGE := 4.0
const SPARK_R := 1.5
const SPARK_EVERY := 1.0
const SPARK_FRAC := 1.0 / 40.0
## Pedregulho.
const BOULDER_R := 0.5
const BOULDER_WARN := 0.3  ## treme (linha de aviso) antes de rolar
const BOULDER_SPEED := 8.0
const BOULDER_MAX := 11.0  ## rola no máx. isso (m)
const BOULDER_FRAC := 1.0 / 8.0
const BOULDER_KNOCK := 8.0
const BOULDER_STUN := 0.8  ## caído
const BOULDER_W := 0.45  ## folga de cada lado da linha (além do raio)
const STONE_R := 0.32
## Gêiser.
const GEYSER_EVERY := Vector2(11.0, 13.0)
const GEYSER_FIRST := Vector2(7.0, 12.0)
const GEYSER_WARN := 1.5
const GEYSER_EARLY := 0.8  ## Água/Fogo nele: aviso curto
const GEYSER_AIR := 1.1
const GEYSER_H := 2.2
const GEYSER_OUT := 1.3  ## cai a isso do centro
const GEYSER_FLY := 1.5  ## Voador em quem está no ar do gêiser
const STEAM_SECS := 2.0
const STEAM_R := 0.95
const STEAM_H := 4.0
const GEYSER_TYPES := ["water", "fire"]
## Colmeia e enxame.
const HIVE_CD := 15.0
const SWARM_SECS := 4.0
const SWARM_SPEED := 4.6
const SWARM_REACH := 0.9
const SWARM_TICK := 0.6
const SWARM_FRAC := 1.0 / 48.0
const SWARM_POISON := 0.12
const SWARM_FIRE_R := 1.6  ## golpe de Fogo a até isso do enxame o espalha
const SWARM_RANGE := 9.0  ## só persegue quem está a até isso da colmeia
## Cogumelos de esporo.
const SPORE_R := 1.3
const SPORE_SECS := 2.0
const SPORE_CD := 10.0
const SPORE_SLEEP := 0.3
const SPORE_POISON := 0.35  ## (sorteio: < SLEEP dorme; < SLEEP + POISON envenena; senão nada)
const SPORE_WET_SAY := 6.0
## IA.
const AI_EVERY := 0.5  ## olha as chances de tiro no objeto a cada AI_EVERY s
const AI_SHOT_CD := 3.5  ## depois de atirar num objeto (era 6: objetos quase não apareciam)
const AI_BANK_OPEN := 0.15  ## chance (por olhada) de tentar a tabela com o alvo à vista
const AI_GEYSER_SOON := 1.0  ## evita o gêiser a menos disso da erupção (2,2: ninguém subia nunca)
const AI_KINDS := ["projectile", "beam"]
const AI_SAFE := 1.0  ## além do raio da explosão
const BERRY_SEEK := 7.0
const BERRY_HP := 0.45
const BERRY_LOW_EN := 30.0
const BERRY_SAFE := 2.0  ## inimigo a menos disso do caminho ou da fruta: não vai
const BERRY_CHASE := 4.0
const BERRY_CHASE_CD := 8.0

var terrain  ## BattleTerrain
var arena: Node
## {kind, pos, r, state, node, cd, ...}: tree (state "", "burn", "tip"), voltorb ("", "armed"), bush,
## crystal, log.
var items: Array = []
## Oran no chão: {pos, node, src ("bush"/"tree"), owner (o objeto), t (vida; INF = até pegarem)}
var berries: Array = []
## Enxames soltos da colmeia: {pos, target, t, tick, by, hive, node}
var swarms: Array = []
## Nuvens de esporo: {pos, t, hit (ids já sorteados), node}
var clouds: Array = []
var _t := 0.0
var _ai := {}  ## id do lutador -> {next, chase, chase_cd}

static var _tex := {}


func _init(t) -> void:
	terrain = t
	arena = t.arena


## Os objetos só existem no modo de energia (o VGC fica como está); opts.props: false desliga.
func enabled() -> bool:
	if not bool(arena.opts.get("props", true)):
		return false
	return arena.has_method("energy_on") and arena.energy_on()


func _tele(kind: String, data: Dictionary) -> void:
	terrain._tele(kind, data)


func _uid(f) -> String:
	return terrain._uid(f)


func _vis() -> bool:
	return arena.is_inside_tree() and not bool(arena.opts.get("fast_sim", false))


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _dmg(f: BattleFighter, frac: float) -> int:
	return maxi(1, int(float(f.max_hp) * frac * f.dot_scale()))


# --- Montagem ---


func add(kind: String, at: Vector3) -> void:
	var o := {"kind": kind, "pos": _flat(at), "r": float(SIZES[kind][0]), "state": "", "cd": 0.0}
	match kind:
		"tree":
			o.berry_cd = 0.0
		"bush":
			o.grow_t = arena.rng.randf_range(BUSH_EVERY.x, BUSH_EVERY.y)
			o.burnt_t = 0.0
		"crystal":
			o.hp = CRYSTAL_HP
			o.charge_t = 0.0
			o.spark_t = 0.0
		"geyser":
			o.timer = arena.rng.randf_range(GEYSER_FIRST.x, GEYSER_FIRST.y)
		"hive":
			o.rest_t = 0.0
		"mushroom":
			o.rest_t = 0.0
			o.inside = {}
			o.wet_t = 0.0
		"boulder":
			_on_hill(o)
	o.y = terrain.height_at(o.pos) if o.kind == "boulder" else 0.0
	if _vis():
		_build(o)
	items.append(o)


## Pedregulho: vai para o topo do morro mais perto que ainda não tem um (sem morro, fica onde caiu).
## Prefere morro alto (h >= BattleTerrain.HIGH): na quadra voxel há montinhos baixos.
func _on_hill(o: Dictionary) -> void:
	var best := {}
	for low_ok in [false, true]:
		var best_d := INF
		for h in terrain.obstacles:
			if h.kind != "hill" or of_kind("boulder").any(func(b): return b.get("hill") == h):
				continue
			if not low_ok and float(h.h) < BattleTerrain.HIGH:
				continue
			var d := _flat(h.pos - o.pos).length()
			if d < best_d:
				best_d = d
				best = h
		if not best.is_empty():
			break
	if best.is_empty():
		return
	o.hill = best
	o.pos = _flat(best.pos)


## Espaço livre no cenário (BattleTerrain._spot_free) também longe dos objetos.
func spot_free(at: Vector3, r: float, gap: float) -> bool:
	for o in items:
		if _flat(at - o.pos).length() < r + float(o.r) + gap:
			return false
	return true


func of_kind(kind: String) -> Array:
	return items.filter(func(o): return o.kind == kind)


# --- Cobertura, chão e energia ---


## Tiro em `p` (local) parou num objeto alto (árvore em pé, cristal, Voltorb)?
func blocks_shot(p: Vector3) -> bool:
	for o in items:
		if o.kind == "geyser":
			if o.state == "steam" and p.y < STEAM_H and _flat(p - o.pos).length() < STEAM_R:
				return true  # vapor do gêiser
			continue
		if not SHOT_R.has(o.kind) or o.kind == "tree" and o.state == "fallen":
			continue
		var top := float(o.get("y", 0.0)) + float(COVER_H[o.kind])
		if p.y < top and _flat(p - o.pos).length() < float(SHOT_R[o.kind]):
			return true
	return false


func has_cover() -> bool:
	for o in items:
		if SHOT_R.has(o.kind):
			return true
	return false


## Esconderijos para BattleTerrain.cover_spot: árvores, cristais e pedras (Voltorb não: ele explode;
## colmeia também não).
func cover_cands() -> Array:
	var out: Array = []
	for o in items:
		if o.kind in ["tree", "crystal", "stone"]:
			out.append({"pos": o.pos, "r": float(SHOT_R[o.kind])})
	return out


## Grama perto de árvore em pé recupera mais energia.
func regen_mult(f: BattleFighter) -> float:
	if not "grass" in f.types:
		return 1.0
	for o in items:
		if o.kind == "tree" and _flat(f.position - o.pos).length() <= TREE_NEAR:
			return TREE_REGEN
	return 1.0


## Andar em cima do tronco caído: devagar.
func move_mult(f: BattleFighter) -> float:
	for o in items:
		if o.kind == "log" and f.height() < 0.5 and _log_dist(o, f.position) < LOG_R + 0.25:
			return LOG_SLOW
	return 1.0


func _log_dist(o: Dictionary, p: Vector3) -> float:
	return _flat(p - _log_closest(o, p)).length()


func _log_closest(o: Dictionary, p: Vector3) -> Vector3:
	var a: Vector3 = o.pos
	var along := clampf(_flat(p - a).dot(o.dir), 0.0, float(o.len))
	return a + o.dir * along


# --- Golpes ---


## Um golpe chegou em `at` (BattleTerrain.on_move_landed: área, tiro parado, acerto num lutador).
func on_move_landed(user: BattleFighter, mv: Dictionary, at: Vector3, radius: float) -> void:
	if items.is_empty() or float(mv.get("power", 0)) <= 0.0:
		return
	if String(mv.get("type", "")) == "fire":
		for sw in swarms.duplicate():
			if _flat(at - sw.pos).length() <= SWARM_FIRE_R + radius * 0.5:
				_end_swarm(sw, "fire", user)
	for o in items.duplicate():
		if o.kind in ["log", "stone"] or float(o.cd) > 0.0:
			continue
		var reach := float(SHOT_R.get(o.kind, SOLID_R.get(o.kind, o.r))) + 0.25 + radius * 0.5
		if o.kind == "boulder" and o.has("hill"):
			reach = maxf(reach, float(o.hill.r) + 0.2)  # golpe no morro sacode o pedregulho
		if _flat(at - o.pos).length() <= reach:
			hit_prop(o, user, mv)


## Raio (BattleMoves._beam): o primeiro objeto alto na linha leva o golpe; o cristal reflete.
func on_beam(user: BattleFighter, mv: Dictionary, dir: Vector3, r: float, w: float) -> void:
	if items.is_empty() or not is_instance_valid(user):
		return
	var from := _flat(user.position)
	var got := _first_on_line(from, dir, r)
	if got.is_empty():
		return
	var o: Dictionary = got.o
	var hp: Vector3 = got.at
	if terrain.shot_block(from, hp) < _flat(hp - from).length() - 0.35:
		return  # pico, morro ou caixa antes
	if o.kind == "crystal":
		_reflect(user, mv, o, from, dir, r - _flat(hp - from).length(), w)
	hit_prop(o, user, mv)


## Primeiro objeto alto que a reta de `from` na direção `dir` (até `r` m) toca: {o, at, t}.
func _first_on_line(from: Vector3, dir: Vector3, r: float) -> Dictionary:
	var best := {}
	var best_t := r
	for o in items:
		if not SHOT_R.has(o.kind):
			continue
		var t := _ray_circle(from, dir, o.pos, float(SHOT_R[o.kind]))
		if t >= 0.0 and t < best_t:
			best_t = t
			best = {"o": o, "at": from + dir * t, "t": t}
	return best


## Distância ao longo do raio até o círculo (centro `c`, raio `rad`), ou -1.
static func _ray_circle(from: Vector3, dir: Vector3, c: Vector3, rad: float) -> float:
	var m := _flat(from - c)
	var b := m.dot(dir)
	var cc := m.length_squared() - rad * rad
	if cc > 0.0 and b > 0.0:
		return -1.0
	var disc := b * b - cc
	if disc < 0.0:
		return -1.0
	return maxf(-b - sqrt(disc), 0.0)


## Direção do raio refletido no cristal (espelho pela normal do ponto de contato), ou ZERO se a reta
## não toca nele.
static func reflect_dir(from: Vector3, dir: Vector3, c: Vector3) -> Vector3:
	var t := _ray_circle(from, dir, c, float(SHOT_R.crystal))
	if t < 0.0:
		return Vector3.ZERO
	var n := _flat(from + dir * t - c).normalized()
	if n.length() < 0.5:
		return -dir
	return (dir - n * 2.0 * dir.dot(n)).normalized()


func _reflect(
	user: BattleFighter,
	mv: Dictionary,
	o: Dictionary,
	from: Vector3,
	dir: Vector3,
	left: float,
	w: float
) -> void:
	var out := reflect_dir(from, dir, o.pos)
	if out == Vector3.ZERO or left <= 0.3:
		return
	var at: Vector3 = (
		o.pos + _flat(from + dir * _ray_circle(from, dir, o.pos, SHOT_R.crystal) - o.pos)
	)
	var start := at + out * 0.25
	var m := mv.duplicate()
	m.erase("_cast")
	m["reflected"] = true
	var hits: Array = []
	var frac := 0.0
	for f in arena.moves._victims(user, mv, start):
		var rel := _flat(f.position - start)
		var along := rel.dot(out)
		if along < -0.3 or along > left or (rel - out * along).length() > w / 2.0 + 0.5:
			continue
		if terrain.shot_block(start + out * 0.3, f.position) < INF:
			continue
		var hp0: int = f.hp
		arena.moves.hit(user, f, m, out, REFLECT)
		var dealt := hp0 - int(f.hp)
		frac += float(dealt) / maxf(f.max_hp, 1)
		hits.append(_uid(f))
		_tele(
			"crystal_reflect_hit",
			{
				"who": _uid(f),
				"by": _uid(user),
				"dmg": dealt,
				"frac": snappedf(float(dealt) / maxf(f.max_hp, 1), 0.001)
			}
		)
	_tele("crystal_reflect", {"by": _uid(user), "move": String(mv.get("id", "")), "hits": hits})
	arena.popup(o.pos + Vector3(0, 1.5, 0), "Reflected!", Color(0.6, 0.95, 1.0))
	if _vis():
		var col := Dex.type_color(String(mv.get("type", "normal")))
		arena.fx_beam(start + Vector3(0, 0.6, 0), out, left, maxf(w * 0.7, 0.3), col, 0.3)


## O objeto `o` levou um golpe de `user`.
func hit_prop(o: Dictionary, user: BattleFighter, mv: Dictionary) -> void:
	if not items.has(o):
		return
	o.cd = HIT_CD
	var type := String(mv.get("type", ""))
	var power := float(mv.get("power", 0))
	var breaker := type in BREAKERS
	match String(o.kind):
		"tree":
			if o.state != "":
				return
			if type == "fire":
				_ignite_tree(o, user)
			elif breaker and power >= TREE_STRONG:
				_tip_tree(o, user, TREE_TIP, "strong")
			elif float(o.berry_cd) <= 0.0:
				o.berry_cd = TREE_BERRY_CD
				_drop_berry(o, "tree", TREE_BERRY_LIFE)
		"voltorb":
			if o.state == "" and (type in ["fire", "electric"] or power >= STRONG):
				_wake(o, user)
		"bush":
			if type == "fire" and float(o.burnt_t) <= 0.0:
				_burn_bush(o, user)
		"crystal":
			if type == "electric":
				if float(o.charge_t) <= 0.0:
					_tele("crystal_charge", {"by": _uid(user)})
					arena.popup(
						o.pos + Vector3(0, 1.5, 0), "Crystal charged!", Dex.type_color("electric")
					)
				o.charge_t = CHARGE
				o.spark_t = 0.0
				_crystal_glow(o, true)
			elif breaker:
				o.hp = int(o.hp) - (2 if power >= STRONG else 1)
				if o.hp <= 0:
					_break_crystal(o, user)
				elif is_instance_valid(o.get("node")):
					o.node.scale = Vector3(1.0, 0.75, 1.0)
		"boulder":
			if o.state == "" and (type in BREAKERS or type == "ground" or power >= STRONG):
				_push_boulder(o, user, mv)
		"geyser":
			if o.state == "" and type in GEYSER_TYPES:
				_geyser_warn(o, GEYSER_EARLY, user)
		"hive":
			if type == "fire":
				_burn_hive(o, user)
			elif float(o.rest_t) <= 0.0:
				_release_swarm(o, user)
		"mushroom":
			_spore(o, user, false)


# --- Árvore ---


func _ignite_tree(o: Dictionary, user: BattleFighter) -> void:
	o.state = "burn"
	o.t = TREE_BURN
	o.by = user
	o.fall_dir = _fall_dir(o, user)
	o.warned = false
	_tele("tree_ignite", {"by": _uid(user)})
	arena.popup(o.pos + Vector3(0, 2.2, 0), "The tree caught fire!", Dex.type_color("fire"))
	if is_instance_valid(o.get("canopy_mat")):
		ArenaVoxels.tint_mat(o.canopy_mat, Color(1.0, 0.55, 0.3))


func _tip_tree(o: Dictionary, user: BattleFighter, secs: float, cause: String) -> void:
	o.state = "tip"
	o.t = secs
	o.by = user
	o.cause = cause
	if not o.has("fall_dir"):
		o.fall_dir = _fall_dir(o, user)
	_warn_line(o, secs)
	arena.popup(o.pos + Vector3(0, 2.2, 0), "It's falling!", Color(1.0, 0.8, 0.5))


func _warn_line(o: Dictionary, secs: float) -> void:
	arena.telegraph(
		{
			"kind": "line",
			"side": -1,
			"t": secs + 0.1,
			"from": o.pos,
			"dir": o.fall_dir,
			"len": TREE_H + 0.3,
			"w": (TREE_W + 0.35) * 2.0
		}
	)
	if _vis():
		arena.fx_beam(
			o.pos + Vector3(0, 0.05, 0) + o.fall_dir * 0.2,
			o.fall_dir,
			TREE_H,
			TREE_W * 2.0,
			Color(1.0, 0.45, 0.2, 0.35),
			secs
		)


## Para longe de quem atacou (com um pouco de sorte); se a ponta sai da quadra, tenta girar.
func _fall_dir(o: Dictionary, user: BattleFighter) -> Vector3:
	var rng: RandomNumberGenerator = arena.rng
	var d := Vector3.ZERO
	if is_instance_valid(user):
		d = _flat(o.pos - user.position)
	if d.length() < 0.1:
		var a := rng.randf() * TAU
		d = Vector3(cos(a), 0, sin(a))
	d = d.normalized().rotated(Vector3.UP, rng.randf_range(-0.35, 0.35))
	var inner: Rect2 = arena.rect.grow(-0.3)
	for turn in [0.0, 0.6, -0.6, 1.2, -1.2]:
		var dd := d.rotated(Vector3.UP, turn)
		var tip: Vector3 = o.pos + dd * TREE_H
		if inner.has_point(Vector2(tip.x, tip.z)):
			return dd
	return d


func _fell(o: Dictionary) -> void:
	var by: BattleFighter = o.by if is_instance_valid(o.get("by")) else null
	var d: Vector3 = o.fall_dir
	var hits: Array = []
	var frac := 0.0
	for f in arena.fighters:
		if not is_instance_valid(f) or not f.active() or f.hidden != "" or f.motion == "tunnel":
			continue
		var rel := _flat(f.position - o.pos)
		var along := rel.dot(d)
		if along < 0.2 or along > TREE_H + 0.3:
			continue
		var perp := rel - d * along
		if perp.length() > TREE_W + 0.35 * along / TREE_H + 0.2:
			continue
		var n := _dmg(f, TREE_FRAC)
		var push := perp.normalized() if perp.length() > 0.05 else Vector3(-d.z, 0, d.x)
		if by:
			f.last_hit_by = by
		f.popup("-%d Tree fell!" % n, Color(0.75, 0.55, 0.3), 1.0, 0.7)
		f.take_damage(n, push, TREE_KNOCK)
		frac += float(n) / maxf(f.max_hp, 1)
		hits.append(_uid(f))
		_tele(
			"tree_fall_hit",
			{
				"who": _uid(f),
				"by": _uid(by),
				"dmg": n,
				"frac": snappedf(float(n) / maxf(f.max_hp, 1), 0.001)
			}
		)
	_tele("tree_fall", {"by": _uid(by), "cause": String(o.get("cause", "fire")), "hits": hits})
	arena.say("The tree fell!")
	# Vira tronco no chão (baixo: não cobre, anda devagar, para investida).
	o.kind = "log"
	o.state = "fallen"
	o.dir = d
	o.len = TREE_H * 0.9
	o.life = LOG_LIFE
	o.r = 0.3
	if _vis():
		PixelFx.pop(arena, "dust", o.pos + d * TREE_H * 0.5 + Vector3(0, 0.3, 0), 2.0, 0.5)
		if is_instance_valid(o.get("node")):
			o.node.basis = Basis(Vector3.UP.cross(d).normalized(), PI * 0.5)
			o.node.position.y = 0.22
		if is_instance_valid(o.get("canopy_mat")):
			ArenaVoxels.tint_mat(
				o.canopy_mat,
				Color(0.45, 0.35, 0.25) if o.get("cause", "fire") == "fire" else Color.WHITE
			)
		if is_instance_valid(terrain.floor_node):
			terrain.floor_node.forget(o.pos)


func _tick_tree(o: Dictionary, dt: float) -> void:
	o.berry_cd = maxf(float(o.berry_cd) - dt, 0.0)
	match String(o.state):
		"burn":
			o.t = float(o.t) - dt
			if _vis() and fmod(_t, 0.3) < dt:
				PixelFx.pop(arena, "fire", o.pos + Vector3(0, 2.0, 0), 1.3, 0.35)
			if not o.warned and float(o.t) <= TREE_WARN:
				o.warned = true
				o.cause = "fire"
				_warn_line(o, float(o.t))
			if float(o.t) <= 0.0:
				_fell(o)
		"tip":
			o.t = float(o.t) - dt
			if _vis() and is_instance_valid(o.get("node")):
				var k := 1.0 - clampf(float(o.t) / TREE_TIP, 0.0, 1.0)
				o.node.basis = Basis(Vector3.UP.cross(o.fall_dir).normalized(), 0.12 * k)
			if float(o.t) <= 0.0:
				_fell(o)


func _tick_log(o: Dictionary, dt: float) -> void:
	o.life = float(o.life) - dt
	if float(o.life) <= 0.0:
		_remove(o)
		return
	# Investida que bate no tronco para.
	for f in arena.fighters:
		if not is_instance_valid(f) or not f.active() or f.dash_t <= 0.0 or f.height() > 0.5:
			continue
		var c := _log_closest(o, f.position)
		var to := _flat(c - f.position)
		if to.length() > LOG_R + BODY_R or to.length() < 0.12:
			continue
		if to.normalized().dot(f.dash_dir) > 0.3:
			f.dash_t = 0.0
			f.knock = Vector3.ZERO
			f.popup("Hit the log!", Color(0.8, 0.65, 0.45), 0.8, 0.5)
			_tele("log_block", {"who": _uid(f)})


# --- Voltorb ---


func _wake(o: Dictionary, user: BattleFighter) -> void:
	o.state = "armed"
	o.t = VOLT_WARN
	o.by = user
	arena.telegraph({"kind": "disc", "side": -1, "t": VOLT_WARN, "at": o.pos, "r": VOLT_R})
	arena.popup(o.pos + Vector3(0, 1.0, 0), "Voltorb woke up!", Color(1.0, 0.4, 0.3), 1.1)
	_tele("voltorb_wake", {"by": _uid(user)})
	if _vis():
		var ring := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = VOLT_R
		cm.bottom_radius = VOLT_R
		cm.height = 0.02
		cm.radial_segments = 32
		ring.mesh = cm
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(1.0, 0.2, 0.15, 0.3)
		ring.material_override = mat
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.position = o.pos + Vector3(0, 0.03, 0)
		arena.add_child(ring)
		o.ring = ring


func _boom(o: Dictionary) -> void:
	var by: BattleFighter = o.by if is_instance_valid(o.get("by")) else null
	_remove(o)
	var hits: Array = []
	for f in arena.fighters:
		if not is_instance_valid(f) or not f.active() or f.hidden != "" or f.motion == "tunnel":
			continue
		var rel := _flat(f.position - o.pos)
		if rel.length() > VOLT_R + 0.3:
			continue
		var n := _dmg(f, VOLT_FRAC)
		if by:
			f.last_hit_by = by
		f.popup("-%d Explosion!" % n, Color(1.0, 0.5, 0.3), 1.1, 0.7)
		f.take_damage(n, rel.normalized() if rel.length() > 0.05 else Vector3.RIGHT, VOLT_KNOCK)
		hits.append(_uid(f))
		_tele(
			"voltorb_hit",
			{
				"who": _uid(f),
				"by": _uid(by),
				"dmg": n,
				"frac": snappedf(float(n) / maxf(f.max_hp, 1), 0.001)
			}
		)
	_tele("voltorb_boom", {"by": _uid(by), "hits": hits})
	arena.say("The Voltorb exploded!")
	if _vis():
		PixelFx.pop(arena, "fire", o.pos + Vector3(0, 0.6, 0), VOLT_R * 1.6, 0.5)
		PixelFx.pop(arena, "electric", o.pos + Vector3(0, 0.5, 0), VOLT_R * 1.2, 0.4)
		if arena.has_method("cut_in") and not hits.is_empty():
			arena.cut_in("BOOM!", Color(1.0, 0.45, 0.3))
	# Outro Voltorb perto acorda (corrente).
	for v in items.duplicate():
		if v.kind == "voltorb" and v.state == "" and _flat(v.pos - o.pos).length() <= VOLT_R + 0.5:
			_wake(v, by)


func _tick_voltorb(o: Dictionary, dt: float) -> void:
	if o.state != "armed":
		return
	o.t = float(o.t) - dt
	if _vis():
		var k := 1.0 + 0.12 * sin(_t * 30.0)
		if is_instance_valid(o.get("node")):
			o.node.scale = Vector3(k, k, k)
		if is_instance_valid(o.get("ring")):
			o.ring.material_override.albedo_color.a = 0.2 + 0.25 * absf(sin(_t * 12.0))
	if float(o.t) <= 0.0:
		_boom(o)


# --- Arbusto e frutas ---


func _burn_bush(o: Dictionary, user: BattleFighter) -> void:
	o.burnt_t = BUSH_BURN
	for b in berries.duplicate():
		if b.owner == o:
			_drop_berry_node(b)
	_tele("bush_burn", {"by": _uid(user)})
	arena.popup(o.pos + Vector3(0, 1.0, 0), "The bush burned!", Dex.type_color("fire"))
	if _vis():
		PixelFx.pop(arena, "fire", o.pos + Vector3(0, 0.5, 0), 1.4, 0.5)
		if is_instance_valid(o.get("node")):
			o.node.scale = Vector3(0.7, 0.5, 0.7)
		if is_instance_valid(o.get("canopy_mat")):
			ArenaVoxels.tint_mat(o.canopy_mat, Color(0.35, 0.28, 0.22))


func _tick_bush(o: Dictionary, dt: float) -> void:
	if float(o.burnt_t) > 0.0:
		o.burnt_t = float(o.burnt_t) - dt
		if float(o.burnt_t) <= 0.0:
			o.grow_t = arena.rng.randf_range(BUSH_EVERY.x, BUSH_EVERY.y)
			_tele("bush_regrow", {})
			if is_instance_valid(o.get("node")):
				o.node.scale = Vector3.ONE
			if is_instance_valid(o.get("canopy_mat")):
				ArenaVoxels.tint_mat(o.canopy_mat, Color.WHITE)
		return
	for b in berries:
		if b.owner == o:
			return  # uma por vez
	o.grow_t = float(o.grow_t) - dt
	if float(o.grow_t) <= 0.0:
		o.grow_t = arena.rng.randf_range(BUSH_EVERY.x, BUSH_EVERY.y)
		_drop_berry(o, "bush", INF)


## Oran ao lado de `o` (dentro da quadra).
func _drop_berry(o: Dictionary, src: String, life: float) -> void:
	var rng: RandomNumberGenerator = arena.rng
	var inner: Rect2 = arena.rect.grow(-0.6)
	var at: Vector3 = o.pos
	for _try in 8:
		var a := rng.randf() * TAU
		at = o.pos + Vector3(cos(a), 0, sin(a)) * BERRY_OFF
		if inner.has_point(Vector2(at.x, at.z)):
			break
	var b := {"pos": at, "src": src, "owner": o, "t": life}
	if _vis() and terrain.lattice:
		b.node = ArenaPropsVox.berry()
		b.node.position = at + Vector3(0, 0.2, 0)
		arena.add_child(b.node)
	elif _vis():
		var mi := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.14
		s.height = 0.26
		s.radial_segments = 8
		s.rings = 4
		mi.mesh = s
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = ptex("oran")
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mat.roughness = 0.6
		mi.material_override = mat
		mi.position = at + Vector3(0, 0.2, 0)
		arena.add_child(mi)
		b.node = mi
	berries.append(b)
	_tele("berry_drop", {"src": src})


func _drop_berry_node(b: Dictionary) -> void:
	berries.erase(b)
	if is_instance_valid(b.get("node")):
		b.node.queue_free()


func _tick_berries(dt: float) -> void:
	for b in berries.duplicate():
		b.t = float(b.t) - dt
		if float(b.t) <= 0.0:
			_drop_berry_node(b)
			continue
		if _vis() and is_instance_valid(b.get("node")):
			b.node.position.y = 0.2 + 0.05 * sin(_t * 4.0 + b.pos.x)
		for f in arena.fighters:
			if not is_instance_valid(f) or not f.active() or f.height() > 0.6:
				continue
			var reach := PICK_FAR if f.types.any(func(t): return t in PICK_TYPES) else PICK_R
			if _flat(f.position - b.pos).length() > reach or not _wants_berry(f):
				continue
			_eat(f, b)
			break


## Nada a ganhar (HP cheio e barra cheia; no 1x1 só a barra): deixa a fruta no chão.
func _wants_berry(f: BattleFighter) -> bool:
	var en := f.energy_mode and f.pp_max < BattleEnergy.MAX - 1.0
	if _energy_only(f):
		return en
	return f.hp < f.max_hp or en


## No 1x1 a Oran só dá energia (cura alongava as lutas: bateria 126 s contra 117 s sem frutas).
func _energy_only(f: BattleFighter) -> bool:
	return f.energy_mode and int(arena.get("_battle_size")) < 2


func _eat(f: BattleFighter, b: Dictionary) -> void:
	var hp_k := float(f.hp) / maxf(f.max_hp, 1)
	var en_k := f.pp_max / BattleEnergy.MAX if f.energy_mode else 1.0
	var gain := "hp" if hp_k <= en_k and not _energy_only(f) else "energy"
	var n := 0
	if gain == "hp":
		var before: int = f.hp
		f.heal(f.paced(maxi(1, int(float(f.max_hp) * BERRY_HEAL))))
		n = int(f.hp) - before
		f.popup("+%d Oran" % n, Color(0.5, 1.0, 0.55), 0.9, 0.3, "heal")
	else:
		var e0: float = f.pp_max
		f.pp_max = minf(f.pp_max + BERRY_EN, BattleEnergy.MAX)
		n = int(round(f.pp_max - e0))
		f.popup("+%d energy (Oran)" % n, Color(0.55, 0.95, 0.6), 0.9, 0.3, "heal")
	f.set_meta("ate_berry", true)  # Belch
	_tele("berry_pick", {"who": _uid(f), "src": String(b.src), "gain": gain, "n": n})
	_drop_berry_node(b)


# --- Cristal ---


func _crystal_glow(o: Dictionary, on: bool) -> void:
	var mat = o.get("crystal_mat")
	if mat is StandardMaterial3D:
		mat.emission_enabled = on
		mat.emission = Dex.type_color("electric")
		mat.emission_energy_multiplier = 1.4
	elif mat is ShaderMaterial:
		var c := Dex.type_color("electric")
		mat.set_shader_parameter("flash", Vector3(c.r, c.g, c.b) * 1.2 if on else Vector3.ZERO)


func _tick_crystal(o: Dictionary, dt: float) -> void:
	if float(o.charge_t) <= 0.0:
		return
	o.charge_t = float(o.charge_t) - dt
	o.spark_t = float(o.spark_t) - dt
	if float(o.spark_t) <= 0.0:
		o.spark_t = SPARK_EVERY
		_spark(o)
	if float(o.charge_t) <= 0.0:
		o.charge_t = 0.0
		_crystal_glow(o, false)


func _spark(o: Dictionary) -> void:
	var any := false
	for f in arena.fighters:
		if not is_instance_valid(f) or not f.active() or f.hidden != "" or "ground" in f.types:
			continue
		if _flat(f.position - o.pos).length() > SPARK_R or f.height() > 1.6:
			continue
		var n := _dmg(f, SPARK_FRAC)
		f.popup("-%d Spark" % n, Dex.type_color("electric"), 0.8, 0.3)
		f.take_damage(n, Vector3.ZERO, 0.0)
		any = true
		_tele(
			"crystal_spark",
			{"who": _uid(f), "dmg": n, "frac": snappedf(float(n) / maxf(f.max_hp, 1), 0.001)}
		)
	if any and _vis():
		PixelFx.pop(arena, "electric", o.pos + Vector3(0, 0.7, 0), SPARK_R * 1.4, 0.3)


func _break_crystal(o: Dictionary, user: BattleFighter) -> void:
	_tele("crystal_break", {"by": _uid(user)})
	arena.popup(o.pos + Vector3(0, 1.2, 0), "The crystal broke!", Color(0.7, 0.95, 1.0))
	if _vis():
		PixelFx.pop(arena, "stone", o.pos + Vector3(0, 0.6, 0), 1.4, 0.4)
	_remove(o)


func _remove(o: Dictionary) -> void:
	items.erase(o)
	for k in ["node", "ring", "steam"]:
		if is_instance_valid(o.get(k)):
			o[k].queue_free()
	if is_instance_valid(terrain.floor_node):
		terrain.floor_node.forget(o.pos)


# --- Pedregulho ---


## Caminho da rolagem a partir de `o` na direção `d`: {len, into (objeto onde para ou {}), sink}.
## Para na parede, no pico, na caixa/pedra do campo, num objeto sólido, numa subida ou afunda no lago.
func roll_path(o: Dictionary, d: Vector3) -> Dictionary:
	var inner: Rect2 = arena.rect.grow(-(BOULDER_R + 0.1))
	var p: Vector3 = o.pos
	var h: float = terrain.height_at(p)
	var step := 0.1
	var dist := 0.0
	while dist < BOULDER_MAX:
		var nx := p + d * step
		if not inner.has_point(Vector2(nx.x, nx.z)):
			return {"len": dist, "into": {}, "sink": false}
		for ob in terrain.obstacles:
			if ob.kind == "peak" and _flat(nx - ob.pos).length() < float(ob.r) * 0.8 + BOULDER_R:
				return {"len": dist, "into": {}, "sink": false}
		var pond: Dictionary = terrain.pond_at(nx)
		if not pond.is_empty() and float(pond.ice_t) <= 0.0:
			return {"len": dist + step, "into": {}, "sink": true}
		var nh: float = terrain.height_at(nx)
		if nh > h + 0.02:
			return {"len": dist, "into": {}, "sink": false}  # subida: para
		h = nh
		if arena.field:
			for c in arena.field.objects:
				if _flat(nx - c.pos).length() < BattleField.OBJ_R + BOULDER_R:
					return {"len": dist, "into": {}, "sink": false}
		for q in items:
			if q == o or not SOLID_R.has(q.kind) or q.kind == "tree" and q.state == "fallen":
				continue
			if _flat(nx - q.pos).length() < float(SOLID_R[q.kind]) + BOULDER_R:
				return {"len": dist, "into": q, "sink": false}
		p = nx
		dist += step
	return {"len": dist, "into": {}, "sink": false}


func _push_boulder(o: Dictionary, user: BattleFighter, mv: Dictionary) -> void:
	var d := Vector3.ZERO
	if is_instance_valid(user):
		d = _flat(o.pos - user.position)
	if d.length() < 0.1:
		var a: float = arena.rng.randf() * TAU
		d = Vector3(cos(a), 0, sin(a))
	d = d.normalized()
	var path := roll_path(o, d)
	o.state = "wobble"
	o.t = BOULDER_WARN
	o.by = user
	o.dir = d
	o.path = path
	o.done = 0.0
	o.hits = []
	var secs := BOULDER_WARN + float(path.len) / BOULDER_SPEED
	arena.telegraph(
		{
			"kind": "line",
			"side": -1,
			"t": secs + 0.1,
			"from": o.pos,
			"dir": d,
			"len": float(path.len) + BOULDER_R,
			"w": (BOULDER_R + BOULDER_W) * 2.0
		}
	)
	arena.popup(
		o.pos + Vector3(0, float(o.y) + 1.3, 0),
		"The boulder is about to roll!",
		Color(0.85, 0.75, 0.6)
	)
	_tele(
		"boulder_push",
		{"by": _uid(user), "move": String(mv.get("id", "")), "len": snappedf(path.len, 0.1)}
	)
	if _vis():
		arena.fx_beam(
			o.pos + Vector3(0, 0.05, 0),
			d,
			float(path.len) + BOULDER_R,
			BOULDER_R * 2.0,
			Color(0.9, 0.6, 0.3, 0.3),
			secs
		)


func _tick_boulder(o: Dictionary, dt: float) -> void:
	match String(o.state):
		"":
			o.y = terrain.height_at(o.pos)  # o morro pode ter baixado ou desabado
			if is_instance_valid(o.get("node")):
				o.node.position.y = float(o.y) + BOULDER_R
		"wobble":
			o.t = float(o.t) - dt
			if _vis() and is_instance_valid(o.get("node")):
				o.node.rotation.z = 0.12 * sin(_t * 40.0)
			if float(o.t) <= 0.0:
				o.state = "roll"
				_tele("boulder_roll", {"by": _uid(o.get("by"))})
		"roll":
			var d: Vector3 = o.dir
			var stp := minf(BOULDER_SPEED * dt, float(o.path.len) - float(o.done))
			o.done = float(o.done) + stp
			o.pos = o.pos + d * stp
			o.y = terrain.height_at(o.pos)
			_boulder_hits(o)
			if _vis() and is_instance_valid(o.get("node")):
				o.node.position = o.pos + Vector3(0, float(o.y) + BOULDER_R, 0)
				o.node.rotate(Vector3.UP.cross(d).normalized(), stp / BOULDER_R)
			if float(o.done) >= float(o.path.len) - 0.001:
				_boulder_stop(o)


func _boulder_hits(o: Dictionary) -> void:
	var by: BattleFighter = o.by if is_instance_valid(o.get("by")) else null
	for f in arena.fighters:
		if not is_instance_valid(f) or not f.active() or f.hidden != "" or f.motion == "tunnel":
			continue
		if f.get_instance_id() in o.hits or f.height() > 0.9:
			continue
		var rel := _flat(f.position - o.pos)
		if rel.length() > BOULDER_R + BODY_R:
			continue
		o.hits.append(f.get_instance_id())
		var n := _dmg(f, BOULDER_FRAC)
		var d: Vector3 = o.dir
		var side := rel - d * rel.dot(d)
		var push := (d + side.normalized() * 0.8).normalized() if side.length() > 0.05 else d
		if by:
			f.last_hit_by = by
		f.stun_t = maxf(f.stun_t, BOULDER_STUN)
		f.interrupt_prepare()
		f.popup("-%d Boulder!" % n, Color(0.8, 0.7, 0.55), 1.1, 0.7)
		f.take_damage(n, push, BOULDER_KNOCK)
		_tele(
			"boulder_hit",
			{
				"who": _uid(f),
				"by": _uid(by),
				"dmg": n,
				"frac": snappedf(float(n) / maxf(f.max_hp, 1), 0.001)
			}
		)
		if _vis() and arena.has_method("cut_in"):
			arena.cut_in("ROLLED!", Color(0.8, 0.65, 0.45))


func _boulder_stop(o: Dictionary) -> void:
	var by: BattleFighter = o.by if is_instance_valid(o.get("by")) else null
	var into: Dictionary = o.path.into
	var what := "nada"
	if bool(o.path.sink):
		what = "lago"
	elif not into.is_empty() and items.has(into):
		what = String(into.kind)
		_boulder_into(into, by, o.dir)
	_tele("boulder_stop", {"by": _uid(by), "into": what, "len": snappedf(float(o.done), 0.1)})
	if _vis():
		PixelFx.pop(arena, "dust", o.pos + Vector3(0, float(o.y) + 0.3, 0), 1.6, 0.4)
	if bool(o.path.sink):
		arena.popup(o.pos + Vector3(0, 0.6, 0), "Sank!", Dex.type_color("water"))
		_remove(o)
		return
	# Vira pedra pequena: cobertura baixa.
	o.kind = "stone"
	o.state = ""
	o.r = STONE_R
	o.erase("hill")
	if _vis() and is_instance_valid(o.get("node")):
		o.node.scale = Vector3.ONE * (STONE_R / BOULDER_R)
		o.node.position = o.pos + Vector3(0, float(o.y) + STONE_R * 0.8, 0)


## O pedregulho bateu num objeto: árvore cai na direção da rolagem, Voltorb acorda, cristal quebra,
## colmeia solta o enxame.
func _boulder_into(q: Dictionary, by: BattleFighter, d: Vector3) -> void:
	match String(q.kind):
		"tree":
			if q.state == "":
				q.fall_dir = d
				_tip_tree(q, by, 0.25, "boulder")
		"voltorb":
			if q.state == "":
				_wake(q, by)
		"crystal":
			_break_crystal(q, by)
		"hive":
			if float(q.rest_t) <= 0.0:
				_release_swarm(q, by)


# --- Gêiser ---


func _geyser_warn(o: Dictionary, secs: float, by: BattleFighter = null) -> void:
	o.state = "warn"
	o.t = secs
	o.early = by != null
	# Sem aviso no chão para a esquiva (com ele ninguém subia: bateria 2): só o vapor e o desvio da IA.
	if by:
		_tele("geyser_early", {"by": _uid(by)})
		arena.popup(o.pos + Vector3(0, 1.0, 0), "The geyser is boiling!", Color(0.8, 0.9, 1.0))
	if _vis() and is_instance_valid(o.get("steam")):
		o.steam.visible = true
		o.steam.scale = Vector3(0.6, 0.25, 0.6)


func _erupt(o: Dictionary) -> void:
	o.state = "steam"
	o.t = STEAM_SECS
	var launched: Array = []
	for f in arena.fighters:
		if not is_instance_valid(f) or not f.active() or f.hidden != "":
			continue
		if f.motion != "" or f.launch_t > 0.0 or not terrain._grounded(f) or f.ground_y > 0.2:
			continue
		var rel := _flat(f.position - o.pos)
		if rel.length() > float(o.r) + 0.15:
			continue
		var out := rel.normalized() if rel.length() > 0.05 else Vector3(1, 0, 0)
		var land: Vector3 = o.pos + out * GEYSER_OUT
		var inner: Rect2 = arena.rect.grow(-0.7)
		land.x = clampf(land.x, inner.position.x, inner.end.x)
		land.z = clampf(land.z, inner.position.y, inner.end.y)
		f.interrupt_prepare()
		f.start_motion(
			"leap", land, GEYSER_AIR, GEYSER_H, null, Callable(), 0.0, Callable(), f.ground_y
		)
		f.set_meta("geyser_air", _t + GEYSER_AIR)
		f.popup("Launched into the air!", Color(0.8, 0.9, 1.0), 1.0, 0.6)
		launched.append(_uid(f))
		_tele("geyser_launch", {"who": _uid(f)})
	_tele("geyser_erupt", {"early": bool(o.get("early", false)), "launched": launched})
	if not launched.is_empty():
		arena.say("The geyser erupted!")
	if _vis():
		PixelFx.pop(arena, "water", o.pos + Vector3(0, 1.2, 0), 2.0, 0.6)
		if is_instance_valid(o.get("steam")):
			o.steam.visible = true
			o.steam.scale = Vector3.ONE


func _tick_geyser(o: Dictionary, dt: float) -> void:
	o.t = float(o.get("t", 0.0)) - dt
	match String(o.state):
		"":
			o.timer = float(o.timer) - dt
			if float(o.timer) <= GEYSER_WARN:
				_geyser_warn(o, maxf(float(o.timer), 0.1))
		"warn":
			if _vis() and fmod(_t, 0.4) < dt:
				PixelFx.pop(arena, "wind", o.pos + Vector3(0, 0.3, 0), 1.0, 0.3)
			if float(o.t) <= 0.0:
				_erupt(o)
		"steam":
			if float(o.t) <= 0.0:
				o.state = ""
				o.early = false
				o.timer = arena.rng.randf_range(GEYSER_EVERY.x, GEYSER_EVERY.y)
				if is_instance_valid(o.get("steam")):
					o.steam.visible = false


## Segundos até a próxima erupção (0 = soltando vapor agora).
func geyser_in(o: Dictionary) -> float:
	match String(o.state):
		"warn":
			return maxf(float(o.t), 0.0)
		"steam":
			return 0.0
	return float(o.timer)


## Dano extra (BattleTerrain.damage_mult): golpe Voador em quem o gêiser jogou para o alto.
func damage_mult(_user: BattleFighter, target: BattleFighter, mv: Dictionary) -> float:
	if String(mv.get("type", "")) != "flying" or not is_instance_valid(target):
		return 1.0
	if not target.has_meta("geyser_air") or _t > float(target.get_meta("geyser_air")) + 0.2:
		return 1.0
	target.popup("Helpless in the air!", Color(0.8, 0.9, 1.0), 0.9, 0.6)
	_tele("geyser_fly_hit", {"who": _uid(target)})
	return GEYSER_FLY


# --- Colmeia ---


## Quem o enxame persegue: o mais perto da colmeia entre quem bateu e os inimigos dele (Inseto não).
func swarm_target(o: Dictionary, user: BattleFighter) -> BattleFighter:
	var cands: Array = []
	if is_instance_valid(user):
		cands.append(user)
		cands.append_array(arena.targets_of(user))
	else:
		cands = arena.fighters
	var best: BattleFighter = null
	var best_d := SWARM_RANGE
	for g in cands:
		if not is_instance_valid(g) or not g.active() or "bug" in g.types:
			continue
		var d := _flat(g.position - o.pos).length()
		if d < best_d:
			best_d = d
			best = g
	return best


func _release_swarm(o: Dictionary, user: BattleFighter) -> void:
	o.rest_t = HIVE_CD
	var tgt := swarm_target(o, user)
	if tgt == null:
		arena.popup(o.pos + Vector3(0, 1.2, 0), "The Beedrill didn't care.", Color(0.95, 0.85, 0.3))
		_tele("hive_swarm", {"by": _uid(user), "who": ""})
		return
	var sw := {"pos": o.pos, "target": tgt, "t": SWARM_SECS, "tick": 0.3, "by": user, "hive": o}
	if _vis():
		sw.node = _swarm_node()
		sw.node.position = o.pos + Vector3(0, 1.0, 0)
		arena.add_child(sw.node)
	swarms.append(sw)
	arena.popup(o.pos + Vector3(0, 1.3, 0), "Beedrill swarm!", Color(0.95, 0.85, 0.3), 1.1)
	tgt.popup("The swarm is coming!", Color(0.95, 0.85, 0.3), 0.9, 0.6)
	_tele("hive_swarm", {"by": _uid(user), "who": _uid(tgt), "self": tgt == user})


func _tick_swarms(dt: float) -> void:
	for sw in swarms.duplicate():
		sw.t = float(sw.t) - dt
		var tgt: BattleFighter = sw.target if is_instance_valid(sw.target) else null
		if float(sw.t) <= 0.0 or tgt == null or not tgt.active():
			_end_swarm(sw, "time")
			continue
		var to := _flat(tgt.position - sw.pos)
		sw.pos = sw.pos + to.limit_length(SWARM_SPEED * dt)
		if _vis() and is_instance_valid(sw.get("node")):
			sw.node.position = sw.pos + Vector3(0, 1.0 + 0.15 * sin(_t * 9.0), 0)
			sw.node.rotation.y += dt * 6.0
		sw.tick = float(sw.tick) - dt
		if float(sw.tick) > 0.0 or to.length() > SWARM_REACH or tgt.hidden != "":
			continue
		sw.tick = SWARM_TICK
		var n := _dmg(tgt, SWARM_FRAC)
		var by: BattleFighter = sw.by if is_instance_valid(sw.get("by")) else null
		if by and by.side != tgt.side:
			tgt.last_hit_by = by
		tgt.popup("-%d Sting" % n, Color(0.95, 0.85, 0.3), 0.8, 0.3)
		tgt.take_damage(n, Vector3.ZERO, 0.0)
		var poisoned := false
		if arena.rng.randf() < SWARM_POISON:
			poisoned = _give_status(tgt, "poison", by)
		_tele(
			"swarm_sting",
			{
				"who": _uid(tgt),
				"dmg": n,
				"frac": snappedf(float(n) / maxf(tgt.max_hp, 1), 0.001),
				"poisoned": poisoned
			}
		)


func _end_swarm(sw: Dictionary, why: String, by: BattleFighter = null) -> void:
	swarms.erase(sw)
	if is_instance_valid(sw.get("node")):
		sw.node.queue_free()
	if why == "fire":
		arena.popup(
			sw.pos + Vector3(0, 1.2, 0), "The fire scared the swarm away!", Dex.type_color("fire")
		)
		_tele("swarm_fire", {"by": _uid(by)})
		if _vis():
			PixelFx.pop(arena, "fire", sw.pos + Vector3(0, 1.0, 0), 1.2, 0.3)


func _burn_hive(o: Dictionary, user: BattleFighter) -> void:
	_tele("hive_burn", {"by": _uid(user)})
	arena.popup(o.pos + Vector3(0, 1.2, 0), "The hive burned!", Dex.type_color("fire"))
	if _vis():
		PixelFx.pop(arena, "fire", o.pos + Vector3(0, 0.6, 0), 1.4, 0.5)
	_remove(o)


## Status do cenário (enxame, esporo): passa pelas mesmas regras do golpe (tipo imune, habilidade,
## Safeguard, imunidade de recém-curado).
func _give_status(f: BattleFighter, s: String, by: BattleFighter) -> bool:
	if f.status != "" or (f.status_immune_t > 0.0 and f.last_status == s):
		return false
	var mv = arena.get("moves")
	if mv and mv.effects and mv.effects.has_method("_status"):
		mv.effects._status(by, f, s)
	else:
		f.apply_status(s, by)
	return f.status == s


# --- Cogumelos de esporo ---


func _spore(o: Dictionary, by: BattleFighter, step: bool) -> void:
	if float(o.rest_t) > 0.0:
		return
	if terrain._weather() == "rain":
		if _t - float(o.wet_t) >= SPORE_WET_SAY or float(o.wet_t) <= 0.0:
			o.wet_t = maxf(_t, 0.001)
			arena.popup(o.pos + Vector3(0, 0.6, 0), "Wet spores", Dex.type_color("water"))
			_tele("spore_wet", {})
		return
	o.rest_t = SPORE_CD
	var c := {"pos": o.pos, "t": SPORE_SECS, "hit": {}, "by": by}
	if _vis():
		c.node = _cloud_node()
		c.node.position = o.pos + Vector3(0, 0.5, 0)
		arena.add_child(c.node)
		if is_instance_valid(o.get("node")):
			o.node.scale = Vector3(1.0, 0.5, 1.0)
	clouds.append(c)
	arena.popup(o.pos + Vector3(0, 0.9, 0), "Spore cloud!", Color(0.85, 0.6, 0.95))
	_tele("spore_cloud", {"by": _uid(by), "step": step})


func _tick_mushroom(o: Dictionary, dt: float) -> void:
	if float(o.rest_t) > 0.0:
		o.rest_t = float(o.rest_t) - dt
		if float(o.rest_t) <= 0.0 and is_instance_valid(o.get("node")):
			o.node.scale = Vector3.ONE
	var now := {}
	for f in arena.fighters:
		if not is_instance_valid(f) or not f.active() or f.hidden != "" or f.motion == "tunnel":
			continue
		if f.height() > 0.3 or _flat(f.position - o.pos).length() > float(o.r):
			continue
		now[f.get_instance_id()] = true
		if not o.inside.has(f.get_instance_id()):
			_spore(o, f, true)
	o.inside = now


func _tick_clouds(dt: float) -> void:
	for c in clouds.duplicate():
		c.t = float(c.t) - dt
		if float(c.t) <= 0.0:
			clouds.erase(c)
			if is_instance_valid(c.get("node")):
				c.node.queue_free()
			continue
		var by: BattleFighter = c.by if is_instance_valid(c.get("by")) else null
		for f in arena.fighters:
			if not is_instance_valid(f) or not f.active() or f.hidden != "" or "grass" in f.types:
				continue
			var id: int = f.get_instance_id()
			if c.hit.has(id) or f.height() > 1.5:
				continue
			if _flat(f.position - c.pos).length() > SPORE_R:
				continue
			c.hit[id] = true
			var roll: float = arena.rng.randf()
			var st := ""
			if roll < SPORE_SLEEP:
				st = "sleep"
			elif roll < SPORE_SLEEP + SPORE_POISON:
				st = "poison"
			var got := st != "" and _give_status(f, st, by)
			_tele("spore_status", {"who": _uid(f), "st": st if got else ""})


# --- IA dos objetos novos ---


## Desvio da IA (BattleTerrain.steer): contorna os esporos prontos (quem não é de Grama), não entra no
## gêiser perto da erupção e foge do enxame que vem atrás dele.
func avoid(f: BattleFighter, want: Vector3) -> Vector3:
	if items.is_empty() and swarms.is_empty():
		return want
	var out := want
	for sw in swarms:
		if sw.target == f:
			var away := _flat(f.position - sw.pos)
			if away.length() < 3.0:
				var dir_away := away.normalized() if away.length() > 0.05 else Vector3.RIGHT
				out += dir_away * 1.2 * (1.0 - away.length() / 3.0)
				f.sprinting = f.can_sprint(true)
	var wet: bool = terrain._weather() == "rain"
	for o in items:
		var clear := 0.0
		match String(o.kind):
			"mushroom":
				if "grass" in f.types or float(o.rest_t) > 0.0 or wet or f.height() > 0.3:
					continue
				clear = float(o.r) + 0.45
			"geyser":
				if geyser_in(o) > AI_GEYSER_SOON or f.height() > 0.3:
					continue
				clear = float(o.r) + 0.7  # não entra; quem já está em cima fica (e sobe)
			_:
				continue
		if want.length() < 0.05:
			continue
		var dir := want.normalized()
		var to := _flat(o.pos - f.position)
		var ahead := to.dot(dir)
		if ahead <= 0.0 or ahead > clear + 1.4:
			continue
		var side := to - dir * ahead
		if side.length() >= clear:
			continue
		var tangent := Vector3(-dir.z, 0.0, dir.x)
		if side.dot(tangent) > 0.0:
			tangent = -tangent
		out += tangent * (1.0 - side.length() / clear) * 1.4 * want.length()
	if out.is_equal_approx(want) or out.length() < 0.001:
		return want
	return out.normalized() * maxf(want.length(), minf(out.length(), 1.0))


## Pedregulho: rola na direção de quem atira; vale se um inimigo está na linha e nenhum aliado.
func _boulder_shot(f: BattleFighter, mv: Dictionary, me: Vector3, reach: float) -> Dictionary:
	var type := String(mv.get("type", ""))
	if not (type in BREAKERS or type == "ground") and float(mv.get("power", 0)) < STRONG:
		return {}
	for o in items:
		if o.kind != "boulder" or o.state != "":
			continue
		var to := _flat(o.pos - me)
		if to.length() > reach or to.length() < 1.2:
			continue
		var d := to.normalized()
		var path := roll_path(o, d)
		if float(path.len) < 1.0:
			continue
		var w := BOULDER_R + BODY_R + 0.4
		var hill_r := float(o.hill.r) if o.has("hill") else 0.0
		var clear: bool = terrain.shot_block(me, o.pos) >= to.length() - maxf(hill_r, 0.5) - 0.35
		if _in_lane(f, o.pos, d, float(path.len) + 0.5, w) and clear:
			return {"what": "boulder", "pos": o.pos}
	return {}


## Inimigo (e nenhum aliado) na faixa de `from` na direção `d`, até `len` m, meia largura `w`.
func _in_lane(f: BattleFighter, from: Vector3, d: Vector3, len: float, w: float) -> bool:
	var foe_in := false
	for g in arena.fighters:
		if not is_instance_valid(g) or not g.active():
			continue
		var rel := _flat(g.position - from)
		var along := rel.dot(d)
		if along < 0.2 or along > len or (rel - d * along).length() > w:
			continue
		if g.side == f.side:
			return false
		foe_in = true
	return foe_in


## Colmeia: só com um inimigo bem perto dela (o enxame vai em quem está mais perto) e eu longe.
func _hive_shot(f: BattleFighter, mv: Dictionary, me: Vector3, reach: float) -> Dictionary:
	if String(mv.get("type", "")) == "fire":
		return {}
	for o in items:
		if o.kind != "hive" or float(o.rest_t) > 0.0:
			continue
		var d := _flat(o.pos - me).length()
		if d > reach or d < 2.5:
			continue
		var tgt := swarm_target(o, f)
		if tgt == null or tgt.side == f.side:
			continue
		if _flat(tgt.position - o.pos).length() > 2.2:
			continue
		if _clear_to(me, o):
			return {"what": "hive", "pos": o.pos}
	return {}


## Gêiser: Água/Fogo nele com um inimigo em cima (aviso curto) e nenhum aliado.
func _geyser_shot(f: BattleFighter, mv: Dictionary, me: Vector3, reach: float) -> Dictionary:
	if not String(mv.get("type", "")) in GEYSER_TYPES:
		return {}
	for o in items:
		if o.kind != "geyser" or o.state != "" or float(o.timer) < 2.0:
			continue
		var d := _flat(o.pos - me).length()
		if d > reach or d < float(o.r) + 1.0:
			continue
		if not _side_near(f, o.pos, float(o.r) + 0.3, true):
			continue
		if _side_near(f, o.pos, float(o.r) + 0.6, false):
			continue
		if terrain.shot_block(me, o.pos) >= d - 0.4:
			return {"what": "geyser", "pos": o.pos}
	return {}


## Esporos: estoura com um inimigo (que não é de Grama, sem status) dentro da nuvem e nenhum aliado.
func _spore_shot(f: BattleFighter, _mv: Dictionary, me: Vector3, reach: float) -> Dictionary:
	if terrain._weather() == "rain":
		return {}
	for o in items:
		if o.kind != "mushroom" or float(o.rest_t) > 0.0:
			continue
		var d := _flat(o.pos - me).length()
		if d > reach or d < SPORE_R + 1.0:
			continue
		var foe := false
		for g in arena.targets_of(f):
			if g.active() and not "grass" in g.types and g.status == "":
				if _flat(g.position - o.pos).length() <= SPORE_R - 0.2:
					foe = true
		if not foe or _side_near(f, o.pos, SPORE_R + 0.5, false):
			continue
		if terrain.shot_block(me, o.pos) >= d - 0.4:
			return {"what": "mushroom", "pos": o.pos}
	return {}


## Cristal: Elétrico carrega com um inimigo colado nele (faísca) e nenhum aliado.
func _charge_shot(f: BattleFighter, mv: Dictionary, me: Vector3, reach: float) -> Dictionary:
	if String(mv.get("type", "")) != "electric":
		return {}
	for o in items:
		if o.kind != "crystal" or float(o.charge_t) > 0.0:
			continue
		var d := _flat(o.pos - me).length()
		if d > reach or d < SPARK_R + 1.0:
			continue
		if not _side_near(f, o.pos, SPARK_R - 0.1, true):
			continue
		if _side_near(f, o.pos, SPARK_R + 0.5, false):
			continue
		if _clear_to(me, o):
			return {"what": "crystal_charge", "pos": o.pos}
	return {}


# --- Por quadro ---


func tick(dt: float) -> void:
	if items.is_empty() and berries.is_empty() and swarms.is_empty() and clouds.is_empty():
		return
	_t += dt
	for o in items.duplicate():
		o.cd = maxf(float(o.cd) - dt, 0.0)
		match String(o.kind):
			"tree":
				_tick_tree(o, dt)
			"log":
				_tick_log(o, dt)
			"voltorb":
				_tick_voltorb(o, dt)
			"bush":
				_tick_bush(o, dt)
			"crystal":
				_tick_crystal(o, dt)
			"boulder":
				_tick_boulder(o, dt)
			"geyser":
				_tick_geyser(o, dt)
			"hive":
				o.rest_t = maxf(float(o.rest_t) - dt, 0.0)
			"mushroom":
				_tick_mushroom(o, dt)
	_tick_berries(dt)
	_tick_swarms(dt)
	_tick_clouds(dt)
	_push_out()


## Corpo sólido: tira o lutador de dentro (quem voa passa por cima do que é baixo).
func _push_out() -> void:
	for f in arena.fighters:
		if not is_instance_valid(f) or not f.active() or f.motion == "tunnel":
			continue
		for o in items:
			if not SOLID_R.has(o.kind):
				continue
			if f.height() > float(COVER_H.get(o.kind, 0.9)):
				continue
			var d := _flat(f.position - o.pos)
			var lim: float = float(SOLID_R[o.kind]) + BODY_R
			if d.length() >= lim:
				continue
			if d.length() < 0.001:
				d = Vector3.RIGHT
			f.position += d.normalized() * (lim - d.length())


# --- IA ---


## Tiro num objeto (BattleAI._free_fire, modo de energia): Voltorb ao lado do inimigo, árvore que cai
## em cima dele, tabela no cristal com o alvo escondido. Solta o golpe e devolve true.
static func ai_shot(ai, mode: int) -> bool:
	var f: BattleFighter = ai.f
	var ter = f.arena.get("terrain") if f.arena else null
	if ter == null or ter.get("props") == null or ter.props.items.is_empty():
		return false
	return ter.props._ai_shot(ai, mode)


func _ai_shot(ai, mode: int) -> bool:
	var f: BattleFighter = ai.f
	if not f.can_act() or f.gcd_t > 0.0 or not is_instance_valid(f.opponent):
		return false
	var st: Dictionary = _ai_state(f)
	if _t < float(st.next):
		return false
	st.next = _t + AI_EVERY
	var me := _flat(f.position)
	for id in f.moves:
		var mv := Dex.move(String(id))
		if not String(mv.get("kind", "")) in AI_KINDS or float(mv.get("power", 0)) <= 0.0:
			continue
		if not ai._ready(String(id)):
			continue
		var reach: float = ai.move_reach(String(id)) * 0.95
		var shot := _voltorb_shot(f, mv, me, reach)
		for fn in [_tree_shot, _boulder_shot, _hive_shot, _geyser_shot, _spore_shot, _charge_shot]:
			if shot.is_empty():
				shot = fn.call(f, mv, me, reach)
		if (
			shot.is_empty()
			and String(mv.kind) == "beam"
			and (ai._los_blocked(String(id), f.opponent) or arena.rng.randf() < AI_BANK_OPEN)
		):
			shot = _bank_shot(f, mv, me)
		if shot.is_empty():
			continue
		f.set_meta("prop_aim", {"id": String(id), "pos": shot.pos, "until": _t + 3.0})
		if not f.arena.moves.use(f, String(id)):
			f.remove_meta("prop_aim")
			continue
		ai.intent = String(id)
		ai.why = "prop_" + String(shot.what)
		ai.recover_t = BattleAI.RECOVER
		ai.note_used(String(id))
		ai._after_fire(mode)
		st.next = _t + AI_SHOT_CD
		_tele("prop_ai_shot", {"who": _uid(f), "what": shot.what, "move": String(id)})
		return true
	return false


func _ai_state(f: BattleFighter) -> Dictionary:
	var k := f.get_instance_id()
	if not _ai.has(k):
		_ai[k] = {"next": 0.0, "chase": 0.0, "chase_cd": 0.0}
	return _ai[k]


## A linha de `me` até o objeto `o` está livre até ele.
func _clear_to(me: Vector3, o: Dictionary) -> bool:
	var d := _flat(o.pos - me).length()
	return terrain.shot_block(me, o.pos) >= d - float(SHOT_R.get(o.kind, 0.5)) - 0.35


func _voltorb_shot(f: BattleFighter, mv: Dictionary, me: Vector3, reach: float) -> Dictionary:
	var type := String(mv.get("type", ""))
	if not type in ["fire", "electric"] and float(mv.get("power", 0)) < STRONG:
		return {}
	for o in items:
		if o.kind != "voltorb" or o.state != "":
			continue
		var d := _flat(o.pos - me).length()
		if d > reach or d < VOLT_R + AI_SAFE:
			continue
		if (
			not _side_near(f, o.pos, VOLT_R + 0.2, true)
			or _side_near(f, o.pos, VOLT_R + 0.3, false)
		):
			continue
		if _clear_to(me, o):
			return {"what": "voltorb", "pos": o.pos}
	return {}


## Algum inimigo (`foes`) ou aliado/eu mesmo (`not foes`) a até `r` m de `p`.
func _side_near(f: BattleFighter, p: Vector3, r: float, foes: bool) -> bool:
	for g in arena.fighters:
		if not is_instance_valid(g) or not g.active():
			continue
		if (g.side != f.side) != foes:
			continue
		if _flat(g.position - p).length() <= r:
			return true
	return false


func _tree_shot(f: BattleFighter, mv: Dictionary, me: Vector3, reach: float) -> Dictionary:
	var type := String(mv.get("type", ""))
	var strong := type in BREAKERS and float(mv.get("power", 0)) >= TREE_STRONG
	if type != "fire" and not strong:
		return {}
	for o in items:
		if o.kind != "tree" or o.state != "":
			continue
		var to := _flat(o.pos - me)
		if to.length() > reach or to.length() < 1.0:
			continue
		var d := to.normalized()
		var foe_in := false
		var ally_in := false
		for g in arena.fighters:
			if not is_instance_valid(g) or not g.active():
				continue
			var rel := _flat(g.position - o.pos)
			var along := rel.dot(d)
			if along < 0.4 or along > TREE_H + 0.3 or (rel - d * along).length() > TREE_W + 0.5:
				continue
			if g.side != f.side:
				foe_in = true
			else:
				ally_in = true
		if foe_in and not ally_in and _clear_to(me, o):
			return {"what": "tree", "pos": o.pos}
	return {}


## Tabela: mira num ponto do cristal de onde o raio refletido chega no alvo sem nada no meio.
func _bank_shot(f: BattleFighter, mv: Dictionary, me: Vector3) -> Dictionary:
	var opp: BattleFighter = f.opponent
	var r := float(mv.get("range", 14.0))
	var w := float(mv.get("width", 0.8))
	var tgt := _flat(opp.position)
	for o in items:
		if o.kind != "crystal":
			continue
		var to := _flat(o.pos - me)
		if to.length() > r - 1.0 or to.length() < 1.0 or not _clear_to(me, o):
			continue
		var side := Vector3(-to.z, 0, to.x).normalized()
		for k in [0.0, 0.25, -0.25, 0.5, -0.5, 0.7, -0.7]:
			var aim: Vector3 = o.pos + side * float(SHOT_R.crystal) * k
			var d := _flat(aim - me).normalized()
			var out := reflect_dir(me, d, o.pos)
			if out == Vector3.ZERO:
				continue
			var hit: Vector3 = me + d * _ray_circle(me, d, o.pos, SHOT_R.crystal)
			var rel := tgt - hit
			var along := rel.dot(out)
			if along < 0.5 or along > r - _flat(hit - me).length():
				continue
			if (rel - out * along).length() > w / 2.0 + 0.3:
				continue
			if terrain.shot_block(hit + out * 0.55, tgt) < INF:
				continue
			return {"what": "crystal", "pos": aim}
	return {}


## Direção do golpe que a IA mirou num objeto (BattleMoves.deliver). Sem mira guardada, `dir`.
func aim_dir(user: BattleFighter, mv: Dictionary, dir: Vector3) -> Vector3:
	if not user.has_meta("prop_aim"):
		return dir
	var m: Dictionary = user.get_meta("prop_aim")
	if String(m.id) != String(mv.get("id", "")) or _t > float(m.until):
		if _t > float(m.until):
			user.remove_meta("prop_aim")
		return dir
	user.remove_meta("prop_aim")
	var d := _flat(m.pos - user.position)
	return d.normalized() if d.length() > 0.05 else dir


## Andar da IA (BattleAI._energy_steer): com HP ou energia baixa vai na Oran mais perto se o caminho
## está livre de inimigos (no máx. BERRY_CHASE s por vez). INF = segue a IA normal.
static func steer(ai, d: float) -> Vector3:
	var f: BattleFighter = ai.f
	var ter = f.arena.get("terrain") if f.arena else null
	if ter == null or ter.get("props") == null or ter.props.berries.is_empty():
		return Vector3.INF
	return ter.props._berry_steer(ai, d)


func _berry_steer(ai, d: float) -> Vector3:
	var f: BattleFighter = ai.f
	var st: Dictionary = _ai_state(f)
	if _t < float(st.chase_cd):
		return Vector3.INF
	var low_hp := float(f.hp) <= float(f.max_hp) * BERRY_HP and not _energy_only(f)
	var low_en := f.energy_mode and f.pp_max < BERRY_LOW_EN
	if not low_hp and not low_en:
		st.chase = 0.0
		return Vector3.INF
	var me := _flat(f.position)
	var best := {}
	var best_d := BERRY_SEEK
	for b in berries:
		var bd := _flat(b.pos - me).length()
		if bd < best_d and _safe_path(f, me, b.pos):
			best_d = bd
			best = b
	if best.is_empty():
		st.chase = 0.0
		return Vector3.INF
	if float(st.chase) <= 0.0:
		st.chase = _t
		_tele("prop_ai_berry", {"who": _uid(f)})
	elif _t - float(st.chase) > BERRY_CHASE:
		st.chase = 0.0
		st.chase_cd = _t + BERRY_CHASE_CD
		return Vector3.INF
	ai.tag = "berry"
	ai._fly(d)
	f.sprinting = best_d > 2.0 and f.can_sprint(true)
	var to: Vector3 = best.pos - me
	return to.normalized() * clampf(to.length(), 0.4, 1.0)


## Nenhum inimigo a menos de BERRY_SAFE m do caminho até a fruta, nem mais perto dela que eu.
func _safe_path(f: BattleFighter, a: Vector3, b: Vector3) -> bool:
	var ab := b - a
	for g in arena.targets_of(f):
		var p := _flat(g.position)
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		if (p - (a + ab * t)).length() < BERRY_SAFE:
			return false
		if (p - b).length() < (a - b).length():
			return false
	return true


# --- Visual (só fora do fast_sim) ---


func _build(o: Dictionary) -> void:
	if terrain.lattice:
		_build_voxel(o)
		return
	var root := Node3D.new()
	root.name = "Prop_%s" % o.kind
	root.position = o.pos
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(int(o.pos.x * 100.0), int(o.pos.z * 100.0)))
	match String(o.kind):
		"tree":
			root.add_child(terrain._frustum(0.26, 0.18, 1.6, ptex("bark"), 7, 1.2))
			var mat := BattleTerrain._mat(ptex("leaves"), 1.4)
			for c in [
				[0.85, Vector3(0, 1.9, 0)],
				[0.65, Vector3(0.35, 2.3, -0.2)],
				[0.6, Vector3(-0.3, 2.15, 0.3)]
			]:
				root.add_child(_ball(float(c[0]), c[1], mat))
			o.canopy_mat = mat
		"bush":
			var mat := BattleTerrain._mat(ptex("bush"), 1.6)
			for i in 3:
				var a := TAU * i / 3.0 + rng.randf()
				var b := _ball(0.42, Vector3(cos(a) * 0.2, 0.3, sin(a) * 0.2), mat)
				b.scale = Vector3(1.0, 0.75, 1.0)
				root.add_child(b)
			o.canopy_mat = mat
		"voltorb":
			var mi := MeshInstance3D.new()
			var s := SphereMesh.new()
			s.radius = 0.38
			s.height = 0.76
			s.radial_segments = 12
			s.rings = 6
			mi.mesh = s
			mi.material_override = BattleTerrain._mat(ptex("voltorb"), 1.0, false)
			mi.position.y = 0.38
			mi.rotation.y = rng.randf() * TAU
			root.add_child(mi)
		"crystal":
			var mat := BattleTerrain._mat(ptex("crystal"), 1.0)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color = Color(1, 1, 1, 0.88)
			mat.metallic_specular = 1.0
			mat.roughness = 0.2
			o.crystal_mat = mat
			for c in [
				[0.2, 1.35, Vector3.ZERO, 0.0],
				[0.13, 0.85, Vector3(0.22, 0, 0.1), 0.35],
				[0.12, 0.7, Vector3(-0.18, 0, -0.14), -0.4]
			]:
				var mi := MeshInstance3D.new()
				var cm := CylinderMesh.new()
				cm.bottom_radius = float(c[0])
				cm.top_radius = float(c[0]) * 0.25
				cm.height = float(c[1])
				cm.radial_segments = 6
				cm.rings = 1
				mi.mesh = cm
				mi.material_override = mat
				mi.position = c[2] + Vector3(0, float(c[1]) * 0.5, 0)
				mi.rotation.z = float(c[3])
				root.add_child(mi)
		"boulder":
			var b := _ball(BOULDER_R, Vector3.ZERO, BattleTerrain._mat(ptex("boulder"), 1.0))
			b.scale = Vector3(1.0, 1.25, 1.0)  # _ball achata (altura 1,6 x raio): volta a ser redonda
			root.add_child(b)
			root.position.y = float(o.get("y", 0.0)) + BOULDER_R  # gira em volta do centro
		"geyser":
			root.add_child(terrain._disc(float(o.r), ptex("vent"), 1.0))
			_build_steam(o)
		"hive":
			root.add_child(terrain._frustum(0.32, 0.36, 0.45, ptex("bark"), 7, 1.0))
			var h := _ball(0.32, Vector3(0, 0.72, 0), BattleTerrain._mat(ptex("hive"), 1.0, false))
			h.scale = Vector3(1.0, 1.5, 1.0)
			root.add_child(h)
		"mushroom":
			var mat := BattleTerrain._mat(ptex("mushroom"), 1.0, false)
			var stem := BattleTerrain._mat(ptex("stem"), 1.0, false)
			for i in 5:
				var a := TAU * i / 5.0 + rng.randf()
				var d := rng.randf_range(0.15, float(o.r) * 0.75)
				var at := Vector3(cos(a) * d, 0, sin(a) * d)
				var k := rng.randf_range(0.7, 1.2)
				var st := _ball(0.05 * k, at + Vector3(0, 0.1 * k, 0), stem)
				st.scale = Vector3(1.0, 3.0, 1.0)
				root.add_child(st)
				root.add_child(_ball(0.17 * k, at + Vector3(0, 0.22 * k, 0), mat))
	o.node = root
	arena.add_child(root)


## Quadra voxel (BattleTerrain.lattice): o objeto em voxel (ArenaPropsVox); copa e cristal com
## material próprio (tint e flash) nos mesmos campos de antes.
func _build_voxel(o: Dictionary) -> void:
	var root := ArenaPropsVox.prop(o, terrain.scenario)
	if root == null:
		return
	if root.has_meta("canopy"):
		o.canopy_mat = root.get_meta("canopy")
	if root.has_meta("crystal"):
		o.crystal_mat = root.get_meta("crystal")
	if o.kind == "geyser":
		_build_steam(o)
	o.node = root
	arena.add_child(root)


## Vapor do gêiser: coluna translúcida que aparece no aviso e na erupção.
func _build_steam(o: Dictionary) -> void:
	var steam := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = STEAM_R * 1.1
	cm.bottom_radius = STEAM_R * 0.6
	cm.height = STEAM_H
	cm.radial_segments = 10
	cm.rings = 1
	steam.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.92, 0.96, 1.0, 0.45)
	steam.material_override = mat
	steam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	steam.position = o.pos + Vector3(0, STEAM_H * 0.5, 0)
	steam.visible = false
	arena.add_child(steam)
	o.steam = steam


## Enxame: bolinhas amarelas e pretas girando.
func _swarm_node() -> Node3D:
	var root := Node3D.new()
	var mat := BattleTerrain._mat(ptex("hive"), 1.0, false)
	for i in 7:
		var a := TAU * i / 7.0
		root.add_child(_ball(0.07, Vector3(cos(a) * 0.4, 0.15 * sin(a * 3.0), sin(a) * 0.4), mat))
	return root


## Nuvem de esporo: bola roxa translúcida do tamanho de SPORE_R.
func _cloud_node() -> Node3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = SPORE_R
	s.height = SPORE_R
	s.radial_segments = 12
	s.rings = 4
	mi.mesh = s
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.8, 0.55, 0.95, 0.35)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _ball(r: float, at: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 1.6
	s.radial_segments = 8
	s.rings = 4
	mi.mesh = s
	mi.material_override = mat
	mi.position = at
	return mi


## Texturas de pixel art (32 x 32) geradas uma vez.
static func ptex(kind: String) -> Texture2D:
	if _tex.has(kind):
		return _tex[kind]
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("prop_" + kind)
	for y in 32:
		for x in 32:
			img.set_pixel(x, y, _px(kind, x, y, rng))
	var t := ImageTexture.create_from_image(img)
	_tex[kind] = t
	return t


static func _px(kind: String, x: int, y: int, rng: RandomNumberGenerator) -> Color:
	var n := rng.randf()
	match kind:
		"bark":
			var pal := [Color("3d2614"), Color("553720"), Color("6e4a2c"), Color("8a6240")]
			if (x * 5 + int(y / 4)) % 7 == 0:
				return pal[0]
			return pal[1] if n < 0.45 else (pal[2] if n < 0.9 else pal[3])
		"leaves", "bush":
			var pal := (
				[Color("1e5a24"), Color("2d7a30"), Color("44993d"), Color("6cba52")]
				if kind == "leaves"
				else [Color("1a4a20"), Color("265f29"), Color("357634"), Color("4f8f40")]
			)
			if kind == "bush" and (x * 7 + y * 11) % 37 == 0:
				return Color("3a6fd8")  # frutinhas azuis
			if (x + y * 3) % 9 == 0 and n < 0.6:
				return pal[0]
			return pal[1] if n < 0.4 else (pal[2] if n < 0.85 else pal[3])
		"voltorb":
			# Esfera: v de cima (0) para baixo (31). Vermelho em cima, faixa preta, branco embaixo, olhos
			# fechados (traço preto) na frente.
			if y >= 15 and y <= 16:
				return Color("1a1a1a")
			if y < 15:
				if y >= 10 and y <= 11 and ((x >= 4 and x <= 8) or (x >= 12 and x <= 16)):
					return Color("1a1a1a")
				if y < 4 and (x + y) % 6 == 0:
					return Color("ff8a80")
				return Color("d8322a") if n < 0.85 else Color("b82620")
			return Color("f2f2f2") if n < 0.85 else Color("d6d6dc")
		"crystal":
			var pal := [Color("3a8fb8"), Color("5cc0e0"), Color("9fe4f6"), Color("e8fbff")]
			var stripe := (x + y * 2) % 11
			if stripe == 0:
				return pal[3]
			if stripe < 3:
				return pal[2]
			return pal[1] if n < 0.7 else pal[0]
		"boulder":
			var pal := [Color("5a5550"), Color("78716a"), Color("948c82"), Color("b0a89c")]
			if (x * 3 + y * 5) % 13 == 0:
				return pal[0]
			return pal[1] if n < 0.45 else (pal[2] if n < 0.9 else pal[3])
		"vent":
			var c := Vector2(x - 15.5, y - 15.5).length()
			if c < 4.0:
				return Color("1c2a33")
			if c < 7.0:
				return Color("6fb7c9") if n < 0.6 else Color("a6dde8")
			return Color("5e5a55") if n < 0.6 else Color("4a4642")
		"hive":
			if y % 6 < 2:
				return Color("2a2216")
			return Color("e0b030") if n < 0.75 else Color("c8962a")
		"mushroom":
			if (x * 7 + y * 3) % 11 == 0 or (x * 5 + y * 9) % 17 == 0:
				return Color("f4eee4")
			return Color("a8509a") if n < 0.7 else Color("8a3e86")
		"stem":
			return Color("e8e0cc") if n < 0.7 else Color("d2c8b0")
		"oran":
			if y < 6 and x >= 13 and x <= 18:
				return Color("3f8a34")  # folhinha
			return Color("2f5fd0") if n < 0.75 else Color("5a86ea")
	return Color.WHITE

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
## Oran: cura BERRY_HEAL do HP ou dá BERRY_EN de energia (o que faltar mais).
## IA (estáticos, chamados de BattleAI): ai_shot (tiro no objeto: Voltorb perto do inimigo, derrubar a
## árvore em cima dele, tabela no cristal) e steer (ir na fruta com HP/energia baixa). Os anéis de
## aviso entram em arena.telegraph com side -1 (os dois lados desviam).

const ORDER := ["tree", "crystal", "voltorb", "bush"]  ## colocados depois do relevo (SCENARIOS)
## Tamanho por tipo, como BattleTerrain.SIZES: [raio mín., raio máx., altura mín., altura máx.]. O raio
## aqui é o de espaço no cenário (copa, brilho); o corpo sólido é SOLID_R.
const SIZES := {
	"tree": [0.9, 0.9, 0.0, 0.0],
	"crystal": [0.6, 0.6, 0.0, 0.0],
	"voltorb": [0.5, 0.5, 0.0, 0.0],
	"bush": [0.7, 0.7, 0.0, 0.0],
}
## Corpo sólido (lutador não atravessa), raio contra tiro e altura da cobertura (0 = não cobre).
const SOLID_R := {"tree": 0.4, "crystal": 0.45, "voltorb": 0.42, "bush": 0.5}
const SHOT_R := {"tree": 0.55, "crystal": 0.45, "voltorb": 0.42}
const COVER_H := {"tree": 2.6, "crystal": 1.4, "voltorb": 0.85}
const BODY_R := 0.4
const STRONG := 80.0
const HIT_CD := 0.3
## Árvore.
const TREE_H := 2.6
const TREE_NEAR := 2.0
const TREE_REGEN := 1.2
const TREE_BURN := 2.0
const TREE_WARN := 1.0  ## aviso (linha no chão) no fim da queima
const TREE_TIP := 0.7  ## golpe forte: aviso até cair
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
const BERRY_HEAL := 1.0 / 8.0
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
## IA.
const AI_EVERY := 0.5  ## olha as chances de tiro no objeto a cada AI_EVERY s
const AI_SHOT_CD := 6.0  ## depois de atirar num objeto
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
	if _vis():
		_build(o)
	items.append(o)


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
		if not SHOT_R.has(o.kind) or o.kind == "tree" and o.state == "fallen":
			continue
		if p.y < float(COVER_H[o.kind]) and _flat(p - o.pos).length() < float(SHOT_R[o.kind]):
			return true
	return false


func has_cover() -> bool:
	for o in items:
		if SHOT_R.has(o.kind):
			return true
	return false


## Esconderijos para BattleTerrain.cover_spot: árvores e cristais (Voltorb não: ele explode).
func cover_cands() -> Array:
	var out: Array = []
	for o in items:
		if o.kind in ["tree", "crystal"]:
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
	for o in items.duplicate():
		if o.kind == "log" or float(o.cd) > 0.0:
			continue
		var reach := float(SHOT_R.get(o.kind, SOLID_R.get(o.kind, 0.5))) + 0.25 + radius * 0.5
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
	arena.popup(o.pos + Vector3(0, 1.5, 0), "Refletiu!", Color(0.6, 0.95, 1.0))
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
	var breaker := type in ["rock", "fighting"]
	match String(o.kind):
		"tree":
			if o.state != "":
				return
			if type == "fire":
				_ignite_tree(o, user)
			elif breaker and power >= STRONG:
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
						o.pos + Vector3(0, 1.5, 0), "Cristal carregado!", Dex.type_color("electric")
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


# --- Árvore ---


func _ignite_tree(o: Dictionary, user: BattleFighter) -> void:
	o.state = "burn"
	o.t = TREE_BURN
	o.by = user
	o.fall_dir = _fall_dir(o, user)
	o.warned = false
	_tele("tree_ignite", {"by": _uid(user)})
	arena.popup(o.pos + Vector3(0, 2.2, 0), "A árvore pegou fogo!", Dex.type_color("fire"))
	if is_instance_valid(o.get("canopy_mat")):
		o.canopy_mat.albedo_color = Color(1.0, 0.55, 0.3)


func _tip_tree(o: Dictionary, user: BattleFighter, secs: float, cause: String) -> void:
	o.state = "tip"
	o.t = secs
	o.by = user
	o.cause = cause
	if not o.has("fall_dir"):
		o.fall_dir = _fall_dir(o, user)
	_warn_line(o, secs)
	arena.popup(o.pos + Vector3(0, 2.2, 0), "Vai cair!", Color(1.0, 0.8, 0.5))


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
		f.popup("-%d Árvore caiu!" % n, Color(0.75, 0.55, 0.3), 1.0, 0.7)
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
	arena.say("A árvore caiu!")
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
			o.canopy_mat.albedo_color = (
				Color(0.45, 0.35, 0.25) if o.get("cause", "fire") == "fire" else Color.WHITE
			)


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
			f.popup("Bateu no tronco!", Color(0.8, 0.65, 0.45), 0.8, 0.5)
			_tele("log_block", {"who": _uid(f)})


# --- Voltorb ---


func _wake(o: Dictionary, user: BattleFighter) -> void:
	o.state = "armed"
	o.t = VOLT_WARN
	o.by = user
	arena.telegraph({"kind": "disc", "side": -1, "t": VOLT_WARN, "at": o.pos, "r": VOLT_R})
	arena.popup(o.pos + Vector3(0, 1.0, 0), "Voltorb acordou!", Color(1.0, 0.4, 0.3), 1.1)
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
		f.popup("-%d Explosão!" % n, Color(1.0, 0.5, 0.3), 1.1, 0.7)
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
	arena.say("O Voltorb explodiu!")
	if _vis():
		PixelFx.pop(arena, "fire", o.pos + Vector3(0, 0.6, 0), VOLT_R * 1.6, 0.5)
		PixelFx.pop(arena, "electric", o.pos + Vector3(0, 0.5, 0), VOLT_R * 1.2, 0.4)
		if arena.has_method("cut_in") and not hits.is_empty():
			arena.cut_in("BUM!", Color(1.0, 0.45, 0.3))
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
	arena.popup(o.pos + Vector3(0, 1.0, 0), "O arbusto queimou!", Dex.type_color("fire"))
	if _vis():
		PixelFx.pop(arena, "fire", o.pos + Vector3(0, 0.5, 0), 1.4, 0.5)
		if is_instance_valid(o.get("node")):
			o.node.scale = Vector3(0.7, 0.5, 0.7)
		if is_instance_valid(o.get("canopy_mat")):
			o.canopy_mat.albedo_color = Color(0.35, 0.28, 0.22)


func _tick_bush(o: Dictionary, dt: float) -> void:
	if float(o.burnt_t) > 0.0:
		o.burnt_t = float(o.burnt_t) - dt
		if float(o.burnt_t) <= 0.0:
			o.grow_t = arena.rng.randf_range(BUSH_EVERY.x, BUSH_EVERY.y)
			_tele("bush_regrow", {})
			if is_instance_valid(o.get("node")):
				o.node.scale = Vector3.ONE
			if is_instance_valid(o.get("canopy_mat")):
				o.canopy_mat.albedo_color = Color.WHITE
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
	if _vis():
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


## Nada a ganhar (HP cheio e barra cheia): deixa a fruta no chão.
func _wants_berry(f: BattleFighter) -> bool:
	return f.hp < f.max_hp or (f.energy_mode and f.pp_max < BattleEnergy.MAX - 1.0)


func _eat(f: BattleFighter, b: Dictionary) -> void:
	var hp_k := float(f.hp) / maxf(f.max_hp, 1)
	var en_k := f.pp_max / BattleEnergy.MAX if f.energy_mode else 1.0
	var gain := "hp" if hp_k <= en_k else "energy"
	var n := 0
	if gain == "hp":
		var before: int = f.hp
		f.heal(maxi(1, int(float(f.max_hp) * BERRY_HEAL)))
		n = int(f.hp) - before
		f.popup("+%d Oran" % n, Color(0.5, 1.0, 0.55), 0.9, 0.3, "heal")
	else:
		var e0: float = f.pp_max
		f.pp_max = minf(f.pp_max + BERRY_EN, BattleEnergy.MAX)
		n = int(round(f.pp_max - e0))
		f.popup("+%d energia (Oran)" % n, Color(0.55, 0.95, 0.6), 0.9, 0.3, "heal")
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
		f.popup("-%d Faísca" % n, Dex.type_color("electric"), 0.8, 0.3)
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
	arena.popup(o.pos + Vector3(0, 1.2, 0), "O cristal quebrou!", Color(0.7, 0.95, 1.0))
	if _vis():
		PixelFx.pop(arena, "stone", o.pos + Vector3(0, 0.6, 0), 1.4, 0.4)
	_remove(o)


func _remove(o: Dictionary) -> void:
	items.erase(o)
	for k in ["node", "ring"]:
		if is_instance_valid(o.get(k)):
			o[k].queue_free()


# --- Por quadro ---


func tick(dt: float) -> void:
	if items.is_empty() and berries.is_empty():
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
	_tick_berries(dt)
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
		if shot.is_empty():
			shot = _tree_shot(f, mv, me, reach)
		if (
			shot.is_empty()
			and String(mv.kind) == "beam"
			and ai._los_blocked(String(id), f.opponent)
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
			not _side_near(f, o.pos, VOLT_R * 0.85, true)
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
	var strong := type in ["rock", "fighting"] and float(mv.get("power", 0)) >= STRONG
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
			if along < 0.4 or along > TREE_H or (rel - d * along).length() > TREE_W + 0.2:
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
	var low_hp := float(f.hp) <= float(f.max_hp) * BERRY_HP
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
	o.node = root
	arena.add_child(root)


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
		"oran":
			if y < 6 and x >= 13 and x <= 18:
				return Color("3f8a34")  # folhinha
			return Color("2f5fd0") if n < 0.75 else Color("5a86ea")
	return Color.WHITE

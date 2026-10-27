class_name MoveFx3D
extends Fx3DKit
## Efeitos 3D de todos os golpes do modo de energia (partículas, luzes, raios, feixes, cortes, ondas).
## Cada golpe é montado pela entrega (kind), pelo tipo (paleta e matéria, Fx3DKit.TYPES) e pela
## força (tier: fraco = simples, forte = mais camadas, luz e tremor). Golpes marcantes têm receita
## própria em MoveFx3DSig. Os avisos no chão saíram: a carga e a preparação do efeito avisam.
## Só visual: nada aqui muda dano, alcance ou tempo.

## Golpes de corte (fita em arco), mordida (duas fitas que fecham) e pancada (onda de choque).
const SLASH_WORDS := [
	"slash",
	"cut",
	"claw",
	"scratch",
	"swipe",
	"blade",
	"scissor",
	"sword",
	"razor",
	"fury_cutter",
	"cross_poison",
	"leaf_blade",
	"psycho_cut",
	"aerial_ace",
	"night_slash",
	"false_swipe",
	"x_scissor",
	"sacred",
	"kowtow",
	"ceaseless",
	"aqua_cutter",
	"stone_axe",
	"dual_chop"
]
const BITE_WORDS := ["bite", "fang", "crunch", "jaw", "chomp", "hyper_fang", "super_fang"]
const CLAW_WORDS := ["claw", "scratch", "fury_swipes", "swipe"]

var sig: MoveFx3DSig
var _charging := {}  ## id do lutador -> id do golpe em preparação


func _init(v: BattleVfx) -> void:
	super(v)
	sig = MoveFx3DSig.new(self)


## Liga só no modo de energia, com a arena na árvore e fora da bateria rápida.
func on() -> bool:
	if not vfx.enabled or not is_instance_valid(arena) or not arena.is_inside_tree():
		return false
	var o = arena.get("opts")
	if o is Dictionary and bool(o.get("fast_sim", false)):
		return false
	return arena.has_method("energy_on") and arena.energy_on()


func tick(dt: float) -> void:
	tick_events(dt)


static func type_of(mv: Dictionary) -> String:
	return String(mv.get("type", "normal"))


static func _has_word(id: String, words: Array) -> bool:
	for w in words:
		if id.contains(String(w)):
			return true
	return false


## Força visual: 0.6 (fraco) .. 1.6 (muito forte).
static func kpow(t: int) -> float:
	return [0.75, 0.7, 0.95, 1.2, 1.5][clampi(t, 0, 4)]


func mouth(user: BattleFighter, gd: Vector3) -> Vector3:
	return center(user, 0.5) + gd * 0.35


# --- Preparação (carga antes de soltar) ---


## Chamado quando o golpe começa a preparar (Pikachu carregando o Thunderbolt...).
func prepare(user: BattleFighter, mv: Dictionary, secs: float) -> void:
	if not on() or not is_instance_valid(user) or secs < 0.08:
		return
	_charging[user.get_instance_id()] = String(mv.get("id", ""))
	if sig.prepare(user, mv, secs):
		return
	var kind := String(mv.get("kind", ""))
	var physical := kind in ["dash", "arc", "multi_arc", "whip"]
	charge(user, mv, secs, kpow(tier(mv)) * (0.75 if physical else 1.0), physical)


## O lutador ainda está carregando este golpe?
func still_charging(user: BattleFighter, id: String) -> bool:
	return (
		is_instance_valid(user)
		and user.is_inside_tree()
		and user.active()
		and (user.prepare_id == id or user.prepare_t <= 0.0)
	)


## Carga em volta do usuário: partículas que convergem, orbe que cresce, luz que sobe e a matéria
## do tipo (faíscas e raios, chamas aos pés, gotas girando, folhas, anéis psíquicos...).
func charge(user: BattleFighter, mv: Dictionary, secs: float, k := 1.0, physical := false) -> void:
	if not is_instance_valid(user) or secs <= 0.05:
		return
	var type := type_of(mv)
	var t := tier(mv)
	var id := String(mv.get("id", ""))
	var h := height(user)
	var off := Vector3(0, h * 0.5, 0)
	var alive := func() -> bool: return still_charging(user, id)
	# Partículas que vêm de fora e entram no corpo.
	var conv := trail_opts(type, 0.8 * k)
	conv.follow = user
	conv.speed = [0.2, 0.8]
	var p := emitter(
		Vector3.ZERO,
		secs,
		(18.0 + 14.0 * t) * k,
		conv,
		func():
			if not alive.call():
				return null
			var d := rand_dir()
			d.y = absf(d.y) * 0.6
			return (
				user.global_position
				+ off
				+ d.normalized() * randf_range(1.0, 1.6) * maxf(h, 0.8) * k
			)
	)
	p.attract_node = user
	p.attract_off = off
	p.attract_k = 22.0
	p.kill_near = 0.18
	p.gravity = Vector3.ZERO
	if type in ["water", "grass", "psychic", "fairy", "dragon", "ghost"]:
		p.orbit_k = 14.0
	# Orbe/brilho no corpo que cresce.
	if not physical:
		shell(
			center(user, 0.5),
			0.05,
			(0.22 + 0.07 * t) * k * maxf(h, 0.8),
			mid(type, 0.9),
			secs + 0.08,
			{
				"follow": user,
				"off": off,
				"fade_in": 0.3,
				"fade_out": 0.15,
				"noise": 0.5,
				"phase": 3.0
			}
		)
		emitter(
			Vector3.ZERO,
			secs,
			30.0,
			{
				"follow": user,
				"shape": Fx3D.Shape.GLOW,
				"life": [0.12, 0.2],
				"size": [0.5 * k, 0.3 * k],
				"col": [core(type, 0.5), mid(type, 0.0)],
				"speed": [0.0, 0.1]
			},
			func(): return center(user, 0.5) if alive.call() else null
		)
	# Luz que sobe junto.
	light(
		center(user, 0.5),
		lightc(type),
		(1.5 + 1.2 * t) * k,
		3.0 + t,
		secs + 0.1,
		{
			"follow": user,
			"off": off,
			"attack": secs * 0.85,
			"hold": 0.8,
			"flicker": 0.35 if type == "electric" else 0.08
		}
	)
	_charge_flavor(user, type, t, secs, k, physical, alive)


func _charge_flavor(
	user: BattleFighter,
	type: String,
	t: int,
	secs: float,
	k: float,
	physical: bool,
	alive: Callable
) -> void:
	var h := height(user)
	match type:
		"electric":
			repeat(
				0.05,
				secs,
				func(_i: int) -> bool:
					if not alive.call():
						return false
					var c := center(user, 0.5)
					var a := c + rand_dir() * h * randf_range(0.35, 0.7) * k
					var b := c + rand_dir() * h * randf_range(0.35, 0.7) * k
					bolt(a, b, mid(type), 0.03 * k, 0.07, {"segs": 6, "amp": 0.1 * k})
					if randf() < 0.4:
						element(type, a, 3, {"k": 0.6})
					return true
			)
		"fire", "dragon":
			emitter(
				Vector3.ZERO,
				secs,
				40.0 * k,
				_m(
					trail_opts(type, 1.1 * k),
					{"follow": user, "up": 2.4, "flat": true, "r": 0.55 * k, "speed": [0.1, 0.4]}
				),
				func(): return feet(user) if alive.call() else null
			)
		"water", "ice":
			ring(
				feet(user),
				0.3,
				1.1 * k,
				mid(type, 0.7),
				secs,
				{"follow": user, "off": Vector3(0, 0.05, 0), "noise": 0.6, "spin": 3.0}
			)
		"grass", "bug", "fairy":
			var o := trail_opts(type, 1.1 * k)
			o.follow = user
			var q := emitter(
				Vector3.ZERO,
				secs,
				16.0 * k,
				_m(o, {"speed": [0.0, 0.2], "life": [0.6, 0.9]}),
				func():
					return (
						(
							feet(user)
							+ (
								(
									Vector3(randf_range(-1, 1), randf() * h, randf_range(-1, 1))
									. normalized()
								)
								* 1.0
								* k
							)
							+ Vector3(0, h * 0.3, 0)
						)
						if alive.call()
						else null
					)
			)
			q.attract_node = user
			q.attract_off = Vector3(0, h * 0.5, 0)
			q.orbit_k = 26.0
			q.attract_k = 6.0
		"psychic":
			repeat(
				maxf(secs / 3.0, 0.12),
				secs,
				func(_i: int) -> bool:
					if not alive.call():
						return false
					var c := center(user, 0.5)
					ring(
						c,
						1.4 * k,
						0.15,
						mid(type, 0.9),
						0.3,
						{"normal": (cam_pos(c) - c).normalized(), "inner": 0.82}
					)
					return true
			)
		"ground", "rock", "fighting", "normal", "steel":
			emitter(
				Vector3.ZERO,
				secs,
				30.0 * k,
				{
					"follow": user,
					"shape": Fx3D.Shape.SPARK,
					"stretch": 0.08,
					"life": [0.2, 0.35],
					"size": [0.08 * k, 0.03 * k],
					"col": [core(type), mid(type, 0.0)],
					"speed": [2.5, 4.5],
					"dir": Vector3.UP,
					"spread": 0.15,
					"flat": true,
					"r": 0.5 * k
				},
				func(): return feet(user) if alive.call() else null
			)
			if t >= 3 or type in ["ground", "rock"]:
				element(
					"ground" if type != "steel" else "steel",
					feet(user),
					int(6 * k),
					{"dir": Vector3.UP, "spread": 1.2, "speed": [0.6, 1.6], "k": 0.7}
				)
		"ghost", "dark":
			var q2 := emitter(
				Vector3.ZERO,
				secs,
				24.0 * k,
				_m(trail_opts(type, 1.2 * k), {"follow": user, "speed": [0.0, 0.3]}),
				func(): return center(user, 0.5) + rand_dir() * 1.3 * k if alive.call() else null
			)
			q2.attract_node = user
			q2.attract_off = Vector3(0, h * 0.5, 0)
			q2.attract_k = 10.0
			q2.orbit_k = 18.0
		"poison":
			emitter(
				Vector3.ZERO,
				secs,
				20.0 * k,
				_m(
					trail_opts(type, 1.2 * k),
					{"follow": user, "up": 1.2, "flat": true, "r": 0.5 * k}
				),
				func(): return feet(user) if alive.call() else null
			)
		"flying":
			ring(
				center(user, 0.3),
				0.9 * k,
				0.4,
				Color(1, 1, 1, 0.6),
				secs,
				{
					"follow": user,
					"off": Vector3(0, h * 0.3, 0),
					"noise": 0.8,
					"spin": 9.0,
					"inner": 0.9
				}
			)
	if physical and t >= 3:
		ring(feet(user), 0.2, 1.2 * k, mid(type, 0.6), minf(secs, 0.4), {"noise": 0.3})


## Repete fn(i) -> bool a cada `every` s por `secs` s (para quando fn devolve false).
func repeat(every: float, secs: float, fn: Callable, i := 0) -> void:
	if secs <= 0.0:
		return
	if not fn.call(i):
		return
	later(every, repeat.bind(every, secs - every, fn, i + 1))


# --- Ao soltar ---


func cast(user: BattleFighter, mv: Dictionary, dir: Vector3) -> void:
	if not on() or not is_instance_valid(user) or not user.is_inside_tree():
		return
	_charging.erase(user.get_instance_id())
	var gd := gdir(dir)
	if sig.cast(user, mv, gd):
		return
	var kind := String(mv.get("kind", ""))
	var type := type_of(mv)
	var t := tier(mv)
	match kind:
		"projectile", "homing":
			muzzle(user, mv, gd)
		"dash":
			dash(user, mv, gd)
		"arc":
			swing(user, mv, gd, 0)
		"multi_arc":
			var hits := int(mv.get("hits", 3))
			var every := float(mv.get("interval", 0.2))
			for i in hits:
				later(
					every * i,
					func() -> void:
						if is_instance_valid(user) and user.active():
							swing(user, mv, gdir(user.aim_dir()), i)
				)
		"beam":
			charge(user, mv, float(mv.get("windup", 0.6)), kpow(t))
		"aoe_self":
			var w := float(mv.get("windup", 0.4))
			charge(user, mv, w, kpow(t) * 0.9, String(mv.get("category", "")) == "physical")
		"self_buff":
			buff(user, mv)
		"debuff_aoe":
			debuff(user, mv, gd)
		"stream", "aoe_target", "zone", "whip":
			if t >= 1 and kind != "whip":
				muzzle(user, mv, gd, 0.6)
		_:
			muzzle(user, mv, gd, 0.5)


## Clarão na boca ao soltar (projétil, jorro).
func muzzle(user: BattleFighter, mv: Dictionary, gd: Vector3, k := 1.0) -> void:
	var type := type_of(mv)
	var t := tier(mv)
	var at := mouth(user, gd)
	var s := kpow(t) * k
	flash(at, 0.6 * s, core(type, 0.9), 0.12)
	element(
		type,
		at,
		int((4 + 3 * t) * k),
		{"dir": gd, "spread": 0.5, "speed": [2.0, 5.0], "k": 0.7 * s}
	)
	if t >= 2:
		light(at, lightc(type), 2.0 + t, 3.0 + t * 0.5, 0.18)
	if t >= 3:
		ring(at, 0.1, 0.7 * s, mid(type, 0.8), 0.22, {"normal": gd, "inner": 0.8})


# --- Projéteis ---


## Visual do projétil (o nó anda sozinho; tudo aqui segue o nó e some com ele).
func projectile(p: Node3D, mv: Dictionary, dir: Vector3) -> void:
	if not on() or not is_instance_valid(p):
		return
	if sig.projectile(p, mv, gdir(dir)):
		return
	var type := type_of(mv)
	var t := tier(mv)
	var s := kpow(t)
	var status := t == 0
	orb(p, type, s * (0.6 if status else 1.0), t)
	var tr := trail_opts(type, 0.8 * s)
	tr.follow = p
	tr.speed = [0.0, 0.5]
	emitter(
		Vector3.ZERO,
		6.0,
		26.0 + 16.0 * t,
		tr,
		func():
			return (
				p.global_position
				if is_instance_valid(p) and p.is_inside_tree() and not p.get("done")
				else null
			)
	)
	if t >= 2:
		var l := light(
			p.global_position,
			lightc(type),
			1.2 + 0.8 * t,
			2.5 + 0.5 * t,
			6.0,
			{"follow": p, "attack": 0.03, "hold": 0.95}
		)
		if l:
			_die_with(l, p)


## Orbe do projétil com a cara do tipo: miolo, casca e um detalhe (pedra, cristal, folha, bolha...).
func orb(p: Node3D, type: String, s: float, t: int) -> void:
	var r := 0.16 * s
	match type:
		"rock", "ground":
			var m := solid(
				p.global_position,
				{
					"kind": "rock",
					"col": Color(0.55, 0.45, 0.33) if type == "rock" else Color(0.45, 0.32, 0.2),
					"size": r * 2.2,
					"life": 6.0,
					"spin": 8.0,
					"floor": false,
					"follow": p
				}
			)
			_die_with(m, p)
			return
		"ice":
			var m2 := solid(
				p.global_position,
				{
					"kind": "crystal",
					"col": Color(0.78, 0.95, 1.0, 0.9),
					"emit": 1.5,
					"size": r * 2.6,
					"life": 6.0,
					"spin": 10.0,
					"floor": false,
					"follow": p
				}
			)
			_die_with(m2, p)
		"grass":
			for i in 2:
				var m3 := solid(
					p.global_position,
					{
						"kind": "leaf",
						"col": Color(0.4, 0.85, 0.3),
						"emit": 0.4,
						"size": r * 2.4,
						"life": 6.0,
						"spin": 16.0,
						"floor": false,
						"follow": p
					}
				)
				_die_with(m3, p)
			return
		"dark", "ghost":
			var d := shell(
				p.global_position,
				r * 1.6,
				r * 1.8,
				mid(type),
				6.0,
				{"follow": p, "noise": 0.8, "phase": 6.0, "fade_out": 0.02}
			)
			_die_with(d, p)
			var core_c := Color(0.05, 0.0, 0.08, 0.9)
			var e := emitter(
				Vector3.ZERO,
				6.0,
				40.0,
				{
					"follow": p,
					"carry": 1.0,
					"shape": Fx3D.Shape.SMOKE,
					"add": false,
					"life": [0.15, 0.3],
					"size": [r * 2.4, r * 1.6],
					"col": [core_c, Color(0.1, 0.0, 0.15, 0.0)],
					"speed": [0.0, 0.2]
				},
				func():
					return (
						p.global_position if is_instance_valid(p) and p.is_inside_tree() else null
					)
			)
			e.fade_in = 0.0
			return
	var sh := shell(
		p.global_position,
		r,
		r * 1.15,
		mid(type),
		6.0,
		{"follow": p, "noise": 0.4, "phase": 5.0, "fade_out": 0.02}
	)
	_die_with(sh, p)
	var em := emitter(
		Vector3.ZERO,
		6.0,
		50.0,
		{
			"follow": p,
			"carry": 1.0,
			"shape": Fx3D.Shape.GLOW,
			"life": [0.08, 0.14],
			"size": [r * 3.2, r * 2.4],
			"col": [core(type, 0.9), mid(type, 0.3)],
			"speed": [0.0, 0.0],
			"fade_in": 0.0,
			"boost": 2.6
		},
		func(): return p.global_position if is_instance_valid(p) and p.is_inside_tree() else null
	)
	em.fade_in = 0.0
	if type == "electric":
		repeat(
			0.05,
			6.0,
			func(_i: int) -> bool:
				if not is_instance_valid(p) or not p.is_inside_tree() or p.get("done"):
					return false
				var c := p.global_position
				bolt(
					c,
					c + rand_dir() * r * 3.0,
					mid(type),
					0.025,
					0.06,
					{"segs": 4, "amp": 0.06, "core": false}
				)
				return true
		)


## O efeito some quando o nó seguido sai (projétil acertou ou sumiu).
func _die_with(n: Node3D, p: Node3D) -> void:
	if n == null:
		return
	repeat(
		0.03,
		30.0,
		func(_i: int) -> bool:
			if not is_instance_valid(n):
				return false
			if not is_instance_valid(p) or not p.is_inside_tree() or p.get("done"):
				if n is Fx3DMesh:
					var m := n as Fx3DMesh
					m.life = minf(m.life, m.age + 0.06)
				elif n is Fx3DLight:
					var l := n as Fx3DLight
					l.life = minf(l.life, l.age + 0.08)
				return false
			return true
	)


# --- Investida ---


func dash(user: BattleFighter, mv: Dictionary, gd: Vector3) -> void:
	var type := type_of(mv)
	var t := tier(mv)
	var s := kpow(t)
	var secs := clampf(
		float(mv.get("range", 3.0)) / maxf(float(mv.get("speed", 12.0)), 0.1) + 0.15, 0.2, 1.6
	)
	var h := height(user)
	var off := Vector3(0, h * 0.5, 0)
	var live := func():
		return center(user, 0.5) if is_instance_valid(user) and user.is_inside_tree() else null
	# Riscos de velocidade e a matéria do tipo no corpo.
	emitter(
		Vector3.ZERO,
		secs,
		40.0 + 20.0 * t,
		{
			"follow": user,
			"shape": Fx3D.Shape.SPARK,
			"stretch": 0.07,
			"life": [0.12, 0.25],
			"size": [0.06 * s, 0.02],
			"col": [Color(1, 1, 1, 0.9), mid(type, 0.0)],
			"speed": [0.5, 2.0],
			"dir": -gd,
			"spread": 0.3,
			"r": h * 0.45
		},
		live
	)
	if type != "normal" or t >= 3:
		var o := trail_opts(type, 1.0 * s)
		o.follow = user
		o.r = h * 0.35
		emitter(Vector3.ZERO, secs, 24.0 + 14.0 * t, o, live)
	shell(
		center(user, 0.5),
		h * 0.45 * s,
		h * 0.6 * s,
		mid(type, 0.55 + 0.1 * t),
		secs,
		{
			"follow": user,
			"off": off,
			"noise": 0.6,
			"phase": 6.0,
			"s0v": Vector3(h * 0.4, h * 0.55, h * 0.4) * s,
			"s1v": Vector3(h * 0.55, h * 0.65, h * 0.55) * s
		}
	)
	if t >= 2:
		light(
			center(user, 0.5),
			lightc(type),
			1.0 + t,
			2.5 + t * 0.5,
			secs,
			{"follow": user, "off": off, "hold": 0.8}
		)
	element(
		"ground",
		feet(user),
		4 + t,
		{"dir": Vector3.UP - gd, "spread": 0.7, "speed": [0.5, 1.5], "k": 0.6}
	)


# --- Golpes de perto ---


func swing(user: BattleFighter, mv: Dictionary, gd: Vector3, i := 0) -> void:
	var id := String(mv.get("id", ""))
	var type := type_of(mv)
	var t := tier(mv)
	var s := kpow(t)
	var h := height(user)
	var reach := float(mv.get("range", 1.8))
	var c := center(user, 0.5) + gd * minf(reach * 0.55, 1.2)
	var side := gd.cross(Vector3.UP).normalized()
	var col := core(type) if type == "normal" else mid(type)
	if _has_word(id, BITE_WORDS):
		var r := 0.55 * s * maxf(h, 0.8)
		for sgn in [1.0, -1.0]:
			slash(
				c,
				side,
				Vector3.UP * sgn,
				r,
				120.0,
				col,
				0.14 * s,
				0.28,
				{"sweep": 0.45, "tail": 0.9}
			)
			slash(
				c,
				side,
				Vector3.UP * sgn,
				r * 0.82,
				110.0,
				Color.WHITE,
				0.05 * s,
				0.28,
				{"sweep": 0.45, "tail": 0.9}
			)
		later(
			0.12,
			func() -> void:
				flash(c, 0.6 * s, core(type), 0.1)
				element(type, c, 6 + 3 * t, {"k": 0.7 * s})
		)
	elif _has_word(id, SLASH_WORDS):
		var claws := 3 if _has_word(id, CLAW_WORDS) else 1
		var tilt := deg_to_rad([35.0, -35.0, 70.0][i % 3])
		var axis := Vector3.UP.rotated(gd, tilt)
		var start := gd
		var r2 := (0.7 + 0.12 * t) * maxf(h, 0.8)
		var cc := center(user, 0.5) + gd * 0.2
		for k2 in claws:
			var o := axis.cross(gd).normalized() * (k2 - (claws - 1) / 2.0) * 0.16
			slash(
				cc + o,
				axis,
				start,
				r2,
				150.0,
				col,
				(0.1 if claws > 1 else 0.22) * s,
				0.26 + 0.03 * t,
				{"sweep": 0.4}
			)
			slash(
				cc + o,
				axis,
				start,
				r2,
				150.0,
				Color.WHITE,
				(0.035 if claws > 1 else 0.07) * s,
				0.22,
				{"sweep": 0.4}
			)
		if id.contains("scissor") or id.contains("cross"):
			slash(
				cc,
				Vector3.UP.rotated(gd, -tilt),
				start,
				r2,
				150.0,
				col,
				0.2 * s,
				0.3,
				{"sweep": 0.4}
			)
		element(type, c, 4 + 3 * t, {"dir": side, "spread": 0.8, "speed": [1.5, 4.0], "k": 0.6 * s})
	else:
		# Pancada (soco, chute, chifre, cauda): estocada rápida e o anel sai no acerto (hit).
		var a := center(user, 0.45)
		var b := a + gd * minf(reach, 2.0)
		var rb := Fx3DRibbon.make(Fx3D.mesh_mat(Fx3D.Mode.RIBBON, 2.4), col, 0.2 * s, 0.16, cam())
		rb.pts = PackedVector3Array([a, a.lerp(b, 0.5), b])
		rb.widths = PackedFloat32Array([0.02, 0.18 * s, 0.3 * s])
		rb.alphas = PackedFloat32Array([0.0, 0.6, 1.0])
		_add(rb)
		rb.rebuild()
		emitter(
			Vector3.ZERO,
			0.12,
			80.0,
			{
				"shape": Fx3D.Shape.SPARK,
				"stretch": 0.06,
				"life": [0.1, 0.18],
				"size": [0.05, 0.02],
				"col": [Color(1, 1, 1, 0.8), mid(type, 0.0)],
				"speed": [6.0, 9.0],
				"dir": gd,
				"spread": 0.12,
				"r": 0.25 * s
			},
			func(): return a
		)


## Chicote: fita da boca até a ponta + estalo do tipo na ponta.
func tip(user: BattleFighter, mv: Dictionary, at_local: Vector3, dir: Vector3) -> void:
	if not on() or not is_instance_valid(user):
		return
	var type := type_of(mv)
	var t := tier(mv)
	var gd := gdir(dir)
	var a := center(user, 0.45)
	var b := gpos(at_local) + Vector3(0, height(user) * 0.4, 0)
	var side := gd.cross(Vector3.UP).normalized()
	var col := mid(type)
	if type == "grass":
		col = hexc("3fae2a")
	var rb := Fx3DRibbon.make(Fx3D.mesh_mat(Fx3D.Mode.RIBBON, 2.0, 0.0, 0.6), col, 0.12, 0.3, cam())
	rb.fade_in = 0.0
	rb.shape = func(r: Fx3DRibbon, k: float) -> void:
		var pts := PackedVector3Array()
		var reach := clampf(k / 0.35, 0.0, 1.0)
		for i in 12:
			var u := float(i) / 11.0 * reach
			var bend := sin(u * PI) * (1.0 - reach * 0.6) * 0.7
			pts.append(a.lerp(b, u) + side * bend + Vector3.UP * sin(u * PI) * 0.3)
		r.pts = pts
	_add(rb)
	rb.shape.call(rb, 0.0)
	rb.rebuild()
	later(
		0.1,
		func() -> void:
			flash(b, 0.5 * kpow(t), core(type), 0.1)
			element(type, b, 6 + 3 * t, {"k": 0.6})
	)


# --- Jorro (stream) ---


func stream(user: BattleFighter, mv: Dictionary, dir: Vector3, length: float, dur: float) -> void:
	if not on() or not is_instance_valid(user):
		return
	var gd := gdir(dir)
	if sig.stream(user, mv, gd, length, dur):
		return
	var type := type_of(mv)
	var t := tier(mv)
	var s := kpow(t)
	var half := deg_to_rad(float(mv.get("angle", 35))) / 2.0
	var id := String(mv.get("id", ""))
	var face := func() -> Vector3:
		return gdir(user.facing) if is_instance_valid(user) and user.facing.length() > 0.01 else gd
	var live := func():
		return (
			mouth(user, face.call())
			if is_instance_valid(user) and user.is_inside_tree() and user.active()
			else null
		)
	var speed := length / 0.4
	if _has_word(
		id,
		[
			"voice",
			"buzz",
			"growl",
			"roar",
			"sing",
			"screech",
			"boomburst",
			"uproar",
			"snore",
			"round",
			"echoed",
			"chatter",
			"noise",
			"howl"
		]
	):
		# Som: anéis que saem pela frente e crescem.
		repeat(
			0.09,
			dur,
			func(i: int) -> bool:
				var at = live.call()
				if at == null:
					return false
				var f: Vector3 = face.call()
				var rg := ring(
					at,
					0.2,
					maxf(length * tan(half), 0.8),
					mid(type, 0.85) if i % 2 == 0 else core(type, 0.85),
					0.4,
					{"normal": f, "inner": 0.86}
				)
				rg.vel = f * speed * 0.8
				return true
		)
		return
	if (
		type in ["flying", "dragon"]
		and _has_word(
			id, ["gust", "twister", "hurricane", "air", "wind", "blizzard", "bleak", "tornado"]
		)
	):
		# Vento: riscos em espiral pelo cone.
		emitter(
			Vector3.ZERO,
			dur,
			70.0 + 30.0 * t,
			{
				"shape": Fx3D.Shape.SPARK,
				"stretch": 0.1,
				"life": [0.3, 0.45],
				"size": [0.08 * s, 0.03],
				"col": [Color(1, 1, 1, 0.9) if type == "flying" else accent(type), mid(type, 0.0)],
				"speed": [speed * 0.6, speed],
				"dir": gd,
				"spread": half
			},
			live
		)
		repeat(
			0.12,
			dur,
			func(_i: int) -> bool:
				var at = live.call()
				if at == null:
					return false
				var f: Vector3 = face.call()
				var rg := ring(
					at + f * 0.5,
					0.3,
					length * tan(half) * 0.9,
					Color(1, 1, 1, 0.5) if type == "flying" else mid(type, 0.6),
					0.45,
					{"normal": f, "inner": 0.9, "noise": 0.7, "spin": 14.0}
				)
				rg.vel = f * speed * 0.7
				return true
		)
		return
	# Jorro da matéria do tipo (fogo, água, pó, gás...).
	var o := trail_opts(type, 1.4 * s)
	o.speed = [speed * 0.75, speed * 1.05]
	o.dir = gd
	o.spread = half * 0.85
	o.life = [0.35, 0.5]
	o.drag = 0.6
	o.erase("grav")
	var e := emitter(Vector3.ZERO, dur, 90.0 + 40.0 * t, o, live)
	e.spawn = func(pp: Fx3DParticles) -> void:
		var at = live.call()
		if at == null:
			pp.emit_for = 0.0
			return
		o.dir = face.call()
		_emit_one(pp, at, o)
	light(
		mouth(user, gd) + gd * length * 0.4,
		lightc(type),
		1.6 + 0.8 * t,
		length * 0.8,
		dur + 0.1,
		{
			"follow": user,
			"off": Vector3(0, height(user) * 0.5, 0) + gd * length * 0.4,
			"attack": 0.1,
			"hold": 0.85,
			"flicker": 0.2
		}
	)


# --- Feixe ---


func beam(user: BattleFighter, mv: Dictionary, dir: Vector3, length: float, dur: float) -> void:
	if not on() or not is_instance_valid(user):
		return
	var gd := gdir(dir)
	if sig.beam(user, mv, gd, length, dur):
		return
	beam_body(user, mv, gd, length, dur)


## Corpo do feixe: tubo branco por dentro e do tipo por fora, clarão na boca, faíscas pelo caminho,
## anéis correndo (fortes), luzes ao longo e o estouro no fim.
func beam_body(
	user: BattleFighter, mv: Dictionary, gd: Vector3, length: float, dur: float, o := {}
) -> void:
	var type := type_of(mv)
	var t := tier(mv)
	var s := kpow(t) * float(o.get("k", 1.0))
	var w := float(mv.get("width", 0.8)) * 0.5 * s
	var from := mouth(user, gd)
	var col: Color = o.get("col", mid(type))
	var inner: Color = o.get("inner", core(type))
	tube(from, gd, length, w * 0.35, inner, dur, {"noise": 0.3, "phase": 2.0, "boost": 3.0})
	tube(from, gd, length, w, col, dur, {"noise": float(o.get("noise", 0.7)), "phase": 1.5})
	if t >= 3:
		tube(
			from,
			gd,
			length,
			w * 1.6,
			Color(col, 0.35),
			dur,
			{"noise": 0.9, "phase": 1.0, "boost": 1.4}
		)
	flash(from, w * 4.0, core(type), dur * 0.6)
	shell(from, w * 0.8, w * 1.6, col, dur, {"noise": 0.6, "phase": 6.0})
	var end := from + gd * length
	emitter(
		Vector3.ZERO,
		dur,
		60.0 + 30.0 * t,
		_m(
			trail_opts(type, s),
			{
				"speed": [length * 1.5, length * 2.2],
				"dir": gd,
				"spread": 0.05,
				"life": [0.25, 0.4],
				"r": w
			}
		),
		func(): return from
	)
	emitter(
		Vector3.ZERO,
		dur,
		40.0 + 20.0 * t,
		{
			"shape": Fx3D.Shape.SPARK,
			"stretch": 0.05,
			"life": [0.2, 0.4],
			"size": [0.12 * s, 0.04],
			"col": [inner, col * Color(1, 1, 1, 0.0)],
			"speed": [3.0, 7.0],
			"dir": -gd,
			"spread": 1.0
		},
		func(): return end
	)
	if t >= 3:
		repeat(
			0.08,
			dur,
			func(_i: int) -> bool:
				var rg := ring(
					from, w * 1.2, w * 2.2, Color(col, 0.8), 0.35, {"normal": gd, "inner": 0.8}
				)
				rg.vel = gd * length * 2.0
				return true
		)
	var nl := 2 if t < 3 else 3
	for i in nl:
		light(
			from + gd * length * (float(i) + 0.5) / nl,
			lightc(type),
			2.5 + t,
			3.0 + w * 3.0,
			dur + 0.1,
			{"hold": 0.7, "flicker": 0.15}
		)
	if t >= 4:
		shake(0.14, dur)
	elif t >= 3:
		shake(0.06, dur * 0.6)


# --- Acerto ---


func hit(
	user: BattleFighter,
	target: BattleFighter,
	mv: Dictionary,
	dir: Vector3,
	crit := false,
	eff := 1.0
) -> void:
	if not on() or not is_instance_valid(target) or not target.is_inside_tree():
		return
	var gd := gdir(dir)
	if sig.hit(user, target, mv, gd, crit, eff):
		return
	impact(target, mv, gd, crit, eff)


## Impacto: clarão, matéria do tipo espirrando, anel de choque (médio+), casca (forte+), luz e tremor.
func impact(
	target: BattleFighter, mv: Dictionary, gd: Vector3, crit := false, eff := 1.0, k := 1.0
) -> void:
	var type := type_of(mv)
	var t := maxi(tier(mv), 1)
	var big := crit or eff > 1.0
	var s := kpow(t) * k * (1.25 if big else 1.0)
	var at := center(target, 0.5)
	var physical := String(mv.get("category", "")) == "physical"
	flash(at, (0.9 + 0.25 * t) * s, core(type), 0.14)
	if physical:
		burst(
			at,
			{
				"n": 1,
				"shape": Fx3D.Shape.STAR,
				"speed": [0, 0],
				"life": [0.16, 0.16],
				"size": [1.2 * s, 0.6 * s],
				"col": [Color.WHITE, mid(type, 0.0)],
				"fade_in": 0.0
			}
		)
	element(type, at, int((6 + 5 * t) * s), {"dir": gd, "spread": 1.1, "k": 0.8 * s})
	burst(
		at,
		{
			"n": 6 + 4 * t,
			"shape": Fx3D.Shape.SPARK,
			"stretch": 0.05,
			"speed": [4.0, 9.0],
			"life": [0.12, 0.25],
			"size": [0.08 * s, 0.03],
			"col": [Color.WHITE, core(type, 0.0)],
			"dir": gd,
			"spread": 1.2,
			"drag": 4.0,
			"boost": 3.0
		}
	)
	if t >= 2:
		ring(at, 0.15, (0.8 + 0.2 * t) * s, mid(type, 0.9), 0.25, {"normal": gd, "inner": 0.8})
	if t >= 3:
		shell(at, 0.2, (0.6 + 0.15 * t) * s, mid(type, 0.8), 0.3, {"noise": 0.5, "phase": 4.0})
		ring(feet(target), 0.2, (1.0 + 0.3 * t) * s, mid(type, 0.6), 0.4, {"noise": 0.5})
	light(at, lightc(type), (1.5 + 1.0 * t) * s, 2.5 + t * 0.8, 0.22 + 0.04 * t)
	if big:
		ring(
			at,
			0.2,
			1.4 * s,
			Color(1, 0.95, 0.7, 0.9),
			0.3,
			{"normal": (cam_pos(at) - at).normalized(), "inner": 0.85}
		)
	if t >= 4 or (t >= 3 and big):
		shake(0.05 + 0.03 * t, 0.22)


# --- Áreas ---


## Começo de uma área no alvo (Thunder, Rock Slide, Psychic...): o efeito se forma no lugar
## durante o windup (no lugar do disco no chão).
func area_pre(
	user: BattleFighter, mv: Dictionary, at_local: Vector3, r: float, windup: float
) -> void:
	if not on():
		return
	var at := gpos(at_local)
	at.y = floor_y()
	if sig.area_pre(user, mv, at, r, windup):
		return
	var type := type_of(mv)
	var t := tier(mv)
	var s := kpow(t)
	# A matéria do tipo se junta acima do ponto, numa espiral que desce, e a luz sobe.
	var top := at + Vector3(0, 1.2 + 0.4 * t, 0)
	var o := trail_opts(type, 1.0 * s)
	o.speed = [0.0, 0.3]
	var e := emitter(
		Vector3.ZERO,
		windup,
		30.0 + 15.0 * t,
		_m(o, {"life": [0.5, 0.8]}),
		func():
			return (
				top
				+ (
					(
						Vector3(randf_range(-1, 1), randf_range(-0.3, 0.6), randf_range(-1, 1))
						. normalized()
					)
					* r
					* 1.1
				)
			)
	)
	e.attract_point = top
	e.attract_k = 8.0
	e.orbit_k = 16.0
	e.gravity = Vector3.ZERO
	shell(
		top,
		0.05,
		(0.25 + 0.08 * t) * s,
		mid(type, 0.85),
		windup + 0.05,
		{"noise": 0.6, "phase": 5.0, "fade_in": 0.5, "fade_out": 0.1}
	)
	light(
		top,
		lightc(type),
		(1.5 + t) * s,
		r * 2.0 + 2.0,
		windup + 0.1,
		{"attack": windup * 0.9, "hold": 0.9, "flicker": 0.1}
	)
	# Brilho vivo no chão crescendo (é o efeito, não um disco plano).
	emitter(
		Vector3.ZERO,
		windup,
		20.0 + 6.0 * t,
		{
			"shape": Fx3D.Shape.GLOW,
			"life": [0.3, 0.5],
			"size": [0.25, 0.05],
			"col": [mid(type, 0.8), deep(type, 0.0)],
			"speed": [0.3, 1.0],
			"dir": Vector3.UP,
			"spread": 0.3,
			"flat": true,
			"r": r * 0.9
		},
		func(): return at
	)


## A área cai (no alvo ou em volta do usuário).
func area_land(
	user: BattleFighter, mv: Dictionary, at_local: Vector3, r: float, around_user: bool
) -> void:
	if not on():
		return
	var at := gpos(at_local)
	at.y = floor_y()
	if sig.area_land(user, mv, at, r, around_user):
		return
	burst_area(mv, at, r)


## Explosão genérica de área: anéis no chão, coluna da matéria do tipo, poeira, luz e tremor.
func burst_area(mv: Dictionary, at: Vector3, r: float, k := 1.0) -> void:
	var type := type_of(mv)
	var t := maxi(tier(mv), 1)
	var s := kpow(t) * k
	ring(at + Vector3(0, 0.05, 0), 0.2, r * 1.1, mid(type, 0.95), 0.35, {"noise": 0.4, "soft": 0.7})
	if t >= 2:
		ring(at + Vector3(0, 0.05, 0), 0.2, r * 0.8, core(type, 0.9), 0.25, {"inner": 0.85})
	if t >= 3:
		later(
			0.08,
			ring.bind(at + Vector3(0, 0.05, 0), 0.3, r * 1.4, mid(type, 0.7), 0.45, {"noise": 0.6})
		)
	element(
		type,
		at + Vector3(0, 0.3, 0),
		int((10 + 8 * t) * s),
		{"dir": Vector3.UP, "spread": 0.9, "speed": [2.0, 6.0], "k": s, "r": r * 0.7}
	)
	burst(
		at,
		{
			"n": 8 + 4 * t,
			"shape": Fx3D.Shape.SMOKE,
			"add": false,
			"speed": [1.5, 3.5],
			"life": [0.5, 0.9],
			"size": [0.4 * s, 1.0 * s],
			"col": [Color(0.8, 0.72, 0.6, 0.55), Color(0.7, 0.65, 0.6, 0.0)],
			"dir": Vector3.UP,
			"spread": 1.45,
			"drag": 3.0,
			"flat": true,
			"r": r * 0.6
		}
	)
	flash(at + Vector3(0, 0.6, 0), r * 1.2 * s, core(type), 0.16)
	light(at + Vector3(0, 0.8, 0), lightc(type), (2.5 + t) * s, r * 2.5 + 2.0, 0.35)
	if t >= 3:
		shake(0.06 + 0.03 * (t - 3), 0.3)


## Zona que fica (Fire Spin, Whirlpool, Sand Tomb...): redemoinho da matéria do tipo pelo tempo todo.
func zone_at(user: BattleFighter, mv: Dictionary, at_local: Vector3, r: float, dur: float) -> void:
	if not on():
		return
	var at := gpos(at_local)
	at.y = floor_y()
	if sig.zone(user, mv, at, r, dur):
		return
	vortex(mv, at, r, dur)


func vortex(mv: Dictionary, at: Vector3, r: float, dur: float, k := 1.0) -> void:
	var type := type_of(mv)
	var t := maxi(tier(mv), 1)
	var hgt := (1.4 + 0.3 * t) * k
	var f := shell(
		at,
		0,
		0,
		mid(type, 0.7),
		dur,
		{
			"mesh": Fx3D.funnel(0.35),
			"noise": 0.85,
			"phase": 3.0,
			"spin": 5.0,
			"fade_in": 0.08,
			"fade_out": 0.12,
			"s0v": Vector3(r * 0.5, hgt * 0.4, r * 0.5),
			"s1v": Vector3(r, hgt, r)
		}
	)
	f.grow_ease = true
	shell(
		at,
		0,
		0,
		core(type, 0.5),
		dur,
		{
			"mesh": Fx3D.funnel(0.5),
			"noise": 0.9,
			"phase": 4.5,
			"spin": -7.0,
			"fade_in": 0.1,
			"fade_out": 0.12,
			"s0v": Vector3(r * 0.3, hgt * 0.3, r * 0.3),
			"s1v": Vector3(r * 0.7, hgt * 0.8, r * 0.7)
		}
	)
	var o := trail_opts(type, 1.2 * k)
	o.speed = [0.5, 1.2]
	o.up = 1.2
	o.life = [0.6, 1.0]
	var e := emitter(
		Vector3.ZERO,
		dur,
		40.0 + 10.0 * t,
		o,
		func():
			return (
				at
				+ (
					Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
					* r
					* randf_range(0.5, 1.0)
				)
				+ Vector3(0, randf() * hgt * 0.5, 0)
			)
	)
	e.attract_point = at
	e.orbit_k = 30.0
	e.attract_k = 4.0
	e.gravity = Vector3.ZERO
	light(
		at + Vector3(0, hgt * 0.5, 0),
		lightc(type),
		1.5 + 0.5 * t,
		r * 2.5,
		dur,
		{"attack": 0.2, "hold": 0.9, "flicker": 0.15}
	)


# --- Apoio ---


func buff(user: BattleFighter, mv: Dictionary) -> void:
	var type := type_of(mv)
	var h := height(user)
	var off := Vector3(0, 0.05, 0)
	ring(feet(user), 0.2, 1.3, mid(type, 0.9), 0.6, {"noise": 0.3, "follow": user, "off": off})
	emitter(
		Vector3.ZERO,
		0.6,
		50.0,
		{
			"follow": user,
			"shape": Fx3D.Shape.SPARK,
			"stretch": 0.1,
			"life": [0.35, 0.6],
			"size": [0.09, 0.03],
			"col": [core(type), mid(type, 0.0)],
			"speed": [2.0, 3.5],
			"dir": Vector3.UP,
			"spread": 0.1,
			"flat": true,
			"r": 0.6
		},
		func(): return feet(user) if is_instance_valid(user) and user.is_inside_tree() else null
	)
	shell(
		center(user, 0.5),
		h * 0.5,
		h * 0.75,
		mid(type, 0.6),
		0.6,
		{"follow": user, "off": Vector3(0, h * 0.5, 0), "noise": 0.5, "phase": 3.0}
	)
	light(
		center(user, 0.5),
		lightc(type),
		2.5,
		3.5,
		0.7,
		{"follow": user, "off": Vector3(0, h * 0.5, 0), "attack": 0.15}
	)
	element(type, center(user, 0.6), 10, {"k": 0.7, "speed": [0.8, 2.0]})


func debuff(user: BattleFighter, mv: Dictionary, gd: Vector3) -> void:
	var type := type_of(mv)
	var id := String(mv.get("id", ""))
	var c := center(user, 0.55)
	var r := minf(float(mv.get("radius", 6.0)), 4.0)
	if _has_word(
		id,
		["growl", "roar", "screech", "metal_sound", "noble", "snarl", "howl", "parting", "confide"]
	):
		for i in 4:
			later(
				0.08 * i,
				func() -> void:
					var rg := ring(
						c, 0.3, r * 0.8, mid(type, 0.8), 0.4, {"normal": gd, "inner": 0.88}
					)
					rg.vel = gd * 6.0
			)
	elif _has_word(
		id,
		[
			"leer",
			"scary",
			"glare",
			"eerie",
			"fake_tears",
			"charm",
			"baby_doll",
			"play_nice",
			"tickle"
		]
	):
		var eye := center(user, 0.8)
		burst(
			eye,
			{
				"n": 2,
				"shape": Fx3D.Shape.STAR,
				"speed": [0, 0],
				"life": [0.35, 0.35],
				"size": [0.9, 0.2],
				"col": [Color(1, 0.3, 0.3) if type != "fairy" else mid(type), Color(1, 1, 1, 0.0)],
				"r": 0.15
			}
		)
		light(eye, Color(1, 0.4, 0.4) if type != "fairy" else lightc(type), 2.0, 3.0, 0.4)
	elif id == "flash":
		flash(c, 4.0, Color.WHITE, 0.3)
		light(c, Color.WHITE, 8.0, 10.0, 0.4)
		return
	elif _has_word(id, ["smoke", "sand", "mud", "kinesis", "sweet", "feather"]):
		element(
			type if type != "normal" else "ground",
			c,
			24,
			{"dir": gd, "spread": 0.8, "speed": [1.5, 4.0], "k": 1.2}
		)
	ring(feet(user), 0.3, r, mid(type, 0.7), 0.5, {"noise": 0.5})
	element(type, c, 10, {"dir": gd, "spread": 1.0, "k": 0.8})


## Estágio subiu/desceu: riscos subindo (ou caindo) na cor do status.
func stat_change(f: BattleFighter, key: String, up: bool) -> void:
	if not on() or not is_instance_valid(f) or not f.is_inside_tree():
		return
	var col: Color = MoveShow.STAT_COL.get(key, Color.WHITE)
	var h := height(f)
	var top := feet(f) + Vector3(0, h * 1.1, 0)
	emitter(
		Vector3.ZERO,
		0.45,
		40.0,
		{
			"follow": f,
			"shape": Fx3D.Shape.SPARK,
			"stretch": 0.12,
			"life": [0.3, 0.45],
			"size": [0.1, 0.04],
			"col": [col.lightened(0.4), Color(col, 0.0)],
			"speed": [2.0, 3.0],
			"dir": Vector3.UP if up else Vector3.DOWN,
			"spread": 0.05,
			"flat": true,
			"r": 0.55
		},
		func():
			return (
				(feet(f) if up else feet(f) + Vector3(0, h * 1.1, 0))
				if is_instance_valid(f) and f.is_inside_tree()
				else null
			)
	)
	ring(
		feet(f) if up else top,
		0.6,
		0.3 if up else 1.0,
		Color(col, 0.8),
		0.45,
		{"follow": f, "off": Vector3(0, 0.05, 0) if up else Vector3(0, h * 1.1, 0), "inner": 0.85}
	)

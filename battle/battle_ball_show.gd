extends RefCounted
## Espetáculo da Pokébola (só visual; a arena nunca cria isto no fast_sim): o gesto do treinador,
## o rastro da bola girando, o quique, o clarão ao abrir (luz, raios, faíscas, onda no piso, poeira),
## o Pokémon que se materializa (silhueta branca que cresce e ganha cor) e a poeira ao pousar; na
## volta, o Pokémon encolhe numa luz vermelha que voa para a mão do treinador.
## Com a câmera de ação (BattleDirector) a bola é maior e a troca é coreografada em tempos próprios
## (WINDUP, FLIGHT, BOUNCE, OPEN); sem ela a arena mantém os tempos antigos (SEND_FLIGHT, SEND_OPEN)
## e só o visual muda. Usa um RandomNumberGenerator próprio (nunca o arena.rng).

## Coreografia com a câmera de ação (segundos de luta): o treinador prepara o arremesso, a bola voa,
## quica até HOVER m e abre no alto; depois some em OPEN s enquanto o Pokémon cresce em GROW s.
const WINDUP := 0.45
const FLIGHT := 0.75
const BOUNCE := 0.25
const OPEN := 0.5
const GROW := 0.45
const HOVER := 1.1
## Bola maior na quadra de 48 m (legível de longe pela câmera de ação; 2,2 ficou grande demais).
const BALL_SCALE := 1.5
const TRAIL_EVERY := 0.025
const RED := Color(1.0, 0.22, 0.18)
const DUST := Color(0.82, 0.74, 0.6, 0.75)

var arena: Node3D
var _rng := RandomNumberGenerator.new()
var _grow: Array = []  ## [{f, t, dur, big}]
var _trail_acc := 0.0


func _init(a: Node3D) -> void:
	arena = a
	_rng.seed = 7177


func _vfx() -> BattleVfx:
	return arena.get("vfx")


func _cam() -> Camera3D:
	var v := _vfx()
	return v.cam() if v else null


## Peça procedural solta no mundo (global), acompanhada pelo BattleVfx.
func _bit(
	tex: String, at: Vector3, size: float, col: Color, o := {}, face := ProcFx.Face.BILLBOARD
) -> ProcFx:
	var v := _vfx()
	if v == null or not v.enabled or not arena.is_inside_tree():
		return null
	var f := ProcFx.make(tex, size, col, face, bool(o.get("add", true)))
	if f == null:
		return null
	f.life = float(o.get("life", 0.4))
	f.velocity = o.get("vel", Vector3.ZERO)
	f.gravity = float(o.get("gravity", 0.0))
	f.drag = float(o.get("drag", 0.0))
	f.grow = o.get("grow", Vector2.ONE)
	f.fade = float(o.get("fade", 0.4))
	f.fade_in = float(o.get("fade_in", 0.0))
	f.pop = float(o.get("pop", 0.0))
	f.spin = float(o.get("spin", 0.0))
	if face == ProcFx.Face.ROLL:
		var c := _cam()
		if c == null:
			f.free()
			return null
		f.set_roll(_rng.randf() * TAU, c)
	var follow = o.get("follow")
	if follow is Node3D and is_instance_valid(follow):
		f.follow = follow
		f.follow_off = o.get("follow_off", Vector3.ZERO)
	arena.add_child(f)
	f.global_position = at
	v._track(f)
	return f


# --- Treinador ---


## Gesto do arremesso no boneco do treinador (só o boneco criado pela arena): agacha e recua na
## preparação (r < 0), estica para a frente com um pulinho ao soltar e volta ao normal.
## r = segundos desde que a bola saiu da mão.
func trainer_pose(side: int, r: float) -> void:
	var stands: Dictionary = arena.get("_stands")
	var owned: Dictionary = arena.get("_stand_owned")
	if not owned.has(side) or not stands.has(side) or not is_instance_valid(stands[side]):
		return
	var spr := (stands[side] as Node3D).get_node_or_null("Sprite") as Sprite3D
	if spr == null:
		return
	if not spr.has_meta("pose_off"):
		spr.set_meta("pose_off", spr.offset)
		spr.set_meta("pose_y", spr.position.y)
	var base: Vector2 = spr.get_meta("pose_off")
	var y0: float = spr.get_meta("pose_y")
	var dir := 1.0 if side == 0 else -1.0  # o lado A joga para +x (direita da tela)
	var sx := 1.0
	var sy := 1.0
	var ox := 0.0
	var hop := 0.0
	var col := -1
	if r < 0.0:
		var k := clampf(1.0 + r / WINDUP, 0.0, 1.0)
		k = k * k * (3.0 - 2.0 * k)
		sx = 1.0 + 0.12 * k
		sy = 1.0 - 0.1 * k
		ox = -dir * 2.5 * k
		col = 0
	elif r < 0.12:
		var k := r / 0.12
		sx = lerpf(1.12, 0.86, k)
		sy = lerpf(0.9, 1.16, k)
		ox = lerpf(-2.5, 3.5, k) * dir
		hop = 0.14 * sin(k * PI * 0.5)
		col = 1
	elif r < 0.45:
		var k := (r - 0.12) / 0.33
		k = k * k * (3.0 - 2.0 * k)
		sx = lerpf(0.86, 1.0, k)
		sy = lerpf(1.16, 1.0, k)
		ox = lerpf(3.5, 0.0, k) * dir
		hop = 0.14 * (1.0 - k)
		col = 1 if k < 0.6 else -1
	spr.scale = Vector3(sx, sy, 1.0)
	spr.offset = base + Vector2(ox, 0.0)
	spr.position.y = y0 + hop
	if "step_col" in spr:
		spr.set("step_col", col)


# --- Bola ---


## Rastro da bola em voo (vermelho e branco alternados, brilho somado).
func trail(ball: Node3D, dt: float, big: bool) -> void:
	_trail_acc += dt
	if _trail_acc < TRAIL_EVERY:
		return
	_trail_acc = 0.0
	if not ball.is_inside_tree():
		return
	var s := 1.0 if big else 0.55
	var white := _rng.randf() < 0.4
	_bit(
		"glow",
		ball.global_position,
		0.9 * s,
		Color(1.0, 1.0, 1.0, 0.75) if white else Color(RED, 0.85),
		{"life": 0.32, "grow": Vector2(1.0, 0.25), "fade": 0.7}
	)
	if big and _rng.randf() < 0.35:
		_bit(
			"star4",
			ball.global_position,
			0.35,
			Color(1.0, 0.95, 0.7, 0.9),
			{
				"life": 0.4,
				"vel": Vector3(_rng.randf_range(-1, 1), _rng.randf_range(0.5, 1.5), 0.0),
				"gravity": 3.0,
				"fade": 0.5
			}
		)


## Poeira e um anel no chão quando a bola quica (global).
func bounce(ground: Vector3, big: bool) -> void:
	var s := 1.0 if big else 0.6
	dust(ground, 5, 0.5 * s, 0.6 * s)
	_bit(
		"ring_soft",
		ground + Vector3(0, 0.06, 0),
		1.0 * s,
		Color(1, 1, 1, 0.6),
		{"life": 0.3, "grow": Vector2(0.5, 2.2), "fade": 0.6},
		ProcFx.Face.GROUND
	)


## A bola abre (at = a bola, ground = o chão embaixo, globais): clarão branco, luz, raios girando,
## anel vermelho, faíscas que voam, onda no piso e poeira.
func burst(at: Vector3, ground: Vector3, big: bool) -> void:
	var s := 1.0 if big else 0.55
	_bit(
		"glow",
		at,
		6.0 * s,
		Color(1, 1, 1, 1),
		{"life": 0.4, "grow": Vector2(0.3, 1.3), "fade": 0.7}
	)
	_bit(
		"glow", at, 3.0 * s, Color(RED, 0.9), {"life": 0.3, "grow": Vector2(0.4, 1.6), "fade": 0.8}
	)
	_bit(
		"rays",
		at,
		7.0 * s,
		Color(1.0, 0.97, 0.85, 0.95),
		{"life": 0.55, "grow": Vector2(0.4, 1.25), "fade": 0.55, "spin": 2.5},
		ProcFx.Face.ROLL
	)
	_bit(
		"ring", at, 1.5 * s, Color(RED, 0.9), {"life": 0.35, "grow": Vector2(0.3, 3.0), "fade": 0.6}
	)
	for i in 12 if big else 7:
		var a := TAU * float(i) / (12.0 if big else 7.0) + _rng.randf() * 0.4
		var up := _rng.randf_range(0.4, 1.4)
		_bit(
			"star4",
			at,
			_rng.randf_range(0.35, 0.6) * s,
			Color(1.0, 0.92, 0.55, 1.0) if i % 2 == 0 else Color(1, 1, 1, 1),
			{
				"life": _rng.randf_range(0.45, 0.7),
				"vel": Vector3(cos(a), up, sin(a)) * _rng.randf_range(3.5, 6.0) * s,
				"gravity": 7.0 * s,
				"drag": 1.5,
				"fade": 0.45
			}
		)
	_bit(
		"ring",
		ground + Vector3(0, 0.07, 0),
		1.2 * s,
		Color(1.0, 1.0, 1.0, 0.85),
		{"life": 0.5, "grow": Vector2(0.4, 6.0), "fade": 0.7},
		ProcFx.Face.GROUND
	)
	_bit(
		"ring_soft",
		ground + Vector3(0, 0.06, 0),
		1.2 * s,
		Color(RED, 0.7),
		{"life": 0.6, "grow": Vector2(0.3, 4.0), "fade": 0.6},
		ProcFx.Face.GROUND
	)
	dust(ground, 8 if big else 5, 1.0 * s, 0.9 * s)
	var v := _vfx()
	if v and arena.is_inside_tree():
		var lt := Flash.new()
		lt.omni_range = 9.0 * s
		lt.light_color = Color(1.0, 0.95, 0.9)
		arena.add_child(lt)
		lt.global_position = at
		v._track(lt)


## Poeira no chão (global) em volta de `at`.
func dust(at: Vector3, n: int, r: float, size: float) -> void:
	for i in n:
		var a := TAU * float(i) / float(maxi(n, 1)) + _rng.randf() * 0.5
		var p := at + Vector3(cos(a) * r, 0.15, sin(a) * r) * _rng.randf_range(0.6, 1.0)
		_bit(
			"cloud",
			p,
			size * _rng.randf_range(0.8, 1.2),
			DUST,
			{
				"add": false,
				"life": _rng.randf_range(0.5, 0.8),
				"vel": Vector3(cos(a), 0.35, sin(a)) * _rng.randf_range(1.5, 3.0),
				"drag": 3.0,
				"grow": Vector2(0.6, 1.5),
				"fade": 0.6
			}
		)


# --- Pokémon ---


## O Pokémon que saiu da bola: silhueta branca que cresce até o tamanho certo e ganha cor.
func materialise(f: BattleFighter, big: bool) -> void:
	if not is_instance_valid(f) or f.look == null:
		return
	for e in _grow:
		if e.f == f:
			_grow.erase(e)
			break
	_grow.append({"f": f, "t": 0.0, "dur": GROW, "big": big})
	var h := maxf(f.visual_height(), 0.8)
	_bit(
		"glow",
		f.global_position + Vector3(0, h * 0.5, 0),
		h * 2.2,
		Color(1, 1, 1, 0.9),
		{
			"life": GROW + 0.2,
			"grow": Vector2(0.4, 1.1),
			"fade": 0.6,
			"follow": f,
			"follow_off": Vector3(0, h * 0.5, 0)
		}
	)
	_apply(_grow[-1])


## Passo do crescimento (dt da luta, o mesmo da bola).
func tick(dt: float) -> void:
	for e in _grow.duplicate():
		var f = e.f
		if not is_instance_valid(f) or f.look == null:
			_grow.erase(e)
			continue
		e.t += dt
		if e.t >= float(e.dur):
			_grow.erase(e)
			f.look.scale_mult = 1.0
			if f.visible and f.is_inside_tree():
				var big: bool = e.big
				var s := 1.0 if big else 0.6
				dust(f.global_position, 6, 0.6 * s, 0.7 * s)
				_bit(
					"ring_soft",
					f.global_position + Vector3(0, 0.06, 0),
					1.0 * s,
					Color(1, 1, 1, 0.5),
					{"life": 0.35, "grow": Vector2(0.6, 2.5), "fade": 0.6},
					ProcFx.Face.GROUND
				)
			continue
		_apply(e)


func _apply(e: Dictionary) -> void:
	var f: BattleFighter = e.f
	var k := clampf(float(e.t) / float(e.dur), 0.0, 1.0)
	var s := 1.0
	if k < 0.7:
		var q := k / 0.7
		s = lerpf(0.05, 1.12, 1.0 - pow(1.0 - q, 3.0))
	else:
		s = lerpf(1.12, 1.0, (k - 0.7) / 0.3)
	f.look.scale_mult = s
	var c := clampf((k - 0.35) / 0.65, 0.0, 1.0)
	var w := lerpf(3.2, 1.0, c * c * (3.0 - 2.0 * c))
	f.flash(Color(w, w, w), 0.06)


func growing(f: BattleFighter) -> bool:
	return _grow.any(func(e) -> bool: return e.f == f)


## Recolher: o Pokémon encolhe numa silhueta vermelha e uma luz vermelha voa até a mão (global).
func recall(f: BattleFighter, hand: Vector3, secs: float) -> void:
	if not is_instance_valid(f) or not f.is_inside_tree():
		return
	var h := maxf(f.visual_height(), 0.8)
	var mid := f.global_position + Vector3(0, h * 0.5, 0)
	var src: Sprite3D = f.look.sprite() if f.look else null
	var v := _vfx()
	if src and v and v.enabled:
		var g := ProcFx.ghost(src, Color(2.6, 0.5, 0.45, 1.0))
		if g:
			g.life = secs
			g.grow = Vector2(1.0, 0.05)
			g.fade = 0.3
			arena.add_child(g)
			g.global_position = src.global_position
			v._track(g)
	_bit("glow", mid, h * 2.0, Color(RED, 0.9), {"life": secs, "grow": Vector2(1.0, 0.2)})
	var to := hand - mid
	_bit(
		"glow",
		mid,
		0.9,
		Color(1.0, 0.35, 0.3, 1.0),
		{"life": secs * 1.4, "vel": to / maxf(secs * 1.4, 0.05), "fade": 0.2, "fade_in": secs * 0.4}
	)
	_bit(
		"ring_soft",
		f.global_position + Vector3(0, 0.06, 0),
		1.2,
		Color(RED, 0.7),
		{"life": secs, "grow": Vector2(1.6, 0.3), "fade": 0.5},
		ProcFx.Face.GROUND
	)


## Luz do clarão que some em LIFE s (anda no tick do BattleVfx).
class Flash:
	extends OmniLight3D
	const LIFE := 0.35
	var age := 0.0

	func _init() -> void:
		light_energy = 6.0
		shadow_enabled = false

	func tick(dt: float) -> bool:
		age += dt
		light_energy = 6.0 * maxf(0.0, 1.0 - age / LIFE)
		return age < LIFE

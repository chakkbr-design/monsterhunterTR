class_name BattlePhysics
extends RefCounted
## Física de impacto da luta (Gen 9): empurrão pela eficácia, crítico e peso; golpes que arremessam
## (Whirlwind, Roar, Dragon Tail, Circle Throw e contato forte) e batida na cerca/caixa/pedra;
## salto em cima do alvo (Body Slam, Stomp, Bounce, Fly; Earthquake/Magnitude pulam no lugar);
## investida que some e reaparece sobre o alvo (Aerial Ace) e Dig/Dive (anda por baixo e sai sob o alvo).
## BattleMoves cria um (moves.phys); o lutador roda os movimentos em BattleFighter._scripted_step.
## Campos opcionais por golpe em data/moves.json: "push" (m de arremesso), "leap" (true ou
## {secs, h, sky}), "blink": true, "tunnel": "dig"|"dive". Sem o campo vale a tabela por id abaixo
## (para os golpes que o outro branch acrescenta).

## Golpes que no oficial forçam a troca: aqui arremessam o alvo longe (m).
const PUSH_IDS := {"whirlwind": 5.0, "roar": 5.0, "dragon_tail": 4.0, "circle_throw": 4.0}
## Saltos: tempo no ar (s), altura (m), "sky" = fica fora de alcance no alto (Fly, Bounce).
const LEAP_IDS := {
	"body_slam": {"secs": 0.42, "h": 1.5},
	"stomp": {"secs": 0.34, "h": 1.0},
	"heavy_slam": {"secs": 0.5, "h": 2.0},
	"heat_crash": {"secs": 0.5, "h": 2.0},
	"high_jump_kick": {"secs": 0.4, "h": 1.6},
	"bounce": {"secs": 1.1, "h": 4.5, "sky": true},
	"fly": {"secs": 1.2, "h": 5.0, "sky": true},
}
const BLINK_IDS := ["aerial_ace", "feint_attack", "shadow_sneak"]
const TUNNEL_IDS := {"dig": "dig", "dive": "dive"}
## Escondido (Dig/Dive/Fly/Bounce): só estes golpes alcançam; os da lista "x2" batem em dobro (oficial).
const REACHES_HIDDEN := {
	"dig": ["earthquake", "magnitude", "fissure"],
	"dive": ["surf", "whirlpool"],
	"sky":
	["gust", "twister", "thunder", "hurricane", "sky_uppercut", "smack_down", "thousand_arrows"],
}
const HIDDEN_DOUBLE := ["earthquake", "magnitude", "surf", "whirlpool", "gust", "twister"]
const CONTACT_KINDS := ["dash", "arc", "multi_arc", "lunge"]
## Contato forte (poder >= STRONG_POWER) arremessa: 0,6 m + 1,2 m a cada 40 de poder acima.
const STRONG_POWER := 80.0
const LAUNCH_MIN := 0.5
const WEIGHT_REF := 40.0
## Batida na cerca/objeto: fração do HP máximo na velocidade cheia do arremesso.
const CRASH_FRAC := 0.08
const CRASH_MIN_SPEED := 0.15
const STRIKE_R := 1.3
const TRAIL_EVERY := 0.12

var arena: Node
var rng: RandomNumberGenerator


func _init(a: Node, r: RandomNumberGenerator) -> void:
	arena = a
	rng = r


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _id(mv: Dictionary) -> String:
	return String(mv.get("id", ""))


# --- Classificação dos golpes ---


func push_dist(mv: Dictionary) -> float:
	if mv.has("push"):
		return float(mv.push)
	return float(PUSH_IDS.get(_id(mv), 0.0))


func leap_of(mv: Dictionary) -> Dictionary:
	var l = mv.get("leap", LEAP_IDS.get(_id(mv)))
	if l is Dictionary:
		return l
	if l == true:
		return {"secs": 0.4, "h": 1.4}
	return {}


func is_blink(mv: Dictionary) -> bool:
	return bool(mv.get("blink", _id(mv) in BLINK_IDS))


func tunnel_of(mv: Dictionary) -> String:
	return String(mv.get("tunnel", TUNNEL_IDS.get(_id(mv), "")))


## Golpe com entrega própria (salto, sumiço, túnel): BattleMoves.deliver passa para cá.
func scripted(mv: Dictionary) -> bool:
	return not leap_of(mv).is_empty() or is_blink(mv) or tunnel_of(mv) != ""


## Escondido sob a terra/água/no alto: só os golpes da lista alcançam. Devolve o multiplicador de poder
## (0 = não alcança).
func hidden_power(mv: Dictionary, target: BattleFighter) -> float:
	if target.hidden == "":
		return 1.0
	if _id(mv) in REACHES_HIDDEN.get(target.hidden, []):
		return 2.0 if _id(mv) in HIDDEN_DOUBLE else 1.0
	return 0.0


# --- Empurrão ---


## Multiplicador do empurrão: superefetivo empurra mais, pouco efetivo menos, crítico mais, pesado menos.
static func knock_mult(eff: float, crit: bool, weight_kg := WEIGHT_REF) -> float:
	var k := 1.0
	if eff >= 4.0:
		k *= 1.9
	elif eff > 1.0:
		k *= 1.5
	elif eff > 0.0 and eff <= 0.25:
		k *= 0.35
	elif eff > 0.0 and eff < 1.0:
		k *= 0.55
	if crit:
		k *= 1.4
	return k * clampf(pow(WEIGHT_REF / maxf(weight_kg, 1.0), 0.25), 0.7, 1.35)


static func weight_of(f: BattleFighter) -> float:
	if f == null or f.mon == null:
		return WEIGHT_REF
	return float(Dex.species(f.mon.species).get("weight_kg", WEIGHT_REF))


## Metros de arremesso de um acerto (0 = só o empurrão normal).
func launch_dist(
	mv: Dictionary, eff: float, crit: bool, target: BattleFighter, final: bool
) -> float:
	var base := push_dist(mv)
	var power := float(mv.get("power", 0))
	if (
		base <= 0.0
		and final
		and String(mv.get("category", "")) == "physical"
		and power >= STRONG_POWER
		and (String(mv.get("kind", "")) in CONTACT_KINDS or scripted(mv))
	):
		base = 0.6 + (power - STRONG_POWER) / 40.0 * 1.2
	if base <= 0.0:
		return 0.0
	return base * knock_mult(eff, crit, weight_of(target))


## Depois do dano: arremessa se o golpe for de arremesso ou contato forte.
func after_hit(
	user: BattleFighter,
	target: BattleFighter,
	mv: Dictionary,
	dir: Vector3,
	eff: float,
	crit: bool,
	final: bool
) -> void:
	if not is_instance_valid(target) or not target.alive() or target.motion != "":
		return
	var dist := launch_dist(mv, eff, crit, target, final)
	if dist < LAUNCH_MIN:
		return
	var d := _flat(dir)
	if d.length() < 0.01 and is_instance_valid(user):
		d = _flat(target.position - user.position)
	if d.length() < 0.01:
		d = Vector3.BACK
	launch(target, d.normalized(), dist, push_dist(mv) > 0.0)


## Arremessa o alvo `dist` metros na direção `dir` (desacelera até parar; sobe um pouco no meio).
func launch(f: BattleFighter, dir: Vector3, dist: float, forced := false) -> void:
	var secs := clampf(0.25 + dist * 0.07, 0.3, 0.7)
	var lift := minf(0.2 + dist * 0.12, 0.9)
	f.launch(dir, dist, secs, lift)
	if forced:
		f.popup("Arremessado!", Color(0.85, 0.9, 1.0), 1.0, 0.9)
	if arena.vfx and arena.vfx.has_method("launch"):
		arena.vfx.launch(f, dir, dist)


## Chamado pelo lutador a cada passo do arremesso: true se bateu (na cerca, num objeto ou parede).
func crash_check(f: BattleFighter, next: Vector3) -> bool:
	var bounds: Rect2 = arena.rect.grow(-0.5)
	var what := ""
	var obj = null
	if not bounds.has_point(Vector2(next.x, next.z)):
		what = "fence"
	elif arena.field:
		for o in arena.field.objects:
			if _flat(next - o.pos).length() < BattleField.OBJ_R + BattleField.BODY_R:
				what = "rock" if o.rock else "crate"
				obj = o
				break
	if (
		what == ""
		and arena.get("fixed")
		and arena.has_method("_solid_at")
		and arena._solid_at(next)
	):
		what = "wall"
	if what == "":
		return false
	_crash(f, what, obj)
	return true


func _crash(f: BattleFighter, what: String, obj) -> void:
	var ratio := f.launch_t / maxf(f.launch_total, 0.001)
	var dir := f.launch_v.normalized()
	f.launch_t = 0.0
	if ratio < CRASH_MIN_SPEED:
		return
	f.knock = -dir * 3.0
	f.stun_t = maxf(f.stun_t, 0.35)
	var n := maxi(1, int(float(f.max_hp) * CRASH_FRAC * ratio * f.dot_scale()))
	var words := {
		"fence": "Bateu na cerca!",
		"rock": "Bateu na pedra!",
		"crate": "Bateu na caixa!",
		"wall": "Bateu na parede!"
	}
	f.popup("-%d %s" % [n, words.get(what, "Bateu!")], Color(1.0, 0.8, 0.55), 0.9, 0.6)
	f.take_damage(n, Vector3.ZERO, 0.0)
	if obj != null and arena.field:
		arena.field._hit_objects(obj.pos, 0.05)
	var at: Vector3 = f.position + dir * 0.4
	at.y = 0.4
	if arena.vfx and arena.vfx.has_method("crash"):
		arena.vfx.crash(f, at, what)
	else:
		PixelFx.pop(arena, "dust", at, 1.3, 0.35)
	preload("res://audio/cue.gd").sfx("hit")


# --- Salto em cima do alvo ---


## Body Slam, Stomp, Bounce, Fly: pula e cai em cima do alvo; o acerto é no pouso.
func start_leap(user: BattleFighter, mv: Dictionary, dir: Vector3, miss: BattleFighter) -> void:
	var l := leap_of(mv)
	var target: BattleFighter = user.opponent if is_instance_valid(user.opponent) else null
	var to := user.position + dir * float(mv.get("range", 3.0))
	var track := 0.6
	if target and target.active():
		to = target.position - dir * 0.5
	if miss != null:
		to += dir.cross(Vector3.UP).normalized() * (1.6 if rng.randf() < 0.5 else -1.6)
		target = null
		track = 0.0
	var dist := _flat(to - user.position).length()
	var secs := float(l.get("secs", 0.4)) * clampf(0.75 + dist * 0.08, 0.8, 1.3)
	var h := float(l.get("h", 1.4)) * clampf(0.7 + dist * 0.1, 0.8, 1.3)
	var sky := bool(l.get("sky", false))
	user.start_motion(
		"leap",
		to,
		secs,
		h,
		target,
		_land_strike.bind(user, mv, miss),
		track,
		_sky_tick if sky else Callable()
	)
	if sky:
		user.popup("Subiu bem alto!", Color(0.8, 0.9, 1.0), 0.9, 0.9)


## Fly/Bounce: fica fora de alcance no meio do salto.
func _sky_tick(f: BattleFighter, s: float, _dt: float) -> void:
	f.hidden = "sky" if s > 0.15 and s < 0.85 else ""


## Earthquake/Magnitude ("slam"): agacha, pula no lugar e cai; o tremor sai no pouso (_aoe_self).
func slam_hop(user: BattleFighter, mv: Dictionary, secs: float) -> void:
	var h := maxf(user.jump_height * 1.8, 0.8)
	if mv.has("magnitude") or _id(mv) == "magnitude":
		h *= clampf(float(mv.get("power", 70)) / 70.0, 0.5, 2.0)
	user.start_motion("leap", user.position, maxf(secs, 0.2), h, null, Callable(), 0.0)


## Pouso de salto/sumiço/túnel: acerta o alvo mais perto do ponto (alvo único) com impacto no chão.
func _land_strike(user: BattleFighter, mv: Dictionary, miss: BattleFighter) -> void:
	if not is_instance_valid(user) or not user.active():
		return
	user.hidden = ""
	var at := _flat(user.position)
	if arena.field:
		arena.field.on_move_landed(user, mv, at, 0.9)
	arena.fx_disc(at, 1.1, Color(0.85, 0.75, 0.55, 0.6), 0.25)
	PixelFx.pop(arena, "dust", at + Vector3(0, 0.3, 0), 1.6, 0.4)
	var best: BattleFighter = null
	var bd := STRIKE_R
	for t in arena.moves._victims(user, mv, at):
		if t == miss:
			continue
		var d := _flat(t.position - at).length()
		if d <= bd:
			bd = d
			best = t
	if best == null:
		if is_instance_valid(miss) and miss.active():
			miss.popup("Errou!", Color(0.75, 0.85, 1.0))
		return
	var to := _flat(best.position - at)
	arena.moves.hit(user, best, mv, to.normalized() if to.length() > 0.05 else user.facing)


# --- Aerial Ace: some e reaparece sobre o alvo ---


func start_blink(user: BattleFighter, mv: Dictionary, dir: Vector3, miss: BattleFighter) -> void:
	user.hidden = "blink"
	if user.look:
		user.look.visible = false
	if arena.vfx and arena.is_inside_tree():
		arena.vfx.puff(arena.to_global(user.position + Vector3(0, 0.45, 0)), 0.9)
	user.start_motion(
		"blink", user.position, 0.18, 0.0, null, _blink_drop.bind(user, mv, dir, miss), 0.0
	)


func _blink_drop(user: BattleFighter, mv: Dictionary, dir: Vector3, miss: BattleFighter) -> void:
	if not is_instance_valid(user) or not user.active():
		return
	var t: BattleFighter = user.opponent
	var at := user.position + dir * minf(float(mv.get("range", 6.0)), 4.0)
	if is_instance_valid(t) and t.active():
		var to := _flat(t.position - user.position)
		var d := to.normalized() if to.length() > 0.01 else dir
		at = t.position - d * 0.7
		user.facing = d
	if miss != null:
		at += dir.cross(Vector3.UP).normalized() * 1.6
	at.y = 0.0
	user.position = at + Vector3(0, 1.3, 0)
	if user.look:
		user.look.visible = true
	user.hidden = ""
	if arena.vfx and arena.vfx.has_method("blink"):
		arena.vfx.blink(user)
	user.start_motion(
		"leap", at, 0.14, 0.0, null, _land_strike.bind(user, mv, miss), 0.0, Callable(), 1.3
	)


# --- Dig / Dive: entra na terra, anda por baixo deixando rastro e sai embaixo do alvo ---


func start_tunnel(user: BattleFighter, mv: Dictionary, _dir: Vector3, miss: BattleFighter) -> void:
	var kind := tunnel_of(mv)
	user.hidden = kind
	user.popup(
		"Entrou na terra!" if kind == "dig" else "Mergulhou!", Color(0.85, 0.75, 0.55), 0.9, 0.9
	)
	if arena.vfx and arena.vfx.has_method("burrow"):
		arena.vfx.burrow(user)
	else:
		PixelFx.pop(arena, "dust", user.position + Vector3(0, 0.3, 0), 1.5, 0.45)
	user.start_motion(
		"burrow", user.position, 0.3, 0.0, null, _tunnel_go.bind(user, mv, miss), 0.0, _sink_tick
	)


func _sink_tick(f: BattleFighter, s: float, _dt: float) -> void:
	if f.look:
		f.look.position.y = -f.look_h * 1.2 * s
		f.look.visible = s < 0.95


func _tunnel_go(user: BattleFighter, mv: Dictionary, miss: BattleFighter) -> void:
	if not is_instance_valid(user) or not user.active():
		return
	var t: BattleFighter = user.opponent if is_instance_valid(user.opponent) else null
	var speed := float(mv.get("speed", 8.0))
	var secs := float(mv.get("range", 7.0)) / maxf(speed, 1.0) + 0.4
	var to := user.position + user.facing * float(mv.get("range", 7.0))
	if t and t.active():
		to = t.position
	var off := Vector3.ZERO
	if miss != null:
		off = user.facing.cross(Vector3.UP).normalized() * (1.7 if rng.randf() < 0.5 else -1.7)
		to += off
		t = null
	var from := _flat(user.position)
	if arena.vfx and arena.vfx.has_method("dig_trail"):
		arena.vfx.dig_trail(user, from, _flat(to), _flat(to - from).length() / maxf(speed, 1.0))
	var st := {"acc": 0.0}
	user.start_motion(
		"tunnel", to, secs, speed, t, _tunnel_up.bind(user, mv, miss), 1.0, _trail_tick.bind(st)
	)


## Fallback do rastro (sem arena.vfx.dig_trail): poeira no chão por onde passa.
func _trail_tick(f: BattleFighter, _s: float, dt: float, st: Dictionary) -> void:
	if arena.vfx and arena.vfx.has_method("dig_trail"):
		return
	st.acc += dt
	if st.acc >= TRAIL_EVERY:
		st.acc = 0.0
		PixelFx.pop(arena, "dust", _flat(f.position) + Vector3(0, 0.15, 0), 0.8, 0.5)


func _tunnel_up(user: BattleFighter, mv: Dictionary, miss: BattleFighter) -> void:
	if not is_instance_valid(user) or not user.active():
		return
	if arena.vfx and arena.vfx.has_method("unburrow"):
		arena.vfx.unburrow(user)
	if user.look:
		user.look.position.y = 0.0
		user.look.visible = true
	_land_strike(user, mv, miss)
	user.start_motion("leap", user.position, 0.22, 0.6, null, Callable(), 0.0)

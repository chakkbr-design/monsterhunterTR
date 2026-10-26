class_name BattleDirector
extends RefCounted
## Câmera de ação do treino no modo de energia (opts.action_cam; nunca no fast_sim nem no VGC).
## Enquadra todos os Pokémon em campo com uma margem pequena (CAM_MARGIN m) em vez de mostrar a
## quadra inteira, e faz as cenas:
## - golpe que vai nocautear (dano esperado >= HP do alvo): zoom no alvo e a luta a FINISH_SCALE
##   antes do golpe chegar; no desmaio, zoom mais fechado nele ainda em câmera lenta (KO_SECS);
## - golpe grande (poder >= BIG_BP): enquadra quem usou e o alvo, câmera um pouco lenta (BIG_SCALE);
## - troca (recolher ou soltar): todo mundo para (holding) até o antigo sair e o novo cair, com a
##   câmera no treinador e no ponto da bola.
## Os tempos das cenas são em segundos de luta (dt já escalado), para casarem com o desmaio e a bola.

const FOV := 50.0
const PITCH := deg_to_rad(30.0)
## Nas cenas de nocaute a câmera sobe (PITCH_KO) para os morros e pedras não taparem o alvo.
const PITCH_KO := deg_to_rad(48.0)
## Margin around each Pokémon, and the least body height that must fit (taller art uses its own
## visible height, BattleFighter.visual_height).
const CAM_MARGIN := 1.4
const BODY_H := 1.6
## Free band for the fight between the HUD: under the top cards (BattleHUD.top_band, one row in
## singles, two in doubles) plus TOP_PAD px, and above the bottom FRAME_BOT of the screen (log line
## and the training bar). The camera is raised (v_offset) to centre the picture in that band, so
## nobody it frames sits under the cards.
const TOP_PAD := 8.0
const FRAME_BOT := 0.12
## When the eased camera would leave someone it frames under the HUD (a change of scene, the fight
## spreading out), it catches up at this rate (per real second) instead of EASE, and at least
## GUARD_SPEED m/s, so a fighter running or knocked back never gets ahead of it.
const GUARD_EASE := 8.0
const GUARD_SPEED := 30.0
const MIN_DIST := 6.0
## Distance cap: on the energy court (48 x 28, Pokémon kept within +-23.5 x +-13.5) even two
## opposite corners fit a 16:9 screen (_need gives about 46.5 m for the whole rectangle with the
## margin, in the doubles band).
const MAX_DIST := 47.0
## Suavidade (por segundo real) do enquadramento normal e das cenas.
const EASE := 2.6
const EASE_SHOT := 5.0
## Golpe que nocauteia: velocidade da luta, tempo de espera pelo acerto e folga entre alarmes falsos.
const FINISH_SCALE := 0.5
const FINISH_WAIT := 1.2
const FINISH_GAP := 2.5
const FINISH_MARGIN := 1.6
## O dano esperado é a média: um pouco acima dela já conta (rolagem alta, crítico).
const FINISH_ROLL := 1.1
## Desmaio: tempo do zoom (a arena some com o corpo em FAINT_CLEAR = 1 s) e a margem.
const KO_SECS := 1.1
const KO_MARGIN := 0.9
const KO_DIST := 4.5
## Golpe grande: poder mínimo (o nominal, multi-hit conta os acertos), duração, velocidade e folga.
const BIG_BP := 100.0
const BIG_SECS := 0.9
const BIG_SCALE := 0.75
const BIG_GAP := 3.0
const BIG_MARGIN := 1.2
## Troca: tempo mínimo parado depois do raio e depois da bola abrir; teto de segurança.
const RECALL_HOLD := 0.6
const OPEN_HOLD := 0.5
## O treinador entra no quadro da troca se estiver a menos disto (m) do ponto da bola: na quadra de
## 48 m ele fica a 24,8 m do centro e a bola cai a ENTRY_X = 6 m (ou onde o anterior estava).
const SWITCH_TRAINER := 20.0
const HOLD_MAX := 6.0

var arena: Node
## Cena atual: "" (enquadrar todos), "finish", "ko", "big", "switch".
var shot := ""
var shot_t := 0.0
var target: BattleFighter = null
var user: BattleFighter = null
var _switch_at := Vector3.ZERO
var _switch_side := 0
var _hold_t := 0.0
var _held := 0.0
var _await_send := false
var _finish_gap := 0.0
var _big_gap := 0.0
var _focus := Vector3.ZERO
var _dist := MAX_DIST
var _snap := true
var _pitch := PITCH


func _init(a: Node) -> void:
	arena = a


## Velocidade da luta agora (a arena multiplica o dt).
func time_scale() -> float:
	match shot:
		"finish", "ko":
			return FINISH_SCALE
		"big":
			return BIG_SCALE
	return 1.0


## Troca em andamento: ninguém age (a arena só roda os eventos e a bola).
func holding() -> bool:
	if _held >= HOLD_MAX:
		return false
	var balls: Array = arena.get("_balls")
	return _hold_t > 0.0 or not balls.is_empty() or _await_send


## Passo da luta (dt escalado).
func tick(dt: float) -> void:
	_finish_gap = maxf(_finish_gap - dt, 0.0)
	_big_gap = maxf(_big_gap - dt, 0.0)
	if holding():
		_hold_t = maxf(_hold_t - dt, 0.0)
		_held += dt
	else:
		_held = 0.0
		_await_send = false
		if shot == "switch":
			shot = ""
	if shot in ["finish", "ko", "big"]:
		shot_t -= dt
		if shot_t <= 0.0 or (shot == "finish" and not _ok(target)):
			shot = ""
	if _await_send and not _waiting_replacement():
		_await_send = false


func _ok(f) -> bool:
	return f is BattleFighter and is_instance_valid(f) and f.active()


func _waiting_replacement() -> bool:
	var pend: Array = arena.get("_pending")
	return not pend.is_empty() or int(arena.get("_enemy_pending")) > 0


# --- Ganchos da arena ---


func on_move(u: BattleFighter, mv: Dictionary) -> void:
	if shot in ["switch", "ko", "finish"] or String(mv.get("category", "")) == "status":
		return
	var t = u.opponent
	if _ok(t) and t.side != u.side and _finish_gap <= 0.0 and _lethal(u, t, mv):
		shot = "finish"
		user = u
		target = t
		shot_t = FINISH_WAIT + Dex.prepare_time(mv) + float(mv.get("duration", 0.0))
		_finish_gap = FINISH_GAP
		return
	if _big_gap <= 0.0 and BattleEnergy.nominal_bp(mv) >= BIG_BP and float(mv.get("bp", 0)) > 0:
		shot = "big"
		user = u
		target = t if _ok(t) else null
		shot_t = BIG_SECS
		_big_gap = BIG_GAP


## O golpe deve nocautear: dano esperado (o da IA, sem sorteio) x FINISH_ROLL >= HP; a entrada
## protegida segura.
func _lethal(u: BattleFighter, t: BattleFighter, mv: Dictionary) -> bool:
	var mvs = arena.get("moves")
	if mvs == null:
		return false
	if t.entry_t > 0.0 and t.hp >= t.max_hp:
		return false
	if String(mv.get("special", "")) == "future_sight":
		return false  # cai segundos depois: o zoom do desmaio cobre
	var est: float = mvs.expected_damage(u, t, mv)
	if String(mv.get("kind", "")) in ["zone", "stream"] and float(mv.get("tick", 0.0)) > 0.0:
		est *= maxf(float(mv.get("duration", 0.0)) / float(mv.tick), 1.0)  # vários acertos
	return est * FINISH_ROLL >= float(t.hp)


func on_faint(f: BattleFighter) -> void:
	if shot == "switch":
		return
	shot = "ko"
	target = f
	shot_t = KO_SECS


func on_recall(f: BattleFighter) -> void:
	_hold_t = maxf(_hold_t, RECALL_HOLD)
	_await_send = _waiting_replacement()
	_start_switch(f.side, f.position)


func on_send(side: int, at: Vector3) -> void:
	_start_switch(side, at)


func on_ball_open() -> void:
	_hold_t = maxf(_hold_t, OPEN_HOLD)
	_await_send = _waiting_replacement()


func _start_switch(side: int, at: Vector3) -> void:
	if shot == "ko" and shot_t > 0.0 and not _await_send:
		return  # o último do lado caiu: o zoom fica nele
	shot = "switch"
	_switch_side = side
	_switch_at = at * Vector3(1, 0, 1)


# --- Câmera ---


func camera(cam: Camera3D, raw: float) -> void:
	if cam == null:
		return
	cam.fov = FOV
	var pts: Array = []
	var margin := float(
		{"finish": FINISH_MARGIN, "ko": KO_MARGIN, "big": BIG_MARGIN}.get(shot, CAM_MARGIN)
	)
	var ease := EASE_SHOT if _scene_fighters().size() > 0 or shot == "switch" else EASE
	if shot == "switch":
		pts.append(_switch_at)
		pts.append(_switch_at + Vector3(0, BODY_H, 0))
		if arena.has_method("trainer_spot"):
			var tp: Vector3 = arena.trainer_spot(_switch_side)
			if (tp - _switch_at).length() < SWITCH_TRAINER:
				pts.append(tp)
				pts.append(tp + Vector3(0, BODY_H + 0.2, 0))
	for f in framed():
		var p: Vector3 = f.position
		pts.append(p)
		pts.append(p + Vector3(0, maxf(BODY_H, f.visual_height()), 0))
	if pts.is_empty():
		for side in [0, 1]:
			pts.append(arena.trainer_spot(side))
	var box := _box(pts, margin)
	var band := _band(cam)
	var want_focus := Vector3((box[0].x + box[1].x) * 0.5, box[0].y, (box[0].z + box[1].z) * 0.5)
	var want_d := _need(box, want_focus, _shot_pitch(), band, KO_DIST if shot == "ko" else MIN_DIST)
	var k := 1.0 if _snap else clampf(raw * ease, 0.0, 1.0)
	_snap = false
	_focus = _focus.lerp(want_focus, k)
	_dist = lerpf(_dist, want_d, k)
	_pitch = lerpf(_pitch, _shot_pitch(), k)
	# The eased camera must still hold what it frames inside the band (a switch of scene, fighters
	# spreading out): catch up quickly, the focus first, then back off to what still does not fit.
	if _need(box, _focus, _pitch, band, 0.0) > _dist:
		var kg := clampf(raw * GUARD_EASE, 0.0, 1.0)
		_focus = _focus.lerp(want_focus, kg)
		var need := maxf(_need(box, _focus, _pitch, band, 0.0), _dist)
		_dist = minf(lerpf(_dist, need, kg) + raw * GUARD_SPEED, need)
	var off := Vector3(0, sin(_pitch), cos(_pitch)) * _dist
	cam.position = _focus + off
	# Raising the camera along its own up moves the picture down into the band (under the cards).
	cam.v_offset = _dist * band[2]
	if cam.is_inside_tree():
		cam.look_at(cam.get_parent().to_global(_focus), Vector3.UP)


func _shot_pitch() -> float:
	return PITCH_KO if shot in ["finish", "ko"] else PITCH


## The fighters the camera frames now: the scene's (finish, knockout, big move) or, without one,
## everyone on the field. Empty in the switch scene, which frames the trainer and the ball spot.
func framed() -> Array:
	if shot == "switch":
		return []
	var out := _scene_fighters()
	if out.is_empty():
		for f in arena.get("fighters"):
			if is_instance_valid(f) and f.on_field and f.visible:
				out.append(f)
	return out


## The finish scene frames the target (and the user when close), the knockout the fainted one, a
## big move its user (and the target when close).
func _scene_fighters() -> Array:
	var out: Array = []
	match shot:
		"finish":
			out.append(target)
			if _ok(user) and user.flat_to(target).length() < 5.0:
				out.append(user)
		"ko":
			out.append(target)
		"big":
			out.append(user)
			if _ok(target) and user.flat_to(target).length() < 9.0:
				out.append(target)
	return out.filter(func(f) -> bool: return f is BattleFighter and is_instance_valid(f))


## Box of the points with the margin around them (x and z only): [lo, hi].
static func _box(pts: Array, margin: float) -> Array:
	var lo: Vector3 = pts[0]
	var hi: Vector3 = pts[0]
	for p in pts:
		lo = lo.min(p)
		hi = hi.max(p)
	return [lo - Vector3(margin, 0, margin), hi + Vector3(margin, 0, margin)]


## The usable screen as tangents of the half field of view: [top, bottom, shift, side]. A point may
## project up to `top` above and `bottom` below the view centre once the camera is raised by `shift`
## x its distance (v_offset): the top is under the HUD cards, the bottom over the log. `side` is the
## horizontal half width (with a little slack at the edges).
func _band(cam: Camera3D) -> Array:
	var vp := cam.get_viewport()
	var sz: Vector2 = vp.get_visible_rect().size if vp else Vector2(1152, 648)
	var rows := 2 if int(arena.get("_battle_size")) >= 2 else 1
	var top_px := BattleHUD.top_band(rows) + TOP_PAD
	var t := tan(deg_to_rad(FOV) * 0.5)
	var ft := clampf(1.0 - 2.0 * top_px / maxf(sz.y, 1.0), 0.1, 1.0)
	var fb := 1.0 - 2.0 * FRAME_BOT
	return [t * ft, t * fb, t * (fb - ft) * 0.5, t * sz.x / maxf(sz.y, 1.0) * 0.92]


## Smallest camera distance (pitch `pt`, looking at `focus`, raised by the band's shift) at which
## the whole box fits the screen width and the free band, at least `min_d` and at most MAX_DIST.
func _need(box: Array, focus: Vector3, pt: float, band: Array, min_d: float) -> float:
	var lo: Vector3 = box[0]
	var hi: Vector3 = box[1]
	var top: float = band[0]
	var bot: float = band[1]
	var s: float = band[2]
	var tx: float = band[3]
	var fwd := -Vector3(0, sin(pt), cos(pt))
	var up := Vector3(0, cos(pt), -sin(pt))
	var d := min_d
	for x in [lo.x, hi.x]:
		for y in [lo.y, hi.y]:
			for z in [lo.z, hi.z]:
				var q := Vector3(x, y, z) - focus
				var u := q.dot(up)
				var f := q.dot(fwd)
				# Depth d + f; height on screen (u - s d) / (d + f) between -bot and top.
				d = maxf(d, absf(q.x) / tx - f)
				d = maxf(d, (u - top * f) / (top + s))
				d = maxf(d, (-u - bot * f) / (bot - s))
	return minf(d, MAX_DIST)

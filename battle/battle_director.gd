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
## Margem em volta de cada Pokémon e altura do corpo que precisa caber.
const CAM_MARGIN := 1.4
const BODY_H := 1.6
## Folga para o HUD (cartões em cima, log embaixo): a altura útil da tela é FRAME_V dela.
const FRAME_V := 0.82
const MIN_DIST := 6.0
const MAX_DIST := 22.0
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
## O treinador entra no quadro da troca se estiver a menos disto (m) do ponto da bola.
const SWITCH_TRAINER := 10.0
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
	var margin := CAM_MARGIN
	var ease := EASE_SHOT
	match shot:
		"finish":
			margin = FINISH_MARGIN
			_body_pts(pts, target)
			if _ok(user) and user.flat_to(target).length() < 5.0:
				_body_pts(pts, user)
		"ko":
			margin = KO_MARGIN
			_body_pts(pts, target)
		"big":
			margin = BIG_MARGIN
			_body_pts(pts, user)
			if _ok(target) and user.flat_to(target).length() < 9.0:
				_body_pts(pts, target)
		"switch":
			pts.append(_switch_at)
			pts.append(_switch_at + Vector3(0, BODY_H, 0))
			if arena.has_method("trainer_spot"):
				var tp: Vector3 = arena.trainer_spot(_switch_side)
				if (tp - _switch_at).length() < SWITCH_TRAINER:
					pts.append(tp)
					pts.append(tp + Vector3(0, BODY_H + 0.2, 0))
	if pts.is_empty():
		ease = EASE
		for f in arena.get("fighters"):
			if is_instance_valid(f) and f.on_field and f.visible:
				_body_pts(pts, f)
	if pts.is_empty():
		for side in [0, 1]:
			pts.append(arena.trainer_spot(side))
	var want := _fit(pts, margin, cam, KO_DIST if shot == "ko" else MIN_DIST)
	var k := 1.0 if _snap else clampf(raw * ease, 0.0, 1.0)
	_snap = false
	_focus = _focus.lerp(want[0], k)
	_dist = lerpf(_dist, want[1], k)
	_pitch = lerpf(_pitch, _shot_pitch(), k)
	var off := Vector3(0, sin(_pitch), cos(_pitch)) * _dist
	cam.position = _focus + off
	if cam.is_inside_tree():
		cam.look_at(cam.get_parent().to_global(_focus), Vector3.UP)


func _shot_pitch() -> float:
	return PITCH_KO if shot in ["finish", "ko"] else PITCH


func _body_pts(pts: Array, f) -> void:
	if not (f is BattleFighter) or not is_instance_valid(f):
		return
	var p: Vector3 = f.position
	pts.append(p)
	pts.append(p + Vector3(0, BODY_H, 0))


## Foco (centro dos pontos no chão) e a menor distância da câmera (pitch fixo) em que todos os pontos,
## com a margem, cabem na tela.
func _fit(pts: Array, margin: float, cam: Camera3D, min_d: float) -> Array:
	var lo: Vector3 = pts[0]
	var hi: Vector3 = pts[0]
	for p in pts:
		lo = lo.min(p)
		hi = hi.max(p)
	lo -= Vector3(margin, 0, margin)
	hi += Vector3(margin, 0, margin)
	var focus := Vector3((lo.x + hi.x) * 0.5, lo.y, (lo.z + hi.z) * 0.5)
	var vp := cam.get_viewport()
	var sz: Vector2 = vp.get_visible_rect().size if vp else Vector2(16, 9)
	var aspect := sz.x / maxf(sz.y, 1.0)
	var ty := tan(deg_to_rad(FOV) * 0.5) * FRAME_V
	var tx := tan(deg_to_rad(FOV) * 0.5) * aspect * 0.92
	var pt := _shot_pitch()
	var fwd := -Vector3(0, sin(pt), cos(pt))
	var up := Vector3(0, cos(pt), -sin(pt))
	var d := min_d
	for x in [lo.x, hi.x]:
		for y in [lo.y, hi.y]:
			for z in [lo.z, hi.z]:
				var q := Vector3(x, y, z) - focus
				d = maxf(d, absf(q.x) / tx - q.dot(fwd))
				d = maxf(d, absf(q.dot(up)) / ty - q.dot(fwd))
	return [focus, minf(d, MAX_DIST)]

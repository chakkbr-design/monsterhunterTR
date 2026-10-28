class_name BattleDirector
extends RefCounted
## Câmera de ação do treino (opts.action_cam; nunca no fast_sim).
## Enquadra todos os Pokémon em campo com uma margem pequena (CAM_MARGIN m) em vez de mostrar a
## quadra inteira, e faz as cenas:
## - nocaute (só o de verdade: o golpe já acertou, o HP zerou e nada o segurou — Focus Sash, Sturdy,
##   a amizade, a entrada protegida): no impacto a luta quase congela (KO_HIT_SCALE por KO_HIT s) e
##   a câmera fecha no desmaiado em câmera lenta (KO_SCALE por KO_SECS). Não há mais o zoom antes
##   do golpe pela previsão de dano (Caio, 2026-10-26: o alvo desviava e o zoom vinha mesmo assim);
## - golpe grande (poder >= BIG_BP): enquadra quem usou e o alvo, câmera um pouco lenta (BIG_SCALE);
## - troca e substituto durante a luta (Caio, 2026-10-27): sem cena nenhuma. O treinador recolhe e
##   joga a bola, a câmera segue enquadrando todos e a luta não para;
## - soltar na abertura do treino (shot "send", BallShow): close no treinador enquanto ele prepara o
##   arremesso, a câmera segue a bola até o ponto onde cai e fecha no Pokémon que saiu por MON_BEAT
##   s (holding segura a abertura); depois volta a enquadrar todos;
## - cena fixa (set_cine, a abertura do treino): enquadra os pontos dados (o telão, a arena inteira).
## Os tempos das cenas são em segundos de luta (dt já escalado), para casarem com o desmaio e a bola.

const FOV := 50.0
## The one camera angle (Caio, 2026-10-27): every scene (knockout, ball, opening, cine) keeps
## this pitch and the fixed yaw, and zooms only by moving closer along the same line of sight.
## Obstacles in the way fade instead (FADE_*).
const PITCH := deg_to_rad(30.0)
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
## Nocaute: o impacto quase congela (KO_HIT s de luta a KO_HIT_SCALE, o hit-stop da cena) e depois
## o zoom em câmera lenta (KO_SCALE) por KO_SECS (a arena some com o corpo em FAINT_CLEAR = 1 s).
const KO_HIT := 0.06
const KO_HIT_SCALE := 0.2
const KO_SCALE := 0.75  # Caio, 2026-10-27: 0,5x deixava os closes lentos demais
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
## Soltar (shot "send"): close no treinador (distância mínima, margem, inclinação), a bola em voo
## (a bola e o ponto onde cai) e o Pokémon que saiu, que segura a luta MON_BEAT s depois de a bola
## abrir.
const SEND_TRAINER_DIST := 5.0
const SEND_TRAINER_MARGIN := 1.2
const SEND_TRAINER_PITCH := deg_to_rad(16.0)
const SEND_BALL_DIST := 8.0
const SEND_BALL_MARGIN := 2.0
const SEND_BALL_PITCH := deg_to_rad(26.0)
const SEND_MON_DIST := 4.5
const SEND_MON_MARGIN := 1.0
const SEND_MON_PITCH := deg_to_rad(20.0)
const MON_BEAT := 0.8
const HOLD_MAX := 6.0
## Obstacles in the way fade (GeometryInstance3D.transparency, like the overworld camera's
## buildings) to FADE_ALPHA at FADE_RATE per real second: what stands between the eye and a
## fighter, what the eye is inside of or within FADE_EYE m of, and anything within FADE_NEAR m of
## the eye, in front of every fighter, that fills over FADE_COVER of the screen (a boulder right at
## the lens). Flat things (under FADE_MIN_H m tall) never fade.
const FADE_ALPHA := 0.6
const FADE_RATE := 4.0
const FADE_EYE := 1.5
const FADE_NEAR := 6.0
const FADE_COVER := 0.15
const FADE_MIN_H := 0.5
## A sight line this close (m) above a hill or peak's profile already counts as hidden.
const RELIEF_PAD := 0.1
## The fade tests run at most this often (real seconds): the fade itself takes 1 / FADE_RATE.
const FADE_STEP := 1.0 / 30.0

var arena: Node
## Cena atual: "" (enquadrar todos), "ko", "big", "switch", "send".
var shot := ""
var shot_t := 0.0
var target: BattleFighter = null
var user: BattleFighter = null
var _switch_at := Vector3.ZERO
var _switch_side := 0
var _hold_t := 0.0
var _held := 0.0
var _await_send := false
## Quem saiu da bola na cena "send" (o zoom depois de ela abrir).
var _spot: Array = []
## Cena fixa {pts (locais da arena), margin, pitch, min_d} (set_cine; o pitch é ignorado, a câmera
## fica sempre em PITCH); vazio = as cenas normais.
var cine := {}
var _ko_hit := 0.0
var _big_gap := 0.0
var _focus := Vector3.ZERO
var _dist := MAX_DIST
var _snap := true
var _pitch := PITCH
## Obstacle node -> [child count, its GeometryInstance3D] (found once, again if its children change).
var _geoms := {}
var _fade_t := 0.0


func _init(a: Node) -> void:
	arena = a


## Velocidade da luta agora (a arena multiplica o dt).
func time_scale() -> float:
	match shot:
		"ko":
			return KO_HIT_SCALE if _ko_hit > 0.0 else KO_SCALE
		"big":
			return BIG_SCALE
	return 1.0


## Fim da luta (estado "ending", sem tick): o zoom do último nocaute ainda acaba no tempo dele, senão a
## câmera lenta seguraria a espera do resultado inteira.
func cool(dt: float) -> void:
	_ko_hit = maxf(_ko_hit - dt, 0.0)
	if shot in ["ko", "big"]:
		shot_t -= dt
		if shot_t <= 0.0:
			shot = ""


## Bola da abertura em andamento: ninguém age. Na luta a troca não segura nada.
func holding() -> bool:
	if _held >= HOLD_MAX or _in_fight():
		return false
	var balls: Array = arena.get("_balls")
	return _hold_t > 0.0 or not balls.is_empty() or _await_send


## Passo da luta (dt escalado).
func tick(dt: float) -> void:
	_ko_hit = maxf(_ko_hit - dt, 0.0)
	_big_gap = maxf(_big_gap - dt, 0.0)
	if holding():
		_hold_t = maxf(_hold_t - dt, 0.0)
		_held += dt
	else:
		_held = 0.0
		_await_send = false
		if shot in ["switch", "send"]:
			shot = ""
			_spot.clear()
	if shot in ["ko", "big"]:
		shot_t -= dt
		if shot_t <= 0.0:
			shot = ""
			var side := _ball_side()
			if side >= 0 and not _in_fight():
				shot = "send"  # o zoom do desmaio acabou com uma bola no ar: segue a bola
				_switch_side = side
	if _await_send and not _waiting_replacement():
		_await_send = false


## Luta de verdade (não a abertura): troca e substituto não mexem na câmera.
func _in_fight() -> bool:
	return String(arena.get("state")) in ["fight", "ending"]


func _ok(f) -> bool:
	return f is BattleFighter and is_instance_valid(f) and f.active()


func _waiting_replacement() -> bool:
	var pend: Array = arena.get("_pending")
	return not pend.is_empty() or int(arena.get("_enemy_pending")) > 0


# --- Ganchos da arena ---


func on_move(u: BattleFighter, mv: Dictionary) -> void:
	if shot in ["switch", "send", "ko"] or String(mv.get("category", "")) == "status":
		return
	var t = u.opponent
	if _big_gap <= 0.0 and BattleEnergy.nominal_bp(mv) >= BIG_BP and float(mv.get("bp", 0)) > 0:
		shot = "big"
		user = u
		target = t if _ok(t) else null
		shot_t = BIG_SECS
		_big_gap = BIG_GAP


## Nocaute de verdade (o sinal fainted sai depois do dano e das defesas contra o golpe fatal):
## hit-stop no impacto e zoom em câmera lenta no desmaiado.
func on_faint(f: BattleFighter) -> void:
	if shot == "switch":
		return
	shot = "ko"
	target = f
	shot_t = KO_SECS
	_ko_hit = KO_HIT


func on_recall(f: BattleFighter) -> void:
	if _in_fight():
		return
	_hold_t = maxf(_hold_t, RECALL_HOLD)
	_await_send = _waiting_replacement()
	_start_switch(f.side, f.position)


func on_send(side: int, at: Vector3) -> void:
	if _in_fight():
		return
	if shot != "send" or side != _switch_side:
		_spot.clear()
	_start_switch(side, at)
	if shot == "switch":
		shot = "send"


## A bola abriu; f = quem saiu dela (o zoom de MON_BEAT s nele).
func on_ball_open(f: BattleFighter = null) -> void:
	if _in_fight():
		return
	_hold_t = maxf(_hold_t, MON_BEAT if f else OPEN_HOLD)
	_await_send = _waiting_replacement()
	if f and not _spot.has(f):
		_spot.append(f)


## Cena fixa: enquadra `pts` (locais da arena) com essa margem, inclinação (rad) e distância mínima
## até clear_cine(). A abertura do treino usa para o telão e a arena inteira.
func set_cine(pts: Array, margin: float, pitch: float, min_d: float) -> void:
	cine = {"pts": pts, "margin": margin, "pitch": pitch, "min_d": min_d}


func clear_cine() -> void:
	cine = {}


## Lado da 1ª bola ainda fechada (-1 = nenhuma).
func _ball_side() -> int:
	for e in arena.get("_balls"):
		if not bool(e.get("opened", true)):
			return int(e.get("side", 0))
	return -1


## Bolas ainda fechadas do lado da cena "send".
func _side_balls() -> Array:
	var out: Array = []
	for e in arena.get("_balls"):
		if not bool(e.get("opened", true)) and int(e.get("side", -1)) == _switch_side:
			out.append(e)
	return out


## Quadro da cena "send": [pontos, margem, inclinação, distância mínima]. Com o treinador ainda
## preparando: ele de perto; com a bola no ar: a bola e onde ela cai; depois: quem saiu (framed).
func _send_frame() -> Array:
	# Recolher pela bola: a bola indo até o Pokémon e ele entrando antes do close no treinador.
	for e in arena.get("_balls"):
		if (
			bool(e.get("recall", false))
			and int(e.get("side", -1)) == _switch_side
			and float(e.t) < float(e.get("watch", 0.0))
		):
			var to: Vector3 = e.get("to", _switch_at)
			var floor_at := Vector3(to.x, maxf(to.y - 1.0, 0.0), to.z)
			var rp: Array = [floor_at, floor_at + Vector3(0, BODY_H, 0), _switch_at]
			var b = e.get("ball")
			if b is Node3D and is_instance_valid(b):
				rp.append((b as Node3D).position)
			return [rp, SEND_BALL_MARGIN, SEND_BALL_PITCH, SEND_BALL_DIST]
	var balls := _side_balls()
	if balls.is_empty():
		var pts: Array = []
		if _spot_fighters().is_empty():
			pts = [_switch_at, _switch_at + Vector3(0, BODY_H, 0)]
		return [pts, SEND_MON_MARGIN, SEND_MON_PITCH, SEND_MON_DIST]
	if balls.all(func(e) -> bool: return float(e.t) < float(e.get("windup", 0.0))):
		var tp: Vector3 = arena.trainer_spot(_switch_side)
		return [
			[tp, tp + Vector3(0, BODY_H + 0.3, 0)],
			SEND_TRAINER_MARGIN,
			SEND_TRAINER_PITCH,
			SEND_TRAINER_DIST
		]
	var pts: Array = []
	for e in balls:
		var b = e.get("ball")
		if b is Node3D and is_instance_valid(b):
			pts.append((b as Node3D).position)
		var to: Vector3 = e.get("to", _switch_at)
		pts.append(Vector3(to.x, float(e.get("ground", 0.0)), to.z))
		pts.append(Vector3(to.x, float(e.get("ground", 0.0)) + BODY_H, to.z))
	return [pts, SEND_BALL_MARGIN, SEND_BALL_PITCH, SEND_BALL_DIST]


func _spot_fighters() -> Array:
	return _spot.filter(
		func(f) -> bool: return f is BattleFighter and is_instance_valid(f) and f.visible
	)


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
	var margin := float({"ko": KO_MARGIN, "big": BIG_MARGIN}.get(shot, CAM_MARGIN))
	var ease := (
		EASE_SHOT
		if _scene_fighters().size() > 0 or shot in ["switch", "send"] or not cine.is_empty()
		else EASE
	)
	var pitch := PITCH
	var min_d := KO_DIST if shot == "ko" else MIN_DIST
	if not cine.is_empty():
		pts = (cine.pts as Array).duplicate()
		margin = float(cine.margin)
		min_d = float(cine.min_d)
	elif shot == "send":
		var fr := _send_frame()
		pts = fr[0]
		margin = fr[1]
		min_d = fr[3]
	elif shot == "switch":
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
	var want_d := _need(box, want_focus, pitch, band, min_d)
	var k := 1.0 if _snap else clampf(raw * ease, 0.0, 1.0)
	_snap = false
	_focus = _focus.lerp(want_focus, k)
	_dist = lerpf(_dist, want_d, k)
	_pitch = lerpf(_pitch, pitch, k)
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
		_fade_t += raw
		if _fade_t >= FADE_STEP:
			_fade_obstacles(cam, _fade_t)
			_fade_t = 0.0


## Obstacles that can stand in the camera's way, as [node, relief]: relief (hills and peaks, with
## their BattleTerrain dictionary; not the ponds), props (trees, boulders, crystals...), biome
## solids and field objects (relief {}). Null nodes (fast_sim) are skipped.
func _obstacle_nodes() -> Array:
	var all: Array = []
	var ter = arena.get("terrain")
	if ter:
		for o in ter.obstacles:
			if String(o.get("kind", "")) != "pond":
				all.append([o.get("node"), o])
		if ter.props:
			for it in ter.props.items:
				all.append([it.get("node"), {}])
		if ter.biomes:
			for so in ter.biomes.solids:
				all.append([so.get("node"), {}])
	var fld = arena.get("field")
	if fld:
		for ob in fld.objects:
			all.append([ob.get("node"), {}])
	return all.filter(
		func(e: Array) -> bool:
			return e[0] is Node3D and is_instance_valid(e[0]) and e[0].is_inside_tree()
	)


## Every obstacle mesh the camera may fade.
func obstacles() -> Array:
	var out: Array = []
	for e in _obstacle_nodes():
		out.append_array(_geoms_of(e[0]))
	return out


func _geoms_of(n: Node3D) -> Array:
	var c: Array = _geoms.get(n, [])
	if c.is_empty() or int(c[0]) != n.get_child_count():
		c = [n.get_child_count(), n.find_children("*", "GeometryInstance3D", true, false)]
		_geoms[n] = c
	return c[1]


## Fades each obstacle (all its meshes together) that is in the way, and brings it back after.
func _fade_obstacles(cam: Camera3D, raw: float) -> void:
	var eye := cam.get_camera_transform().origin
	var fwd := -cam.global_transform.basis.z
	var aims: Array = []
	var near := INF
	for f in arena.get("fighters"):
		if is_instance_valid(f) and f.on_field and f.visible:
			var h: float = f.visual_height()
			var g: Vector3 = f.global_position
			aims.append(g + Vector3(0, h * 0.5, 0))
			aims.append(g + Vector3(0, h * 0.9, 0))
			near = minf(near, (g - eye).dot(fwd))
	var vp := cam.get_viewport().get_visible_rect().size
	var nodes := _obstacle_nodes()
	if _geoms.size() > nodes.size() * 2:
		_geoms.clear()  # nodes gone (a hill collapsed, a tree burnt): find them again
	for e in nodes:
		var geoms: Array = _geoms_of(e[0])
		var relief: Dictionary = e[1]
		var hit := not relief.is_empty() and _relief_hides(relief, eye, aims)
		for gi in geoms:
			if hit:
				break
			if is_instance_valid(gi) and gi.is_visible_in_tree():
				hit = _in_the_way(gi, cam, eye, fwd, aims if relief.is_empty() else [], near, vp)
		for gi in geoms:
			if is_instance_valid(gi):
				_fade(gi, FADE_ALPHA if hit else 0.0, raw)


func _fade(gi: GeometryInstance3D, want: float, raw: float) -> void:
	if is_equal_approx(gi.transparency, want):
		return
	gi.transparency = move_toward(gi.transparency, want, raw * FADE_RATE)
	# A ghost casts no shadow (as in the overworld); the old setting comes back with it.
	if gi.transparency > 0.0:
		if not gi.has_meta("fade_shadow"):
			gi.set_meta("fade_shadow", gi.cast_shadow)
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	elif gi.has_meta("fade_shadow"):
		gi.cast_shadow = gi.get_meta("fade_shadow")
		gi.remove_meta("fade_shadow")


## A hill or peak hides a fighter: the sight line dips under its profile somewhere over its
## footprint. The profile is the gameplay one (BattleTerrain._height_of: flat top of radius `top`
## at height `h`, straight slope out to `r`), which the voxel relief follows.
func _relief_hides(o: Dictionary, eye: Vector3, aims: Array) -> bool:
	var c: Vector3 = o.pos
	var r: float = o.r
	var top: float = o.top
	var h: float = o.h
	var a: Vector3 = arena.to_local(eye)
	for p in aims:
		var b: Vector3 = arena.to_local(p)
		# Part of the sight line over the footprint: |flat(a + t (b - a) - c)| < r.
		var dv := Vector2(b.x - a.x, b.z - a.z)
		var fv := Vector2(a.x - c.x, a.z - c.z)
		var qa := dv.dot(dv)
		var qb := 2.0 * fv.dot(dv)
		var disc := qb * qb - 4.0 * qa * (fv.dot(fv) - r * r)
		if qa < 0.0001 or disc <= 0.0:
			continue
		var t0 := clampf((-qb - sqrt(disc)) / (2.0 * qa), 0.0, 1.0)
		var t1 := clampf((-qb + sqrt(disc)) / (2.0 * qa), 0.0, 1.0)
		for i in 9:
			var q := a.lerp(b, lerpf(t0, t1, i / 8.0))
			var d := Vector2(q.x - c.x, q.z - c.z).length()
			var y := h if d <= top else h * (1.0 - (d - top) / maxf(r - top, 0.01))
			if d < r and q.y < y + RELIEF_PAD:
				return true
	return false


## A mesh in the way: the eye inside or close to it, its box across a sight line (`aims`; none
## for relief, which _relief_hides tests on its real shape), or close to the lens and filling over
## FADE_COVER of the screen in front of every fighter.
func _in_the_way(
	gi: GeometryInstance3D,
	cam: Camera3D,
	eye: Vector3,
	fwd: Vector3,
	aims: Array,
	near: float,
	vp: Vector2
) -> bool:
	var box := gi.get_aabb()
	if box.size.y < FADE_MIN_H:
		return false
	var xf := gi.global_transform
	var inv := xf.affine_inverse()
	var le := inv * eye
	if box.grow(FADE_EYE).has_point(le):
		return true
	for p in aims:
		if box.intersects_segment(le, inv * p) != null:
			return true
	var depth := (xf * box.get_center() - eye).dot(fwd)
	if depth <= 0.0 or depth > near - 1.0:
		return false
	if (xf * le.clamp(box.position, box.end) - eye).length() > FADE_NEAR:
		return false
	var rect := Rect2()
	var seen := 0
	for i in 8:
		var w := xf * box.get_endpoint(i)
		if cam.is_position_behind(w):
			continue
		var sp := cam.unproject_position(w)
		rect = Rect2(sp, Vector2.ZERO) if seen == 0 else rect.expand(sp)
		seen += 1
	var cover := rect.intersection(Rect2(Vector2.ZERO, vp)).get_area() / maxf(vp.x * vp.y, 1.0)
	return seen > 1 and cover > FADE_COVER


## The fighters the camera frames now: the scene's (knockout, big move) or, without one,
## everyone on the field. Empty in the switch scene, which frames the trainer and the ball spot.
func framed() -> Array:
	if shot == "switch" or not cine.is_empty():
		return []
	if shot == "send":
		return [] if not _side_balls().is_empty() else _spot_fighters()
	var out := _scene_fighters()
	if out.is_empty():
		for f in arena.get("fighters"):
			if is_instance_valid(f) and f.on_field and f.visible:
				out.append(f)
	return out


## The knockout frames the fainted one, a big move its user (and the target when close).
func _scene_fighters() -> Array:
	var out: Array = []
	match shot:
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
	var bot := FRAME_BOT
	# Vídeo vertical (opts.frame_band = [topo, baixo], frações da tela): o HUD do vídeo cobre essas
	# faixas (tools/video/make_vertical.py), e a luta fica no meio.
	var band = arena.get("opts").get("frame_band") if arena.get("opts") is Dictionary else null
	if band is Array and band.size() == 2:
		top_px = float(band[0]) * sz.y
		bot = float(band[1])
	var t := tan(deg_to_rad(FOV) * 0.5)
	var ft := clampf(1.0 - 2.0 * top_px / maxf(sz.y, 1.0), 0.1, 1.0)
	var fb := 1.0 - 2.0 * bot
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

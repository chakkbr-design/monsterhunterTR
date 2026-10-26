class_name WorldCompanion
extends Node3D
## Um Pokémon da equipe fora da bola (o creature.gd do original em modo FOLLOW): segue o rastro do
## jogador, para em roda dele quando ele para, faz as ações do humor (COME / ORBIT / NAP / PLAY),
## pede descanso quando cansado, busca fruta e senta no piquenique. E faz carinho, F dá comida.
## O status (queimadura, veneno, paralisia, sono) corre fora da bola como no original (combatant.gd
## _tick_status): dano a cada 1 s e some sozinho depois de STATUS_TIME.
## Visual apenas (sem colisão); WorldFollower cria e tira um por Mon de Game.out.

const GROUP := "ow_companion"
const CREATURE_SPRITE := "res://gfx/creature_sprite.gd"

enum Act { NONE, COME, ORBIT, NAP, PLAY, SIT, ASK, REST, CHAT, FETCH }

## creature.gd do original.
const FOLLOW_LEAD := 1.0
const FOLLOW_SPACING := 0.9
const FOLLOW_STOP := 0.35
const FOLLOW_SPEED := 4.6
const FOLLOW_RUN := 7.6
const FOLLOW_LOST := 18.0
const ACT_COME_S := 8.0
const ACT_ORBIT_S := 6.0
const ACT_PLAY_S := 8.0
const ORBIT_RATE := 1.4
const BUMP_SPEED := 1.5
const BUMP_TIME := 0.1
const NIGHT_SPEED := 0.5
const BUBBLE_REPEAT := 0.9
const HEART_COL := Color(1.0, 0.55, 0.72)
## combatant.gd STATUS_TIME do original.
const STATUS_TIME := {"burn": 6.0, "poison": 6.0, "paralysis": 6.0, "sleep": 3.0}
const STATUS_WORD := {"burn": "queimadura", "poison": "veneno"}

var mon: Mon
var manager: Node  ## o WorldFollower
var look: Node3D
var act := Act.NONE
var ring_slot := 0
var ring_count := 1
var ring_radius := 1.8
var come_radius := 1.2
var night := false
var fetch_target := Vector3.INF
var sit_target := Vector3.INF
var chase_goal := Vector3.INF
var hopping := false
var leaving := false

var _act_left := 0.0
var _act_angle := INF
var _come_hop := false
var _bubble_t := 0.0
var _zzz_t := 0.0
var _bump_t := 0.0
var _bump_vel := Vector3.ZERO
var _status := ""
var _status_t := 0.0
var _status_tick := 1.0
var _species := ""


func _enter_tree() -> void:
	add_to_group(GROUP)
	add_to_group("ow_follower")  # o mato alto balança com ele (tall_grass.gd)


func _ready() -> void:
	if ResourceLoader.exists(CREATURE_SPRITE):
		look = load(CREATURE_SPRITE).new()
		look.species = mon.species
		_species = mon.species
		add_child(look)
		# Sai da bola: cresce de 5% a 115% e assenta (send_out do original).
		look.scale = Vector3.ONE * 0.05
		var tw := create_tween()
		tw.tween_property(look, "scale", Vector3.ONE * 1.15, 0.15)
		tw.tween_property(look, "scale", Vector3.ONE, 0.1)


## Índice na equipe (follow_slot do original).
func index() -> int:
	return Game.party.find(mon)


## Volta para a bola: encolhe e some.
func leave() -> void:
	if leaving:
		return
	leaving = true
	remove_from_group(GROUP)
	if look == null:
		queue_free()
		return
	var tw := create_tween()
	tw.tween_property(look, "scale", Vector3.ONE * 0.05, 0.2)
	tw.tween_callback(queue_free)


func _process(delta: float) -> void:
	if leaving or mon == null:
		return
	if look and _species != mon.species:
		# Evoluiu (pedra, troca): a mesma figura troca de espécie; a evolução no próprio sprite
		# (evolution_ui.begin_on) já segura este nó e deixa a espécie nova nele.
		_species = mon.species
		look.species = mon.species
	var p := Overworld.player_of(self)
	visible = p != null and not Game.is_busy()
	if p == null or Game.is_busy():
		return
	_tick_status(delta)
	if mon == null or leaving:
		return
	if hopping:
		return
	var want := _act_logic(delta, p) if act != Act.NONE else _follow_logic(p)
	if _bump_t > 0.0:
		global_position += _bump_vel * (_bump_t / BUMP_TIME) * delta
		_bump_t = maxf(0.0, _bump_t - delta)
	if want.is_finite():
		_step_to(want, delta)
	if look and look.get("state") != null:
		look.state = "sleep" if act == Act.NAP or act == Act.REST else ""


# --- Andar ---


func _player_still(p: OverworldPlayer) -> bool:
	return Vector2(p.velocity.x, p.velocity.z).length() < 0.1


func _face(at: Vector3) -> void:
	if look and look.has_method("face_point"):
		look.face_point(at)


## _follow_logic do original: alvo no rastro quando o jogador anda, lugar na roda quando ele para.
func _follow_logic(p: OverworldPlayer) -> Vector3:
	var still := _player_still(p)
	if p.can_act() and p.focus == self and still:
		_face(p.global_position)
		return Vector3.INF
	if global_position.distance_to(p.global_position) > FOLLOW_LOST:
		global_position = manager.trail_point(FOLLOW_LEAD + index() * FOLLOW_SPACING)
		if look and look.has_method("reset_motion"):
			look.reset_motion()
		return Vector3.INF
	if still:
		var t := _ring_target(p)
		if _flat(t - global_position) < FOLLOW_STOP:
			_face(p.global_position)
			return Vector3.INF
		return t
	return manager.trail_point(FOLLOW_LEAD + index() * FOLLOW_SPACING)


func _ring_target(p: OverworldPlayer) -> Vector3:
	var n := maxi(ring_count, 1)
	var ang := TAU * float(ring_slot) / float(n)
	var t: Vector3 = p.global_position + Vector3(cos(ang), 0.0, sin(ang)) * ring_radius
	var g := ground_y(t, p.global_position.y)
	if absf(g - p.global_position.y) > 0.6:
		return global_position
	t.y = g
	return t


## _step_to do original: rápido longe, devagar perto, metade da velocidade à noite.
func _step_to(target: Vector3, delta: float, speed := -1.0) -> void:
	var v := target - global_position
	var d := _flat(v)
	if d < FOLLOW_STOP:
		return
	if speed < 0.0:
		speed = clampf(d * 2.0, FOLLOW_SPEED, FOLLOW_RUN) * clampf(d / 0.8, 0.3, 1.0)
	speed *= NIGHT_SPEED if night else 1.0
	global_position = global_position.move_toward(target, speed * delta)


func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


## Chão em (x, z) por raio para baixo nas paredes/chão (camada 1); fallback se nada.
func ground_y(at: Vector3, fallback: float) -> float:
	var g := ground_hit(at, fallback)
	return g if is_finite(g) else fallback


## Altura do chão perto de ref_y em (x, z), INF se não há chão.
func ground_hit(at: Vector3, ref_y: float) -> float:
	if not is_inside_tree():
		return INF
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(
		Vector3(at.x, ref_y + 1.5, at.z), Vector3(at.x, ref_y - 3.0, at.z), Overworld.WALL_LAYER
	)
	var hit := space.intersect_ray(q)
	return float(hit.position.y) if not hit.is_empty() else INF


# --- Ações (creature.gd set_act / _act_logic do original) ---


func set_act(a: int) -> void:
	act = a
	_act_left = 0.0
	_act_angle = INF
	_come_hop = false
	_zzz_t = 0.0
	_bubble_t = 0.0
	sit_target = Vector3.INF
	match a:
		Act.COME:
			_act_left = ACT_COME_S
		Act.ORBIT:
			_act_left = ACT_ORBIT_S
		Act.PLAY:
			_act_left = ACT_PLAY_S


func clear_act() -> void:
	act = Act.NONE
	_act_left = 0.0
	_come_hop = false
	sit_target = Vector3.INF
	chase_goal = Vector3.INF
	fetch_target = Vector3.INF


func asking() -> bool:
	return act == Act.ASK


## Alvo da ação (INF = fica parado).
func _act_logic(delta: float, p: OverworldPlayer) -> Vector3:
	if _act_left > 0.0:
		_act_left -= delta
		if _act_left <= 0.0:
			clear_act()
			return Vector3.INF
	match act:
		Act.NAP, Act.REST, Act.CHAT:
			return Vector3.INF
		Act.ASK:
			_face(p.global_position)
			_bubble_t -= delta
			if _bubble_t <= 0.0:
				_bubble_t = BUBBLE_REPEAT
				popup("...", Color.WHITE, 0.6)
			return Vector3.INF
		Act.SIT:
			return sit_target
		Act.FETCH:
			return fetch_target
		Act.COME:
			var d := _flat(p.global_position - global_position)
			if d <= come_radius:
				_face(p.global_position)
				var mood := Mon.mood(mon.friend)
				if not _come_hop and (mood == "Happy" or mood == "Devoted"):
					_come_hop = true
					react_pet()
				return Vector3.INF
			_step_to(p.global_position, delta, FOLLOW_SPEED)
			return Vector3.INF
		Act.ORBIT:
			if not is_finite(_act_angle):
				var off: Vector3 = global_position - p.global_position
				_act_angle = atan2(off.z, off.x)
			_act_angle += ORBIT_RATE * delta
			var t: Vector3 = (
				p.global_position + Vector3(cos(_act_angle), 0.0, sin(_act_angle)) * ring_radius
			)
			var g := ground_y(t, p.global_position.y)
			if absf(g - p.global_position.y) > 0.6:
				return Vector3.INF
			return Vector3(t.x, g, t.z)
		Act.PLAY:
			if chase_goal.is_finite():
				return chase_goal
			var other := _nearest_companion()
			if other == null or _flat(other.global_position - global_position) < 0.6:
				return Vector3.INF
			_step_to(other.global_position, delta, FOLLOW_RUN * 0.45)
			return Vector3.INF
	return Vector3.INF


func _nearest_companion() -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group(GROUP):
		if n == self or not is_instance_valid(n):
			continue
		var d := global_position.distance_to(n.global_position)
		if d < best_d:
			best_d = d
			best = n
	return best


func bump(dir: Vector3) -> void:
	if _bump_t > 0.0 or act in [Act.NAP, Act.ASK, Act.SIT, Act.REST, Act.CHAT, Act.FETCH]:
		return
	dir.y = 0.0
	if dir.length() < 0.001:
		return
	_bump_vel = dir.normalized() * BUMP_SPEED
	_bump_t = BUMP_TIME


# --- Carinho e comida ---


func prompt() -> String:
	if act == Act.ASK:
		return "E: Rest with me"
	return "E: Pet · F: Feed"


## E no companheiro: descansa com ele se está pedindo, senão carinho.
func interact(_p: OverworldPlayer) -> void:
	if asking() and manager and manager.has_method("rest_with"):
		manager.rest_with(self)
		return
	var r: Dictionary = Game.pet(index())
	if r.ok:
		react_pet()
	elif String(r.text) != "":
		_toast(r.text)


## F no companheiro.
func feed() -> void:
	var r: Dictionary = Game.feed(index())
	if r.ok:
		react_feed()
	elif String(r.text) != "":
		_toast(r.text)


func _toast(text: String) -> void:
	var hud := Overworld.hud_of(self)
	if hud:
		hud.toast(text, 2.5)


## react_pet do original: pulinho de 0,25 m em 0,35 s e corações.
func react_pet() -> void:
	if hopping or look == null:
		return
	hopping = true
	var base: Vector3 = look.position
	var tw := create_tween()
	tw.tween_method(
		func(t: float): look.position = base + Vector3(0, sin(t * PI) * 0.25, 0), 0.0, 1.0, 0.35
	)
	await tw.finished
	if is_instance_valid(look):
		look.position = base
	hopping = false
	popup("♥", HEART_COL, 0.7)


## react_feed do original: dois quiques curtos em 0,4 s e um sopro.
func react_feed() -> void:
	if hopping or look == null:
		return
	hopping = true
	var base: Vector3 = look.position
	var tw := create_tween()
	tw.tween_method(
		func(t: float): look.position = base + Vector3(0, absf(sin(t * PI * 2.0)) * 0.07, 0),
		0.0,
		1.0,
		0.4
	)
	await tw.finished
	if is_instance_valid(look):
		look.position = base
	hopping = false
	popup("♪", Color(1, 1, 1), 0.5)


func head_height() -> float:
	return float(look.visible_height()) if look and look.has_method("visible_height") else 0.8


## Texto flutuante acima da cabeça que sobe e some.
func popup(text: String, col: Color, lift := 0.4) -> void:
	var l := Label3D.new()
	l.text = text
	l.modulate = col
	l.font_size = 64
	l.outline_size = 12
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = Vector3(0, head_height() + lift, 0)
	add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", l.position.y + 0.4, 0.9)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.9)
	tw.tween_callback(l.queue_free)


## Emote do original ("bang" = "!") acima da cabeça por `secs`.
func emote(id: String, secs: float) -> void:
	var tex := WorldFx.tex("vfx/emote/%s.png" % id)
	if tex == null:
		popup("!", Color(1.0, 0.85, 0.2), 0.35)
		return
	var s := Sprite3D.new()
	s.texture = tex
	s.pixel_size = 0.5 / maxf(1.0, float(tex.get_height()))
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.no_depth_test = true
	s.shaded = false
	s.position = Vector3(0, head_height() + 0.35, 0)
	add_child(s)
	get_tree().create_timer(secs).timeout.connect(s.queue_free)


# --- Status fora da bola (combatant.gd _tick_status do original) ---


func _tick_status(delta: float) -> void:
	var want := String(mon.status)
	if want != _status:  # sync_status_from_mon: status novo recomeça o relógio
		_status = want
		_status_t = float(STATUS_TIME.get(want, 4.0))
		_status_tick = 1.0
	if _status == "":
		return
	_status_t -= delta
	_status_tick -= delta
	if _status_tick <= 0.0:
		_status_tick = 1.0
		var dmg := 0
		match _status:
			"burn":
				dmg = maxi(1, int(mon.max_hp / 16.0))
			"poison":
				dmg = maxi(1, int(mon.max_hp / 12.0))
		if dmg > 0:
			mon.hp = maxi(mon.hp - dmg, 0)
			popup("-%d %s" % [dmg, STATUS_WORD.get(_status, _status)], Color(0.75, 0.4, 0.9), 0.3)
			if mon.hp == 0:
				mon.status = ""
				_toast("%s fainted!" % mon.display_name)
				Game.recall(index())
				return
	if _status_t <= 0.0:
		mon.status = ""
		_status = ""

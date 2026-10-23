class_name BattleProjectile
extends Node3D
## Projétil simples: anda vel*dt, opcionalmente teleguiado; acerta por distância < HIT_RADIUS.

const HIT_RADIUS := 0.75
const AIM_H := 0.4

var user: BattleFighter
var mv := {}
var vel := Vector3.ZERO
var homing := false
var turn := 4.0
var speed := 12.0
var range_m := 10.0
var travelled := 0.0
var miss_target: BattleFighter
var target: BattleFighter
var lob := 0.0
var lob_len := 1.0
var done := false
var _start := Vector3.ZERO
var _flat_dir := Vector3.ZERO


func setup(u: BattleFighter, m: Dictionary, dir: Vector3, is_homing: bool, miss: BattleFighter, aim: BattleFighter) -> void:
	user = u
	mv = m
	homing = is_homing
	miss_target = miss
	target = aim
	speed = float(m.get("speed", 12.0))
	range_m = float(m.get("range", 10.0))
	turn = float(m.get("turn", 4.0))
	if String(m.get("fx", "")) in ["rock", "lob"]:
		lob = float(m.get("lob_height", 1.2))
	if lob > 0.0:
		lob_len = range_m
		if is_instance_valid(aim) and aim != miss:
			lob_len = clampf(u.flat_to(aim).length() - 0.3, 1.0, range_m)
	position = u.position + Vector3(0, u.look_h * AIM_H, 0) + dir * 0.5
	_start = position
	_flat_dir = dir
	vel = dir * speed
	if not homing and lob == 0.0 and is_instance_valid(aim) and aim != miss:
		var to := _aim_point(aim) - position
		var flat := Vector2(to.x, to.z).length()
		if flat > 0.1:
			vel.y = to.y / flat * speed
	if u.arena and u.arena.get("vfx"):
		u.arena.vfx.projectile_look(self, m, dir)


func _aim_point(t: BattleFighter) -> Vector3:
	return t.position + Vector3(0, t.look_h * AIM_H, 0)


func step(dt: float, arena: Node) -> void:
	if done:
		return
	if not is_instance_valid(user):
		done = true
		return
	if homing and is_instance_valid(target) and target.active():
		var want := (_aim_point(target) - position).normalized() * speed
		vel = vel.lerp(want, clampf(turn * dt, 0.0, 1.0))
	var stepv := vel * dt
	travelled += stepv.length()
	position += stepv
	if lob > 0.0:
		var s := clampf(travelled / lob_len, 0.0, 1.0)
		position.y = _start.y + lob * 4.0 * s * (1.0 - s)
	for t in arena.targets_of(user):
		if t == miss_target:
			continue
		var close := position.distance_to(_aim_point(t)) < HIT_RADIUS
		if lob > 0.0:
			var p := _aim_point(t)
			close = travelled >= lob_len * 0.7 and Vector2(p.x - position.x, p.z - position.z).length() < HIT_RADIUS
		if close:
			var d := Vector3(vel.x, 0.0, vel.z)
			arena.moves.hit(user, t, mv, d.normalized() if d.length() > 0.01 else _flat_dir)
			done = true
			return
	if travelled >= (lob_len if lob > 0.0 else range_m) or position.y < -0.5:
		done = true

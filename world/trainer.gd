class_name WorldTrainer
extends WorldNpc
## Trainer from data/trainers.json: sees the player in a corridor ahead (sight m long, ±0.9 m wide,
## unblocked by walls), shouts "!", walks up to 1.2 m and battles. Can also be talked to.

const STOP_SHORT := 1.2
const WALK_SPEED := 4.0
const SIGHT_COOLDOWN := 2.0

@export var trainer_id := "test_youngster"
@export var show_sight := true

var sight := 5.0
var _def: Dictionary = {}
var _alert: Label3D
var _home := Vector3.ZERO
var _home_yaw := 0.0
var _busy := false
var _sight_cd := 0.0


func _ready() -> void:
	_def = Dex.trainer(trainer_id)
	if not _def.is_empty():
		npc_name = "%s %s" % [String(_def.get("class", "")).replace("_", " ").to_upper(), _def.get("name", "")]
		sight = float(_def.get("sight", sight))
	super._ready()
	_home = global_position
	_home_yaw = rotation.y
	_alert = make_alert(body_height + 0.9)
	add_child(_alert)
	if show_sight and sight > 0.0:
		_add_sight_strip()


func _add_sight_strip() -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(TrainerSight.HALF_WIDTH * 2.0, sight)
	var m := Overworld._mat(Color(1, 0.9, 0.3, 0.18))
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.material = m
	mi.mesh = pm
	mi.position = Vector3(0, 0.03, -sight * 0.5)
	add_child(mi)


func beaten() -> bool:
	return bool(Game.flags.get("trainer_%s" % trainer_id, false))


func prompt() -> String:
	return "E: Talk" if beaten() else "E: Challenge"


func _physics_process(delta: float) -> void:
	_sight_cd = maxf(_sight_cd - delta, 0.0)
	var p := Overworld.player_of(self)
	if p and can_see(p):
		_spot(p)


func can_see(p: OverworldPlayer) -> bool:
	if _def.is_empty() or _busy or beaten() or sight <= 0.0 or _sight_cd > 0.0:
		return false
	if not p.can_act() or Game.first_healthy() < 0:
		return false
	return TrainerSight.in_corridor(global_transform, p.global_position, sight) and _sight_clear(p)


func _sight_clear(p: OverworldPlayer) -> bool:
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP, p.global_position + Vector3.UP, Overworld.WALL_LAYER)
	q.exclude = [get_rid(), p.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _spot(p: OverworldPlayer) -> void:
	_busy = true
	p.locked = true
	p.velocity = Vector3.ZERO
	p.face_toward(global_position)
	face(p.global_position)
	_alert.visible = true
	await get_tree().create_timer(0.7).timeout
	_alert.visible = false
	var to := p.global_position - global_position
	to.y = 0.0
	if to.length() > STOP_SHORT:
		await _walk_to(global_position + to.normalized() * (to.length() - STOP_SHORT))
	face(p.global_position)
	await _battle_sequence(true)
	await _walk_to(_home)
	rotation.y = _home_yaw
	p.locked = false
	_busy = false
	_sight_cd = SIGHT_COOLDOWN


func _walk_to(pos: Vector3) -> void:
	var d := global_position.distance_to(pos)
	if d < 0.05:
		return
	face(pos)
	var tw := create_tween()
	tw.tween_property(self, "global_position", pos, d / WALK_SPEED)
	await tw.finished


func interact(p: OverworldPlayer) -> void:
	face(p.global_position)
	if _def.is_empty():
		await say(lines)
		return
	if beaten():
		await say(PackedStringArray(_def.get("after", ["..."])))
		return
	_busy = true
	await _battle_sequence(true)
	rotation.y = _home_yaw
	_busy = false
	_sight_cd = SIGHT_COOLDOWN


func _battle_sequence(intro: bool) -> void:
	if intro:
		await say(PackedStringArray(_def.get("intro", lines)))
	var ow := Overworld.of(self)
	var party := build_party(_def)
	if ow == null or party.is_empty():
		return
	var r := await ow.battle(party, {"kind": "trainer", "trainer_id": trainer_id, "can_run": false})
	if String(r.get("outcome", "")) == "win":
		Game.flags["trainer_%s" % trainer_id] = true
		await say(PackedStringArray(_def.get("defeat", ["..."])))


## party = [[species, level], ...]; "@flag" species are read from Game.flags (skipped if unset).
static func build_party(def: Dictionary) -> Array:
	var out: Array = []
	for e in def.get("party", []):
		var sp := String(e[0])
		if sp.begins_with("@"):
			sp = String(Game.flags.get(sp.substr(1), ""))
		if sp != "" and Dex.canon(sp) != "":
			out.append(Mon.create(sp, int(e[1])))
	return out

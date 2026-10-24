class_name WorldFollower
extends Node3D
## The lead Pokémon walking behind the player, like the original's companion (visual only: no
## collision, no gameplay). Drawn with gfx CreatureSprite; follows the player's trail with the
## original's speed law (creature.gd _follow_logic/_step_to), so it walks at a steady pace instead
## of stop-and-go (which flickered Walk/Idle and restarted the walk cycle every few frames).
## Stops a step behind when the player stops and turns to face them, hides during battles and when
## the party is empty. Teleports (doors, zone changes) snap it next to the player.

const GROUP := "ow_follower"
const CREATURE_SPRITE := "res://gfx/creature_sprite.gd"
const LEAD := 1.0  ## creature.gd FOLLOW_LEAD: aim at the trail point this many metres behind the player
const STOP := 0.35  ## FOLLOW_STOP: close enough to the aim point
const SPEED := 4.6  ## FOLLOW_SPEED / FOLLOW_RUN: m/s, clamp(d * 2, SPEED, RUN) * clamp(d / 0.8, 0.3, 1)
const RUN := 7.6
const TRAIL_STEP := 0.4  ## player.gd TRAIL_STEP / TRAIL_MAX
const TRAIL_MAX := 64
const SNAP := 6.0  ## farther than this (a teleport) = jump next to the player

var look: Node3D
var _species := ""
var _trail: Array[Vector3] = []  ## newest first, like player.gd _trail


func _enter_tree() -> void:
	add_to_group(GROUP)


func _process(delta: float) -> void:
	var p := Overworld.player_of(self)
	var lead := _lead()
	var want := String(lead.species) if lead else ""
	if want != _species:
		_species = want
		if look and want != "":
			look.species = want  # mesma figura (a evolução no próprio sprite segura este nó)
		elif look:
			look.queue_free()
			look = null
		elif want != "" and ResourceLoader.exists(CREATURE_SPRITE):
			look = load(CREATURE_SPRITE).new()
			look.species = want
			add_child(look)
	visible = p != null and look != null and not Game.is_busy()
	if p == null:
		return
	var at: Vector3 = p.visual_position()
	if _trail.is_empty() or at.distance_to(global_position) > SNAP:
		global_position = at - p.facing * LEAD
		_trail = [at, global_position]  # seeded so the aim point is where it lands
		if look and look.has_method("reset_motion"):
			look.reset_motion()
		return
	if Vector2(at.x - _trail[0].x, at.z - _trail[0].z).length() >= TRAIL_STEP:
		_trail.push_front(at)
		if _trail.size() > TRAIL_MAX:
			_trail.resize(TRAIL_MAX)
	var target := trail_point(LEAD)
	var v := Vector2(target.x - global_position.x, target.z - global_position.z)
	var d := v.length()
	if d < STOP:
		if look and Vector2(p.velocity.x, p.velocity.z).length() < 0.1:
			look.face_point(at)
		return
	var speed := clampf(d * 2.0, SPEED, RUN) * clampf(d / 0.8, 0.3, 1.0)
	global_position = global_position.move_toward(target, speed * delta)


## Point of the player's trail `metres` behind its newest point (player.gd trail_point).
func trail_point(metres: float) -> Vector3:
	var acc := 0.0
	for i in range(1, _trail.size()):
		acc += Vector2(_trail[i - 1].x - _trail[i].x, _trail[i - 1].z - _trail[i].z).length()
		if acc >= metres:
			return _trail[i]
	return _trail[-1]


func _lead() -> Mon:
	var i := int(Game.first_healthy())
	return Game.party[i] if i >= 0 and i < Game.party.size() else null

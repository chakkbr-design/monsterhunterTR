class_name WorldFollower
extends Node3D
## The lead Pokémon walking behind the player, like the original's companion (visual only: no
## collision, no gameplay). Drawn with gfx CreatureSprite; follows the player's trail a step
## behind, sits still when the player stops, hides during battles and when the party is empty.
## Teleports (doors, zone changes) snap it next to the player.

const GROUP := "ow_follower"
const CREATURE_SPRITE := "res://gfx/creature_sprite.gd"
const GAP := 1.3  ## metres of trail kept between the player and the mon
const SNAP := 6.0  ## farther than this (a teleport) = jump next to the player

var look: Node3D
var _species := ""
var _trail: Array[Vector3] = []


func _enter_tree() -> void:
	add_to_group(GROUP)


func _process(_delta: float) -> void:
	var p := Overworld.player_of(self)
	var lead := _lead()
	var want := String(lead.species) if lead else ""
	if want != _species:
		_species = want
		if look:
			look.queue_free()
			look = null
		if want != "" and ResourceLoader.exists(CREATURE_SPRITE):
			look = load(CREATURE_SPRITE).new()
			look.species = want
			add_child(look)
	visible = p != null and look != null and not Game.is_busy()
	if p == null:
		return
	var at: Vector3 = p.visual_position()
	if _trail.is_empty() or at.distance_to(global_position) > SNAP:
		_trail.clear()
		_trail.append(at)
		global_position = at - p.facing * GAP
		if look and look.has_method("reset_motion"):
			look.reset_motion()
		return
	if at.distance_to(_trail[-1]) > 0.15:
		_trail.append(at)
	# Walk the trail until GAP metres of it remain ahead.
	var left := 0.0
	var i := _trail.size() - 1
	while i > 0 and left < GAP:
		left += _trail[i].distance_to(_trail[i - 1])
		i -= 1
	if i > 0:
		_trail = _trail.slice(i)
	var target := _trail[0]
	var to_player := Vector2(at.x - global_position.x, at.z - global_position.z).length()
	if to_player > GAP + 0.1 and global_position.distance_to(target) > 0.05:
		global_position = global_position.move_toward(
			target, maxf(p.velocity.length(), 2.0) * get_process_delta_time() * 1.2
		)


func _lead() -> Mon:
	var i := int(Game.first_healthy())
	return Game.party[i] if i >= 0 and i < Game.party.size() else null

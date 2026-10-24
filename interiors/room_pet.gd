class_name RoomPet
extends WorldNpc
## A trainer-owned Pokémon in a room (original creature.gd with owner_name: calm, named
## "<owner>'s <species>", its own lines). Drawn with gfx CreatureSprite; never battles.

const CREATURE_SPRITE := "res://gfx/creature_sprite.gd"

var species := "Pidgey"
var look: Node3D


func _init() -> void:
	body_height = 0.6
	show_tag = false


func _build_body() -> void:
	if ResourceLoader.exists(CREATURE_SPRITE):
		look = load(CREATURE_SPRITE).new()
		look.species = species
		add_child(look)
		if look.has_method("face"):
			look.face(Vector3(0, 0, 1))
		return
	super._build_body()


func interact(p: OverworldPlayer) -> void:
	if look and look.has_method("face_point"):
		look.face_point(p.global_position)
	await say(lines)

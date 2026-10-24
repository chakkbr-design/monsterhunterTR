class_name PetMon
extends CharacterBody3D
## A trainer-owned Pokémon (the original creature.gd with trainer_owned / owner_name / talk_lines): it
## wanders calmly around its home, never fights, and talks with E as "<species> de <owner>".
## Built by MapBuilder from a map's "pets" entries; PetMon.from_entry(d) works for rooms too
## ({species, level, owner, name?, lines, pos, speed?, wander?}).

const CREATURE_SPRITE := "res://gfx/creature_sprite.gd"
const WANDER := 3.0  ## creature.gd: home +- 3 m

var species := "Pidgey"
var level := 5
var owner_name := ""
var npc_name := ""
var lines: PackedStringArray = []
var move_speed := 1.2  ## the scene's move_speed
var wander := WANDER
var home := Vector3.ZERO
var look: Node3D

var _wander_t := 0.0
var _wander_to := Vector3.ZERO
var _talking := false
var _phys_prev := Vector3.INF
var _phys_cur := Vector3.INF


static func from_entry(d: Dictionary) -> PetMon:
	var p := PetMon.new()
	p.species = String(d.get("species", "Pidgey"))
	p.level = int(d.get("level", 5))
	p.owner_name = String(d.get("owner", ""))
	var sp_name := String(Dex.species(p.species).get("name", p.species))
	p.npc_name = String(
		d.get("name", ("%s de %s" % [sp_name, p.owner_name]) if p.owner_name != "" else sp_name)
	)
	p.lines = MapBuilder.fill_names(d.get("lines", []))
	if p.lines.is_empty():  # creature.gd's generic lines
		var cry := sp_name.substr(0, 4)
		p.lines = PackedStringArray(
			[
				"%s: %s! %s!" % [sp_name, cry, cry.to_lower()],
				(
					"Parece acostumado com gente. Pertence a %s."
					% (p.owner_name if p.owner_name != "" else "alguém")
				)
			]
		)
	p.move_speed = float(d.get("speed", 1.2))
	p.wander = float(d.get("wander", WANDER))
	p.name = String(d.get("node", "Pet_%s" % p.species))
	return p


func _enter_tree() -> void:
	add_to_group(WorldNpc.GROUP)


func _ready() -> void:
	collision_layer = WorldNpc.LAYER
	collision_mask = Overworld.WALL_LAYER | SpawnZone.WATER_LAYER
	home = global_position
	_wander_to = home
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 0.9
	col.shape = cap
	col.position.y = 0.45
	add_child(col)
	if ResourceLoader.exists(CREATURE_SPRITE):
		look = load(CREATURE_SPRITE).new()
		look.name = "Look"
		look.species = species
		look.set("move_speed", move_speed)
		add_child(look)
		return
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.3
	cm.height = 0.9
	cm.material = Overworld._mat(Color(0.75, 0.6, 0.4))
	mi.mesh = cm
	mi.position.y = 0.45
	add_child(mi)


func _physics_process(delta: float) -> void:
	_phys_prev = global_position
	_phys_cur = global_position
	if _talking or Game.is_busy():
		velocity = Vector3.ZERO
		return
	_wander_t -= delta
	if _wander_t <= 0.0:
		_wander_t = randf_range(1.5, 3.5)
		_wander_to = home + Vector3(randf_range(-wander, wander), 0.0, randf_range(-wander, wander))
		if randf() < 0.35:
			_wander_to = global_position
	var v := _wander_to - global_position
	v.y = 0.0
	var dir := Vector3.ZERO if v.length() < 0.2 else v.normalized() * 0.6
	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed
	velocity.y = -0.5 if is_on_floor() else velocity.y - OverworldPlayer.GRAVITY * delta
	move_and_slide()
	_phys_cur = global_position
	if dir.length() > 0.05:
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 1.0 - exp(-8.0 * delta))


func _process(_delta: float) -> void:
	if look == null:
		return
	if not global_position.is_equal_approx(_phys_cur):
		_phys_prev = global_position
		_phys_cur = global_position
	look.position = to_local(
		_phys_prev.lerp(_phys_cur, Engine.get_physics_interpolation_fraction())
	)


func prompt() -> String:
	return "E: Falar"


func face(pos: Vector3) -> void:
	var to := pos - global_position
	if Vector2(to.x, to.z).length() > 0.01:
		rotation.y = atan2(-to.x, -to.z)


func interact(p: OverworldPlayer) -> void:
	_talking = true
	face(p.global_position)
	var hud := Overworld.hud_of(self)
	if hud:
		var g := get_node_or_null("/root/Game")
		var text := lines
		if g and g.has_method("fill_names"):
			text = PackedStringArray()
			for l in lines:
				text.append(g.fill_names(l))
		await hud.say(npc_name, text)
	_talking = false

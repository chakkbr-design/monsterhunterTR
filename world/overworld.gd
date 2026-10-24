class_name Overworld
extends Node3D
## Root of an overworld map: seeds the party, builds placeholder props and wraps the battle bridge.

const GROUP := "ow_root"
const WALL_LAYER := 1

@export var tree_color := Color(0.18, 0.45, 0.2)
@export var trunk_color := Color(0.4, 0.27, 0.15)

var _result: Dictionary = {}
var seed_party := true  ## give a test Bulbasaur when the party is empty (off for a new game)


static func of(n: Node) -> Overworld:
	return n.get_tree().get_first_node_in_group(GROUP) as Overworld


static func player_of(n: Node) -> OverworldPlayer:
	return n.get_tree().get_first_node_in_group(OverworldPlayer.GROUP) as OverworldPlayer


static func hud_of(n: Node) -> WorldHud:
	return n.get_tree().get_first_node_in_group(WorldHud.GROUP) as WorldHud


static func mon_from_entry(entry: Dictionary, rng: RandomNumberGenerator) -> Mon:
	return Mon.create(
		String(entry.get("species", "Bulbasaur")), WildTable.level_for(entry, rng), rng
	)


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	if seed_party and Game.party.is_empty():
		Game.add_mon(Mon.create("bulbasaur", 5))
	var trees := get_node_or_null("Trees")
	if trees:
		for m in trees.get_children():
			if m is Node3D:
				_build_tree(m)


## Overridden by maps that stream terrain: true while the ground under the player is still loading.
func blocks_player() -> bool:
	return false


## Runs one battle through Game and returns its result ({} if a battle could not start).
func battle(enemies: Array, opts: Dictionary) -> Dictionary:
	var p := player_of(self)
	if Game.is_busy() or Game.first_healthy() < 0 or enemies.is_empty() or p == null:
		return {}
	_result = {}
	if not opts.has("floor") and not _ground_under(p.global_position):
		opts = opts.duplicate()
		opts["floor"] = true  # the arena draws no floor of its own: give it one over empty space
	var money_before := int(Game.money)
	Game.battle_finished.connect(_capture, CONNECT_ONE_SHOT)
	Game.request_battle(enemies, opts, self, p.global_position)
	if _result.is_empty():
		_result = await Game.battle_finished
	var outcome := String(_result.get("outcome", "?"))
	var whiteout: bool = outcome == "lose" and not opts.get("scripted", false)
	var hud := hud_of(self)
	if hud and not whiteout:  # a real loss gets the original's white-out lines instead
		var lines := PackedStringArray(
			[
				(
					{
						"win": "Vitória!",
						"lose": "Você perdeu...",
						"run": "Fugiu.",
						"caught": "Capturado!"
					}
					. get(outcome, outcome)
				)
			]
		)
		# o prêmio já aparece no fim da batalha ("Você ganhou ₽X pela vitória!", battle_arena)
		for e in _result.get("evolved", []):
			lines.append("%s evoluiu para %s!" % e)
		hud.toast(" ".join(lines), 3.5)
	if whiteout:
		await _white_out(p, maxi(money_before - int(Game.money), 0))
	return _result


## Game already took the money (`loss`) and healed; send the player back to the heal spot.
func _white_out(p: OverworldPlayer, _loss := 0) -> void:
	for n in get_tree().get_nodes_in_group(WorldNpc.GROUP):
		if n is HealSpot:
			p.global_position = n.global_transform * Vector3(0, 0.2, -1.5)
			p.velocity = Vector3.ZERO
			return


## True when solid world geometry lies within 3 m below `at` (ground, terrace, interior floor).
func _ground_under(at: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(
		at + Vector3.UP, at + Vector3.DOWN * 3.0, WALL_LAYER
	)
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _capture(r: Dictionary) -> void:
	_result = r


func _build_tree(at: Node3D) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = WALL_LAYER
	at.add_child(body)
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.45
	shape.height = 3.0
	col.shape = shape
	col.position.y = 1.5
	body.add_child(col)
	var trunk := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.25
	tm.bottom_radius = 0.35
	tm.height = 1.6
	tm.material = _mat(trunk_color)
	trunk.mesh = tm
	trunk.position.y = 0.8
	body.add_child(trunk)
	var crown := MeshInstance3D.new()
	var cm := SphereMesh.new()
	cm.radius = 1.2
	cm.height = 2.2
	cm.material = _mat(tree_color)
	crown.mesh = cm
	crown.position.y = 2.4
	body.add_child(crown)


static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m

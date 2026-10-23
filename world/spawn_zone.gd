class_name SpawnZone
extends Node3D
## Keeps up to max_alive visible wild mons around this point; respawns 20–30 s after one leaves, away from the player.

@export var table_id := "route_1"
@export var radius := 8.0
@export var max_alive := 3
@export var respawn_min := 20.0
@export var respawn_max := 30.0
@export var min_player_dist := 14.0
@export var mode := "visible"  ## "swim" spawns only inside water rects (layer WATER_LAYER)

const WATER_LAYER := 16  ## same as MapBuilder.WATER_LAYER

var _alive: Array[WildMon] = []
var _pending: Array[float] = []
var _filled := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func _physics_process(delta: float) -> void:
	for i in range(_alive.size() - 1, -1, -1):  # in place: no array + lambda per tick
		if not is_instance_valid(_alive[i]):
			_alive.remove_at(i)
			_pending.append(_rng.randf_range(respawn_min, respawn_max))
	if not _filled:
		_filled = true
		for i in max_alive:
			_spawn(false)
		return
	if Game.is_busy():
		return
	for i in range(_pending.size() - 1, -1, -1):
		_pending[i] -= delta
		if _pending[i] > 0.0:
			continue
		if _alive.size() >= max_alive or _spawn(true):
			_pending.remove_at(i)
		else:
			_pending[i] = 5.0


func _spawn(away_from_player: bool) -> bool:
	var table := Dex.encounter_table(table_id)
	var e := WildTable.pick(table, mode, _rng)
	if e.is_empty():
		return false
	var pos := _free_point(away_from_player)
	if pos == Vector3.INF:
		return false
	var w := WildMon.spawn(Overworld.mon_from_entry(e, _rng), e, get_parent(), pos)
	if mode == "swim":
		w.roams = false  # bobs in place on the pond; engage it from the shore
	_alive.append(w)
	return true


func _free_point(away_from_player: bool) -> Vector3:
	var space := get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = 0.6
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	var swim := mode == "swim"
	q.collision_mask = Overworld.WALL_LAYER | OverworldPlayer.LAYER | WildMon.LAYER | WorldNpc.LAYER | (0 if swim else WATER_LAYER)
	var player := Overworld.player_of(self)
	for attempt in 24:
		var a := _rng.randf() * TAU
		var rad := sqrt(_rng.randf()) * radius
		var p := global_position + Vector3(cos(a) * rad, 0.0, sin(a) * rad)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 3.0, p + Vector3.DOWN * 3.0, Overworld.WALL_LAYER))
		if hit.is_empty() or absf(hit.position.y - global_position.y) > 0.6:
			continue
		p.y = hit.position.y
		if swim != _in_water(space, p):
			continue
		if away_from_player and player and p.distance_to(player.global_position) < min_player_dist:
			continue
		q.transform = Transform3D(Basis(), p + Vector3(0, 0.8, 0))
		if space.intersect_shape(q, 1).is_empty():
			return p
	return Vector3.INF


func _in_water(space: PhysicsDirectSpaceState3D, p: Vector3) -> bool:
	var pq := PhysicsPointQueryParameters3D.new()
	pq.position = p + Vector3(0, 0.5, 0)
	pq.collision_mask = WATER_LAYER
	return not space.intersect_point(pq, 1).is_empty()

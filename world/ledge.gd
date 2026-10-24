class_name WorldLedge
extends StaticBody3D
## One-way ledge on a plateau edge: walking off the top hops down in a short arc (the original
## ledge.gd + player.hop: 1.4 m out, 0.6 m high, 0.4 s, controls locked); from below it is a wall you
## cannot jump over. Origin = middle of the edge at the top height; local +Z points outwards (down side).

const HOP_ZONE := 0.9  ## depth inside the edge where pushing outwards starts the hop (original _zone)
const HOP_OUT := 1.4  ## LIP + 1.3 of the original
const HOP_TIME := 0.4
const HOP_HEIGHT := 0.6
const HOP_META := "ledge_hopping"

@export var length := 6.0
@export var drop := 0.9

var _shape: CollisionShape3D
var _below := true


func _ready() -> void:
	collision_layer = Overworld.WALL_LAYER
	collision_mask = 0
	_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(length, drop + MapBuilder.EDGE_WALL, 0.2)
	_shape.shape = box
	# Sits just inside the edge so a player who dropped down never overlaps it.
	_shape.position = Vector3(0, (MapBuilder.EDGE_WALL - drop) * 0.5, -0.1)
	add_child(_shape)
	TerrainBoulders.row(
		self, length, drop, hash(global_position) if is_inside_tree() else hash(position)
	)  # original's boulder face


func _physics_process(_d: float) -> void:
	var p := Overworld.player_of(self)
	if p == null or not p.is_on_floor():
		return  # keep the last state while airborne, so a jump from below can't switch it off
	var below := p.global_position.y < global_position.y - drop * 0.5
	if below != _below:
		_below = below
		_shape.set_deferred("disabled", not below)
	if not below:
		_try_hop(p)


## On top, inside the edge band, pushing outwards (dot > 0.6, like the original): hop down.
func _try_hop(p: OverworldPlayer) -> void:
	if p.has_meta(HOP_META):
		return
	var lp := to_local(p.global_position)
	if absf(lp.x) > length * 0.5 or lp.z < -HOP_ZONE or lp.z > 0.3:
		return
	var out := global_transform.basis.z
	out.y = 0.0
	out = out.normalized()
	var v := Vector2(p.velocity.x, p.velocity.z)
	if v.length() < 0.1 or Vector2(out.x, out.z).dot(v.normalized()) <= 0.6 or not p.can_act():
		return
	hop(p, out)


func hop(p: OverworldPlayer, out: Vector3) -> void:
	var to := p.global_position + out * HOP_OUT
	var tz := to_local(to).z
	if tz < 0.45:  # land clear of the wall that switches on below the edge
		to += out * (0.45 - tz)
	var low := global_position.y - drop
	var mb := get_parent()
	if mb and mb.has_method("height_at"):
		low = mb.height_at(to.x, to.z)
	to.y = low
	p.set_meta(HOP_META, true)
	var was_locked := p.locked
	p.locked = true
	p.velocity = Vector3.ZERO
	p.set_physics_process(false)
	_cue("ledge_hop")
	var from := p.global_position
	var tw := p.create_tween()
	tw.tween_method(
		func(t: float) -> void:
			p.global_position = from.lerp(to, t) + Vector3(0, sin(t * PI) * HOP_HEIGHT, 0),
		0.0,
		1.0,
		HOP_TIME
	)
	await tw.finished
	if not is_instance_valid(p):
		return
	p.velocity = Vector3.ZERO
	p.set_physics_process(true)
	p.locked = was_locked
	p.remove_meta(HOP_META)
	_cue("ledge_land")


func _cue(n: String) -> void:
	var au := get_node_or_null("/root/Audio")
	if au and au.has_method("has_sfx") and au.has_sfx(n):
		au.sfx(n)

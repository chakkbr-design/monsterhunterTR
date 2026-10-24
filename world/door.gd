class_name WorldDoor
extends WorldNpc
## Building door. If the map's target_spawn leads to a known interior (InteriorDefs.DOOR_TARGETS) and the
## map root can travel (RouteWorld), walking into it enters, like the original door.gd (Area3D
## body_entered); "E: Entrar" still works. Otherwise it shows its lines ("Fechado.") with E.

var target_scene := ""
var target_spawn := ""
var drawn := true  ## false when the building model already draws its door (MapBuilder)

var _walk_in: Area3D


func _ready() -> void:
	super._ready()
	# Walk-in trigger just outside the door face (local -Z = outwards). RouteWorld.travel ignores it
	# during a fade and right after arriving, so stepping out on the door spawn never re-enters.
	_walk_in = Area3D.new()
	_walk_in.name = "WalkIn"
	_walk_in.collision_layer = 0
	_walk_in.collision_mask = OverworldPlayer.LAYER
	_walk_in.monitorable = false
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.2, 1.6, 0.5)
	col.shape = bs
	col.position = Vector3(0, 0.8, -0.25)
	_walk_in.add_child(col)
	add_child(_walk_in)
	_walk_in.body_entered.connect(_on_walk_in)


func _on_walk_in(b: Node) -> void:
	if not b is OverworldPlayer or not (b as OverworldPlayer).can_act() or not leads_inside():
		return
	var t: Array = InteriorDefs.DOOR_TARGETS.get(target_spawn, [])
	var w := Overworld.of(self)
	if t.size() == 2 and w.has_method("travel"):
		w.travel({"interior": t[0], "spawn": t[1]}, self)


func _build_body() -> void:
	if not drawn:
		show_tag = false
		return
	var slab := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.1, 2.0, 0.12)
	bm.material = MapBuilder.mat(color)
	slab.mesh = bm
	slab.position = Vector3(0, 1.0, 0.02)
	add_child(slab)
	var mat := MeshInstance3D.new()
	var mm := BoxMesh.new()
	mm.size = Vector3(1.5, 0.04, 0.8)
	mm.material = MapBuilder.mat(Color(0.75, 0.3, 0.25))
	mat.mesh = mm
	mat.position = Vector3(0, 0.02, -0.45)
	add_child(mat)


func leads_inside() -> bool:
	var w := Overworld.of(self)
	return InteriorDefs.DOOR_TARGETS.has(target_spawn) and w != null and w.has_method("enter_door")


func prompt() -> String:
	return "E: Entrar" if leads_inside() else "E: Olhar"


func interact(_p: OverworldPlayer) -> void:
	if leads_inside():
		await Overworld.of(self).enter_door(target_spawn)
		return
	await say(lines)

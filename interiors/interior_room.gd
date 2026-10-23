class_name InteriorRoom
extends Node3D
## One indoor room built in code from an InteriorDefs.ROOMS entry: floor, walls (the front wall is
## low so the camera sees in), furniture, exit mat, stairs, named markers, spawns and NPCs.
## Look: the original's textured interior surfaces and Kenney furniture (InteriorLook); collision
## stays the furniture boxes of InteriorDefs.
## Placed by RouteWorld at InteriorDefs.origin_of(id); everything below is in local coordinates.

const C_TRIM := Color(0.42, 0.33, 0.25)
const C_VOID := Color(0.08, 0.07, 0.07)
const FRONT_VISIBLE_H := 0.6  ## original room.gd: the open front wall is drawn 0.6 m tall
## Wall height of the original room scenes (room.gd wall_height, default 2.8; scenes/interiors/*).
const WALL_H := 2.8
const WALL_HEIGHTS := {
	"oak_lab": 3.4,
	"pokemon_center_viridian": 3.0,
	"pokemon_center_mt_moon": 3.0,
	"pokemon_center_pewter": 3.75,
	"pewter_gym": 4.5,
	"pewter_museum": 4.25,
}
## Furniture a chair turns to face (the nearest one of these names).
const SEATS_FACE := ["Mesa", "Carteira", "Escrivaninha"]

var id := ""
var def: Dictionary = {}
var size := Vector2(10, 8)
var markers: Dictionary = {}  ## name -> Node3D
var spawns: Dictionary = {}  ## name -> [Vector3 local, Vector3 facing]
var npcs: Dictionary = {}  ## marker name -> WorldNpc
var triggers: Array = []  ## InteriorTrigger

var _body: StaticBody3D


func setup(room_id: String, d: Dictionary) -> InteriorRoom:
	id = room_id
	def = d
	name = "Interior_%s" % room_id
	position = InteriorDefs.origin_of(room_id)
	return self


func wall_height() -> float:
	return float(WALL_HEIGHTS.get(id, WALL_H))


func display_name() -> String:
	return String(def.get("name", id))


func outdoor_zone() -> String:
	return String(def.get("zone", ""))


## Global spawn position (falls back to "door", then the room centre).
func spawn_point(spawn: String) -> Vector3:
	var s: Array = spawns.get(spawn, spawns.get("door", [Vector3.ZERO, Vector3.FORWARD]))
	return to_global(s[0])


func spawn_facing(spawn: String) -> Vector3:
	var s: Array = spawns.get(spawn, spawns.get("door", [Vector3.ZERO, Vector3.FORWARD]))
	return s[1]


func has_spawn(spawn: String) -> bool:
	return spawns.has(spawn)


## True if a global position lies inside this room's footprint (with a small margin).
func contains(p: Vector3) -> bool:
	var l := p - global_position
	return (
		absf(l.x) <= size.x / 2.0 + 1.0
		and absf(l.z) <= size.y / 2.0 + 1.0
		and l.y > -5.0
		and l.y < 10.0
	)


func _ready() -> void:
	var s: Array = def.get("size", [10, 8])
	size = Vector2(float(s[0]), float(s[1]))
	_body = StaticBody3D.new()
	_body.name = "Solids"
	_body.collision_layer = Overworld.WALL_LAYER
	_body.collision_mask = 0
	add_child(_body)
	_build_shell()
	for f in def.get("furniture", []):
		var at := Vector3(float(f[1][0]), 0.0, float(f[1][1]))
		var sz := Vector3(float(f[2][0]), float(f[2][1]), float(f[2][2]))
		var solid: bool = f.size() < 5 or bool(f[4])
		if InteriorLook.furniture(
			self,
			String(f[0]),
			at + Vector3(0, sz.y / 2.0, 0),
			sz,
			Color(String(f[3])),
			_seat_target(String(f[0]), at)
		):
			if solid:
				_solid(at + Vector3(0, sz.y / 2.0, 0), sz)
		else:
			_box(at + Vector3(0, sz.y / 2.0, 0), sz, Color(String(f[3])), String(f[0]), solid)
	for k in def.get("spawns", {}):
		var e: Array = def.spawns[k]
		spawns[String(k)] = [
			Vector3(float(e[0]), 0.0, float(e[1])), InteriorDefs.dir_vec(String(e[2]))
		]
	for k in def.get("markers", {}):
		var e: Array = def.markers[k]
		var m := Node3D.new()
		m.name = "M_%s" % k
		m.position = Vector3(float(e[0]), float(e[3]) if e.size() > 3 else 0.0, float(e[1]))
		var dv := InteriorDefs.dir_vec(String(e[2]))
		m.rotation.y = atan2(-dv.x, -dv.z)  # local -Z looks along dv, like WorldNpc
		add_child(m)
		markers[String(k)] = m
	if def.has("exit"):
		_build_exit(def.exit)
	if def.has("exit_back"):
		_build_exit(def.exit_back, true)
	if def.has("stairs"):
		_build_stairs(def.stairs)
	for n in def.get("npcs", []):
		_spawn_npc(n)
	var light := OmniLight3D.new()
	light.position = Vector3(0, wall_height() - 0.2, 0)
	light.omni_range = maxf(size.x, size.y) * 1.1
	light.light_energy = 0.5
	light.light_color = Color(1.0, 0.95, 0.85)
	add_child(light)


func _build_shell() -> void:
	var w := size.x
	var d := size.y
	var h := wall_height()
	var void_floor := _mesh_box(Vector3(0, -0.12, 0), Vector3(w + 30, 0.1, d + 30), C_VOID, "Void")
	void_floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_box(
		Vector3(0, -0.1, 0),
		Vector3(w, 0.2, d),
		Color(String(def.get("floor", "#c4a77c"))),
		"Floor",
		true
	)
	_skin(
		"Floor",
		InteriorLook.surface(InteriorLook.floor_tex(id), Color(String(def.get("floor", "#c4a77c"))))
	)
	var wc := Color(String(def.get("wall", "#efe4cf")))
	var t := 0.3
	_box(Vector3(0, h / 2.0, -d / 2.0 - t / 2.0), Vector3(w + 2 * t, h, t), wc, "WallBack", true)
	_box(Vector3(-w / 2.0 - t / 2.0, h / 2.0, 0), Vector3(t, h, d), wc, "WallLeft", true)
	_box(Vector3(w / 2.0 + t / 2.0, h / 2.0, 0), Vector3(t, h, d), wc, "WallRight", true)
	# Front wall: low visible strip + full-height invisible collision, so the camera sees in.
	_mesh_box(
		Vector3(0, FRONT_VISIBLE_H / 2.0, d / 2.0 + t / 2.0),
		Vector3(w + 2 * t, FRONT_VISIBLE_H, t),
		wc.darkened(0.1),
		"WallFront"
	)
	var wall_mat := InteriorLook.surface(InteriorLook.wall_tex(id), wc)
	for wn in ["WallBack", "WallLeft", "WallRight", "WallFront"]:
		_skin(wn, wall_mat)
	_solid(Vector3(0, h / 2.0, d / 2.0 + t / 2.0), Vector3(w + 2 * t, h, t))
	for z in [-d / 2.0 + 0.03]:
		_mesh_box(Vector3(0, 0.08, z), Vector3(w, 0.16, 0.06), C_TRIM, "Trim")


## A chair faces the nearest table / desk of the room (Vector3.INF for anything else).
func _seat_target(fname: String, at: Vector3) -> Vector3:
	if fname != "Cadeira":
		return Vector3.INF
	var best := Vector3.INF
	for f in def.get("furniture", []):
		if not SEATS_FACE.has(String(f[0])):
			continue
		var c := Vector3(float(f[1][0]), 0.0, float(f[1][1]))
		if best == Vector3.INF or c.distance_to(at) < best.distance_to(at):
			best = c
	return best


## Exit mat on the front wall (spawn "door"), or on the back wall (back = true, spawn "back": gatehouses).
func _build_exit(e: Dictionary, back := false) -> void:
	var x := float(e.get("x", 0.0))
	var d := size.y
	var sg := -1.0 if back else 1.0
	if (
		InteriorLook.furniture(
			self,
			"Tapete",
			Vector3(x, 0.02, sg * (d / 2.0 - 0.5)),
			Vector3(1.6, 0.04, 0.8),
			Color(0.62, 0.22, 0.2)
		)
		== null
	):
		_mesh_box(
			Vector3(x, 0.01, sg * (d / 2.0 - 0.5)),
			Vector3(1.6, 0.03, 0.8),
			Color(0.62, 0.22, 0.2),
			"ExitMatBack" if back else "ExitMat"
		)
	if back:
		_mesh_box(
			Vector3(x, 1.1, -d / 2.0 + 0.02),
			Vector3(1.4, 2.2, 0.36),
			Color(0.25, 0.2, 0.16),
			"DoorwayBack"
		)
	else:
		_mesh_box(
			Vector3(x, FRONT_VISIBLE_H / 2.0 + 0.01, d / 2.0 + 0.02),
			Vector3(1.4, FRONT_VISIBLE_H + 0.02, 0.36),
			Color(0.25, 0.2, 0.16),
			"Doorway"
		)
	var tag := Label3D.new()
	tag.text = "SAÍDA"
	tag.font_size = 48
	tag.outline_size = 10
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.position = Vector3(x, 2.5 if back else 0.9, sg * d / 2.0)
	add_child(tag)
	spawns["back" if back else "door"] = [Vector3(x, 0.0, sg * (d / 2.0 - 1.8)), Vector3(0, 0, -sg)]
	var trig := InteriorTrigger.new()
	trig.name = "ExitBack" if back else "Exit"
	trig.target = e.get("to", {}).duplicate()
	trig.position = Vector3(x, 0.5, sg * (d / 2.0 - 0.45))
	trig.extent = Vector3(1.6, 1.0, 0.9)
	add_child(trig)
	triggers.append(trig)


func _build_stairs(s: Dictionary) -> void:
	var at := Vector3(float(s.at[0]), 0.0, float(s.at[1]))
	var going_up: bool = String(s.to[0]) == "player_room" or bool(s.get("up", false))
	for i in 4:
		var hgt := 0.12 * (i + 1) if going_up else 0.12 * (4 - i)
		_mesh_box(
			at + Vector3(-0.45 + i * 0.3, hgt / 2.0, 0),
			Vector3(0.3, hgt, 1.3),
			Color(0.55, 0.42, 0.3).lightened(0.05 * i),
			"Step%d" % i
		)
	var tag := Label3D.new()
	tag.text = "SOBE" if going_up else "DESCE"
	tag.font_size = 40
	tag.outline_size = 10
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.position = at + Vector3(0, 1.1, 0)
	add_child(tag)
	var trig := InteriorTrigger.new()
	trig.name = "Stairs"
	trig.target = {"interior": String(s.to[0]), "spawn": String(s.to[1])}
	trig.position = at + Vector3(0, 0.5, 0)
	trig.extent = Vector3(1.2, 1.0, 1.3)
	add_child(trig)
	triggers.append(trig)


func _spawn_npc(n: Dictionary) -> void:
	var m: Node3D = markers.get(String(n.get("marker", "")))
	if m == null:
		return
	var npc: WorldNpc
	match String(n.get("type", "npc")):
		"nurse":
			npc = CenterNurse.new()
		"mom":
			npc = CenterNurse.new()
			(npc as CenterNurse).is_mom = true
		"clerk":
			npc = MartClerk.new()
			(npc as MartClerk).shop_id = String(n.get("shop", "viridian"))
		"pc":
			npc = PcTerminal.new()
		"trainer":
			npc = WorldTrainer.new()
			(npc as WorldTrainer).trainer_id = String(n.get("trainer", ""))
		_:
			npc = WorldNpc.new()
	npc.name = "Npc_%s" % n.marker
	npc.npc_name = String(n.get("name", "Pessoa"))  # trainers replace it from trainers.json
	if n.has("lines"):
		var ls := PackedStringArray()
		for l in n.lines:
			ls.append(String(l))
		npc.lines = ls
	if n.has("color"):
		npc.color = Color(String(n.color))
	if n.has("sprite"):
		npc.sprite_sheet = String(n.sprite)  # original sheet ("npc_oak.png"); else guessed from role/name
	npc.set_meta("interior", id)
	npc.set_meta("role", String(n.get("marker", "")))
	npc.transform = m.transform
	add_child(npc)
	npcs[String(n.marker)] = npc


## Replaces a shell box's flat colour with an original surface material.
func _skin(node_name: String, m: Material) -> void:
	var mi := get_node_or_null(node_name) as MeshInstance3D
	if mi:
		mi.material_override = m


func _mesh_box(center: Vector3, sz: Vector3, c: Color, n := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	bm.material = MapBuilder.mat(c)
	mi.mesh = bm
	mi.position = center
	if n != "":
		mi.name = n
	add_child(mi)
	return mi


func _solid(center: Vector3, sz: Vector3) -> void:
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = sz
	col.shape = bs
	col.position = center
	_body.add_child(col)


func _box(center: Vector3, sz: Vector3, c: Color, n: String, solid: bool) -> void:
	_mesh_box(center, sz, c, n)
	if solid:
		_solid(center, sz)

class_name CaveBuilder
extends RefCounted
## Mt. Moon floors built inside their InteriorRoom (InteriorDefs: "cave": "1f" | "b1f" | "b2f") from the
## FRLG decomp data in data/maps/mt_moon_floors.json (48 x 40 ASCII grid, '#' = rock) and
## data/maps/mt_moon_events.json (warps, objects, bg events). One tile = TILE metres; row 0 is the back (-Z).
##
## decorate(room): rock walls (visible ROCK_H, solid ROCK_SOLID_H so nobody jumps over), ladders between
## floors (InteriorTrigger + spawns "warp_<i>"), the exit to Route 4 west (spawn "west_in" on 1F), the
## Route 4 east mouth on B1F (StoryTrigger "mt_moon_exit": the demo stops there), item balls, trainers
## (Team Rocket grunts rocket_1..4, Super Nerd Miguel and the fossils on B2F), wild spawn zones
## (encounter tables mt_moon_<floor>) and dim lights. Dark hooks: room meta "cave_dark", lights in
## group LIGHT_GROUP, set_flash(room, on).
## decorate_zone(builder): what MapBuilder doesn't build from a zone JSON: "doors" (Mt. Moon mouth on
## Route 3) and "statics" (StaticMon, one fight each). Both are called by the Story autoload when the
## nodes enter the tree (idempotent).

const TILE := 0.9
const FLOORS_PATH := "res://data/maps/mt_moon_floors.json"
const EVENTS_PATH := "res://data/maps/mt_moon_events.json"
const TRAINERS_PATH := "res://data/trainers.json"
const ROOM_PREFIX := "mt_moon_"
const DEPTH := {"1f": 0, "b1f": 1, "b2f": 2}
const ROCK_H := 1.5
const ROCK_SOLID_H := 4.0
const C_ROCK := Color(0.42, 0.36, 0.31)
const C_ROCK_DARK := Color(0.33, 0.28, 0.24)
const C_LADDER := Color(0.55, 0.4, 0.24)
const C_EXIT := Color(0.85, 0.8, 0.6)
const LIGHT_GROUP := "cave_light"
const DARK_ENERGY := 0.35
const FLASH_ENERGY := 1.2
const ROUTE4_WEST := {"zone": "route_3", "spawn": "r4_west_mouth"}
const EXIT_EVENT := "mt_moon_exit"
const FOSSIL_EVENT := "mt_moon_fossils"
const FOSSIL_FLAG := "FLAG_GOT_FOSSIL_FROM_MT_MOON"
const MIGUEL := "super_nerd_miguel"
## Map scripts that are not trainers or items.
const NPC_LINES := {
	"BaldingMan":
	[
		"Ouvi dizer que existem fósseis raros aqui no Monte da Lua.",
		"E também caem PEDRAS DA LUA do céu... Dizem que fazem certos Pokémon evoluir!"
	],
}
const SIGN_LINES := {
	"ZubatSign": ["Cuidado! O ZUBAT suga sangue!"],
}
## bg hidden items "<floor>:<x>,<y>" -> [uid of the original scene, hidden].
const BG_ITEMS := {
	"b1f:46,2": ["mmb1f_tiny1", false],
	"b1f:26,2": ["mmb1f_tiny2", false],
	"b1f:39,34": ["mmb1f_tiny3", false],
	"b1f:24,35": ["mmb1f_big1", false],
	"b1f:6,12": ["mmb1f_big2", false],
	"b1f:25,34": ["mmb1f_big3", false],
	"b2f:20,16": ["mmb2f_hidden_moon_stone", true],
	"b2f:39,11": ["mmb2f_hidden_ether", true],
}
const EXIT_SIGN := [
	"ROTA 4 - CERULEAN", "A estrada para Cerulean ainda está em obras.", "Continua..."
]

static var _floors: Dictionary = {}
static var _events: Dictionary = {}
static var _trainers: Dictionary = {}
static var _rows: Dictionary = {}

# --- data ----------------------------------------------------------------------------------------


static func _json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if d is Dictionary else {}


static func floors() -> Dictionary:
	if _floors.is_empty():
		_floors = _json(FLOORS_PATH)
	return _floors


static func events(floor_id: String) -> Dictionary:
	if _events.is_empty():
		_events = _json(EVENTS_PATH)
	return _events.get(floor_id, {})


## Cached: is_rock() calls this for every tile it checks while a floor is built.
static func rows(floor_id: String) -> PackedStringArray:
	if not _rows.has(floor_id):
		_rows[floor_id] = PackedStringArray(floors().get(floor_id, {}).get("rows", []))
	return _rows[floor_id]


static func room_id(floor_id: String) -> String:
	return ROOM_PREFIX + floor_id


## "MAP_MT_MOON_B1F" -> "b1f" ("" for other maps).
static func floor_of_map(map: String) -> String:
	return map.trim_prefix("MAP_MT_MOON_").to_lower() if map.begins_with("MAP_MT_MOON_") else ""


static func is_rock(floor_id: String, c: int, r: int) -> bool:
	var g := rows(floor_id)
	if r < 0 or r >= g.size() or c < 0 or c >= g[r].length():
		return true
	return g[r][c] == "#"


## Tile centre in room-local coordinates (origin = floor centre).
static func tile_local(floor_id: String, c: int, r: int) -> Vector3:
	var g := rows(floor_id)
	var w := (g[0].length() if not g.is_empty() else 48) * TILE
	var d := g.size() * TILE
	return Vector3((c + 0.5) * TILE - w / 2.0, 0.0, (r + 0.5) * TILE - d / 2.0)


## Rock rectangles [col, row, w, h]: horizontal runs of '#' merged downwards while they line up.
static func rock_rects(floor_id: String) -> Array:
	var out: Array = []
	var open: Dictionary = {}  ## "c0:c1" -> rect
	var g := rows(floor_id)
	for r in g.size():
		var runs: Dictionary = {}
		var c := 0
		var line: String = g[r]
		while c < line.length():
			if line[c] != "#":
				c += 1
				continue
			var c0 := c
			while c < line.length() and line[c] == "#":
				c += 1
			runs["%d:%d" % [c0, c]] = [c0, c]
		var next: Dictionary = {}
		for k in runs:
			if open.has(k):
				open[k][3] += 1
				next[k] = open[k]
			else:
				var rect := [runs[k][0], r, runs[k][1] - runs[k][0], 1]
				out.append(rect)
				next[k] = rect
		open = next
	return out


## Free floor tile next to (c, r) for an arrival (into the open corridor first), avoiding other warps.
static func arrival_tile(floor_id: String, c: int, r: int) -> Vector2i:
	var warps: Dictionary = {}
	for w in events(floor_id).get("warps", []):
		warps[Vector2i(int(w.x), int(w.y))] = true
	for dv in [
		open_dir(floor_id, c, r),
		Vector2i(0, 1),
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, -1),
		Vector2i(1, 1),
		Vector2i(-1, 1),
		Vector2i(1, -1),
		Vector2i(-1, -1)
	]:
		var t: Vector2i = Vector2i(c, r) + dv
		if not is_rock(floor_id, t.x, t.y) and not warps.has(t):
			return t
	return Vector2i(c, r)


## Direction (Vector2i) with the longest free run from (c, r): trainers look down their corridor.
static func open_dir(floor_id: String, c: int, r: int) -> Vector2i:
	var best := Vector2i(0, 1)
	var best_n := -1
	for dv in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
		var n := 0
		while n < 8 and not is_rock(floor_id, c + dv.x * (n + 1), r + dv.y * (n + 1)):
			n += 1
		if n > best_n:
			best_n = n
			best = dv
	return best


## "MtMoon_1F_EventScript_ItemRareCandy" -> "ItemRareCandy".
static func script_tail(script: String) -> String:
	return script.get_slice("_EventScript_", 1) if script.contains("_EventScript_") else script


## "RareCandy" -> "rare_candy", "TM09" -> "tm09".
static func snake(s: String) -> String:
	var out := ""
	for i in s.length():
		var ch := s[i]
		if (
			i > 0
			and ch == ch.to_upper()
			and ch != ch.to_lower()
			and s[i - 1] == s[i - 1].to_lower()
			and s[i - 1] != s[i - 1].to_upper()
		):
			out += "_"
		out += ch.to_lower()
	return out


## Trainer id for an object script: Grunt<N> -> rocket_<N>, otherwise the trainers.json id ending in _<name>.
static func trainer_for(script: String) -> String:
	var tail := script_tail(script)
	if tail.begins_with("Grunt"):
		return "rocket_" + tail.trim_prefix("Grunt")
	if _trainers.is_empty():
		_trainers = _json(TRAINERS_PATH)
	var suffix := "_" + tail.to_lower()
	for id in _trainers:
		if String(id).ends_with(suffix):
			return String(id)
	return ""


## Every object of a floor, classified: [{kind: trainer|item|npc|fossil, id, tile: Vector2i, script}].
static func objects(floor_id: String) -> Array:
	var out: Array = []
	for o in events(floor_id).get("objects", []):
		var script := String(o.get("script", ""))
		var tail := script_tail(script)
		var e := {"script": script, "tail": tail, "tile": Vector2i(int(o.x), int(o.y))}
		var gfx := String(o.get("graphics_id", ""))
		if gfx == "OBJ_EVENT_GFX_ITEM_BALL":
			e.kind = "item"
			e.id = snake(tail.trim_prefix("Item"))
		elif gfx == "OBJ_EVENT_GFX_FOSSIL":
			e.kind = "fossil"
			e.id = snake(tail)  # dome_fossil / helix_fossil
		elif (
			String(o.get("trainer_type", "")) != "TRAINER_TYPE_NONE"
			or trainer_for(script) == MIGUEL
		):
			e.kind = "trainer"
			e.id = trainer_for(script)
		else:
			e.kind = "npc"
			e.id = tail
		out.append(e)
	return out


## Where warp i of a floor leads: {interior, spawn} | {zone, spawn} | {event}.
static func warp_target(floor_id: String, i: int) -> Dictionary:
	var w: Dictionary = events(floor_id).get("warps", [])[i]
	var dest := floor_of_map(String(w.dest_map))
	if dest != "":
		return {"interior": room_id(dest), "spawn": "warp_%s" % w.dest_warp_id}
	if String(w.dest_warp_id) == "0":
		return ROUTE4_WEST.duplicate()
	return {"event": EXIT_EVENT}


# --- building ------------------------------------------------------------------------------------


static func decorate(room: InteriorRoom) -> void:
	if room == null or room.has_meta("cave_built"):
		return
	var fl := String(room.def.get("cave", ""))
	if rows(fl).is_empty():
		return
	room.set_meta("cave_built", true)
	room.set_meta("cave_dark", true)
	var body := StaticBody3D.new()
	body.name = "CaveRocks"
	body.collision_layer = Overworld.WALL_LAYER
	body.collision_mask = 0
	room.add_child(body)
	_rocks(room, body, fl)
	_warps(room, fl)
	_objects(room, fl)
	_bg(room, fl)
	_spawn_zones(room, fl)
	_lights(room)


static func _rocks(room: InteriorRoom, body: StaticBody3D, fl: String) -> void:
	var i := 0
	for rc in rock_rects(fl):
		var a := tile_local(fl, rc[0], rc[1])
		var b := tile_local(fl, rc[0] + rc[2] - 1, rc[1] + rc[3] - 1)
		var center := (a + b) / 2.0
		var size := Vector3(rc[2] * TILE, ROCK_H, rc[3] * TILE)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = size
		bm.material = MapBuilder.mat(C_ROCK if i % 3 else C_ROCK_DARK)
		mi.mesh = bm
		mi.position = center + Vector3(0, ROCK_H / 2.0, 0)
		mi.name = "Rock%d" % i
		room.add_child(mi)
		var col := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(size.x, ROCK_SOLID_H, size.z)
		col.shape = bs
		col.position = center + Vector3(0, ROCK_SOLID_H / 2.0, 0)
		body.add_child(col)
		i += 1


static func _warps(room: InteriorRoom, fl: String) -> void:
	var warps: Array = events(fl).get("warps", [])
	for i in warps.size():
		var w: Dictionary = warps[i]
		var c := int(w.x)
		var r := int(w.y)
		var at := tile_local(fl, c, r)
		var t := arrival_tile(fl, c, r)
		var sp := tile_local(fl, t.x, t.y)
		var away := sp - at
		room.spawns["warp_%d" % i] = [
			sp, away.normalized() if away.length() > 0.01 else Vector3(0, 0, 1)
		]
		var target := warp_target(fl, i)
		if target.has("interior"):
			var dest := String(target.interior).trim_prefix(ROOM_PREFIX)
			var up: bool = DEPTH.get(dest, 0) < DEPTH.get(fl, 0)
			_ladder(room, at, up, i)
			_light(room, at + Vector3(0, 2.0, 0), Color(0.8, 0.85, 1.0), 5.0)
			var trig := InteriorTrigger.new()
			trig.name = "Ladder%d" % i
			trig.target = target
			trig.extent = Vector3(TILE * 0.7, 1.0, TILE * 0.7)
			trig.position = at + Vector3(0, 0.5, 0)
			room.add_child(trig)
			room.triggers.append(trig)
		elif target.has("zone"):
			_mouth(room, at, "SAÍDA")
			room.spawns["west_in"] = room.spawns["warp_%d" % i]
			var trig := InteriorTrigger.new()
			trig.name = "ExitRoute4West"
			trig.target = target
			trig.extent = Vector3(TILE * 0.8, 1.0, TILE * 0.7)
			trig.position = at + Vector3(0, 0.5, 0)
			room.add_child(trig)
			room.triggers.append(trig)
		else:
			_mouth(room, at, "ROTA 4")
			var st := StoryTrigger.new()
			st.name = "ExitRoute4East"
			st.event = EXIT_EVENT
			st.size = Vector3(TILE * 0.8, 3.0, TILE * 0.8)
			st.position = at
			room.add_child(st)
			room.triggers.append(st)
			var sign_tile := arrival_tile(fl, t.x, t.y)
			_sign(
				room,
				"Route4Sign",
				"Placa",
				PackedStringArray(EXIT_SIGN),
				tile_local(fl, sign_tile.x, sign_tile.y)
			)
	# Arrival from outside (or a save without a spawn): the Route 4 mouth on 1F, else the first warp.
	if room.spawns.has("west_in"):
		room.spawns["door"] = room.spawns["west_in"]
	elif (
		room.spawns.has("warp_%d" % (warps.size() - 1))
		and String(warp_target(fl, warps.size() - 1).get("event", "")) != ""
	):
		room.spawns["door"] = room.spawns["warp_%d" % (warps.size() - 1)]
	elif room.spawns.has("warp_0"):
		room.spawns["door"] = room.spawns["warp_0"]


static func _ladder(room: InteriorRoom, at: Vector3, up: bool, i: int) -> void:
	var root := Node3D.new()
	root.name = "LadderMesh%d" % i
	root.position = at
	room.add_child(root)
	_box(
		root,
		Vector3(0, 0.02, 0),
		Vector3(TILE * 0.9, 0.04, TILE * 0.9),
		Color(0.15, 0.12, 0.1) if not up else C_ROCK_DARK
	)
	var h := 2.2 if up else 0.9
	for sx in [-0.3, 0.3]:
		_box(root, Vector3(sx, h / 2.0, 0), Vector3(0.07, h, 0.07), C_LADDER)
	for k in int(h / 0.3):
		_box(root, Vector3(0, 0.25 + k * 0.3, 0), Vector3(0.6, 0.05, 0.06), C_LADDER)
	var tag := Label3D.new()
	tag.text = "SOBE" if up else "DESCE"
	tag.font_size = 40
	tag.outline_size = 10
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.position = Vector3(0, h + 0.4, 0)
	root.add_child(tag)


static func _mouth(room: InteriorRoom, at: Vector3, label: String) -> void:
	var root := Node3D.new()
	root.name = "Mouth_%s" % label.replace(" ", "")
	root.position = at
	room.add_child(root)
	_box(root, Vector3(0, 0.015, 0), Vector3(TILE * 1.4, 0.03, TILE * 1.0), C_EXIT)
	var tag := Label3D.new()
	tag.text = label
	tag.font_size = 44
	tag.outline_size = 10
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.position = Vector3(0, 1.6, 0)
	root.add_child(tag)
	_light(room, at + Vector3(0, 2.2, 0), Color(1.0, 0.95, 0.8), 6.0)


static func _box(parent: Node3D, center: Vector3, size: Vector3, c: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = MapBuilder.mat(c)
	mi.mesh = bm
	mi.position = center
	parent.add_child(mi)


static func _objects(room: InteriorRoom, fl: String) -> void:
	for e in objects(fl):
		var at := tile_local(fl, e.tile.x, e.tile.y)
		match String(e.kind):
			"item":
				var uid := "mm_%s_%s" % [fl, e.id]
				if ItemBall.taken(uid) or Dex.item(String(e.id)).is_empty():
					continue
				var ib := ItemBall.new()
				ib.name = "Item_%s" % uid
				ib.npc_name = ""
				ib.uid = uid
				ib.item_id = String(e.id)
				ib.color = Color(0.9, 0.2, 0.2)
				ib.body_height = 0.5
				ib.position = at
				room.add_child(ib)
			"trainer":
				if String(e.id) == "":
					continue
				var tr := WorldTrainer.new()
				var role := String(e.id).get_slice("_", String(e.id).get_slice_count("_") - 1)
				if String(e.id).begins_with("rocket_"):
					role = String(e.id)
				tr.name = "Trainer_%s" % e.id
				tr.trainer_id = String(e.id)
				tr.color = (
					Color(0.25, 0.25, 0.3)
					if String(e.id).begins_with("rocket_")
					else Color(0.85, 0.55, 0.15)
				)
				tr.position = at
				var dv := open_dir(fl, e.tile.x, e.tile.y)
				tr.rotation.y = atan2(-float(dv.x), -float(dv.y))
				tr.set_meta("interior", room.id)
				tr.set_meta("role", role)
				room.add_child(tr)
				room.npcs[role] = tr
				_banner_name(tr)
				if String(e.id) == MIGUEL:
					var st := StoryTrigger.new()
					st.name = "FossilTrigger"
					st.event = FOSSIL_EVENT
					st.blocks = PackedStringArray([FOSSIL_FLAG])
					st.size = Vector3(TILE * 3.0, 3.0, TILE * 3.0)
					st.position = tile_local(fl, e.tile.x + 1, e.tile.y)
					room.add_child(st)
			"fossil":
				if bool(Game.flags.get(FOSSIL_FLAG, false)):
					continue
				var f := WorldNpc.new()
				var role := String(e.id)
				f.name = "Fossil_%s" % role
				f.npc_name = "Fóssil Domo" if role.begins_with("dome") else "Fóssil Hélice"
				f.lines = PackedStringArray(["Um fóssil de Pokémon pré-histórico!"])
				f.color = (
					Color(0.82, 0.74, 0.58) if role.begins_with("dome") else Color(0.7, 0.62, 0.5)
				)
				f.body_height = 0.5
				f.position = at
				f.set_meta("interior", room.id)
				f.set_meta("role", role)
				room.add_child(f)
				room.npcs[role] = f
			_:
				var n := WorldNpc.new()
				n.name = "Npc_%s" % e.id
				n.npc_name = "Senhor"
				n.lines = PackedStringArray(NPC_LINES.get(String(e.id), ["..."]))
				n.color = Color(0.75, 0.65, 0.5)
				n.position = at
				var dv := open_dir(fl, e.tile.x, e.tile.y)
				n.rotation.y = atan2(-float(dv.x), -float(dv.y))
				room.add_child(n)
				room.npcs[String(e.id)] = n


## trainers.json "display_name" ("Recruta da Equipe Rocket", "Supernerd Miguel") until WorldTrainer reads it.
static func _banner_name(tr: WorldTrainer) -> void:
	var dn := String(Dex.trainer(tr.trainer_id).get("display_name", ""))
	if dn == "" or tr.npc_name == dn:
		return
	tr.npc_name = dn
	var tag = tr.get("_tag")
	if tag is Label3D:
		tag.text = dn


static func _bg(room: InteriorRoom, fl: String) -> void:
	for b in events(fl).get("bg", []):
		if String(b.get("type", "")) == "hidden_item":
			_bg_item(room, fl, b)
			continue
		if String(b.get("type", "")) != "sign":
			continue
		var tail := script_tail(String(b.get("script", "")))
		_sign(
			room,
			tail,
			"Placa",
			PackedStringArray(SIGN_LINES.get(tail, ["..."])),
			tile_local(fl, int(b.x), int(b.y))
		)


## FRLG hidden items as the original's rooms place them (MtMoonB1F/B2F.tscn, item_pickup.gd): the B1F
## mushrooms lie in the open (ball_visible = false: no ball, but the prompt shows), the B2F Moon Stone
## and Ether are hidden (no prompt, E on the spot).
static func _bg_item(room: InteriorRoom, fl: String, b: Dictionary) -> void:
	var key := "%s:%d,%d" % [fl, int(b.x), int(b.y)]
	if not BG_ITEMS.has(key):
		return
	var d: Array = BG_ITEMS[key]
	var id := String(b.get("item", "")).trim_prefix("ITEM_").to_lower()
	if ItemBall.taken(d[0]) or Dex.item(id).is_empty():
		return
	var ib := ItemBall.new()
	ib.name = "Item_%s" % d[0]
	ib.npc_name = ""
	ib.uid = d[0]
	ib.item_id = id
	ib.hidden = d[1]
	ib.ball_visible = false
	ib.body_height = 0.5
	ib.position = tile_local(fl, int(b.x), int(b.y))
	room.add_child(ib)


static func _sign(
	room: InteriorRoom, nm: String, title: String, lines: PackedStringArray, at: Vector3
) -> void:
	var sp := SignPost.new()
	sp.name = nm
	sp.npc_name = title
	sp.lines = lines
	sp.color = Color(0.55, 0.4, 0.25)
	sp.body_height = 1.2
	sp.position = at
	room.add_child(sp)


## Spawn zones on a coarse grid, on open floor (>= 18 free tiles around) and away from warps.
static func spawn_points(fl: String) -> Array:
	var out: Array = []
	var g := rows(fl)
	if g.is_empty():
		return out
	var warps: Array = events(fl).get("warps", [])
	for r in range(4, g.size() - 2, 6):
		for c in range(4, g[0].length() - 2, 7):
			if is_rock(fl, c, r):
				continue
			var free := 0
			for dr in range(-2, 3):
				for dc in range(-2, 3):
					if not is_rock(fl, c + dc, r + dr):
						free += 1
			if free < 18:
				continue
			var near := false
			for w in warps:
				if Vector2(int(w.x) - c, int(w.y) - r).length() < 6.0:
					near = true
			if not near:
				out.append(Vector2i(c, r))
	return out


static func _spawn_zones(room: InteriorRoom, fl: String) -> void:
	var table := "mt_moon_" + fl
	if Dex.encounter_table(table).is_empty():
		return
	var i := 0
	for t in spawn_points(fl):
		var sz := SpawnZone.new()
		sz.name = "CaveSpawn%d" % i
		sz.table_id = table
		sz.radius = TILE * 2.5
		sz.max_alive = 1
		sz.position = tile_local(fl, t.x, t.y)
		room.add_child(sz)
		i += 1


static func _lights(room: InteriorRoom) -> void:
	for c in room.get_children():
		if c is OmniLight3D and not c.is_in_group(LIGHT_GROUP):
			c.light_energy = DARK_ENERGY
			c.light_color = Color(0.7, 0.75, 0.95)
			c.set_meta("cave_base", true)


static func _light(room: InteriorRoom, at: Vector3, c: Color, rng: float) -> void:
	var l := OmniLight3D.new()
	l.position = at
	l.omni_range = rng
	l.light_energy = 0.9
	l.light_color = c
	l.add_to_group(LIGHT_GROUP)
	room.add_child(l)


## Hook for FLASH (and the darkness itself): brightens or dims the cave's ambient light.
static func set_flash(room: InteriorRoom, on: bool) -> void:
	for c in room.get_children():
		if c is OmniLight3D and c.has_meta("cave_base"):
			c.light_energy = FLASH_ENERGY if on else DARK_ENERGY


# --- outdoor zones -------------------------------------------------------------------------------


## Mt. Moon mouth ("doors") and static mons ("statics") of a built zone.
static func decorate_zone(b: MapBuilder) -> void:
	if b == null or not is_instance_valid(b) or b.has_meta("extras_built"):
		return
	b.set_meta("extras_built", true)
	for d in b.data.get("doors", []):
		var door := WorldDoor.new()
		door.name = "Door_%s" % d.get("id", "cave")
		door.npc_name = String(d.get("title", "Monte da Lua"))
		door.lines = PackedStringArray(["A entrada do Monte da Lua."])
		door.color = Color(0.2, 0.17, 0.15)
		door.target_scene = String(d.get("target_scene", ""))
		door.target_spawn = String(d.get("target_spawn", ""))
		door.position = b._at(d)
		var f := clampi(int(d.get("facing", 1)), 0, 3)  ## 1 = faces west (-X), like the mountain face
		door.rotation.y = MapBuilder.facing_yaw(f)
		b.add_child(door)
		if d.has("spawn") and not b.arrivals.has(String(d.spawn)):
			b.arrivals[String(d.spawn)] = door.position + MapBuilder.FACING[f] * 1.8
	for s in b.data.get("statics", []):
		if StaticMon.done(String(s.get("uid", ""))):
			continue
		var sm := StaticMon.from_entry(s)
		sm.position = b._at(s)
		b.add_child(sm)

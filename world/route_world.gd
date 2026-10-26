class_name RouteWorld
extends Overworld
## Pallet Town .. Pewter City (Route 1, Viridian, Route 22, Route 2, Viridian Forest) built at runtime from data/maps/*.json (MapBuilder).
## Like the reference zone_streamer: zones within LOAD_RANGE of the player are built one at a time
## across frames and freed past LOAD_RANGE + UNLOAD_MARGIN. The start zone is built synchronously.
##
## Interiors (res://interiors/) are built once, in code, far from the outdoor map
## (InteriorDefs.BASE, x 10000+), so doors teleport with a fade instead of changing scenes.
## API (docs/CONTRATO.md, Rodada 3): go_to_interior, go_to_zone, location_changed, marker,
## plus save_extra() for the pause menu and set_interact_hook() for the story.

signal location_changed(kind: String, id: String)  ## kind: "zone" | "interior"

const ZONES := [
	"pallet_town",
	"route_1",
	"viridian_city",
	"route_22",
	"route_2",
	"viridian_forest",
	"route_2_north",
	"pewter_city",
	"route_3"
]
const LOAD_RANGE := 40.0
const UNLOAD_MARGIN := 20.0
## Interior camera of the original (every scenes/interiors/*_interiors.tscn CameraRig): 12 m, 30°,
## FOV 30°, far 120 m, DOF band 2.5 m. Outdoors the rig keeps its own (overworld.tscn) values.
const INDOOR_DISTANCE := 12.0
const INDOOR_PITCH := 30.0
const INDOOR_FOV := 30.0
const INDOOR_FAR := 120.0
const INDOOR_DOF := 2.5
const REARM_S := 0.5  ## walk-on triggers ignored this long after arriving

## Hand-placed content the maps don't carry. Trainers come from the map JSON (bug catchers in the forest,
## the rival on Route 22); Brock and Liam stand inside the gym (interiors/interior_defs.gd).
## Route 3 (with Route 4 west and the Mt. Moon mouth) opens east of Pewter; the Story blocks it until the badge.
const EXTRAS := {}

@export var start_zone := ""  ## empty = spawn_request / save / data/world.json "start"
@export var start_spawn := ""
@export var stream := true  ## false: build every zone up front (tests, screenshots)
@export var fade_time := 0.25  ## seconds per half of a door fade (0 = instant)

var zones: Dictionary = {}  ## id -> world.json zone entry
var builders: Dictionary = {}  ## id -> MapBuilder
var interiors: Dictionary = {}  ## id -> InteriorRoom
var active_zone := ""  ## last outdoor zone
var location_kind := "zone"
var location_id := ""
var traveling := false
var _loading := ""
var _check_t := 0.0
var _since_arrival := 0.0
var _fade: ColorRect
var _cam_out := Vector4(12.0, 32.0, 35.0, 6.0)  ## outdoor rig distance, pitch, fov, dof band


func _ready() -> void:
	var g := get_node_or_null("/root/Game")
	var req: Dictionary = g.spawn_request.duplicate() if g else {}
	if g:
		g.spawn_request = {}
	var sv: Dictionary = g.last_save if g else {}
	seed_party = req.is_empty() and sv.is_empty()
	super._ready()
	var w = JSON.parse_string(FileAccess.get_file_as_string("res://data/world.json"))
	var start: Dictionary = w.get("start", {}) if w is Dictionary else {}
	for z in w.get("zones", []) if w is Dictionary else []:
		if ZONES.has(String(z.id)):
			zones[String(z.id)] = z
	_build_interiors()
	_make_fade()
	_make_sky()
	var rig := _rig()
	if rig:
		_cam_out = Vector4(rig.distance, rig.pitch_deg, rig.fov, rig.dof_band)
	var sz := String(start.get("zone", "pallet_town"))
	var sp := String(start.get("spawn", "start"))
	var saved := _vec(sv.get("pos"))
	if start_zone != "":
		_start_zone(start_zone, start_spawn if start_spawn != "" else sp, Vector3.INF)
	elif interiors.has(String(req.get("interior", ""))):
		_start_interior(String(req.interior), String(req.get("spawn", "door")), Vector3.INF)
	elif zones.has(String(req.get("zone", ""))):
		_start_zone(String(req.zone), String(req.get("spawn", "")), Vector3.INF)
	elif interiors.has(String(sv.get("interior", ""))):
		_start_interior(String(sv.interior), String(sv.get("spawn", "door")), saved)
	elif saved != Vector3.INF and interior_at(saved) != "":
		_start_interior(interior_at(saved), "door", saved)
	elif saved != Vector3.INF and zone_at(saved) != "":
		_start_zone(zone_at(saved), sp, saved)
	else:
		_start_zone(sz, sp, Vector3.INF)
	# Continue / New game began a "scene" loading screen (title.gd): let go once the world is up.
	Loading.end_later("scene", 3)


func _start_zone(zone: String, spawn: String, exact: Vector3) -> void:
	for id in ZONES if not stream else [zone]:
		if not builders.has(id):
			_make_builder(id, 0).build()  # items_per_frame 0: finishes synchronously
	place_player(zone, spawn)
	if exact != Vector3.INF:
		_put_player(exact, Vector3.ZERO)
	_camera_mode(false)
	_set_location.call_deferred("zone", zone)


func _start_interior(id: String, spawn: String, exact: Vector3) -> void:
	if not stream:
		for z in ZONES:
			_make_builder(z, 0).build()
	active_zone = interiors[id].outdoor_zone()
	_place_in_interior(id, spawn)
	if exact != Vector3.INF and interiors[id].contains(exact):
		_put_player(exact, Vector3.ZERO)
	_set_location.call_deferred("interior", id)


# --- public API ----------------------------------------------------------------------------------


## Fades out, puts the player on `spawn` of the interior (unknown spawn -> "door") and fades in.
func go_to_interior(interior_id: String, spawn: String = "door") -> void:
	if not interiors.has(interior_id):
		push_warning("RouteWorld: unknown interior '%s'" % interior_id)
		return
	if traveling:
		return
	traveling = true
	await _fade_to(1.0)
	_place_in_interior(interior_id, spawn)
	_set_location("interior", interior_id)
	await _fade_to(0.0)
	traveling = false
	_autosave()


## Fades out, builds the zone if needed, puts the player on its spawn (door arrivals included) and fades in.
func go_to_zone(zone: String, spawn: String) -> void:
	if not zones.has(zone):
		push_warning("RouteWorld: unknown zone '%s'" % zone)
		return
	if traveling:
		return
	traveling = true
	await _fade_to(1.0)
	Loading.begin("zone")  # only shows when the zone is not already preloaded (0.2 s)
	await _ensure_zone(zone)
	place_player(zone, spawn)
	_camera_mode(false)
	_set_location("zone", zone)
	Loading.end("zone")
	await _fade_to(0.0)
	traveling = false
	_autosave()


## Game.autosave (docs/CONTRATO.md): it saves only when nothing modal is open.
func _autosave() -> void:
	var g := get_node_or_null("/root/Game")
	if g and g.has_method("autosave"):
		g.autosave(self)


## Original Game.heal_with_fade: fade out, heal the party, "Your team was healed!" (or msg) with the
## heal jingle, 1.8 s of black, fade in.
func heal_with_fade(msg := "") -> void:
	await _fade_to(1.0, 0.35)
	Game.heal_party()
	var hud := hud_of(self)
	if hud:
		hud.toast(msg if msg != "" else "Your team was healed!", 2.5)
	_sfx("heal")
	await _hold(1.8)
	await _fade_to(0.0, 0.35)


## Original Game.use_escape_rope: anywhere outside a battle, ends the Repel and takes the player to the
## last heal point (no healing). True if used; the caller removes the item.
func escape_rope() -> bool:
	var p := player_of(self)
	if p == null or Game.is_busy() or traveling:
		return false
	if "repel_steps" in Game:
		Game.repel_steps = 0
	var was := p.locked
	p.locked = true
	await _go_heal_point(0.35, 0.0)
	p.locked = was
	return true


## Named point in a room (ball_1..3, oak, rival, clerk, nurse, mom, pc...). null if missing.
func marker(interior_id: String, marker_name: String) -> Node3D:
	var r: InteriorRoom = interiors.get(interior_id)
	if r == null or not r.markers.has(marker_name):
		push_warning("RouteWorld: no marker '%s' in '%s'" % [marker_name, interior_id])
		return null
	return r.markers[marker_name]


func interior(interior_id: String) -> InteriorRoom:
	return interiors.get(interior_id)


## Story hook for an interior NPC (role = marker name: "clerk", "nurse", "mom", "pc"...). See InteriorHooks.
func set_interact_hook(interior_id: String, role: String, cb: Callable) -> void:
	InteriorHooks.set_hook(interior_id, role, cb)


## Map door -> its room (InteriorDefs.DOOR_TARGETS). Used by WorldDoor.
func enter_door(target_spawn: String) -> void:
	var t: Array = InteriorDefs.DOOR_TARGETS.get(target_spawn, [])
	if t.size() == 2:
		await go_to_interior(t[0], t[1])


## Walk-on triggers (exit mats, stairs) call this.
func travel(target: Dictionary, _from: Node = null) -> void:
	if traveling or _since_arrival < REARM_S:
		return
	if target.has("interior"):
		await go_to_interior(String(target.interior), String(target.get("spawn", "door")))
	elif target.has("zone"):
		await go_to_zone(String(target.zone), String(target.get("spawn", "")))


## What the pause menu should pass to Game.save_game(extra):
## {"pos": [x, y, z], "zone": id} outdoors, {"pos": [x, y, z], "interior": id} indoors.
## In grid zones the position is the centre of the player's tile (the target tile mid-step).
func save_extra() -> Dictionary:
	var p := player_of(self)
	var d := {}
	if p:
		var v := p.save_position()
		d["pos"] = [v.x, v.y, v.z]
	d["interior" if location_kind == "interior" else "zone"] = location_id
	return d


# --- interiors -----------------------------------------------------------------------------------


func _build_interiors() -> void:
	for id in InteriorDefs.ORDER:
		var r := InteriorRoom.new().setup(id, InteriorDefs.ROOMS[id])
		add_child(r)
		interiors[id] = r


func interior_at(pos: Vector3) -> String:
	for id in interiors:
		if interiors[id].contains(pos):
			return id
	return ""


func _place_in_interior(id: String, spawn: String) -> void:
	var r: InteriorRoom = interiors[id]
	var sp := spawn if r.has_spawn(spawn) else "door"
	_put_player(r.spawn_point(sp), r.spawn_facing(sp))
	_camera_mode(true)  # the HUD location pill names the room (location_changed)


## In grid zones the player lands on the centre of the nearest free tile (an old save inside what is
## now a wall, an arrival off the grid) and holds still a moment (OverworldPlayer.on_placed).
func _put_player(at: Vector3, facing: Vector3) -> void:
	var p := player_of(self)
	if p == null:
		return
	var g := grid_at(at)
	if g:
		var free := func(c: Vector2i) -> bool: return GridMotion.spot_free(g, c, p)
		p.global_position = g.center(GridMotion.nearest(TileGrid.cell_of(at), free, at))
	else:
		p.global_position = at + Vector3(0, 0.2, 0)
	p.velocity = Vector3.ZERO
	if facing != Vector3.ZERO:
		p.facing = facing
	p._grass.clear()
	p.on_placed()
	var rig := _rig()
	if rig:
		rig.global_position = p.global_position


func _ensure_zone(zone: String) -> void:
	var b: MapBuilder = builders.get(zone)
	if b == null:
		# Sliced over frames (the loading screen keeps animating); instant fades (tests) build at once.
		await _make_builder(zone, 60 if stream and fade_time > 0.0 else 0).build()
	elif not b.is_built:
		await b.built


func _set_location(kind: String, id: String) -> void:
	location_kind = kind
	location_id = id
	_apply_look(kind, id)
	if kind == "zone":
		active_zone = id
	_since_arrival = 0.0
	location_changed.emit(kind, id)


func _rig() -> OverworldCamera:
	return get_tree().get_first_node_in_group(OverworldCamera.GROUP) as OverworldCamera


func _camera_mode(indoor: bool) -> void:
	var rig := _rig()
	if rig == null:
		return
	rig.distance = INDOOR_DISTANCE if indoor else _cam_out.x
	rig.pitch_deg = INDOOR_PITCH if indoor else _cam_out.y
	rig.dof_band = INDOOR_DOF if indoor else _cam_out.w
	rig.set_lens(INDOOR_FOV if indoor else _cam_out.z, INDOOR_FAR if indoor else 220.0)
	if indoor:  # face the room's open (low) front wall
		rig._yaw = 0.0
		rig._yaw_target = 0.0


## Original look: post fx, wind, time of day, weather, ambience, the following partner (world/sky/),
## the F9 sky panel (world/debug/, hidden until F9) and the graphics tier (GfxQuality).
func _make_sky() -> void:
	for n: Node in [
		WorldPostFx.new(),
		WorldWind.new(),
		WorldTimeOfDay.new(),
		WorldWeather.new(),
		WorldAmbient.new(),
		WorldFollower.new(),
		SkyDebugPanel.new()
	]:
		n.name = {
			WorldPostFx: "PostFX",
			WorldWind: "Wind",
			WorldTimeOfDay: "TimeOfDay",
			WorldWeather: "Weather",
			WorldAmbient: "Ambient",
			WorldFollower: "Follower",
			SkyDebugPanel: "SkyPanel"
		}[n.get_script()]
		add_child(n)
	GfxQuality.apply_all(get_viewport())


## Environment, sun, fog, ground tints and camera of the zone (its map look) or of an interior.
func _apply_look(kind: String, id: String) -> void:
	var tod := get_node_or_null("TimeOfDay") as WorldTimeOfDay
	if tod == null:
		return
	var look: Dictionary = zones.get(id, {}).get("look", {}) if kind == "zone" else {}
	if kind == "interior" and interiors.has(id) and interiors[id].has_meta("cave_dark"):
		look = {"cave": true}  # CaveBuilder rooms: dark cave environment, not a house's
	if kind == "zone" and look.is_empty() and builders.has(id):
		look = builders[id].data.get("look", {})
	tod.apply_location(look, kind == "interior")


func _make_fade() -> void:
	var cl := CanvasLayer.new()
	cl.name = "Fade"
	cl.layer = 40
	add_child(cl)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(_fade)


## secs < 0: the door fade (fade_time). fade_time 0 (tests) makes every fade instant.
func _fade_to(a: float, secs := -1.0) -> void:
	if _fade == null:
		return
	if fade_time <= 0.0:
		_fade.color.a = a
		return
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", a, fade_time if secs < 0.0 else secs)
	await tw.finished


## Black-screen pause of the original's heal / white-out (skipped with instant fades).
func _hold(secs: float) -> void:
	if fade_time > 0.0:
		await get_tree().create_timer(secs).timeout


func _sfx(id: String) -> void:
	var au := get_node_or_null("/root/Audio")
	if au and au.has_method("has_sfx") and au.has_sfx(id):
		au.sfx(id)


## Lost a (non-scripted) battle, like the original Game.whiteout (game.gd:696-729): the four lines
## (out of Pokémon, the money lost, "... ... ... ...", home / Pokémon Center), the blackout jingle,
## a 0.6 s fade, the last place that healed the party (Mom by default), the heal jingle, 1 s, fade in.
func _white_out(p: OverworldPlayer, loss := 0) -> void:
	var was := p.locked
	p.locked = true
	var nm := Game.player_name
	var lines := PackedStringArray(["%s has no more Pokémon that can fight!" % nm])
	if loss > 0:
		lines.append("%s panicked and lost ₽%d..." % [nm, loss])
	lines.append("... ... ... ...")
	lines.append(
		(
			"%s scurried %s, protecting the exhausted Pokémon from further harm..."
			% [nm, "home" if _heal_id() == "player_house" else "to a Pokémon Center"]
		)
	)
	var hud := hud_of(self)
	if hud:
		await hud.say("", lines)
	_sfx("blackout")
	await _go_heal_point(0.6, 1.0, "heal")
	p.locked = was


## Interior of the last heal (Game.flags.last_heal, set by the nurse / Mom); player_house by default.
func _heal_id() -> String:
	var id := String(Game.flags.get("last_heal", "player_house"))
	return id if interiors.has(id) else "player_house"


## Fade out (secs), put the player at the heal point's counter, optional jingle, hold, fade in.
func _go_heal_point(secs: float, hold: float, jingle := "") -> void:
	while traveling:
		await get_tree().process_frame
	traveling = true
	await _fade_to(1.0, secs)
	var id := _heal_id()
	active_zone = interiors[id].outdoor_zone()  # like _start_interior: the room's own zone stays loaded
	_place_in_interior(id, "counter" if interiors[id].has_spawn("counter") else "door")
	_set_location("interior", id)
	if jingle != "":
		_sfx(jingle)
	await _hold(hold)
	await _fade_to(0.0, secs)
	traveling = false


# --- outdoor zones -------------------------------------------------------------------------------


static func _vec(a) -> Vector3:
	if a is Array and a.size() == 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return Vector3.INF


func zone_rect(id: String) -> Rect2:
	return MapBuilder.rect_of(zones[id].rect) if zones.has(id) else Rect2()


func zone_at(pos: Vector3) -> String:
	for id in zones:
		if zone_rect(id).has_point(Vector2(pos.x, pos.z)):
			return id
	return ""


## Tile grid of the outdoor zone under `pos` when humans walk on the grid there (docs/VOXEL.md §6):
## the builder's baked grid, or for a grid zone without one a probe of its colliders, made once
## the zone is built and its bodies are in the physics space, then cached on the builder. Null in
## interiors, in free zones and while the zone is unbuilt. OverworldPlayer.force_mode / force_zones
## override the map's "movement" (tests).
func grid_at(pos: Vector3) -> TileGrid:
	if OverworldPlayer.force_mode == "free" or interior_at(pos) != "":
		return null
	var id := zone_at(pos)
	var b: MapBuilder = builders.get(id)
	if b == null or not is_instance_valid(b) or not b.is_built:
		return null
	var mode := String(OverworldPlayer.force_zones.get(id, OverworldPlayer.force_mode))
	if mode == "":
		mode = "grid" if b.grid != null else String(b.data.get("movement", "free"))
	if mode != "grid":
		return null
	if b.grid == null:
		b.grid = GridMotion.probe_zone(b, zone_rect(id))
	return b.grid


## Puts the player on a spawn point of a built zone (falls back to the zone centre).
## Door arrivals ("*_door") face away from the door.
func place_player(zone: String, spawn: String) -> void:
	var p := player_of(self)
	var b: MapBuilder = builders.get(zone)
	if p == null or b == null:
		return
	var at: Vector3 = b.arrivals.get(spawn, Vector3.INF)
	if at == Vector3.INF:
		var c := zone_rect(zone).get_center()
		at = Vector3(c.x, b.height_at(c.x, c.y), c.y)
	_put_player(at, Vector3(0, 0, 1) if spawn.ends_with("_door") else Vector3.ZERO)
	active_zone = zone


func blocks_player() -> bool:
	if traveling:
		return true
	var p := player_of(self)
	if p == null:
		return false
	var id := zone_at(p.global_position)
	return id != "" and not (builders.has(id) and builders[id].is_built)


func _make_builder(id: String, per_frame: int) -> MapBuilder:
	# A map with a "voxel" entry is drawn by its baked voxel scenery (docs/VOXEL.md §5).
	var b: MapBuilder = (
		VoxelZone.new() if not MapBuilder.voxel_info(id).is_empty() else MapBuilder.new()
	)
	b.name = "Zone_%s" % id
	b.zone_id = id
	b.items_per_frame = per_frame
	b.extras = EXTRAS.get(id, {})
	var open: Array = []
	var voxel: Array = []
	for other in zones:
		if other != id:
			open.append(zones[other].rect)
			var ov: Dictionary = zones[other].get("voxel", {})
			if ov.has("extent"):
				voxel.append(ov.extent)
	b.open_rects = open
	b.voxel_rects = voxel
	add_child(b)
	builders[id] = b
	return b


func _process(delta: float) -> void:
	_since_arrival += delta
	_check_t -= delta
	if _check_t > 0.0:
		return
	_check_t = 0.25
	var p := player_of(self)
	if p == null:
		return
	if not traveling:
		_track_location(p)
	for id in builders:
		if builders[id].is_built:
			builders[id].refresh_flags()
	if not stream:
		return
	var here := zone_at(p.global_position)
	var pp := Vector2(p.global_position.x, p.global_position.z)
	# Inside a room: preload the outdoor zone behind its door while the player is still indoors.
	if here == "" and _loading == "" and active_zone != "" and not builders.has(active_zone):
		_stream_in(active_zone)
	for id in zones:
		var d := _rect_distance(zone_rect(id), pp)
		if not builders.has(id):
			if _loading == "" and d < LOAD_RANGE:
				_stream_in(id)
		elif (
			d > LOAD_RANGE + UNLOAD_MARGIN
			and id != here
			and id != _loading
			and id != active_zone  # the zone of the room the player is in: its door awaits the trip
			and not traveling
			and not Game.is_busy()
		):
			builders[id].queue_free()
			builders.erase(id)


## Follows the player when it walks between zones (or is moved by a script without go_to_*).
func _track_location(p: OverworldPlayer) -> void:
	var inside := interior_at(p.global_position)
	if inside != "":
		if location_kind != "interior" or location_id != inside:
			_camera_mode(true)
			_set_location("interior", inside)
		return
	var here := zone_at(p.global_position)
	if here == "" or (location_kind == "zone" and here == location_id):
		return
	_camera_mode(false)
	_set_location("zone", here)  # the HUD location pill shows the zone name


func _stream_in(id: String) -> void:
	_loading = id
	var b := _make_builder(id, 60)
	await b.build()
	_loading = ""


static func _rect_distance(r: Rect2, p: Vector2) -> float:
	var dx := maxf(maxf(r.position.x - p.x, 0.0), p.x - r.end.x)
	var dz := maxf(maxf(r.position.y - p.y, 0.0), p.y - r.end.y)
	return Vector2(dx, dz).length()

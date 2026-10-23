class_name RouteWorld
extends Overworld
## Pallet Town + Route 1 + Viridian City built at runtime from data/maps/*.json (MapBuilder).
## Like the reference zone_streamer: zones within LOAD_RANGE of the player are built one at a time
## across frames and freed past LOAD_RANGE + UNLOAD_MARGIN. The start zone is built synchronously.

const ZONES := ["pallet_town", "route_1", "viridian_city"]
const LOAD_RANGE := 40.0
const UNLOAD_MARGIN := 20.0

## Hand-placed content the maps don't carry (none of these zones has JSON trainers).
const EXTRAS := {
	"pallet_town": {
		"heal_spots": [{"name": "Mamãe", "pos": [-5.4, -5.3], "facing": 0,
				"lines": ["Descanse um pouco, querido.", "Seu time está curado!"]}],
	},
	"route_1": {
		"trainers": [{"id": "bug_catcher_rick", "node": "Trainer_Rick", "pos": [2.0, -53.0], "y": 0.9, "facing": 3}],
	},
	"viridian_city": {
		"heal_spots": [{"name": "Enfermeira", "pos": [10.8, -132.9], "facing": 0,
				"lines": ["Bem-vindo ao Centro Pokémon!", "Seu time está curado!"]}],
		"trainers": [{"id": "bug_catcher_sammy", "node": "Trainer_Sammy", "pos": [6.5, -178.0], "facing": 1}],
	},
}

@export var start_zone := ""  ## empty = data/world.json "start"
@export var start_spawn := ""
@export var stream := true  ## false: build every zone up front (tests, screenshots)

var zones: Dictionary = {}  ## id -> world.json zone entry
var builders: Dictionary = {}  ## id -> MapBuilder
var active_zone := ""
var _loading := ""
var _check_t := 0.0


func _ready() -> void:
	super._ready()
	var w = JSON.parse_string(FileAccess.get_file_as_string("res://data/world.json"))
	var start: Dictionary = w.get("start", {}) if w is Dictionary else {}
	for z in (w.get("zones", []) if w is Dictionary else []):
		if ZONES.has(String(z.id)):
			zones[String(z.id)] = z
	var sz := start_zone if start_zone != "" else String(start.get("zone", "pallet_town"))
	var sp := start_spawn if start_spawn != "" else String(start.get("spawn", "start"))
	var saved := _saved_pos()
	if saved != Vector3.INF and start_zone == "":
		sz = zone_at(saved)
	for id in (ZONES if not stream else [sz]):
		_make_builder(id, 0).build()  # items_per_frame 0: finishes synchronously
	place_player(sz, sp)
	if saved != Vector3.INF and start_zone == "":
		var p := player_of(self)
		p.global_position = saved + Vector3(0, 0.2, 0)
		var rig := get_tree().get_first_node_in_group(OverworldCamera.GROUP) as Node3D
		if rig:
			rig.global_position = p.global_position


## Posição do save carregado pelo Game, se cair dentro de uma das zonas.
func _saved_pos() -> Vector3:
	var g := get_node_or_null("/root/Game")
	var a: Array = g.last_save.get("pos", []) if g else []
	if a.size() != 3:
		return Vector3.INF
	var v := Vector3(a[0], a[1], a[2])
	return v if zone_at(v) != "" else Vector3.INF


func zone_rect(id: String) -> Rect2:
	return MapBuilder.rect_of(zones[id].rect) if zones.has(id) else Rect2()


func zone_at(pos: Vector3) -> String:
	for id in zones:
		if zone_rect(id).has_point(Vector2(pos.x, pos.z)):
			return id
	return ""


## Puts the player on a spawn point of a built zone (falls back to the zone centre).
func place_player(zone: String, spawn: String) -> void:
	var p := player_of(self)
	var b: MapBuilder = builders.get(zone)
	if p == null or b == null:
		return
	var at: Vector3 = b.arrivals.get(spawn, Vector3.INF)
	if at == Vector3.INF:
		var c := zone_rect(zone).get_center()
		at = Vector3(c.x, b.height_at(c.x, c.y), c.y)
	p.global_position = at + Vector3(0, 0.2, 0)
	p.velocity = Vector3.ZERO
	var rig := get_tree().get_first_node_in_group(OverworldCamera.GROUP) as Node3D
	if rig:
		rig.global_position = p.global_position
	active_zone = zone


func blocks_player() -> bool:
	var p := player_of(self)
	if p == null:
		return false
	var id := zone_at(p.global_position)
	return id != "" and not (builders.has(id) and builders[id].is_built)


func _make_builder(id: String, per_frame: int) -> MapBuilder:
	var b := MapBuilder.new()
	b.name = "Zone_%s" % id
	b.zone_id = id
	b.items_per_frame = per_frame
	b.extras = EXTRAS.get(id, {})
	var open: Array = []
	for other in zones:
		if other != id:
			open.append(zones[other].rect)
	b.open_rects = open
	add_child(b)
	builders[id] = b
	return b


func _process(delta: float) -> void:
	_check_t -= delta
	if _check_t > 0.0:
		return
	_check_t = 0.25
	var p := player_of(self)
	if p == null:
		return
	var here := zone_at(p.global_position)
	if here != "" and here != active_zone:
		active_zone = here
		var hud := hud_of(self)
		if hud:
			hud.toast(String(zones[here].get("name", here)), 2.5)
	if not stream:
		return
	var pp := Vector2(p.global_position.x, p.global_position.z)
	for id in zones:
		var d := _rect_distance(zone_rect(id), pp)
		if not builders.has(id):
			if _loading == "" and d < LOAD_RANGE:
				_stream_in(id)
		elif d > LOAD_RANGE + UNLOAD_MARGIN and id != here and id != _loading and not Game.is_busy():
			builders[id].queue_free()
			builders.erase(id)


func _stream_in(id: String) -> void:
	_loading = id
	var b := _make_builder(id, 60)
	await b.build()
	_loading = ""


static func _rect_distance(r: Rect2, p: Vector2) -> float:
	var dx := maxf(maxf(r.position.x - p.x, 0.0), p.x - r.end.x)
	var dz := maxf(maxf(r.position.y - p.y, 0.0), p.y - r.end.y)
	return Vector2(dx, dz).length()

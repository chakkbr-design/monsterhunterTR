class_name VoxelDesign
extends RefCounted
## A voxel zone's design file (data/voxel/<zone>.json, format in docs/VOXEL.md §9): two ASCII layers
## on the 1 m grid, one character per tile, rows north to south:
## - `ground`: what is painted in each square (lawn, cobbles, water...), see GROUND;
## - `things`: what stands on it (buildings, trees, hedges, lamps...), see THINGS (' ' = nothing);
## plus the building styles (by footprint letter), tree overrides, crop fields and the big objects
## (fountain, gate arch, waterfall). Signs and mailboxes come from the map JSON (data/maps/), which
## stays the source of the gameplay. `origin` is the world tile of the first character of the first
## row; `rect` is the gameplay rect in tiles [x0, z0, x1, z1] (inclusive), the rest is scenery.

## Ground legend: character -> kind.
const GROUND := {
	".": "lawn",
	",": "meadow",
	";": "forest_floor",
	"*": "flowers",
	"=": "cobble",
	"+": "slab",
	":": "dirt",
	"%": "soil",
	"_": "sand",
	"~": "shallow",
	"w": "deep",
	"k": "dock",
	"b": "bridge",
}
## Things legend: character -> kind. Upper-case letters not listed here are building footprints
## (see `buildings`); 'd' is the door tile of the building it touches.
const THINGS := {
	" ": "",
	"F": "forest",
	"T": "oak",
	"K": "cherry",
	"A": "apple",
	"Y": "birch",
	"I": "pine",
	"t": "sapling",
	"B": "bush",
	"h": "hedge",
	"f": "fence",
	"W": "wall",
	"g": "pillar",
	"l": "lamp",
	"n": "bench",
	"v": "planter",
	"e": "well",
	"u": "barrel",
	"x": "crate",
	"o": "rock",
	"y": "scarecrow",
	"c": "crop",
	"O": "fountain",
	"d": "door",
}
## Things that leave their tile walkable (none yet: everything that stands on a tile blocks it).
const WALKABLE_THINGS := [""]
const WATER_KINDS := ["shallow", "deep"]
const OVER_WATER := ["dock", "bridge"]  ## walkable decks with water carved under them
const TREE_KINDS := ["oak", "cherry", "apple", "birch", "pine", "sapling"]

var id := ""
var origin := Vector2i.ZERO  ## world tile of ground[0][0]
var size := Vector2i.ZERO  ## columns, rows
var rect := Rect2i()  ## gameplay tiles (position + size, inclusive start)
var ground := PackedStringArray()
var things := PackedStringArray()
var buildings: Array = []  ## {"char", "id", "style", ...} (data/voxel JSON)
var trees: Dictionary = {}  ## Vector2i -> {"species", "size"} overrides of tree tiles
var crops: Array = []  ## {"rect": [x0, z0, x1, z1], "crop": "wheat"}
var objects: Array = []  ## big objects: fountain, gate arch, waterfall...
var raw: Dictionary = {}
var text := ""  ## the JSON text (hashed into the bake)

var _bchars := {}  ## footprint letter -> building entry


static func path_of(zone_id: String) -> String:
	return "res://data/voxel/%s.json" % zone_id


static func load_design(zone_id: String) -> VoxelDesign:
	var p := path_of(zone_id)
	if not FileAccess.file_exists(p):
		return null
	var d := VoxelDesign.new()
	d.text = FileAccess.get_file_as_string(p)
	var j = JSON.parse_string(d.text)
	if not j is Dictionary:
		push_error("VoxelDesign: %s is not a JSON object" % p)
		return null
	d._parse(j)
	return d


func _parse(j: Dictionary) -> void:
	raw = j
	id = String(j.get("id", ""))
	var o: Array = j.get("origin", [0, 0])
	origin = Vector2i(int(o[0]), int(o[1]))
	ground = PackedStringArray(j.get("ground", []))
	things = PackedStringArray(j.get("things", []))
	size = Vector2i(ground[0].length() if ground.size() > 0 else 0, ground.size())
	var r: Array = j.get("rect", [origin.x, origin.y, origin.x + size.x - 1, origin.y + size.y - 1])
	rect = Rect2i(int(r[0]), int(r[1]), int(r[2]) - int(r[0]) + 1, int(r[3]) - int(r[1]) + 1)
	buildings = j.get("buildings", [])
	for b in buildings:
		_bchars[String(b.get("char", "?"))] = b
	for t in j.get("trees", []):
		var p: Array = t.get("pos", [0, 0])
		trees[Vector2i(int(p[0]), int(p[1]))] = t
	crops = j.get("crops", [])
	objects = j.get("objects", [])


## Tile range covered by the layers (world tiles).
func extent() -> Rect2i:
	return Rect2i(origin, size)


## Metre rect on xz of the whole design (tile edges on .5).
func extent_m() -> Rect2:
	return Rect2(Vector2(origin) - Vector2(0.5, 0.5), Vector2(size))


func has_tile(t: Vector2i) -> bool:
	return extent().has_point(t)


func in_rect(t: Vector2i) -> bool:
	return rect.has_point(t)


func gch(t: Vector2i) -> String:
	if not has_tile(t):
		return ""
	var row := ground[t.y - origin.y]
	var i := t.x - origin.x
	return row[i] if i < row.length() else ""


func tch(t: Vector2i) -> String:
	if not has_tile(t):
		return ""
	var row := things[t.y - origin.y] if t.y - origin.y < things.size() else ""
	var i := t.x - origin.x
	return row[i] if i < row.length() else " "


## Ground kind at a tile ("" outside the design).
func ground_kind(t: Vector2i) -> String:
	return String(GROUND.get(gch(t), ""))


## Thing kind at a tile: a THINGS kind, "building" for a footprint letter, "" for nothing.
func thing_kind(t: Vector2i) -> String:
	var c := tch(t)
	if THINGS.has(c):
		return String(THINGS[c])
	if _bchars.has(c):
		return "building"
	return ""


func is_water(t: Vector2i) -> bool:
	return ground_kind(t) in WATER_KINDS


## Water is carved under these tiles (water itself and the decks over it).
func is_wet(t: Vector2i) -> bool:
	var k := ground_kind(t)
	return k in WATER_KINDS or k in OVER_WATER


func building_of_char(c: String) -> Dictionary:
	return _bchars.get(c, {})


## Footprint letter -> tile rect (inclusive) of every tile carrying it, plus its door tiles.
func building_rect(c: String) -> Rect2i:
	var lo := Vector2i(1 << 20, 1 << 20)
	var hi := Vector2i(-(1 << 20), -(1 << 20))
	for z in size.y:
		var row := things[z] if z < things.size() else ""
		for x in row.length():
			if row[x] == c:
				lo = Vector2i(mini(lo.x, x), mini(lo.y, z))
				hi = Vector2i(maxi(hi.x, x), maxi(hi.y, z))
	if hi.x < lo.x:
		return Rect2i()
	return Rect2i(lo + origin, hi - lo + Vector2i.ONE)


## Door tiles ('d') on the border of a footprint.
func doors_of(r: Rect2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for z in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if tch(Vector2i(x, z)) == "d":
				out.append(Vector2i(x, z))
	return out


## All tiles whose things character is c.
func tiles_of(c: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for z in size.y:
		var row := things[z] if z < things.size() else ""
		for x in row.length():
			if row[x] == c:
				out.append(Vector2i(x, z) + origin)
	return out


## Problems that make the design unusable (empty = fine).
func validate() -> PackedStringArray:
	var errs := PackedStringArray()
	if size.x <= 0 or size.y <= 0:
		errs.append("empty ground layer")
		return errs
	for i in ground.size():
		if ground[i].length() != size.x:
			errs.append("ground row %d has %d columns (want %d)" % [i, ground[i].length(), size.x])
		for ch in ground[i]:
			if not GROUND.has(ch):
				errs.append("ground row %d: unknown '%s'" % [i, ch])
				break
	if things.size() != size.y:
		errs.append("things has %d rows (want %d)" % [things.size(), size.y])
	for i in things.size():
		if things[i].length() != size.x:
			errs.append("things row %d has %d columns (want %d)" % [i, things[i].length(), size.x])
		for ch in things[i]:
			if not THINGS.has(ch) and not _bchars.has(ch):
				errs.append("things row %d: unknown '%s'" % [i, ch])
				break
	for b in buildings:
		var r := building_rect(String(b.get("char", "?")))
		if r.size == Vector2i.ZERO:
			errs.append("building %s has no footprint" % b.get("id", "?"))
			continue
		for z in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var c := tch(Vector2i(x, z))
				if c != String(b.char) and c != "d":
					errs.append("building %s footprint is not a rectangle at %d,%d" % [b.id, x, z])
		var fp: Array = b.get("footprint", [])
		if fp.size() == 2 and (r.size.x != int(fp[0]) or r.size.y != int(fp[1])):
			errs.append("building %s is %s tiles, design says %s" % [b.id, r.size, fp])
	if not extent().encloses(rect):
		errs.append("rect %s is outside the layers %s" % [rect, extent()])
	return errs

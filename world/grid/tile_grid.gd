class_name TileGrid
extends RefCounted
## Tile map of a zone authored on the 1 m grid (docs/VOXEL.md, "Tiles"): tile (tx, tz) is the
## square centred on integer world coordinates, edges on .5. Static data only (what the voxel
## generator knows: walls, water, fences, trunks, ground height); people, pets, signs and doors
## block dynamically at runtime. Outside the grid counts as blocked.

const BLOCKED := 1
const WATER := 2
const GRASS := 4  ## tall grass (encounters)
const DOOR := 8  ## a building door: walking into it from the tile in front enters
const LEDGE := 16
const NO_NPC := 32  ## wandering NPCs never step here (doorsteps, gate)
const COVER := 64  ## roof / canopy above (no rain, darker)

var origin := Vector2i.ZERO  ## tile coordinates of local tile (0, 0)
var size := Vector2i.ONE
var flags := PackedByteArray()
var heights := PackedFloat32Array()  ## ground height (m) at each tile centre


func _init(o := Vector2i.ZERO, s := Vector2i.ONE) -> void:
	origin = o
	size = Vector2i(maxi(s.x, 1), maxi(s.y, 1))
	flags.resize(size.x * size.y)
	heights.resize(size.x * size.y)


static func cell_of(p: Vector3) -> Vector2i:
	return Vector2i(roundi(p.x), roundi(p.z))


func has(c: Vector2i) -> bool:
	var l := c - origin
	return l.x >= 0 and l.y >= 0 and l.x < size.x and l.y < size.y


func _i(c: Vector2i) -> int:
	var l := c - origin
	return l.x + l.y * size.x


func flag(c: Vector2i) -> int:
	return flags[_i(c)] if has(c) else BLOCKED


func has_flag(c: Vector2i, f: int) -> bool:
	return flag(c) & f != 0


func set_flag(c: Vector2i, f: int, on := true) -> void:
	if not has(c):
		return
	var i := _i(c)
	flags[i] = (flags[i] | f) if on else (flags[i] & ~f)


func blocked(c: Vector2i) -> bool:
	return flag(c) & (BLOCKED | WATER) != 0


func height(c: Vector2i) -> float:
	return heights[_i(c)] if has(c) else 0.0


func set_height(c: Vector2i, h: float) -> void:
	if has(c):
		heights[_i(c)] = h


func center(c: Vector2i) -> Vector3:
	return Vector3(c.x, height(c), c.y)


## Serialisation for baked zones: {"origin":[x,z],"size":[w,h],"flags":base64,"heights":base64}.
func to_dict() -> Dictionary:
	return {
		"origin": [origin.x, origin.y],
		"size": [size.x, size.y],
		"flags": Marshalls.raw_to_base64(flags),
		"heights": Marshalls.raw_to_base64(heights.to_byte_array()),
	}


static func from_dict(d: Dictionary) -> TileGrid:
	var o: Array = d.get("origin", [0, 0])
	var s: Array = d.get("size", [1, 1])
	var t := TileGrid.new(Vector2i(int(o[0]), int(o[1])), Vector2i(int(s[0]), int(s[1])))
	var f := Marshalls.base64_to_raw(str(d.get("flags", "")))
	if f.size() == t.flags.size():
		t.flags = f
	var h := Marshalls.base64_to_raw(str(d.get("heights", ""))).to_float32_array()
	if h.size() == t.heights.size():
		t.heights = h
	return t


## ASCII dump (tests / debugging): '#' blocked, '~' water, 'D' door, '"' grass, '.' free.
func dump() -> String:
	var lines := PackedStringArray()
	for z in size.y:
		var row := ""
		for x in size.x:
			var f := flags[x + z * size.x]
			if f & DOOR:
				row += "D"
			elif f & WATER:
				row += "~"
			elif f & BLOCKED:
				row += "#"
			elif f & GRASS:
				row += '"'
			else:
				row += "."
		lines.append(row)
	return "\n".join(lines)

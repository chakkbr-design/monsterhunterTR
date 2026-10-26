class_name WorldNpc
extends StaticBody3D
## NPC that talks through the HUD dialogue box. Faces its local -Z. Drawn with the original's 3x4
## walking sheet (CharSprite) from sprite_sheet, its story role or a guess from its name; a capsule
## only when no sheet resolves.

const GROUP := "ow_interact"
const LAYER := 8

@export var npc_name := "Villager"
@export var lines: PackedStringArray = ["Olá!"]
@export var color := Color(0.3, 0.45, 0.85)
@export var body_height := 1.6
@export var sprite_sheet := ""  ## file in original/assets/sprites ("npc_oak.png"); "" = guess
## Original npc.gd: wander_radius > 0 walks around home (new goal every 2-5 s, 40% stays, 1.4 m/s);
## lying lays the sprite down (the sleepy old man). < 0 = read the map entry (`wander`, `lying`).
@export var wander_radius := -1.0
@export var lying := false

const ROLE_SHEETS := {
	"oak": "npc_oak",
	"rival": "npc_rival",
	"mom": "npc_mom",
	"clerk": "npc_clerk",
	"nurse": "npc_nurse",
	"brock": "npc_brock",
	"daisy": "npc_daisy"
}
## Name keyword -> sheet (Portuguese and English names of the port and the original).
const NAME_SHEETS := [
	["enfermeira", "npc_nurse"],
	["nurse", "npc_nurse"],
	["joy", "npc_nurse"],
	["vendedor", "npc_clerk"],
	["clerk", "npc_clerk"],
	["balconista", "npc_clerk"],
	["mamãe", "npc_mom"],
	["mom", "npc_mom"],
	["carvalho", "npc_oak"],
	["oak", "npc_oak"],
	["margarida", "npc_daisy"],
	["daisy", "npc_daisy"],
	["brock", "npc_brock"],
	["cientista", "npc_scientist"],
	["scientist", "npc_scientist"],
	["assistente", "npc_scientist"],
	["aide", "npc_scientist"],
	["guia", "npc_gym_guide"],
	["guide", "npc_gym_guide"],
	["alpinista", "npc_hiker"],
	["hiker", "npc_hiker"],
	["campista", "npc_camper"],
	["camper", "npc_camper"],
	["bug", "npc_bug_catcher"],
	["inseto", "npc_bug_catcher"],
	["lass", "npc_lass"],
	["professora", "npc_cooltrainer_f"],
	["treinador", "npc_camper"],
	["garoto", "npc_youngster"],
	["youngster", "npc_youngster"],
	["menino", "npc_kid"],
	["kid", "npc_kid"],
	["menina", "npc_little_girl"],
	["girl", "npc_girl"],
	["moça", "npc_girl"],
	["senhora", "npc_woman"],
	["woman", "npc_woman"],
	["recepcionista", "npc_woman"],
	["senhor", "npc_oldman"],
	["old", "npc_oldman"],
	["velho", "npc_oldman"],
	["guarda", "npc_worker"],
	["guard", "npc_worker"],
	["worker", "npc_worker"],
	["nerd", "npc_super_nerd"],
	["rocket", "npc_rocket_m"],
	["rival", "npc_rival"],
	["blue", "npc_rival"]
]
const GENERIC_SHEETS := [
	"npc_balding_man", "npc_woman", "npc_kid", "npc_girl", "npc_oldman", "npc_youngster", "npc_lass"
]

var char_sprite: CharSprite
var show_tag := true  ## floating name (placeholders only; sprites and models hide it)

var _tag: Label3D
var talking := false
var _wander_home := Vector3.ZERO
var _goal := Vector3.ZERO
var _wander_t := 0.0
var _col: CollisionShape3D

const WANDER_SPEED := 1.4
const WANDER_MASK := 1 | 2 | 4 | 16  # walls, player, wild mons, water
## Grid zones (docs/VOXEL.md §6): wanderers stroll one tile at a time (1-3 tiles the same way), stop,
## look around; each tile is claimed on the TileGrid before stepping, never the player's tiles, never
## a NO_NPC tile (doorsteps), never past wander_radius tiles from home.
const GRID_WANDER_SPEED := 2.2

var _grid: TileGrid  ## grid under a wanderer (null = free wander)
var _grid_check := 0.0
var _grid_checks := 0
var _gcell := Vector2i.ZERO  ## tile stood on (the target while stepping)
var _gprev := Vector2i.ZERO
var _gdir := Vector2i.ZERO
var _gstep := false
var _gfrom := Vector3.ZERO
var _gto := Vector3.ZERO
var _gseg := 1.0
var _gk := 0.0
var _gfoot := 0
var _gchain := 0


static func make_alert(height: float) -> Label3D:
	var a := Label3D.new()
	a.text = "!"
	a.font_size = 96
	a.outline_size = 18
	a.modulate = Color(1.0, 0.85, 0.2)
	a.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	a.no_depth_test = true
	a.position.y = height
	a.visible = false
	var bang := WorldFx.tex("vfx/emote/bang.png")  # the original's "!" emote
	if bang:
		a.text = ""
		var s := Sprite3D.new()
		s.texture = bang
		s.pixel_size = 0.6 / maxf(1.0, float(bang.get_height()))
		s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		s.no_depth_test = true
		s.shaded = false
		a.add_child(s)
	return a


func _enter_tree() -> void:
	add_to_group(GROUP)


func _exit_tree() -> void:
	_set_grid(null)


func _ready() -> void:
	collision_layer = LAYER
	collision_mask = 0
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = body_height
	col.shape = cap
	col.position.y = body_height * 0.5
	add_child(col)
	_col = col
	_build_body()
	_read_map_entry()
	_wander_home = position
	_goal = position
	if lying:
		_lie_down()
	_tag = Label3D.new()
	_tag.text = npc_name
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.font_size = 72
	_tag.outline_size = 14
	_tag.position.y = body_height + 0.35
	_tag.visible = show_tag and char_sprite == null  # the original shows no floating names
	add_child(_tag)


## Map NPCs (MapBuilder): `wander` and `lying` of this NPC's entry in the zone JSON (matched by position).
func _read_map_entry() -> void:
	if wander_radius >= 0.0:
		return
	wander_radius = 0.0
	var mb := get_parent()
	if mb == null or not ("data" in mb) or not (mb.data is Dictionary):
		return
	for e in mb.data.get("npcs", []):
		var at: Array = e.get("pos", [])
		if (
			at.size() == 2
			and absf(float(at[0]) - position.x) < 0.05
			and absf(float(at[1]) - position.z) < 0.05
		):
			wander_radius = float(e.get("wander", 0.0))
			lying = lying or bool(e.get("lying", false))
			return


## Original _lie_down: sprite flat on its side (-90° in Z), darker, low wide box collider.
func _lie_down() -> void:
	if char_sprite:
		char_sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		char_sprite.rotation = Vector3(0.0, 0.0, -PI * 0.5)
		char_sprite.offset = Vector2.ZERO
		char_sprite.position = Vector3(0, 0.35, 0)
		char_sprite.modulate = Color(0.72, 0.72, 0.8)
	if _col:
		var box := BoxShape3D.new()
		box.size = Vector3(1.7, 0.6, 0.7)
		_col.shape = box
		_col.position = Vector3(0, 0.3, 0)
	if _tag:
		_tag.position.y = 0.9


func _physics_process(delta: float) -> void:
	if wander_radius <= 0.0:
		return
	_grid_check -= delta
	if _grid_check <= 0.0:  # every tick at first (the zone's grid may still be probing), then 1 s
		_grid_checks += 1
		_grid_check = 1.0 if _grid_checks > 10 else 0.0
		_set_grid(GridMotion.grid_for(self))
	if _grid or talking or Game.is_busy():
		return  # grid wander runs in _process: smooth tile steps at any frame rate
	_wander_t -= delta
	if _wander_t <= 0.0:
		_wander_t = randf_range(2.0, 5.0)
		_goal = (
			_wander_home
			+ Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * wander_radius
		)
		if randf() < 0.4:
			_goal = position
	var d := _goal - position
	d.y = 0.0
	if d.length() <= 0.15:
		return
	var step := d.normalized() * minf(WANDER_SPEED * delta, d.length())
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3(0, 0.6, 0)
	var ahead := PhysicsRayQueryParameters3D.create(
		from, from + d.normalized() * 0.55, WANDER_MASK, [get_rid()]
	)
	if not space.intersect_ray(ahead).is_empty():
		_goal = position  # blocked (wall, player, pond): wait for the next goal
		return
	var to := global_position + step
	var down := PhysicsRayQueryParameters3D.create(
		to + Vector3.UP, to + Vector3.DOWN * 2.0, Overworld.WALL_LAYER, [get_rid()]
	)
	var hit := space.intersect_ray(down)
	if hit.is_empty():
		_goal = position
		return
	_turn_to(to - global_position)
	global_position = Vector3(to.x, hit.position.y, to.z)


func _process(delta: float) -> void:
	if _grid:
		_grid_wander(delta)


## Starts / stops grid wander (claims the tile stood on, glides onto its centre when off it).
func _set_grid(g: TileGrid) -> void:
	if g == _grid:
		return
	if _grid:
		_grid.release(_gcell, self)
		_grid.release(_gprev, self)
		if char_sprite:
			char_sprite.step_col = -1
	_grid = g
	_gstep = false
	if g == null:
		return
	_gcell = TileGrid.cell_of(global_position)
	if not g.claim(_gcell, self):  # put onto a wanderer's tile: step aside to the nearest free one
		var p := Overworld.player_of(self)
		var mine := _gcell
		_gcell = GridMotion.nearest(
			mine,
			func(c: Vector2i) -> bool:
				return (
					GridMotion.spot_free(g, c, self)
					and not g.has_flag(c, TileGrid.NO_NPC)
					and not (p and c in p.occupied_cells())
				),
			global_position,
			3
		)
		g.claim(_gcell, self)
	_gprev = _gcell
	_wander_t = randf_range(0.5, 2.0)
	var c := g.center(_gcell)
	if Vector2(c.x - global_position.x, c.z - global_position.z).length() > 0.02:
		_begin_gstep(_gcell, c)


func _grid_wander(delta: float) -> void:
	if Game.is_busy():
		return
	if _gstep:
		_gk = minf(_gk + GRID_WANDER_SPEED * delta / _gseg, 1.0)
		global_position = _gfrom.lerp(_gto, _gk)
		if char_sprite:
			char_sprite.step_col = (1 + _gfoot) if _gk < 0.5 else 0
		if _gk < 1.0:
			return
		_gstep = false
		if _gprev != _gcell:
			_grid.release(_gprev, self)
		_gprev = _gcell
		if char_sprite:
			char_sprite.step_col = -1
		if _gchain > 0 and not talking:
			_gchain -= 1
			_try_gstep(_gdir)
		return
	if talking:
		return
	_wander_t -= delta
	if _wander_t > 0.0:
		return
	_wander_t = randf_range(1.0, 3.5)
	var r := randf()
	if r < 0.3:  # look around
		face(global_position + GridMotion.vec(GridMotion.DIRS[randi() % 4]))
		return
	if r < 0.45:
		return
	var d: Vector2i = GridMotion.DIRS[randi() % 4]
	if not _in_range(_gcell + d):
		d = GridMotion.card(GridMotion.vec(_home_cell() - _gcell))  # back toward home
	if d == Vector2i.ZERO:
		return
	_gchain = randi() % 3
	if not _try_gstep(d):
		face(global_position + GridMotion.vec(d))  # blocked: just look that way


func _try_gstep(d: Vector2i) -> bool:
	var to := _gcell + d
	if not _grid_can(to) or not _grid.claim(to, self):
		return false
	face(global_position + GridMotion.vec(d))
	_gdir = d
	_gprev = _gcell
	_gcell = to
	_begin_gstep(to, _grid.center(to))
	return true


func _begin_gstep(to: Vector2i, at: Vector3) -> void:
	_gcell = to
	_gfrom = global_position
	_gto = at
	_gseg = maxf(Vector2(at.x - _gfrom.x, at.z - _gfrom.z).length(), 0.001)
	_gk = 0.0
	_gstep = true
	_gfoot = 1 - _gfoot


func _home_cell() -> Vector2i:
	var p := get_parent() as Node3D
	return TileGrid.cell_of(p.to_global(_wander_home) if p else _wander_home)


func _in_range(c: Vector2i) -> bool:
	var h := _home_cell()
	var r := ceili(wander_radius)
	return absi(c.x - h.x) <= r and absi(c.y - h.y) <= r


## A tile this wanderer may step into: in range, free (GridMotion.spot_free), not a NO_NPC tile, no
## height jump, not a tile the player stands on or is stepping between.
func _grid_can(c: Vector2i) -> bool:
	if not _in_range(c) or _grid.has_flag(c, TileGrid.NO_NPC):
		return false
	if not GridMotion.spot_free(_grid, c, self):
		return false
	if absf(_grid.height(c) - _grid.height(_gcell)) > GridMotion.MAX_RISE:
		return false
	var p := Overworld.player_of(self)
	if p and c in p.occupied_cells():
		return false
	if (
		_grid.has_meta("probed")
		and GridMotion.live_blocked(get_world_3d().direct_space_state, _grid, c)
	):
		return false
	return true


## Sheet for this NPC: explicit sprite_sheet, story role ("oak", "mom"...), interior role, name keyword.
func resolve_sheet() -> Texture2D:
	var t := CharSprite.sheet(sprite_sheet)
	if t:
		return t
	var role := String(get("role")) if get("role") != null else String(get_meta("role", ""))
	if ROLE_SHEETS.has(role):
		return CharSprite.sheet(ROLE_SHEETS[role])
	var n := npc_name.to_lower()
	for e in NAME_SHEETS:
		if n.contains(e[0]):
			return CharSprite.sheet(e[1])
	return CharSprite.sheet(GENERIC_SHEETS[absi(hash(npc_name + name)) % GENERIC_SHEETS.size()])


## Original walking sheet when one resolves; returns false to let the caller draw a placeholder.
func _build_sprite() -> bool:
	var t := resolve_sheet()
	if t == null:
		return false
	char_sprite = CharSprite.make(t)
	add_child(char_sprite)
	return true


func _build_body() -> void:
	if _build_sprite():
		return
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.35
	cm.height = body_height
	cm.material = Overworld._mat(color)
	mi.mesh = cm
	mi.position.y = body_height * 0.5
	add_child(mi)
	var nose := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.5, 0.18, 0.3)
	bm.material = Overworld._mat(Color(0.1, 0.1, 0.1))
	nose.mesh = bm
	nose.position = Vector3(0, body_height - 0.15, -0.3)
	add_child(nose)


func prompt() -> String:
	return "E: Falar"


## Turns toward `pos` (onto the nearest of the four axes in grid zones).
func face(pos: Vector3) -> void:
	var to := pos - global_position
	if Vector2(to.x, to.z).length() > 0.01 and (_grid or GridMotion.grid_for(self)):
		to = GridMotion.vec(GridMotion.card(to))
	_turn_to(to)


func _turn_to(to: Vector3) -> void:
	if Vector2(to.x, to.z).length() > 0.01:
		rotation.y = atan2(-to.x, -to.z)


## Called by the player on interact; the player stays locked until this returns.
func interact(p: OverworldPlayer) -> void:
	talking = true
	face(p.global_position)
	if has_meta("role") and await InteriorHooks.run(self):
		talking = false
		return
	await say(lines)
	talking = false


func say(text: PackedStringArray) -> void:
	var hud := Overworld.hud_of(self)
	if hud == null:
		return
	var g := get_node_or_null("/root/Game")
	if g and g.has_method("fill_names"):
		var filled := PackedStringArray()
		for l in text:
			filled.append(g.fill_names(l))
		text = filled
	await hud.say(npc_name, text)

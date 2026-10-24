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
	if wander_radius <= 0.0 or talking or Game.is_busy():
		return
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
	face(to)
	global_position = Vector3(to.x, hit.position.y, to.z)


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


func face(pos: Vector3) -> void:
	var to := pos - global_position
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

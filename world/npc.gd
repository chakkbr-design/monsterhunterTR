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

const ROLE_SHEETS := {"oak": "npc_oak", "rival": "npc_rival", "mom": "npc_mom", "clerk": "npc_clerk",
		"nurse": "npc_nurse", "brock": "npc_brock", "daisy": "npc_daisy"}
## Name keyword -> sheet (Portuguese and English names of the port and the original).
const NAME_SHEETS := [["enfermeira", "npc_nurse"], ["nurse", "npc_nurse"], ["joy", "npc_nurse"],
		["vendedor", "npc_clerk"], ["clerk", "npc_clerk"], ["balconista", "npc_clerk"], ["mamãe", "npc_mom"], ["mom", "npc_mom"],
		["carvalho", "npc_oak"], ["oak", "npc_oak"], ["margarida", "npc_daisy"], ["daisy", "npc_daisy"],
		["brock", "npc_brock"], ["cientista", "npc_scientist"], ["scientist", "npc_scientist"], ["assistente", "npc_scientist"],
		["aide", "npc_scientist"], ["guia", "npc_gym_guide"], ["guide", "npc_gym_guide"], ["alpinista", "npc_hiker"],
		["hiker", "npc_hiker"], ["campista", "npc_camper"], ["camper", "npc_camper"], ["bug", "npc_bug_catcher"],
		["inseto", "npc_bug_catcher"], ["lass", "npc_lass"], ["professora", "npc_cooltrainer_f"], ["treinador", "npc_camper"],
		["garoto", "npc_youngster"], ["youngster", "npc_youngster"], ["menino", "npc_kid"], ["kid", "npc_kid"],
		["menina", "npc_little_girl"], ["girl", "npc_girl"], ["moça", "npc_girl"], ["senhora", "npc_woman"],
		["woman", "npc_woman"], ["recepcionista", "npc_woman"], ["senhor", "npc_oldman"], ["old", "npc_oldman"],
		["velho", "npc_oldman"], ["guarda", "npc_worker"], ["guard", "npc_worker"], ["worker", "npc_worker"],
		["nerd", "npc_super_nerd"], ["rocket", "npc_rocket_m"], ["rival", "npc_rival"], ["blue", "npc_rival"]]
const GENERIC_SHEETS := ["npc_balding_man", "npc_woman", "npc_kid", "npc_girl", "npc_oldman", "npc_youngster", "npc_lass"]

var char_sprite: CharSprite
var show_tag := true  ## floating name (placeholders only; sprites and models hide it)

var _tag: Label3D


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
	_build_body()
	_tag = Label3D.new()
	_tag.text = npc_name
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.font_size = 72
	_tag.outline_size = 14
	_tag.position.y = body_height + 0.35
	_tag.visible = show_tag and char_sprite == null  # the original shows no floating names
	add_child(_tag)


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
	face(p.global_position)
	if has_meta("role") and await InteriorHooks.run(self):
		return
	await say(lines)


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

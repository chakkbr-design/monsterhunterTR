class_name ItemBall
extends WorldNpc
## Item on the ground (map "items", Mt. Moon objects). Picking it up adds it to the bag and sets
## flags["item_<uid>"]. Drawn as the original's 3D Poké Ball (gfx/poke_ball_3d.gd) with its periodic glint.
## Like the original item_pickup.gd: hidden = no ball and no prompt, but E on the spot still picks it up;
## ball_visible = false (Mt. Moon mushrooms) = no ball but the prompt shows. Neither blocks the player.

const BALL_SCRIPT := "res://gfx/poke_ball_3d.gd"
## Items.POCKETS of the original, with the pause menu's names.
const POCKETS := {
	"medicine": "Remédios",
	"berries": "Frutas",
	"balls": "Pokébolas",
	"battle": "Itens de Batalha",
	"tm": "MTs",
	"key": "Itens-chave"
}

var uid := ""
var item_id := "potion"
var count := 1
var hidden := false
var ball_visible := true

var _ball: Node3D
var _t := 0.0
var _glow := -1.0  ## last glow energy sent (-1 = none yet)
var _taken := false


static func taken(item_uid: String) -> bool:
	return bool(Game.flags.get("item_%s" % item_uid, false))


static func pocket_name(id: String) -> String:
	var cat := String(Dex.item(id).get("category", "key"))
	return String(POCKETS.get(cat, "Itens"))


func _ready() -> void:
	super._ready()
	if hidden or not ball_visible:
		collision_layer = 0  # the original pickup is a bare Node3D: nothing to bump into


func _build_body() -> void:
	if hidden or not ball_visible:
		show_tag = false
		return
	if ResourceLoader.exists(BALL_SCRIPT):
		_ball = load(BALL_SCRIPT).create()
		_ball.rotation.y = randf() * TAU
		_ball.position.y = 0.17
		add_child(_ball)
		return
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.22
	sm.height = 0.44
	sm.material = MapBuilder.mat(color)
	mi.mesh = sm
	mi.position.y = 0.22
	add_child(mi)


func _process(delta: float) -> void:
	if _ball == null or not _ball.has_method("set_glow"):
		return
	_t += delta
	var e := maxf(0.0, sin(_t * 2.2) - 0.85) * 12.0
	if e > 0.0 or _glow > 0.0:  # dark ~90% of the time: don't dirty the material every frame
		_ball.set_glow(Color(1, 1, 0.85), e)
	_glow = e


func prompt() -> String:
	return "" if hidden or _taken else "E: Pegar"


## The original's two lines: "You found X!" / "You put the X in the <pocket> pocket."
func pickup_lines() -> PackedStringArray:
	var nm := String(Dex.item(item_id).get("name", item_id.replace("_", " ").to_upper()))
	var what := ("%d× %s" % [count, nm]) if count > 1 else nm
	return PackedStringArray(
		[
			"Você encontrou %s!" % what,
			"Você guardou %s no bolso de %s." % [nm, pocket_name(item_id)]
		]
	)


func interact(_p: OverworldPlayer) -> void:
	if _taken:
		return
	_taken = true
	remove_from_group(GROUP)
	Game.add_item(item_id, count)
	Game.flags["item_%s" % uid] = true
	var au := get_node_or_null("/root/Audio")
	if au and au.has_method("has_sfx") and au.has_sfx("item_get"):
		au.sfx("item_get")
	visible = false
	await say(pickup_lines())
	queue_free()

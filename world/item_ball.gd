class_name ItemBall
extends WorldNpc
## Visible item on the ground (map "items"). Picking it up adds it to the bag and sets flags["item_<uid>"].
## Drawn as the original's 3D Poké Ball (gfx/poke_ball_3d.gd) with its periodic glint.

const BALL_SCRIPT := "res://gfx/poke_ball_3d.gd"

var uid := ""
var item_id := "potion"
var count := 1

var _ball: Node3D
var _t := 0.0
var _glow := -1.0  ## last glow energy sent (-1 = none yet)


static func taken(item_uid: String) -> bool:
	return bool(Game.flags.get("item_%s" % item_uid, false))


func _build_body() -> void:
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
	return "E: Pegar"


func interact(_p: OverworldPlayer) -> void:
	Game.add_item(item_id, count)
	Game.flags["item_%s" % uid] = true
	var nm := String(Dex.item(item_id).get("name", item_id.replace("_", " ").to_upper()))
	visible = false
	await say(PackedStringArray(["Encontrou %s%s!" % [nm, "" if count == 1 else " x%d" % count]]))
	queue_free()

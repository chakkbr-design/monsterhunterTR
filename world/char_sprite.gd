class_name CharSprite
extends Sprite3D
## Billboard walking sheet of the original (player, NPCs, trainers): 3 columns x 4 rows
## (Down, Left, Right, Up), walk cycle [0, 1, 0, 2], pixel 0.05 m, feet at the node origin.
## Like the original player.tscn / npc.tscn Sprite3D it is a Y-axis billboard (billboard = 2): it stays
## upright and only turns toward the camera, so the 1.6 m figure keeps its height next to the buildings
## (a full billboard tilts back with the camera pitch and reads ~20% taller).
## The row is chosen in SCREEN space (facing rotated by the camera yaw), like npc.gd camera_row and
## player.gd SpriteLook.facing_row. By default it reads its parent: facing = parent's -Z (WorldNpc
## faces that way) and "moving" = the parent's position changed; the player drives it directly
## through `facing` / `moving` / `speed` (follow_parent = false).

const WALK_CYCLE := [0, 1, 0, 2]
const PIXEL := 0.05
const SHEETS := "res://original/assets/sprites/"
const FACING_MARGIN := 1.25

var follow_parent := true
var facing := Vector3(0, 0, 1)
var moving := false
var speed := 4.0

var _row := 0
var _anim := 0.0
var _last := Vector3.INF
var _walk_tex: Texture2D
var _run_tex: Texture2D


## Sheet by file name ("npc_oak.png" or "npc_oak") or full path; null when missing.
static func sheet(name: String) -> Texture2D:
	if name == "":
		return null
	var p := (
		name
		if name.begins_with("res://")
		else SHEETS + (name if name.ends_with(".png") else name + ".png")
	)
	return load(p) if ResourceLoader.exists(p) else null


static func make(tex: Texture2D, run_tex: Texture2D = null) -> CharSprite:
	var s := CharSprite.new()
	s.name = "Sprite"
	s._walk_tex = tex
	s._run_tex = run_tex
	s.texture = tex
	return s


func _ready() -> void:
	hframes = 3
	vframes = 4
	pixel_size = PIXEL
	offset = Vector2(0, 16)
	billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	shaded = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	frame = 0


func set_running(on: bool) -> void:
	var want := _run_tex if on and _run_tex else _walk_tex
	if want and texture != want:
		texture = want


static func _cam_yaw(tree: SceneTree) -> float:
	var rig = tree.get_first_node_in_group("ow_camera")
	return rig.yaw() if rig else 0.0


func _process(delta: float) -> void:
	var p := get_parent() as Node3D
	if follow_parent and p:
		var f := -p.global_transform.basis.z
		f.y = 0.0
		if f.length() > 0.01:
			facing = f.normalized()
		var at := p.global_position
		moving = (
			_last != Vector3.INF and Vector2(at.x - _last.x, at.z - _last.z).length() > 0.3 * delta
		)
		_last = at
	var d := Vector2(facing.x, facing.z).rotated(_cam_yaw(get_tree()))  # world -> screen (camera yaw)
	_row = facing_row(d, _row)
	if moving:
		_anim += delta * speed * 1.5
	else:
		_anim = 0.0
	var col: int = WALK_CYCLE[int(_anim) % 4] if moving else 0
	frame = _row * 3 + col


## Screen-space direction -> row (0 down/toward camera, 1 left, 2 right, 3 up), with hysteresis.
static func facing_row(dir: Vector2, prev_row: int) -> int:
	var dx := absf(dir.x)
	var dy := absf(dir.y)
	if dx < 0.001 and dy < 0.001:
		return prev_row
	if prev_row == 1 or prev_row == 2:
		if dy > dx * FACING_MARGIN:
			return 0 if dir.y > 0.0 else 3
		return 1 if dir.x < 0.0 else 2
	if dx > dy * FACING_MARGIN:
		return 1 if dir.x < 0.0 else 2
	return 0 if dir.y > 0.0 else 3

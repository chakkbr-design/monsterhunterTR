class_name TallGrass
extends Area3D
## Tall-grass patch: tells the player when it enters/leaves; the player rolls encounters while inside.
## Look ported from the original tall_grass.gd: an HGSS grass tile floor (egrass.png) plus a field of
## camera-facing tuft cards (egrass_u.png, hgss_foliage shader) that sway with the wind, part
## around walkers (player, wild mons, NPCs) and shudder before an ambush.

const TILE := 0.8
const TUFT_PER_TILE := 2
const TUFT_H := 0.65
const TINT := Color(0.85, 0.95, 0.78)
const TUFT_UV := Vector4(0.0, 0.25, 1.0, 0.875)
const GROUND_Y := 0.02
const PUSH_RADIUS := 1.15
const MAX_PUSHERS := 16
const PUSH_SCALE := 1.6
const SHAKE_SECS := 0.6

@export var table_id := "route_1"
@export var size := Vector3(8.0, 1.0, 6.0)
@export var density := 6.0  ## blades per square metre (placeholder look only)
@export var color := Color(0.25, 0.62, 0.22)

var _blades: Node3D
var _mat: ShaderMaterial
var _pushers := PackedVector4Array()
var _shake := 0.0
var _shake_t := 0.0


func table() -> Dictionary:
	return Dex.encounter_table(table_id)


func _ready() -> void:
	collision_layer = 0
	collision_mask = OverworldPlayer.LAYER
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	col.position.y = size.y * 0.5
	add_child(col)
	if WorldFx.tex("models/hgss/common/egrass_u.png") != null:
		_build_hgss()
	else:
		_build_blades()
	body_entered.connect(_on_body.bind("enter_grass"))
	body_exited.connect(_on_body.bind("exit_grass"))


func _on_body(b: Node3D, method: String) -> void:
	if b.has_method(method):
		b.call(method, self)


func _build_hgss() -> void:
	var m := StandardMaterial3D.new()
	m.albedo_texture = WorldFx.tex("models/hgss/common/egrass.png")
	m.albedo_color = TINT
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.uv1_scale = Vector3(size.x / TILE, size.z / TILE, 1.0)
	m.roughness = 1.0
	var pm := PlaneMesh.new()
	pm.size = Vector2(size.x, size.z)
	var floor_mi := MeshInstance3D.new()
	floor_mi.name = "GrassFloor"
	floor_mi.mesh = pm
	floor_mi.material_override = m
	floor_mi.position.y = GROUND_Y
	floor_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(floor_mi)
	var q := QuadMesh.new()
	q.size = Vector2(TILE, TUFT_H)
	q.center_offset = Vector3(0, TUFT_H / 2.0, 0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = q
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(name))
	var nx := maxi(1, ceili(size.x / TILE))
	var nz := maxi(1, ceili(size.z / TILE))
	mm.instance_count = (nx + 1) * (nz + 1) * TUFT_PER_TILE
	var n := 0
	for iz in nz + 1:
		for ix in nx + 1:
			for row in TUFT_PER_TILE:
				var p := Vector3(
					-size.x / 2.0 + (ix + rng.randf_range(-0.25, 0.25)) * TILE,
					GROUND_Y,
					(
						-size.z / 2.0
						+ (iz + (0.5 if row == 1 else 0.0) + rng.randf_range(-0.25, 0.25)) * TILE
					)
				)
				p.x = clampf(p.x, -size.x / 2.0, size.x / 2.0)
				p.z = clampf(p.z, -size.z / 2.0, size.z / 2.0)
				var s := rng.randf_range(0.9, 1.15)
				mm.set_instance_transform(n, Transform3D(Basis().scaled(Vector3(s, s, s)), p))
				n += 1
	_pushers.resize(MAX_PUSHERS)
	_mat = WorldFx.shader_mat(
		"hgss_foliage",
		{
			"albedo_tex": WorldFx.tex("models/hgss/common/egrass_u.png"),
			"uv_rect": TUFT_UV,
			"tint": TINT,
			"sway": 0.05,
			"push_scale": PUSH_SCALE,
			"pushers": _pushers,
			"shake": Vector4.ZERO,
			"hide_rect": Vector4.ZERO,
			"hide_amount": 0.0
		}
	)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Tufts"
	mmi.multimesh = mm
	mmi.material_override = _mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	_blades = mmi


func _build_blades() -> void:
	var mesh := PrismMesh.new()
	mesh.size = Vector3(0.18, 0.75, 0.06)
	mesh.material = Overworld._mat(color)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = int(size.x * size.z * density)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name)
	for i in mm.instance_count:
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(
			Vector3.ONE * rng.randf_range(0.7, 1.3)
		)
		var o := Vector3(
			rng.randf_range(-0.5, 0.5) * size.x, 0.35, rng.randf_range(-0.5, 0.5) * size.z
		)
		mm.set_instance_transform(i, Transform3D(b, o))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)
	_blades = mmi


## Short shudder when something jumps out (centred on the player, like the original).
func shake() -> void:
	_shake = 1.0
	_shake_t = 0.5


func _process(delta: float) -> void:
	if _mat == null:
		if _shake_t > 0.0:
			_shake_t = maxf(_shake_t - delta, 0.0)
			_blades.rotation.z = sin(_shake_t * 40.0) * 0.06 * (_shake_t / 0.5)
		return
	_shake = maxf(0.0, _shake - delta / SHAKE_SECS)
	var here := global_position
	var reach := maxf(size.x, size.z) / 2.0 + PUSH_RADIUS
	var n := 0
	var p := Overworld.player_of(self)
	if p and not _near(p.global_position, here, reach + 25.0) and _shake <= 0.0:
		return  # far from the camera: nobody sees the cards part
	var shake_at := Vector2(here.x, here.z)
	if p:
		shake_at = Vector2(p.global_position.x, p.global_position.z)
		if _near(p.global_position, here, reach):
			_pushers[n] = Vector4(p.global_position.x, 0.0, p.global_position.z, PUSH_RADIUS)  # shader reads .xz
			n += 1
	for grp in [WildMon.GROUP, WorldNpc.GROUP, "ow_follower"]:
		for w in get_tree().get_nodes_in_group(grp):
			if n >= MAX_PUSHERS:
				break
			if w is Node3D and w.visible and _near(w.global_position, here, reach):
				_pushers[n] = Vector4(w.global_position.x, 0.0, w.global_position.z, PUSH_RADIUS)
				n += 1
	for i in range(n, MAX_PUSHERS):
		_pushers[i] = Vector4.ZERO
	_mat.set_shader_parameter("pushers", _pushers)
	_mat.set_shader_parameter("shake", Vector4(shake_at.x, 0.0, shake_at.y, _shake))


static func _near(at: Vector3, here: Vector3, reach: float) -> bool:
	return absf(at.x - here.x) < reach and absf(at.z - here.z) < reach

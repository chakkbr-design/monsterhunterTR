class_name ArenaCrowd
extends RefCounted
## Crowd of the training stadium (ArenaStadium): every seat listed by StadiumParts (bank_seats /
## corner_seats) gets a seated fan with a probability from its position hash. One MultiMesh per
## stand section (so the sections are culled on their own), one shared material whose uniforms make
## the whole crowd cheer or run a Mexican wave.
## Fans are the pixel-art NPCs of the overworld (CROWD_SHEETS, CharSprite sheets): a Y-axis billboard
## quad per seat (battle/voxel/crowd_sprite.gdshader) showing the front-facing idle frame, sunk into
## the seat so only the upper body shows; cheering / the wave stand them up on the walk frames. The
## frames come from a runtime atlas (one row per sheet, the 3 "down" frames). Without the sheets
## (original/ is not in the repo) it falls back to the voxel figures (crowd.gdshader): a handful of
## 1/16 m boxes with the shirt as the instance colour, side colours near each end.
## Fans near each end mostly cheer for that side (side A at -x, side B at +x). Looks never use the
## battle RNG.

const SHADER := "res://battle/voxel/crowd.gdshader"
const SPRITE_SHADER := "res://battle/voxel/crowd_sprite.gdshader"
## Overworld NPC sheets that sit in the stands (everyone the maps, trainers and interiors use except
## the main cast: the player boy / girl "trainer*", the rival and Professor Oak).
const CROWD_SHEETS := [
	"npc_balding_man",
	"npc_brock",
	"npc_bug_catcher",
	"npc_camper",
	"npc_clerk",
	"npc_cooltrainer_f",
	"npc_daisy",
	"npc_girl",
	"npc_gym_guide",
	"npc_hiker",
	"npc_kid",
	"npc_lass",
	"npc_little_girl",
	"npc_mom",
	"npc_nurse",
	"npc_oldman",
	"npc_rocket_m",
	"npc_scientist",
	"npc_super_nerd",
	"npc_woman",
	"npc_worker",
	"npc_youngster",
]
## Sprite fan size: CharSprite pixels scaled up (a 32 px frame is 1.6 m standing, ~1.84 m here; Caio,
## 2026-10-27: 0.72 was too small), sunk SINK m below the seat pan so the head and the upper body
## (~1.5 m) show over the row in front and the legs hide in the seat (0.55 showed little more than heads).
const SPRITE_SCALE := 1.15
const SINK := 0.3
## Share of the seats taken (the bigger pixel-art fans need room: fewer of them).
const FILL := 0.84
const SPRITE_FILL := 0.38
## Length of a Mexican wave (crowd.gdshader wave_secs).
const WAVE_SECS := 14.0
const SHIRTS := [
	Color("e8e4da"),
	Color("2b2d33"),
	Color("e2b33a"),
	Color("3f9a4c"),
	Color("8b4fb8"),
	Color("e47a2e"),
	Color("2fa6a0"),
	Color("e8749a"),
	Color("6d7b8a"),
	Color("a8d0ec"),
	Color("c8b48a"),
	Color("7a3b2e"),
]
const SKIN := [
	Color("f1cfae"),
	Color("e2b48c"),
	Color("c98f63"),
	Color("a46a43"),
	Color("7a4a2c"),
	Color("f6dcc4")
]
const HAIR := [
	Color("2a1d16"),
	Color("5a3a22"),
	Color("b8863a"),
	Color("1b1b1f"),
	Color("8c8a86"),
	Color("a8442a")
]
const TROUSERS := [Color("2f3a52"), Color("3b3b40"), Color("6b5a44"), Color("d8d2c4")]

static var _mesh: ArrayMesh
static var _mat: ShaderMaterial
static var _sprite_tried := false
static var _sprite_mesh: ArrayMesh
static var _sprite_mat: ShaderMaterial
static var _sprite_rows := 0


## The shared material of the voxel fans (fallback; set the cheer / wave uniforms with set_param).
static func material() -> ShaderMaterial:
	if _mat:
		return _mat
	_mat = ShaderMaterial.new()
	_mat.shader = load(SHADER)
	_mat.set_shader_parameter("skin", _arr(SKIN))
	_mat.set_shader_parameter("hair", _arr(HAIR))
	_mat.set_shader_parameter("trousers", _arr(TROUSERS))
	return _mat


## Sets a cheer / wave uniform on every crowd material built so far.
static func set_param(param: String, value: Variant) -> void:
	for m in [_mat, _sprite_mat]:
		if m:
			(m as ShaderMaterial).set_shader_parameter(param, value)


## True when the pixel-art fans are available (at least one sheet loads).
static func uses_sprites() -> bool:
	_build_sprites()
	return _sprite_mat != null


## Builds the atlas (row r = CROWD_SHEETS that load, columns = the 3 "down" frames of the sheet,
## bottom-centred in a cell as big as the largest frame), the quad and the material. Once.
static func _build_sprites() -> void:
	if _sprite_tried:
		return
	_sprite_tried = true
	var imgs: Array[Image] = []
	var cell := Vector2i.ZERO
	for name in CROWD_SHEETS:
		var tex := CharSprite.sheet(name)
		if tex == null:
			continue
		var img := tex.get_image()
		if img == null or img.is_empty():
			continue
		if img.is_compressed() and img.decompress() != OK:
			continue
		img.convert(Image.FORMAT_RGBA8)
		imgs.append(img)
		cell.x = maxi(cell.x, img.get_width() / 3)
		cell.y = maxi(cell.y, img.get_height() / 4)
	if imgs.is_empty() or cell.x <= 0 or cell.y <= 0:
		return
	var atlas := Image.create(cell.x * 3, cell.y * imgs.size(), false, Image.FORMAT_RGBA8)
	for r in imgs.size():
		var img := imgs[r]
		var fw := img.get_width() / 3
		var fh := img.get_height() / 4
		for c in 3:
			atlas.blit_rect(
				img,
				Rect2i(c * fw, 0, fw, fh),
				Vector2i(c * cell.x + (cell.x - fw) / 2, r * cell.y + cell.y - fh)
			)
	_sprite_rows = imgs.size()
	var w := cell.x * CharSprite.PIXEL * SPRITE_SCALE
	var h := cell.y * CharSprite.PIXEL * SPRITE_SCALE
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var q := [
		[Vector3(-w * 0.5, h - SINK, 0), Vector2(0, 0)],
		[Vector3(w * 0.5, h - SINK, 0), Vector2(1, 0)],
		[Vector3(w * 0.5, -SINK, 0), Vector2(1, 1)],
		[Vector3(-w * 0.5, -SINK, 0), Vector2(0, 1)],
	]
	for i in [0, 1, 2, 0, 2, 3]:  # clockwise seen from +z (the camera side)
		st.set_normal(Vector3(0, 0, 1))
		st.set_uv(q[i][1])
		st.add_vertex(q[i][0])
	_sprite_mesh = st.commit()
	_sprite_mat = ShaderMaterial.new()
	_sprite_mat.shader = load(SPRITE_SHADER)
	_sprite_mat.set_shader_parameter("atlas", ImageTexture.create_from_image(atlas))
	_sprite_mat.set_shader_parameter("cells", Vector2(3, _sprite_rows))
	if _mat:
		for p in ["cheer_a", "cheer_b", "wave_tw", "wave_a0"]:
			_sprite_mat.set_shader_parameter(p, _mat.get_shader_parameter(p))


static func _arr(cols: Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	for c in cols:
		out.append(Vector3(c.r, c.g, c.b))
	return out


## Seated fan, local origin on the seat pan top, facing -z.
static func mesh() -> ArrayMesh:
	if _mesh:
		return _mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var d := 0.0625
	_box(st, Vector3(-3, 0, -6) * d, Vector3(3, 2, 1) * d, 3, 0)  # thighs
	_box(st, Vector3(-3, 2, -2) * d, Vector3(3, 10, 2) * d, 0, 0)  # torso
	_box(st, Vector3(-2, 10, -2) * d, Vector3(2, 14, 2) * d, 1, 0)  # head
	_box(st, Vector3(-2, 14, -2) * d, Vector3(2, 15, 3) * d, 2, 0)  # hair / cap top
	_box(st, Vector3(-2, 11, 2) * d, Vector3(2, 14, 3) * d, 2, 0)  # hair back
	_box(st, Vector3(-2, 13.5, -5) * d, Vector3(2, 14, -2) * d, 4, 0)  # cap brim
	_box(st, Vector3(-5, 4, -1) * d, Vector3(-3, 9, 1) * d, 0, 1)  # left sleeve
	_box(st, Vector3(-5, 3, -1) * d, Vector3(-3, 4, 1) * d, 1, 1)  # left hand
	_box(st, Vector3(3, 4, -1) * d, Vector3(5, 9, 1) * d, 0, 2)  # right sleeve
	_box(st, Vector3(3, 3, -1) * d, Vector3(5, 4, 1) * d, 1, 2)  # right hand
	_mesh = st.commit()
	return _mesh


## Axis box a..b (no bottom face), UV = (region, arm), white vertex colour.
static func _box(st: SurfaceTool, a: Vector3, b: Vector3, region: int, arm: int) -> void:
	var faces := [
		[
			Vector3(0, 0, -1),
			[
				Vector3(a.x, a.y, a.z),
				Vector3(a.x, b.y, a.z),
				Vector3(b.x, b.y, a.z),
				Vector3(b.x, a.y, a.z)
			]
		],
		[
			Vector3(0, 0, 1),
			[
				Vector3(b.x, a.y, b.z),
				Vector3(b.x, b.y, b.z),
				Vector3(a.x, b.y, b.z),
				Vector3(a.x, a.y, b.z)
			]
		],
		[
			Vector3(-1, 0, 0),
			[
				Vector3(a.x, a.y, b.z),
				Vector3(a.x, b.y, b.z),
				Vector3(a.x, b.y, a.z),
				Vector3(a.x, a.y, a.z)
			]
		],
		[
			Vector3(1, 0, 0),
			[
				Vector3(b.x, a.y, a.z),
				Vector3(b.x, b.y, a.z),
				Vector3(b.x, b.y, b.z),
				Vector3(b.x, a.y, b.z)
			]
		],
		[
			Vector3(0, 1, 0),
			[
				Vector3(a.x, b.y, a.z),
				Vector3(a.x, b.y, b.z),
				Vector3(b.x, b.y, b.z),
				Vector3(b.x, b.y, a.z)
			]
		],
	]
	for f in faces:
		var n: Vector3 = f[0]
		var q: Array = f[1]
		for i in [0, 2, 1, 0, 3, 2]:
			st.set_normal(n)
			st.set_color(Color.WHITE)
			st.set_uv(Vector2(region, arm))
			st.add_vertex(q[i])


## MultiMeshInstance3D with a fan on the taken seats of `seats` ([Vector3 local, float yaw], in the
## section's frame), `xf` = the section's world transform (for the hashes and the team mix).
static func section(seats: Array, xf: Transform3D, salt := 0) -> MultiMeshInstance3D:
	var sprites := uses_sprites()
	var taken: Array = []
	for s in seats:
		var w: Vector3 = xf * (s[0] as Vector3)
		var h := VoxelGrid.hash01(
			roundi(w.x * 4.0), roundi(w.y * 4.0), roundi(w.z * 4.0), 41 + salt
		)
		if h < (SPRITE_FILL if sprites else FILL):
			taken.append([s, w])
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not sprites
	mm.use_custom_data = true
	mm.mesh = _sprite_mesh if sprites else mesh()
	mm.instance_count = taken.size()
	for i in taken.size():
		var s: Array = taken[i][0]
		var w: Vector3 = taken[i][1]
		var p: Vector3 = s[0]
		var yaw: float = s[1]
		var hv := PackedFloat32Array()
		for k in 13:
			hv.append(VoxelGrid.hash01(roundi(w.x * 4.0), k, roundi(w.z * 4.0), 97 + salt))
		var t := Transform3D(Basis(Vector3.UP, yaw + (hv[1] - 0.5) * 0.3), p)
		var sc := 0.92 + hv[2] * 0.16
		t.basis = t.basis.scaled(Vector3(sc, sc, sc))
		mm.set_instance_transform(i, t)
		# Team: mostly side A fans at -x, side B at +x, a mix in the middle.
		var lean := clampf(w.x / 40.0, -1.0, 1.0)
		var pa := 0.5 - lean * 0.45
		var team := 1
		if hv[3] < pa * 0.62:
			team = 0
		elif hv[3] > 1.0 - (1.0 - pa) * 0.62:
			team = 2
		if sprites:
			# r = sheet row * 2 + mirrored, g = brightness, b = phase, a = team + liveliness.
			var row := int(hv[4] * _sprite_rows) % _sprite_rows
			var flip := 1 if hv[10] < 0.5 else 0
			mm.set_instance_custom_data(
				i, Color(row * 2 + flip, 0.86 + hv[7] * 0.14, hv[11], team + hv[12] * 0.99)
			)
			continue
		var shirt: Color = SHIRTS[int(hv[4] * SHIRTS.size()) % SHIRTS.size()]
		if team != 1 and hv[5] < 0.7:
			var tc: Color = StadiumParts.TEAM[team / 2]
			shirt = tc if hv[6] < 0.75 else Color(StadiumParts.TEAM_DARK[team / 2]).lightened(0.1)
		mm.set_instance_color(i, shirt)
		var skin := int(hv[7] * 6.0) % 6
		var hair := int(hv[8] * 6.0) % 6
		var trou := int(hv[9] * 4.0) % 4
		var cap := 8 if hv[10] < 0.22 else 0
		mm.set_instance_custom_data(
			i, Color(skin + 8 * hair, trou + cap, hv[11], team + hv[12] * 0.99)
		)
	var mi := MultiMeshInstance3D.new()
	mi.name = "Crowd"
	mi.multimesh = mm
	mi.material_override = _sprite_mat if sprites else material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if sprites:
		# Billboards turn with the camera: grow the cull box so an edge sprite is not cut.
		mi.extra_cull_margin = 1.0
	return mi

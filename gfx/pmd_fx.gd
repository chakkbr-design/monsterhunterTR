class_name PmdFx
extends RefCounted
## Porte do vfx_pmd.gd: efeitos de golpe do move_fx.json ("fx") a partir das folhas em
## res://original/assets/vfx/pmd/<fx_id>.png. Devolve FxSprite (o chamador põe na cena e dá tick).
## role = {fx, range: [lo, hi], scale, loop, blend, tint: Color, billboard, mirror, over (s), life}

const DIR := "res://original/assets/vfx/pmd/"
const DATA := "res://data/move_fx.json"
const FX_PIXEL_M := 0.03
const FX_TOWARD_CAM_M := 0.35
const DIR_VEC := [Vector2(0, -1), Vector2(-1, -1), Vector2(-1, 0), Vector2(-1, 1),
		Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(1, -1)]

static var _data := {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA))
		_data = parsed if parsed is Dictionary else {}
	return _data


static func table() -> Dictionary:
	return data().get("fx", {})


static func entry(fx_id: String) -> Dictionary:
	return table().get(fx_id, {})


static func exists(fx_id: String) -> bool:
	return not entry(fx_id).is_empty() and ResourceLoader.exists(DIR + fx_id + ".png")


## Papéis de um golpe no move_fx.json ("user", "travel", "hit", "beam", "stream", "tip").
static func move_roles(move_id: String) -> Dictionary:
	var m = data().get("moves", {}).get(move_id, {})
	return m if m is Dictionary else {}


## Normaliza um papel: "ember" -> {fx: "ember"}; {} se ausente.
static func role(roles: Dictionary, name: String) -> Dictionary:
	var r = roles.get(name)
	if r is String:
		return {"fx": r}
	if r is Dictionary:
		return r
	return {}


static func content_offset(e: Dictionary, lo: int, hi: int) -> Vector2:
	var bbox: Array = e.get("bbox", [])
	if bbox.is_empty():
		return Vector2.ZERO
	var x0 := 1e30
	var y0 := 1e30
	var x1 := -1e30
	var y1 := -1e30
	for i in range(maxi(lo, 0), mini(hi, bbox.size() - 1) + 1):
		var b: Array = bbox[i]
		if b.size() != 4 or float(b[2]) <= float(b[0]) or float(b[3]) <= float(b[1]):
			continue
		x0 = minf(x0, float(b[0]))
		y0 = minf(y0, float(b[1]))
		x1 = maxf(x1, float(b[2]))
		y1 = maxf(y1, float(b[3]))
	if x1 < 0.0:
		return Vector2.ZERO
	return Vector2((x0 + x1) * 0.5 - float(e.frame[0]) * 0.5, (y0 + y1) * 0.5 - float(e.frame[1]) * 0.5)


## Monta o efeito. aim = direção no mundo (orienta efeitos direcionais); cam = câmera para o giro na tela.
static func make(fx_id: String, aim: Vector3, role_d := {}, cam: Camera3D = null) -> FxSprite:
	var e := entry(fx_id)
	if e.is_empty() or not ResourceLoader.exists(DIR + fx_id + ".png"):
		return null
	var tex: Texture2D = load(DIR + fx_id + ".png")
	if tex == null:
		return null
	var n := int(e.get("frames", 1))
	var dirs := int(e.get("dirs", 1))
	var rng: Array = role_d.get("range", [0, n - 1])
	var lo := clampi(int(rng[0]), 0, maxi(n - 1, 0))
	var hi := clampi(int(rng[1]), lo, maxi(n - 1, 0))
	var sd := screen_dir(aim, cam)
	var f := FxSprite.create(tex, n, dirs)
	f.name = "PmdFx_" + fx_id
	f.set_meta("fx", fx_id)
	f.lo = lo
	f.hi = hi
	f.row = _row(e, sd)
	f.fps = float(e.get("fps", 12))
	f.loop = bool(role_d.get("loop", false))
	var over := float(role_d.get("over", 0.0))
	if over > 0.0:
		f.fps = float(hi - lo + 1) / over
	if role_d.has("life"):
		f.life = float(role_d.life)
	f.sprite.pixel_size = FX_PIXEL_M * float(role_d.get("scale", 1.0))
	var c := content_offset(e, lo, hi)
	f.sprite.offset = Vector2(-c.x, c.y)
	f.sprite.no_depth_test = bool(role_d.get("no_depth_test", false))
	var roll := dirs <= 1 and not bool(role_d.get("billboard", false)) and cam != null
	if roll:
		f.sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		f.set_meta("roll", atan2(sd.y, sd.x))
	f.sprite.flip_h = _mirror(e, sd, role_d)
	if role_d.get("tint") is Color:
		f.set_tint(role_d.tint)
	if String(role_d.get("blend", e.get("blend", "alpha"))) == "add":
		f.set_additive(true)
	return f


## Depois de pôr na árvore: alinha efeitos "roll" ao plano da câmera.
static func orient(f: FxSprite, cam: Camera3D) -> void:
	if f == null or cam == null or not f.has_meta("roll") or not f.is_inside_tree():
		return
	f.sprite.global_basis = cam.global_basis.orthonormalized()
	f.sprite.rotate_object_local(Vector3.BACK, float(f.get_meta("roll")))


static func screen_dir(aim: Vector3, cam: Camera3D) -> Vector2:
	var a := Vector3(aim.x, 0.0, aim.z)
	if a.length_squared() < 0.000001:
		return Vector2(0, -1)
	a = a.normalized()
	if cam == null or not cam.is_inside_tree():
		return Vector2(a.x, -a.z)
	var b := cam.global_basis
	var sd := Vector2(a.dot(b.x), a.dot(b.y))
	return sd.normalized() if sd.length_squared() > 0.000001 else Vector2(0, -1)


static func _row(e: Dictionary, sd: Vector2) -> int:
	var dirs := int(e.get("dirs", 1))
	if dirs <= 1:
		return 0
	if dirs < DIR_VEC.size():
		sd.x = -absf(sd.x)
	var best := 0
	var best_dot := -2.0
	for i in mini(dirs, DIR_VEC.size()):
		var d: float = sd.dot(DIR_VEC[i].normalized())
		if d > best_dot:
			best_dot = d
			best = i
	return best


static func _mirror(e: Dictionary, sd: Vector2, role_d: Dictionary) -> bool:
	if role_d.has("mirror"):
		return bool(role_d.mirror)
	var dirs := int(e.get("dirs", 1))
	if dirs > 1 and dirs < DIR_VEC.size():
		return sd.x > 0.0
	return String(e.get("src", "")).contains(".Flip.") and sd.x < 0.0


## Deslocamento de FX_TOWARD_CAM_M em direção à câmera (o efeito não some dentro do sprite).
static func toward_camera(at: Vector3, cam: Camera3D) -> Vector3:
	if cam == null or not cam.is_inside_tree():
		return Vector3.ZERO
	var d := cam.global_position - at
	return d.normalized() * FX_TOWARD_CAM_M if d.length_squared() > 0.000001 else Vector3.ZERO

class_name TerrainPathMask
extends RefCounted
## Port of the original terrain/path_mask.gd: organic dirt roads. Paths are grouped by terrace
## height; each level is one plane with the path_organic shader reading a soft mask (white = road).
## The masks are the original's pre-baked ones (world/masks/<zone>_path_<i>.png); a zone without a
## baked mask gets one generated here (signed distance to the rects + noise warp).

const MASK_DIR := "res://world/masks"
const PX_PER_M := 4.0
const MARGIN := 1.5
const WARP := 0.35
const SOFT := 0.5
const LIFT := 0.012


static func mask_file(zone_id: String, i: int) -> String:
	return "%s/%s_path_%d.png" % [MASK_DIR, zone_id, i]


static func load_mask(path: String) -> Image:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return null
	var img := Image.new()
	if img.load_png_from_buffer(bytes) != OK:
		return null
	return img


## {height: [rects]} in map order.
static func levels(paths: Array, height_at: Callable) -> Dictionary:
	var out := {}
	for r in paths:
		var h := snappedf(
			float(height_at.call(float(r[0]) + float(r[2]) / 2.0, float(r[1]) + float(r[3]) / 2.0)),
			0.01
		)
		if not out.has(h):
			out[h] = []
		out[h].append(r)
	return out


static func bounds(rects: Array) -> Rect2:
	var b := Rect2(rects[0][0], rects[0][1], rects[0][2], rects[0][3])
	for r in rects:
		b = b.merge(Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])))
	return b.grow(MARGIN)


static func generate(rects: Array, area: Rect2, seed := 0) -> Image:
	var w := maxi(int(ceil(area.size.x * PX_PER_M)), 1)
	var h := maxi(int(ceil(area.size.y * PX_PER_M)), 1)
	var img := Image.create(w, h, false, Image.FORMAT_L8)
	var coarse := FastNoiseLite.new()
	coarse.seed = seed
	coarse.frequency = 0.35
	var fine := FastNoiseLite.new()
	fine.seed = seed + 7
	fine.frequency = 1.4
	var reach := SOFT + WARP * 1.35 + 0.05
	for r in rects:
		var g := Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])).grow(reach)
		var i0 := clampi(int((g.position.x - area.position.x) * PX_PER_M), 0, w)
		var i1 := clampi(int(ceil((g.end.x - area.position.x) * PX_PER_M)), 0, w)
		var j0 := clampi(int((g.position.y - area.position.y) * PX_PER_M), 0, h)
		var j1 := clampi(int(ceil((g.end.y - area.position.y) * PX_PER_M)), 0, h)
		for j in range(j0, j1):
			var z := area.position.y + (j + 0.5) / PX_PER_M
			for i in range(i0, i1):
				var x := area.position.x + (i + 0.5) / PX_PER_M
				var d := INF
				for q in rects:
					d = minf(d, _sd_rect(x, z, q))
				d += coarse.get_noise_2d(x, z) * WARP + fine.get_noise_2d(x, z) * WARP * 0.35
				var v := 1.0 - smoothstep(-SOFT * 0.5, SOFT * 0.5, d)
				img.set_pixel(i, j, Color(v, v, v))
	return img


static func _sd_rect(x: float, z: float, r: Array) -> float:
	var qx: float = absf(x - (float(r[0]) + float(r[2]) / 2.0)) - float(r[2]) / 2.0
	var qz: float = absf(z - (float(r[1]) + float(r[3]) / 2.0)) - float(r[3]) / 2.0
	return Vector2(maxf(qx, 0.0), maxf(qz, 0.0)).length() + minf(maxf(qx, qz), 0.0)


static func overlay(
	rects: Array, level: float, image: Image, tint := Color.WHITE, mix := 0.0
) -> MeshInstance3D:
	var area := bounds(rects)
	var mat := WorldFx.shader_mat(
		"path_organic",
		{
			"mask_tex": ImageTexture.create_from_image(image),
			"mask_origin": area.position,
			"mask_size": area.size,
			"path_tint": tint,
			"path_mix": mix
		}
	)
	var pm := PlaneMesh.new()
	pm.size = area.size
	var mi := MeshInstance3D.new()
	mi.name = "PathLevel_%s" % str(level).replace(".", "_")
	mi.mesh = pm
	mi.material_override = mat
	mi.position = Vector3(area.get_center().x, level + LIFT, area.get_center().y)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

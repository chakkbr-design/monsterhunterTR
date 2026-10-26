class_name WeatherKit
extends RefCounted
## Procedural textures and curves shared by the weather effects (world WeatherRig, BattleWeatherFx):
## drop and grain gradients, soft dots, snowflakes, splash rings and a 4-frame splash crown sheet.
## Everything is made once and cached (the same texture object is reused by every material).

const LAYER := 1 << 19  ## visual layer 20: weather effects, never captured by the rain heightfield

static var _cache := {}


static func curve_tex(pts: Array) -> CurveTexture:
	var c := Curve.new()
	for p in pts:
		c.add_point(p)
	var t := CurveTexture.new()
	t.curve = c
	return t


static func color_ramp(a: Color, b: Color) -> GradientTexture1D:
	var g := Gradient.new()
	g.set_color(0, a)
	g.set_color(1, b)
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


## Drop / grain streak: bright in the middle of its length, fading at both ends (vertical, or
## horizontal with `wide`).
static func gradient_tex(wide := false) -> ImageTexture:
	var key := "grad%s" % wide
	if _cache.has(key):
		return _cache[key]
	var n := 32
	var img := Image.create(4 if not wide else n, n if not wide else 4, false, Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var u := float(y if not wide else x) / (n - 1)
			var a := sin(u * PI) * (0.4 + 0.6 * u if not wide else 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_cache[key] = ImageTexture.create_from_image(img)
	return _cache[key]


## Soft dot (flake, dust, mote); a larger `core` keeps the middle harder.
static func dot_tex(core := 0.35) -> ImageTexture:
	var key := "dot%.2f" % core
	if _cache.has(key):
		return _cache[key]
	var n := 32
	var c := (n - 1) * 0.5
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x - c, y - c).length() / c
			var a := clampf(1.0 - smoothstep(core, 1.0, d), 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	_cache[key] = ImageTexture.create_from_image(img)
	return _cache[key]


## Flake: white core with a blue-grey rim, so it still reads over settled snow.
static func flake_tex() -> ImageTexture:
	if _cache.has("flake"):
		return _cache.flake
	var n := 32
	var c := (n - 1) * 0.5
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x - c, y - c).length() / c
			var a := clampf(1.0 - smoothstep(0.55, 1.0, d), 0.0, 1.0)
			var col := Color(1, 1, 1).lerp(Color(0.55, 0.64, 0.8), smoothstep(0.3, 0.75, d))
			col.a = a
			img.set_pixel(x, y, col)
	_cache.flake = ImageTexture.create_from_image(img)
	return _cache.flake


## Pixel snowflake sheet (4 frames side by side, 8 px each): soft round flakes of four sizes
## ("#" solid, "+" half-transparent rim), so they read as snow and never as crisp symbols, and
## turn into soft dots far away (mipmaps).
static func flake_sheet() -> ImageTexture:
	if _cache.has("flake_sheet"):
		return _cache.flake_sheet
	var shapes := [
		[
			"........",
			"..++++..",
			".+####+.",
			".+####+.",
			".+####+.",
			".+####+.",
			"..++++..",
			"........"
		],
		[
			"........",
			"........",
			"...++...",
			"..+##+..",
			"..+##+..",
			"...++...",
			"........",
			"........"
		],
		[
			"........",
			"...+....",
			"..+#+...",
			".+###+..",
			"..+#+...",
			"...+....",
			"........",
			"........"
		],
		[
			"........",
			"........",
			"........",
			"...##...",
			"...##...",
			"........",
			"........",
			"........"
		],
	]
	var img := Image.create(32, 8, false, Image.FORMAT_RGBA8)
	for f in shapes.size():
		var rows: Array = shapes[f]
		for y in 8:
			for x in 8:
				var ch := String(rows[y])[x]
				if ch != ".":
					img.set_pixel(f * 8 + x, y, Color(1, 1, 1, 1.0 if ch == "#" else 0.45))
	_cache.flake_sheet = ImageTexture.create_from_image(img)
	return _cache.flake_sheet


## Thin ring (splash ripple seen from above): alpha rises over `inner` and falls over `outer`
## (fractions of the radius) on an `n` x `n` texture.
static func ring_tex(
	n := 32, inner := Vector2(0.66, 0.8), outer := Vector2(0.88, 1.0)
) -> ImageTexture:
	var key := "ring%d%s%s" % [n, inner, outer]
	if _cache.has(key):
		return _cache[key]
	var c := (n - 1) * 0.5
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x - c, y - c).length() / c
			var a := smoothstep(inner.x, inner.y, d) * (1.0 - smoothstep(outer.x, outer.y, d))
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_cache[key] = ImageTexture.create_from_image(img)
	return _cache[key]


## Splash crown, 4 frames of 8 x 8 px side by side (32 x 8): the drop lands, a crown of
## droplets jumps up and out, then the droplets fall back. Chunky pixels to match the voxels.
static func crown_sheet() -> ImageTexture:
	if _cache.has("crown"):
		return _cache.crown
	var img := Image.create(32, 8, false, Image.FORMAT_RGBA8)
	var frames := [
		[[3, 7], [4, 7], [4, 6]],
		[[2, 6], [5, 6], [3, 5], [4, 4], [2, 7], [5, 7]],
		[[1, 5], [6, 4], [3, 3], [5, 2], [2, 6]],
		[[1, 7], [6, 6], [4, 4], [2, 5]],
	]
	for f in frames.size():
		for p: Array in frames[f]:
			var a := 1.0 - 0.15 * f
			img.set_pixel(f * 8 + int(p[0]), int(p[1]), Color(1, 1, 1, a))
	_cache.crown = ImageTexture.create_from_image(img)
	return _cache.crown

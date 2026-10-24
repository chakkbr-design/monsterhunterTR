class_name ProcFx
extends Node3D
## Peça de efeito procedural (partícula, anel no chão, risco de velocidade, ícone em pixel art
## desenhado em código). Avança só em tick(dt) -> bool, como os outros nós do BattleVfx.
## As texturas são geradas uma vez (brancas, tingidas por `modulate`) e ficam em cache.

const OUTLINE := Color(0.13, 0.1, 0.17, 1.0)
const ICON_PX := 16

enum Face { BILLBOARD, GROUND, ROLL, UPRIGHT }

static var _tex := {}
static var _mats := {}

var spr: Sprite3D
var life := 0.4
var age := 0.0
var velocity := Vector3.ZERO
var gravity := 0.0
var drag := 0.0
var grow := Vector2(1.0, 1.0)  ## escala no início -> no fim
var pop := 0.0  ## s de "pulo" de escala no começo (0.5 -> 1)
var fade_in := 0.0  ## s
var fade := 0.35  ## fração final da vida em que some
var spin := 0.0  ## rad/s (giro na tela, ou no chão)
var follow: Node3D  ## segue este nó (global + follow_off)
var follow_off := Vector3.ZERO
var seek: Node3D  ## voa até este nó (global + seek_off) e some ao chegar
var seek_off := Vector3.ZERO
var seek_speed := 0.0
var wobble := 0.0  ## balanço lateral (m)
var ground_y := -100.0  ## quica/para no chão (y global) se > -100
var alpha := 1.0
var color := Color.WHITE
var on_end: Callable  ## chamado uma vez quando acaba (ex.: pedra que cai solta poeira)
var _roll := 0.0
var _face := Face.BILLBOARD
var _cam: Camera3D
var _px := 0.03
var _phase := 0.0
var _base := Vector3.ZERO
var _ended := false


## Cria uma peça (sem pôr na árvore). size_m = largura da textura em metros.
static func make(
	tex_name: String, size_m: float, col: Color, face := Face.BILLBOARD, add := false
) -> ProcFx:
	var t := tex(tex_name)
	if t == null:
		return null
	var f := ProcFx.new()
	f.name = "Proc_" + tex_name
	f.color = col
	f.alpha = col.a
	f._face = face
	var s := Sprite3D.new()
	s.texture = t
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.shaded = false
	s.double_sided = true
	s.transparent = true
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	f._px = size_m / float(maxi(t.get_width(), 1))
	s.pixel_size = f._px
	match face:
		Face.BILLBOARD:
			s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		Face.UPRIGHT:
			s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		Face.GROUND:
			s.billboard = BaseMaterial3D.BILLBOARD_DISABLED
			s.rotation_degrees = Vector3(-90, 0, 0)
		Face.ROLL:
			s.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	if add:
		s.material_override = _material(t, s.billboard, true)
	s.modulate = col
	f.spr = s
	f.add_child(s)
	f._phase = float(f.get_instance_id() % 628) / 100.0
	return f


## Cópia translúcida do sprite de um lutador (rastro de investida).
static func ghost(src: Sprite3D, col: Color) -> ProcFx:
	if src == null or src.texture == null:
		return null
	var f := ProcFx.new()
	f.name = "Proc_ghost"
	f.color = col
	f.alpha = col.a
	f._face = Face.UPRIGHT if src.billboard == BaseMaterial3D.BILLBOARD_FIXED_Y else Face.BILLBOARD
	var s := Sprite3D.new()
	s.texture = src.texture
	s.hframes = src.hframes
	s.vframes = src.vframes
	s.frame = src.frame
	s.region_enabled = src.region_enabled
	s.region_rect = src.region_rect
	s.centered = src.centered
	s.offset = src.offset
	s.flip_h = src.flip_h
	s.flip_v = src.flip_v
	s.billboard = src.billboard
	s.texture_filter = src.texture_filter
	s.shaded = false
	s.transparent = true
	s.double_sided = true
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.pixel_size = src.pixel_size
	s.scale = src.scale
	s.modulate = col
	f._px = src.pixel_size
	f.spr = s
	f.add_child(s)
	return f


static func _material(t: Texture2D, bb: int, add: bool) -> StandardMaterial3D:
	var key := "%d_%d_%s" % [t.get_instance_id(), bb, add]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if add else BaseMaterial3D.BLEND_MODE_MIX
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_texture = t
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = bb
	m.billboard_keep_scale = true
	_mats[key] = m
	return m


## Ângulo na tela (rad, 0 = direita, anti-horário) para Face.ROLL; precisa da câmera.
func set_roll(angle: float, cam: Camera3D) -> void:
	_roll = angle
	_cam = cam
	_orient()


func _orient() -> void:
	if _face != Face.ROLL or _cam == null or not is_instance_valid(_cam) or not is_inside_tree():
		return
	if not _cam.is_inside_tree():
		return
	spr.global_basis = _cam.global_basis.orthonormalized()
	spr.rotate_object_local(Vector3.BACK, _roll)


func _ready() -> void:
	_orient()
	_apply(0.0)


func tick(dt: float) -> bool:
	age += dt
	if is_instance_valid(follow) and follow.is_inside_tree() and is_inside_tree():
		global_position = follow.global_position + follow_off + _base
		_base += velocity * dt
	elif is_instance_valid(seek) and seek.is_inside_tree() and is_inside_tree():
		var to := seek.global_position + seek_off - global_position
		var step := seek_speed * dt
		velocity = velocity.lerp(to.normalized() * seek_speed, clampf(dt * 6.0, 0.0, 1.0))
		if to.length() <= maxf(step, 0.12):
			age = maxf(age, life)
		else:
			position += velocity * dt
	else:
		velocity.y -= gravity * dt
		if drag > 0.0:
			velocity *= maxf(0.0, 1.0 - drag * dt)
		position += velocity * dt
		if ground_y > -100.0 and is_inside_tree() and global_position.y < ground_y:
			global_position.y = ground_y
			velocity = Vector3(velocity.x * 0.5, absf(velocity.y) * 0.25, velocity.z * 0.5)
	if wobble > 0.0:
		spr.position.x = sin(age * 9.0 + _phase) * wobble
	if spin != 0.0:
		if _face == Face.GROUND:
			spr.rotate_y(spin * dt)
		elif _face == Face.ROLL:
			_roll += spin * dt
	if _face == Face.ROLL:
		_orient()
	if age >= life:
		_finish()
		return false
	_apply(age)
	return true


func _finish() -> void:
	if _ended:
		return
	_ended = true
	if on_end.is_valid():
		on_end.call(self)


func _apply(t: float) -> void:
	var k := clampf(t / maxf(life, 0.001), 0.0, 1.0)
	var s := lerpf(grow.x, grow.y, k)
	if pop > 0.0:
		s *= lerpf(0.4, 1.0, 1.0 - pow(1.0 - clampf(t / pop, 0.0, 1.0), 3.0))
	if _face == Face.BILLBOARD or _face == Face.UPRIGHT:
		spr.pixel_size = _px * maxf(s, 0.001)
	else:
		spr.pixel_size = _px
		spr.scale = Vector3.ONE * maxf(s, 0.001)
	var a := alpha
	if fade_in > 0.0:
		a *= clampf(t / fade_in, 0.0, 1.0)
	if k > 1.0 - fade:
		a *= clampf((1.0 - k) / maxf(fade, 0.001), 0.0, 1.0)
	spr.modulate = Color(color, a)


# --- Texturas geradas em código ---


static func tex(name: String) -> Texture2D:
	if _tex.has(name):
		return _tex[name]
	if name.begins_with("res://"):
		var r: Texture2D = load(name) as Texture2D if ResourceLoader.exists(name) else null
		_tex[name] = r
		return r
	var img: Image = null
	match name:
		"dot":
			img = _soft(16, func(u: float, v: float) -> float: return _falloff(sqrt(u * u + v * v)))
		"glow":
			img = _soft(
				32,
				func(u: float, v: float) -> float: return pow(_falloff(sqrt(u * u + v * v)), 2.2)
			)
		"ring":
			img = _soft(
				64, func(u: float, v: float) -> float: return _band(sqrt(u * u + v * v), 0.86, 0.08)
			)
		"ring_soft":
			img = _soft(
				64,
				func(u: float, v: float) -> float:
					var r := sqrt(u * u + v * v)
					return maxf(_band(r, 0.84, 0.12), 0.18 * _falloff(r) * float(r < 0.86))
			)
		"crescent":
			img = _soft(64, _crescent.bind(0.62, 0.33, 80.0))
		"arc":
			img = _soft(64, _crescent.bind(0.82, 0.1, 62.0))
		"streak":
			img = _soft_wh(
				32,
				8,
				func(u: float, v: float) -> float:
					var head := clampf((u + 1.0) * 0.5, 0.0, 1.0)
					return pow(head, 1.6) * _falloff(absf(v) / maxf(0.25 + 0.75 * head, 0.01))
			)
		"blade":
			img = _soft_wh(
				64,
				10,
				func(u: float, v: float) -> float:
					var w := maxf(1.0 - u * u, 0.0)
					return clampf((w * 0.95 - absf(v)) * 6.0, 0.0, 1.0)
			)
		"rays":
			img = _soft(
				64,
				func(u: float, v: float) -> float:
					var r := sqrt(u * u + v * v)
					var th := atan2(v, u)
					var spokes := pow(maxf(0.0, cos(th * 6.0)), 8.0) * (1.0 - r)
					var spokes2 := pow(maxf(0.0, cos(th * 6.0 + PI / 6.0)), 10.0) * (0.7 - r)
					return clampf(
						maxf(spokes * 1.6, spokes2 * 1.4) + pow(_falloff(r * 2.4), 1.5), 0.0, 1.0
					)
			)
		"star4":
			img = _soft(
				32,
				func(u: float, v: float) -> float:
					var d := pow(absf(u), 0.55) + pow(absf(v), 0.55)
					return clampf(pow(clampf(1.0 - d, 0.0, 1.0), 1.2) * 2.2, 0.0, 1.0)
			)
		"cloud":
			img = _cloud()
		"swirl":
			img = _soft(
				64,
				func(u: float, v: float) -> float:
					var r := sqrt(u * u + v * v)
					var th := atan2(v, u)
					var arm := pow(maxf(0.0, cos(th * 3.0 + r * 7.0)), 3.0)
					return arm * _band(r, 0.6, 0.32)
			)
		"column":
			img = _soft_wh(
				16,
				64,
				func(u: float, v: float) -> float:
					var ends := clampf((1.0 - absf(v)) * 4.0, 0.0, 1.0)
					return _falloff(absf(u)) * ends
			)
		"hex":
			img = _hex()
		"crack":
			img = _crack()
		"hole":
			img = _soft(
				32,
				func(u: float, v: float) -> float:
					var r := sqrt(u * u + v * v)
					return clampf((0.95 - r) * 6.0, 0.0, 1.0) * 0.85
			)
		"clod":
			img = _clod()
		"heart":
			img = _icon(
				func(u: float, v: float) -> bool:
					var x := u * 1.25
					var y := v * 1.3 + 0.12
					var a := x * x + y * y - 1.0
					return a * a * a - x * x * y * y * y <= 0.0
			)
		"moon":
			img = _icon(
				func(u: float, v: float) -> bool:
					var in1 := u * u + v * v < 0.8
					var dx := u - 0.42
					var dy := v - 0.3
					return in1 and dx * dx + dy * dy > 0.5
			)
		"star5":
			img = _icon(
				func(u: float, v: float) -> bool:
					var r := sqrt(u * u + v * v)
					var th := atan2(v, u) - PI / 2.0
					var seg := TAU / 5.0
					var t := absf(fposmod(th, seg) - seg * 0.5) / (seg * 0.5)
					return r <= lerpf(0.42, 0.98, t)
			)
		"spike":
			img = _icon(
				func(u: float, v: float) -> bool:
					return v > -0.85 and v < 0.95 and absf(u) < (0.95 - v) * 0.42
			)
		"arrow":
			img = _icon(
				func(u: float, v: float) -> bool:
					var head := v >= 0.0 and v < 0.95 and absf(u) < (0.95 - v) * 1.0
					var shaft := absf(u) < 0.3 and v > -0.9 and v < 0.05
					return head or shaft
			)
		"fang":
			img = _jaw()
		"claw":
			img = _icon(
				func(u: float, v: float) -> bool:
					for i in 3:
						var off := (float(i) - 1.0) * 0.55
						var s := (u + v) * 0.7071
						var d := (u - v) * 0.7071 - off
						if absf(s) < 0.95 and absf(d) < 0.16 * (1.0 - absf(s)) + 0.02:
							return true
					return false
			)
		"feather":
			img = _icon(
				func(u: float, v: float) -> bool:
					var x := (u - v) * 0.7071
					var y := (u + v) * 0.7071
					return x * x / 0.09 + y * y / 0.85 <= 1.0
			)
		"petal":
			img = _icon(
				func(u: float, v: float) -> bool:
					var y := v + 0.1
					return u * u / (0.32 * (1.0 - y * 0.35)) + y * y / 0.75 <= 1.0
			)
		"drop":
			img = _icon(
				func(u: float, v: float) -> bool:
					var circ := u * u + (v + 0.3) * (v + 0.3) < 0.36
					var tri := v >= -0.3 and v < 0.95 and absf(u) < (0.95 - v) * 0.48
					return circ or tri
			)
		"note":
			img = _mask(
				[
					"....oooo..",
					"....o##oo.",
					"....o#o##o",
					"....o#o.o#o",
					"....o#o..o",
					"....o#o...",
					"....o#o...",
					".oooo#o...",
					"o#####o...",
					"o####o....",
					".oooo.....",
				]
			)
	if img == null:
		_tex[name] = null
		return null
	var t := ImageTexture.create_from_image(img)
	_tex[name] = t
	return t


static func _falloff(r: float) -> float:
	return clampf(1.0 - r, 0.0, 1.0) * clampf(1.0 - r, 0.0, 1.0) * (1.0 + 2.0 * r) * float(r < 1.0)


static func _band(r: float, at: float, w: float) -> float:
	var d := (r - at) / w
	return exp(-d * d)


static func _crescent(u: float, v: float, inner: float, thick: float, deg: float) -> float:
	var r := sqrt(u * u + v * v)
	var th := rad_to_deg(atan2(v, u))
	if absf(th) > deg:
		return 0.0
	var k := absf(th) / deg
	var w := thick * (1.0 - k * k)
	var outer := inner + w
	if r < inner or r > outer:
		return 0.0
	var edge := (r - inner) / maxf(w, 0.001)
	return clampf(0.35 + 0.65 * edge, 0.0, 1.0) * clampf((1.0 - k) * 3.0, 0.0, 1.0)


## Arcada de dentes (24x14): faixa curva e quatro presas, as das pontas mais longas.
static func _jaw() -> Image:
	var w := 26
	var h := 15
	var grid := []
	for y in h:
		var row := []
		for x in w:
			row.append(false)
		grid.append(row)
	for x in range(1, w - 1):
		var k := (float(x) - 12.5) / 12.5
		var top := 1 + int(round(3.0 * k * k))
		for y in range(top, top + 3):
			grid[y][x] = true
	for t in [[4, 10], [9, 6], [16, 6], [21, 10]]:
		var cx: int = t[0]
		var ln: int = t[1]
		var k2 := (float(cx) - 12.5) / 12.5
		var base := 3 + int(round(3.0 * k2 * k2))
		for i in ln:
			var half := int(round(2.2 * (1.0 - float(i) / float(ln))))
			for dx in range(-half, half + 1):
				var yy := base + i
				if yy < h - 1:
					grid[yy][cx + dx] = true
	return _outline(grid, w, h)


static func _soft(n: int, f: Callable) -> Image:
	return _soft_wh(n, n, f)


static func _soft_wh(w: int, h: int, f: Callable) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var u := (float(x) + 0.5) / float(w) * 2.0 - 1.0
			var v := 1.0 - (float(y) + 0.5) / float(h) * 2.0
			var a := clampf(float(f.call(u, v)), 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return img


## Ícone 16x16 a partir de uma forma implícita: preenchimento claro, realce no alto à esquerda e
## contorno escuro (fica legível em cima da grama e dos sprites).
static func _icon(inside: Callable) -> Image:
	var n := ICON_PX
	var grid := []
	for y in n:
		var row := []
		for x in n:
			var u := (float(x) + 0.5) / float(n) * 2.2 - 1.1
			var v := 1.1 - (float(y) + 0.5) / float(n) * 2.2
			row.append(bool(inside.call(u, v)))
		grid.append(row)
	return _outline(grid, n, n)


static func _mask(rows: Array) -> Image:
	var h := rows.size()
	var w := 0
	for r in rows:
		w = maxi(w, String(r).length())
	var n := maxi(maxi(w, h) + 2, ICON_PX)
	var grid := []
	for y in n:
		var row := []
		for x in n:
			row.append(false)
		grid.append(row)
	var ox := (n - w) / 2
	var oy := (n - h) / 2
	for y in h:
		var s := String(rows[y])
		for x in s.length():
			if s[x] == "#":
				grid[y + oy][x + ox] = true
	return _outline(grid, n, n)


static func _outline(grid: Array, w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			if grid[y][x]:
				var lit: bool = not (y > 0 and grid[y - 1][x]) or not (x > 0 and grid[y][x - 1])
				img.set_pixel(x, y, Color(1, 1, 1, 1) if lit else Color(0.86, 0.86, 0.9, 1))
				continue
			var near := false
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var xx: int = x + d.x
				var yy: int = y + d.y
				if xx >= 0 and yy >= 0 and xx < w and yy < h and grid[yy][xx]:
					near = true
					break
			if near:
				img.set_pixel(x, y, OUTLINE)
	return img


static func _hex() -> Image:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var cells := [Vector2.ZERO]
	for i in 6:
		var a := TAU * float(i) / 6.0
		cells.append(Vector2(cos(a), sin(a)) * 0.5)
	for y in n:
		for x in n:
			var p := Vector2((float(x) + 0.5) / n * 2.0 - 1.0, 1.0 - (float(y) + 0.5) / n * 2.0)
			var outer := _hexd(p) / 0.95
			if outer > 1.0:
				continue
			var a := 0.16 + 0.1 * outer
			if outer > 0.9:
				a = 1.0
			for c in cells:
				var d := _hexd((p - c) / 0.29)
				if absf(d - 1.0) < 0.09:
					a = maxf(a, 0.55)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return img


static func _hexd(p: Vector2) -> float:
	var q := Vector2(absf(p.x), absf(p.y))
	return maxf(q.x * 0.866 + q.y * 0.5, q.y)


static func _cloud() -> Image:
	var n := 32
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var blobs := [
		Vector3(-0.45, -0.1, 0.42),
		Vector3(0.0, 0.15, 0.55),
		Vector3(0.45, -0.05, 0.45),
		Vector3(0.15, -0.3, 0.4),
		Vector3(-0.2, -0.3, 0.4)
	]
	for y in n:
		for x in n:
			var u := (float(x) + 0.5) / n * 2.0 - 1.0
			var v := 1.0 - (float(y) + 0.5) / n * 2.0
			var a := 0.0
			for b in blobs:
				var d: float = Vector2(u - b.x, v - b.y).length() / b.z
				a = maxf(a, clampf((1.0 - d) * 4.0, 0.0, 1.0))
			if a <= 0.0:
				continue
			var shade := clampf(0.62 + v * 0.45, 0.45, 1.0)
			img.set_pixel(x, y, Color(shade, shade, shade * 1.04, a))
	return img


static func _crack() -> Image:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var r := RandomNumberGenerator.new()
	r.seed = 77
	var col := Color(0.16, 0.11, 0.07, 0.9)
	for k in 7:
		var a := TAU * float(k) / 7.0 + r.randf_range(-0.3, 0.3)
		var p := Vector2(32, 32)
		var ln := r.randf_range(16.0, 30.0)
		var steps := int(ln)
		for i in steps:
			a += r.randf_range(-0.35, 0.35)
			p += Vector2(cos(a), sin(a))
			var w := 1 if i > steps / 2 else 2
			for dx in range(-w / 2, w / 2 + 1):
				for dy in range(-w / 2, w / 2 + 1):
					var q := Vector2i(int(p.x) + dx, int(p.y) + dy)
					if q.x >= 0 and q.y >= 0 and q.x < n and q.y < n:
						img.set_pixelv(q, col)
	for y in n:
		for x in n:
			var d := Vector2(x - 31.5, y - 31.5).length()
			if d < 6.0:
				img.set_pixel(x, y, Color(0.12, 0.08, 0.05, 0.85))
	return img


static func _clod() -> Image:
	var rows := [
		"..oooo..",
		".o#+##o.",
		"o#+####o",
		"o######o",
		"o#####xo",
		".o##xxo.",
		"..oooo..",
	]
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	var pal := {
		"o": Color(0.18, 0.11, 0.06),
		"#": Color(0.55, 0.38, 0.22),
		"+": Color(0.72, 0.55, 0.34),
		"x": Color(0.4, 0.27, 0.15)
	}
	for y in rows.size():
		var s := String(rows[y])
		for x in s.length():
			if pal.has(s[x]):
				img.set_pixel(x, y, pal[s[x]])
	return img

class_name PokemonSprites
extends RefCounted
## Porte do pokemon_sprites.gd do original: monta a "spec" visual de cada espécie a partir de
## res://original/assets/pokemon/<slug>/ (overworld.png + sprite.json, front/back/icon/party_icon,
## pmd/anims.json + pmd/*-Anim.png). Tudo estático e em cache.
##
## spec(species) -> {texture, hframes, vframes, rows, frames_per_row, pixel_size, offset_y,
##                   visible_m, tint, static, faces, real, icon, front, back, party_icon,
##                   front_frames, back_frames, party_icon_frames, pmd?}
## pmd[name] = {texture, w, h, dirs, frames, durations (s), anchor, rush, hit, return}

const ROOT := "res://original/assets/pokemon/"
const ORIGINAL_PREFIX := "res://original/assets/"
const PMD_ANIMS := "res://data/pmd_anims.json"
const FALLBACK_SPRITE := "res://original/assets/sprites/critter_green.png"
const DEFAULT_ROWS := {"down": 0, "left": 1, "right": 2, "up": 3}
const PLACEHOLDER_PIXEL := 0.05
const CARD_H := 1.3

static var _cache := {}
static var _pmd_data := {}
static var _footprint_cache := {}
static var _fit_cache := {}


static func slug(species: String) -> String:
	return species.to_lower().replace(" ", "_").replace(".", "").replace("'", "")


## Caminho do original ("res://assets/...") convertido para "res://original/assets/...".
static func asset_path(p: String) -> String:
	if p.begins_with("res://assets/"):
		return ORIGINAL_PREFIX + p.substr("res://assets/".length())
	return p


static func dir_of(species: String) -> String:
	return ROOT + slug(species) + "/"


static func _species_data(species: String) -> Dictionary:
	return Dex.species(species)


static func spec(species: String) -> Dictionary:
	var key := slug(species)
	if _cache.has(key):
		return _cache[key]
	var sp := _species_data(species)
	var dir := dir_of(species)
	var s := {}
	if ResourceLoader.exists(dir + "overworld.png"):
		var tex: Texture2D = load(dir + "overworld.png")
		var cfg := {}
		if FileAccess.file_exists(dir + "sprite.json"):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(dir + "sprite.json"))
			if parsed is Dictionary:
				cfg = parsed
		var w := tex.get_width()
		var h := tex.get_height()
		var hf := int(cfg.get("hframes", 0))
		var vf := int(cfg.get("vframes", 0))
		if hf <= 0 or vf <= 0:
			if h == w * 2:
				hf = 2
				vf = 4
			else:
				hf = 1
				vf = 1
		var fh := float(h) / vf
		var height_m := float(cfg.get("height_m", sp.get("height_m", 1.4)))
		s = {"texture": tex, "hframes": hf, "vframes": vf, "rows": cfg.get("rows", DEFAULT_ROWS),
				"frames_per_row": hf, "pixel_size": height_m / fh, "offset_y": fh / 2.0,
				"visible_m": float(cfg.get("visible_m", height_m * 0.6)),
				"tint": Color.WHITE, "static": hf * vf == 1, "faces": cfg.get("faces", "left"), "real": true}
	elif ResourceLoader.exists(dir + "front.png"):
		# Sem overworld: o primeiro quadro do front.png como carta parada (altura da espécie).
		var strip := _strip(dir + "front.png")
		var fr: Texture2D = strip.frame
		var fh2 := maxf(float(fr.get_height()), 1.0)
		var hm := float(sp.get("height_m", 1.0))
		s = {"texture": fr, "hframes": 1, "vframes": 1, "rows": {}, "frames_per_row": 1,
				"pixel_size": clampf(hm, 0.5, 2.0) / fh2, "offset_y": fh2 / 2.0, "tint": Color.WHITE,
				"static": true, "faces": "left", "real": true, "visible_m": clampf(hm, 0.5, 2.0)}
	else:
		var path := asset_path(String(sp.get("sprite", FALLBACK_SPRITE)))
		if not ResourceLoader.exists(path):
			path = FALLBACK_SPRITE
		var tex2: Texture2D = load(path)
		s = {"texture": tex2, "hframes": 2, "vframes": 4, "rows": DEFAULT_ROWS, "frames_per_row": 2,
				"pixel_size": PLACEHOLDER_PIXEL * float(sp.get("placeholder_scale", 1.0)), "offset_y": 16.0,
				"static": false, "faces": "left", "real": false, "visible_m": 1.0,
				"tint": Color(String(sp.get("placeholder_tint", "#ffffff")))}
	_pack_sprites(s, dir)
	_pack_pmd(s, dir + "pmd/")
	_cache[key] = s
	return s


static func has_pmd(species: String) -> bool:
	return spec(species).has("pmd")


static func _pack_pmd(s: Dictionary, pmd_dir: String) -> void:
	if not FileAccess.file_exists(pmd_dir + "anims.json"):
		return
	var raw = JSON.parse_string(FileAccess.get_file_as_string(pmd_dir + "anims.json"))
	if not raw is Dictionary:
		return
	var pmd := {}
	for name in raw:
		var a: Dictionary = raw[name]
		var path := pmd_dir + String(a.file)
		if not ResourceLoader.exists(path):
			continue
		var tex: Texture2D = load(path)
		if tex == null:
			continue
		var secs: Array = []
		for t in a.durations:
			secs.append(float(t) / 60.0)
		pmd[name] = {"texture": tex, "w": int(a.w), "h": int(a.h), "dirs": int(a.dirs),
				"frames": secs.size(), "durations": secs, "anchor": a.get("anchor", []),
				"rush": int(a.get("rush", -1)), "hit": int(a.get("hit", -1)), "return": int(a.get("return", -1))}
	if not pmd.has("Idle"):
		return
	s["pmd"] = pmd
	var idle: Dictionary = pmd["Idle"]
	var fh := int(idle.h)
	var img := (idle.texture as Texture2D).get_image()
	var used := Rect2i(0, 0, int(idle.w), fh)
	if img != null:
		used = img.get_region(Rect2i(0, 0, int(idle.w), fh)).get_used_rect()
	s["texture"] = idle.texture
	s["hframes"] = int(idle.frames)
	s["vframes"] = int(idle.dirs)
	s["frames_per_row"] = int(idle.frames)
	s["static"] = false
	s["pixel_size"] = float(s.get("visible_m", 1.0)) / maxf(float(used.size.y), 1.0)
	s["offset_y"] = float(used.position.y + used.size.y) - fh / 2.0


static func pmd_anims() -> Dictionary:
	if _pmd_data.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PMD_ANIMS))
		_pmd_data = parsed if parsed is Dictionary else {}
	return _pmd_data


## Primeira animação da cadeia que a espécie tem ("" se nenhuma).
static func resolve_chain(species: String, chain: Array) -> String:
	var pmd: Dictionary = spec(species).get("pmd", {})
	for name in chain:
		if pmd.has(name):
			return String(name)
	return ""


## Cadeia de animação de um golpe (por id, senão pelo kind).
static func move_chain(mv: Dictionary) -> Array:
	var chains := pmd_anims()
	var by_kind: Dictionary = chains.get("kinds", {})
	var by_move: Dictionary = chains.get("moves", {})
	return by_move.get(String(mv.get("id", "")), by_kind.get(String(mv.get("kind", "")), []))


static func state_chain(state: String) -> Array:
	return pmd_anims().get("states", {}).get(state, [])


static func footprint_m(species: String) -> float:
	var key := slug(species)
	if _footprint_cache.has(key):
		return _footprint_cache[key]
	var s := spec(species)
	var w := 0.0
	if bool(s.get("real", false)):
		var tex: Texture2D = s.texture
		var fw := int(tex.get_width() / maxi(1, int(s.hframes)))
		var fh := int(tex.get_height() / maxi(1, int(s.vframes)))
		var img := tex.get_image()
		if img != null and fw > 0 and fh > 0:
			w = float(img.get_region(Rect2i(0, 0, fw, fh)).get_used_rect().size.x) * float(s.pixel_size)
	if w <= 0.0:
		w = float(s.get("visible_m", 1.0)) * 0.9
	_footprint_cache[key] = w
	return w


static func _pack_sprites(s: Dictionary, dir: String) -> void:
	var icon_tex: Texture2D = load(dir + "icon.png") if ResourceLoader.exists(dir + "icon.png") else _frame0(s)
	var fr := _strip(dir + "front.png")
	var bk := _strip(dir + "back.png")
	var party := _strip(dir + "party_icon.png")
	s["icon"] = icon_tex
	s["front"] = fr.get("frame", icon_tex)
	s["back"] = bk.get("frame", s["front"])
	s["party_icon"] = party.get("frame", icon_tex)
	s["front_frames"] = {"texture": fr.get("texture", s["front"]), "frames": fr.get("frames", 1)}
	s["back_frames"] = {"texture": bk.get("texture", s["back"]), "frames": bk.get("frames", 1)}
	s["party_icon_frames"] = {"texture": party.get("texture", s["party_icon"]), "frames": party.get("frames", 1)}


static func _strip(path: String) -> Dictionary:
	if not ResourceLoader.exists(path):
		return {}
	var tex: Texture2D = load(path)
	if tex == null:
		return {}
	var fh := tex.get_height()
	if fh <= 0:
		return {}
	var frames := maxi(1, int(tex.get_width() / fh))
	return {"texture": tex, "frames": frames, "frame": atlas(tex, 0, frames)}


static func atlas(tex: Texture2D, index: int, frames: int) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = tex
	var w := tex.get_width() / float(maxi(1, frames))
	at.region = Rect2(index * w, 0, w, tex.get_height())
	return at


static func _frame0(s: Dictionary) -> Texture2D:
	var tex: Texture2D = s.texture
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(0, 0, tex.get_width() / s.hframes, tex.get_height() / s.vframes)
	return at


static func icon(species: String) -> Texture2D:
	return spec(species).icon


static func front(species: String) -> Texture2D:
	return spec(species).front


static func back(species: String) -> Texture2D:
	return spec(species).back


static func party_icon(species: String) -> Texture2D:
	return spec(species).party_icon


static func front_frames(species: String) -> Dictionary:
	return spec(species).front_frames


static func back_frames(species: String) -> Dictionary:
	return spec(species).back_frames


static func party_icon_frames(species: String) -> Dictionary:
	return spec(species).party_icon_frames


static func tint(species: String) -> Color:
	return spec(species).tint


static func icon_fitted(species: String, size_px: int, fill := 0.95) -> Texture2D:
	return _fit_icon(species, size_px, fill, false)


static func disc_icon(species: String, size_px: int, fill := 0.85) -> Texture2D:
	return _fit_icon(species, size_px, fill, true)


static func _fit_icon(species: String, size_px: int, fill: float, circle: bool) -> Texture2D:
	var key := "%s|%d|%.2f|%s" % [slug(species), size_px, fill, circle]
	if _fit_cache.has(key):
		return _fit_cache[key]
	var tex: Texture2D = icon(species)
	if tex == null:
		return null
	var img: Image = null
	if tex is AtlasTexture:
		var at := tex as AtlasTexture
		img = at.atlas.get_image().get_region(Rect2i(at.region))
	else:
		img = tex.get_image()
	if img == null:
		_fit_cache[key] = tex
		return tex
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var used := img.get_used_rect()
	var crop: Image = img.get_region(used) if used.size.x > 0 and used.size.y > 0 else img.duplicate()
	var k := (size_px * fill) / maxf(float(crop.get_width()), float(crop.get_height()))
	crop.resize(maxi(1, int(round(crop.get_width() * k))), maxi(1, int(round(crop.get_height() * k))), Image.INTERPOLATE_NEAREST)
	var canvas := Image.create(size_px, size_px, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0, 0, 0, 0))
	canvas.blit_rect(crop, Rect2i(Vector2i.ZERO, crop.get_size()),
			Vector2i((size_px - crop.get_width()) / 2, (size_px - crop.get_height()) / 2))
	if circle:
		var r := size_px * 0.5
		var rr := r * r
		for y in size_px:
			for x in size_px:
				var dx := x + 0.5 - r
				var dy := y + 0.5 - r
				if dx * dx + dy * dy > rr:
					canvas.set_pixel(x, y, Color(0, 0, 0, 0))
	var out := ImageTexture.create_from_image(canvas)
	_fit_cache[key] = out
	return out


## Spec de "carta" (textura avulsa, sem animação) com altura fixa.
static func card(tex: Texture2D) -> Dictionary:
	var h := maxf(float(tex.get_height()), 1.0) if tex != null else 1.0
	return {"texture": tex, "hframes": 1, "vframes": 1, "rows": {}, "frames_per_row": 1,
			"pixel_size": CARD_H / h, "offset_y": h / 2.0, "tint": Color.WHITE,
			"static": true, "faces": "left", "visible_m": CARD_H}


static func reload() -> void:
	_cache.clear()
	_footprint_cache.clear()
	_fit_cache.clear()
	_pmd_data = {}

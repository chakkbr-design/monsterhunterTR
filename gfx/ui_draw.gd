class_name UiDraw
extends RefCounted
## Porte dos helpers de desenho do original (ui/ui_draw.gd + cores/fontes do ui_kit.gd).
## Tudo estático: recebe um CanvasItem e desenha no _draw() dele.

const PAPER := Color("f8f8f0")
const INK := Color("283040")
const RED := Color("e0403a")
const GREEN := Color("48a860")
const BLUE := Color("3870c8")
const AMBER := Color("e8b030")
const PP_BLUE := Color("58a0e8")
const DIM := Color("9098a0")
const COL_INK := Color(0.07, 0.08, 0.11)
const COL_WHITE := Color(0.97, 0.97, 0.95)
const TRACK := Color(0.16, 0.18, 0.22)
const EXP_TRACK := Color(0.46, 0.49, 0.56)
const COL_BUFF := Color(0.3, 0.62, 1.0)
const COL_DEBUFF := Color(0.93, 0.33, 0.3)

const TITLE_FONT_PATH := "res://original/assets/fonts/PixelifySans.ttf"
const BODY_FONT_PATH := "res://original/assets/fonts/Nunito.ttf"

const STATUS_TAGS := {
	"burn": ["BRN", Color(0.93, 0.45, 0.2)],
	"poison": ["PSN", Color(0.65, 0.3, 0.75)],
	"paralysis": ["PAR", Color(0.95, 0.8, 0.2)],
	"sleep": ["SLP", Color(0.55, 0.6, 0.7)],
	"freeze": ["FRZ", Color(0.55, 0.85, 0.9)],
	"faint": ["FNT", Color(0.45, 0.45, 0.5)],
	"leech": ["SEED", Color(0.4, 0.75, 0.3)],
	"confusion": ["CNF", Color(0.85, 0.45, 0.75)]
}
const STAGE_ORDER := ["atk", "def", "spa", "spd", "spe"]
const STAGE_SHORT := {"atk": "ATK", "def": "DEF", "spa": "SPA", "spd": "SPD", "spe": "SPE"}

static var _fonts := {}


static func title_font() -> Font:
	return _font(TITLE_FONT_PATH, 600)


static func font() -> Font:
	return _font(BODY_FONT_PATH, 600)


static func heavy_font() -> Font:
	return _font(BODY_FONT_PATH, 900)


static func _font(p: String, weight: int) -> Font:
	var key := "%s:%d" % [p, weight]
	if _fonts.has(key):
		return _fonts[key]
	var f: Font = ThemeDB.fallback_font
	var base := load(p) as FontFile if ResourceLoader.exists(p) else null
	if base:
		var fv := FontVariation.new()
		fv.base_font = base
		fv.variation_opentype = {
			TextServerManager.get_primary_interface().name_to_tag("wght"): weight
		}
		f = fv
	_fonts[key] = f
	return f


static func hp_color(ratio: float) -> Color:
	if ratio > 0.5:
		return GREEN
	if ratio > 0.2:
		return AMBER
	return RED


static func glass_box(alpha := 0.35, radius := 14) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(INK, alpha)
	sb.border_color = Color(PAPER, 0.08)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	return sb


static func glass(ci: CanvasItem, r: Rect2, alpha := 0.35, radius := 14) -> void:
	rounded(ci, r, Color(INK, alpha), radius, 1.0, Color(PAPER, 0.08))


## Uma StyleBoxFlat reaproveitada: draw_style_box desenha na hora, então dá para reconfigurar a cada chamada
## (antes era uma StyleBoxFlat nova por retângulo, dezenas por quadro no HUD da batalha).
static var _sb: StyleBoxFlat


static func rounded(
	ci: CanvasItem,
	r: Rect2,
	col: Color,
	radius := 6.0,
	border := 0.0,
	border_col := Color.TRANSPARENT
) -> void:
	if _sb == null:
		_sb = StyleBoxFlat.new()
		_sb.anti_aliasing = true
	var sb := _sb
	sb.bg_color = col
	sb.set_corner_radius_all(int(radius))
	sb.set_border_width_all(int(border) if border > 0.0 else 0)
	sb.border_color = border_col
	ci.draw_style_box(sb, r)


static func text(
	ci: CanvasItem,
	pos: Vector2,
	s: String,
	size: int,
	col := COL_WHITE,
	outline := 4,
	align := HORIZONTAL_ALIGNMENT_LEFT,
	width := -1.0,
	f: Font = null
) -> void:
	var fnt := f if f != null else font()
	if outline > 0:
		ci.draw_string_outline(
			fnt, pos, s, align, width, size, outline, Color(0, 0, 0, 0.85 * col.a)
		)
	ci.draw_string(fnt, pos, s, align, width, size, col)


static func text_width(s: String, size: int, f: Font = null) -> float:
	return (f if f != null else font()).get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


static func text_center(
	ci: CanvasItem,
	center: Vector2,
	s: String,
	size: int,
	col := COL_WHITE,
	outline := 4,
	f: Font = null
) -> void:
	var fnt := f if f != null else font()
	var w := fnt.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	text(
		ci,
		Vector2(center.x - w * 0.5, center.y),
		s,
		size,
		col,
		outline,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		fnt
	)


static func key_pill(
	ci: CanvasItem, center: Vector2, label: String, size := 22.0, dim := false
) -> void:
	if label == "":
		return
	var fs := int(size * 0.62)
	var w := maxf(size, text_width(label, fs) + size * 0.5)
	var r := Rect2(center - Vector2(w, size) * 0.5, Vector2(w, size))
	rounded(ci, Rect2(r.position + Vector2(0, 2), r.size), Color(0, 0, 0, 0.45), size * 0.22)
	rounded(
		ci, r, Color(0.92, 0.93, 0.96, 0.55 if dim else 0.95), size * 0.22, 1.0, Color(1, 1, 1, 0.9)
	)
	var tw := text_width(label, fs)
	ci.draw_string(
		font(),
		Vector2(center.x - tw * 0.5, center.y + fs * 0.36),
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		fs,
		COL_INK
	)


static func type_pill(
	ci: CanvasItem, pos: Vector2, type_name: String, col: Color, fs := 11
) -> float:
	var label := type_name.to_upper()
	var w := text_width(label, fs) + 12.0
	var h := fs + 6.0
	rounded(ci, Rect2(pos, Vector2(w, h)), col.darkened(0.15), h * 0.5, 1.0, col.lightened(0.35))
	ci.draw_string(
		font(), pos + Vector2(6, h - 4.5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, COL_WHITE
	)
	return w


static func type_pill_width(type_name: String, fs := 11) -> float:
	return text_width(type_name.to_upper(), fs) + 12.0


static func status_pill(ci: CanvasItem, pos: Vector2, status: String, fs := 12) -> float:
	if not STATUS_TAGS.has(status):
		return 0.0
	var t: Array = STATUS_TAGS[status]
	var w := text_width(t[0], fs) + 12.0
	var h := fs + 6.0
	rounded(ci, Rect2(pos, Vector2(w, h)), t[1], 4)
	ci.draw_string(
		font(), pos + Vector2(6, h - 4.5), t[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, COL_WHITE
	)
	return w


static func status_pill_width(status: String, fs := 12) -> float:
	return text_width(STATUS_TAGS[status][0], fs) + 12.0 if STATUS_TAGS.has(status) else 0.0


static func bar(
	ci: CanvasItem,
	r: Rect2,
	fill: float,
	col: Color,
	ghost := -1.0,
	ghost_col := Color(1, 1, 1, 0.75),
	rtl := false,
	track := TRACK
) -> void:
	var rad := r.size.y * 0.5
	rounded(ci, r.grow(1.5), Color(0, 0, 0, 0.6), rad + 1.5)
	rounded(ci, r, track, rad)
	if ghost > fill:
		_fill(ci, r, ghost, ghost_col, rad, rtl)
	if fill > 0.0:
		_fill(ci, r, fill, col, rad, rtl)
		_fill(
			ci,
			Rect2(r.position, Vector2(r.size.x, r.size.y * 0.42)),
			fill,
			Color(1, 1, 1, 0.22),
			rad * 0.5,
			rtl
		)


static func _fill(ci: CanvasItem, r: Rect2, f: float, col: Color, rad: float, rtl := false) -> void:
	var w := maxf(r.size.x * clampf(f, 0.0, 1.0), rad * 2.0 if f > 0.0 else 0.0)
	var x := r.position.x + (r.size.x - w if rtl else 0.0)
	rounded(ci, Rect2(Vector2(x, r.position.y), Vector2(w, r.size.y)), col, rad)


## Chips de estágio (ATK▲▲, DEF▼...). `stages` = {atk: int, ...}; evasion > 0 mostra EVA.
static func mod_chips(
	ci: CanvasItem, pos: Vector2, stages: Dictionary, evasion: bool, fs := 10, max_x := INF
) -> float:
	var x := pos.x
	var chips: Array = []
	for k in STAGE_ORDER:
		var s: int = int(stages.get(k, 0))
		if s != 0:
			chips.append([STAGE_SHORT[k], s])
	if evasion:
		chips.append(["EVA", 1])
	var h := fs + 6.0
	for c in chips:
		var label: String = c[0]
		var s: int = c[1]
		var n := absi(s)
		var tri := fs * 0.62
		var w := text_width(label, fs) + 10.0 + n * (tri + 1.5) + 2.0
		if x + w > max_x:
			break
		var col := COL_BUFF if s > 0 else COL_DEBUFF
		rounded(
			ci,
			Rect2(Vector2(x, pos.y), Vector2(w, h)),
			col.darkened(0.25),
			4,
			1.0,
			col.lightened(0.3)
		)
		ci.draw_string(
			font(),
			Vector2(x + 5, pos.y + h - 4.5),
			label,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			fs,
			COL_WHITE
		)
		var tx := x + 7.0 + text_width(label, fs)
		var cy := pos.y + h * 0.5
		for i in n:
			var p := Vector2(tx + i * (tri + 1.5), cy)
			var pts := (
				PackedVector2Array(
					[
						p + Vector2(0, tri * 0.45),
						p + Vector2(tri, tri * 0.45),
						p + Vector2(tri * 0.5, -tri * 0.45)
					]
				)
				if s > 0
				else PackedVector2Array(
					[
						p + Vector2(0, -tri * 0.45),
						p + Vector2(tri, -tri * 0.45),
						p + Vector2(tri * 0.5, tri * 0.45)
					]
				)
			)
			ci.draw_colored_polygon(pts, COL_WHITE)
		x += w + 4.0
	return x - pos.x


## Ícone de Poké Ball desenhado (top = cor da metade de cima).
static func ball(
	ci: CanvasItem, c: Vector2, r: float, top := Color(0.89, 0.21, 0.17), dim := false
) -> void:
	var white := Color(0.96, 0.96, 0.94) if not dim else Color(0.55, 0.55, 0.58)
	if dim:
		top = DIM.darkened(0.3)
	ci.draw_circle(c + Vector2(0, 1.5), r, Color(0, 0, 0, 0.6))
	ci.draw_circle(c, r, white)
	var half := PackedVector2Array([c + Vector2(-r, 0)])
	for i in 13:
		var a := PI + PI * i / 12.0
		half.append(c + Vector2(cos(a), sin(a)) * r)
	half.append(c + Vector2(r, 0))
	ci.draw_colored_polygon(half, top)
	var bh := r * 0.3
	ci.draw_rect(Rect2(c.x - r, c.y - bh * 0.5, r * 2.0, bh), Color(0.08, 0.08, 0.09))
	ci.draw_circle(c, r * 0.32, Color(0.08, 0.08, 0.09))
	ci.draw_circle(c, r * 0.18, Color(0.97, 0.97, 0.97))
	ci.draw_arc(c, r, 0.0, TAU, 24, Color(0.08, 0.08, 0.09), 1.2, true)

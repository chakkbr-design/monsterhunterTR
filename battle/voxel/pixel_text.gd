class_name PixelText
extends RefCounted
## Tiny 3 x 5 pixel font (uppercase letters, digits and a few signs) drawn into Images: the
## perimeter boards, banners and flags of the training stadium (ArenaStadium). One texel is one
## 1/16 m "detail voxel" on the boards, so the lettering matches the voxel look.

const W := 3
const H := 5
const GLYPHS := {
	"A": ["010", "101", "111", "101", "101"],
	"B": ["110", "101", "110", "101", "110"],
	"C": ["011", "100", "100", "100", "011"],
	"D": ["110", "101", "101", "101", "110"],
	"E": ["111", "100", "110", "100", "111"],
	"F": ["111", "100", "110", "100", "100"],
	"G": ["011", "100", "101", "101", "011"],
	"H": ["101", "101", "111", "101", "101"],
	"I": ["111", "010", "010", "010", "111"],
	"J": ["001", "001", "001", "101", "010"],
	"K": ["101", "101", "110", "101", "101"],
	"L": ["100", "100", "100", "100", "111"],
	"M": ["101", "111", "111", "101", "101"],
	"N": ["110", "101", "101", "101", "101"],
	"O": ["010", "101", "101", "101", "010"],
	"P": ["110", "101", "110", "100", "100"],
	"Q": ["010", "101", "101", "110", "011"],
	"R": ["110", "101", "110", "101", "101"],
	"S": ["011", "100", "010", "001", "110"],
	"T": ["111", "010", "010", "010", "010"],
	"U": ["101", "101", "101", "101", "111"],
	"V": ["101", "101", "101", "101", "010"],
	"W": ["101", "101", "111", "111", "101"],
	"X": ["101", "101", "010", "101", "101"],
	"Y": ["101", "101", "010", "010", "010"],
	"Z": ["111", "001", "010", "100", "111"],
	"0": ["111", "101", "101", "101", "111"],
	"1": ["010", "110", "010", "010", "111"],
	"2": ["110", "001", "010", "100", "111"],
	"3": ["110", "001", "010", "001", "110"],
	"4": ["101", "101", "111", "001", "001"],
	"5": ["111", "100", "110", "001", "110"],
	"6": ["011", "100", "111", "101", "111"],
	"7": ["111", "001", "010", "010", "010"],
	"8": ["111", "101", "111", "101", "111"],
	"9": ["111", "101", "111", "001", "110"],
	".": ["000", "000", "000", "000", "010"],
	"!": ["010", "010", "010", "000", "010"],
	"-": ["000", "000", "111", "000", "000"],
	"+": ["000", "010", "111", "010", "000"],
	":": ["000", "010", "000", "010", "000"],
	"'": ["010", "010", "000", "000", "000"],
	" ": ["000", "000", "000", "000", "000"],
}


## Width in pixels of `text` at `scale` (1 px between letters).
static func width(text: String, scale := 1) -> int:
	return maxi(0, text.length() * (W + 1) - 1) * scale


## Draws `text` with its top-left at (x, y); unknown characters are skipped as spaces.
static func draw(img: Image, text: String, x: int, y: int, col: Color, scale := 1) -> void:
	var cx := x
	for ch in text.to_upper():
		var rows: Array = GLYPHS.get(_plain(ch), GLYPHS[" "])
		for r in H:
			var row: String = rows[r]
			for c in W:
				if row[c] != "1":
					continue
				for sy in scale:
					for sx in scale:
						var px := cx + c * scale + sx
						var py := y + r * scale + sy
						if px >= 0 and py >= 0 and px < img.get_width() and py < img.get_height():
							img.set_pixel(px, py, col)
		cx += (W + 1) * scale


## Draws `text` centred horizontally in [x0, x1) with its top at y.
static func draw_centred(
	img: Image, text: String, x0: int, x1: int, y: int, col: Color, scale := 1
) -> void:
	draw(img, text, x0 + (x1 - x0 - width(text, scale)) / 2, y, col, scale)


## Accented letters drawn as their plain form (the font has no accents).
static func _plain(ch: String) -> String:
	var from := "ÁÀÂÃÄÉÊÈÍÎÓÔÕÖÚÜÇ"
	var to := "AAAAAEEEIIOOOOUUC"
	var i := from.find(ch)
	return to[i] if i >= 0 else ch

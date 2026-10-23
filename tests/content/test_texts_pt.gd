extends SceneTree
## Textos dos mapas e dos treinadores em português: nenhuma palavra inglesa comum nas falas de NPCs,
## placas, portas e treinadores (heurística por lista de palavras). Também confere que os ids continuam.
## godot --headless --path . --script res://tests/content/test_texts_pt.gd

## Palavras que só existem em inglês (nada que também seja português, como "a", "me", "no", "do").
const ENGLISH := [
	"the",
	"you",
	"your",
	"you're",
	"i'm",
	"don't",
	"can't",
	"won't",
	"it's",
	"that's",
	"with",
	"and",
	"this",
	"that",
	"is",
	"are",
	"have",
	"has",
	"what",
	"there",
	"here",
	"my",
	"of",
	"to",
	"it",
	"be",
	"for",
	"not",
	"just",
	"if",
	"get",
	"was",
	"were",
	"will",
	"would",
	"i",
	"from",
	"at",
	"by",
	"an",
	"or",
	"out",
	"up",
	"let's",
	"they",
	"we",
	"he",
	"she",
	"his",
	"her",
	"go",
	"come",
	"back",
	"ahead",
	"city",
	"town",
	"route",
	"sign",
	"center",
	"house",
	"welcome",
	"trainer",
	"tips",
	"gym",
	"leader",
	"badge"
]
const TEXT_KEYS := [
	"lines", "intro", "defeat", "after", "lose", "badge_speech", "gift_speech", "gate_line"
]

var _fails := 0
var _hits: Array = []
var _count := 0


func _initialize() -> void:
	var re := RegEx.new()
	re.compile("[a-zà-ÿ']+")
	var maps := DirAccess.get_files_at("res://data/maps")
	for f in maps:
		if not f.ends_with(".json") or f.begins_with("mt_moon"):
			continue
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/" + f))
		_text(re, f + ":name", d.get("name", ""))
		for n in d.get("npcs", []):
			_text(re, "%s:npc %s" % [f, n.get("node", "")], n.get("name", ""))
			_lines(re, "%s:npc %s" % [f, n.get("node", "")], n.get("lines", []))
		for s in d.get("signs", []):
			_text(re, "%s:sign %s" % [f, s.get("name", "")], s.get("title", ""))
			_lines(re, "%s:sign %s" % [f, s.get("name", "")], s.get("lines", []))
		for b in d.get("buildings", []):
			var m: Dictionary = b.get("message", {})
			_text(re, "%s:building %s" % [f, b.get("id", "")], m.get("title", ""))
			_lines(re, "%s:building %s" % [f, b.get("id", "")], m.get("lines", []))
			_text(re, "%s:board %s" % [f, b.get("id", "")], b.get("board", {}).get("text", ""))
	var t = JSON.parse_string(FileAccess.get_file_as_string("res://data/trainers.json"))
	for id in t:
		if id == "_doc":
			continue
		for k in TEXT_KEYS:
			_lines(re, "trainers:%s.%s" % [id, k], t[id].get(k, []))
		_text(re, "trainers:%s.display_name" % id, t[id].get("display_name", ""))
	check(_count > 300, "textos verificados (%d)" % _count)
	for h in _hits.slice(0, 30):
		print("  inglês? ", h)
	check(_hits.is_empty(), "nenhuma palavra inglesa nos textos (%d suspeitos)" % _hits.size())
	check(
		(
			t.has("rocket_1")
			and t.has("super_nerd_miguel")
			and t.rocket_1.get("display_name", "") == "Recruta da Equipe Rocket"
		),
		"ids dos treinadores mantidos"
	)
	check(
		int(t.super_nerd_miguel.get("sight", -1)) == 0,
		"Miguel só luta pela cena dos fósseis (sight 0)"
	)
	print("PASSOU (0 falhas)" if _fails == 0 else "FALHOU (%d falhas)" % _fails)
	quit(1 if _fails > 0 else 0)


func check(cond: bool, what: String) -> void:
	print(("ok   " if cond else "FAIL ") + what)
	if not cond:
		_fails += 1


func _lines(re: RegEx, where: String, a) -> void:
	if a is Array:
		for l in a:
			_text(re, where, l)


func _text(re: RegEx, where: String, s) -> void:
	if not s is String or s == "":
		return
	_count += 1
	for m in re.search_all(String(s).to_lower().replace("pokémon", "").replace("poké", "")):
		if ENGLISH.has(m.get_string()):
			_hits.append('%s: "%s" (%s)' % [where, String(s).replace("\n", " "), m.get_string()])
			return

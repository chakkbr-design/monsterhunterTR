extends SceneTree
## Map and trainer texts are English: no common Portuguese word and no accented letter (other than
## the é of Pokémon / Poké) in NPC lines, signs, doors and trainer lines (word-list heuristic). Also
## checks that the ids are kept.
## godot --headless --path . --script res://tests/content/test_texts_en.gd

## Words that only exist in Portuguese (nothing that is also English).
const PORTUGUESE := [
	"você",
	"voce",
	"não",
	"nao",
	"uma",
	"para",
	"seu",
	"sua",
	"seus",
	"suas",
	"está",
	"muito",
	"ainda",
	"mais",
	"aqui",
	"porque",
	"pelo",
	"pela",
	"dos",
	"das",
	"ele",
	"ela",
	"vai",
	"isso",
	"esse",
	"essa",
	"aquele",
	"quando",
	"então",
	"também",
	"onde",
	"são",
	"das",
	"ei",
	"olá",
	"obrigado",
	"cidade",
	"rota",
	"placa",
	"treinador",
	"treinadores",
	"batalha",
	"golpe",
	"golpes",
	"líder",
	"insígnia",
	"ginásio",
	"vamos",
	"vencer",
	"fique",
	"venha",
	"cuidado",
	"meu",
	"minha",
	"meus",
	"nós",
	"vocês",
	"deixe",
	"leve",
	"pegue",
	"tenho",
	"estou",
	"posso",
	"preciso",
	"queria",
	"quero",
	"fazer",
	"depois",
	"antes",
	"sempre",
	"nunca",
	"agora",
	"hoje",
	"lá",
	"além",
	"mamãe",
	"vovô"
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
	check(_count > 300, "texts checked (%d)" % _count)
	for h in _hits.slice(0, 30):
		print("  Portuguese? ", h)
	check(_hits.is_empty(), "no Portuguese word in the texts (%d suspects)" % _hits.size())
	check(
		(
			t.has("rocket_1")
			and t.has("super_nerd_miguel")
			and t.rocket_1.get("display_name", "") == "Team Rocket Grunt"
		),
		"trainer ids kept"
	)
	check(
		int(t.super_nerd_miguel.get("sight", -1)) == 0,
		"Miguel only fights through the fossil scene (sight 0)"
	)
	print("PASSED (0 failures)" if _fails == 0 else "FAILED (%d failures)" % _fails)
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
	var low := String(s).to_lower().replace("pokémon", "").replace("pokédex", "").replace(
		"poké", ""
	)
	for m in re.search_all(low):
		var w := m.get_string()
		if PORTUGUESE.has(w) or w.length() != w.to_utf8_buffer().size():
			_hits.append('%s: "%s" (%s)' % [where, String(s).replace("\n", " "), w])
			return

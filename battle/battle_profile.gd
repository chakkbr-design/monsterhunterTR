class_name BattleProfile
extends RefCounted
## Perfil de movimento da Batalha Viva: sai sozinho dos stats e golpes do Mon, com correção opcional por
## espécie (data/battle_profiles.json), puxado pela Natureza e pela habilidade.
## brawler (Brigão), shooter (Atirador), skirmisher (Escaramuçador), wall (Muralha),
## trickster (Trapaceiro), flyer (Voador).

const PATH := "res://data/battle_profiles.json"
const NAMES := {
	"brawler": "Brawler",
	"shooter": "Shooter",
	"skirmisher": "Skirmisher",
	"wall": "Wall",
	"trickster": "Trickster",
	"flyer": "Flyer",
}
## band: distância preferida sem golpe em mente; retreat: s recuando depois de bater (e até onde);
## strafe: quanto anda de lado; dodge: chance de reagir a golpe avisado; think: ritmo de decisão;
## fly: altura de voo; guard: protege o parceiro; sprint: vontade de correr para fechar distância.
const PARAMS := {
	"brawler":
	{
		"band": Vector2(0.9, 1.8),
		"retreat": 0.25,
		"retreat_to": 2.0,
		"strafe": 0.35,
		"dodge": 0.45,
		"think": 0.9,
		"fly": 0.0,
		"guard": false,
		"sprint": 1.0
	},
	"shooter":
	{
		"band": Vector2(5.0, 7.0),
		"retreat": 0.8,
		"retreat_to": 6.0,
		"strafe": 0.6,
		"dodge": 0.7,
		"think": 1.0,
		"fly": 0.0,
		"guard": false,
		"sprint": 0.5
	},
	"skirmisher":
	{
		"band": Vector2(3.0, 4.5),
		"retreat": 0.9,
		"retreat_to": 4.5,
		"strafe": 0.8,
		"dodge": 0.8,
		"think": 0.85,
		"fly": 0.0,
		"guard": false,
		"sprint": 1.0
	},
	"wall":
	{
		"band": Vector2(1.8, 3.2),
		"retreat": 0.0,
		"retreat_to": 2.5,
		"strafe": 0.2,
		"dodge": 0.25,
		"think": 1.1,
		"fly": 0.0,
		"guard": true,
		"sprint": 0.3
	},
	"trickster":
	{
		"band": Vector2(3.5, 5.0),
		"retreat": 0.6,
		"retreat_to": 4.5,
		"strafe": 1.0,
		"dodge": 0.65,
		"think": 0.95,
		"fly": 0.0,
		"guard": false,
		"sprint": 0.6
	},
	"flyer":
	{
		"band": Vector2(2.5, 4.5),
		"retreat": 0.7,
		"retreat_to": 4.0,
		"strafe": 0.9,
		"dodge": 0.6,
		"think": 0.9,
		"fly": 1.3,
		"guard": false,
		"sprint": 0.8
	},
}
const CONTACT_KINDS := ["dash", "arc", "multi_arc", "lunge"]
const RANGED_KINDS := ["projectile", "homing", "beam", "stream", "aoe_target", "zone", "whip"]
## Natureza que sobe o stat puxa o perfil: Speed -> Escaramuçador, Ataque -> Brigão etc.
const NATURE_PULL := {
	"spe": "skirmisher", "atk": "brawler", "def": "wall", "spa": "shooter", "spd": "trickster"
}
## Temperamento pela Natureza (Fúria x Pânico com HP baixo): + agressivo, - medroso.
const TEMPER := {
	"lonely": 1,
	"brave": 1,
	"adamant": 1,
	"naughty": 1,
	"hasty": 1,
	"rash": 1,
	"timid": -1,
	"bold": -1,
	"modest": -1,
	"calm": -1,
	"gentle": -1,
	"careful": -1,
	"relaxed": -1,
}

static var _overrides := {}
static var _loaded := false


static func overrides() -> Dictionary:
	if not _loaded:
		_loaded = true
		if FileAccess.file_exists(PATH):
			var d = JSON.parse_string(FileAccess.get_file_as_string(PATH))
			if d is Dictionary:
				_overrides = d
	return _overrides


static func params(name: String) -> Dictionary:
	return PARAMS.get(name, PARAMS.brawler)


static func display(name: String) -> String:
	return String(NAMES.get(name, name))


## Pontos de cada perfil (o maior ganha). bias: perfil puxado pela habilidade ("" = nenhum).
static func scores(m: Mon, move_ids: Array, bias := "") -> Dictionary:
	var sp := Dex.species(m.species)
	var b: Dictionary = sp.get("base", {})
	var atk := float(b.get("atk", 50))
	var spa := float(b.get("spa", 50))
	var bulk := (float(b.get("def", 50)) + float(b.get("spd", 50)) + float(b.get("hp", 50))) / 3.0
	var spe := float(b.get("spe", 50))
	var avg := (atk + spa + bulk + spe) / 4.0
	var contact := 0
	var ranged := 0
	var status := 0
	for id in move_ids:
		var mv := Dex.move(String(id))
		var k := String(mv.get("kind", ""))
		if float(mv.get("power", 0)) <= 0.0:
			status += 1
		elif k in CONTACT_KINDS:
			contact += 1
		elif k in RANGED_KINDS:
			ranged += 1
	var s := {
		"brawler": contact * 1.0 + (atk - spa) / 25.0,
		"shooter": ranged * 1.0 + (spa - atk) / 25.0,
		"skirmisher": (spe - avg) / 12.0,
		"wall": (bulk - avg) / 12.0 - maxf(spe - avg, 0.0) / 20.0,
		"trickster": status * 0.8 - 0.6,
		"flyer": -9.0,
	}
	var loco := String(sp.get("locomotion", "ground"))
	if loco == "fly" or ("flying" in m.types and loco != "ground"):
		s.flyer = 9.0
	var nat: Array = StatCalc.NATURES.get(m.nature, [])
	if nat.size() == 2 and NATURE_PULL.has(nat[0]):
		s[NATURE_PULL[nat[0]]] += 0.8
	if s.has(bias):
		s[bias] += 1.2
	return s


static func pick(m: Mon, move_ids: Array, bias := "") -> String:
	var o = overrides().get(m.species)
	if o is String and PARAMS.has(o):
		return o
	var s := scores(m, move_ids, bias)
	var best := "brawler"
	for k in s:
		if float(s[k]) > float(s[best]):
			best = k
	return best


static func temper(m: Mon) -> int:
	return int(TEMPER.get(m.nature, 0))

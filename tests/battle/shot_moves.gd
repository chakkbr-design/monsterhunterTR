extends SceneTree
## Capturas dos efeitos de golpe (render de verdade, NÃO headless):
##   godot --path . --script res://tests/battle/shot_moves.gd --resolution 960x540 -- \
##     moves=ember,thunder out=C:/pasta [sheet=1] [single=1]
## sheet=1 (padrão): uma folha PNG por 4 golpes, cada linha = 3 momentos do golpe.
## single=1: um PNG em tela cheia por golpe (no momento do meio), para docs/screens.
## Golpes que ainda não estão no moves.json usam um kind provisório (GUESS) só para a captura.

const ARENA := "res://battle/battle_arena.tscn"
const DT := 1.0 / 60.0
const TILE := Vector2i(400, 250)
## Golpes novos (Gen 9) ainda sem entrada no moves.json deste branch (cópia do gen9-golpes):
## [tipo, kind, categoria, poder, extras].
const GUESS := {
	"acid_spray":
	[
		"poison",
		"projectile",
		"special",
		40,
		{
			"range": 9,
			"speed": 13,
			"knockback": 2,
			"fx": "lob",
			"lob_height": 1.6,
			"effect": {"stat": "spd", "stages": -2, "chance": 1.0},
			"uses": 20,
			"accuracy": 100,
			"bp": 40
		}
	],
	"after_you": ["normal", "self_buff", "status", 0, {"special": "after_you", "uses": 15}],
	"agility": ["psychic", "self_buff", "status", 0, {"stat": "spe", "stages": 2, "uses": 30}],
	"air_cutter":
	[
		"flying",
		"projectile",
		"special",
		27,
		{
			"range": 10,
			"speed": 16,
			"knockback": 2,
			"count": 3,
			"spread": 40,
			"crit": 1,
			"uses": 25,
			"accuracy": 95,
			"bp": 60,
			"multi_target": "all_opponents"
		}
	],
	"aromatherapy": ["grass", "self_buff", "status", 0, {"special": "aromatherapy", "uses": 5}],
	"assurance":
	[
		"dark",
		"arc",
		"physical",
		60,
		{
			"range": 1.9,
			"knockback": 5,
			"angle": 80,
			"special": "assurance",
			"uses": 10,
			"accuracy": 100,
			"bp": 60
		}
	],
	"belch":
	[
		"poison",
		"stream",
		"special",
		40,
		{
			"range": 3.5,
			"knockback": 4,
			"angle": 60,
			"duration": 0.6,
			"tick": 0.15,
			"special": "belch",
			"uses": 10,
			"accuracy": 90,
			"bp": 120
		}
	],
	"bug_bite":
	[
		"bug",
		"arc",
		"physical",
		60,
		{
			"range": 1.9,
			"knockback": 5,
			"angle": 80,
			"special": "pluck",
			"uses": 20,
			"accuracy": 100,
			"bp": 60
		}
	],
	"bulldoze":
	[
		"ground",
		"aoe_self",
		"physical",
		60,
		{
			"knockback": 6,
			"windup": 0.35,
			"radius": 4.0,
			"slam": true,
			"effect": {"stat": "spe", "stages": -1, "chance": 1.0},
			"uses": 20,
			"accuracy": 100,
			"bp": 60,
			"multi_target": "all_other_pokemon"
		}
	],
	"charm":
	[
		"fairy",
		"debuff_aoe",
		"status",
		0,
		{"radius": 6.0, "stat": "atk", "stages": -2, "uses": 20, "accuracy": 100}
	],
	"coil":
	[
		"poison",
		"self_buff",
		"status",
		0,
		{"stat": "atk", "stages": 1, "stats": {"atk": 1, "def": 1, "acc": 1}, "uses": 20}
	],
	"confuse_ray":
	[
		"ghost",
		"projectile",
		"status",
		0,
		{
			"range": 9,
			"speed": 11,
			"knockback": 0,
			"effect": {"status": "confusion", "chance": 1.0},
			"fx": "rings",
			"uses": 10,
			"accuracy": 100
		}
	],
	"copycat": ["normal", "self_buff", "status", 0, {"special": "copycat", "uses": 20}],
	"cosmic_power":
	[
		"psychic",
		"self_buff",
		"status",
		0,
		{"stat": "def", "stages": 1, "stats": {"def": 1, "spd": 1}, "uses": 20}
	],
	"covet":
	[
		"normal",
		"dash",
		"physical",
		60,
		{
			"allowed_midair": false,
			"range": 3.5,
			"speed": 14,
			"knockback": 5,
			"special": "covet",
			"uses": 25,
			"accuracy": 100,
			"bp": 60
		}
	],
	"cross_poison":
	[
		"poison",
		"arc",
		"physical",
		70,
		{
			"range": 2.0,
			"knockback": 6,
			"angle": 90,
			"crit": 1,
			"effect": {"status": "poison", "chance": 0.1},
			"uses": 20,
			"accuracy": 100,
			"bp": 70
		}
	],
	"disarming_voice":
	[
		"fairy",
		"stream",
		"special",
		40,
		{
			"range": 5.0,
			"knockback": 3,
			"angle": 80,
			"duration": 0.5,
			"tick": 0.15,
			"once": true,
			"fx": "rings",
			"uses": 15,
			"bp": 40,
			"multi_target": "all_opponents"
		}
	],
	"discharge":
	[
		"electric",
		"aoe_self",
		"special",
		80,
		{
			"knockback": 5,
			"windup": 0.3,
			"radius": 3.5,
			"effect": {"status": "paralysis", "chance": 0.3},
			"uses": 15,
			"accuracy": 100,
			"bp": 80,
			"multi_target": "all_other_pokemon"
		}
	],
	"double_edge":
	[
		"normal",
		"dash",
		"physical",
		120,
		{
			"allowed_midair": false,
			"range": 8.0,
			"speed": 18,
			"knockback": 10,
			"recoil": 0.33,
			"uses": 15,
			"accuracy": 100,
			"bp": 120
		}
	],
	"echoed_voice":
	[
		"normal",
		"stream",
		"special",
		40,
		{
			"range": 5.0,
			"knockback": 3,
			"angle": 60,
			"duration": 0.5,
			"tick": 0.15,
			"once": true,
			"fx": "rings",
			"special": "echoed_voice",
			"uses": 15,
			"accuracy": 100,
			"bp": 40
		}
	],
	"endeavor":
	[
		"normal",
		"arc",
		"physical",
		1,
		{
			"range": 1.9,
			"knockback": 4,
			"angle": 90,
			"special": "endeavor",
			"uses": 5,
			"accuracy": 100
		}
	],
	"extrasensory":
	[
		"psychic",
		"aoe_target",
		"special",
		80,
		{
			"range": 8,
			"knockback": 3,
			"windup": 0.5,
			"radius": 1.4,
			"effect": {"status": "flinch", "chance": 0.1},
			"fx": "psy_rings",
			"uses": 20,
			"accuracy": 100,
			"bp": 80
		}
	],
	"feather_dance":
	[
		"flying",
		"debuff_aoe",
		"status",
		0,
		{"radius": 6.0, "stat": "atk", "stages": -2, "uses": 15, "accuracy": 100}
	],
	"feint":
	[
		"normal",
		"dash",
		"physical",
		30,
		{
			"allowed_midair": false,
			"range": 6.0,
			"speed": 15,
			"knockback": 4,
			"windup": 0.05,
			"special": "feint",
			"uses": 10,
			"accuracy": 100,
			"bp": 30,
			"priority": 2
		}
	],
	"fell_stinger":
	[
		"bug",
		"arc",
		"physical",
		50,
		{
			"range": 1.9,
			"knockback": 4,
			"angle": 50,
			"special": "fell_stinger",
			"uses": 25,
			"accuracy": 100,
			"bp": 50
		}
	],
	"fire_spin":
	[
		"fire",
		"zone",
		"special",
		12,
		{
			"range": 8,
			"knockback": 0,
			"duration": 2.5,
			"tick": 0.5,
			"radius": 1.6,
			"trap": 0.6,
			"uses": 15,
			"accuracy": 85,
			"bp": 35
		}
	],
	"fissure":
	[
		"ground",
		"aoe_target",
		"physical",
		1,
		{
			"range": 8,
			"knockback": 6,
			"windup": 0.9,
			"radius": 1.3,
			"fx": "quake",
			"special": "ohko",
			"uses": 5,
			"accuracy": 30
		}
	],
	"flare_blitz":
	[
		"fire",
		"dash",
		"physical",
		120,
		{
			"allowed_midair": false,
			"range": 8.0,
			"speed": 18,
			"knockback": 10,
			"recoil": 0.33,
			"effect": {"status": "burn", "chance": 0.1},
			"uses": 15,
			"accuracy": 100,
			"bp": 120
		}
	],
	"flash_cannon":
	[
		"steel",
		"beam",
		"special",
		80,
		{
			"range": 12,
			"knockback": 4,
			"windup": 0.45,
			"width": 0.7,
			"root": 0.5,
			"effect": {"stat": "spd", "stages": -1, "chance": 0.1},
			"uses": 10,
			"accuracy": 100,
			"bp": 80
		}
	],
	"flatter":
	[
		"dark",
		"projectile",
		"status",
		0,
		{
			"range": 9,
			"speed": 11,
			"knockback": 0,
			"effect": {"status": "confusion", "chance": 1.0},
			"special": "flatter",
			"fx": "rings",
			"uses": 15,
			"accuracy": 100
		}
	],
	"follow_me":
	["normal", "self_buff", "status", 0, {"special": "follow_me", "uses": 20, "priority": 2}],
	"fury_cutter":
	[
		"bug",
		"arc",
		"physical",
		40,
		{
			"range": 1.9,
			"knockback": 3,
			"angle": 90,
			"chain": 2,
			"special": "chain",
			"uses": 20,
			"accuracy": 95,
			"bp": 40
		}
	],
	"gastro_acid":
	[
		"poison",
		"projectile",
		"status",
		0,
		{
			"range": 9,
			"speed": 12,
			"knockback": 0,
			"fx": "lob",
			"lob_height": 1.4,
			"special": "gastro_acid",
			"uses": 10,
			"accuracy": 100
		}
	],
	"giga_drain":
	[
		"grass",
		"projectile",
		"special",
		75,
		{
			"range": 9,
			"speed": 16,
			"knockback": 2,
			"drain": 0.5,
			"turn": 2.0,
			"uses": 10,
			"accuracy": 100,
			"bp": 75
		}
	],
	"grassy_terrain":
	["grass", "self_buff", "status", 0, {"special": "grassy_terrain", "uses": 10}],
	"gravity": ["psychic", "self_buff", "status", 0, {"special": "gravity", "uses": 5}],
	"gunk_shot":
	[
		"poison",
		"projectile",
		"physical",
		120,
		{
			"range": 10,
			"speed": 14,
			"knockback": 7,
			"fx": "lob",
			"lob_height": 2.4,
			"effect": {"status": "poison", "chance": 0.3},
			"uses": 5,
			"accuracy": 80,
			"bp": 120
		}
	],
	"gyro_ball":
	[
		"steel",
		"dash",
		"physical",
		60,
		{
			"allowed_midair": false,
			"range": 6.5,
			"speed": 16,
			"knockback": 7,
			"special": "gyro_ball",
			"uses": 5,
			"accuracy": 100
		}
	],
	"haze": ["ice", "self_buff", "status", 0, {"special": "haze", "uses": 30}],
	"healing_wish": ["psychic", "self_buff", "status", 0, {"special": "healing_wish", "uses": 10}],
	"hyper_voice":
	[
		"normal",
		"stream",
		"special",
		90,
		{
			"range": 5.5,
			"knockback": 5,
			"angle": 80,
			"duration": 0.6,
			"tick": 0.15,
			"once": true,
			"fx": "rings",
			"uses": 10,
			"accuracy": 100,
			"bp": 90,
			"multi_target": "all_opponents"
		}
	],
	"ice_fang":
	[
		"ice",
		"arc",
		"physical",
		65,
		{
			"range": 1.9,
			"knockback": 5,
			"angle": 80,
			"effect": {"status": "freeze", "chance": 0.1},
			"flinch": 0.1,
			"uses": 15,
			"accuracy": 95,
			"bp": 65
		}
	],
	"imprison": ["psychic", "self_buff", "status", 0, {"special": "imprison", "uses": 10}],
	"incinerate":
	[
		"fire",
		"stream",
		"special",
		20,
		{
			"range": 5.0,
			"knockback": 2,
			"angle": 60,
			"duration": 0.6,
			"tick": 0.15,
			"special": "incinerate",
			"uses": 15,
			"accuracy": 100,
			"bp": 60,
			"multi_target": "all_opponents"
		}
	],
	"inferno":
	[
		"fire",
		"projectile",
		"special",
		100,
		{
			"range": 11,
			"speed": 11,
			"knockback": 6,
			"effect": {"status": "burn", "chance": 1.0},
			"uses": 5,
			"accuracy": 50,
			"bp": 100
		}
	],
	"iron_defense": ["steel", "self_buff", "status", 0, {"stat": "def", "stages": 2, "uses": 15}],
	"laser_focus": ["normal", "self_buff", "status", 0, {"special": "laser_focus", "uses": 30}],
	"life_dew": ["water", "self_buff", "status", 0, {"special": "life_dew", "uses": 10}],
	"light_screen": ["psychic", "self_buff", "status", 0, {"special": "light_screen", "uses": 30}],
	"mean_look":
	[
		"normal",
		"projectile",
		"status",
		0,
		{"range": 9, "speed": 14, "knockback": 0, "special": "mean_look", "uses": 5}
	],
	"meteor_mash":
	[
		"steel",
		"dash",
		"physical",
		90,
		{
			"allowed_midair": false,
			"range": 7.0,
			"speed": 17,
			"knockback": 8,
			"effect": {"stat": "atk", "stages": 1, "chance": 0.2, "self": true},
			"uses": 10,
			"accuracy": 90,
			"bp": 90
		}
	],
	"metronome": ["normal", "self_buff", "status", 0, {"special": "metronome", "uses": 10}],
	"mimic": ["normal", "self_buff", "status", 0, {"special": "mimic", "uses": 10}],
	"moonblast":
	[
		"fairy",
		"projectile",
		"special",
		95,
		{
			"range": 12,
			"speed": 13,
			"knockback": 5,
			"effect": {"stat": "spa", "stages": -1, "chance": 0.3},
			"uses": 15,
			"accuracy": 100,
			"bp": 95
		}
	],
	"moonlight":
	["fairy", "self_buff", "status", 0, {"special": "heal_weather", "heal": 0.5, "uses": 5}],
	"nasty_plot": ["dark", "self_buff", "status", 0, {"stat": "spa", "stages": 2, "uses": 20}],
	"night_slash":
	[
		"dark",
		"arc",
		"physical",
		70,
		{
			"range": 2.0,
			"knockback": 6,
			"angle": 90,
			"crit": 1,
			"uses": 15,
			"accuracy": 100,
			"bp": 70
		}
	],
	"nuzzle":
	[
		"electric",
		"dash",
		"physical",
		20,
		{
			"allowed_midair": false,
			"range": 3.5,
			"speed": 13,
			"knockback": 3,
			"effect": {"status": "paralysis", "chance": 1.0},
			"uses": 20,
			"accuracy": 100,
			"bp": 20
		}
	],
	"petal_blizzard":
	[
		"grass",
		"aoe_self",
		"physical",
		90,
		{
			"knockback": 5,
			"windup": 0.3,
			"radius": 3.5,
			"uses": 15,
			"accuracy": 100,
			"bp": 90,
			"multi_target": "all_other_pokemon"
		}
	],
	"play_nice":
	[
		"normal",
		"debuff_aoe",
		"status",
		0,
		{"radius": 6.0, "stat": "atk", "stages": -1, "special": "no_protect", "uses": 20}
	],
	"play_rough":
	[
		"fairy",
		"dash",
		"physical",
		90,
		{
			"allowed_midair": false,
			"range": 6.5,
			"speed": 16,
			"knockback": 8,
			"effect": {"stat": "atk", "stages": -1, "chance": 0.1},
			"uses": 10,
			"accuracy": 90,
			"bp": 90
		}
	],
	"pluck":
	[
		"flying",
		"dash",
		"physical",
		60,
		{
			"allowed_midair": false,
			"range": 2.8,
			"speed": 13,
			"knockback": 4,
			"special": "pluck",
			"uses": 20,
			"accuracy": 100,
			"bp": 60
		}
	],
	"poison_fang":
	[
		"poison",
		"arc",
		"physical",
		50,
		{
			"range": 1.9,
			"knockback": 5,
			"angle": 80,
			"effect": {"status": "toxic", "chance": 0.5},
			"uses": 15,
			"accuracy": 100,
			"bp": 50
		}
	],
	"power_whip":
	[
		"grass",
		"dash",
		"physical",
		120,
		{
			"allowed_midair": false,
			"range": 7.0,
			"speed": 17,
			"knockback": 9,
			"uses": 10,
			"accuracy": 85,
			"bp": 120
		}
	],
	"protect":
	["normal", "self_buff", "status", 0, {"special": "protect", "uses": 10, "priority": 4}],
	"psychic":
	[
		"psychic",
		"aoe_target",
		"special",
		90,
		{
			"range": 9,
			"knockback": 4,
			"windup": 0.55,
			"radius": 1.6,
			"effect": {"stat": "spd", "stages": -1, "chance": 0.1},
			"fx": "psy_rings",
			"uses": 10,
			"accuracy": 100,
			"bp": 90
		}
	],
	"quick_guard":
	["fighting", "self_buff", "status", 0, {"special": "quick_guard", "uses": 15, "priority": 3}],
	"quiver_dance":
	[
		"bug",
		"self_buff",
		"status",
		0,
		{"stat": "spa", "stages": 1, "stats": {"spa": 1, "spd": 1, "spe": 1}, "uses": 20}
	],
	"rage_powder":
	[
		"bug",
		"self_buff",
		"status",
		0,
		{"special": "follow_me", "powder": true, "uses": 20, "priority": 2}
	],
	"rest": ["psychic", "self_buff", "status", 0, {"special": "rest", "uses": 5}],
	"roost": ["flying", "self_buff", "status", 0, {"special": "roost", "heal": 0.5, "uses": 5}],
	"round":
	[
		"normal",
		"stream",
		"special",
		60,
		{
			"range": 5.0,
			"knockback": 3,
			"angle": 50,
			"duration": 0.5,
			"tick": 0.15,
			"once": true,
			"fx": "rings",
			"special": "round",
			"uses": 15,
			"accuracy": 100,
			"bp": 60
		}
	],
	"safeguard": ["normal", "self_buff", "status", 0, {"special": "safeguard", "uses": 25}],
	"sandstorm": ["rock", "self_buff", "status", 0, {"special": "sandstorm", "uses": 10}],
	"shell_smash":
	[
		"normal",
		"self_buff",
		"status",
		0,
		{
			"stat": "atk",
			"stages": 2,
			"stats": {"atk": 2, "spa": 2, "spe": 2, "def": -1, "spd": -1},
			"uses": 15
		}
	],
	"sludge_bomb":
	[
		"poison",
		"projectile",
		"special",
		90,
		{
			"range": 10,
			"speed": 14,
			"knockback": 5,
			"fx": "lob",
			"lob_height": 2.2,
			"effect": {"status": "poison", "chance": 0.3},
			"uses": 10,
			"accuracy": 100,
			"bp": 90
		}
	],
	"spit_up":
	[
		"normal",
		"projectile",
		"special",
		100,
		{
			"range": 10,
			"speed": 14,
			"knockback": 6,
			"special": "spit_up",
			"uses": 10,
			"accuracy": 100
		}
	],
	"spite":
	[
		"ghost",
		"projectile",
		"status",
		0,
		{"range": 9, "speed": 12, "knockback": 0, "special": "spite", "uses": 10, "accuracy": 100}
	],
	"stockpile":
	[
		"normal",
		"self_buff",
		"status",
		0,
		{"stat": "def", "stages": 1, "special": "stockpile", "uses": 20}
	],
	"stored_power":
	[
		"psychic",
		"projectile",
		"special",
		20,
		{
			"range": 10,
			"speed": 14,
			"knockback": 3,
			"special": "stored_power",
			"uses": 10,
			"accuracy": 100,
			"bp": 20
		}
	],
	"superpower":
	[
		"fighting",
		"dash",
		"physical",
		120,
		{
			"allowed_midair": false,
			"range": 7.0,
			"speed": 17,
			"knockback": 11,
			"self_stats": {"atk": -1, "def": -1},
			"uses": 5,
			"accuracy": 100,
			"bp": 120
		}
	],
	"swallow": ["normal", "self_buff", "status", 0, {"special": "swallow", "uses": 10}],
	"sweet_kiss":
	[
		"fairy",
		"projectile",
		"status",
		0,
		{
			"range": 9,
			"speed": 10,
			"knockback": 0,
			"effect": {"status": "confusion", "chance": 1.0},
			"uses": 10,
			"accuracy": 75
		}
	],
	"swords_dance": ["normal", "self_buff", "status", 0, {"stat": "atk", "stages": 2, "uses": 20}],
	"synthesis":
	["grass", "self_buff", "status", 0, {"special": "heal_weather", "heal": 0.5, "uses": 5}],
	"tailwind": ["flying", "self_buff", "status", 0, {"special": "tailwind", "uses": 15}],
	"take_down":
	[
		"normal",
		"dash",
		"physical",
		90,
		{
			"allowed_midair": false,
			"range": 7.0,
			"speed": 17,
			"knockback": 9,
			"recoil": 0.25,
			"uses": 20,
			"accuracy": 85,
			"bp": 90
		}
	],
	"thunder_fang":
	[
		"electric",
		"arc",
		"physical",
		65,
		{
			"range": 1.9,
			"knockback": 5,
			"angle": 80,
			"effect": {"status": "paralysis", "chance": 0.1},
			"flinch": 0.1,
			"uses": 15,
			"accuracy": 95,
			"bp": 65
		}
	],
	"thunder_punch":
	[
		"electric",
		"arc",
		"physical",
		75,
		{
			"range": 1.9,
			"knockback": 6,
			"angle": 80,
			"effect": {"status": "paralysis", "chance": 0.1},
			"uses": 15,
			"accuracy": 100,
			"bp": 75
		}
	],
	"toxic":
	[
		"poison",
		"projectile",
		"status",
		0,
		{
			"range": 9,
			"speed": 12,
			"knockback": 0,
			"fx": "lob",
			"lob_height": 1.4,
			"effect": {"status": "toxic", "chance": 1.0},
			"uses": 10,
			"accuracy": 90
		}
	],
	"toxic_spikes": ["poison", "self_buff", "status", 0, {"special": "toxic_spikes", "uses": 20}],
	"venoshock":
	[
		"poison",
		"projectile",
		"special",
		65,
		{
			"range": 10,
			"speed": 14,
			"knockback": 4,
			"special": "venoshock",
			"uses": 10,
			"accuracy": 100,
			"bp": 65
		}
	],
	"wave_crash":
	[
		"water",
		"dash",
		"physical",
		120,
		{
			"allowed_midair": false,
			"range": 8.0,
			"speed": 19,
			"knockback": 10,
			"recoil": 0.33,
			"uses": 10,
			"accuracy": 100,
			"bp": 120
		}
	],
	"will_o_wisp":
	[
		"fire",
		"projectile",
		"status",
		0,
		{
			"range": 9,
			"speed": 10,
			"knockback": 0,
			"effect": {"status": "burn", "chance": 1.0},
			"uses": 15,
			"accuracy": 85
		}
	],
	"worry_seed":
	[
		"grass",
		"projectile",
		"status",
		0,
		{
			"range": 9,
			"speed": 12,
			"knockback": 0,
			"special": "worry_seed",
			"uses": 10,
			"accuracy": 100
		}
	],
	"x_scissor":
	[
		"bug",
		"arc",
		"physical",
		80,
		{"range": 2.0, "knockback": 6, "angle": 100, "uses": 15, "accuracy": 100, "bp": 80}
	],
	"zen_headbutt":
	[
		"psychic",
		"dash",
		"physical",
		80,
		{
			"allowed_midair": false,
			"range": 6.5,
			"speed": 16,
			"knockback": 8,
			"effect": {"status": "flinch", "chance": 0.2},
			"uses": 15,
			"accuracy": 90,
			"bp": 80
		}
	],
}

var _world: Node3D
var _label: Label
var _args := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := String(a).split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_main.call_deferred()


func _main() -> void:
	await process_frame
	_world = _build_world()
	var cl := CanvasLayer.new()
	cl.layer = 100
	root.add_child(cl)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 26)
	_label.add_theme_color_override("font_color", Color(1, 1, 0.6))
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 8)
	cl.add_child(_label)
	var ids: Array = String(_args.get("moves", "ember")).split(",", false)
	var out := String(_args.get("out", ProjectSettings.globalize_path("user://shots")))
	DirAccess.make_dir_recursive_absolute(out)
	var a := _arena()
	await _steps(a, 3.0)
	var single := _args.has("single")
	var rows: Array = []
	var sheet_n := 0
	for id in ids:
		var mv := _move(String(id))
		if mv.is_empty():
			print("sem golpe: ", id)
			continue
		var imgs := await _shoot(a, mv, single)
		if single:
			imgs[0].save_png(out.path_join(String(id) + ".png"))
			print("salvo ", out.path_join(String(id) + ".png"))
			continue
		rows.append(imgs)
		if rows.size() == 4:
			_save_sheet(rows, out.path_join("sheet_%02d.png" % sheet_n))
			sheet_n += 1
			rows.clear()
	if not rows.is_empty():
		_save_sheet(rows, out.path_join("sheet_%02d.png" % sheet_n))
	quit(0)


func _move(id: String) -> Dictionary:
	var mv := Dex.move(id)
	if mv.is_empty() and GUESS.has(id):
		var g: Array = GUESS[id]
		mv = {"id": id, "name": id, "type": g[0], "kind": g[1], "category": g[2], "power": g[3]}
		for k in g[4]:
			mv[k] = g[4][k]
	if mv.is_empty():
		return {}
	mv = mv.duplicate(true)
	mv.accuracy = 0
	return mv


func _times(mv: Dictionary) -> Array:
	var w := float(mv.get("windup", 0.6))
	match String(mv.get("kind", "")):
		"dash":
			return [0.1, 0.2, 0.32]
		"arc":
			return [0.04, 0.1, 0.18]
		"multi_arc":
			return [0.05, 0.2, 0.36]
		"whip":
			return [0.05, 0.12, 0.22]
		"projectile", "homing":
			return [0.12, 0.24, 0.36]
		"beam":
			return [w * 0.7, w + 0.08, w + 0.25]
		"aoe_target":
			return [w * 0.6, w + 0.05, w + 0.22]
		"aoe_self":
			return [maxf(w * 0.6, 0.05), w + 0.06, w + 0.22]
		"stream":
			return [0.15, 0.4, 0.7]
		"zone":
			return [0.3, 0.9, 1.8]
	return [0.12, 0.3, 0.55]


func _shoot(a: Node, mv: Dictionary, single: bool) -> Array:
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	a.vfx.clear()
	for t in 20:
		a.step(DT)
	var kind := String(mv.get("kind", ""))
	var gap := 3.6
	if kind in ["arc", "multi_arc"]:
		gap = 1.5
	elif kind in ["dash", "whip", "stream"]:
		gap = 2.6
	p.position = Vector3(-gap * 0.5, 0, 0.4)
	e.position = Vector3(gap * 0.5, 0, -0.4)
	p.velocity = Vector3.ZERO
	e.velocity = Vector3.ZERO
	p.hp = p.max_hp
	e.hp = e.max_hp
	e.status = ""
	e.confusion_t = 0.0
	p.status = ""
	p.stamina = p.pp_max
	p.facing = (e.position - p.position).normalized()
	await _steps(a, 0.1)
	_label.text = "%s  (%s, %s)" % [String(mv.id), String(mv.kind), String(mv.type)]
	a.moves.deliver(p, mv)
	var imgs: Array = []
	var t := 0.0
	var times := _times(mv)
	if single:
		times = [times[1]]
	for want in times:
		while t < float(want):
			a.step(DT)
			t += DT
			e.hp = e.max_hp
			p.hp = p.max_hp
			e.position = Vector3(gap * 0.5, 0, -0.4) if kind != "dash" else e.position
		imgs.append(await _grab(a, single))
	await _steps(a, 0.8)
	return imgs


func _grab(a: Node, full: bool) -> Image:
	for i in 2:
		await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	if full:
		return img
	var cam: Camera3D = a._cam
	var mid: Vector3 = (
		(a.player.global_position + a.enemy.global_position) * 0.5 + Vector3(0, 0.7, 0)
	)
	var c := cam.unproject_position(mid)
	var sz := Vector2i(640, 400)
	var x := clampi(int(c.x) - sz.x / 2, 0, img.get_width() - sz.x)
	var y := clampi(int(c.y) - sz.y / 2, 0, img.get_height() - sz.y)
	var crop := img.get_region(Rect2i(Vector2i(x, y), sz))
	crop.resize(TILE.x, TILE.y, Image.INTERPOLATE_BILINEAR)
	var lbl := img.get_region(Rect2i(0, 0, 420, 40))
	lbl.resize(280, 27)
	crop.blit_rect(lbl, Rect2i(0, 0, 280, 27), Vector2i.ZERO)
	return crop


func _save_sheet(rows: Array, path: String) -> void:
	var sheet := Image.create(TILE.x * 3, TILE.y * rows.size(), false, Image.FORMAT_RGBA8)
	sheet.fill(Color.BLACK)
	for r in rows.size():
		for k in (rows[r] as Array).size():
			var im: Image = rows[r][k]
			im.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(im, Rect2i(Vector2i.ZERO, TILE), Vector2i(TILE.x * k, TILE.y * r))
	sheet.save_png(path)
	print("salvo ", path)


func _arena() -> Node:
	var a: Node = load(ARENA).instantiate()
	a.manual = true
	_world.add_child(a)
	var p := Mon.create("clefairy", 40)
	a.start(
		[p],
		[Mon.create("rattata", 100)],
		{"seed": 3, "battle_size": 1, "kind": "wild", "speed": 1.0, "field_objects": false}
	)
	return a


func _steps(a: Node, secs: float) -> void:
	for i in int(round(secs / DT)):
		a.step(DT)
		if a.state == "fight" and is_instance_valid(a.enemy):
			a.enemy.controller = "none"
			a.player.controller = "none"
		if i % 2 == 0:
			await process_frame


func _build_world() -> Node3D:
	var w := Node3D.new()
	root.add_child(w)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.38, 0.6, 0.92)
	sm.sky_horizon_color = Color(0.75, 0.85, 0.95)
	sky.sky_material = sm
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.9
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	w.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	w.add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 80)
	var gm := StandardMaterial3D.new()
	gm.albedo_texture = load("res://original/assets/textures/ground_grass.png")
	gm.uv1_scale = Vector3(40, 40, 1)
	gm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	pm.material = gm
	ground.mesh = pm
	w.add_child(ground)
	return w

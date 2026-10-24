class_name InteriorDefs
extends RefCounted
## Room definitions (local coordinates: origin = floor centre, +Z = front wall, where the exit is).
## Rooms are built inside RouteWorld at BASE + index * SPACING, far from the outdoor maps.
##
## size: [w, d] (from data/interiors/*.json rects). exit: {x, to} -> mat on the front wall, spawn "door".
## stairs: {at: [x, z], to: [interior, spawn]}. spawns: name -> [x, z, dir]. markers: name -> [x, z, dir, y?].
## furniture: [name, [x, z, y?], [w, h, d], color, solid?]. npcs: {type, marker, name, lines, color, shop?,
## after_heal? (nurse/mom), species? (pet), uid/item/count? (hidden_item), sprite?}.
## dir: "n" (-Z, back wall), "s" (+Z, front), "e" (+X), "w" (-X).

const BASE := Vector3(10000, 0, 0)
const SPACING := 40.0
const WALL_H := 3.0

## Map door target_spawn (data/maps/*.json) -> [interior id, spawn].
const DOOR_TARGETS := {
	"player_house": ["player_house", "door"],
	"rival_house": ["rival_house", "door"],
	"lab": ["oak_lab", "door"],
	"vc_center_in": ["pokemon_center_viridian", "door"],
	"vc_mart_in": ["mart_viridian", "door"],
	"vc_school_in": ["trainer_school_viridian", "door"],
	"vc_house_in": ["viridian_house", "door"],
	"vf_gate_s_in": ["forest_gate_south", "door"],
	"vf_gate_s_out": ["forest_gate_south", "back"],
	"vf_gate_n_in": ["forest_gate_north", "door"],
	"vf_gate_n_out": ["forest_gate_north", "back"],
	"pw_center_in": ["pokemon_center_pewter", "door"],
	"pw_mart_in": ["mart_pewter", "door"],
	"pw_gym_in": ["pewter_gym", "door"],
	"pw_museum_in": ["pewter_museum", "door"],
	"pw_house1_in": ["pewter_house1", "door"],
	"pw_house2_in": ["pewter_house2", "door"],
	"mm_center_in": ["pokemon_center_mt_moon", "door"],
	"mm_1f_west_in": ["mt_moon_1f", "west_in"],
}

## Order fixes each room's slot in the world.
const ORDER := [
	"player_room",
	"player_house",
	"rival_house",
	"oak_lab",
	"pokemon_center_viridian",
	"mart_viridian",
	"trainer_school_viridian",
	"viridian_house",
	"forest_gate_south",
	"forest_gate_north",
	"pokemon_center_pewter",
	"mart_pewter",
	"pewter_gym",
	"pewter_museum",
	"pewter_house1",
	"pewter_house2",
	"pokemon_center_mt_moon",
	"mt_moon_1f",
	"mt_moon_b1f",
	"mt_moon_b2f"
]

## Caves (CaveBuilder): same x slot as any room, but pushed this far south so their bigger floors never overlap.
const CAVE_Z := 200.0
const CAVE_GAP_Z := 60.0

const ROOMS := {
	"player_room":
	{
		"name": "Quarto",
		"zone": "pallet_town",
		"size": [11, 8],
		"floor": "#b9a27e",
		"wall": "#e8dcc4",
		"stairs": {"at": [4.3, -2.7], "to": ["player_house", "stairs"]},
		"spawns":
		{
			"bed": [-2.9, -1.8, "e"],
			"stairs": [2.6, -2.7, "w"],
			"bedroom": [-2.9, -1.8, "e"],
			"bedroom_start": [-2.9, -1.8, "e"]
		},
		"markers":
		{"bed": [-4.2, -2.5, "s"], "desk_potion": [0.6, -3.0, "s"], "tv": [-1.2, 1.4, "n"]},
		"furniture":
		[
			["Cama", [-4.2, -2.5], [1.5, 0.55, 2.4], "#d0503f"],
			["Travesseiro", [-4.2, -3.4], [1.2, 0.75, 0.5], "#f4f1ea"],
			["Escrivaninha", [0.6, -3.5], [2.2, 0.85, 0.8], "#8a6b45"],
			["Computador", [0.6, -3.55, 0.85], [0.8, 0.6, 0.5], "#d1d6e0", false],
			["Estante", [-1.8, -3.6], [1.4, 2.0, 0.6], "#6f5236"],
			["TV", [-1.2, 1.6], [1.4, 1.0, 0.6], "#2b2d33"],
			["Videogame", [-1.2, 0.8], [0.6, 0.15, 0.4], "#7d7f86"],
			["Tapete", [0.5, 0.0], [3.0, 0.02, 2.0], "#4f79b8", false],
			["Planta", [4.6, 3.2], [0.6, 1.2, 0.6], "#3f8a45"],
		],
		# Original Bedroom.tscn: no PC terminal, only a hidden Potion at the desk (PCPotion, uid bedroom_pc).
		"npcs":
		[
			{
				"type": "hidden_item",
				"marker": "desk_potion",
				"name": "",
				"uid": "bedroom_pc",
				"item": "potion",
				"count": 1
			}
		],
	},
	"player_house":
	{
		"name": "Casa",
		"zone": "pallet_town",
		"size": [12, 7],
		"floor": "#c4a77c",
		"wall": "#efe4cf",
		"exit": {"x": -0.8, "to": {"zone": "pallet_town", "spawn": "player_house_door"}},
		"stairs": {"at": [4.9, -2.3], "to": ["player_room", "stairs"]},
		"spawns":
		{
			"stairs": [3.2, -2.3, "w"],
			"player_house": [-0.8, 1.7, "n"],
			"player_house_stairs": [3.2, -2.3, "w"]
		},
		"markers":
		{
			"mom": [-1.6, -0.6, "s"],
			"table": [0.4, -0.4, "s"],
			"tv": [-4.0, -2.8, "s"],
			"pidgey": [-2.8, 0.7, "s"]
		},
		"furniture":
		[
			["Mesa", [0.4, -0.4], [2.2, 0.8, 1.4], "#9a7448"],
			["Cadeira", [0.4, 0.75], [0.6, 0.5, 0.6], "#7b5a36"],
			["Cadeira", [1.9, -0.4], [0.6, 0.5, 0.6], "#7b5a36"],
			["Bancada", [-3.3, -3.0], [3.6, 1.0, 0.7], "#d8d4cc"],
			["Fogão", [-1.0, -3.0], [1.0, 1.0, 0.7], "#5a5d63"],
			["TV", [-5.2, -1.0], [0.6, 1.0, 1.4], "#2b2d33"],
			["Planta", [-5.4, 2.9], [0.6, 1.2, 0.6], "#3f8a45"],
		],
		"npcs":
		[
			{
				"type": "mom",
				"marker": "mom",
				"name": "Mamãe",
				"color": "#d77fa1",
				# Original PlayerHouse.tscn NPC_Mom (action HEAL): lines, heal with fade, after_heal_lines.
				"lines": ["{PLAYER}! Você devia descansar um pouco."],
				"after_heal": ["Que bom! Você e seus Pokémon estão ótimos. Cuide-se!"]
			},
			# MomsPidgey (creature.gd, owner_name Mom).
			{
				"type": "pet",
				"marker": "pidgey",
				"species": "Pidgey",
				"name": "Pidgey da Mamãe",
				"lines":
				[
					"Pidgey: Pidge...",
					"O Pidgey da Mamãe está cochilando no tapete. Ele faz parte da família há anos."
				]
			}
		],
	},
	"rival_house":
	{
		"name": "Casa do Rival",
		"zone": "pallet_town",
		"size": [12, 7],
		"floor": "#c9b08a",
		"wall": "#e9e2d2",
		"exit": {"x": -0.8, "to": {"zone": "pallet_town", "spawn": "rival_house_door"}},
		"spawns": {"rival_house": [-0.8, 1.7, "n"]},
		"markers":
		{"daisy": [1.5, -1.0, "s"], "table": [0.4, -0.6, "s"], "rattata": [2.6, 0.9, "s"]},
		"furniture":
		[
			["Mesa", [0.0, -0.6], [2.2, 0.8, 1.4], "#9a7448"],
			["Estante", [-4.0, -3.0], [2.4, 2.0, 0.6], "#6f5236"],
			["Estante", [4.0, -3.0], [2.4, 2.0, 0.6], "#6f5236"],
			["Quadro", [0.0, -3.3], [1.6, 1.1, 0.1], "#6aa0d8"],
			["Planta", [5.4, 2.9], [0.6, 1.2, 0.6], "#3f8a45"],
		],
		"npcs":
		[
			{
				"type": "npc",
				"marker": "daisy",
				"name": "Margarida",
				"color": "#e3a85b",
				"lines":
				[
					"Oi, {PLAYER}! Meu irmão {RIVAL} foi ver o Prof. Carvalho.",
					"Ele vive dizendo que vai ser o melhor treinador."
				]
			},
			# DaisysRattata (creature.gd, owner_name Daisy).
			{
				"type": "pet",
				"marker": "rattata",
				"species": "Rattata",
				"name": "Rattata da Margarida",
				"lines": ["Rattata: Ratta! Rattata!", "Ele cheira sua mão e abana o rabo."]
			}
		],
	},
	"oak_lab":
	{
		"name": "Laboratório do Prof. Carvalho",
		"zone": "pallet_town",
		"size": [13, 16],
		"floor": "#b9b3a6",
		"wall": "#f1f0ea",
		"exit": {"x": 0.0, "to": {"zone": "pallet_town", "spawn": "lab_door"}},
		"spawns": {"lab": [0.0, 5.7, "n"], "front_of_oak": [0.0, -2.6, "n"]},
		"markers":
		{
			"oak": [0.0, -4.4, "s"],
			"rival": [-1.6, -2.6, "e"],
			"player": [0.0, -2.6, "n"],
			"ball_1": [2.4, -4.6, "s", 0.98],
			"ball_2": [3.2, -4.6, "s", 0.98],
			"ball_3": [4.0, -4.6, "s", 0.98],
			"table": [3.2, -4.6, "s"],
			# Centro da quadra da 1ª luta com o rival (RivalBattleSpot do Lab.tscn do original, z 0.6):
			# a quadra 10 x 6.4 (x -5..5, z -2.6..3.8) fica livre de móveis e gente, como lá.
			"rival_battle": [0.0, 0.6, "n"],
			"aide_1": [-1.2, -6.2, "s"],
			"aide_2": [5.1, 6.3, "w"],
			"pidgey": [-2.5, 5.2, "s"],
		},
		"furniture":
		[
			["Mesa das Pokébolas", [3.2, -4.6], [3.0, 0.9, 1.0], "#8d6a43"],
			["Máquina", [-4.6, -6.9], [2.6, 2.0, 1.2], "#7f8ea3"],
			["Estante", [-5.9, -4.6], [0.6, 2.2, 3.0], "#6f5236"],
			["Estante", [5.9, -4.6], [0.6, 2.2, 3.0], "#6f5236"],
			["Estante", [-4.6, 5.5], [3.0, 2.2, 0.6], "#6f5236"],
			["Estante", [4.6, 5.5], [3.0, 2.2, 0.6], "#6f5236"],
			["Computador", [3.8, -6.9], [2.4, 1.1, 0.9], "#4c5563"],
			["Mesa", [-2.2, -7.4], [1.8, 0.85, 1.0], "#b7b2a4"],
			["Mesa", [0.6, -7.4], [1.8, 0.85, 1.0], "#b7b2a4"],
			["Tapete", [0.0, 0.0], [2.0, 0.02, 9.0], "#6c8ac0", false],
			["Planta", [-6.0, -7.4], [0.6, 1.2, 0.6], "#3f8a45"],
		],
		"npcs":
		[
			{
				"type": "npc",
				"marker": "aide_1",
				"name": "Pesquisador-chefe",
				"color": "#e9e9e9",
				"sprite": "npc_scientist",
				"lines":
				[
					"O professor? Ele saiu faz um tempinho...",
					"Essas Pokébolas na mesa são para treinadores novatos, mas só o Prof. Carvalho pode entregá-las."
				]
			},
			{
				"type": "npc",
				"marker": "aide_2",
				"name": "Assistente do Laboratório",
				"color": "#e9e9e9",
				"sprite": "npc_scientist",
				"lines":
				[
					"Estou anotando como os Pokémon reagem aos treinadores. Uns fogem, uns avançam, outros só observam.",
					"Pokémon de treinadores ficam calmos perto das pessoas. Tente falar com o Pidgey!"
				]
			},
			# LabPidgey (creature.gd, npc_name "the Lab's Pidgey").
			{
				"type": "pet",
				"marker": "pidgey",
				"species": "Pidgey",
				"name": "Pidgey do Laboratório",
				"lines":
				[
					"Pidgey: Pidge! Pidge!",
					"Um Pidgey de pesquisa. Ele vem pulando ver se você tem algum petisco."
				]
			},
		],
	},
	"pokemon_center_viridian":
	{
		"name": "Centro Pokémon",
		"zone": "viridian_city",
		"size": [15, 7],
		"floor": "#d8c7b8",
		"wall": "#f2e9e0",
		"exit": {"x": 0.0, "to": {"zone": "viridian_city", "spawn": "vc_center_door"}},
		"spawns": {"vc_center_in": [0.0, 1.7, "n"], "counter": [0.0, -1.1, "n"]},
		"markers":
		{
			"nurse": [0.0, -2.6, "s"],
			"counter": [0.0, -1.95, "s"],
			"pc": [5.6, -2.9, "s"],
			"attendant": [-4.8, 0.0, "w"],
			"traveller": [6.2, -0.2, "e"],
			"youngster": [2.0, 1.1, "w"]
		},
		"furniture":
		[
			["Balcão", [0.0, -1.95], [5.0, 1.1, 0.5], "#e05a52"],
			["Máquina de cura", [-1.5, -3.0], [1.4, 1.3, 0.6], "#c9cfd8"],
			["Banco", [-5.5, 1.0], [2.4, 0.5, 0.8], "#cf7a52"],
			["Banco", [5.5, 1.0], [2.4, 0.5, 0.8], "#cf7a52"],
			["Mesa do PC", [5.6, -3.0], [1.6, 0.85, 0.7], "#8b929c"],
			["Planta", [-7.0, -3.0], [0.6, 1.2, 0.6], "#3f8a45"],
			["Planta", [7.0, 3.0], [0.6, 1.2, 0.6], "#3f8a45"],
		],
		"npcs":
		[
			{
				"type": "nurse",
				"marker": "nurse",
				"name": "Enfermeira",
				"color": "#f2a3c0",
				# Original NPC_Nurse (action HEAL): lines, heal with fade, after_heal_lines.
				"lines":
				[
					"Bem-vindo ao nosso Centro Pokémon!",
					"Quer que eu cure seus Pokémon e os deixe em perfeita saúde?",
					"Certo, vou levar seus Pokémon por alguns segundos."
				],
				"after_heal":
				[
					"Obrigada por esperar. Seus Pokémon estão totalmente recuperados. Esperamos vê-lo de novo!"
				]
			},
			{"type": "pc", "marker": "pc", "name": "PC"},
			# viridian/PokemonCenter.tscn: Attendant, Traveller, Youngster (the Cable Club is not ported).
			{
				"type": "npc",
				"marker": "attendant",
				"name": "Atendente",
				"sprite": "npc_scientist",
				"lines":
				[
					"Os Centros Pokémon curam Pokémon cansados, feridos ou desmaiados.",
					"Eles deixam todos os Pokémon completamente saudáveis."
				]
			},
			{
				"type": "npc",
				"marker": "traveller",
				"name": "Viajante",
				"sprite": "npc_oldman",
				"lines":
				[
					"Há um Centro Pokémon em cada cidade daqui para a frente.",
					"Eles não cobram nada, então não tenha vergonha de curar seus Pokémon."
				]
			},
			{
				"type": "npc",
				"marker": "youngster",
				"name": "Garoto",
				"sprite": "npc_youngster",
				"lines":
				[
					"Fique à vontade para usar aquele PC no canto.",
					"Foi a recepcionista que me disse. Ela é tão gentil!"
				]
			},
		],
	},
	"mart_viridian":
	{
		"name": "Poké Mart",
		"zone": "viridian_city",
		"size": [11, 6],
		"floor": "#c3cad3",
		"wall": "#eef1f4",
		"exit": {"x": 0.0, "to": {"zone": "viridian_city", "spawn": "vc_mart_door"}},
		"spawns": {"vc_mart_in": [0.0, 1.2, "n"], "counter": [-2.6, -0.4, "w"]},
		"markers":
		{
			"clerk": [-4.4, -0.4, "e"],
			"counter": [-3.6, -0.4, "e"],
			"girl": [0.6, 0.7, "e"],
			"old_man": [4.0, 2.4, "w"]
		},
		"furniture":
		[
			["Balcão", [-3.6, -0.4], [0.6, 1.1, 2.8], "#2f6cc9"],
			["Caixa", [-3.6, -1.3], [0.5, 0.3, 0.5], "#30343b"],
			["Prateleira", [2.8, -2.2], [4.0, 1.7, 0.6], "#c0c6ce"],
			["Prateleira", [2.8, -0.3], [4.0, 1.7, 0.6], "#c0c6ce"],
		],
		"npcs":
		[
			{
				"type": "clerk",
				"marker": "clerk",
				"name": "Vendedor",
				"color": "#4d86d8",
				"shop": "viridian"
			},
			# viridian/PokeMart.tscn: Girl and Old Man.
			{
				"type": "npc",
				"marker": "girl",
				"name": "Moça",
				"sprite": "npc_girl",
				"lines": ["Ouvi dizer que esta loja vende muito Antídoto."]
			},
			{
				"type": "npc",
				"marker": "old_man",
				"name": "Senhor",
				"sprite": "npc_oldman",
				"lines":
				[
					"Preciso comprar umas Poções.",
					"Nunca se sabe quando seus Pokémon vão precisar de uma cura rápida."
				]
			},
		],
	},
	"trainer_school_viridian":
	{
		"name": "Escola de Treinadores",
		"zone": "viridian_city",
		"size": [10, 6],
		"floor": "#c8b48f",
		"wall": "#ece4d4",
		"exit": {"x": 0.0, "to": {"zone": "viridian_city", "spawn": "vc_school_door"}},
		"spawns": {"vc_school_in": [0.0, 1.2, "n"]},
		"markers": {"teacher": [0.0, -2.1, "s"], "student": [2.5, 1.9, "n"]},
		"furniture":
		[
			["Lousa", [0.0, -2.85], [4.0, 1.6, 0.1], "#2f4a3a"],
			["Carteira", [-2.5, -0.6], [1.2, 0.7, 0.7], "#9a7448"],
			["Carteira", [2.5, -0.6], [1.2, 0.7, 0.7], "#9a7448"],
			["Carteira", [-2.5, 1.0], [1.2, 0.7, 0.7], "#9a7448"],
			["Carteira", [2.5, 1.0], [1.2, 0.7, 0.7], "#9a7448"],
		],
		"npcs":
		[
			{
				"type": "npc",
				"marker": "teacher",
				"name": "Professora",
				"color": "#9a6fc4",
				"sprite": "npc_woman",
				"lines":
				[
					"Bem-vindo à Escola de Treinadores!",
					"Fogo vence Planta, Planta vence Água, Água vence Fogo.",
					"Aprenda as vantagens de tipo e seus Pokémon vão agradecer."
				]
			},
			{
				"type": "npc",
				"marker": "student",
				"name": "Aluno",
				"sprite": "npc_kid",
				"lines":
				[
					"Estou copiando as anotações da lousa...",
					"Golpes de status como Growl não causam dano, mas fazem diferença!"
				]
			},
		],
	},
	"viridian_house":
	{
		"name": "Casa",
		"zone": "viridian_city",
		"size": [12, 7],
		"floor": "#c4a77c",
		"wall": "#efe4cf",
		"exit": {"x": -0.4, "to": {"zone": "viridian_city", "spawn": "vc_house_door"}},
		"spawns": {"vc_house_in": [-0.4, 1.7, "n"]},
		"markers": {"old_man": [2.0, 0.9, "n"], "girl": [-4.4, -1.7, "s"]},
		"furniture":
		[
			["Mesa", [2.0, -0.2], [2.0, 0.8, 1.2], "#9a7448"],
			["Estante", [-4.0, -3.0], [2.4, 2.0, 0.6], "#6f5236"],
			["Planta", [5.4, 2.9], [0.6, 1.2, 0.6], "#3f8a45"],
		],
		"npcs":
		[
			# viridian/ViridianHouse.tscn: Old Man (nicknames) and Girl.
			{
				"type": "npc",
				"marker": "old_man",
				"name": "Senhor",
				"sprite": "npc_oldman",
				"lines":
				[
					"Inventar apelidos é divertido, mas não é tão fácil.",
					"Nomes espertos são legais, mas nomes simples são mais fáceis de lembrar."
				]
			},
			{
				"type": "npc",
				"marker": "girl",
				"name": "Menina",
				"sprite": "npc_little_girl",
				"lines": ["Meu papai também adora Pokémon."]
			},
		],
	},
	# --- Rota 2 / Floresta de Viridian (portarias: entrada pela frente, saída pelos fundos) ---
	# ForestSouthGate.tscn / ForestNorthGate.tscn: 16.25 x 12.5, mesas, cadeiras, plantas e 3 NPCs.
	"forest_gate_south":
	{
		"name": "Portaria da Floresta",
		"zone": "route_2",
		"size": [16.25, 12.5],
		"floor": "#c9c2b0",
		"wall": "#e6e0d0",
		"exit": {"x": 0.0, "to": {"zone": "route_2", "spawn": "r2_forest_gate_door"}},
		"exit_back": {"x": 0.0, "to": {"zone": "route_2", "spawn": "r2_forest_gate_back"}},
		"spawns": {},
		"markers":
		{
			"woman_1": [-3.75, 1.875, "s"],
			"woman_2": [3.75, 0.625, "w"],
			"aide_hm05": [-3.75, 0.625, "s"]
		},
		"furniture":
		[
			["Tapete", [0.0, 0.625], [3.75, 0.02, 8.75], "#6c8ac0", false],
			["Mesa", [5.625, -1.25], [1.4, 0.8, 1.0], "#9a7448"],
			["Mesa", [5.625, 2.5], [1.4, 0.8, 1.0], "#9a7448"],
			["Cadeira", [4.375, -1.25], [0.6, 0.5, 0.6], "#7b5a36"],
			["Cadeira", [6.875, -1.25], [0.6, 0.5, 0.6], "#7b5a36"],
			["Cadeira", [4.375, 2.5], [0.6, 0.5, 0.6], "#7b5a36"],
			["Cadeira", [6.875, 2.5], [0.6, 0.5, 0.6], "#7b5a36"],
			["Planta", [-7.5, -4.375], [0.6, 1.2, 0.6], "#3f8a45"],
			["Planta", [-2.5, -4.375], [0.6, 1.2, 0.6], "#3f8a45"],
			["Planta", [2.5, -4.375], [0.6, 1.2, 0.6], "#3f8a45"],
			["Planta", [7.5, -4.375], [0.6, 1.2, 0.6], "#3f8a45"],
			["Planta", [-7.5, -1.25], [0.6, 1.2, 0.6], "#3f8a45"],
			["Planta", [-7.5, 2.5], [0.6, 1.2, 0.6], "#3f8a45"],
		],
		"npcs":
		[
			{
				"type": "npc",
				"marker": "woman_1",
				"name": "Mulher",
				"sprite": "npc_woman",
				"lines":
				[
					"Você vai para a Floresta de Viridian? Lá dentro é um labirinto natural. Cuidado para não se perder."
				]
			},
			{
				"type": "npc",
				"marker": "woman_2",
				"name": "Mulher",
				"sprite": "npc_woman",
				"lines":
				[
					"O Rattata pode ser pequeno, mas não subestime a mordida dele.",
					"Você já pegou um?"
				]
			},
			# Ajudante do Prof. Carvalho (original NPC_Aide, action GIFT -> Story.aide_reward):
			# a recompensa (HM05 com 10 espécies) vem do gancho da história em "aide_hm05".
			{
				"type": "npc",
				"marker": "aide_hm05",
				"name": "Ajudante",
				"sprite": "npc_scientist",
				"lines":
				[
					"Oi! Lembra de mim? Sou um dos ajudantes do Prof. Carvalho.",
					"Se a sua Pokédex tiver dados completos de dez espécies, devo lhe dar uma recompensa.",
					"O Prof. Carvalho me confiou o HM05 para você.",
					"Então, {PLAYER}, deixe-me perguntar.",
					"Você já reuniu dados de pelo menos dez tipos de Pokémon?"
				]
			},
		],
	},
	"forest_gate_north":
	{
		"name": "Portaria da Floresta",
		"zone": "route_2_north",
		"size": [16.25, 12.5],
		"floor": "#c9c2b0",
		"wall": "#e6e0d0",
		"exit": {"x": 0.0, "to": {"zone": "route_2_north", "spawn": "r2n_gate_door"}},
		"exit_back": {"x": 0.0, "to": {"zone": "route_2_north", "spawn": "r2n_gate_back"}},
		"spawns": {},
		"markers":
		{
			"youngster": [-2.5, -1.875, "s"],
			"old_man": [-3.75, 1.875, "s"],
			"cooltrainer": [3.75, -0.625, "e"]
		},
		"furniture":
		[
			["Tapete", [0.0, 0.625], [3.75, 0.02, 8.75], "#6c8ac0", false],
			["Mesa", [5.625, -1.25], [1.4, 0.8, 1.0], "#9a7448"],
			["Mesa", [5.625, 2.5], [1.4, 0.8, 1.0], "#9a7448"],
			["Cadeira", [4.375, -1.25], [0.6, 0.5, 0.6], "#7b5a36"],
			["Cadeira", [6.875, -1.25], [0.6, 0.5, 0.6], "#7b5a36"],
			["Cadeira", [4.375, 2.5], [0.6, 0.5, 0.6], "#7b5a36"],
			["Cadeira", [6.875, 2.5], [0.6, 0.5, 0.6], "#7b5a36"],
			["Planta", [-7.5, -4.375], [0.6, 1.2, 0.6], "#3f8a45"],
			["Planta", [-2.5, -4.375], [0.6, 1.2, 0.6], "#3f8a45"],
			["Planta", [2.5, -4.375], [0.6, 1.2, 0.6], "#3f8a45"],
			["Planta", [7.5, -4.375], [0.6, 1.2, 0.6], "#3f8a45"],
			["Planta", [-7.5, -1.25], [0.6, 1.2, 0.6], "#3f8a45"],
			["Planta", [-7.5, 2.5], [0.6, 1.2, 0.6], "#3f8a45"],
		],
		"npcs":
		[
			{
				"type": "npc",
				"marker": "youngster",
				"name": "Garoto",
				"sprite": "npc_youngster",
				"lines":
				[
					"Muitos Pokémon só vivem em florestas e cavernas.",
					"Você precisa ser persistente e procurar em todo lugar para achar tipos diferentes."
				]
			},
			{
				"type": "npc",
				"marker": "old_man",
				"name": "Senhor",
				"sprite": "npc_oldman",
				"lines":
				[
					"Você reparou nas árvores finas à beira do caminho?",
					"Dizem que dá para cortá-las com um golpe Pokémon especial."
				]
			},
			{
				"type": "npc",
				"marker": "cooltrainer",
				"name": "Treinadora",
				"sprite": "npc_cooltrainer_f",
				"lines":
				[
					"Você conhece a técnica de cancelar a evolução?",
					"Quando um Pokémon está evoluindo, você pode interromper o processo.",
					"É uma técnica para criar Pokémon do jeito que eles são."
				]
			},
		],
	},
	# --- Pewter ---
	"pokemon_center_pewter":
	{
		"name": "Centro Pokémon",
		"zone": "pewter_city",
		"size": [16, 8],
		"floor": "#d8c7b8",
		"wall": "#f2e9e0",
		"exit": {"x": 0.0, "to": {"zone": "pewter_city", "spawn": "pw_center_door"}},
		"spawns": {"pw_center_in": [0.0, 2.2, "n"], "counter": [0.0, -1.6, "n"]},
		"markers":
		{"nurse": [0.0, -3.1, "s"], "counter": [0.0, -2.45, "s"], "pc": [6.0, -3.4, "s"]},
		"furniture":
		[
			["Balcão", [0.0, -2.45], [5.0, 1.1, 0.5], "#e05a52"],
			["Máquina de cura", [-1.5, -3.5], [1.4, 1.3, 0.6], "#c9cfd8"],
			["Banco", [-6.0, 1.6], [2.4, 0.5, 0.8], "#cf7a52"],
			["Banco", [6.0, 1.6], [2.4, 0.5, 0.8], "#cf7a52"],
			["Mesa do PC", [6.0, -3.5], [1.6, 0.85, 0.7], "#8b929c"],
			["Planta", [-7.4, -3.4], [0.6, 1.2, 0.6], "#3f8a45"],
			["Planta", [7.4, 3.4], [0.6, 1.2, 0.6], "#3f8a45"],
		],
		"npcs":
		[
			{
				"type": "nurse",
				"marker": "nurse",
				"name": "Enfermeira",
				"color": "#f2a3c0",
				# Original pewter/PokemonCenter.tscn NPC_Nurse: all four lines before the heal, then the
				# default after_heal_lines of npc.gd.
				"lines":
				[
					"Bem-vindo ao nosso Centro Pokémon!",
					"Quer que eu cure seus Pokémon e os deixe em perfeita saúde?",
					"Certo, vou levar seus Pokémon por alguns segundos.",
					"Obrigada por esperar. Seus Pokémon estão totalmente recuperados. Esperamos vê-lo de novo!"
				],
				"after_heal": ["Pronto! Você e seus Pokémon estão ótimos. Cuide-se!"]
			},
			{"type": "pc", "marker": "pc", "name": "PC"},
		],
	},
	"mart_pewter":
	{
		"name": "Poké Mart",
		"zone": "pewter_city",
		"size": [12, 7],
		"floor": "#c3cad3",
		"wall": "#eef1f4",
		"exit": {"x": 0.0, "to": {"zone": "pewter_city", "spawn": "pw_mart_door"}},
		"spawns": {"pw_mart_in": [0.0, 1.7, "n"], "counter": [-3.0, -0.4, "w"]},
		"markers": {"clerk": [-4.9, -0.4, "e"], "counter": [-4.1, -0.4, "e"]},
		"furniture":
		[
			["Balcão", [-4.1, -0.4], [0.6, 1.1, 2.8], "#2f6cc9"],
			["Caixa", [-4.1, -1.3], [0.5, 0.3, 0.5], "#30343b"],
			["Prateleira", [2.8, -2.6], [4.0, 1.7, 0.6], "#c0c6ce"],
			["Prateleira", [2.8, -0.6], [4.0, 1.7, 0.6], "#c0c6ce"],
		],
		"npcs":
		[
			{
				"type": "clerk",
				"marker": "clerk",
				"name": "Vendedor",
				"color": "#4d86d8",
				"shop": "pewter"
			},
		],
	},
	"pewter_gym":
	{
		"name": "Ginásio de Pewter",
		"zone": "pewter_city",
		"size": [22, 22],
		"floor": "#9c958a",
		"wall": "#b9b2a6",
		"exit": {"x": 0.0, "to": {"zone": "pewter_city", "spawn": "pw_gym_door"}},
		"spawns": {"pw_gym_in": [0.0, 9.0, "n"], "front_of_brock": [0.0, -6.8, "n"]},
		"markers":
		{
			"brock": [0.0, -8.4, "s"],
			# PewterGym.tscn (30 x 26): Trainer_Liam (-7.5, 4.5) olhando para o norte, escalado para 22 x 22;
			# a visão (5 m, ±0.9 m) cobre só a faixa oeste e o corredor central fica livre, como lá.
			"liam": [-5.5, 3.8, "n"],
			"arena_center": [0.0, -3.0, "s"],
			"guide": [3.2, 8.2, "s"]
		},
		"furniture":
		[
			["Rocha", [-7.5, -6.0], [2.2, 1.6, 2.0], "#7d766b"],
			["Rocha", [7.5, -6.5], [2.6, 1.8, 2.2], "#7d766b"],
			["Rocha", [-8.0, 3.0], [2.0, 1.4, 2.4], "#857e72"],
			["Rocha", [8.0, 2.0], [2.4, 1.2, 2.0], "#857e72"],
			["Rocha", [-6.0, 7.5], [1.6, 1.0, 1.6], "#8e877b"],
			["Rocha", [6.5, 7.0], [1.8, 1.2, 1.4], "#8e877b"],
			["Plataforma", [0.0, -8.4], [5.0, 0.04, 2.4], "#6e675d", false],
			["Estátua", [-2.0, 9.6], [0.8, 1.8, 0.8], "#a8a39a"],
			["Estátua", [2.0, 9.6], [0.8, 1.8, 0.8], "#a8a39a"],
		],
		"npcs":
		[
			{"type": "trainer", "marker": "brock", "trainer": "brock", "color": "#8a5a3a"},
			{"type": "trainer", "marker": "liam", "trainer": "camper_liam", "color": "#5f8a3a"},
			{
				"type": "npc",
				"marker": "guide",
				"name": "Guia do Ginásio",
				"color": "#e0e0e0",
				"sprite": "npc_gym_guide",
				"lines":
				[
					"Opa! Você quer sonhar alto?",
					"Tem coragem de sonhar em se tornar o campeão Pokémon?",
					"Não sou treinador, mas posso dar dicas de como vencer.",
					"Deixa que eu levo você até o topo!",
					"O primeiro Pokémon a entrar numa luta é o da esquerda na lista de Pokémon.",
					"Mudando a ordem dos Pokémon, você pode ganhar vantagem.",
					"Experimente ordens diferentes de acordo com a equipe do adversário."
				]
			},
		],
	},
	"pewter_museum":
	{
		"name": "Museu de Ciências de Pewter",
		"zone": "pewter_city",
		"size": [20, 10],
		"floor": "#bdb2a0",
		"wall": "#ece6da",
		"exit": {"x": -1.5, "to": {"zone": "pewter_city", "spawn": "pw_museum_door"}},
		"spawns": {"pw_museum_in": [-1.5, 3.2, "n"]},
		"markers": {"clerk": [-6.0, 1.0, "e"]},
		"furniture":
		[
			["Balcão", [-7.0, 1.0], [0.6, 1.1, 2.6], "#8b6a46"],
			["Fóssil de Aerodactyl", [0.0, -3.9], [4.0, 1.4, 1.0], "#d9cfbd"],
			["Fóssil de Kabutops", [6.5, -3.9], [2.4, 1.6, 1.0], "#d4c8b2"],
			["Pedra da Lua", [-6.5, -3.4], [1.2, 1.2, 1.2], "#9aa4c8"],
			["Vitrine", [3.5, 1.5], [2.2, 1.0, 1.0], "#a8c6d8"],
		],
		"npcs":
		[
			{
				"type": "npc",
				"marker": "clerk",
				"name": "Recepcionista",
				"color": "#c46a6a",
				"sprite": "npc_woman",
				"lines": ["Temos dois fósseis de Pokémon raros e pré-históricos em exposição."]
			},
		],
	},
	"pewter_house1":
	{
		"name": "Casa",
		"zone": "pewter_city",
		"size": [12, 7],
		"floor": "#c4a77c",
		"wall": "#efe4cf",
		"exit": {"x": -0.4, "to": {"zone": "pewter_city", "spawn": "pw_house1_door"}},
		"spawns": {"pw_house1_in": [-0.4, 1.7, "n"]},
		"markers": {"woman": [2.0, 0.9, "n"]},
		"furniture":
		[
			["Mesa", [2.0, -0.2], [2.0, 0.8, 1.2], "#9a7448"],
			["Estante", [-4.0, -3.0], [2.4, 2.0, 0.6], "#6f5236"],
		],
		"npcs":
		[
			# pewter/PewterHouse1.tscn: NPC_Woman.
			{
				"type": "npc",
				"marker": "woman",
				"name": "Mulher",
				"sprite": "npc_woman",
				"lines":
				[
					"Bem-vindo à Cidade de Pewter!",
					"Vale a pena visitar o Museu de Ciências: tem fósseis de Pokémon antigos!"
				]
			},
		],
	},
	"pewter_house2":
	{
		"name": "Casa",
		"zone": "pewter_city",
		"size": [12, 7],
		"floor": "#c4a77c",
		"wall": "#efe4cf",
		"exit": {"x": -0.4, "to": {"zone": "pewter_city", "spawn": "pw_house2_door"}},
		"spawns": {"pw_house2_in": [-0.4, 1.7, "n"]},
		"markers": {"girl": [2.0, 1.9, "n"]},
		"furniture":
		[
			["Mesa", [2.0, -0.2], [2.0, 0.8, 1.2], "#9a7448"],
			["Planta", [5.4, 2.9], [0.6, 1.2, 0.6], "#3f8a45"],
		],
		"npcs":
		[
			# pewter/PewterHouse2.tscn: NPC_Girl.
			{
				"type": "npc",
				"marker": "girl",
				"name": "Moça",
				"sprite": "npc_girl",
				"lines":
				[
					"Os Pokémon aprendem técnicas novas conforme crescem.",
					"Mas alguns golpes precisam ser ensinados por pessoas."
				]
			},
		],
	},
	# --- Rota 4 / Monte da Lua ---
	"pokemon_center_mt_moon":
	{
		"name": "Centro Pokémon",
		"zone": "route_3",
		"size": [16, 8],
		"floor": "#d8c7b8",
		"wall": "#f2e9e0",
		"exit": {"x": 0.0, "to": {"zone": "route_3", "spawn": "r4_center_door"}},
		"spawns": {"mm_center_in": [0.0, 2.2, "n"], "counter": [0.0, -1.6, "n"]},
		"markers":
		{
			"nurse": [0.0, -3.1, "s"],
			"counter": [0.0, -2.45, "s"],
			"pc": [6.0, -3.4, "s"],
			"salesman": [-5.6, -1.6, "e"],
			"visitor": [5.0, 0.6, "w"]
		},
		"furniture":
		[
			["Balcão", [0.0, -2.45], [5.0, 1.1, 0.5], "#e05a52"],
			["Máquina de cura", [-1.5, -3.5], [1.4, 1.3, 0.6], "#c9cfd8"],
			["Banco", [-6.0, 1.6], [2.4, 0.5, 0.8], "#cf7a52"],
			["Banco", [6.0, 1.6], [2.4, 0.5, 0.8], "#cf7a52"],
			["Mesa do PC", [6.0, -3.5], [1.6, 0.85, 0.7], "#8b929c"],
			["Planta", [-7.4, -3.4], [0.6, 1.2, 0.6], "#3f8a45"],
			["Planta", [7.4, 3.4], [0.6, 1.2, 0.6], "#3f8a45"],
		],
		"npcs":
		[
			{
				"type": "nurse",
				"marker": "nurse",
				"name": "Enfermeira",
				"color": "#f2a3c0",
				# Original NPC_Nurse (action HEAL): lines, heal with fade, after_heal_lines.
				"lines":
				[
					"Bem-vindo ao nosso Centro Pokémon!",
					"Quer que eu cure seus Pokémon e os deixe em perfeita saúde?",
					"Certo, vou levar seus Pokémon por alguns segundos."
				],
				"after_heal":
				[
					"Obrigada por esperar. Seus Pokémon estão totalmente recuperados. Esperamos vê-lo de novo!"
				]
			},
			{"type": "pc", "marker": "pc", "name": "PC"},
			{
				"type": "npc",
				"marker": "salesman",
				"name": "Vendedor",
				"color": "#c9a94a",
				"lines": ["Ei, você aí! Tenho uma oferta imperdível!"]
			},
			{
				"type": "npc",
				"marker": "visitor",
				"name": "Moça",
				"color": "#e39ab0",
				"lines":
				[
					"Dizem que o Monte da Lua está cheio de Zubat.",
					"Leve bastante Poção, a caverna é comprida!"
				]
			},
		],
	},
	# Andares do Monte da Lua: só o casco aqui; rochas, escadas, itens, treinadores e encontros vêm de
	"mt_moon_1f":
	{
		# CaveBuilder.decorate (data/maps/mt_moon_floors.json + mt_moon_events.json), 0,9 m por tile (48 x 40).
		"name": "Monte da Lua 1F",
		"zone": "route_3",
		"size": [43.2, 36.0],
		"cave": "1f",
		"floor": "#6b5f52",
		"wall": "#4a4139"
	},
	"mt_moon_b1f":
	{
		"name": "Monte da Lua B1F",
		"zone": "route_3",
		"size": [43.2, 36.0],
		"cave": "b1f",
		"floor": "#655a4e",
		"wall": "#463d35"
	},
	"mt_moon_b2f":
	{
		"name": "Monte da Lua B2F",
		"zone": "route_3",
		"size": [43.2, 36.0],
		"cave": "b2f",
		"floor": "#5f554a",
		"wall": "#423a33"
	},
}


static func origin_of(id: String) -> Vector3:
	var i := ORDER.find(id)
	var cave := String(ROOMS.get(id, {}).get("cave", ""))
	var z := 0.0 if cave == "" else CAVE_Z + CAVE_GAP_Z * ["1f", "b1f", "b2f"].find(cave)
	return BASE + Vector3(SPACING * maxi(i, 0), 0, z)


static func dir_vec(d: String) -> Vector3:
	return (
		{
			"n": Vector3(0, 0, -1),
			"s": Vector3(0, 0, 1),
			"e": Vector3(1, 0, 0),
			"w": Vector3(-1, 0, 0)
		}
		. get(d, Vector3(0, 0, -1))
	)

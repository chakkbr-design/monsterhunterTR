class_name StoryFlags
extends RefCounted
## Regras puras do roteiro (sem cena): o que cada lugar dispara conforme Game.flags.
## Flags usadas: oak_stopped, got_starter (+ starter_chosen, compat. com os mapas), starter / rival_starter (Game),
## rival_battle_done, rival_battle_won, has_parcel, has_pokedex, parcel_delivered, old_man_lesson, hm05_flash.

const RIVAL_TRAINER := "rival_blue_route22"
const RIVAL_FIRST_LEVEL := 5
const PARCEL := "oaks_parcel"
const POKEDEX := "pokedex"
const DEX_BALLS := 5

## Passos do roteiro, em ordem.
const STEPS := [
	"leave_house",
	"oak_stop",
	"pick_starter",
	"rival_battle",
	"get_parcel",
	"deliver_parcel",
	"done"
]


static func on(flags: Dictionary, k: String) -> bool:
	return bool(flags.get(k, false))


## Gatilho genérico: todas as `requires` ligadas e nenhuma `blocks`.
static func can_fire(flags: Dictionary, requires: Array, blocks: Array) -> bool:
	for f in requires:
		if not on(flags, String(f)):
			return false
	for f in blocks:
		if on(flags, String(f)):
			return false
	return true


## Passo atual do roteiro (para debug, testes e falas).
static func step(flags: Dictionary) -> String:
	if on(flags, "has_pokedex"):
		return "done"
	if on(flags, "has_parcel"):
		return "deliver_parcel"
	if on(flags, "rival_battle_done"):
		return "get_parcel"
	if on(flags, "got_starter"):
		return "rival_battle"
	if on(flags, "oak_stopped"):
		return "pick_starter"
	return "leave_house"


## O Oak barra quem vai para o mato alto sem Pokémon.
static func oak_should_stop(flags: Dictionary) -> bool:
	return not on(flags, "got_starter")


## O que acontece ao entrar numa sala ("" = nada).
static func interior_event(flags: Dictionary, id: String) -> String:
	match id:
		"oak_lab":
			if on(flags, "has_parcel") and not on(flags, "has_pokedex"):
				return "parcel_deliver"
		"mart_viridian":
			if (
				on(flags, "got_starter")
				and not on(flags, "has_parcel")
				and not on(flags, "has_pokedex")
			):
				return "mart_parcel"
	return ""


## Quem fica no laboratório agora.
static func lab_has_oak(flags: Dictionary) -> bool:
	return on(flags, "oak_stopped")


static func lab_has_rival(flags: Dictionary) -> bool:
	return not on(flags, "rival_battle_done")


## Pokébolas que ainda estão na mesa (ordem de Game.STARTERS).
static func balls_left(flags: Dictionary, starters: Array) -> Array:
	var out: Array = []
	for sp in starters:
		if String(flags.get("starter", "")) == sp or String(flags.get("rival_starter", "")) == sp:
			continue
		out.append(sp)
	return out


## Pegar uma Pokébola: só depois do Oak trazer o jogador e antes de ter um inicial.
static func can_pick(flags: Dictionary) -> bool:
	return on(flags, "oak_stopped") and not on(flags, "got_starter")


## Party da primeira luta: [[espécie, nível]] com o inicial do rival no nível 5.
static func first_rival_party(flags: Dictionary) -> Array:
	var sp := String(flags.get("rival_starter", ""))
	return [[sp, RIVAL_FIRST_LEVEL]] if sp != "" else []


## Falas do Oak fora de cena.
static func oak_lines(flags: Dictionary) -> PackedStringArray:
	if on(flags, "has_pokedex"):
		return PackedStringArray(
			["Come visit me once in a while.", "I want to know how your Pokédex is coming along!"]
		)
	if on(flags, "has_parcel"):
		return PackedStringArray(["Hm? Do you have something for me?"])
	if on(flags, "rival_battle_done"):
		return PackedStringArray(
			[
				"{PLAYER}, Viridian City is to the north, past Route 1.",
				"They say the shop there received a parcel of mine."
			]
		)
	if on(flags, "got_starter"):
		return PackedStringArray(["If a wild Pokémon appears, yours can battle it."])
	if on(flags, "oak_stopped"):
		return PackedStringArray(
			["There are Pokémon in these three Poké Balls.", "You can pick one, {PLAYER}!"]
		)
	return PackedStringArray(["Ah, {PLAYER}! Today is a big day."])


static func rival_lines(flags: Dictionary) -> PackedStringArray:
	if on(flags, "got_starter"):
		return PackedStringArray(["My Pokémon looks a lot stronger than yours."])
	if on(flags, "oak_stopped"):
		return PackedStringArray(["You can pick first, {PLAYER}. I'm mature!"])
	return PackedStringArray(["{PLAYER}? Gramps isn't here yet. What a wait!"])


## lines_for "Mom" do original (antes do inicial; depois ela só cura).
static func mom_lines(flags: Dictionary) -> PackedStringArray:
	if not on(flags, "got_starter"):
		return PackedStringArray(
			[
				"...Right.\nAll boys leave home someday.\nIt said so on TV.",
				"Oh, yes. PROF. OAK, next door,\nwas looking for you."
			]
		)
	return PackedStringArray(["{PLAYER}! Take a rest.", "There, your team is full of energy!"])


## lines_for "Daisy" do original (story.gd:85-88).
static func daisy_lines(flags: Dictionary) -> PackedStringArray:
	if on(flags, "rival_battle_done"):
		return PackedStringArray(
			["{PLAYER}, I heard you\nbattled {RIVAL}.", "I wish I'd seen that!"]
		)
	return PackedStringArray(["Hi, {PLAYER}!", "My brother, {RIVAL}, is at\nGramps's lab."])


## NPCs do lab do original: Head Researcher (aide_1, story.gd:89-91) e Lab Aide (aide_2).
static func lab_npc_name(role: String) -> String:
	return "Head Researcher" if role == "aide_1" else "Lab Aide"


static func lab_npc_lines(flags: Dictionary, role: String) -> PackedStringArray:
	if role == "aide_1":
		if on(flags, "starter_chosen") or on(flags, "got_starter"):
			return PackedStringArray(["That Pokémon already trusts you. Take good care of it!"])
		return PackedStringArray(
			[
				"The professor? He stepped out a little while ago...",
				"Those Poké Balls on the table are for new trainers, but only Prof. Oak can hand them out."
			]
		)
	return PackedStringArray(
		[
			"I'm noting how Pokémon react to trainers. Some flee, some attack, others just watch.",
			"A trainer's Pokémon stay calm around people. Try talking to the Pidgey!"
		]
	)


## Ajudante do Oak depois de dar o HM05 (lines_for "Aide", story.gd:114-117).
static func aide_lines() -> PackedStringArray:
	return PackedStringArray(["How is your POKéDEX coming along?", "Keep it up!"])


## Cartões da aula do velhinho (catch_weaken/catch_status/catch_throw do battle_tutorial.gd).
const CATCH_CARDS := [
	[
		"Weaken it first",
		"A Pokémon at full health escapes the ball. Get its HP into the yellow or red, but don't make it faint!"
	],
	[
		"Status helps",
		"A sleeping or paralyzed Pokémon is much easier to catch. Moves like Sleep Powder or Thunder Wave are a trainer's best friends."
	],
	["Throw the ball", "In battle, press Q to throw a Poké Ball. Better balls, better odds!"],
]

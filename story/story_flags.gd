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
			["Venha me visitar de vez em quando.", "Quero saber como está indo a sua Pokédex!"]
		)
	if on(flags, "has_parcel"):
		return PackedStringArray(["Hm? Você tem algo para mim?"])
	if on(flags, "rival_battle_done"):
		return PackedStringArray(
			[
				"{PLAYER}, a Cidade de Viridian fica ao norte, depois da Rota 1.",
				"Dizem que a loja de lá recebeu uma encomenda minha."
			]
		)
	if on(flags, "got_starter"):
		return PackedStringArray(["Se um Pokémon selvagem aparecer, o seu pode lutar com ele."])
	if on(flags, "oak_stopped"):
		return PackedStringArray(
			["Nessas três Poké Balls há Pokémon.", "Pode escolher um, {PLAYER}!"]
		)
	return PackedStringArray(["Ah, {PLAYER}! Hoje é um grande dia."])


static func rival_lines(flags: Dictionary) -> PackedStringArray:
	if on(flags, "got_starter"):
		return PackedStringArray(["Meu Pokémon parece bem mais forte que o seu."])
	if on(flags, "oak_stopped"):
		return PackedStringArray(["Pode escolher primeiro, {PLAYER}. Eu sou maduro!"])
	return PackedStringArray(["{PLAYER}? O vovô ainda não chegou. Que demora!"])


## lines_for "Mom" do original (antes do inicial; depois ela só cura).
static func mom_lines(flags: Dictionary) -> PackedStringArray:
	if not on(flags, "got_starter"):
		return PackedStringArray(
			[
				"...Certo.\nTodo garoto sai de casa um dia.\nDisseram isso na TV.",
				"Ah, sim. O PROF. CARVALHO, aqui do lado,\nestava procurando você."
			]
		)
	return PackedStringArray(
		["{PLAYER}! Descanse um pouco.", "Pronto, seu time está cheio de energia!"]
	)


## lines_for "Daisy" do original (story.gd:85-88).
static func daisy_lines(flags: Dictionary) -> PackedStringArray:
	if on(flags, "rival_battle_done"):
		return PackedStringArray(
			["{PLAYER}, ouvi dizer que você\nbatalhou contra o {RIVAL}.", "Queria ter visto isso!"]
		)
	return PackedStringArray(["Oi, {PLAYER}!", "Meu irmão, {RIVAL}, está no\nlaboratório do vovô."])


## NPCs do lab do original: Head Researcher (aide_1, story.gd:89-91) e Lab Aide (aide_2).
static func lab_npc_name(role: String) -> String:
	return "Pesquisador-chefe" if role == "aide_1" else "Assistente do lab"


static func lab_npc_lines(flags: Dictionary, role: String) -> PackedStringArray:
	if role == "aide_1":
		if on(flags, "starter_chosen") or on(flags, "got_starter"):
			return PackedStringArray(["Esse Pokémon já confia em você. Cuide bem dele!"])
		return PackedStringArray(
			[
				"O professor? Ele saiu faz um tempinho...",
				"Aquelas Poké Balls na mesa são para treinadores novos, mas só o Prof. Carvalho pode entregá-las."
			]
		)
	return PackedStringArray(
		[
			"Estou anotando como os Pokémon reagem aos treinadores. Uns fogem, uns atacam, outros só observam.",
			"Pokémon de treinador ficam calmos perto das pessoas. Tente falar com o Pidgey!"
		]
	)


## Ajudante do Oak depois de dar o HM05 (lines_for "Aide", story.gd:114-117).
static func aide_lines() -> PackedStringArray:
	return PackedStringArray(["Como está indo a sua POKéDEX?", "Continue assim!"])


## Cartões da aula do velhinho (catch_weaken/catch_status/catch_throw do battle_tutorial.gd).
const CATCH_CARDS := [
	[
		"Enfraqueça primeiro",
		"Um Pokémon com a vida cheia escapa da bola. Deixe o HP dele no amarelo ou no vermelho, mas sem desmaiar!"
	],
	[
		"Status ajuda",
		"Um Pokémon dormindo ou paralisado é bem mais fácil de capturar. Golpes como Sleep Powder ou Thunder Wave são os melhores amigos de um treinador."
	],
	[
		"Lance a bola",
		"Na batalha, aperte Q para lançar uma Poké Ball. Bolas melhores, chances melhores!"
	],
]

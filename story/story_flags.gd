class_name StoryFlags
extends RefCounted
## Regras puras do roteiro (sem cena): o que cada lugar dispara conforme Game.flags.
## Flags usadas: oak_stopped, got_starter (+ starter_chosen, compat. com os mapas), starter / rival_starter (Game),
## rival_battle_done, rival_battle_won, mom_healed, has_parcel, has_pokedex, parcel_delivered.

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
		"player_house":
			if on(flags, "rival_battle_done") and not on(flags, "mom_healed"):
				return "mom_heal"
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


static func mom_lines(flags: Dictionary) -> PackedStringArray:
	if not on(flags, "got_starter"):
		return PackedStringArray(["O Prof. Carvalho, aqui do lado, estava procurando você."])
	return PackedStringArray(
		["{PLAYER}! Descanse um pouco.", "Pronto, seu time está cheio de energia!"]
	)


## Pewter: o guia leva ao ginásio uma vez, e só antes da Insígnia da Rocha.
## Flags: pewter_guide_done, badge_boulder (+ boulder_badge), rival2_done / rival2_won (Rota 22, via trainers.json).
static func pewter_guide_due(flags: Dictionary) -> bool:
	return not on(flags, "pewter_guide_done") and not on(flags, "badge_boulder")

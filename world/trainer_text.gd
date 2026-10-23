class_name TrainerText
extends RefCounted
## Portuguese lines for the trainers placed up to Pewter (data/trainers.json keeps the original English).
## lines(id, key, fallback): key = intro | defeat | after | lose | badge_speech | gift_speech.

const CLASS_PT := {
	"bug_catcher": "Caçador de Insetos", "camper": "Campista", "gym_leader": "Líder", "rival": "Rival",
	"youngster": "Jovem", "lass": "Moça", "picnicker": "Piqueniqueira", "hiker": "Alpinista",
}

const TEXT := {
	"bug_catcher_rick": {
		"intro": ["Ei! Você tem Pokémon!", "Vamos lá, vamos batalhar!"],
		"defeat": ["Não!", "O Caterpie não aguentou!"],
		"after": ["Psiu! Você vai espantar os insetos.", "Fica para outra vez, tá?"],
	},
	"bug_catcher_doug": {
		"intro": ["Ei!", "Treinador Pokémon não foge de batalha!"],
		"defeat": ["Hã?", "Acabaram os meus Pokémon!"],
		"after": ["Que droga! Vou capturar uns mais fortes!"],
	},
	"bug_catcher_anthony": {
		"intro": ["Posso ser pequeno, mas não pegue leve comigo!"],
		"defeat": ["Ah, poxa.", "Nada deu certo."],
		"after": ["Perdi parte da minha mesada..."],
	},
	"bug_catcher_charlie": {
		"intro": ["Sabia que os Pokémon evoluem?"],
		"defeat": ["Ah!", "Eu perdi!"],
		"after": ["Pokémon inseto evoluem rápido.", "São muito divertidos!"],
	},
	"bug_catcher_sammy": {
		"intro": ["Ei, espere aí!", "Qual é a pressa?"],
		"defeat": ["Desisto!", "Você é bom nisso!"],
		"after": ["Às vezes dá para achar coisas no chão.", "Estou procurando o que deixei cair. Me ajuda?"],
	},
	"camper_liam": {
		"intro": ["Pare aí, garoto!", "Você está a anos-luz de enfrentar o Brock!"],
		"defeat": ["Droga!", "Ano-luz não mede tempo... mede distância!"],
		"after": ["Você é bom...", "Mas não tão bom quanto o Brock!"],
	},
	"brock": {
		"intro": ["Então você veio. Eu sou Brock, o Líder do Ginásio de Pewter.",
			"Minha força de vontade é dura como pedra, e meus Pokémon também.",
			"Isso mesmo: meus Pokémon são todos do tipo Pedra!",
			"Vai me desafiar mesmo sabendo que vai perder?",
			"Muito bem! Mostre o seu melhor!"],
		"defeat": ["Subestimei você, e por isso perdi.",
			"Como prova da sua vitória, aceite a INSÍGNIA DA ROCHA oficial da Liga Pokémon."],
		"after": ["Há todo tipo de treinador neste mundo enorme.",
			"Você parece ter muito talento.",
			"Uma sugestão: vá ao Ginásio de Cerulean e teste as suas habilidades."],
		"badge_speech": ["Só de ter a INSÍGNIA DA ROCHA, seus Pokémon ficam mais fortes.",
			"Ela também permite usar o golpe FLASH fora das batalhas."],
		"gift_speech": ["Espere! Leve isto também.",
			"Um TM, Máquina Técnica, guarda uma técnica para Pokémon.",
			"O TM39 contém TUMBA DE PEDRAS.",
			"Ele lança rochas no inimigo e reduz a VELOCIDADE dele."],
	},
	"rival_blue_route22": {
		"intro": ["Ei! {PLAYER}!", "Vai para a Liga Pokémon? Esqueça!",
			"Aposto que você nem tem insígnias.", "O guarda não deixa passar sem elas.",
			"Aliás, seus Pokémon ficaram mais fortes?"],
		"defeat": ["Ahh!", "Você só teve sorte!"],
		"lose": ["Isso! Eu sou demais ou não sou?"],
		"after": ["Ouvi dizer que a Liga Pokémon está cheia de treinadores fortes.",
			"Preciso descobrir como passar por eles.",
			"E você, pare de enrolar e siga em frente!"],
	},
}


static func lines(id: String, key: String, def: Dictionary) -> PackedStringArray:
	var t: Dictionary = TEXT.get(id, {})
	if t.has(key):
		return PackedStringArray(t[key])
	return PackedStringArray(def.get(key, []))


## "Caçador de Insetos Rick", "Líder Brock"; the rival uses Game.rival_name.
static func display_name(id: String, def: Dictionary) -> String:
	var cls := String(def.get("class", ""))
	if cls == "rival":
		return "{RIVAL}"
	return ("%s %s" % [CLASS_PT.get(cls, cls.replace("_", " ").capitalize()), def.get("name", "")]).strip_edges()

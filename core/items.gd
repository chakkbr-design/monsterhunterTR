class_name Items
extends RefCounted
## Uso de itens fora e dentro da batalha. Não mexe na bolsa: quem chama desconta com Game.take_item.


## O item faria algo neste Pokémon?
static func can_use(id: String, m: Mon) -> bool:
	var fx: Dictionary = Dex.item(id).get("effect", {})
	if fx.has("revive"):
		return m.is_fainted()
	if m.is_fainted():
		return false
	if fx.has("hp"):
		return m.hp < m.max_hp
	if fx.has("cure"):
		return fx.cure == "all" and m.status != "" or m.status == fx.cure
	if fx.has("level"):
		return m.level < Growth.MAX_LEVEL
	if fx.has("teach"):
		return not m.moves.has(fx.teach)
	if fx.has("evolve"):
		return evolution_by_item(m, id) != ""
	return false


## Aplica o efeito e devolve um texto curto do que aconteceu ("" se nada).
static func use(id: String, m: Mon) -> String:
	if not can_use(id, m):
		return ""
	var fx: Dictionary = Dex.item(id).get("effect", {})
	if fx.has("revive"):
		m.hp = maxi(1, m.max_hp / 2)
		return "%s se recuperou!" % m.display_name
	if fx.has("hp"):
		var before := m.hp
		m.hp = m.max_hp if str(fx.hp) == "full" else mini(m.max_hp, m.hp + int(fx.hp))
		return "%s recuperou %d de HP." % [m.display_name, m.hp - before]
	if fx.has("cure"):
		m.status = ""
		return "%s está curado." % m.display_name
	if fx.has("level"):
		m.add_exp(Growth.exp_for_level(m.growth, m.level + int(fx.level)) - m.xp)
		return "%s subiu para o nível %d!" % [m.display_name, m.level]
	if fx.has("teach"):
		if m.moves.size() < Mon.MAX_MOVES:
			m.moves.append(fx.teach)
			return "%s aprendeu %s!" % [m.display_name, Dex.move(fx.teach).get("name", fx.teach)]
		return ""
	if fx.has("evolve"):
		var from := m.display_name
		m.evolve(evolution_by_item(m, id))
		return "%s evoluiu para %s!" % [from, m.species]
	return ""


static func evolution_by_item(m: Mon, item_id: String) -> String:
	var evo: Dictionary = Dex.species(m.species).get("evolution", {})
	if String(evo.get("method", "")) == "item" and String(evo.get("item", "")) == item_id:
		return Dex.canon(String(evo.get("into", "")))
	return ""

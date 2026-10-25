class_name BattleEndTurn
extends RefCounted
## Fim de turno oficial (Gen 9), uma vez por rodada (BattleTurns), depois que todos em campo agiram.
## A arena cria um por luta (arena.end_turn) e BattleTurns._end_round chama run() antes das
## substituições de quem desmaiou (com opts.turn_mode false, a cada ROUND_SECS s).
##
## Ordem (Showdown "residual order" da Gen 9; dentro de cada passo pela Speed, arena.turns.speed_order,
## com Trick Room invertendo):
##   1. clima: conta a rodada (se acabou agora, não tira HP), areia 1/16, Rain Dish, Dry Skin, Solar Power
##   2. Future Sight  3. Wish
##   4. por lutador: Grassy Terrain 1/16, Shed Skin, Leftovers 1/16 / Black Sludge
##   5. Aqua Ring 1/16  6. Ingrain 1/16  7. Leech Seed 1/8 (para quem plantou)
##   8. veneno 1/8 / Toxic n/16 (Poison Heal cura 1/8)  9. queimadura 1/16  10. Curse 1/4
##   11. Wrap/Bind 1/8 (4-5 turnos)
##   12. fim de Taunt, Encore, Disable, Heal Block, Throat Chop; Yawn (dorme)
##   13. lado: Reflect, Light Screen, Safeguard, Mist, Tailwind
##   14. campo: Trick Room, Gravity, terrenos  15. Uproar
##   16. Speed Boost, Natural Cure/Regenerator/Pickup (adaptados)
##   17. o que dura só a rodada (Protect, Endure, Quick/Wide Guard, Roost, Follow Me)
##   18. sono/congelado/confusão de quem não segue a fila (a vez de quem segue conta em try_act)
## Frutinhas seguradas (Oran, Sitrus, Pecha, Persim) agem na hora, como no oficial (held_check).

const COL_POISON := Color(0.75, 0.35, 0.95)
const COL_BURN := Color(1.0, 0.45, 0.2)
const COL_SEED := Color(0.45, 0.85, 0.35)
const COL_CURSE := Color(0.6, 0.45, 0.8)
const COL_BIND := Color(0.85, 0.7, 0.5)
const COL_SAND := Color(0.85, 0.72, 0.42)
const COL_SLUDGE := Color(0.6, 0.35, 0.7)
const COL_END := Color(0.9, 0.9, 0.75)
## Itens segurados (no trainer_item, o mesmo campo que Fling/Knock Off/Trick usam).
const LEFTOVERS := "leftovers"
const BLACK_SLUDGE := "black_sludge"
## Frutinha de HP: id -> [limite (fração do HP máx.), cura (HP fixo se >= 1, fração se < 1)].
const HP_BERRIES := {"oran_berry": [0.5, 10.0], "sitrus_berry": [0.5, 0.25]}
## Frutinha de status: id -> status que cura.
const CURE_BERRIES := {"pecha_berry": ["poison", "toxic"], "persim_berry": ["confusion"]}
## Efeitos de rodada que acabam e o aviso no log (lado, campo, volátil).
const SIDE_ENDS := {
	"reflect": "O Reflect acabou.",
	"light_screen": "O Light Screen acabou.",
	"safeguard": "O Safeguard acabou.",
	"mist": "A névoa protetora sumiu.",
	"tailwind": "O vento a favor parou.",
}
const FIELD_ENDS := {
	"gravity": "A gravidade voltou ao normal.",
	"magic": "Os itens voltaram a funcionar.",
	"grassy": "O campo de grama sumiu.",
	"electric": "O campo elétrico sumiu.",
	"misty": "O campo de névoa sumiu.",
	"psychic": "O campo psíquico sumiu.",
	"wonder": "A Wonder Room acabou.",
}

var arena: Node
## Fins de turno já rodados.
var rounds := 0
## O que aconteceu no último fim de turno, na ordem: {step, who (BattleFighter ou null), amount}.
## Para os testes e o HUD.
var last_log: Array = []
## Ordem pela Speed do último fim de turno.
var last_order: Array = []


func _init(a: Node) -> void:
	arena = a


func _fx() -> BattleMoveEffects:
	var m = arena.get("moves")
	return m.effects if m else null


func _ab() -> BattleAbilities:
	return arena.get("abilities")


func _note(step: String, f: BattleFighter, amount := 0) -> void:
	last_log.append({"step": step, "who": f, "amount": amount})


func _say(text: String) -> void:
	_note("say:" + text, null)
	if arena.has_method("say"):
		arena.say(text)


## Quem está em campo agora, pela Speed (Trick Room inverte; empate no sorteio da rodada).
func _order() -> Array:
	var live: Array = arena.fighters.filter(func(g): return is_instance_valid(g) and g.active())
	var t = arena.get("turns")
	if t and t.has_method("speed_order"):
		return t.speed_order(live)
	return live


func _frac(f: BattleFighter, k: float) -> int:
	return maxi(1, int(f.max_hp * k))


# --- Roda ---


## Roda os efeitos de fim de turno na ordem oficial, uma vez.
func run() -> void:
	rounds += 1
	last_log = []
	var fx := _fx()
	var ab := _ab()
	var order := _order()
	last_order = order
	# 1. Clima
	var weather_on := false
	if ab:
		weather_on = ab.count_weather_round()
		if ab.weather_ended != "":
			_say(_weather_end_text(ab.weather_ended))
	if weather_on:
		for f in order:
			if f.active():
				var hp0: int = f.hp
				ab.weather_residual(f)
				if f.hp != hp0:
					_note("weather", f, f.hp - hp0)
	if fx:
		# 2. Future Sight  3. Wish
		for f in fx.end_turn_future():
			_note("future_sight", f)
		for f in fx.end_turn_wish():
			_note("wish", f)
	# 4. Grassy Terrain, Shed Skin, Leftovers / Black Sludge (por lutador)
	for f in order:
		if not f.active():
			continue
		if fx and fx.active(fx.field, "grassy") and fx.grounded(f):
			_heal(f, _frac(f, 1.0 / 16.0), "grama", "grassy")
		if ab and ab.shed_skin(f):
			_note("shed_skin", f)
		_leftovers(f)
	if fx:
		# 5. Aqua Ring  6. Ingrain
		for f in order:
			if f.active() and bool(fx.st(f).get("aqua_ring", false)):
				_heal(f, _frac(f, 1.0 / 16.0), "Aqua Ring", "aqua_ring")
		for f in order:
			if f.active() and bool(fx.st(f).get("ingrain", false)):
				_heal(f, _frac(f, 1.0 / 16.0), "raízes", "ingrain")
	# 7. Leech Seed
	for f in order:
		if f.active() and f.seeded:
			_leech(f)
	# 8. Veneno / Toxic  9. Queimadura
	for f in order:
		if f.active() and f.status in ["poison", "toxic"]:
			_poison(f)
	for f in order:
		if f.active() and f.status == "burn":
			_dmg(f, _frac(f, 1.0 / 16.0), "queimadura", COL_BURN, "burn")
	if fx:
		# 10. Curse  11. Wrap/Bind
		for f in order:
			if f.active() and bool(fx.st(f).get("cursed", false)):
				_dmg(f, _frac(f, 1.0 / 4.0), "maldição", COL_CURSE, "curse")
		for f in order:
			if f.active() and fx.active(fx.st(f), "bound"):
				_bind(f)
		# 12. Taunt, Encore, Disable, Heal Block, Throat Chop, Yawn
		for f in order:
			if f.active():
				_volatiles(f)
		# 13. Lado  14. Campo  15. Uproar
		_sides()
	_field()
	if fx and fx.count_round(fx.field, "uproar"):
		_say("O barulho acabou.")
	# 16. Speed Boost e o resto das habilidades de fim de turno
	if ab:
		for f in order:
			if f.active():
				ab.late_residual(f)
		ab.finish_round(order)
	# 17. O que dura só a rodada
	if fx:
		fx.end_turn_only()
	# 18. Sono/congelado/confusão de quem não segue a fila
	for f in order:
		if f.active() and not f.counts_on_turn():
			f.round_count()
	_show()


## Uma linha curta no HUD quando o fim de turno mexeu em alguém.
func _show() -> void:
	var any := last_log.any(func(e): return e.who != null)
	if any and arena.get("hud") and arena.hud.has_method("warn"):
		arena.hud.warn("Fim da rodada", COL_END)


# --- Passos ---


func _dmg(f: BattleFighter, n: int, why: String, col: Color, step: String) -> int:
	var d := f.residual_damage(n, why, col)
	_note(step, f, -d)
	return d


func _heal(f: BattleFighter, n: int, why: String, step: String) -> int:
	var h := f.residual_heal(n, why)
	if h > 0:
		_note(step, f, h)
	return h


## Leftovers +1/16; Black Sludge +1/16 no Veneno e -1/8 nos outros.
func _leftovers(f: BattleFighter) -> void:
	if not _holds(f):
		return
	match f.trainer_item:
		LEFTOVERS:
			_heal(f, _frac(f, 1.0 / 16.0), "Leftovers", "leftovers")
		BLACK_SLUDGE:
			if "poison" in f.types:
				_heal(f, _frac(f, 1.0 / 16.0), "Black Sludge", "black_sludge")
			else:
				_dmg(f, _frac(f, 1.0 / 8.0), "Black Sludge", COL_SLUDGE, "black_sludge")


## Leech Seed: 1/8 de quem foi semeado para quem plantou (ou quem está no lugar dele).
func _leech(f: BattleFighter) -> void:
	var to: BattleFighter = f.leech_source
	if not is_instance_valid(to) or not to.active():
		to = null
		var src_side := 1 - f.side
		if is_instance_valid(f.leech_source):
			src_side = f.leech_source.side
		for g in arena.fighters:
			if is_instance_valid(g) and g.active() and g.side == src_side:
				to = g
				break
	var d := _dmg(f, _frac(f, 1.0 / 8.0), "semente", COL_SEED, "leech_seed")
	if d > 0 and to != null:
		var ab := _ab()
		if ab and ab.drain_backfires(to, f, d):  # Liquid Ooze: a semente faz mal a quem plantou
			_note("liquid_ooze", to, -d)
		else:
			_heal(to, d, "semente", "leech_heal")


## Veneno 1/8; Toxic n/16 (n sobe a cada fim de turno). Poison Heal cura 1/8 no lugar.
func _poison(f: BattleFighter) -> void:
	var toxic := f.status == "toxic"
	if toxic:
		f.toxic_n = mini(f.toxic_n + 1, BattleFighter.TOXIC_MAX)
	var ab := _ab()
	if ab and ab.ability_of(f) == "poison_heal":
		if _heal(f, _frac(f, 1.0 / 8.0), "Poison Heal", "poison_heal") > 0:
			ab._fire(f, Color(0.5, 1.0, 0.6))
		return
	if toxic:
		_dmg(f, _frac(f, 1.0 / 16.0) * f.toxic_n, "Toxic", COL_POISON, "toxic")
	else:
		_dmg(f, _frac(f, 1.0 / 8.0), "veneno", COL_POISON, "poison")


## Wrap/Bind (e Fire Spin, Whirlpool, Sand Tomb...): conta o turno; se ainda preso, 1/8.
func _bind(f: BattleFighter) -> void:
	var fx := _fx()
	var s := fx.st(f)
	var src = s.get("bound_by")
	var nm := String(s.get("bound_move", "o golpe"))
	if not is_instance_valid(src) or not src.active():
		fx.free_bind(f)
		return
	if fx.count_round(s, "bound"):
		fx.free_bind(f)
		f.popup("Livrou-se de %s!" % nm, COL_BIND, 0.85)
		_note("bind_end", f)
		return
	_dmg(f, _frac(f, 1.0 / 8.0), nm, COL_BIND, "bind")


## Fim dos voláteis contados em turnos (ordem oficial: Taunt, Encore, Disable, Heal Block,
## Throat Chop, Yawn).
func _volatiles(f: BattleFighter) -> void:
	var fx := _fx()
	var s := fx.st(f)
	if fx.count_round(s, "taunt"):
		f.popup("A provocação passou.", COL_END, 0.8)
		_note("taunt_end", f)
	if fx.count_round(s, "encore"):
		fx.end_encore(f)
		f.popup("O bis acabou.", COL_END, 0.8)
		_note("encore_end", f)
	if fx.count_round(s, "disable"):
		fx.end_disable(f)
		f.popup("Golpe liberado!", COL_END, 0.8)
		_note("disable_end", f)
	if fx.count_round(s, "heal_block"):
		_note("heal_block_end", f)
	if fx.count_round(s, "magnet"):
		f.popup("O levitar acabou.", COL_END, 0.8)
		_note("magnet_end", f)
	if fx.count_round(s, "throat"):
		_note("throat_end", f)
	if fx.count_round(s, "yawn"):
		fx.yawn_sleep(f)
		_note("yawn", f)
	if BattleKanto.perish_tick(fx, f):
		_note("perish", f)
	BattleMore.end_turn(fx, f)


## Lado (Reflect, Light Screen, Safeguard, Mist, Tailwind): conta a rodada e avisa quem acabou.
func _sides() -> void:
	var fx := _fx()
	for side in 2:
		for k in SIDE_ENDS:
			if fx.count_round(fx.sides[side], k):
				_say(("Seu lado: " if side == 0 else "Lado adversário: ") + String(SIDE_ENDS[k]))


## Campo: Trick Room (BattleTurns.trick_room_rounds), Gravity e terrenos.
func _field() -> void:
	var t = arena.get("turns")
	if t and t.has_method("count_trick_room") and t.count_trick_room():
		_say("As dimensões voltaram ao normal.")
	var fx := _fx()
	if fx == null:
		return
	for k in FIELD_ENDS:
		if fx.count_round(fx.field, k):
			_say(String(FIELD_ENDS[k]))


static func _weather_end_text(w: String) -> String:
	match w:
		"sun":
			return "O sol enfraqueceu."
		"rain":
			return "A chuva parou."
		"sand":
			return "A tempestade de areia passou."
		"hail":
			return "A neve parou."
	return "O clima voltou ao normal."


# --- Itens segurados ---


func _holds(f: BattleFighter) -> bool:
	var fx := _fx()
	if fx and fx.active(fx.field, "magic"):
		return false  # Magic Room
	return is_instance_valid(f) and f.trainer_item != "" and not f.item_used


## Frutinha segurada que age sozinha, na hora (oficial): Oran (+10) e Sitrus (+1/4) com HP <= 1/2,
## Pecha contra veneno, Persim contra confusão. fighter.take_damage/apply_status chamam.
func held_check(f: BattleFighter) -> void:
	if not _holds(f) or not f.alive():
		return
	var id := f.trainer_item
	if HP_BERRIES.has(id):
		var row: Array = HP_BERRIES[id]
		var ab := _ab()
		var glut: bool = ab != null and ab.ability_of(f) == "gluttony"
		var limit := float(row[0]) + (BattleAbilities.GLUTTONY_BONUS if glut else 0.0)
		if f.hp * 1.0 > f.max_hp * limit:
			return
		var amt := float(row[1])
		_eat(f)
		var heal_n := int(amt) if amt >= 1.0 else maxi(1, int(f.max_hp * amt))
		if glut:
			heal_n = int(heal_n * BattleAbilities.GLUTTONY_HEAL)  # Gluttony: devora a frutinha
			ab._fire(f, Color(0.9, 0.7, 0.4))
		f.residual_heal(heal_n, _item_name(id))
	elif CURE_BERRIES.has(id):
		var cures: Array = CURE_BERRIES[id]
		if f.status in cures:
			_eat(f)
			f.clear_status()
			f.popup("%s curou!" % _item_name(id), Color(0.6, 1.0, 0.7), 0.85)
		elif "confusion" in cures and f.confusion_t > 0.0:
			_eat(f)
			f.confusion_t = 0.0
			f.popup("%s curou!" % _item_name(id), Color(0.6, 1.0, 0.7), 0.85)


func _eat(f: BattleFighter) -> void:
	f.item_used = true
	f.set_meta("ate_berry", true)  # Belch


static func _item_name(id: String) -> String:
	return String(Dex.item(id).get("name", id))

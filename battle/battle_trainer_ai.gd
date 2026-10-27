class_name BattleTrainerAI
extends RefCounted
## IA do treinador de um lado (pesquisa em docs/IA_TREINADOR.md): no começo de cada rodada decide trocas e
## o item do treinador, e escolhe quem entra no lugar de quem desmaiou. Usa a interface da arena
## (request_switch, request_trainer_item, bench_of; arena.trainer_ai[side]).
## Troca (como a "Smart Switching" do pokeemerald-expansion e os jogadores competitivos): só quem ainda tem
## HP para valer a pena sai, quando o matchup está ruim (leva >= 50% e tira < 30%, todos os golpes sem
## efeito, ou o atributo de ataque em -2) e há no banco alguém que aguenta o golpe da entrada e bate
## pelo menos parecido. Uma troca por lado por rodada, sem ping-pong, com chance de não trocar pelo
## nível da IA (think_scale), para não ficar previsível.
## Item: cura com HP baixo só se a cura faz sobreviver à rodada; cura status que atrapalha (sono,
## paralisia em quem é rápido, queimadura em atacante físico, veneno com HP ainda bom).
## Substituto: maior (dano que tira - dano que leva), com bônus de KO e de ser mais rápido.

## Matchup ruim: leva BAD_TAKE (fração do HP) e tira menos de BAD_DEAL; sai só com HP >= KEEP_HP.
const BAD_TAKE := 0.5
const BAD_DEAL := 0.3
const KEEP_HP := 0.4
const LOW_STAGE := -2
## Quem entra precisa levar no máximo IN_TAKE do HP e no máximo IN_RATIO do que o atual levaria.
const IN_TAKE := 0.6
const IN_RATIO := 0.6
const IN_DEAL := 0.8
## Não troca o mesmo Pokémon de novo antes de NO_PINGPONG rodadas.
const NO_PINGPONG := 2
## Cura: HP <= HEAL_AT.
const HEAL_AT := 0.35
const ROLL_MEAN := 0.925

var arena
var side := 0
## Rodada em que cada Mon trocou (sem ping-pong) e total de trocas (para testes e log).
var _swapped := {}
var switches := 0
var items := 0


func _init(a, s: int) -> void:
	arena = a
	side = s


## Opção por lado (opts.trainer_ai): bool vale para os dois; Array [lado 0, lado 1].
static func side_on(v, side: int) -> bool:
	if v is Array:
		return side < v.size() and bool(v[side])
	return bool(v)


func _rng() -> RandomNumberGenerator:
	return arena.rng


func _round() -> int:
	return int(arena.turns.round_n) if arena.get("turns") != null else 0


func mine() -> Array:
	return arena.fighters.filter(
		func(g): return is_instance_valid(g) and g.side == side and g.active() and g.on_field
	)


func foes() -> Array:
	return arena.fighters.filter(
		func(g): return is_instance_valid(g) and g.side != side and g.active() and g.on_field
	)


func _think() -> float:
	for f in mine():
		if f.ai != null:
			return float(f.ai.think_scale)
	return 1.0


## Chance de fazer a troca certa: 0,7 no think_scale 1 (mais esperto, mais vezes).
func _switch_chance() -> float:
	return clampf(1.1 - 0.4 * _think(), 0.3, 0.95)


# --- Estimativas (lutador em campo ou Mon do banco) ---


## {types, level, atk, spa, def, spd, spe, hp, max_hp, moves} de um lutador (com estágios) ou Mon.
static func unit_of(x) -> Dictionary:
	if x is BattleFighter:
		return {
			"types": x.types,
			"level": x.level,
			"atk": x.stat("atk"),
			"spa": x.stat("spa"),
			"def": x.stat("def"),
			"spd": x.stat("spd"),
			"spe": BattleTurns.order_speed(x),
			"hp": float(x.hp),
			"max_hp": float(x.max_hp),
			"moves": x.moves,
			"burn": x.status == "burn",
		}
	var m: Mon = x
	return {
		"types": m.types,
		"level": m.level,
		"atk": float(m.stats.get("atk", 1)),
		"spa": float(m.stats.get("spa", 1)),
		"def": float(m.stats.get("def", 1)),
		"spd": float(m.stats.get("spd", 1)),
		"spe": float(m.stats.get("spe", 1)) * (0.5 if m.status == "paralysis" else 1.0),
		"hp": float(BattleFighter.hp_from_mon(m.hp)),
		"max_hp": float(BattleFighter.hp_from_mon(m.max_hp)),
		"moves": m.moves,
		"burn": m.status == "burn",
	}


## Dano médio de um golpe (fórmula Gen 5+ sem os detalhes de campo), já com o ritmo da arena.
func est(a: Dictionary, d: Dictionary, mv: Dictionary) -> float:
	var power := float(mv.get("power", 0))
	if power <= 0.0:
		return 0.0
	var eff := Dex.effectiveness(String(mv.get("type", "")), d.types)
	if eff <= 0.0:
		return 0.0
	var phys := String(mv.get("category", "")) == "physical"
	var at := float(a.atk if phys else a.spa)
	if phys and bool(a.burn):
		at *= 0.5
	var df := maxf(float(d.def if phys else d.spd), 1.0)
	var base := ((2.0 * float(a.level) / 5.0 + 2.0) * power * at / df) / 50.0 + 2.0
	var stab := 1.5 if mv.get("type") in a.types else 1.0
	var acc := float(mv.get("accuracy", 100)) / 100.0
	var hits := float(BattleMoves.hits_of(mv))
	var pace := float(arena.get("damage_pace")) if arena.get("damage_pace") != null else 1.0
	return base * stab * eff * ROLL_MEAN * clampf(acc, 0.0, 1.0) * hits * pace


func best(a: Dictionary, d: Dictionary) -> float:
	var b := 0.0
	for id in a.moves:
		b = maxf(b, est(a, d, Dex.move(String(id))))
	return b


## {deal, take, faster}: maior fração do HP que ele tira de um inimigo (até 1), maior fração do
## próprio HP que um inimigo tira dele, e se é mais rápido que todos.
func matchup(u: Dictionary, against: Array) -> Dictionary:
	var deal := 0.0
	var take := 0.0
	var faster := true
	for o in against:
		var e := unit_of(o)
		# Fractions of the Mon's own HP (the fighter has HP_MULT times it), so the thresholds keep
		# their meaning with the doubled battle HP.
		deal = maxf(deal, minf(best(u, e) * BattleFighter.HP_MULT / maxf(float(e.hp), 1.0), 1.0))
		take = maxf(take, best(e, u) * BattleFighter.HP_MULT / maxf(float(u.hp), 1.0))
		if float(e.spe) >= float(u.spe):
			faster = false
	return {"deal": deal, "take": take, "faster": faster}


# --- Decisões ---


## Começo da rodada (arena.begin_of_round): itens e no máximo uma troca.
func round_start() -> void:
	if arena.get("state") != "fight":
		return
	var against := foes()
	if against.is_empty():
		return
	var busy := {}
	for f in mine():
		var it := item_for(f)
		if it != "" and arena.request_trainer_item(side, it, f):
			busy[f] = true
			items += 1
	var pick := {}
	var gain := 0.0
	for f in mine():
		if busy.has(f):
			continue
		var c := switch_for(f, against)
		if not c.is_empty() and float(c.gain) > gain:
			gain = float(c.gain)
			pick = c
	if pick.is_empty() or _rng().randf() >= _switch_chance():
		return
	var out: BattleFighter = pick.out
	var m: Mon = arena.bench_of(side)[int(pick.idx)]
	if arena.request_switch(side, out, int(pick.idx)):
		_swapped[out.mon] = _round()
		_swapped[m] = _round()
		switches += 1


## Troca para `f`: {out, idx (bench_of), gain} ou {} se não vale.
func switch_for(f: BattleFighter, against: Array) -> Dictionary:
	if f.mon == null or _round() - int(_swapped.get(f.mon, -99)) <= NO_PINGPONG:
		return {}
	if float(f.hp) / maxf(float(f.max_hp), 1.0) < KEEP_HP:
		return {}  # quem já está fraco fica e bate (sacrifício), não vale a troca
	if arena.moves.effects.cant_escape(f):
		return {}
	var cur := matchup(unit_of(f), against)
	var phys := f.stat("atk") >= f.stat("spa")
	var stage := int(f.stages.get("atk" if phys else "spa", 0))
	var bad: bool = (
		(float(cur.take) >= BAD_TAKE and float(cur.deal) < BAD_DEAL)
		or float(cur.deal) <= 0.0
		or stage <= LOW_STAGE
	)
	if not bad:
		return {}
	var bench: Array = arena.bench_of(side)
	var best_c := {}
	var best_g := 0.0
	for k in bench.size():
		var m: Mon = bench[k]
		var u := unit_of(m)
		var mu := matchup(u, against)
		if float(mu.take) > IN_TAKE or float(mu.take) > float(cur.take) * IN_RATIO + 0.05:
			continue
		if float(mu.deal) < float(cur.deal) * IN_DEAL:
			continue
		var g := (
			float(cur.take)
			- float(mu.take)
			+ 0.7 * (float(mu.deal) - float(cur.deal))
			+ (0.1 if mu.faster else 0.0)
			+ (0.3 if stage <= LOW_STAGE else 0.0)
		)
		if g > best_g:
			best_g = g
			best_c = {"out": f, "idx": k, "gain": g}
	return best_c


## Item do treinador para `f` agora ("" = nenhum). Um por Mon por luta.
func item_for(f: BattleFighter) -> String:
	var id := String(f.trainer_item)
	if id == "" or f.item_used or not f.alive():
		return ""
	var e: Dictionary = Dex.item(id).get("effect", {})
	var hp := float(f.hp) / maxf(float(f.max_hp), 1.0)
	if e.has("hp") and hp <= HEAL_AT:
		var heal := (
			float(f.max_hp) if str(e.hp) == "full" else float(BattleFighter.hp_from_mon(int(e.hp)))
		)
		heal = minf(heal, float(f.max_hp - f.hp))
		if incoming(f) < float(f.hp) + heal:
			return id
		return ""  # morre na rodada mesmo curado: melhor atacar
	if e.has("cure") and f.status != "" and (String(e.cure) == "all" or f.status == String(e.cure)):
		if _status_hurts(f):
			return id
	return ""


## Dano esperado em `f` nesta rodada: o maior golpe de um inimigo e metade do segundo (na dupla os
## dois nem sempre miram nele).
func incoming(f: BattleFighter) -> float:
	var me := unit_of(f)
	var list: Array = []
	for o in foes():
		list.append(best(unit_of(o), me))
	list.sort()
	list.reverse()
	var tot := 0.0
	for k in list.size():
		tot += float(list[k]) * (1.0 if k == 0 else 0.5)
	return tot


func _status_hurts(f: BattleFighter) -> bool:
	match f.status:
		"sleep":
			return true
		"paralysis":
			return true
		"burn":
			return f.stat("atk") >= f.stat("spa")
		"poison", "toxic":
			return float(f.hp) / maxf(float(f.max_hp), 1.0) > 0.4
	return false


## Substituto de quem desmaiou (arena._replacement): índice em bench_of(side), -1 = a arena escolhe.
func pick_replacement(_slot: int) -> int:
	var bench: Array = arena.bench_of(side)
	var against := foes()
	if bench.is_empty() or against.is_empty():
		return -1
	var best_k := -1
	var best_s := -INF
	for k in bench.size():
		var u := unit_of(bench[k])
		var mu := matchup(u, against)
		var s := float(mu.deal) - 0.7 * minf(float(mu.take), 1.5)
		if float(mu.deal) >= 1.0:
			s += 0.3
		if mu.faster:
			s += 0.15
		s += 0.2 * float(u.hp) / maxf(float(u.max_hp), 1.0)
		if s > best_s:
			best_s = s
			best_k = k
	return best_k

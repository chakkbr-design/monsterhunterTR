class_name BattleTactics
extends RefCounted
## Escolha de golpe e alvo no estilo VGC (pesquisa em docs/IA_VGC.md): cada par (golpe, alvo) ganha
## uma pontuação aditiva, como as flags de IA do pokeemerald-expansion, e o maior vence.
## Dano: fração do HP atual do alvo (até 1) mais bônus de KO, vezes o valor do alvo (quanto ele ameaça
## o meu lado). Dupla: golpe de área soma os alvos com 0,75x e desconta o parceiro; foco no alvo que o
## parceiro também mira quando os dois juntos derrubam; evita o alvo que o parceiro já derruba sozinho.
## Status: Protect com ameaça de KO (nunca duas rodadas seguidas), Tailwind quando o meu lado é mais
## lento, Helping Hand quando faz o parceiro derrubar, Follow Me com o parceiro ameaçado, paralisia em
## quem é mais rápido, queimadura em atacante físico, sono, buff só em rodada segura, cura com HP baixo.
## Comando (OFENSIVO/DEFENSIVO/SUPORTE), Natureza (temperamento) e ânimo (Fúria/Pânico) pesam no fim.
## Golpe que não está na lista acima cai nas regras antigas de BattleAI (status_ok, status_weight).

## Bônus de KO (em frações de HP) e de golpe de prioridade que derruba alguém mais rápido.
const KO_BONUS := 0.8
const PRIORITY_KO := 0.6
## Peso da ameaça do alvo no valor dele e bônus de quem faz suporte (Tailwind, Follow Me...).
const THREAT_VALUE := 0.6
const SUPPORT_VALUE := 0.25
const SUPPORT_SPECIALS := ["tailwind", "follow_me", "helping_hand", "trick_room", "fake_out"]
## Foco: os dois juntos derrubam (bônus) ou o parceiro já derruba sozinho (o meu golpe vale menos).
const FOCUS_BONUS := 0.6
const OVERKILL_MULT := 0.05
## Alvo que deve usar Protect agora (ameaçado e com Protect livre): golpe de alvo único vale menos.
const PROTECT_GUESS := 0.8
## Acertar o parceiro (Earthquake) custa CUT_PARTNER x a fração de HP dele; derrubar o parceiro, mais.
const CUT_PARTNER := 1.5
const CUT_PARTNER_KO := 1.5
## Protect: ameaça (dano esperado / HP) a partir de PROTECT_FROM; repetir na rodada seguinte, quase nunca.
const PROTECT_FROM := 0.5
const PROTECT_REPEAT := 0.05
## Buff com HP abaixo de SAFE_HP vale 0,3x.
const SAFE_HP := 0.6
## Ruído para não ficar previsível (+-NOISE na pontuação).
const NOISE := 0.08
const NOISE_STATUS := 0.35
## Buff: SETUP_REL x a pontuação do melhor ataque (peso 0,4 de BattleAI.status_weight = 1), vezes o
## quanto a rodada é segura; com o ruído maior do status ele vence o ataque em ~1 de 4 rodadas seguras.
const SETUP_REL := 0.85
## Outros status: entram com chance peso x OTHER_CHANCE valendo OTHER_SCORE.
const OTHER_CHANCE := 1.2
const OTHER_SCORE := 0.5
## Melhor opção só um status abaixo disto, com golpe de dano no repertório: deixa BattleAI decidir.
const FILLER_MIN := 0.2
## Comandos (iguais aos de BattleAI): multiplicadores de [dano, Protect, buff, suporte/status].
const CMD_MULT := [
	[1.15, 0.5, 0.3, 0.4], [0.9, 1.4, 1.3, 1.0], [0.85, 1.1, 1.0, 1.5], [1.0, 1.0, 1.0, 1.0]
]
const HEALS := ["roost", "heal_weather", "rest", "swallow", "life_dew", "wish"]

var ai
var f: BattleFighter
## Última rodada em que usou Protect (Protect seguido falha no oficial; aqui a IA evita).
var protect_round := -99
## Último golpe escolhido aqui e o alvo (para status_ok e testes).
var last_pick := ""
var last_target: BattleFighter = null
var last_scores := {}


func _init(battle_ai) -> void:
	ai = battle_ai
	f = battle_ai.f


## Ligado para todo lutador de treinador e do jogador, com rodadas; o selvagem segue a IA antiga.
## opts.vgc_ai = false desliga (testes antigos); [true, false] liga só no lado 0 (comparar com a antiga).
static func enabled_for(fighter: BattleFighter) -> bool:
	var a = fighter.arena
	if a == null or not side_on(a.get("opts").get("vgc_ai", true), fighter.side):
		return false
	var turns = a.get("turns")
	if turns == null or not turns.on:
		return false  # ritmo antigo (sem rodadas): a IA antiga
	return not (String(a.get("kind")) == "wild" and fighter.side == 1)


## Opção por lado: bool vale para os dois; Array [lado 0, lado 1].
static func side_on(v, side: int) -> bool:
	if v is Array:
		return side < v.size() and bool(v[side])
	return bool(v)


func _round() -> int:
	var turns = f.arena.get("turns")
	return int(turns.round_n) if turns != null else int(Time.get_ticks_msec() / 4000)


## Escolhe o golpe entre `avail` e mira o alvo (f.opponent). "" = deixa a regra antiga decidir.
func choose(avail: Array) -> String:
	last_scores = {}
	last_pick = ""
	var foes: Array = f.arena.targets_of(f)
	if foes.is_empty() or avail.is_empty():
		return ""
	var p: BattleFighter = ai.partner()
	var ctx := {"foes": foes, "p": p, "threat": incoming(f) / maxf(float(f.hp), 1.0)}
	var hit := 0.0
	for id in f.moves:
		var mv := Dex.move(String(id))
		if float(mv.get("power", 0)) > 0.0:
			hit = maxf(hit, float(_score_damage(String(id), mv, ctx).score))
	ctx["hit"] = hit
	var best := ""
	var best_t: BattleFighter = null
	var best_s := -INF
	var rng: RandomNumberGenerator = f.arena.rng
	var cands: Array = []
	var cats := {}
	for id in avail:
		var r := score_move(String(id), ctx)
		var s := float(r.score)
		if s <= 0.0:
			continue
		var nz := NOISE if int(r.get("cat", 0)) <= 1 else NOISE_STATUS
		s *= 1.0 + rng.randf_range(-nz, nz)
		last_scores[String(id)] = s
		cats[String(id)] = int(r.get("cat", 0))
		cands.append([String(id), r.target])
		if s > best_s:
			best_s = s
			best = String(id)
			best_t = r.target
	if best == "":
		return ""
	# Só status fraco à mão com golpe de dano esperando o cooldown: a regra antiga decide (espera).
	if best_s < FILLER_MIN and int(cats.get(best, 0)) >= 2 and ai._has_connecting_move():
		return ""
	if rng.randf() < ai.error_chance() and cands.size() > 1:
		var c: Array = cands[rng.randi() % cands.size()]
		best = c[0]
		best_t = c[1]
	if is_instance_valid(best_t) and best_t.active() and best_t.side != f.side:
		f.opponent = best_t
		ai.retarget_t = maxf(ai.retarget_t, BattleTurns.ROUND_SECS + 0.5)
	last_pick = best
	last_target = best_t
	return best


## Golpe usado (BattleAI.note_used): marca a rodada do Protect.
func note_used(id: String) -> void:
	if String(Dex.move(id).get("special", "")) == "protect":
		protect_round = _round()


func protected_last_round() -> bool:
	return protect_round >= _round() - 1


# --- Estimativas ---


func _dmg(user: BattleFighter, t: BattleFighter, mv: Dictionary) -> float:
	if not is_instance_valid(t) or not t.active():
		return 0.0
	return f.arena.moves.expected_damage(user, t, mv, false)


## Maior dano esperado de `user` em `t` com um golpe só.
func best_on(user: BattleFighter, t: BattleFighter) -> float:
	var b := 0.0
	for id in user.moves:
		var mv := Dex.move(String(id))
		if float(mv.get("power", 0)) > 0.0:
			b = maxf(b, _dmg(user, t, mv))
	return b


## Dano que `me` deve levar nesta rodada: o melhor golpe de um inimigo e metade do segundo (na dupla
## os dois nem sempre miram nele).
func incoming(me: BattleFighter) -> float:
	var list: Array = []
	for foe in f.arena.targets_of(me):
		list.append(best_on(foe, me))
	list.sort()
	list.reverse()
	var tot := 0.0
	for k in list.size():
		tot += float(list[k]) * (1.0 if k == 0 else 0.5)
	return tot


## Quanto o alvo ameaça o meu lado (fração do HP do mais ferido por ele, até 1) e se faz suporte.
func value_of(t: BattleFighter, p: BattleFighter) -> float:
	var thr := 0.0
	for me in [f, p]:
		if me != null and is_instance_valid(me) and me.active():
			thr = maxf(thr, minf(best_on(t, me) / maxf(float(me.hp), 1.0), 1.0))
	var v := 1.0 + THREAT_VALUE * thr
	for id in t.moves:
		if String(Dex.move(String(id)).get("special", "")) in SUPPORT_SPECIALS:
			v += SUPPORT_VALUE
			break
	return v


## Ordem da rodada: `a` age antes de `b` (Speed efetiva; Trick Room inverte).
func faster(a: BattleFighter, b: BattleFighter) -> bool:
	var sa := BattleTurns.order_speed(a)
	var sb := BattleTurns.order_speed(b)
	var turns = f.arena.get("turns")
	if turns != null and turns.trick_room():
		return sa < sb
	return sa > sb


func _frac(d: float, t: BattleFighter, val: float) -> float:
	var hp := maxf(float(t.hp), 1.0)
	return (minf(d / hp, 1.0) + (KO_BONUS if d >= hp else 0.0)) * val


## O alvo deve usar Protect agora: tem Protect livre e o meu lado o derruba nesta rodada.
func _likely_protect(t: BattleFighter, p: BattleFighter) -> bool:
	if not t.moves.any(func(m): return String(Dex.move(String(m)).get("special", "")) == "protect"):
		return false
	if t.ai != null and t.ai.get("tactics") != null and t.ai.tactics.protected_last_round():
		return false
	var dmg := best_on(f, t) + (best_on(p, t) if p != null else 0.0)
	return dmg >= float(t.hp)


## Golpe elétrico/água de alvo único mirado em quem tem parceiro com Lightning Rod/Storm Drain: vai
## para o parceiro dele.
func _redirected(mv: Dictionary, t: BattleFighter, foes: Array) -> BattleFighter:
	var ab = f.arena.get("abilities")
	if ab == null or not ab.has_method("ability_of"):
		return t
	var ty := String(mv.get("type", ""))
	for o in foes:
		if o == t:
			continue
		var a := String(ab.ability_of(o))
		if (a == "lightning_rod" and ty == "electric") or (a == "storm_drain" and ty == "water"):
			return o
	return t


# --- Pontuação ---


## {score, target} de um golpe. score <= 0 = não usar agora.
func score_move(id: String, ctx: Dictionary) -> Dictionary:
	var mv := Dex.move(id)
	if mv.is_empty():
		return {"score": 0.0, "target": null}
	var r: Dictionary
	var cat := 0
	if float(mv.get("power", 0)) > 0.0:
		r = _score_damage(id, mv, ctx)
	else:
		r = _score_status(id, mv, ctx)
		cat = int(r.get("cat", 3))
	var mode: int = ai.ally_mode()
	var s := float(r.score) * float(CMD_MULT[clampi(mode, 0, 3)][cat])
	var temper := BattleProfile.temper(f.mon)
	if cat == 0:
		s *= 1.0 + 0.1 * temper
	elif cat == 1:
		s *= 1.0 - 0.25 * temper
	if f.mood_state == "fury" and cat != 0:
		s *= 0.2
	elif f.mood_state == "panic" and cat == 1:
		s *= 1.5
	return {"score": s, "target": r.target, "cat": cat}


func _score_damage(id: String, mv: Dictionary, ctx: Dictionary) -> Dictionary:
	var foes: Array = ctx.foes
	var p: BattleFighter = ctx.p
	var mt := BattleMoves.multi_target(mv)
	if mt != "":
		var mult := BattleMoves.SPREAD_MULT if foes.size() >= 2 else 1.0
		var s := 0.0
		var top: BattleFighter = null
		var top_s := -INF
		for t in foes:
			var v := _frac(_dmg(f, t, mv) * mult, t, value_of(t, p))
			s += v
			if v > top_s:
				top_s = v
				top = t
		if mt == "all_other_pokemon" and p != null:
			var dp := _dmg(f, p, mv) * mult
			var php := maxf(float(p.hp), 1.0)
			s -= CUT_PARTNER * minf(dp / php, 1.0) + (CUT_PARTNER_KO if dp >= php else 0.0)
		return {"score": s, "target": top}
	var best_s := -INF
	var best_t: BattleFighter = null
	var prio := BattleTurns.priority_of(f, id)
	var pint := ""
	if p != null and p.ai != null:
		pint = String(p.ai.intent)
	for t in foes:
		var real := _redirected(mv, t, foes)
		var d := _dmg(f, real, mv)
		var val := value_of(real, p)
		var s := _frac(d, real, val)
		if d <= 0.0:
			s = 0.0
		if prio > 0 and d >= float(real.hp) and faster(real, f):
			s += PRIORITY_KO * val
		if String(mv.get("special", "")) == "fake_out" and d > 0.0:
			s += 0.7 * val
		var ef = mv.get("effect")
		if ef is Dictionary and ef.has("status") and not bool(ef.get("self", false)):
			if ai._status_lands(real, String(ef.status), false):
				s += 0.15 * float(ef.get("chance", 100)) / 100.0
		# Foco com o parceiro: ele mira o mesmo alvo nesta rodada.
		if pint != "" and p.opponent == real and float(Dex.move(pint).get("power", 0)) > 0.0:
			var pd := _dmg(p, real, Dex.move(pint))
			if pd >= float(real.hp) * 1.05:
				s = OVERKILL_MULT * val  # sobra: só vale se o golpe do parceiro falhar
			elif pd + d >= float(real.hp):
				s += FOCUS_BONUS * val
		if _likely_protect(real, p):
			s *= PROTECT_GUESS
		if s > best_s:
			best_s = s
			best_t = real
	return {"score": maxf(best_s, 0.0), "target": best_t}


## cat: 1 Protect, 2 buff, 3 suporte/status.
func _score_status(id: String, mv: Dictionary, ctx: Dictionary) -> Dictionary:
	var foes: Array = ctx.foes
	var p: BattleFighter = ctx.p
	var thr: float = ctx.threat
	var hp := float(f.hp) / maxf(float(f.max_hp), 1.0)
	var sp := String(mv.get("special", ""))
	var no := {"score": 0.0, "target": null, "cat": 3}
	if not f.arena.moves.effects.usable(f, mv):
		return no
	match sp:
		"protect", "wide_guard":
			if protected_last_round():
				return {"score": PROTECT_REPEAT * thr, "target": null, "cat": 1}
			if sp == "wide_guard" and not _foes_spread(foes):
				return no
			if thr < PROTECT_FROM:
				return {"score": 0.0, "target": null, "cat": 1}
			var s := minf(thr, 1.5) * 0.9
			if p != null:
				for t in foes:
					if best_on(p, t) >= float(t.hp):
						s += 0.3  # o parceiro derruba quem me ameaça
						break
			if sp == "wide_guard":
				s *= 0.8
			return {"score": s, "target": null, "cat": 1}
		"tailwind":
			var turns = f.arena.get("turns")
			if (
				f.arena.moves.effects.side_active(f.side, "tailwind")
				or (turns != null and turns.trick_room())
			):
				return no
			var slow := 0
			for me in [f, p]:
				if me != null and foes.any(func(t): return faster(t, me)):
					slow += 1
			if slow == 0:
				return no
			return {"score": 0.45 + 0.35 * slow + (0.3 if ai.round_k <= 1 else 0.0), "target": null}
		"trick_room":
			var tr: bool = f.arena.turns.trick_room() if f.arena.get("turns") != null else false
			var slower := 0
			for me in [f, p]:
				if (
					me != null
					and foes.all(
						func(t): return BattleTurns.order_speed(t) > BattleTurns.order_speed(me)
					)
				):
					slower += 1
			if tr == (slower > 0):
				return no
			return {"score": 0.9, "target": null}
		"helping_hand":
			if p == null or p.ai == null or String(p.ai.intent) == "":
				return no
			var pmv := Dex.move(String(p.ai.intent))
			var pt: BattleFighter = p.opponent
			if float(pmv.get("power", 0)) <= 0.0 or not is_instance_valid(pt) or not pt.active():
				return no
			var pd := _dmg(p, pt, pmv)
			if pd < float(pt.hp) and pd * 1.5 >= float(pt.hp):
				return {"score": 1.0, "target": null}
			return {"score": 0.4 * minf(pd / maxf(float(pt.hp), 1.0), 1.0), "target": null}
		"follow_me":
			if p == null or hp < 0.5:
				return no
			var pthr := incoming(p) / maxf(float(p.hp), 1.0)
			return {"score": 0.8 if pthr >= 0.6 else 0.0, "target": null}
	if sp in HEALS or (sp == "" and String(mv.get("kind", "")) == "heal"):
		var ok = f.arena.moves.effects.ai_worth(f, mv)
		if hp < 0.45 and ok != false:
			return {"score": 0.75, "target": null}
		return no
	if String(mv.get("kind", "")) == "self_buff":
		if not ai.status_ok(id, true):
			return {"score": 0.0, "target": null, "cat": 2}
		# Comparado com o melhor ataque desta rodada (SETUP_REL dele para o Swords Dance, peso 0,4).
		var hit := float(ctx.get("hit", 0.0))
		var w := float(ai.status_weight(id)) / 0.4 * SETUP_REL * (hit if hit > 0.0 else 0.5)
		if String(mv.get("stat", "")) == "spe" and foes.all(func(t): return faster(f, t)):
			w *= 0.25  # já sou o mais rápido
		# Rodada segura: quantos golpes eu aguento (1 / ameaça); com menos de 1,5 o buff não paga.
		var safe := clampf((1.0 / maxf(thr, 0.01) - 1.5) / 1.5, 0.0, 1.0)
		# Já derrubo alguém em até 2 golpes: o buff vale metade.
		if foes.any(func(t): return best_on(f, t) * 2.0 >= float(t.hp)):
			w *= 0.5
		return {"score": w * safe * (1.0 if hp > SAFE_HP else 0.3), "target": null, "cat": 2}
	var ef = mv.get("effect")
	if (
		sp == "thunder_wave"
		or (ef is Dictionary and ef.has("status") and not ef.get("self", false))
	):
		var st := "paralysis" if sp == "thunder_wave" else String(ef.status)
		var best := 0.0
		var bt: BattleFighter = null
		for t in foes:
			if sp == "thunder_wave" and "ground" in t.types:
				continue
			if not ai._status_lands(t, st, bool(mv.get("powder", false))):
				continue
			var w := _status_value(st, t, p)
			if float(t.hp) / maxf(float(t.max_hp), 1.0) < 0.3:
				w *= 0.3
			w *= value_of(t, p) * 0.8
			if w > best:
				best = w
				bt = t
		return {"score": best, "target": bt}
	# Resto (telas, Taunt, Spikes...): entra na disputa só às vezes, pelo peso antigo de BattleAI.
	if (
		ai.status_ok(id, ai._has_connecting_move())
		and f.arena.rng.randf() < float(ai.status_weight(id)) * OTHER_CHANCE
	):
		return {"score": OTHER_SCORE, "target": null}
	return no


func _status_value(st: String, t: BattleFighter, p: BattleFighter) -> float:
	match st:
		"sleep":
			return 0.85
		"paralysis":
			for me in [f, p]:
				if me != null and faster(t, me):
					return 0.7
			return 0.3
		"burn":
			return 0.75 if t.stat("atk") > t.stat("spa") * 1.1 else 0.2
		"poison", "toxic":
			return 0.35
		"confusion":
			return 0.3
	return 0.25


func _foes_spread(foes: Array) -> bool:
	for t in foes:
		for id in t.moves:
			var mv := Dex.move(String(id))
			if float(mv.get("power", 0)) > 0.0 and BattleMoves.multi_target(mv) != "":
				return true
	return false

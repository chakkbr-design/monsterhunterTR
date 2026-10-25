class_name BattleMoreA
extends RefCounted
## Golpes da Gen 2-9 (parte A: físicos e metade dos de status; tools/moves_more_a.py).
## Ganchos chamados por BattleMore (battle_more.gd); fx = BattleMoveEffects (fx.st(f), fx.set_rounds...).
## Estado de lutador em fx.st(f): glaive, salted, jaw/jaw_with, electrify, grudge, kshield, bide, smacked,
## protect_fx, foresight; de lado em fx.sides: aurora_veil, crafty_shield; do campo em fx.field: plasma,
## fairy_lock, fusion_flare_t. Contados em rodadas no end_turn (set_rounds / count_round).

## Glaive Rush: vulnerável por este tempo ou até o próximo golpe.
const GLAIVE_SECS := 3.0
## Anchor Shot / Spirit Shackle: imobilizado no lugar (além de não poder trocar nem fugir).
const PIN_SECS := 2.0
## Jaw Lock: distância máxima entre os dois e duração em rodadas.
const LEASH := 2.4
const JAW_TURNS := 4
## Bide guarda o dano por 2 rodadas e devolve o dobro.
const BIDE_TURNS := 2
const BIDE_MULT := 2
## Fusion Bolt dobra se o Fusion Flare saiu há pouco (qualquer lado).
const FUSION_WINDOW := 4.0
## Thousand Arrows deixa o alvo no chão por estas rodadas.
const SMACK_TURNS := 5
const FAIRY_LOCK_TURNS := 2
## Bolt Beak / Fishious Rend no modo de energia: o alvo parado há mais que isto "ainda não agiu".
const IDLE_SECS := 2.5
const SOUND := ["clangorous_soul", "confide", "grass_whistle"]
const CONTACT_KINDS := ["dash", "arc", "multi_arc", "whip"]
## Natural Gift: tipo da frutinha (o poder é 80 em todas as que existem aqui).
const BERRY_TYPE := {
	"cheri_berry": "fire",
	"chesto_berry": "water",
	"pecha_berry": "electric",
	"rawst_berry": "grass",
	"aspear_berry": "ice",
	"leppa_berry": "fighting",
	"oran_berry": "poison",
	"persim_berry": "ground",
	"lum_berry": "flying",
	"sitrus_berry": "psychic",
	"razz_berry": "steel",
	"figy_berry": "bug",
	"wiki_berry": "rock",
	"mago_berry": "ghost",
	"aguav_berry": "dragon",
	"iapapa_berry": "dark",
}
const BERRY_POWER := 80.0
## Cores dos avisos.
const COL_FIELD := Color(0.8, 0.9, 1.0)
const COL_HOLD := Color(0.85, 0.85, 0.85)
const COL_SALT := Color(0.95, 0.95, 0.95)
const COL_TETHER := Color(0.7, 0.45, 0.85)

# --- Ajudantes ---


## O golpe encosta no alvo (física de perto), para King's Shield, Baneful Bunker, Beak Blast.
static func _contact(mv: Dictionary) -> bool:
	return (
		String(mv.get("category", "")) == "physical" and String(mv.get("kind", "")) in CONTACT_KINDS
	)


static func _id_has(f: BattleFighter, part: String) -> bool:
	return is_instance_valid(f) and part in String(f.body_id())


## Frutinha segurada que o Natural Gift conhece ("" = nenhuma).
static func _berry(fx: BattleMoveEffects, user: BattleFighter) -> String:
	if fx._has_item(user) and BERRY_TYPE.has(user.trainer_item):
		return user.trainer_item
	return ""


## Bolt Beak / Fishious Rend: o usuário chega antes do alvo. No modo VGC, o alvo ainda não agiu na
## rodada; no resto, ele está no meio de um golpe ou parado há mais de IDLE_SECS.
static func _moved_first(fx: BattleMoveEffects, target: BattleFighter) -> bool:
	var ts := fx.st(target)
	var t = fx.arena.get("turns")
	if t != null and bool(t.on):
		return int(ts.get("act_round", -1)) != fx._round_id()
	return (
		target.prepare_t > 0.0
		or target.dash_t > 0.0
		or fx.now - float(ts.get("move_t", -99.0)) > IDLE_SECS
	)


## Quantos da equipe do usuário já desmaiaram (Last Respects).
static func _fallen(fx: BattleMoveEffects, user: BattleFighter) -> int:
	var n := 0
	for m in fx._party_of(user):
		if m is Mon and m != user.mon and m.hp <= 0:
			n += 1
	return n


## O primeiro lutador ativo da arena / do lado (para contar o que é do campo ou do lado uma vez só).
static func _first(fx: BattleMoveEffects, side := -1) -> BattleFighter:
	for g in fx.arena.fighters:
		if is_instance_valid(g) and g.active() and (side < 0 or g.side == side):
			return g
	return null


static func _snow(fx: BattleMoveEffects) -> bool:
	return fx.weather() in ["hail", "snow"]


# --- Gancho de usable() ---


## Golpe que não pode sair agora: texto do motivo ("" = pode). A IA também consulta.
static func blocked(fx: BattleMoveEffects, user: BattleFighter, mv: Dictionary) -> String:
	var s := fx.st(user)
	var id := String(mv.get("id", ""))
	var sp := String(mv.get("special", ""))
	if fx.active(s, "throat") and id in SOUND:
		return "Garganta ferida!"
	if fx.active(s, "bide") and sp != "bide":
		return "Guardando energia!"
	match sp:
		"bide":
			if fx.active(s, "bide"):
				return "Já está guardando!"
		"no_repeat":
			if String(s.last) == id:
				return "Não dá duas vezes seguidas!"
		"double_shock":
			if not "electric" in user.types:
				return "Não é mais Elétrico!"
		"natural_gift":
			if _berry(fx, user) == "":
				return "Sem frutinha!"
		"aurora_veil":
			if not _snow(fx):
				return "Só na neve!"
			if fx.active(fx._sd(user.side), "aurora_veil"):
				return "Já está ativo!"
		"clangorous_soul":
			if user.hp <= user.max_hp / 3:
				return "HP insuficiente!"
		"fillet_away":
			if user.hp <= user.max_hp / 2:
				return "HP insuficiente!"
		"ally_buff":
			if fx.partner(user) == null:
				return "Mas falhou!"
		"gear_up":
			if fx._ability(user) not in ["plus", "minus"] and not _mate_plus(fx, user):
				return "Mas falhou!"
	return ""


static func _mate_plus(fx: BattleMoveEffects, user: BattleFighter) -> bool:
	var m := fx.partner(user)
	return m != null and fx._ability(m) in ["plus", "minus"]


# --- Gancho de on_use() ---


## Saiu um golpe (qualquer um), antes da entrega.
static func on_use(fx: BattleMoveEffects, user: BattleFighter, mv: Dictionary) -> void:
	var s := fx.st(user)
	var id := String(mv.get("id", ""))
	var sp := String(mv.get("special", ""))
	s["move_t"] = fx.now
	s["act_round"] = fx._round_id()
	if id == "fusion_flare":
		fx.field["fusion_flare_t"] = fx.now
	if sp == "glaive":
		s["glaive"] = fx.now + GLAIVE_SECS
		user.popup("Sem guarda!", Color(1, 0.6, 0.4), 0.9)
	elif s.has("glaive"):
		s.erase("glaive")  # o próximo golpe do usuário acaba com a vulnerabilidade
	if sp == "protect":
		s["protect_fx"] = ""
	match sp:
		"beak_blast":
			user.popup("Esquentando o bico!", Dex.type_color("fire"), 0.9)
		"natural_gift":
			var b := _berry(fx, user)
			if b != "":
				user.item_used = true
				user.set_meta("ate_berry", true)
				user.popup("Usou %s!" % fx._item_name(user), Color(1, 0.85, 0.5), 0.8)
		"ignore_ability":
			_mold_breaker(fx, user, mv)
	if mv.has("recharge_after") and String(mv.get("kind", "")) != "beam":
		var wait := Dex.prepare_time(mv) + 0.2
		match String(mv.get("kind", "")):
			"dash":
				wait += float(mv.get("range", 5.0)) / maxf(float(mv.get("speed", 12.0)), 1.0)
			"projectile":
				wait += float(mv.get("range", 10.0)) / maxf(float(mv.get("speed", 12.0)), 1.0)
		var rest := float(mv.recharge_after)
		fx.arena.later(
			wait,
			func() -> void:
				if is_instance_valid(user) and user.alive():
					user.stun_t = maxf(user.stun_t, rest)
					user.popup("Precisa recarregar!", Color(1, 0.7, 0.4), 1.0, 0.9)
		)


## Sunsteel Strike: durante o golpe o usuário vale como Mold Breaker (e perde a própria habilidade
## por esse tempo).
static func _mold_breaker(fx: BattleMoveEffects, user: BattleFighter, mv: Dictionary) -> void:
	var had := user.has_meta("ability_override")
	var old = user.get_meta("ability_override", "")
	user.set_meta("ability_override", "mold_breaker")
	var secs := (
		Dex.prepare_time(mv)
		+ float(mv.get("range", 6.0)) / maxf(float(mv.get("speed", 12.0)), 1.0)
		+ 0.6
	)
	fx.arena.later(
		secs,
		func() -> void:
			if (
				not is_instance_valid(user)
				or user.get_meta("ability_override", "") != "mold_breaker"
			):
				return
			if had:
				user.set_meta("ability_override", old)
			else:
				user.remove_meta("ability_override")
	)


# --- Gancho de blocks_hit() ---


## Proteções novas (King's Shield, Crafty Shield) e os efeitos de contato do Baneful Bunker, do Burning
## Bulwark e do bico quente do Beak Blast. true = o golpe parou aqui.
static func blocks_hit(
	fx: BattleMoveEffects, user: BattleFighter, target: BattleFighter, mv: Dictionary
) -> bool:
	var sp := String(mv.get("special", ""))
	var ts := fx.st(target)
	var dmg := float(mv.get("power", 0)) > 0.0
	var contact := _contact(mv)
	if (
		contact
		and target.prepare_id == "beak_blast"
		and target.prepare_t > 0.0
		and not fx.active(ts, "protect")
	):
		target.popup("Bico em brasa!", Dex.type_color("fire"), 0.9)
		fx._status(target, user, "burn")
	if (
		not dmg
		and String(mv.get("category", "")) == "status"
		and fx.active(fx._sd(target.side), "crafty_shield")
	):
		target.popup("Escudo astuto!", Color(1, 0.7, 0.9))
		fx.note_fail(user)
		return true
	if sp in ["no_protect", "feint"]:
		return false
	if dmg and fx.active(ts, "kshield"):
		target.popup("Escudo do rei!", Color(0.8, 0.85, 0.95), 1.1)
		if contact and user.alive():
			fx.arena.moves.change_stage(user, "atk", -2, target)
		fx.note_fail(user)
		return true
	var pfx := String(ts.get("protect_fx", ""))
	if pfx != "" and contact and fx.active(ts, "protect"):
		# o Protect comum (base) barra o golpe logo depois; aqui só o efeito no atacante
		if pfx == "baneful":
			fx._status(target, user, "poison")
		elif pfx == "burn":
			fx._status(target, user, "burn")
	return false


# --- Ganchos da fórmula ---


## Poder deste acerto (poder variável). Devolve o poder novo.
static func power(
	fx: BattleMoveEffects, user: BattleFighter, target: BattleFighter, m: Dictionary, p: float
) -> float:
	match String(m.get("special", "")):
		"collision":
			if Dex.effectiveness(String(m.get("type", "")), target.types) > 1.0:
				p *= 4.0 / 3.0
		"last_respects":
			p += 50.0 * _fallen(fx, user)
		"friend_power":
			var fr := int(user.mon.friend) if user.mon != null else 70
			if bool(m.get("friend_inv", false)):
				fr = 255 - fr
			p = maxf(1.0, floorf(float(fr) * 0.4))
		"fusion":
			if fx.now - float(fx.field.get("fusion_flare_t", -99.0)) <= FUSION_WINDOW:
				p *= 2.0
		"psyblade":
			if fx.active(fx.field, "electric") and fx.grounded(user):
				p *= 1.5
		"gravity_boost":
			if fx.active(fx.field, "gravity"):
				p *= 1.5
		"moved_first":
			if _moved_first(fx, target):
				p *= 2.0
		"natural_gift":
			if _berry(fx, user) != "":
				p = BERRY_POWER
	if p > 0.0 and is_instance_valid(target) and target.side != user.side:
		if fx.active(fx.st(target), "glaive"):
			p *= 2.0  # Glaive Rush: o alvo está sem guarda
		var sd := fx._sd(target.side)
		if fx.active(sd, "aurora_veil"):
			p *= (
				BattleMoveEffects.SCREEN_MULT_DOUBLES
				if bool(fx.arena.get("doubles"))
				else BattleMoveEffects.SCREEN_MULT
			)
	return p


## Tipo deste acerto (golpes que mudam de tipo). Devolve o tipo novo.
static func move_type(
	fx: BattleMoveEffects, user: BattleFighter, _target: BattleFighter, m: Dictionary, ty: String
) -> String:
	match String(m.get("special", "")):
		"ivy_cudgel":
			if _id_has(user, "wellspring"):
				return "water"
			if _id_has(user, "hearthflame"):
				return "fire"
			if _id_has(user, "cornerstone"):
				return "rock"
		"aura_wheel":
			if _id_has(user, "hangry"):
				return "dark"
		"multi_attack":
			if _id_has(user, "silvally") and not user.types.is_empty():
				return String(user.types[0])
		"natural_gift":
			var b := _berry(fx, user)
			if b != "":
				return String(BERRY_TYPE[b])
	if fx.active(fx.st(user), "electrify"):
		return "electric"
	if ty == "normal" and fx.active(fx.field, "plasma") and float(m.get("power", 0)) > 0.0:
		return "electric"
	return ty


## Perfil do atacante: Spectral Thief rouba os aumentos do alvo antes de calcular o dano.
static func attacker(
	_fx: BattleMoveEffects, user: BattleFighter, target: BattleFighter, m: Dictionary, p: Dictionary
) -> void:
	if String(m.get("special", "")) != "spectral_thief":
		return
	var took := false
	for k in target.stages.keys():
		var v := int(target.stages[k])
		if v > 0:
			user.stages[k] = clampi(int(user.stages.get(k, 0)) + v, -6, 6)
			target.stages[k] = 0
			took = true
	if took:
		user.popup("Roubou os aumentos!", Dex.type_color("ghost"), 0.9)
		var np := user.damage_profile()
		for k in np:
			p[k] = np[k]


## Perfil do defensor: Thousand Arrows ignora o voo; Foresight deixa Normal e Lutador baterem em Fantasma.
static func defender(
	fx: BattleMoveEffects, _user: BattleFighter, target: BattleFighter, m: Dictionary, p: Dictionary
) -> void:
	var ty := String(m.get("type", ""))
	var types: Array = p.types
	if String(m.get("special", "")) == "thousand_arrows" and "flying" in types:
		types = types.duplicate()
		types.erase("flying")
		if types.is_empty():
			types = ["normal"]
		p["types"] = types
	if (
		bool(fx.st(target).get("foresight", false))
		and ty in ["normal", "fighting"]
		and "ghost" in types
	):
		types = types.duplicate()
		types.erase("ghost")
		if types.is_empty():
			types = ["normal"]
		p["types"] = types


# --- Gancho de after_hit() ---


## Depois do acerto (também golpes de status com alvo), com o dano tirado.
static func after_hit(
	fx: BattleMoveEffects, user: BattleFighter, target: BattleFighter, mv: Dictionary, dealt: int
) -> void:
	var sp := String(mv.get("special", ""))
	if sp == "":
		return
	var s := fx.st(user)
	var ts := fx.st(target)
	var sheer := fx.sheer_force(user, mv)
	match sp:
		"pin":
			if target.alive():
				if not "ghost" in target.types:
					ts["trapped"] = true
				target.trap_t = maxf(target.trap_t, PIN_SECS)
				target.popup("Preso no lugar!", Color(0.8, 0.7, 0.9))
		"dire_claw":
			if not sheer and dealt > 0 and target.alive() and fx.rng.randf() < 0.5:
				fx._status(user, target, ["poison", "paralysis", "sleep"][fx.rng.randi() % 3])
		"double_shock":
			if dealt > 0 and int(s.get("ds_cast", -1)) != user.cast_n:
				s["ds_cast"] = user.cast_n
				user.types = user.types.filter(func(t): return t != "electric")
				user.popup("Perdeu o tipo Elétrico!", Dex.type_color("electric"), 0.9)
		"jaw_lock":
			if dealt > 0 and user.alive() and target.alive():
				_jaw_lock(fx, user, target)
		"thousand_arrows":
			if target.alive():
				if target.fly_h > 0.3 or target.fly_target > 0.0 or fx.active(ts, "magnet"):
					target.popup("Derrubado!", Dex.type_color("ground"), 1.0)
				ts.erase("magnet")
				ts.erase("magnet#")
				target.fly_target = 0.0
				fx.set_rounds(ts, "smacked", SMACK_TURNS)
		"trap_all":
			if target.alive() and not "ghost" in target.types:
				ts["trapped"] = true
				target.popup("Não pode fugir!", Color(0.85, 0.7, 0.45))
		"salt_cure":
			if dealt > 0 and target.alive() and not bool(ts.get("salted", false)):
				ts["salted"] = true
				target.popup("Curado no sal!", COL_SALT)
		"stone_axe":
			if dealt > 0 and int(s.get("axe_cast", -1)) != user.cast_n:
				s["axe_cast"] = user.cast_n
				if not fx.spikes.any(
					func(z): return int(z.side) == user.side and bool(z.get("rock", false))
				):
					fx._lay_stealth_rock(user)
		"plasma_fists":
			if dealt > 0:
				fx.set_rounds(fx.field, "plasma", 1)
				user.popup("Ion elétrico!", Dex.type_color("electric"), 0.9)
		"order_up":
			if dealt > 0 and int(s.get("order_cast", -1)) != user.cast_n:
				s["order_cast"] = user.cast_n
				_order_up(fx, user)
		"captivate":
			var a := String(user.mon.gender)
			var b := String(target.mon.gender)
			if a == "" or b == "" or a == b:
				target.popup("Sem efeito...", Color(0.7, 0.7, 0.7))
				fx.note_fail(user)
			else:
				fx.arena.moves.change_stage(target, "spa", -2, user)
		"doodle":
			var ab := fx._ability(target)
			if ab == "":
				fx._fail(user)
			else:
				for g in [user, fx.partner(user)]:
					if g != null:
						g.set_meta("ability_override", ab)
				user.popup("Copiou %s!" % ab.replace("_", " "), Color(0.9, 0.9, 0.95), 0.9)
		"electrify":
			fx.set_rounds(ts, "electrify", 1)
			target.popup("Eletrizado!", Dex.type_color("electric"))
		"foresight":
			ts["foresight"] = true
			target.evasion_t = 0.0
			target.popup("Descoberto!", Color(0.95, 0.95, 0.85))
		"forests_curse":
			if "grass" in target.types:
				fx._fail(user)
			else:
				var t: Array = target.types.duplicate()
				t.append("grass")
				target.types = t
				target.popup("Ganhou o tipo Planta!", Dex.type_color("grass"))
		"instruct":
			var last := fx._last_of(target)
			if fx._copyable(last) == "":
				fx._fail(user)
			else:
				target.popup("Repete!", Color(1, 0.7, 0.9))
				fx._call(target, last)
		"corrosive_gas":
			if fx._has_item(target):
				target.popup("Perdeu %s!" % fx._item_name(target), Color(0.75, 0.5, 0.85))
				target.item_used = true


## Order Up: o Dondozo com o Tatsugiri de parceiro sobe um atributo pela forma dele.
static func _order_up(fx: BattleMoveEffects, user: BattleFighter) -> void:
	var mate := fx.partner(user)
	if not _id_has(user, "dondozo") or not _id_has(mate, "tatsugiri"):
		return
	var k := "atk"
	if _id_has(mate, "droopy"):
		k = "def"
	elif _id_has(mate, "stretchy"):
		k = "spe"
	fx.arena.moves.change_stage(user, k, 1)


## Jaw Lock: os dois ficam presos um ao outro (sem trocar nem fugir, com coleira).
static func _jaw_lock(fx: BattleMoveEffects, a: BattleFighter, b: BattleFighter) -> void:
	if fx.active(fx.st(a), "jaw") or fx.active(fx.st(b), "jaw"):
		return
	for pair in [[a, b], [b, a]]:
		var f: BattleFighter = pair[0]
		var s := fx.st(f)
		fx.set_rounds(s, "jaw", JAW_TURNS)
		s["jaw_with"] = pair[1]
		s["trapped"] = true
		f.popup("Presos pela mordida!", COL_TETHER, 0.9)


static func _jaw_free(fx: BattleMoveEffects, f: BattleFighter) -> void:
	var s := fx.st(f)
	s.erase("jaw")
	s.erase("jaw#")
	s.erase("jaw_with")
	s["trapped"] = false


# --- Status em si mesmo / no campo ---


## Golpe de status em si mesmo/no campo pelo special. true = tratado aqui.
static func self_move(fx: BattleMoveEffects, user: BattleFighter, mv: Dictionary) -> bool:
	var s := fx.st(user)
	var sd := fx._sd(user.side)
	var mate := fx.partner(user)
	var moves: BattleMoves = fx.arena.moves
	match String(mv.get("special", "")):
		"ally_buff":
			if mate == null:
				fx._fail(user)
			else:
				moves.change_stage(
					mate, String(mv.get("ally_stat", "spd")), int(mv.get("ally_stages", 1))
				)
		"autotomize":
			moves.change_stage(user, "spe", int(mv.get("stages", 2)))
			user.set_meta("weight_mult", maxf(float(user.get_meta("weight_mult", 1.0)) * 0.5, 0.1))
			user.popup("Ficou leve!", Color(0.85, 0.9, 1.0), 0.9)
		"aurora_veil":
			fx.set_rounds(sd, "aurora_veil", BattleMoveEffects.FIELD_TURNS)
			user.popup("Aurora Veil!", Color(0.7, 0.95, 1.0))
			fx._vfx(
				"screen",
				[
					user.side,
					"aurora_veil",
					BattleMoveEffects.rounds_secs(BattleMoveEffects.FIELD_TURNS)
				]
			)
		"protect_ex":
			if not fx._stall_ok(s):
				fx._fail(user)
			else:
				fx.set_rounds(s, "protect", 1)
				s["insight"] = false
				s["protect_fx"] = String(mv.get("protect_fx", ""))
				user.popup("Proteger!", Color(0.6, 0.9, 1.0), 1.1)
				fx._vfx("protect_shield", [user, fx.round_left()])
		"kings_shield":
			if not fx._stall_ok(s):
				fx._fail(user)
			else:
				fx.set_rounds(s, "kshield", 1)
				user.popup("Escudo do rei!", Color(0.8, 0.85, 0.95), 1.1)
				fx._vfx("protect_shield", [user, fx.round_left()])
		"crafty_shield":
			fx.set_rounds(sd, "crafty_shield", 1)
			user.popup("Escudo astuto!", Color(1, 0.7, 0.9))
			fx._vfx("protect_shield", [user, fx.round_left()])
		"chilly_reception":
			fx.set_weather("hail", BattleMoveEffects.FIELD_TURNS, user)
			fx.arena.popup(
				user.position + Vector3(0, 1.6, 0), "Piada gelada! Nevou.", Dex.type_color("ice")
			)
			if fx.has_reserve(user):
				fx.arena.later(
					BattleMoveEffects.PIVOT_DELAY, func() -> void: fx._switch(user, false)
				)
		"clangorous_soul":
			if user.hp <= user.max_hp / 3:
				fx._fail(user)
			else:
				user.take_damage(maxi(1, user.max_hp / 3), Vector3.ZERO, 0.0)
				for k in ["atk", "def", "spa", "spd", "spe"]:
					moves.change_stage(user, k, 1)
		"fillet_away":
			if user.hp <= user.max_hp / 2:
				fx._fail(user)
			else:
				user.take_damage(maxi(1, user.max_hp / 2), Vector3.ZERO, 0.0)
				for k in ["atk", "spa", "spe"]:
					moves.change_stage(user, k, 2)
		"court_change":
			_court_change(fx, user)
		"decorate":
			var to := mate if mate != null else user
			moves.change_stage(to, "atk", 2)
			moves.change_stage(to, "spa", 2)
		"fairy_lock":
			fx.set_rounds(fx.field, "fairy_lock", FAIRY_LOCK_TURNS)
			fx.arena.popup(
				user.position + Vector3(0, 1.6, 0), "Ninguém foge!", Dex.type_color("fairy")
			)
		"floral_healing":
			var to2 := mate if mate != null else user
			var k := 2.0 / 3.0 if fx.active(fx.field, "grassy") and fx.grounded(to2) else 0.5
			fx._heal(to2, int(ceil(to2.max_hp * k)))
		"flower_shield":
			var any := false
			for g in fx.arena.fighters:
				if is_instance_valid(g) and g.active() and "grass" in g.types:
					moves.change_stage(g, "def", 1)
					any = true
			if not any:
				fx._fail(user)
		"gear_up":
			for g in [user, mate]:
				if g != null and fx._ability(g) in ["plus", "minus"]:
					moves.change_stage(g, "atk", 1)
					moves.change_stage(g, "spa", 1)
		"grudge":
			fx.set_rounds(s, "grudge", 1)
			user.popup("Rancor!", Dex.type_color("ghost"), 0.9)
		"heal_cure_team":
			for g in [user, mate]:
				if g != null:
					g.clear_status()
					fx._heal(g, int(ceil(g.max_hp * float(mv.get("heal", 0.25)))))
		"bide":
			s["bide_dmg"] = 0
			s["bide_by"] = null
			fx.set_rounds(s, "bide", BIDE_TURNS)
			user.popup("Guardando energia!", Color(0.9, 0.85, 0.7), 1.0)
		_:
			return false
	return true


## Court Change: troca de lado o que está de cada lado (armadilhas e barreiras).
static func _court_change(fx: BattleMoveEffects, user: BattleFighter) -> void:
	var a: Dictionary = fx.sides[0]
	var b: Dictionary = fx.sides[1]
	for k in [
		"reflect",
		"light_screen",
		"aurora_veil",
		"safeguard",
		"mist",
		"tailwind",
		"quick_guard",
		"wide_guard",
		"crafty_shield"
	]:
		for key in [k, k + "#"]:
			var av = a.get(key, null)
			var bv = b.get(key, null)
			if bv == null:
				a.erase(key)
			else:
				a[key] = bv
			if av == null:
				b.erase(key)
			else:
				b[key] = av
	for z in fx.spikes:
		z["side"] = 1 - int(z.side)
	var fl = fx.arena.get("field")
	if fl != null:
		for m in fl.marks:
			if m.kind == "spikes":
				m["side"] = 1 - int(m.side)
	fx.arena.popup(user.position + Vector3(0, 1.6, 0), "Quadra trocada!", Color(0.9, 0.9, 0.95))


# --- A IA ---


## A IA: vale usar agora? true/false, ou null = sem opinião.
static func ai_worth(fx: BattleMoveEffects, f: BattleFighter, mv: Dictionary) -> Variant:
	var sp := String(mv.get("special", ""))
	var opp := f.opponent
	var has_opp := is_instance_valid(opp) and opp.active()
	var hp := float(f.hp) / maxf(float(f.max_hp), 1.0)
	var mate := fx.partner(f)
	var s := fx.st(f)
	match sp:
		"ally_buff":
			return mate != null and int(mate.stages.get(String(mv.get("ally_stat", "spd")), 0)) < 2
		"aurora_veil":
			return _snow(fx) and not fx.active(fx._sd(f.side), "aurora_veil") and has_opp
		"autotomize":
			return int(f.stages.get("spe", 0)) < 2
		"protect_ex", "kings_shield":
			return fx._threatened(f)
		"crafty_shield":
			return has_opp and fx._has_cat(opp, "status") and fx._threatened(f)
		"captivate":
			return (
				has_opp
				and f.mon.gender != ""
				and opp.mon.gender != ""
				and f.mon.gender != opp.mon.gender
				and int(opp.stages.get("spa", 0)) > -2
			)
		"chilly_reception":
			return (
				not _snow(fx)
				and (fx.has_reserve(f) or "ice" in f.types or fx._has_type_hit(f, "ice"))
			)
		"clangorous_soul":
			return hp > 0.6 and int(f.stages.get("atk", 0)) < 2 and int(f.stages.get("spe", 0)) < 2
		"fillet_away":
			return hp > 0.65 and int(f.stages.get("atk", 0)) < 2
		"corrosive_gas":
			return has_opp and fx._has_item(opp) and f.flat_to(opp).length() < 3.6
		"court_change":
			var bad := fx.spikes.any(func(z): return int(z.side) != f.side)
			var theirs := (
				fx.active(fx._sd(1 - f.side), "reflect")
				or fx.active(fx._sd(1 - f.side), "light_screen")
				or fx.active(fx._sd(1 - f.side), "tailwind")
			)
			return bad or (theirs and not fx.active(fx._sd(f.side), "tailwind"))
		"decorate":
			return mate != null or int(f.stages.get("atk", 0)) < 2
		"doodle":
			return has_opp and fx._ability(opp) != "" and fx._ability(opp) != fx._ability(f)
		"electrify":
			return (
				has_opp
				and not fx.active(fx.st(opp), "electrify")
				and Dex.effectiveness("electric", f.types) < 1.0
				and fx._has_cat(opp, "physical")
			)
		"fairy_lock":
			return false
		"floral_healing":
			var to := mate if mate != null else f
			return float(to.hp) / maxf(float(to.max_hp), 1.0) < 0.5
		"flower_shield":
			return "grass" in f.types and int(f.stages.get("def", 0)) < 2
		"foresight":
			return (
				has_opp
				and not bool(fx.st(opp).get("foresight", false))
				and ("ghost" in opp.types or opp.evasion_t > 0.0)
			)
		"forests_curse":
			return has_opp and not "grass" in opp.types and fx._has_type_hit(f, "grass")
		"gear_up":
			return int(f.stages.get("atk", 0)) < 2
		"grudge":
			return hp < 0.3 and fx._threatened(f)
		"heal_cure_team":
			return (
				hp < 0.5
				or f.status in BattleMoveEffects.MAJOR
				or (mate != null and float(mate.hp) / maxf(float(mate.max_hp), 1.0) < 0.5)
			)
		"instruct":
			var last := fx._last_of(opp) if has_opp else ""
			if last == "":
				return false
			return float(Dex.move(last).get("power", 0)) <= 0.0
		"bide":
			return hp > 0.7 and has_opp and fx._threatened(f)
	return null


# --- Dano guardado, queda e fim de turno ---


## Alvo levou dano de golpe: o Bide guarda o dano e o Grudge anota o golpe que o derrubou.
static func note_damage(
	fx: BattleMoveEffects, user: BattleFighter, target: BattleFighter, mv: Dictionary, dealt: int
) -> void:
	if user.side == target.side:
		return
	var ts := fx.st(target)
	ts["last_mv"] = String(mv.get("id", ""))
	if fx.active(ts, "bide"):
		ts["bide_dmg"] = int(ts.get("bide_dmg", 0)) + dealt
		ts["bide_by"] = user
	if not target.alive():
		_grudge(fx, target, user)


## Um lutador desmaiou.
static func note_faint(fx: BattleMoveEffects, f: BattleFighter) -> void:
	var s := fx.st(f)
	var by = s.get("last_by")
	if is_instance_valid(by):
		_grudge(fx, f, by)


## Grudge: o autor do golpe que derrubou perde esse golpe (PP zerado: trava sem fim).
static func _grudge(fx: BattleMoveEffects, f: BattleFighter, by: BattleFighter) -> void:
	var s := fx.st(f)
	var id := String(s.get("last_mv", ""))
	if not fx.active(s, "grudge") or id == "" or not by.moves.has(id):
		return
	s.erase("grudge")
	s.erase("grudge#")
	by.move_cd[id] = BattleMoveEffects.LOCK_CD
	by.popup("%s zerado!" % Dex.move(id).get("name", id), Dex.type_color("ghost"), 0.9)


## Todo frame (fx.now já avançou): coleira do Jaw Lock, Thousand Arrows no chão, Fairy Lock.
static func tick(fx: BattleMoveEffects, dt: float) -> void:
	var lock := fx.active(fx.field, "fairy_lock")
	for f in fx.arena.fighters:
		if not is_instance_valid(f) or not f.active():
			continue
		var s := fx.st(f)
		if lock:
			if not bool(s.get("trapped", false)):
				s["trapped"] = true
				s["fl_trap"] = true
		elif bool(s.get("fl_trap", false)):
			s["fl_trap"] = false
			s["trapped"] = false
		if fx.active(s, "smacked"):
			f.fly_target = 0.0
			s["smk"] = true
		elif bool(s.get("smk", false)):
			s["smk"] = false
			f.fly_target = float(f.prof.get("fly", 0.0))
		if not fx.active(s, "jaw"):
			continue
		var g = s.get("jaw_with")
		if not is_instance_valid(g) or not g.active() or not fx.active(fx.st(g), "jaw"):
			_jaw_free(fx, f)
			continue
		if f.get_instance_id() > g.get_instance_id() or _moving(f) or _moving(g):
			continue
		var d := Vector3(g.position.x - f.position.x, 0.0, g.position.z - f.position.z)
		var dist := d.length()
		if dist > LEASH:
			var pull := d.normalized() * (dist - LEASH) * minf(1.0, dt * 6.0) * 0.5
			f.position += pull
			g.position -= pull


static func _moving(f: BattleFighter) -> bool:
	return f.launch_t > 0.0 or f.motion != "" or f.dash_t > 0.0 or f.lunge_t > 0.0


## Fim de turno (uma vez por rodada) de cada lutador ativo: conte rodadas com fx.count_round.
static func end_turn(fx: BattleMoveEffects, f: BattleFighter) -> void:
	var s := fx.st(f)
	if bool(s.get("salted", false)):
		var k := 0.25 if ("water" in f.types or "steel" in f.types) else 0.125
		f.residual_damage(maxi(1, int(f.max_hp * k)), "sal", COL_SALT)
	for key in ["electrify", "grudge", "kshield", "smacked"]:
		fx.count_round(s, key)
	if fx.count_round(s, "jaw"):
		_jaw_free(fx, f)
		f.popup("A mordida soltou.", COL_HOLD, 0.8)
	if fx.count_round(s, "bide"):
		_unleash(fx, f)
	# o que é do lado ou do campo conta uma vez só (pelo primeiro lutador ativo)
	if f == _first(fx, f.side):
		var sd := fx._sd(f.side)
		if fx.count_round(sd, "aurora_veil"):
			f.popup("O Aurora Veil acabou.", COL_FIELD, 0.8)
		fx.count_round(sd, "crafty_shield")
	if f == _first(fx):
		for key in ["plasma", "fairy_lock"]:
			fx.count_round(fx.field, key)


## Bide: acabou o tempo, devolve o dobro do dano guardado a quem mais bateu.
static func _unleash(fx: BattleMoveEffects, f: BattleFighter) -> void:
	var s := fx.st(f)
	var dmg := int(s.get("bide_dmg", 0)) * BIDE_MULT
	var by = s.get("bide_by")
	s.erase("bide_dmg")
	s.erase("bide_by")
	var to: BattleFighter = by if is_instance_valid(by) and by.active() else f.opponent
	if dmg <= 0 or not is_instance_valid(to) or not to.active():
		f.popup("Nada para devolver...", COL_HOLD, 0.9)
		return
	f.popup("Liberou a energia!", Color(1, 0.7, 0.35), 1.1)
	fx._direct(f, to, dmg, 8.0)

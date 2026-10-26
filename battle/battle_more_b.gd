class_name BattleMoreB
extends RefCounted
## Golpes da Gen 2-9 (parte B: especiais e a outra metade dos de status; tools/moves_more_b.py).
## Ganchos chamados por BattleMore (battle_more.gd); fx = BattleMoveEffects (fx.st(f), fx.set_rounds...).
## Estado novo em fx.st(f): b_use_t (último golpe), fickle, shell_until, b_guard/guard (Obstruct, Silk Trap,
## Spiky Shield), torment, tar, odor, no_retreat, syrup, octolock/octo_by/octo_trap; no campo (fx.field):
## mud_sport (Mud Sport) e b_fusion_t (Fusion Bolt usado há pouco). Rodadas contadas em end_turn.

## Janela (s) do Shell Trap armado, de quando o golpe de status começa.
const SHELL_WINDOW := 1.5
const SHELL_RADIUS := 3.8
const SHELL_BOOM_POWER := 150.0
## Core Enforcer: o alvo "já se moveu neste turno" se agiu há até CORE_WINDOW s.
const CORE_WINDOW := 3.0
## Fusion Flare dobra se o Fusion Bolt saiu há até FUSION_WINDOW s.
const FUSION_WINDOW := 4.0
## Thunderclap: o alvo está atacando se o golpe saiu há até ATTACK_WINDOW s.
const ATTACK_WINDOW := 0.6
const SPLASH_R := 2.2
const SPLASH_FRAC := 1.0 / 16.0
const OCTO_TURNS := 4
const OCTO_GRIP := 0.8
const SYRUP_TURNS := 3
const QUASH_DELAY := 1.6
const MUD_SPORT_MULT := 1.0 / 3.0
const SE_BOOST := 4.0 / 3.0
const FICKLE_CHANCE := 0.3
const SPIKY_FRAC := 1.0 / 8.0
const WEB_AHEAD := 1.6
const WEB_SIDE := 1.8
const WEB_REPEAT := 12.0
const CONTACT_KINDS := ["dash", "arc", "multi_arc", "whip"]
const CURABLE := ["burn", "paralysis", "poison", "toxic"]
const STAT_KEYS := ["atk", "def", "spa", "spd", "spe"]
## Hidden Power: o tipo vem do último bit de cada IV (HP, Atk, Def, Spe, SpA, SpD).
const HP_TYPES := [
	"fighting",
	"flying",
	"poison",
	"ground",
	"rock",
	"bug",
	"ghost",
	"steel",
	"fire",
	"water",
	"grass",
	"electric",
	"psychic",
	"ice",
	"dragon",
	"dark",
]
const HP_ORDER := ["hp", "atk", "def", "spe", "spa", "spd"]
## Techno Blast: o tipo vem do Drive que o usuário segura (sem ele, Normal).
const DRIVES := {
	"douse_drive": "water", "shock_drive": "electric", "burn_drive": "fire", "chill_drive": "ice"
}
const GUARD_TEXT := {
	"obstruct": "Obstruct!",
	"silk_trap": "Silk Trap!",
	"spiky_shield": "Spiky Shield!",
}
const GUARD_COL := {
	"obstruct": Color(0.55, 0.4, 0.75),
	"silk_trap": Color(0.7, 0.85, 0.3),
	"spiky_shield": Color(0.45, 0.85, 0.35),
}


static func _sp(mv: Dictionary) -> String:
	return String(mv.get("special", ""))


static func _ok(f) -> bool:
	return is_instance_valid(f) and f.active()


## O adversário está no meio de um golpe de dano (preparando, em investida ou acabou de soltar).
static func _attacking(fx: BattleMoveEffects, t: BattleFighter) -> bool:
	if not _ok(t):
		return false
	if t.prepare_t > 0.0 and float(Dex.move(t.prepare_id).get("power", 0)) > 0.0:
		return true
	if t.dash_t > 0.0 and float(t.dash_move.get("power", 0)) > 0.0:
		return true
	var ts := fx.st(t)
	var last := Dex.move(String(ts.last))
	return (
		fx.now - float(ts.get("b_use_t", -99.0)) <= ATTACK_WINDOW
		and float(last.get("power", 0)) > 0.0
		and String(last.get("kind", "")) != "self_buff"
	)


## Golpe físico a caminho de quem usa (a IA do Shell Trap).
static func _phys_threat(fx: BattleMoveEffects, f: BattleFighter) -> bool:
	for foe in fx._foes(f):
		var mv: Dictionary = Dex.move(foe.prepare_id) if foe.prepare_t > 0.0 else foe.dash_move
		if foe.prepare_t > 0.0 or foe.dash_t > 0.0:
			if String(mv.get("category", "")) == "physical" and float(mv.get("power", 0)) > 0.0:
				return true
	return false


static func _fainted_ally(fx: BattleMoveEffects, user: BattleFighter) -> Mon:
	var best: Mon = null
	for m in fx._party_of(user):
		if m is Mon and m.hp <= 0 and m != user.mon:
			if best == null or m.level > best.level:
				best = m
	return best


static func _held_berry(fx: BattleMoveEffects, f: BattleFighter) -> bool:
	return fx._has_item(f) and String(f.trainer_item).ends_with("_berry")


static func _has_berry(fx: BattleMoveEffects, f: BattleFighter) -> bool:
	return _held_berry(fx, f) or not fx._berries_near(f).is_empty()


## Come a frutinha segurada (Oran e Sitrus curam, Pecha e Persim tiram o status). true = comeu.
static func _eat_held(fx: BattleMoveEffects, f: BattleFighter) -> bool:
	if not _held_berry(fx, f):
		return false
	var id := String(f.trainer_item)
	f.popup("Ate %s!" % fx._item_name(f), Color(0.5, 1.0, 0.5), 0.8)
	f.item_used = true
	f.set_meta("ate_berry", true)
	if BattleEndTurn.HP_BERRIES.has(id):
		var row: Array = BattleEndTurn.HP_BERRIES[id]
		var amt := int(row[1]) if float(row[1]) >= 1.0 else int(ceil(f.max_hp * float(row[1])))
		fx._heal(f, amt)
	elif BattleEndTurn.CURE_BERRIES.has(id):
		var cure: Array = BattleEndTurn.CURE_BERRIES[id]
		if f.status in cure:
			f.clear_status()
		elif "confusion" in cure:
			f.confusion_t = 0.0
	return true


static func _hp_type(user: BattleFighter) -> String:
	if user.mon == null:
		return "normal"
	var bits := 0
	var i := 0
	for k in HP_ORDER:
		bits += (int(user.mon.ivs.get(k, 31)) & 1) << i
		i += 1
	return String(HP_TYPES[bits * 15 / 63])


## Photon Geyser vira físico (Ataque contra Defesa) quando o Ataque do usuário é maior.
static func _photon_physical(user: BattleFighter) -> bool:
	return user.stat("atk") > user.stat("spa")


# --- Gancho de usable() ---


static func blocked(fx: BattleMoveEffects, user: BattleFighter, mv: Dictionary) -> String:
	var s := fx.st(user)
	if bool(s.get("torment", false)) and String(s.last) == String(mv.get("id", "")):
		return "Tormented!"
	match _sp(mv):
		"burn_up":
			if not "fire" in user.types:
				return "Not a Fire type!"
		"shed_tail":
			if not fx.has_reserve(user):
				return "No one to switch in!"
			if user.hp <= user.max_hp / 2:
				return "Not enough HP!"
		"revival_blessing":
			if _fainted_ally(fx, user) == null:
				return "No one to revive!"
		"thunderclap":
			if not _attacking(fx, user.opponent):
				return "But it failed!"
		"no_retreat":
			if bool(s.get("no_retreat", false)):
				return "But it failed!"
		"sketch":
			var c := fx._copyable(fx._last_of(user.opponent))
			if c == "" or c in user.moves:
				return "Nothing to copy!"
		"stuff_cheeks":
			if not _has_berry(fx, user):
				return "No Berry!"
		"refresh":
			if not user.status in CURABLE:
				return "But it failed!"
		"psycho_shift":
			if not user.status in BattleMoveEffects.MAJOR:
				return "No status!"
	return ""


# --- Gancho de on_use() ---


static func on_use(fx: BattleMoveEffects, user: BattleFighter, mv: Dictionary) -> void:
	var s := fx.st(user)
	s["b_use_t"] = fx.now
	if String(mv.get("id", "")) == "fusion_bolt":
		fx.field["b_fusion_t"] = fx.now
	if _sp(mv) == "fickle_beam":
		s["fickle"] = fx.rng.randf() < FICKLE_CHANCE
		if bool(s.fickle):
			user.popup("Power doubled!", Dex.type_color("dragon"), 0.9)


# --- Gancho de blocks_hit() ---


## Obstruct, Silk Trap e Spiky Shield: como o Protect, mas quem encosta paga (contato).
static func blocks_hit(
	fx: BattleMoveEffects, user: BattleFighter, target: BattleFighter, mv: Dictionary
) -> bool:
	var ts := fx.st(target)
	if not fx.active(ts, "b_guard") or _sp(mv) in ["no_protect", "feint"]:
		return false
	var guard := String(ts.get("guard", ""))
	# Obstruct e Silk Trap só barram golpe de dano (como o King's Shield); o Spiky Shield barra tudo.
	if guard != "spiky_shield" and String(mv.get("category", "")) == "status":
		return false
	target.popup("Protected itself!", GUARD_COL.get(guard, Color(0.6, 0.9, 1.0)), 1.1)
	fx.st(user).fail = true
	fx.crash_damage(user, mv)
	if float(mv.get("power", 0)) > 0.0 and _touches(mv):
		_guard_react(fx, user, target, guard)
	return true


## O golpe encosta no alvo: o dado oficial ("contact") vale mais que o kind.
static func _touches(mv: Dictionary) -> bool:
	if mv.has("contact"):
		return bool(mv.contact)
	return String(mv.get("kind", "")) in CONTACT_KINDS


static func _guard_react(
	fx: BattleMoveEffects, user: BattleFighter, guard_user: BattleFighter, guard: String
) -> void:
	match guard:
		"obstruct":
			fx.arena.moves.change_stage(user, "def", -2, guard_user)
		"silk_trap":
			fx.arena.moves.change_stage(user, "spe", -1, guard_user)
		"spiky_shield":
			var ab = fx.arena.abilities
			if ab and ab.has_method("no_indirect") and ab.no_indirect(user):
				return
			var d := maxi(1, int(user.max_hp * SPIKY_FRAC))
			user.take_damage(d, Vector3.ZERO, 0.0)
			user.popup("-%d spikes" % d, Dex.type_color("grass"), 0.9)


# --- Ganchos de poder, tipo e perfis ---


static func power(
	fx: BattleMoveEffects, user: BattleFighter, target: BattleFighter, m: Dictionary, p: float
) -> float:
	var ty := String(m.get("type", ""))
	if ty == "electric" and fx.active(fx.field, "mud_sport"):
		p *= MUD_SPORT_MULT
	if ty == "fire" and bool(fx.st(target).get("tar", false)):
		p *= 2.0  # Tar Shot: o piche pega fogo
	match _sp(m):
		"fickle_beam":
			if bool(fx.st(user).get("fickle", false)):
				p *= 2.0
		"se_boost":
			if Dex.effectiveness(ty, target.types) > 1.0:
				p *= SE_BOOST
		"hydro_steam":
			if fx.weather() == "sun":
				p *= 3.0  # tira o 0,5x do sol sobre Água e dá 1,5x
		"rising_voltage":
			if fx.active(fx.field, "electric") and fx.grounded(target):
				p *= 2.0
		"fusion_flare":
			if fx.now - float(fx.field.get("b_fusion_t", -99.0)) <= FUSION_WINDOW:
				p *= 2.0
	return p


static func move_type(
	fx: BattleMoveEffects, user: BattleFighter, _target: BattleFighter, m: Dictionary, ty: String
) -> String:
	match _sp(m):
		"hidden_power":
			return _hp_type(user)
		"type_of_user":
			return String(user.types[0]) if not user.types.is_empty() else ty
		"techno_blast":
			var item := String(user.trainer_item) if fx._has_item(user) else ""
			return String(DRIVES.get(item, ty))
	return ty


static func attacker(
	_fx: BattleMoveEffects,
	user: BattleFighter,
	_target: BattleFighter,
	m: Dictionary,
	p: Dictionary
) -> void:
	if _sp(m) == "photon_geyser" and _photon_physical(user):
		p["spa"] = user.stat("atk")
		p["crit_spa"] = user.crit_stat("atk", true)


static func defender(
	fx: BattleMoveEffects, user: BattleFighter, target: BattleFighter, m: Dictionary, p: Dictionary
) -> void:
	if _sp(m) == "photon_geyser" and _photon_physical(user):
		p["spd"] = p.def
		p["crit_spd"] = p.crit_def
	if (
		bool(fx.st(target).get("odor", false))
		and "ghost" in p.types
		and String(m.get("type", "")) in ["normal", "fighting"]
	):
		var ty: Array = p.types.duplicate()
		ty.erase("ghost")
		p["types"] = ty if not ty.is_empty() else ["normal"]


# --- Depois do acerto ---


static func after_hit(
	fx: BattleMoveEffects, user: BattleFighter, target: BattleFighter, mv: Dictionary, dealt: int
) -> void:
	var sp := _sp(mv)
	if sp == "" or not is_instance_valid(user) or not is_instance_valid(target):
		return
	var ts := fx.st(target)
	var hit_ok := dealt > 0 and target.alive() and not fx.sheer_force(user, mv)
	match sp:
		"burn_up":
			_lose_fire(user)
		"core_enforcer":
			if hit_ok and fx.now - float(ts.get("b_use_t", -99.0)) <= CORE_WINDOW:
				if fx._ability(target) != "":
					target.set_meta("ability_override", "")
					target.popup("Ability suppressed!", Color(0.7, 0.9, 0.5))
		"flame_burst":
			if dealt > 0:
				_splash(fx, user, target)
		"best_stat":
			if hit_ok and user.alive():
				var best := "atk"
				var bv := -1.0
				for k in STAT_KEYS:
					if float(user.stats.get(k, 0)) > bv:
						bv = float(user.stats.get(k, 0))
						best = k
				fx.arena.moves.change_stage(user, best, 1)
		"magic_powder":
			if target.types == ["psychic"]:
				fx._fail(user)
			else:
				target.types = ["psychic"]
				target.popup("Became Psychic type!", Dex.type_color("psychic"), 1.0, 0.8)
		"octolock":
			_octolock(fx, user, target)
		"odor_sleuth":
			ts["odor"] = true
			target.evasion_t = 0.0
			target.popup("Identified!", Color(0.9, 0.85, 0.7))
		"psycho_shift":
			_psycho_shift(fx, user, target)
		"purify":
			if target.status in BattleMoveEffects.MAJOR:
				target.clear_status()
				target.popup("Status cured!", Color(0.8, 0.6, 0.95))
				fx._heal(user, int(ceil(user.max_hp / 2.0)))
			else:
				fx._fail(user)
		"quash":
			target.gcd_t = maxf(target.gcd_t, QUASH_DELAY)
			target.popup("Moved to last!", Color(0.6, 0.45, 0.7))
		"sketch":
			_sketch(fx, user, target, mv)
		"spicy_extract":
			fx.arena.moves.change_stage(target, "atk", 2, user)
			fx.arena.moves.change_stage(target, "def", -2, user)
		"syrup_bomb":
			if dealt > 0 and target.alive():
				fx.set_rounds(ts, "syrup", SYRUP_TURNS)
				target.popup("Stuck in syrup!", Color(0.75, 0.9, 0.35))
		"tar_shot":
			ts["tar"] = true
			target.popup("Covered in tar!", Color(0.45, 0.35, 0.3))
		"topsy_turvy":
			_topsy(fx, user, target)
		"torment":
			ts["torment"] = true
			target.popup("Tormented!", Color(0.7, 0.45, 0.85))
		"toxic_thread":
			if target.alive():
				fx.arena.moves.change_stage(target, "spe", -1, user)
		"trick_or_treat":
			if "ghost" in target.types:
				fx._fail(user)
			else:
				var ty: Array = target.types.duplicate()
				ty.append("ghost")
				target.types = ty
				target.popup("Gained Ghost type!", Dex.type_color("ghost"), 1.0, 0.8)


## Burn Up: o usuário perde o tipo Fire (sem tipo sobra Normal, como o Roost).
static func _lose_fire(user: BattleFighter) -> void:
	if not "fire" in user.types:
		return
	var ty: Array = user.types.duplicate()
	ty.erase("fire")
	user.types = ty if not ty.is_empty() else ["normal"]
	user.popup("Lost the Fire type!", Dex.type_color("fire"), 1.0, 0.8)


## Flame Burst: faíscas ferem quem está colado no alvo (dupla).
static func _splash(fx: BattleMoveEffects, user: BattleFighter, target: BattleFighter) -> void:
	for f in fx._foes(user):
		if f == target or not _ok(f):
			continue
		if (
			Vector2(f.position.x - target.position.x, f.position.z - target.position.z).length()
			> SPLASH_R
		):
			continue
		var d := maxi(1, int(f.max_hp * SPLASH_FRAC))
		f.take_damage(d, Vector3.ZERO, 0.0)
		f.popup("-%d sparks" % d, Dex.type_color("fire"), 0.8)


static func _octolock(fx: BattleMoveEffects, user: BattleFighter, target: BattleFighter) -> void:
	var ts := fx.st(target)
	if fx.active(ts, "octolock") or "ghost" in target.types:
		fx._fail(user)
		return
	fx.set_rounds(ts, "octolock", OCTO_TURNS)
	ts["octo_by"] = user
	if not bool(ts.trapped):
		ts["trapped"] = true
		ts["octo_trap"] = true
	target.trap_t = maxf(target.trap_t, OCTO_GRIP)
	target.popup("Caught by tentacles!", Dex.type_color("fighting"), 1.0, 0.8)


static func _octo_end(fx: BattleMoveEffects, f: BattleFighter) -> void:
	var s := fx.st(f)
	s.erase("octolock")
	s.erase("octolock#")
	s.erase("octo_by")
	if bool(s.get("octo_trap", false)):
		s["trapped"] = false
		s.erase("octo_trap")
	f.popup("Broke free of the tentacles.", BattleEndTurn.COL_END, 0.8)


static func _psycho_shift(
	fx: BattleMoveEffects, user: BattleFighter, target: BattleFighter
) -> void:
	var status := user.status
	if not status in BattleMoveEffects.MAJOR or target.status != "":
		fx._fail(user)
		return
	fx._status(user, target, status)
	if target.status == status:
		user.clear_status()
		user.popup("Passed the status!", Dex.type_color("psychic"), 0.9)
	else:
		fx._fail(user)


## Sketch: troca o próprio Sketch pelo último golpe do alvo, para o resto da vida do Pokémon.
static func _sketch(
	fx: BattleMoveEffects, user: BattleFighter, target: BattleFighter, mv: Dictionary
) -> void:
	var c := fx._copyable(fx._last_of(target))
	var id := String(mv.get("id", "sketch"))
	var i := user.moves.find(id)
	if c == "" or i < 0 or c in user.moves:
		fx._fail(user)
		return
	user.moves[i] = c
	if user.mon != null:
		var j := user.mon.moves.find(id)
		if j >= 0:
			user.mon.moves[j] = c
	user.popup("Sketched %s!" % Dex.move(c).get("name", c), Color(0.95, 0.9, 0.8), 1.0, 0.8)


static func _topsy(fx: BattleMoveEffects, user: BattleFighter, target: BattleFighter) -> void:
	var any := false
	for k in target.stages:
		var v := int(target.stages[k])
		if v != 0:
			any = true
			target.stages[k] = -v
	if any:
		target.popup("Stat changes inverted!", Color(0.6, 0.4, 0.7))
	else:
		fx._fail(user)


# --- self_buff ---


static func self_move(fx: BattleMoveEffects, user: BattleFighter, mv: Dictionary) -> bool:
	var sp := _sp(mv)
	var s := fx.st(user)
	var moves = fx.arena.moves
	match sp:
		"obstruct", "silk_trap", "spiky_shield":
			if not fx._stall_ok(s):
				fx._fail(user)
				return true
			fx.set_rounds(s, "b_guard", 1)
			s["guard"] = sp
			user.popup(String(GUARD_TEXT[sp]), GUARD_COL[sp], 1.1)
			fx._vfx("protect_shield", [user, fx.round_left()])
		"mud_sport":
			if fx.active(fx.field, "mud_sport"):
				fx._fail(user)
				return true
			fx.set_rounds(fx.field, "mud_sport", BattleMoveEffects.FIELD_TURNS)
			fx.arena.popup(
				user.position + Vector3(0, 1.6, 0), "Mud on the court!", Dex.type_color("ground")
			)
		"no_retreat":
			for k in STAT_KEYS:
				moves.change_stage(user, k, 1)
			s["no_retreat"] = true
			s["trapped"] = true
			user.popup("No retreat!", Dex.type_color("fighting"), 1.0, 0.8)
		"power_trick":
			var a = user.stats.get("atk", 10)
			user.stats["atk"] = user.stats.get("def", 10)
			user.stats["def"] = a
			user.popup("Attack and Defense swapped!", Dex.type_color("psychic"))
		"refresh":
			user.clear_status()
			user.popup("Refreshed!", Color(0.8, 1.0, 0.8))
		"revival_blessing":
			_revive(fx, user)
		"rototiller":
			var n := 0
			for f in fx.arena.fighters:
				if _ok(f) and "grass" in f.types and fx.grounded(f):
					moves.change_stage(f, "atk", 1)
					moves.change_stage(f, "spa", 1)
					n += 1
			if n == 0:
				fx._fail(user)
		"shed_tail":
			_shed_tail(fx, user)
		"shore_up":
			fx._heal(user, int(ceil(user.max_hp * (2.0 / 3.0 if fx.weather() == "sand" else 0.5))))
		"sticky_web":
			_sticky_web(fx, user)
		"stuff_cheeks":
			if _held_berry(fx, user):
				_eat_held(fx, user)
			elif not fx._berries_near(user).is_empty():
				fx._eat_berry_near(user, user)
			else:
				fx._fail(user)
				return true
			user.set_meta("ate_berry", true)
			moves.change_stage(user, "def", 2)
		"take_heart":
			user.clear_status()
			user.confusion_t = 0.0
			moves.change_stage(user, "spa", 1)
			moves.change_stage(user, "spd", 1)
		"teatime":
			var ate := 0
			for f in fx.arena.fighters:
				if _ok(f) and _eat_held(fx, f):
					ate += 1
			if ate == 0:
				fx._fail(user)
		"tidy_up":
			_tidy_up(fx, user)
		"shell_trap":
			_shell_arm(fx, user)
		_:
			return false
	return true


static func _revive(fx: BattleMoveEffects, user: BattleFighter) -> void:
	var m := _fainted_ally(fx, user)
	if m == null:
		fx._fail(user)
		return
	m.hp = maxi(1, m.max_hp / 2)
	m.status = ""
	m.battle_status = ""
	user.popup("Revived %s!" % m.display_name, Color(1.0, 0.95, 0.75), 1.2, 0.9)
	# Adversário: o reanimado volta para a fila de quem ainda vai entrar.
	if user.side == 1:
		var list = fx.arena.get("enemies")
		var idx = fx.arena.get("enemy_index")
		var i: int = list.find(m) if list is Array else -1
		if i >= 0 and idx != null and i <= int(idx):
			list.remove_at(i)
			fx.arena.set("enemy_index", int(idx) - 1)
			list.insert(int(idx), m)


static func _shed_tail(fx: BattleMoveEffects, user: BattleFighter) -> void:
	var cost := maxi(1, user.max_hp / 2)
	if user.hp <= cost or not fx.has_reserve(user):
		fx._fail(user)
		return
	user.take_damage(cost, Vector3.ZERO, 0.0)
	user.popup("Shed its tail! -%d" % cost, Color(0.9, 0.85, 0.8), 0.9)
	var amt := maxi(1, user.max_hp / 4)
	fx.arena.later(
		BattleMoveEffects.PIVOT_DELAY,
		func() -> void:
			if not _ok(user) or not fx.arena.has_method("switch_out"):
				return
			var nf = fx.arena.switch_out(user)
			if nf != null:
				fx.st(nf)["sub"] = amt
				nf.popup("Took over the substitute!", Color(0.9, 0.9, 0.95))
				fx._vfx("substitute", [nf, true])
	)


## Sticky Web: até 3 teias no chão em volta de cada adversário (onde ele ainda não pisa); sem o chão vivo,
## a Velocidade cai direto.
static func _sticky_web(fx: BattleMoveEffects, user: BattleFighter) -> void:
	var foes := fx._foes(user)
	if foes.is_empty():
		fx._fail(user)
		return
	var ex = _extras(fx)
	for foe in foes:
		if ex == null:
			fx.arena.moves.change_stage(foe, "spe", -1, user)
			continue
		var to: Vector3 = user.position - foe.position
		to.y = 0.0
		var dir := to.normalized() if to.length() > 0.1 else Vector3.RIGHT
		var side := Vector3(-dir.z, 0.0, dir.x)
		var at := Vector3(foe.position.x, 0.0, foe.position.z) + dir * WEB_AHEAD
		for off in [Vector3.ZERO, side * WEB_SIDE, -side * WEB_SIDE]:
			ex._add_web(at + off, user, true)
	fx._sd(user.side)["web_t"] = fx.now
	user.popup("Sticky Web!", Dex.type_color("bug"), 1.0, 0.8)


## Teias, cipós e pedrinhas do cenário (BattleGroundExtras), se o chão vivo está ligado.
static func _extras(fx: BattleMoveEffects):
	var ter = fx.arena.get("terrain")
	if ter == null:
		return null
	var g = ter.get("ground")
	if g == null or not g.on or g.extras == null or not g.extras.on:
		return null
	return g.extras


## Tidy Up: +1 Ataque e Velocidade; limpa espinhos, pedras, teias do cenário e substitutos.
static func _tidy_up(fx: BattleMoveEffects, user: BattleFighter) -> void:
	fx.arena.moves.change_stage(user, "atk", 1)
	fx.arena.moves.change_stage(user, "spe", 1)
	fx.spikes.clear()
	if fx.arena.field and fx.arena.field.has_method("clear_spikes"):
		fx.arena.field.clear_spikes(-1)
	var ex = _extras(fx)
	if ex != null:
		for w in ex.webs.duplicate():
			ex._drop(ex.webs, w)
	for f in fx.arena.fighters:
		if _ok(f) and int(fx.st(f).sub) > 0:
			fx.st(f)["sub"] = 0
			f.popup("Substitute faded!", Color(0.85, 0.85, 0.85), 0.9)
			fx._vfx("substitute", [f, false])
	user.popup("Tidied up!", Color(0.9, 0.9, 0.85), 1.0, 0.8)


## Shell Trap: armado por SHELL_WINDOW s (o usuário parado); um golpe físico recebido explode na hora.
static func _shell_arm(fx: BattleMoveEffects, user: BattleFighter) -> void:
	var until := fx.now + SHELL_WINDOW
	fx.st(user)["shell_until"] = until
	user.root_t = maxf(user.root_t, SHELL_WINDOW)
	user.popup("Trap set!", Dex.type_color("fire"), 1.0, 0.8)
	fx._vfx("protect_shield", [user, SHELL_WINDOW])
	fx.arena.later(
		SHELL_WINDOW + 0.05,
		func() -> void:
			if (
				is_instance_valid(user)
				and is_equal_approx(float(fx.st(user).get("shell_until", -99.0)), until)
			):
				fx.st(user)["shell_until"] = -99.0
				fx.note_fail(user)
				user.popup("The trap failed!", Color(0.8, 0.8, 0.8))
	)


static func _shell_boom(fx: BattleMoveEffects, user: BattleFighter) -> void:
	var base := Dex.move("shell_trap")
	var m := base.duplicate()
	m["kind"] = "aoe_self"
	m["power"] = float(base.get("bp", SHELL_BOOM_POWER))
	m["knockback"] = 9
	m["windup"] = 0.12
	m["radius"] = SHELL_RADIUS
	m["special"] = ""
	m.erase("priority")
	user.popup("The trap exploded!", Dex.type_color("fire"), 1.1, 0.9)
	fx.arena.moves._aoe_self(user, fx.arena.moves._cast_copy(user, m))


# --- Troca de atributo em área (debuff_aoe com "special") ---


static func debuff_move(
	fx: BattleMoveEffects, user: BattleFighter, t: BattleFighter, mv: Dictionary
) -> bool:
	var sp := _sp(mv)
	if not sp in ["stats_down", "parting_shot"]:
		return false
	var stats = mv.get("stats")
	if stats is Dictionary:
		for k in stats:
			fx.arena.moves.change_stage(t, String(k), int(stats[k]), user)
	if sp == "parting_shot":
		var s := fx.st(user)
		if int(s.get("pivot_cast", -1)) != user.cast_n and fx.has_reserve(user):
			s["pivot_cast"] = user.cast_n
			user.popup("See ya!", Dex.type_color("dark"), 0.9)
			fx.arena.later(BattleMoveEffects.PIVOT_DELAY, func() -> void: fx._switch(user, false))
	return true


# --- A IA ---


static func ai_power(
	fx: BattleMoveEffects, user: BattleFighter, _target: BattleFighter, mv: Dictionary
) -> float:
	if _sp(mv) == "shell_trap":
		return float(mv.get("bp", SHELL_BOOM_POWER)) if _phys_threat(fx, user) else 0.0
	return -1.0


static func ai_worth(fx: BattleMoveEffects, f: BattleFighter, mv: Dictionary) -> Variant:
	var opp := f.opponent
	var has_opp := _ok(opp)
	var hp := float(f.hp) / maxf(float(f.max_hp), 1.0)
	var s := fx.st(f)
	match _sp(mv):
		"obstruct", "silk_trap", "spiky_shield":
			return fx._threatened(f)
		"shell_trap":
			return _phys_threat(fx, f)
		"mud_sport":
			return (
				not fx.active(fx.field, "mud_sport")
				and has_opp
				and fx._has_type_hit(opp, "electric")
				and not fx._has_type_hit(f, "electric")
			)
		"no_retreat":
			return not bool(s.get("no_retreat", false)) and hp > 0.6
		"power_trick":
			return f.stat("def") > f.stat("atk") * 1.3 and fx._has_cat(f, "physical")
		"refresh":
			return f.status in CURABLE
		"revival_blessing":
			return _fainted_ally(fx, f) != null
		"rototiller":
			return "grass" in f.types and fx.grounded(f)
		"shed_tail":
			return hp > 0.55 and fx.has_reserve(f) and fx._threatened(f)
		"shore_up":
			return hp < 0.5
		"sticky_web":
			return (
				has_opp
				and not "bug" in opp.types
				and fx.now - float(fx._sd(f.side).get("web_t", -99.0)) > WEB_REPEAT
			)
		"stuff_cheeks":
			return _has_berry(fx, f) and int(f.stages.get("def", 0)) < 2
		"take_heart":
			return f.status != "" or (int(f.stages.get("spa", 0)) < 1 and fx._has_cat(f, "special"))
		"teatime":
			return _held_berry(fx, f) and hp < 0.7
		"tidy_up":
			return (
				fx.spikes.any(func(z): return int(z.side) != f.side)
				or (has_opp and int(fx.st(opp).sub) > 0)
				or int(f.stages.get("atk", 0)) < 1
			)
		"magic_powder":
			return (
				has_opp
				and not "psychic" in opp.types
				and not "grass" in opp.types
				and (
					fx._has_type_hit(f, "ghost")
					or fx._has_type_hit(f, "dark")
					or fx._has_type_hit(f, "bug")
				)
			)
		"octolock":
			return has_opp and not fx.active(fx.st(opp), "octolock") and not "ghost" in opp.types
		"odor_sleuth":
			return (
				has_opp
				and not bool(fx.st(opp).get("odor", false))
				and ("ghost" in opp.types or opp.evasion_t > 0.0)
			)
		"psycho_shift":
			return has_opp and f.status in BattleMoveEffects.MAJOR and opp.status == ""
		"purify", "spicy_extract":
			return false  # só ajudam quem leva (o parceiro); o alvo da IA é o adversário
		"quash":
			return has_opp and opp.gcd_t <= 0.2 and fx._threatened(f)
		"sketch":
			return (
				has_opp and fx._copyable(fx._last_of(opp)) != "" and not fx._last_of(opp) in f.moves
			)
		"tar_shot":
			return (
				has_opp and not bool(fx.st(opp).get("tar", false)) and fx._has_type_hit(f, "fire")
			)
		"topsy_turvy":
			return has_opp and fx._stage_sum(opp) >= 2
		"torment":
			return has_opp and not bool(fx.st(opp).get("torment", false))
		"toxic_thread":
			return (
				has_opp and opp.status == "" and not ("poison" in opp.types or "steel" in opp.types)
			)
		"trick_or_treat":
			return has_opp and not "ghost" in opp.types and fx._has_type_hit(f, "ghost")
		"stats_down":
			return (
				has_opp
				and (int(opp.stages.get("atk", 0)) > -2 or int(opp.stages.get("spa", 0)) > -2)
			)
		"parting_shot":
			return (
				has_opp
				and fx.has_reserve(f)
				and (hp < 0.6 or fx._threatened(f))
				and (int(opp.stages.get("atk", 0)) > -2 or int(opp.stages.get("spa", 0)) > -2)
			)
	return null


# --- Eventos ---


## Alvo levou dano de golpe: um golpe físico no usuário do Shell Trap armado explode a armadilha.
static func note_damage(
	fx: BattleMoveEffects, user: BattleFighter, target: BattleFighter, mv: Dictionary, _dealt: int
) -> void:
	if user.side == target.side or not target.alive():
		return
	var ts := fx.st(target)
	if (
		fx.now < float(ts.get("shell_until", -99.0))
		and String(mv.get("category", "")) == "physical"
	):
		ts["shell_until"] = -99.0
		_shell_boom(fx, target)


static func note_faint(_fx: BattleMoveEffects, _f: BattleFighter) -> void:
	pass


static func tick(_fx: BattleMoveEffects, _dt: float) -> void:
	pass


## Fim de turno (uma vez por rodada por lutador): proteções, xarope, tentáculos e a lama do Mud Sport.
static func end_turn(fx: BattleMoveEffects, f: BattleFighter) -> void:
	var s := fx.st(f)
	fx.count_round(s, "b_guard")
	if fx.active(s, "syrup"):
		fx.arena.moves.change_stage(f, "spe", -1)
		fx.count_round(s, "syrup")
	if fx.active(s, "octolock"):
		var by = s.get("octo_by")
		var gone := not _ok(by)
		if not gone:
			fx.arena.moves.change_stage(f, "def", -1)
			fx.arena.moves.change_stage(f, "spd", -1)
		if fx.count_round(s, "octolock") or gone:
			_octo_end(fx, f)
	var et = fx.arena.get("end_turn")
	var rid: int = int(et.rounds) if et != null else fx._round_id()
	if fx.active(fx.field, "mud_sport") and int(fx.field.get("mud_sport_r", -1)) != rid:
		fx.field["mud_sport_r"] = rid
		if fx.count_round(fx.field, "mud_sport"):
			f.popup("The mud dried up.", BattleEndTurn.COL_END, 0.8)

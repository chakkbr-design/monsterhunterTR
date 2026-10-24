class_name BattleMoveEffects
extends RefCounted
## Mecânicas dos golpes da Gen 9 que não cabem num `kind` de entrega: proteção, recuo, poder variável,
## dano fixo e OHKO, cura, Stockpile, clima, terreno, telas, Tailwind, Gravity, Toxic Spikes, Follow Me,
## Metronome/Copycat/Mimic, Imprison, Spite, Disable, Encore, Mean Look, troca de habilidade etc.
## Chamado pelos ganchos de BattleMoves (use/deliver/hit) e pela arena (tick). Campo "special" do golpe.
## Tempo real: 1 turno da série = TURN segundos para os efeitos de campo (status já duram em segundos).

const TURN := 1.6
const PROTECT_TIME := 0.8
const QUICK_GUARD_TIME := 1.2
const FIELD_TURNS := 5
const TAILWIND_TURNS := 4
const FOLLOW_TIME := 3.2
const LASER_TIME := 6.0
const CHARGE_TIME := 8.0
const CURSE_TIME := 8.0
const ROOST_TIME := TURN
## Prioridade negativa: preparo extra por nível (Whirlwind -6 sai 0,6 s mais devagar) e GCD maior.
const NEG_PRIORITY_DELAY := 0.1
const NEG_PRIORITY_GCD := 0.05
const ASSURANCE_WINDOW := 1.5
const ROUND_WINDOW := 2.0
## Golpe de 2 a 5 acertos: distribuição oficial (Gen 5+).
const HITS_ODDS := [[2, 0.35], [3, 0.35], [4, 0.15], [5, 0.15]]
const TOXIC_SPIKE_R := 1.1
const TOXIC_SPIKE_LIFE := 20.0
const BERRY_REACH := 2.0
const SCREEN_MULT := 0.5
const SCREEN_MULT_DOUBLES := 2.0 / 3.0
const GRASSY_BOOST := 1.3
const QUAKE_MOVES := ["earthquake", "bulldoze", "magnitude"]
## Fora de Metronome/Copycat/Mimic (como a lista oficial, com os que só existem aqui).
const CALL_BAN := [
	"metronome",
	"copycat",
	"mimic",
	"struggle",
	"protect",
	"quick_guard",
	"follow_me",
	"rage_powder",
	"after_you",
	"feint",
	"helping_hand",
	"covet",
	"thief",
	"belch",
	"spit_up",
	"swallow",
	"stockpile",
	"healing_wish",
	"self_destruct",
	"transform",
]
## Helping Hand: o parceiro tem HELP_WINDOW s para soltar um golpe de dano, que vale 1,5x por
## HELP_HOLD s (cobre jatos e golpes de vários acertos do mesmo uso).
const HELP_WINDOW := 4.0
const HELP_HOLD := 2.5
const HELP_MULT := 1.5
const MAJOR := ["burn", "poison", "toxic", "paralysis", "sleep", "freeze"]
const HEAL_COL := Color(0.5, 1.0, 0.55)

var arena: Node
var rng: RandomNumberGenerator
var now := 0.0
## Último golpe usado na luta por qualquer um (Copycat).
var last_any := ""
var sides := [{}, {}]
var field := {}
var spikes: Array = []
var _st := {}
var _last_crit := false
var _turn_acc := 0.0


func _init(a: Node, r: RandomNumberGenerator) -> void:
	arena = a
	rng = r


func st(f: BattleFighter) -> Dictionary:
	var id := f.get_instance_id()
	if not _st.has(id):
		_st[id] = {
			"last": "",
			"hurt_t": -99.0,
			"protect": -99.0,
			"follow": -99.0,
			"laser": -99.0,
			"charged": -99.0,
			"roost": -99.0,
			"curse": -99.0,
			"stock": 0,
			"stock_gain": {},
			"spit": 0,
			"chain": {},
			"echo_n": 0,
			"round2": false,
			"imprison": false,
			"trapped": false,
			"curled": false,
			"self_cast": -1,
			"helped": -99.0,
			"help_id": "",
			"help_t": -99.0,
		}
	return _st[id]


func _sd(side: int) -> Dictionary:
	return sides[clampi(side, 0, 1)]


func _left(d: Dictionary, k: String) -> float:
	return float(d.get(k, -99.0)) - now


func active(d: Dictionary, k: String) -> bool:
	return _left(d, k) > 0.0


## Efeito de lado ativo (safeguard, light_screen, tailwind...). A IA consulta.
func side_active(side: int, k: String) -> bool:
	return active(_sd(side), k)


func _ability(f: BattleFighter) -> String:
	if arena.abilities and arena.abilities.has_method("ability_of"):
		return String(arena.abilities.ability_of(f))
	return String(f.mon.ability) if f.mon else ""


func partner(f: BattleFighter) -> BattleFighter:
	for g in arena.fighters:
		if g != f and is_instance_valid(g) and g.side == f.side and g.active():
			return g
	return null


func _foes(f: BattleFighter) -> Array:
	return arena.targets_of(f)


func _vfx(name: String, args: Array) -> void:
	if arena.vfx and arena.vfx.has_method(name):
		arena.vfx.callv(name, args)


func _heal(f: BattleFighter, n: int) -> void:
	n = mini(n, f.max_hp - f.hp)
	if n <= 0 or not f.alive():
		return
	f.heal(n)
	f.popup("+%d" % n, HEAL_COL, 0.9, 0.3, "heal")
	_vfx("heal", [f])


func _fail(f: BattleFighter) -> void:
	f.popup("Mas falhou!", Color(0.8, 0.8, 0.8))


func grounded(f: BattleFighter) -> bool:
	if active(field, "gravity"):
		return true
	return (
		not f.is_airborne()
		and f.fly_h < 0.3
		and not "flying" in f.types
		and _ability(f) != "levitate"
	)


# --- Clima (o de battle_abilities quando existe; senão o daqui) ---


func weather() -> String:
	var ab = arena.abilities
	if ab and ab.has_method("weather_now"):
		var w = ab.weather_now()
		if w is Dictionary:
			w = w.get("kind", "")
		return _norm_weather(String(w) if w != null else "")
	return String(field.get("weather", "")) if active(field, "weather_t") else ""


func _local_weather() -> bool:
	return not (arena.abilities and arena.abilities.has_method("set_weather"))


static func _norm_weather(w: String) -> String:
	match w:
		"sandstorm":
			return "sand"
		"rain_dance":
			return "rain"
		"sunny_day":
			return "sun"
	return w


func set_weather(kind: String, secs: float) -> void:
	if not _local_weather():
		arena.abilities.set_weather(kind, secs)
	else:
		field["weather"] = kind
		field["weather_t"] = now + secs
	_vfx("weather", [kind, secs])


# --- Ganchos de BattleMoves.use ---


## Golpe que não pode sair agora (sem Stockpile, sem frutinha, aprisionado...). A IA também consulta.
func usable(user: BattleFighter, mv: Dictionary, feedback := false) -> bool:
	var why := _blocked(user, mv)
	if why != "" and feedback:
		user.popup(why, Color(0.85, 0.85, 0.85))
	return why == ""


func _blocked(user: BattleFighter, mv: Dictionary) -> String:
	var id := String(mv.get("id", ""))
	for foe in _foes(user):
		if bool(st(foe).imprison) and id in foe.moves:
			return "Aprisionado!"
	match String(mv.get("special", "")):
		"spit_up", "swallow":
			if int(st(user).stock) <= 0:
				return "Nada guardado!"
		"belch":
			if not user.has_meta("ate_berry"):
				return "Precisa comer frutinha!"
		"healing_wish":
			if not has_reserve(user):
				return "Ninguém para entrar!"
		"rest":
			if user.hp >= user.max_hp or user.status == "sleep":
				return "Mas falhou!"
			if _ability(user) in ["insomnia", "vital_spirit"]:
				return "Não consegue dormir!"
		"mimic":
			if _copyable(_last_of(user.opponent)) == "":
				return "Nada para copiar!"
		"copycat":
			if _copyable(last_any) == "":
				return "Nada para copiar!"
		"after_you":
			if partner(user) == null:
				return "Mas falhou!"
		"stockpile":
			if int(st(user).stock) >= 3:
				return "Não cabe mais!"
	return ""


func _last_of(f: BattleFighter) -> String:
	return String(st(f).last) if is_instance_valid(f) else ""


func _copyable(id: String) -> String:
	if id == "" or id in CALL_BAN or Dex.move(id).is_empty():
		return ""
	return id


func has_reserve(user: BattleFighter) -> bool:
	var list = arena.get("party") if user.side == 0 else arena.get("enemies")
	if not list is Array:
		return false
	var on_field := {}
	for f in arena.fighters:
		if is_instance_valid(f) and f.active():
			on_field[f.mon] = true
	for m in list:
		if m is Mon and m != user.mon and m.hp > 0 and not on_field.has(m):
			return true
	return false


## Prioridade negativa sai mais devagar (preparo extra) e segura o GCD um pouco mais.
func priority_delay(user: BattleFighter, mv: Dictionary) -> float:
	var p := int(mv.get("priority", 0))
	if p >= 0:
		return 0.0
	user.gcd_t += NEG_PRIORITY_GCD * -p
	return NEG_PRIORITY_DELAY * -p


func on_use(user: BattleFighter, mv: Dictionary) -> void:
	var id := String(mv.get("id", ""))
	var s := st(user)
	s.last = id
	if not String(mv.get("special", "")) in ["copycat", "metronome"]:
		last_any = id
	var sd := _sd(user.side)
	if float(mv.get("power", 0)) > 0.0 and now - float(s.helped) <= HELP_WINDOW:
		# Helping Hand: o próximo golpe de dano do parceiro sai com 1,5x
		s.help_id = id
		s.help_t = now
		s.helped = -99.0
	match String(mv.get("special", "")):
		"chain":
			var c: Dictionary = s.chain.get(id, {"n": 0, "t": -99.0, "cast": 0, "hit": 0})
			if int(c.hit) != int(c.cast) or now - float(c.t) > _chain_window(mv):
				c.n = 0
			c.cast = int(c.cast) + 1
			c.t = now
			s.chain[id] = c
		"echoed_voice":
			var win := _chain_window(mv)
			sd["echo_n"] = (
				mini(int(sd.get("echo_n", 0)) + 1, 4)
				if now - float(sd.get("echo_t", -99.0)) <= win
				else 0
			)
			sd["echo_t"] = now
			s.echo_n = int(sd.echo_n)
		"round":
			var prev_t := float(sd.get("round_t", -99.0))
			s.round2 = (
				now - prev_t <= ROUND_WINDOW
				and int(sd.get("round_by", 0)) != user.get_instance_id()
			)
			sd["round_t"] = now
			sd["round_by"] = user.get_instance_id()
		"spit_up":
			s.spit = int(s.stock)
			_drop_stockpile(user)
		"self_confuse":
			var wait := float(mv.get("duration", 0.0)) + float(mv.get("windup", 0.0)) + 0.6
			arena.later(
				wait,
				func() -> void:
					if is_instance_valid(user) and user.alive() and user.apply_status("confusion"):
						user.popup("Ficou confuso de cansaço!", Dex.type_color("psychic"))
			)
	var cs = mv.get("charge_stats")
	if cs is Dictionary:
		for k in cs:
			arena.moves.change_stage(user, String(k), int(cs[k]))


func _chain_window(mv: Dictionary) -> float:
	return Dex.cooldown(mv) * 1.5 + 1.5


# --- Ganchos de BattleMoves.deliver ---


func accuracy_of(user: BattleFighter, mv: Dictionary) -> float:
	var acc := float(mv.get("accuracy", 0.0))
	if acc <= 0.0:
		return 0.0
	var id := String(mv.get("id", ""))
	if id == "toxic" and "poison" in user.types:
		return 0.0
	if id in ["thunder", "hurricane"] and weather() == "rain":
		return 0.0
	if String(mv.get("special", "")) == "ohko":
		var t := user.opponent
		if is_instance_valid(t):
			acc += float(user.level - t.level)
	if active(field, "gravity"):
		acc *= 5.0 / 3.0
	return acc


func roll_hits(mv: Dictionary) -> Dictionary:
	var hr = mv.get("hits_range")
	if not hr is Array:
		return mv
	var n := int(hr[1])
	var r := rng.randf()
	for row in HITS_ODDS:
		r -= float(row[1])
		if r < 0.0:
			n = int(row[0])
			break
	n = clampi(n, int(hr[0]), int(hr[1]))
	var m := mv.duplicate()
	if String(mv.get("kind", "")) == "projectile":
		m["count"] = n
	else:
		m["hits"] = n
	return m


# --- Ganchos de BattleMoves.hit ---


## Golpe parado antes de acertar (Protect, Quick Guard, pó em Grama, Thunder Wave em Terra).
func blocks_hit(user: BattleFighter, target: BattleFighter, mv: Dictionary) -> bool:
	if not is_instance_valid(user) or target.side == user.side:
		return false
	var sp := String(mv.get("special", ""))
	if (
		bool(mv.get("powder", false))
		and ("grass" in target.types or _ability(target) == "overcoat")
	):
		target.popup("Sem efeito...", Color(0.7, 0.7, 0.7))
		return true
	if sp == "thunder_wave" and "ground" in target.types:
		target.popup("Sem efeito...", Color(0.7, 0.7, 0.7))
		return true
	var ts := st(target)
	var sd := _sd(target.side)
	if sp == "feint":
		if active(ts, "protect") or active(sd, "quick_guard"):
			ts.protect = -99.0
			sd.erase("quick_guard")
			target.popup("A proteção caiu!", Color(1, 0.8, 0.5))
		return false
	if sp == "no_protect":
		return false
	if active(ts, "protect"):
		target.popup("Protegeu-se!", Color(0.6, 0.9, 1.0), 1.1)
		return true
	if int(mv.get("priority", 0)) > 0 and active(sd, "quick_guard"):
		target.popup("Guarda Rápida!", Color(0.6, 0.9, 1.0))
		return true
	return false


## Golpe que não usa a fórmula: OHKO (Fissure) e Endeavor. true = já resolvido aqui.
func exact_hit(user: BattleFighter, target: BattleFighter, mv: Dictionary, dir: Vector3) -> bool:
	var sp := String(mv.get("special", ""))
	if sp != "ohko" and sp != "endeavor":
		return false
	var prof := defender_profile(user, target, mv)
	if Dex.effectiveness(String(mv.get("type", "normal")), prof.types) == 0.0:
		target.popup("Sem efeito...", Color(0.7, 0.7, 0.7))
		return true
	var amount := 0
	if sp == "ohko":
		if target.level > user.level or _ability(target) == "sturdy":
			target.popup("Não afetou!", Color(0.8, 0.8, 0.8))
			return true
		amount = target.hp
	else:
		if target.hp <= user.hp:
			_fail(user)
			return true
		amount = target.hp - user.hp
	var hp_before := target.hp
	target.last_hit_by = user
	target.take_damage(
		amount, dir, float(mv.get("knockback", 4.0)), {"source": user, "eff": 1.0, "final": true}
	)
	target.popup(str(amount), Color(0.95, 0.3, 0.25), 1.2, 0.35, "damage")
	if sp == "ohko" and not target.alive():
		target.popup("NOCAUTE EM UM GOLPE!", Color(1, 0.55, 0.3), 1.2, 0.8, "crit")
	arena.note_hit(user, target, mv, amount, hp_before)
	if amount >= hp_before and arena.has_method("on_knocked_out"):
		arena.on_knocked_out(user, target)
	st(target).hurt_t = now
	return true


## Poder do golpe neste acerto (variável, crítico forçado, Charge...). Duplica só se mudar algo.
func adjust_move(user: BattleFighter, target: BattleFighter, m: Dictionary) -> Dictionary:
	var s := st(user)
	var p := float(m.get("power", 0))
	var p0 := p
	var id := String(m.get("id", ""))
	match String(m.get("special", "")):
		"chain":
			var c: Dictionary = s.chain.get(id, {})
			p *= pow(2.0, mini(int(c.get("n", 0)), int(m.get("chain", 2))))
			if id == "rollout" and bool(s.curled):
				p *= 2.0
		"echoed_voice":
			p = minf(p * (int(s.echo_n) + 1), 200.0)
		"round":
			if bool(s.round2):
				p *= 2.0
		"spit_up":
			p = 100.0 * maxi(int(s.spit), 1)
		"stored_power":
			var up := 0
			for k in user.stages:
				up += maxi(int(user.stages[k]), 0)
			p = 20.0 + 20.0 * up
		"venoshock":
			if target.status in ["poison", "toxic"]:
				p *= 2.0
		"assurance":
			if now - float(st(target).hurt_t) <= ASSURANCE_WINDOW:
				p *= 2.0
		"gyro_ball":
			p = clampf(
				floorf(25.0 * target.eff_spe() / maxf(user.eff_spe(), 1.0)) + 1.0, 1.0, 150.0
			)
		"electro_ball":
			var r := user.eff_spe() / maxf(target.eff_spe(), 1.0)
			p = (
				150.0
				if r >= 4.0
				else (120.0 if r >= 3.0 else (80.0 if r >= 2.0 else (60.0 if r >= 1.0 else 40.0)))
			)
		"flail":
			var q := int(48.0 * float(user.hp) / maxf(float(user.max_hp), 1.0))
			p = (
				200.0
				if q <= 1
				else (
					150.0
					if q <= 4
					else (100.0 if q <= 9 else (80.0 if q <= 16 else (40.0 if q <= 32 else 20.0)))
				)
			)
		"low_kick":
			var w := float(Dex.species(target.mon.species).get("weight_kg", 20.0))
			p = (
				20.0
				if w < 10.0
				else (
					40.0
					if w < 25.0
					else (
						60.0
						if w < 50.0
						else (80.0 if w < 100.0 else (100.0 if w < 200.0 else 120.0))
					)
				)
			)
	if String(m.get("type", "")) == "electric" and active(s, "charged"):
		p *= 2.0
	var crit := active(s, "laser")
	if p == p0 and not crit:
		return m
	var out := m.duplicate()
	out["power"] = p
	if crit:
		out["crit"] = 3
	return out


## Perfil do defensor: na Gravity o Voador perde a imunidade a golpe de Terra.
func defender_profile(_user: BattleFighter, target: BattleFighter, m: Dictionary) -> Dictionary:
	var p := target.damage_profile()
	if String(m.get("type", "")) == "ground" and active(field, "gravity") and "flying" in p.types:
		var ty: Array = p.types.duplicate()
		ty.erase("flying")
		p["types"] = ty if not ty.is_empty() else ["normal"]
	return p


## Depois da rolagem: dano fixo (Super Fang, Seismic Toss, Dragon Rage, Sonic Boom). O ritmo da luta
## (damage_pace) continua valendo em cima, como em qualquer golpe.
func on_damage_roll(
	user: BattleFighter, target: BattleFighter, m: Dictionary, res: Dictionary
) -> void:
	_last_crit = bool(res.get("crit", false))
	var fixed := -1
	match String(m.get("special", "")):
		"fixed":
			fixed = int(m.get("fixed", 20))
		"super_fang":
			fixed = maxi(1, target.hp / 2)
		"level_damage":
			fixed = user.level
	if fixed < 0 or float(res.get("eff", 1.0)) == 0.0:
		return
	res["damage"] = fixed
	res["crit"] = false
	res["eff"] = 1.0
	_last_crit = false


## Multiplicador do fim da fórmula: Light Screen, clima e terreno.
func damage_mult(user: BattleFighter, target: BattleFighter, mv: Dictionary) -> float:
	var m := 1.0
	var s := st(user)
	if String(s.help_id) == String(mv.get("id", "")) and now - float(s.help_t) <= HELP_HOLD:
		m *= HELP_MULT
	var type := String(mv.get("type", ""))
	var special: bool = mv.get("category", "") == "special"
	if special and active(_sd(target.side), "light_screen") and not _last_crit:
		m *= SCREEN_MULT_DOUBLES if bool(arena.get("doubles")) else SCREEN_MULT
	if active(field, "grassy"):
		if type == "grass" and grounded(user):
			m *= GRASSY_BOOST
		if String(mv.get("id", "")) in QUAKE_MOVES and grounded(target):
			m *= 0.5
	var w := weather()
	if String(mv.get("id", "")) == "solar_beam" and w in ["rain", "sand", "hail", "snow"]:
		m *= 0.5
	if _local_weather():
		if w == "rain":
			m *= 1.5 if type == "water" else (0.5 if type == "fire" else 1.0)
		elif w == "sand" and special and "rock" in target.types:
			m /= 1.5
	return m


## Status que o golpe não consegue dar (Safeguard; Aço e Veneno não se envenenam).
func blocks_status(user: BattleFighter, target: BattleFighter, s: String) -> bool:
	if s in ["poison", "toxic"] and ("steel" in target.types or "poison" in target.types):
		target.popup("Imune a veneno", Color(0.8, 0.8, 0.8))
		return true
	if (
		(s in MAJOR or s == "confusion")
		and is_instance_valid(user)
		and user.side != target.side
		and active(_sd(target.side), "safeguard")
	):
		target.popup("Protegido pelo Safeguard!", Color(0.7, 0.9, 1.0))
		return true
	return false


## Sheer Force: golpe de dano perde o efeito secundário.
func sheer_force(user: BattleFighter, mv: Dictionary) -> bool:
	return float(mv.get("power", 0)) > 0.0 and _ability(user) == "sheer_force"


func after_hit(user: BattleFighter, target: BattleFighter, mv: Dictionary, dealt: int) -> void:
	if not is_instance_valid(user) or not is_instance_valid(target):
		return
	var s := st(user)
	var id := String(mv.get("id", ""))
	var sp := String(mv.get("special", ""))
	var sheer := sheer_force(user, mv)
	if dealt > 0:
		st(target).hurt_t = now
		if active(s, "laser"):
			s.laser = -99.0
		if String(mv.get("type", "")) == "electric":
			s.charged = -99.0
		if target.status == "freeze" and String(mv.get("type", "")) == "fire" and target.alive():
			target.clear_status()
			target.popup("Descongelou!", Color(0.7, 0.95, 1.0))
		if mv.has("recoil") and user.alive() and _ability(user) != "rock_head":
			var r := maxi(1, int(float(dealt) * float(mv.recoil)))
			user.take_damage(r, Vector3.ZERO, 0.0)
			user.popup("-%d recuo" % r, Color(0.9, 0.6, 0.6), 0.8)
	if not sheer and target.alive():
		if mv.has("flinch") and rng.randf() < float(mv.flinch):
			_status(user, target, "flinch")
		if mv.has("tri") and rng.randf() < float(mv.tri):
			_status(user, target, ["burn", "paralysis", "freeze"][rng.randi() % 3])
	if mv.has("trap") and String(mv.get("kind", "")) in ["zone", "stream"] and target.alive():
		target.trap_t = maxf(target.trap_t, float(mv.trap))
	var ss = mv.get("self_stats")
	if ss is Dictionary and user.alive() and int(s.self_cast) != user.cast_n:
		s.self_cast = user.cast_n
		for k in ss:
			arena.moves.change_stage(user, String(k), int(ss[k]))
	var ts := st(target)
	match sp:
		"chain":
			var c: Dictionary = s.chain.get(id, {})
			if not c.is_empty() and int(c.hit) != int(c.cast):
				c.hit = c.cast
				c.n = int(c.n) + 1
		"fell_stinger":
			if not target.alive() and user.alive():
				arena.moves.change_stage(user, "atk", 3)
		"covet":
			if dealt > 0:
				_steal_item(user, target)
		"pluck":
			if dealt > 0:
				_eat_berry_near(user, target)
		"incinerate":
			_burn_berries_near(target)
		"rapid_spin":
			_rapid_spin(user)
		"mean_look":
			if "ghost" in target.types:
				target.popup("Sem efeito...", Color(0.7, 0.7, 0.7))
			else:
				ts.trapped = true
				target.popup("Não pode fugir!", Color(0.8, 0.6, 0.9))
		"spite":
			var last := _last_of(target)
			if last == "":
				_fail(user)
			else:
				var cut := 4.0 * target.pp_cost_of(Dex.move(last))
				target.pp_max = maxf(target.pp_max - cut, 0.0)
				target.stamina = minf(target.stamina, target.pp_max)
				target.mon.pp = target.pp_max
				target.popup(
					"PP de %s caiu!" % Dex.move(last).get("name", last), Color(0.8, 0.6, 0.9)
				)
		"disable":
			var last2 := _last_of(target)
			if last2 == "":
				_fail(user)
			else:
				target.move_cd[last2] = maxf(float(target.move_cd.get(last2, 0.0)), 4.0 * TURN)
				target.popup(
					"%s desativado!" % Dex.move(last2).get("name", last2), Color(0.8, 0.8, 0.9)
				)
		"encore":
			var last3 := _last_of(target)
			if last3 == "":
				_fail(user)
			else:
				for mid in target.moves:
					if String(mid) != last3:
						target.move_cd[mid] = maxf(float(target.move_cd.get(mid, 0.0)), 3.0 * TURN)
				target.popup(
					"Bis! Só %s!" % Dex.move(last3).get("name", last3), Color(1, 0.85, 0.6)
				)
		"gastro_acid":
			target.set_meta("ability_override", "")
			target.popup("Habilidade anulada!", Color(0.7, 0.9, 0.5))
		"worry_seed":
			target.set_meta("ability_override", "insomnia")
			if target.status == "sleep":
				target.clear_status()
			target.popup("Habilidade virou Insomnia!", Color(0.7, 0.9, 0.5))
		"flatter":
			arena.moves.change_stage(target, "spa", 1)
		"yawn":
			if target.status != "":
				_fail(user)
			else:
				target.popup("Sonolento...", Color(0.75, 0.8, 0.95))
				arena.later(
					TURN,
					func() -> void:
						if is_instance_valid(target) and target.active() and target.status == "":
							_status(user, target, "sleep")
				)


## Status de efeito extra pelas mesmas regras do hit (imunidade de tipo, habilidade, Safeguard).
func _status(user: BattleFighter, target: BattleFighter, s: String) -> void:
	if BattleMoves.STATUS_IMMUNE.get(s, "-") in target.types:
		return
	if arena.abilities and arena.abilities.blocks_status(target, s):
		return
	if blocks_status(user, target, s):
		return
	if target.apply_status(s, user):
		target.popup(
			String(BattleMoves.STATUS_WORDS.get(s, s.to_upper() + "!")),
			Color(1, 0.9, 0.6),
			1.0,
			0.15,
			"status"
		)


func _steal_item(user: BattleFighter, target: BattleFighter) -> void:
	if target.trainer_item == "" or target.item_used or user.trainer_item != "":
		return
	user.trainer_item = target.trainer_item
	user.item_used = false
	target.item_used = true
	var nm := String(Dex.item(user.trainer_item).get("name", user.trainer_item))
	user.popup("Roubou %s!" % nm, Color(1, 0.85, 0.5))


func _berries_near(target: BattleFighter) -> Array:
	var f = arena.get("field")
	if f == null or not "berries" in f:
		return []
	return f.berries.filter(
		func(b):
			return (
				Vector2(b.pos.x - target.position.x, b.pos.z - target.position.z).length()
				<= BERRY_REACH
			)
	)


func _drop_berry(b: Dictionary) -> void:
	arena.field.berries.erase(b)
	if is_instance_valid(b.node):
		b.node.queue_free()


func _eat_berry_near(user: BattleFighter, target: BattleFighter) -> void:
	var near := _berries_near(target)
	if near.is_empty():
		return
	_drop_berry(near[0])
	user.set_meta("ate_berry", true)
	user.popup("Comeu a frutinha!", Color(0.5, 1.0, 0.5), 0.8)
	_heal(user, maxi(1, int(user.max_hp / 10.0)))


func _burn_berries_near(target: BattleFighter) -> void:
	for b in _berries_near(target):
		_drop_berry(b)
		target.popup("A frutinha queimou!", Dex.type_color("fire"), 0.8)


func _rapid_spin(user: BattleFighter) -> void:
	if user.status == "leech":
		user.clear_status()
	user.trap_t = 0.0
	for z in spikes.duplicate():
		if int(z.side) != user.side:
			_drop_spike(z)


# --- self_buff com "special" ou vários atributos ---


## true = o golpe foi resolvido aqui (o _self_buff padrão não roda).
func self_move(user: BattleFighter, mv: Dictionary) -> bool:
	var sp := String(mv.get("special", ""))
	var s := st(user)
	var sd := _sd(user.side)
	if sp == "curse" and "ghost" in user.types:
		var foe := user.opponent
		user.take_damage(maxi(1, user.max_hp / 2), Vector3.ZERO, 0.0)
		if is_instance_valid(foe) and foe.active():
			st(foe).curse = now + CURSE_TIME
			st(foe).curse_tick = now + TURN
			foe.popup("Amaldiçoado!", Dex.type_color("ghost"))
		return true
	var stats = mv.get("stats")
	if stats is Dictionary and sp in ["", "curse"]:
		for k in stats:
			arena.moves.change_stage(user, String(k), int(stats[k]))
		return true
	match sp:
		"", "charge", "defense_curl":
			if sp == "charge":
				s.charged = now + CHARGE_TIME
				user.popup("Carregado!", Dex.type_color("electric"))
			elif sp == "defense_curl":
				s.curled = true
			return false
		"protect":
			s.protect = now + PROTECT_TIME
			user.popup("Proteger!", Color(0.6, 0.9, 1.0), 1.1)
			_vfx("protect_shield", [user, PROTECT_TIME])
		"quick_guard":
			sd["quick_guard"] = now + QUICK_GUARD_TIME
			user.popup("Guarda Rápida!", Color(0.6, 0.9, 1.0))
			_vfx("protect_shield", [user, QUICK_GUARD_TIME])
		"follow_me":
			s.follow = now + FOLLOW_TIME
			s.follow_powder = bool(mv.get("powder", false))
			user.popup("Todos olham para %s!" % user.mon.display_name, Color(1, 0.8, 0.5))
			_vfx("spotlight", [user, FOLLOW_TIME])
		"after_you":
			var p := partner(user)
			if p == null:
				_fail(user)
			else:
				p.gcd_t = 0.0
				var best := ""
				for mid in p.moves:
					if (
						best == ""
						or float(p.move_cd.get(mid, 0.0)) < float(p.move_cd.get(best, 0.0))
					):
						best = String(mid)
				if best != "":
					p.move_cd[best] = 0.0
				p.popup("Vai você primeiro!", Color(0.8, 0.9, 1.0))
		"helping_hand":
			var ally := partner(user)
			if ally and ally.alive():
				st(ally).helped = now
				ally.popup("Ajuda!", Color(1.0, 0.85, 0.4), 0.8)
			else:
				_fail(user)
		"laser_focus":
			s.laser = now + LASER_TIME
			user.popup("Mira perfeita!", Color(1, 0.6, 0.3))
		"imprison":
			s.imprison = true
			user.popup("Aprisionou os golpes!", Dex.type_color("psychic"))
		"stockpile":
			if int(s.stock) >= 3:
				_fail(user)
				return true
			s.stock = int(s.stock) + 1
			for k in ["def", "spd"]:
				var before := int(user.stages.get(k, 0))
				arena.moves.change_stage(user, k, 1)
				var g: Dictionary = s.stock_gain
				g[k] = int(g.get(k, 0)) + int(user.stages.get(k, 0)) - before
			user.popup("Guardou %d!" % int(s.stock), Color(0.9, 0.85, 0.6))
		"swallow":
			var n := int(s.stock)
			if n <= 0:
				_fail(user)
				return true
			_heal(user, int(ceil(user.max_hp * [0.0, 0.25, 0.5, 1.0][mini(n, 3)])))
			_drop_stockpile(user)
		"heal_weather":
			var w := weather()
			var k2 := 0.5
			if w == "sun":
				k2 = 2.0 / 3.0
			elif w != "":
				k2 = 0.25
			_heal(user, int(ceil(user.max_hp * k2)))
		"roost":
			_heal(user, int(ceil(user.max_hp * float(mv.get("heal", 0.5)))))
			if "flying" in user.types:
				s.roost = now + ROOST_TIME
				s.roost_types = user.types.duplicate()
				var ty: Array = user.types.duplicate()
				ty.erase("flying")
				user.types = ty if not ty.is_empty() else ["normal"]
				user.fly_target = 0.0
		"rest":
			user.clear_status()
			user.confusion_t = 0.0
			_heal(user, user.max_hp)
			user.apply_status("sleep")
			user.status_t = 2.0 * TURN
			user.popup("Dormiu e recuperou tudo!", Color(0.75, 0.8, 0.95))
		"life_dew":
			for f in [user, partner(user)]:
				if f != null:
					_heal(f, int(ceil(f.max_hp * 0.25)))
		"aromatherapy":
			_aromatherapy(user)
		"haze":
			for f in arena.fighters:
				if is_instance_valid(f) and f.active():
					for k in f.stages:
						f.stages[k] = 0
					f.evasion_t = 0.0
			arena.popup(
				user.position + Vector3(0, 1.6, 0),
				"Névoa: atributos zerados!",
				Color(0.8, 0.9, 1.0)
			)
			_vfx("haze", [user])
		"light_screen", "safeguard":
			sd[sp] = now + FIELD_TURNS * TURN
			user.popup(
				"Light Screen!" if sp == "light_screen" else "Safeguard!", Color(0.9, 0.85, 1.0)
			)
			_vfx("screen", [user.side, sp, FIELD_TURNS * TURN])
		"tailwind":
			sd["tailwind"] = now + TAILWIND_TURNS * TURN
			user.popup("Vento a favor!", Dex.type_color("flying"))
			_vfx("screen", [user.side, sp, TAILWIND_TURNS * TURN])
		"gravity":
			field["gravity"] = now + FIELD_TURNS * TURN
			arena.popup(
				user.position + Vector3(0, 1.6, 0), "Gravidade intensa!", Dex.type_color("psychic")
			)
			_vfx("gravity", [FIELD_TURNS * TURN])
		"grassy_terrain":
			field["grassy"] = now + FIELD_TURNS * TURN
			arena.popup(
				user.position + Vector3(0, 1.6, 0), "Campo de grama!", Dex.type_color("grass")
			)
			_vfx("terrain", ["grassy", FIELD_TURNS * TURN])
		"sandstorm":
			set_weather("sand", FIELD_TURNS * TURN)
			arena.popup(
				user.position + Vector3(0, 1.6, 0), "Tempestade de areia!", Dex.type_color("rock")
			)
		"rain_dance":
			set_weather("rain", FIELD_TURNS * TURN)
			arena.popup(
				user.position + Vector3(0, 1.6, 0), "Começou a chover!", Dex.type_color("water")
			)
		"toxic_spikes":
			_lay_toxic_spikes(user)
		"healing_wish":
			var ids := []
			for f in arena.fighters:
				if is_instance_valid(f) and f.active():
					ids.append(f.get_instance_id())
			sd["wish"] = ids
			user.popup("Desejo de cura!", Color(1, 0.8, 0.95))
			user.take_damage(user.hp, Vector3.ZERO, 0.0)
		"metronome":
			var pool: Array = Dex.all_moves().filter(func(x): return _copyable(String(x)) != "")
			if not pool.is_empty():
				_call(user, String(pool[rng.randi() % pool.size()]))
		"copycat":
			var c := _copyable(last_any)
			if c == "":
				_fail(user)
			else:
				_call(user, c)
		"mimic":
			var c2 := _copyable(_last_of(user.opponent))
			var i := user.moves.find(String(mv.get("id", "mimic")))
			if c2 == "" or i < 0 or c2 in user.moves:
				_fail(user)
			else:
				user.moves[i] = c2
				user.popup("Copiou %s!" % Dex.move(c2).get("name", c2), Color(0.9, 0.9, 1.0))
		_:
			return false
	return true


func _call(user: BattleFighter, id: String) -> void:
	var mv := Dex.move(id)
	user.popup("→ %s!" % mv.get("name", id), Color(1, 0.95, 0.7), 1.0, 0.5)
	arena.later(
		0.25,
		func() -> void:
			if is_instance_valid(user) and user.can_act():
				arena.moves.deliver(user, mv)
	)


func _drop_stockpile(user: BattleFighter) -> void:
	var s := st(user)
	for k in s.stock_gain:
		user.stages[k] = clampi(int(user.stages.get(k, 0)) - int(s.stock_gain[k]), -6, 6)
	s.stock_gain = {}
	s.stock = 0


func _aromatherapy(user: BattleFighter) -> void:
	var cured := 0
	for f in arena.fighters:
		if is_instance_valid(f) and f.active() and f.side == user.side and f.status in MAJOR:
			f.clear_status()
			cured += 1
	var list = arena.get("party") if user.side == 0 else arena.get("enemies")
	if list is Array:
		for m in list:
			if m is Mon and m.hp > 0 and m.status != "":
				m.status = ""
				cured += 1
	user.popup("Aroma calmante!" if cured > 0 else "Ninguém precisava.", Color(0.7, 1.0, 0.7))


func _lay_toxic_spikes(user: BattleFighter) -> void:
	var foes := _foes(user)
	if foes.is_empty():
		_fail(user)
		return
	for foe in foes:
		var at := Vector3(foe.position.x, 0.0, foe.position.z)
		var layered := false
		for z in spikes:
			if int(z.side) == user.side and Vector3(z.pos - at).length() < TOXIC_SPIKE_R + 0.5:
				z.layers = mini(int(z.layers) + 1, 2)
				z.t = now + TOXIC_SPIKE_LIFE
				layered = true
		if not layered:
			spikes.append(
				{"pos": at, "side": user.side, "layers": 1, "t": now + TOXIC_SPIKE_LIFE, "hit": {}}
			)
			arena.fx_disc(
				at, TOXIC_SPIKE_R, Dex.type_color("poison") * Color(1, 1, 1, 0.3), TOXIC_SPIKE_LIFE
			)
			_vfx("toxic_spikes", [user.side, at, TOXIC_SPIKE_R, TOXIC_SPIKE_LIFE])
	user.popup("Espinhos venenosos!", Dex.type_color("poison"))


func _drop_spike(z: Dictionary) -> void:
	spikes.erase(z)


# --- Por frame (arena._fight_step) ---


func tick(dt: float) -> void:
	now += dt
	_turn_acc += dt
	var turn := _turn_acc >= TURN
	if turn:
		_turn_acc -= TURN
	var sand := _local_weather() and weather() == "sand"
	var grassy := active(field, "grassy")
	var gravity := active(field, "gravity")
	for f in arena.fighters:
		if not is_instance_valid(f) or not f.active():
			continue
		var s := st(f)
		if s.has("roost_types") and not active(s, "roost"):
			f.types = s.roost_types
			s.erase("roost_types")
		var grav_on := bool(s.get("grav", false))
		if gravity or active(s, "roost"):
			f.fly_target = 0.0
			s["grav"] = true
		elif grav_on:
			s["grav"] = false
			f.fly_target = float(f.prof.get("fly", 0.0))
		if active(s, "follow"):
			for foe in _foes(f):
				if bool(s.get("follow_powder", false)) and "grass" in foe.types:
					continue
				foe.opponent = f
		if active(s, "curse") and now >= float(s.get("curse_tick", 0.0)):
			s.curse_tick = now + TURN
			var d := maxi(1, int(f.max_hp / 8.0 * f.dot_scale()))
			f.popup("-%d maldição" % d, Dex.type_color("ghost"), 0.8)
			f.take_damage(d, Vector3.ZERO, 0.0)
		if turn and f.alive():
			if grassy and grounded(f) and f.hp < f.max_hp:
				_heal(f, maxi(1, int(f.max_hp / 16.0 * f.dot_scale())))
			if sand and not ("rock" in f.types or "ground" in f.types or "steel" in f.types):
				var d2 := maxi(1, int(f.max_hp / 16.0 * f.dot_scale()))
				f.popup("-%d areia" % d2, Dex.type_color("rock"), 0.8)
				f.take_damage(d2, Vector3.ZERO, 0.0)
	_tick_spikes()
	_tick_wish()


func _tick_spikes() -> void:
	for z in spikes.duplicate():
		if now >= float(z.t):
			_drop_spike(z)
			continue
		for f in arena.fighters:
			if not is_instance_valid(f) or not f.active() or f.side == int(z.side):
				continue
			var id: int = f.get_instance_id()
			if z.hit.has(id) or not grounded(f) or f.position.y > 0.3:
				continue
			if (
				Vector3(f.position.x - z.pos.x, 0.0, f.position.z - z.pos.z).length()
				> TOXIC_SPIKE_R
			):
				continue
			z.hit[id] = true
			if "poison" in f.types:
				f.popup("Absorveu os espinhos!", Dex.type_color("poison"))
				_drop_spike(z)
				break
			_status(null, f, "toxic" if int(z.layers) >= 2 else "poison")


func _tick_wish() -> void:
	for side in 2:
		var ids = sides[side].get("wish")
		if not ids is Array:
			continue
		for f in arena.fighters:
			if (
				is_instance_valid(f)
				and f.active()
				and f.side == side
				and not f.get_instance_id() in ids
			):
				f.clear_status()
				_heal(f, f.max_hp)
				f.popup("O desejo se realizou!", Color(1, 0.8, 0.95), 1.1)
				sides[side].erase("wish")
				break


# --- Consultas de fora ---


func speed_mult(f: BattleFighter) -> float:
	return 2.0 if active(_sd(f.side), "tailwind") else 1.0


func no_jump() -> bool:
	return active(field, "gravity")


func cant_escape(f: BattleFighter) -> bool:
	return is_instance_valid(f) and bool(st(f).trapped) and not "ghost" in f.types


## Dano esperado de OHKO/Endeavor para a IA (-1 = use a fórmula).
func expected_exact(user: BattleFighter, target: BattleFighter, mv: Dictionary) -> float:
	match String(mv.get("special", "")):
		"ohko":
			if target.level > user.level:
				return 0.0
			return float(target.hp) * clampf(accuracy_of(user, mv) / 100.0, 0.0, 1.0)
		"endeavor":
			return float(maxi(target.hp - user.hp, 0))
	return -1.0


## Poder para a IA (variável ou guardado). Sem Stockpile o Spit Up vale 0.
func ai_power(user: BattleFighter, target: BattleFighter, mv: Dictionary) -> float:
	if float(mv.get("power", 0)) <= 0.0:
		return 0.0
	if not usable(user, mv):
		return 0.0
	if String(mv.get("special", "")) == "spit_up":
		return 100.0 * int(st(user).stock)
	return float(adjust_move(user, target, mv).get("power", 0))


## A IA usa este golpe de suporte agora? null = critério padrão (estágio).
func ai_worth(f: BattleFighter, mv: Dictionary) -> Variant:
	var sp := String(mv.get("special", ""))
	if sp == "" or sp in ["charge", "defense_curl", "chain", "no_protect", "thunder_wave"]:
		return null
	if not usable(f, mv):
		return false
	var hp := float(f.hp) / maxf(float(f.max_hp), 1.0)
	var opp := f.opponent
	var has_opp := is_instance_valid(opp) and opp.active()
	var s := st(f)
	var sd := _sd(f.side)
	match sp:
		"protect", "quick_guard":
			return _threatened(f)
		"rest":
			return hp < 0.35 or (f.status in MAJOR and hp < 0.6)
		"roost", "heal_weather":
			return hp < 0.5
		"life_dew":
			var p := partner(f)
			return hp < 0.6 or (p != null and float(p.hp) / maxf(p.max_hp, 1) < 0.6)
		"swallow":
			return hp < 0.5
		"stockpile":
			return int(s.stock) < 2 and int(f.stages.get("def", 0)) < 2
		"haze":
			var mine := 0
			var theirs := 0
			for k in f.stages:
				mine += int(f.stages[k])
			if has_opp:
				for k in opp.stages:
					theirs += int(opp.stages[k])
			return theirs >= 2 or mine <= -2
		"light_screen", "safeguard", "tailwind":
			return not active(sd, sp)
		"gravity":
			return (
				not active(field, "gravity")
				and has_opp
				and ("flying" in opp.types or opp.fly_target > 0.0)
			)
		"grassy_terrain":
			return not active(field, "grassy") and (hp < 0.8 or _has_type_hit(f, "grass"))
		"sandstorm":
			return (
				weather() != "sand"
				and ("rock" in f.types or "ground" in f.types or "steel" in f.types)
			)
		"rain_dance":
			return weather() != "rain"
		"toxic_spikes":
			return (
				has_opp
				and opp.status == ""
				and not ("poison" in opp.types or "steel" in opp.types)
				and spikes.filter(func(z): return int(z.side) == f.side).is_empty()
			)
		"follow_me":
			var p2 := partner(f)
			return p2 != null and float(p2.hp) / maxf(p2.max_hp, 1) < 0.6
		"after_you":
			return partner(f) != null
		"helping_hand":
			return partner(f) != null
		"laser_focus":
			return not active(s, "laser")
		"healing_wish":
			return hp < 0.25
		"imprison":
			return not bool(s.imprison) and has_opp and f.moves.any(func(m): return m in opp.moves)
		"metronome", "copycat", "mimic":
			return true
		"aromatherapy":
			var p3 := partner(f)
			return f.status in MAJOR or (p3 != null and p3.status in MAJOR)
		"mean_look":
			return has_opp and not bool(st(opp).trapped)
		"spite", "disable", "encore":
			return has_opp and _last_of(opp) != ""
		"gastro_acid":
			return has_opp and _ability(opp) != ""
		"worry_seed":
			return has_opp and _ability(opp) != "insomnia"
		"yawn":
			return has_opp and opp.status == ""
		"curse":
			if "ghost" in f.types:
				return hp > 0.6
			return int(f.stages.get("atk", 0)) < 2
	return null


func _has_type_hit(f: BattleFighter, type: String) -> bool:
	return f.moves.any(
		func(m):
			var mv := Dex.move(String(m))
			return float(mv.get("power", 0)) > 0.0 and String(mv.get("type", "")) == type
	)


func _threatened(f: BattleFighter) -> bool:
	for e in arena.telegraphs:
		if int(e.get("side", -1)) != f.side:
			return true
	for foe in _foes(f):
		if foe.prepare_t > 0.0 or foe.dash_t > 0.0:
			return true
	for p in arena.projectiles:
		if is_instance_valid(p) and is_instance_valid(p.user) and p.user.side != f.side:
			if p.position.distance_to(f.position) < 4.0:
				return true
	return false

class_name BattleMoveEffects
extends RefCounted
## Mecânicas dos golpes da Gen 9 que não cabem num `kind` de entrega: proteção, recuo, poder variável,
## dano fixo e OHKO, cura, Stockpile, clima, terreno, telas, Tailwind, Gravity, Toxic Spikes, Follow Me,
## Metronome/Copycat/Mimic, Imprison, Spite, Disable, Encore, Mean Look, troca de habilidade etc.
## Learnsets completos: Counter, Substitute, Endure, troca (Baton Pass, U-turn), armadilhas (Spikes, Stealth
## Rock), terrenos Elétrico/Névoa, Reflect, Taunt, Attract, Wish, Future Sight, poder condicional...
## Chamado pelos ganchos de BattleMoves (use/deliver/hit) e pela arena (tick). Campo "special" do golpe.
## Turno do oficial = rodada (BattleTurns): tudo que dura "N turnos" conta rodadas no fim de turno
## (BattleEndTurn, set_rounds/count_round): clima e terrenos 5, Tailwind 4, telas 5, Gravity 5,
## Safeguard/Mist 5, Taunt 3, Encore 3, Disable 4, Yawn, Wish, Future Sight, Wrap/Bind 4-5. Protect,
## Endure, Quick/Wide Guard, Roost e Follow Me valem até o fim da rodada em que saíram. Counter e as
## janelas de reação curtas (Fake Out, Revenge, Assurance, Helping Hand) seguem em segundos.

## Duração "sem fim em segundos" de um efeito contado em rodadas (o fim vem de count_round).
const FOREVER := 1.0e9
## Cooldown que trava um golpe (Disable, Encore) até o efeito acabar no fim de turno.
const LOCK_CD := 1.0e6
const FIELD_TURNS := 5
## Clima nos golpes (oficial): Thunder/Hurricane 50% no sol; Solar Beam/Blade sem carga no sol.
const SUN_STORM_ACC := 50.0
const SOLAR_MOVES := ["solar_beam", "solar_blade"]
const SOLAR_SUN_WINDUP := 0.25
const TAILWIND_TURNS := 4
const LASER_TURNS := 2
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
	"counter",
	"mirror_coat",
	"endure",
	"wide_guard",
	"focus_punch",
	"sleep_talk",
	"snore",
	"trick",
	"switcheroo",
]
## Helping Hand: o parceiro tem HELP_WINDOW s para soltar um golpe de dano, que vale 1,5x por
## HELP_HOLD s (cobre jatos e golpes de vários acertos do mesmo uso).
const HELP_WINDOW := 4.0
const HELP_HOLD := 2.5
const HELP_MULT := 1.5
const MAJOR := ["burn", "poison", "toxic", "paralysis", "sleep", "freeze"]
const HEAL_COL := Color(0.5, 1.0, 0.55)
## Counter/Mirror Coat: postura curta (prioridade -5 já atrasa a entrada); o golpe recebido volta 2x.
const COUNTER_TIME := 1.0
const COUNTER_MULT := 2
## Fake Out só logo depois de entrar em campo; Avalanche/Payback/Revenge: o alvo me acertou há pouco.
const FAKE_OUT_WINDOW := 1.5
const REVENGE_WINDOW := 1.5
## Future Sight cai no fim do 2º turno depois do uso (3 contando o do uso; o aviso no chão é o
## windup normal na hora).
const FUTURE_TURNS := 3
## Wish cura no fim do turno seguinte; Yawn faz dormir no fim do turno seguinte.
const WISH_TURNS := 2
const YAWN_TURNS := 2
const ATTRACT_FAIL := 0.5
const TAUNT_TURNS := 3
const ENCORE_TURNS := 3
const DISABLE_TURNS := 4
const THROAT_TURNS := 2
const HEAL_BLOCK_TURNS := 2
const UPROAR_TURNS := 3
## Wrap/Bind e companhia: 4-5 turnos (Showdown: duração 5-6 contando o do uso), 1/8 por turno.
const BIND_TURNS := [5, 6]
const BIND_MOVES := [
	"wrap",
	"bind",
	"fire_spin",
	"whirlpool",
	"sand_tomb",
	"clamp",
	"infestation",
	"magma_storm",
	"snap_trap",
	"thunder_cage",
]
const PIVOT_DELAY := 0.35
const PRESENT_HEAL := 0.2
const STEALTH_R := 1.4
const TERRAINS := ["grassy", "electric", "misty", "psychic"]
const TERRAIN_BOOST := 1.3
const MISTY_DRAGON := 0.5
## Magnet Rise: 5 turnos levitando (imune a Terra, sem pisar no chão), a altura do voo em m.
const MAGNET_TURNS := 5
const MAGNET_H := 0.8
## Lock-On: o próximo golpe não erra (o uso + o turno seguinte).
const LOCK_TURNS := 2
## Rage Fist: +50 de poder por vez que levou golpe, até 350.
const RAGE_STEP := 50.0
const RAGE_MAX := 350.0
## Golpes que descongelam o alvo além dos de Fogo.
const THAW_MOVES := ["scald"]
## Acupressure: atributos que podem subir.
const ACUPRESSURE_STATS := ["atk", "def", "spa", "spd", "spe", "acc"]
## Golpes de som oficiais que existem no jogo (Throat Chop bloqueia; atravessam o Substitute).
const SOUND_MOVES := [
	"alluring_voice",
	"heal_bell",
	"perish_song",
	"sparkling_aria",
	"bug_buzz",
	"disarming_voice",
	"echoed_voice",
	"growl",
	"howl",
	"hyper_voice",
	"metal_sound",
	"psychic_noise",
	"roar",
	"round",
	"screech",
	"sing",
	"snarl",
	"snore",
	"supersonic",
	"uproar",
]
## Saem mesmo dormindo (Snore, Sleep Talk).
const SLEEP_MOVES := ["sleep_only", "sleep_talk"]

var arena: Node
var rng: RandomNumberGenerator
var now := 0.0
## Último golpe usado na luta por qualquer um (Copycat).
var last_any := ""
var sides := [{}, {}]
var field := {}
var spikes: Array = []
## Future Sight no ar: {user, mv, miss, rounds}.
var futures: Array = []
var _st := {}
var _last_crit := false


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
			"entered": now,
			"endure": -99.0,
			"counter": -99.0,
			"counter_cat": "",
			"sub": 0,
			"taunt": -99.0,
			"throat": -99.0,
			"heal_block": -99.0,
			"attract": -99.0,
			"regen": false,
			"rooted": false,
			"used": {},
			"fail": false,
			"prev_fail": false,
			"rose_t": -99,
			"fell_t": -99,
			"hit_by": {},
			"focus_t": -99.0,
			"pivot_cast": -1,
			"omni_cast": -1,
			"rage": 0,
			"destiny": false,
		}
	return _st[id]


func _sd(side: int) -> Dictionary:
	return sides[clampi(side, 0, 1)]


func _left(d: Dictionary, k: String) -> float:
	return float(d.get(k, -99.0)) - now


func active(d: Dictionary, k: String) -> bool:
	return _left(d, k) > 0.0


## Liga `k` em `d` por `n` rodadas (turnos do oficial): BattleEndTurn conta no fim de cada rodada,
## incluindo a do uso (count_round).
func set_rounds(d: Dictionary, k: String, n: int) -> void:
	d[k] = now + FOREVER
	d[k + "#"] = n


## Rodadas que ainda faltam de `k` (0 = desligado ou contado em segundos).
func rounds_left(d: Dictionary, k: String) -> int:
	return int(d.get(k + "#", 0)) if active(d, k) else 0


## Fim de turno: desconta uma rodada de `k` (como o oficial, antes do efeito). true = acabou agora.
func count_round(d: Dictionary, k: String) -> bool:
	if not d.has(k + "#"):
		return false
	if not active(d, k):
		d.erase(k + "#")  # tirado antes (Brick Break, Defog, Feint...)
		return false
	var n := int(d[k + "#"]) - 1
	if n > 0:
		d[k + "#"] = n
		return false
	d.erase(k)
	d.erase(k + "#")
	return true


## Segundos que ainda faltam na rodada (para o visual do que dura até o fim dela).
func round_left() -> float:
	var t = arena.get("turns")
	if t == null:
		return 1.0
	return maxf(BattleTurns.ROUND_SECS - float(t.round_t), 0.6)


## Segundos aproximados de `n` rodadas (só para o visual).
static func rounds_secs(n: int) -> float:
	return n * BattleTurns.ROUND_SECS


## Rodada atual (para "neste turno": Lash Out, Burning Jealousy).
func _round_id() -> int:
	var t = arena.get("turns")
	return int(t.round_n) if t else 0


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
	n = mini(f.paced(n), f.max_hp - f.hp)  # modo de energia: x0,6 (fighter.paced)
	if n <= 0 or not f.alive():
		return
	if heal_blocked(f):
		f.popup("Não pode se curar!", Color(0.8, 0.6, 0.9), 0.8)
		return
	f.heal(n)
	f.popup("+%d" % n, HEAL_COL, 0.9, 0.3, "heal")
	_vfx("heal", [f])


func _fail(f: BattleFighter) -> void:
	f.popup("Mas falhou!", Color(0.8, 0.8, 0.8))
	note_fail(f)


## O golpe deste uso falhou ou errou (Stomping Tantrum dobra no próximo).
func note_fail(f: BattleFighter) -> void:
	if is_instance_valid(f):
		st(f).fail = true


## Supercell Slam: errou ou foi parado, o usuário se machuca (fração do HP máximo em "crash").
func crash_damage(user: BattleFighter, mv: Dictionary) -> void:
	if not mv.has("crash") or not is_instance_valid(user) or not user.alive():
		return
	var n := user.paced(maxi(1, int(ceil(float(user.max_hp) * float(mv.crash)))))
	user.take_damage(n, Vector3.ZERO, 0.0)
	user.popup("-%d machucou-se!" % n, Color(1.0, 0.7, 0.5), 0.9)


## Um lutador desmaiou (Retaliate olha o lado dele).
func note_faint(f: BattleFighter) -> void:
	BattleKanto.note_faint(self, f)
	BattleMore.note_faint(self, f)


## Entrou em campo agora (Fake Out conta a partir daqui).
func on_enter(f: BattleFighter) -> void:
	st(f).entered = now


## Mudança de estágio que pegou (Burning Jealousy, Lash Out olham o último turno).
func note_stage(f: BattleFighter, delta: int) -> void:
	if delta > 0:
		st(f).rose_t = _round_id()
	elif delta < 0:
		st(f).fell_t = _round_id()


## Queda de atributo vinda do outro lado barrada pelo Mist.
func mist_blocks(c: BattleFighter, src: BattleFighter) -> bool:
	if not is_instance_valid(src) or src.side == c.side or not side_active(c.side, "mist"):
		return false
	c.popup("Protegido pela névoa!", Color(0.8, 0.9, 1.0))
	return true


func _has_item(f: BattleFighter) -> bool:
	if active(field, "magic"):
		return false  # Magic Room: item sem efeito
	return is_instance_valid(f) and f.trainer_item != "" and not f.item_used


func _item_name(f: BattleFighter) -> String:
	return String(Dex.item(f.trainer_item).get("name", f.trainer_item))


func _party_of(f: BattleFighter) -> Array:
	var list = arena.get("party") if f.side == 0 else arena.get("enemies")
	return list if list is Array else []


func grounded(f: BattleFighter) -> bool:
	if active(field, "gravity"):
		return true
	if active(st(f), "magnet"):
		return false
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


## Clima de golpe por `rounds` rodadas (5 turnos no oficial, 8 com a pedra do clima de `user`),
## contadas no fim de turno. O visual do clima é o BattleWeatherFx, que lê weather().
func set_weather(kind: String, rounds: int, user: BattleFighter = null) -> void:
	if not _local_weather():
		if user != null and arena.abilities.has_method("weather_rounds_for"):
			rounds = maxi(rounds, arena.abilities.weather_rounds_for(user, kind))
		arena.abilities.set_weather_rounds(kind, rounds)
	else:
		field["weather"] = kind
		set_rounds(field, "weather_t", rounds)


# --- Ganchos de BattleMoves.use ---


## Golpe que não pode sair agora (sem Stockpile, sem frutinha, aprisionado...). A IA também consulta.
func usable(user: BattleFighter, mv: Dictionary, feedback := false) -> bool:
	var why := _blocked(user, mv)
	if why != "" and feedback:
		user.popup(why, Color(0.85, 0.85, 0.85))
	return why == ""


func _blocked(user: BattleFighter, mv: Dictionary) -> String:
	var id := String(mv.get("id", ""))
	var s := st(user)
	for foe in _foes(user):
		if bool(st(foe).imprison) and id in foe.moves:
			return "Aprisionado!"
	if active(s, "taunt") and String(mv.get("category", "")) == "status":
		return "Provocado!"
	if active(s, "throat") and id in SOUND_MOVES:
		return "Garganta ferida!"
	match String(mv.get("special", "")):
		"baton_pass":
			if not has_reserve(user):
				return "Ninguém para entrar!"
		"fake_out":
			if now - float(s.entered) > FAKE_OUT_WINDOW:
				return "Só logo ao entrar!"
		"upper_hand":
			if not _priority_windup(user.opponent):
				return "Mas falhou!"
		"fling":
			if not _has_item(user):
				return "Sem item para arremessar!"
		"last_resort":
			for mid in user.moves:
				if String(mid) != id and not s.used.has(String(mid)):
					return "Ainda não!"
			if user.moves.size() < 2:
				return "Mas falhou!"
		"sleep_only", "sleep_talk":
			if user.status != "sleep":
				return "Só dormindo!"
		"belly_drum":
			if user.hp <= user.max_hp / 2 or int(user.stages.get("atk", 0)) >= 6:
				return "Mas falhou!"
		"substitute":
			if int(s.sub) > 0:
				return "Já tem um substituto!"
			if user.hp <= user.max_hp / 4:
				return "HP insuficiente!"
		"dragon_cheer":
			if partner(user) == null:
				return "Mas falhou!"
		"wish":
			for w in _sd(user.side).get("wishes", []):
				if int(w.id) == user.get_instance_id():
					return "Mas falhou!"
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
	var k := BattleKanto.blocked(self, user, mv)
	if k != "":
		return k
	return BattleMore.blocked(self, user, mv)


func _last_of(f: BattleFighter) -> String:
	return String(st(f).last) if is_instance_valid(f) else ""


func _copyable(id: String) -> String:
	if id == "" or id in CALL_BAN or Dex.move(id).is_empty():
		return ""
	return id


## Upper Hand: o alvo está preparando (ou já lançado num) golpe de prioridade.
func _priority_windup(t: BattleFighter) -> bool:
	if not is_instance_valid(t) or not t.active():
		return false
	if t.prepare_t > 0.0 and int(Dex.move(t.prepare_id).get("priority", 0)) > 0:
		return true
	return t.dash_t > 0.0 and int(t.dash_move.get("priority", 0)) > 0


## Golpe que sai mesmo dormindo (Snore, Sleep Talk), se nada mais segura o lutador.
func sleep_move(f: BattleFighter, mv: Dictionary) -> bool:
	return (
		f.status == "sleep"
		and String(mv.get("special", "")) in SLEEP_MOVES
		and f.alive()
		and f.stun_t <= 0.0
		and f.impact_t <= 0.0
	)


## O golpe como sai agora (Grassy Glide ganha prioridade +1 no campo de grama; Solar Beam/Blade no sol
## saem sem o turno de carga, aqui o preparo quase todo).
func move_for(user: BattleFighter, mv: Dictionary) -> Dictionary:
	if String(mv.get("id", "")) in SOLAR_MOVES and weather() == "sun":
		var sm := mv.duplicate()
		sm["windup"] = SOLAR_SUN_WINDUP
		return sm
	if (
		String(mv.get("special", "")) == "grassy_glide"
		and active(field, "grassy")
		and grounded(user)
	):
		var m := mv.duplicate()
		m["priority"] = 1
		return m
	return mv


## Apaixonado (Attract): metade das vezes o golpe não sai.
func infatuated_fail(f: BattleFighter) -> bool:
	if not active(st(f), "attract") or rng.randf() >= ATTRACT_FAIL:
		return false
	f.popup("Está apaixonado!", Color(1, 0.55, 0.75))
	return true


func heal_blocked(f: BattleFighter) -> bool:
	return is_instance_valid(f) and active(st(f), "heal_block")


## Ingrain: enraizado, não é empurrado nem arremessado.
func rooted(f: BattleFighter) -> bool:
	return is_instance_valid(f) and bool(st(f).rooted)


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
	s.prev_fail = bool(s.fail)
	s.fail = false
	s.used[id] = true
	if not String(mv.get("special", "")) in ["copycat", "metronome"]:
		last_any = id
	var sd := _sd(user.side)
	if id != "destiny_bond":
		s.destiny = false  # Destiny Bond vale até o próximo golpe de quem usou
	if mv.has("max_recoil"):
		# Steel Beam: perde metade do HP máximo depois de atirar, acertando ou não
		var lose := user.paced(int(ceil(float(user.max_hp) * float(mv.max_recoil))))
		arena.later(
			float(mv.get("windup", 0.0)) + 0.2,
			func() -> void:
				if is_instance_valid(user) and user.alive():
					user.take_damage(lose, Vector3.ZERO, 0.0)
					user.popup("-%d recuo" % lose, Color(0.9, 0.6, 0.6), 0.8)
		)
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
		"focus_punch":
			s.focus_t = now
			user.popup("Concentrando...", Color(1, 0.75, 0.4), 0.8)
		"fling":
			user.item_used = true
			user.popup("Arremessou %s!" % _item_name(user), Color(1, 0.85, 0.5), 0.8)
		"uproar":
			set_rounds(field, "uproar", UPROAR_TURNS)
			for f in arena.fighters:
				if is_instance_valid(f) and f.active() and f.status == "sleep":
					f.clear_status()
					f.popup("Acordou com o barulho!", Color(1, 0.85, 0.5))
		"steel_roller", "poltergeist":
			BattleKanto.on_use(self, user, mv)
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
	BattleMore.on_use(self, user, mv)


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
	var w := weather()
	if id in ["thunder", "hurricane"]:
		if w == "rain":
			return 0.0
		if w == "sun":
			acc = SUN_STORM_ACC
	if id == "blizzard" and w in ["hail", "snow"]:
		return 0.0
	if String(mv.get("special", "")) == "ohko":
		var t := user.opponent
		if is_instance_valid(t):
			acc += float(user.level - t.level)
		if id == "sheer_cold" and not "ice" in user.types:
			acc = 20.0 + (float(user.level - t.level) if is_instance_valid(t) else 0.0)  # oficial Gen 7+
	if active(st(user), "lock"):
		return 0.0  # Lock-On: não erra
	if active(field, "gravity"):
		acc *= 5.0 / 3.0
	return acc


func roll_hits(mv: Dictionary, user: BattleFighter = null) -> Dictionary:
	if String(mv.get("special", "")) == "beat_up" and user != null:
		# Beat Up: um golpe por membro saudável da equipe (poder oficial 5 + Ataque base / 10).
		var pw := _beat_powers(user)
		var b := mv.duplicate()
		b["hits"] = pw.size()
		b["_beat"] = {"i": 0, "pw": pw}
		return b
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
	if user != null and arena.abilities and arena.abilities.ability_of(user) == "skill_link":
		n = int(hr[1])  # Skill Link: sempre o máximo de acertos
	n = clampi(n, int(hr[0]), int(hr[1]))
	var m := mv.duplicate()
	if String(mv.get("kind", "")) == "projectile" and not bool(mv.get("boomerang", false)):
		m["count"] = n
	else:
		m["hits"] = n
	return m


func _beat_powers(user: BattleFighter) -> Array:
	var pw := []
	for m in _party_of(user):
		if m is Mon and m.hp > 0 and m.status == "":
			pw.append(5 + int(Dex.species(m.species).get("base", {}).get("atk", 50)) / 10)
	if pw.is_empty():
		pw.append(5 + int(Dex.species(user.mon.species).get("base", {}).get("atk", 50)) / 10)
	return pw


# --- Ganchos de BattleMoves.hit ---


## Golpe parado antes de acertar (Protect, Quick Guard, pó em Grama, Thunder Wave em Terra).
func blocks_hit(user: BattleFighter, target: BattleFighter, mv: Dictionary) -> bool:
	if not is_instance_valid(user) or target.side == user.side:
		return false
	var sp := String(mv.get("special", ""))
	var us := st(user)
	if sp == "focus_punch" and float(us.hurt_t) > float(us.focus_t):
		user.popup("Perdeu a concentração!", Color(0.85, 0.85, 0.85))
		us.fail = true
		return true
	if (
		bool(mv.get("powder", false))
		and ("grass" in target.types or _ability(target) == "overcoat")
	):
		target.popup("Sem efeito...", Color(0.7, 0.7, 0.7))
		return true
	if sp == "thunder_wave" and "ground" in target.types:
		target.popup("Sem efeito...", Color(0.7, 0.7, 0.7))
		return true
	if (
		String(mv.get("type", "")) == "ground"
		and float(mv.get("power", 0)) > 0.0
		and active(st(target), "magnet")
		and not active(field, "gravity")
	):
		target.popup("Levitando!", Color(0.8, 0.9, 1.0))
		return true
	var ts := st(target)
	var sd := _sd(target.side)
	if sp == "feint":
		if active(ts, "protect") or active(sd, "quick_guard"):
			ts.protect = -99.0
			sd.erase("quick_guard")
			target.popup("A proteção caiu!", Color(1, 0.8, 0.5))
		return false
	if BattleKanto.blocks_hit(self, user, target, mv):
		return true
	if BattleMore.blocks_hit(self, user, target, mv):
		return true
	if (
		float(mv.get("power", 0)) <= 0.0
		and int(ts.sub) > 0
		and not String(mv.get("id", "")) in SOUND_MOVES
	):
		target.popup("O substituto bloqueou!", Color(0.85, 0.85, 0.85))
		us.fail = true
		return true
	if sp == "no_protect":
		return false
	if active(ts, "protect"):
		target.popup("Protegeu-se!", Color(0.6, 0.9, 1.0), 1.1)
		BattleKanto.on_protected(self, target)
		us.fail = true
		crash_damage(user, mv)
		return true
	if active(field, "psychic") and int(mv.get("priority", 0)) > 0 and grounded(target):
		target.popup("O campo psíquico protege!", Dex.type_color("psychic"))
		us.fail = true
		return true
	if int(mv.get("priority", 0)) > 0 and active(sd, "quick_guard"):
		target.popup("Guarda Rápida!", Color(0.6, 0.9, 1.0))
		us.fail = true
		return true
	if BattleMoves.multi_target(mv) != "" and active(sd, "wide_guard"):
		target.popup("Guarda Ampla!", Color(0.6, 0.9, 1.0))
		us.fail = true
		return true
	return false


## Golpe que não usa a fórmula: OHKO (Fissure) e Endeavor. true = já resolvido aqui.
func exact_hit(user: BattleFighter, target: BattleFighter, mv: Dictionary, dir: Vector3) -> bool:
	var sp := String(mv.get("special", ""))
	var prof := defender_profile(user, target, mv)
	var eff := Dex.effectiveness(String(mv.get("type", "normal")), prof.types)
	if sp == "screen_break" and eff > 0.0 and target.side != user.side:
		_break_screens(target)
	if sp == "present" and rng.randf() < PRESENT_HEAL:
		# Present: às vezes o "presente" cura o alvo em 1/4.
		target.popup("Era um presente!", Color(1, 0.85, 0.6))
		_heal(target, int(ceil(target.max_hp / 4.0)))
		return true
	if not sp in ["ohko", "endeavor", "final_gambit", "metal_burst"]:
		return false
	if eff == 0.0:
		target.popup("Sem efeito...", Color(0.7, 0.7, 0.7))
		note_fail(user)
		return true
	var amount := 0
	if sp == "ohko" and String(mv.get("id", "")) == "sheer_cold" and "ice" in target.types:
		target.popup("Sem efeito...", Color(0.7, 0.7, 0.7))
		note_fail(user)
		return true
	if sp == "metal_burst":
		amount = BattleKanto.burst_amount(self, user)
	elif sp == "ohko":
		if target.level > user.level or _ability(target) == "sturdy":
			target.popup("Não afetou!", Color(0.8, 0.8, 0.8))
			return true
		amount = target.hp
	elif sp == "final_gambit":
		amount = user.hp
	else:
		if target.hp <= user.hp:
			_fail(user)
			return true
		amount = target.hp - user.hp
	if substitute_soak(user, target, mv, amount):
		amount = 0
	amount = cap_damage(user, target, mv, amount)
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
	if sp == "final_gambit" and user.alive():
		user.take_damage(user.hp, Vector3.ZERO, 0.0)
	return true


## Brick Break / Psychic Fangs: quebra o Reflect e o Light Screen do lado do alvo antes do acerto.
func _break_screens(target: BattleFighter) -> void:
	var sd := _sd(target.side)
	if active(sd, "reflect") or active(sd, "light_screen"):
		sd.erase("reflect")
		sd.erase("light_screen")
		target.popup("As barreiras quebraram!", Color(1, 0.8, 0.5))


## Dano final que o alvo aguenta: Endure e False Swipe deixam 1 HP.
## Status mais difícil de pegar no modo de energia (BattleEnergy.status_chance_mult); no VGC, o oficial.
## Recém-curado do mesmo status (BattleEnergy.STATUS_IMMUNE) não pega.
func status_chance_mult(
	_user: BattleFighter, target: BattleFighter, mv: Dictionary, s: String
) -> float:
	if not target.energy_mode:
		return 1.0
	if target.status_immune_t > 0.0 and target.last_status == s:
		return 0.0
	return BattleEnergy.status_chance_mult(mv, s)


func cap_damage(user: BattleFighter, target: BattleFighter, mv: Dictionary, dmg: int) -> int:
	if dmg < target.hp or not is_instance_valid(user):
		return dmg
	if String(mv.get("special", "")) == "false_swipe":
		return maxi(target.hp - 1, 0)
	if active(st(target), "endure"):
		target.popup("Aguentou!", Color(1, 0.85, 0.5), 1.1)
		return target.hp - 1
	return dmg


## Substitute leva o golpe no lugar do dono (som atravessa). true = o boneco absorveu.
func substitute_soak(user: BattleFighter, target: BattleFighter, mv: Dictionary, dmg: int) -> bool:
	var ts := st(target)
	if (
		int(ts.sub) <= 0
		or not is_instance_valid(user)
		or user.side == target.side
		or String(mv.get("id", "")) in SOUND_MOVES
	):
		return false
	ts.sub = maxi(int(ts.sub) - dmg, 0)
	target.popup("Substituto -%d" % dmg, Color(0.85, 0.85, 0.85), 0.9)
	if int(ts.sub) <= 0:
		target.popup("O substituto quebrou!", Color(1, 0.8, 0.5))
		_vfx("substitute", [target, false])
	return true


## Poder do golpe neste acerto (variável, crítico forçado, Charge...). Duplica só se mudar algo.
func adjust_move(user: BattleFighter, target: BattleFighter, m: Dictionary) -> Dictionary:
	var s := st(user)
	var p := float(m.get("power", 0))
	var p0 := p
	var id := String(m.get("id", ""))
	var ty := String(m.get("type", ""))
	var ty0 := ty
	match String(m.get("special", "")):
		"acrobatics":
			if not _has_item(user):
				p *= 2.0
		"facade":
			if user.status in ["burn", "poison", "toxic", "paralysis"]:
				p *= 2.0
		"hex":
			if target.status in MAJOR:
				p *= 2.0
		"knock_off":
			if _has_item(target):
				p *= 1.5
		"lash_out":
			if int(s.fell_t) == _round_id():
				p *= 2.0
		"revenge":
			if now - float(s.hit_by.get(target.get_instance_id(), -99.0)) <= REVENGE_WINDOW:
				p *= 2.0
		"stomping_tantrum":
			if bool(s.prev_fail):
				p *= 2.0
		"brine":
			if target.hp * 2 < target.max_hp:
				p *= 2.0
		"hard_press":
			p = maxf(1.0, floorf(p * float(target.hp) / maxf(float(target.max_hp), 1.0)))
		"rage_fist":
			p = minf(p + RAGE_STEP * int(s.rage), RAGE_MAX)
		"water_spout":
			p = maxf(1.0, floorf(p * float(user.hp) / maxf(float(user.max_hp), 1.0)))
		"heat_crash":
			var r := BattlePhysics.weight_of(user) / maxf(BattlePhysics.weight_of(target), 0.1)
			p = (
				120.0
				if r >= 5.0
				else (100.0 if r >= 4.0 else (80.0 if r >= 3.0 else (60.0 if r >= 2.0 else 40.0)))
			)
		"weather_ball":
			var wb := {"sun": "fire", "rain": "water", "sand": "rock", "hail": "ice", "snow": "ice"}
			var w := weather()
			if wb.has(w):
				ty = String(wb[w])
				p *= 2.0
		"present":
			var r2 := rng.randf() * (1.0 - PRESENT_HEAL)
			p = 40.0 if r2 < 0.4 else (80.0 if r2 < 0.7 else 120.0)
		"beat_up":
			var b = m.get("_beat")
			if b is Dictionary and not (b.pw as Array).is_empty():
				p = float(b.pw[mini(int(b.i), b.pw.size() - 1)])
				b.i = int(b.i) + 1
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
		"retaliate":
			if BattleKanto.ally_fell(self, user):
				p *= 2.0
		"triple_axel":
			p *= BattleKanto.hit_number(m, target)
		"terrain_pulse":
			var pt := BattleKanto.pulse_type(self, user)
			if pt != "":
				p *= 2.0
				ty = pt
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
			var w := float(Dex.species(target.body_id()).get("weight_kg", 20.0))
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
	p = BattleMore.power(self, user, target, m, p)
	ty = BattleMore.move_type(self, user, target, m, ty)
	if ty == "electric" and active(s, "charged"):
		p *= 2.0
	var crit := active(s, "laser")
	if p == p0 and not crit and ty == ty0:
		return m
	var out := m.duplicate()
	out["power"] = p
	out["type"] = ty
	if crit:
		out["crit"] = 3
	return out


## Perfil do atacante: Body Press usa a Defesa, Foul Play o Ataque do alvo, Facade ignora a queimadura.
func attacker_profile(user: BattleFighter, target: BattleFighter, m: Dictionary) -> Dictionary:
	var p := user.damage_profile()
	match String(m.get("special", "")):
		"body_press":
			p["atk"] = user.stat("def")
			p["crit_atk"] = user.crit_stat("def", true)
		"foul_play":
			p["atk"] = target.stat("atk")
			p["crit_atk"] = target.crit_stat("atk", true)
		"facade":
			p["burned"] = false
	BattleMore.attacker(self, user, target, m, p)
	return p


## Perfil do defensor: na Gravity o Voador perde a imunidade a golpe de Terra.
func defender_profile(user: BattleFighter, target: BattleFighter, m: Dictionary) -> Dictionary:
	var p := target.damage_profile()
	if arena.abilities:
		p["types"] = arena.abilities.hit_types(user, target, m, p.types)  # Scrappy
	if String(m.get("type", "")) == "ground" and active(field, "gravity") and "flying" in p.types:
		var ty: Array = p.types.duplicate()
		ty.erase("flying")
		p["types"] = ty if not ty.is_empty() else ["normal"]
	if active(field, "wonder"):
		# Wonder Room: Defesa e Def. Esp. trocadas
		var d: float = p.def
		p["def"] = p.spd
		p["spd"] = d
		var cd: float = p.crit_def
		p["crit_def"] = p.crit_spd
		p["crit_spd"] = cd
	if String(m.get("special", "")) == "psyshock":
		# Psyshock: golpe especial contra a Defesa física.
		p["spd"] = p.def
		p["crit_spd"] = p.crit_def
	match String(m.get("special", "")):
		"freeze_dry":
			p["types"] = BattleKanto.freeze_types(p.types)
		"ignore_stages":
			# Darkest Lariat: ignora as mudanças de Defesa e Def. Esp. do alvo
			p["def"] = float(target.stats.get("def", 1))
			p["spd"] = float(target.stats.get("spd", 1))
			p["crit_def"] = p.def
			p["crit_spd"] = p.spd
	BattleMore.defender(self, user, target, m, p)
	if arena.abilities and arena.abilities.no_crit(target, user):
		p["no_crit"] = true
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
	var physical: bool = mv.get("category", "") == "physical"
	var screen := "light_screen" if special else ("reflect" if physical else "")
	if screen != "" and active(_sd(target.side), screen) and not _last_crit:
		m *= SCREEN_MULT_DOUBLES if bool(arena.get("doubles")) else SCREEN_MULT
	if active(field, "grassy"):
		if type == "grass" and grounded(user):
			m *= GRASSY_BOOST
		if String(mv.get("id", "")) in QUAKE_MOVES and grounded(target):
			m *= 0.5
	if active(field, "electric") and type == "electric" and grounded(user):
		m *= TERRAIN_BOOST
	if active(field, "psychic") and type == "psychic" and grounded(user):
		m *= TERRAIN_BOOST
	if active(field, "misty") and type == "dragon" and grounded(target):
		m *= MISTY_DRAGON
	var w := weather()
	if String(mv.get("id", "")) in SOLAR_MOVES and w in ["rain", "sand", "hail", "snow"]:
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
		s == "sleep"
		and (active(field, "uproar") or (active(field, "electric") and grounded(target)))
	):
		target.popup("Não consegue dormir!", Color(0.85, 0.85, 0.85))
		return true
	if (s in MAJOR or s == "confusion") and active(field, "misty") and grounded(target):
		target.popup("Protegido pelo campo de névoa!", Color(0.95, 0.75, 0.95))
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
		st(target).hit_by[user.get_instance_id()] = now
		if user.side != target.side:
			st(target).rage = int(st(target).rage) + 1
		if active(s, "lock"):
			s.lock = -99.0
		if not target.alive() and bool(st(target).destiny) and user.alive():
			st(target).destiny = false
			user.popup("Levado pelo Destiny Bond!", Dex.type_color("ghost"))
			user.take_damage(user.hp, Vector3.ZERO, 0.0)
		_counter(user, target, mv, dealt)
		BattleKanto.note_damage(self, user, target, mv, dealt)
		BattleMore.note_damage(self, user, target, mv, dealt)
		if active(s, "laser"):
			s.laser = -99.0
		if String(mv.get("type", "")) == "electric":
			s.charged = -99.0
		if (
			target.status == "freeze"
			and (String(mv.get("type", "")) == "fire" or id in THAW_MOVES)
			and target.alive()
		):
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
	if id in BIND_MOVES and dealt > 0 and target.alive() and not active(st(target), "bound"):
		# Wrap/Bind: preso 4-5 turnos, 1/8 no fim de cada um (BattleEndTurn), sem fugir nem trocar
		var bs := st(target)
		set_rounds(bs, "bound", rng.randi_range(int(BIND_TURNS[0]), int(BIND_TURNS[1])))
		bs.bound_by = user
		bs.bound_move = String(mv.get("name", id))
	var ss = mv.get("self_stats")
	if ss is Dictionary and user.alive() and int(s.self_cast) != user.cast_n:
		s.self_cast = user.cast_n
		for k in ss:
			arena.moves.change_stage(user, String(k), int(ss[k]))
	var ts := st(target)
	match sp:
		"reflect_type", "role_play", "entrainment", "split_stats", "swap_stages", "swap_stats", "cure_burn", "steel_roller":
			BattleKanto.after_hit(self, user, target, mv, dealt)
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
		"clear_smog":
			if dealt > 0 and target.alive():
				for k in target.stages:
					target.stages[k] = 0
				target.popup("Atributos zerados!", Color(0.8, 0.9, 1.0))
		"soak":
			if target.types == ["water"]:
				_fail(user)
			else:
				target.types = ["water"]
				target.popup("Virou Water!", Dex.type_color("water"))
		"simple_beam":
			if _ability(target) == "simple":
				_fail(user)
			else:
				target.set_meta("ability_override", "simple")
				target.popup("Habilidade virou Simple!", Color(0.7, 0.9, 0.5))
		"lock_on":
			set_rounds(s, "lock", LOCK_TURNS)
			user.popup("Mira travada!", Color(1, 0.6, 0.3))
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
				if not target.energy_mode:
					target.mon.pp = target.pp_max
				var said := "PP de %s caiu!" % Dex.move(last).get("name", last)
				target.popup("Energia caiu!" if target.energy_mode else said, Color(0.8, 0.6, 0.9))
		"disable":
			var last2 := _last_of(target)
			if last2 == "":
				_fail(user)
			else:
				end_disable(target)
				set_rounds(ts, "disable", DISABLE_TURNS)
				ts.disable_move = last2
				target.move_cd[last2] = LOCK_CD
				target.popup(
					"%s desativado!" % Dex.move(last2).get("name", last2), Color(0.8, 0.8, 0.9)
				)
		"encore":
			var last3 := _last_of(target)
			if last3 == "":
				_fail(user)
			else:
				end_encore(target)
				set_rounds(ts, "encore", ENCORE_TURNS)
				ts.encore_move = last3
				for mid in target.moves:
					if String(mid) != last3:
						target.move_cd[mid] = LOCK_CD
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
			# Flatter: At. Esp. +1; Swagger ("flatter_stat": "atk"): Ataque +2.
			var fk := String(mv.get("flatter_stat", "spa"))
			arena.moves.change_stage(target, fk, 2 if fk == "atk" else 1)
		"jealousy":
			if not sheer and target.alive() and int(ts.rose_t) == _round_id():
				_status(user, target, String(mv.get("jealous_status", "burn")))
		"omni_boost":
			if not sheer and user.alive() and int(s.omni_cast) != user.cast_n:
				s.omni_cast = user.cast_n
				if rng.randf() < float(mv.get("omni_chance", 0.1)):
					for k in ["atk", "def", "spa", "spd", "spe"]:
						arena.moves.change_stage(user, k, 1)
		"knock_off":
			if dealt > 0 and _has_item(target):
				target.item_used = true
				target.popup("Perdeu %s!" % _item_name(target), Color(1, 0.75, 0.5))
		"heal_block":
			if target.alive():
				set_rounds(ts, "heal_block", HEAL_BLOCK_TURNS)
				target.popup("Não pode se curar!", Color(0.8, 0.6, 0.9))
		"throat_chop":
			if dealt > 0 and target.alive():
				set_rounds(ts, "throat", THROAT_TURNS)
				target.popup("Garganta ferida!", Color(0.85, 0.6, 0.6))
		"terrain_clear":
			_clear_terrain(target)
		"pivot":
			if user.alive() and int(s.pivot_cast) != user.cast_n and has_reserve(user):
				s.pivot_cast = user.cast_n
				arena.later(PIVOT_DELAY, func() -> void: _switch(user, false))
		"attract":
			_attract(user, target)
		"taunt":
			set_rounds(ts, "taunt", TAUNT_TURNS)
			target.popup("Provocado!", Color(1, 0.55, 0.4))
		"memento":
			arena.moves.change_stage(target, "atk", -2, user)
			arena.moves.change_stage(target, "spa", -2, user)
			if user.alive():
				user.take_damage(user.hp, Vector3.ZERO, 0.0)
		"pain_split":
			var avg := (user.hp + target.hp) / 2
			for f in [user, target]:
				if f.hp > avg:
					f.take_damage(f.hp - avg, Vector3.ZERO, 0.0)
				elif f.hp < avg:
					f.heal(avg - f.hp)
				f.popup("HP dividido!", Color(0.9, 0.9, 1.0), 0.8)
		"skill_swap":
			var a := _ability(user)
			var b := _ability(target)
			user.set_meta("ability_override", b)
			target.set_meta("ability_override", a)
			user.popup("Trocou de habilidade!", Dex.type_color("psychic"))
		"strength_sap":
			if int(target.stages.get("atk", 0)) <= -6:
				_fail(user)
			else:
				_heal(user, int(target.stat("atk")))
				arena.moves.change_stage(target, "atk", -1, user)
		"trick":
			if not _has_item(user) and not _has_item(target):
				_fail(user)
			else:
				var mine := user.trainer_item if _has_item(user) else ""
				var theirs := target.trainer_item if _has_item(target) else ""
				user.trainer_item = theirs
				user.item_used = false
				target.trainer_item = mine
				target.item_used = false
				user.popup("Trocou os itens!", Color(1, 0.85, 0.5))
		"yawn":
			if target.status != "" or active(ts, "yawn"):
				_fail(user)
			else:
				# dorme no fim do turno seguinte (BattleEndTurn: yawn_sleep)
				target.popup("Sonolento...", Color(0.75, 0.8, 0.95))
				set_rounds(ts, "yawn", YAWN_TURNS)
				ts.yawn_by = user


## Status de efeito extra pelas mesmas regras do hit (imunidade de tipo, habilidade, Safeguard).
func _status(user: BattleFighter, target: BattleFighter, s: String) -> void:
	if BattleMoves.STATUS_IMMUNE.get(s, "-") in target.types:
		return
	if arena.abilities and arena.abilities.blocks_status(target, s, user):
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


## Counter/Mirror Coat: na postura, o golpe da categoria certa volta 2x para quem bateu.
func _counter(user: BattleFighter, target: BattleFighter, mv: Dictionary, dealt: int) -> void:
	var ts := st(target)
	if (
		user.side == target.side
		or not active(ts, "counter")
		or String(mv.get("category", "")) != String(ts.counter_cat)
		or not target.alive()
		or not user.alive()
	):
		return
	ts.counter = -99.0
	target.popup("Revidou!", Color(1, 0.6, 0.35), 1.1)
	_direct(target, user, dealt * COUNTER_MULT)


## Dano direto (fora da fórmula), com empurrão e hit-stop de golpe.
func _direct(src: BattleFighter, dst: BattleFighter, amount: int, knock := 6.0) -> void:
	var to := dst.position - src.position
	to.y = 0.0
	var dir := to.normalized() if to.length() > 0.01 else Vector3.BACK
	var hp0 := dst.hp
	dst.last_hit_by = src
	dst.take_damage(amount, dir, knock, {"source": src, "eff": 1.0, "final": true})
	dst.popup(str(amount), Color(0.95, 0.3, 0.25), 1.2, 0.35, "damage")
	arena.note_hit(src, dst, {}, amount, hp0)
	if amount >= hp0 and arena.has_method("on_knocked_out"):
		arena.on_knocked_out(src, dst)
	st(dst).hurt_t = now


func _attract(user: BattleFighter, target: BattleFighter) -> void:
	var a := String(user.mon.gender)
	var b := String(target.mon.gender)
	if a == "" or b == "":
		target.popup("Sem efeito...", Color(0.7, 0.7, 0.7))
		note_fail(user)
	elif a == b or active(st(target), "attract"):
		_fail(user)
	else:
		st(target).attract = now + FOREVER  # oficial: até sair de campo
		target.popup("Apaixonou-se!", Color(1, 0.55, 0.75))


## Troca de golpe (Baton Pass, U-turn...): o próximo do banco entra no lugar. pass_stats = Baton Pass.
func _switch(user: BattleFighter, pass_stats: bool) -> void:
	if not is_instance_valid(user) or not user.active() or not arena.has_method("switch_out"):
		return
	var keep: Dictionary = user.stages.duplicate()
	var crit := user.crit_stage
	var nf = arena.switch_out(user)
	if nf == null:
		_fail(user)
	elif pass_stats:
		nf.stages = keep
		nf.crit_stage = crit
		nf.popup("Recebeu o bastão!", Color(0.8, 0.9, 1.0))


func _clear_terrain(near: BattleFighter) -> void:
	var had := false
	for k in TERRAINS:
		if active(field, k):
			had = true
		field.erase(k)
	if had:
		near.popup("O terreno sumiu!", Color(0.85, 0.85, 0.85))


func _set_terrain(kind: String, user: BattleFighter, text: String, type: String) -> void:
	for k in TERRAINS:
		field.erase(k)
	set_rounds(field, kind, FIELD_TURNS)
	arena.popup(user.position + Vector3(0, 1.6, 0), text, Dex.type_color(type))
	_vfx("terrain", [kind, rounds_secs(FIELD_TURNS)])


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
	user.clear_seed()
	free_bind(user)
	user.trap_t = 0.0
	for z in spikes.duplicate():
		if int(z.side) != user.side:
			_drop_spike(z)
	if arena.field and arena.field.has_method("clear_spikes"):
		arena.field.clear_spikes(1 - user.side)


## debuff_aoe com "special" (Tickle, Teeter Dance, Venom Drench). true = resolvido aqui.
func debuff_move(user: BattleFighter, t: BattleFighter, mv: Dictionary) -> bool:
	match String(mv.get("special", "")):
		"tickle":
			arena.moves.change_stage(t, "atk", -1, user)
			arena.moves.change_stage(t, "def", -1, user)
		"teeter_dance":
			_status(user, t, "confusion")
		"venom_drench":
			if t.status in ["poison", "toxic"]:
				for k in ["atk", "spa", "spe"]:
					arena.moves.change_stage(t, k, -1, user)
			else:
				t.popup("Sem efeito...", Color(0.7, 0.7, 0.7))
		_:
			return false
	return true


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
			st(foe).cursed = true  # 1/4 no fim de cada turno até sair de campo (BattleEndTurn)
			foe.popup("Amaldiçoado!", Dex.type_color("ghost"))
		return true
	var stats = mv.get("stats")
	if stats is Dictionary and sp in ["", "curse"]:
		# Growth: +2 em vez de +1 no sol (oficial)
		var mult := 2 if String(mv.get("id", "")) == "growth" and weather() == "sun" else 1
		for k in stats:
			arena.moves.change_stage(user, String(k), int(stats[k]) * mult)
		return true
	match sp:
		"", "charge", "defense_curl":
			if sp == "charge":
				s.charged = now + FOREVER  # Gen 9: até o próximo golpe Elétrico
				user.popup("Carregado!", Dex.type_color("electric"))
			elif sp == "defense_curl":
				s.curled = true
			return false
		"protect":
			# Protect/Detect: o turno todo (até o fim da rodada em que saiu); uso em rodadas seguidas
			# tem 1/3 de chance a cada vez (1, 1/3, 1/9...), zera quando uma rodada passa sem usar
			if not _stall_ok(s):
				_fail(user)
				return true
			set_rounds(s, "protect", 1)
			s.insight = bool(mv.get("insight", false))  # Detect lê o golpe
			user.popup("Proteger!", Color(0.6, 0.9, 1.0), 1.1)
			_vfx("protect_shield", [user, round_left()])
		"quick_guard":
			set_rounds(sd, "quick_guard", 1)
			user.popup("Guarda Rápida!", Color(0.6, 0.9, 1.0))
			_vfx("protect_shield", [user, round_left()])
		"follow_me":
			set_rounds(s, "follow", 1)
			s.follow_powder = bool(mv.get("powder", false))
			user.popup("Todos olham para %s!" % user.mon.display_name, Color(1, 0.8, 0.5))
			_vfx("spotlight", [user, round_left()])
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
			set_rounds(s, "laser", LASER_TURNS)
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
		"heal_half":
			_heal(user, int(ceil(user.max_hp * float(mv.get("heal", 0.5)))))
		"magnet_rise":
			if active(s, "magnet") or active(field, "gravity"):
				_fail(user)
				return true
			set_rounds(s, "magnet", MAGNET_TURNS)
			user.popup("Levitando!", Dex.type_color("electric"))
		"wonder_room":
			var wpos := user.position + Vector3(0, 1.6, 0)
			if active(field, "wonder"):
				field.erase("wonder")
				field.erase("wonder#")
				arena.popup(wpos, "Tudo voltou ao normal!", Dex.type_color("psychic"))
			else:
				set_rounds(field, "wonder", FIELD_TURNS)
				arena.popup(wpos, "Defesas trocadas!", Dex.type_color("psychic"))
				_vfx("gravity", [rounds_secs(FIELD_TURNS)])
		"psychic_terrain":
			_set_terrain("psychic", user, "Campo psíquico!", "psychic")
		"destiny_bond":
			s.destiny = true
			user.popup("Destiny Bond!", Dex.type_color("ghost"))
		"coaching":
			var coach := partner(user)
			if coach == null:
				_fail(user)
			else:
				for k in ["atk", "def"]:
					arena.moves.change_stage(coach, k, 1)
		"acupressure":
			var pool3: Array = ACUPRESSURE_STATS.filter(
				func(k): return int(user.stages.get(k, 0)) < 6
			)
			if pool3.is_empty():
				_fail(user)
			else:
				arena.moves.change_stage(user, String(pool3[rng.randi() % pool3.size()]), 2)
		"recycle":
			if user.trainer_item != "" and user.item_used:
				user.item_used = false
				user.popup("Reciclou %s!" % _item_name(user), Color(0.7, 1.0, 0.7))
			else:
				_fail(user)
		"magnetic_flux":
			var got3 := 0
			for f in [user, partner(user)]:
				if f != null and _ability(f) in ["plus", "minus"]:
					got3 += 1
					for k in ["def", "spd"]:
						arena.moves.change_stage(f, k, 1)
			if got3 == 0:
				_fail(user)
		"ally_switch":
			var mate := partner(user)
			if mate == null:
				_fail(user)
			else:
				var at := user.position
				user.position = mate.position
				mate.position = at
				user.popup("Trocou de lugar!", Dex.type_color("psychic"))
		"roost":
			_heal(user, int(ceil(user.max_hp * float(mv.get("heal", 0.5)))))
			if "flying" in user.types:
				set_rounds(s, "roost", 1)  # sem o tipo Voador até o fim da rodada
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
			user.sleep_turns = BattleFighter.REST_COUNTER  # dorme 2 turnos
			user.popup("Dormiu e recuperou tudo!", Color(0.75, 0.8, 0.95))
		"life_dew":
			for f in [user, partner(user)]:
				if f != null:
					_heal(f, int(ceil(f.max_hp * 0.25)))
		"aromatherapy":
			_aromatherapy(user, bool(mv.get("bell", false)))
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
		"light_screen", "safeguard", "reflect", "mist":
			set_rounds(sd, sp, FIELD_TURNS)
			var words := {
				"light_screen": "Light Screen!",
				"safeguard": "Safeguard!",
				"reflect": "Reflect!",
				"mist": "Névoa protetora!"
			}
			user.popup(String(words[sp]), Color(0.9, 0.85, 1.0))
			_vfx("screen", [user.side, sp, rounds_secs(FIELD_TURNS)])
		"tailwind":
			set_rounds(sd, "tailwind", TAILWIND_TURNS)
			user.popup("Vento a favor!", Dex.type_color("flying"))
			_vfx("screen", [user.side, sp, rounds_secs(TAILWIND_TURNS)])
		"gravity":
			set_rounds(field, "gravity", FIELD_TURNS)
			arena.popup(
				user.position + Vector3(0, 1.6, 0), "Gravidade intensa!", Dex.type_color("psychic")
			)
			_vfx("gravity", [rounds_secs(FIELD_TURNS)])
		"trick_room":
			# Trick Room (-7 no oficial): a ordem da rodada inverte; usar de novo desliga
			var t = arena.get("turns")
			if t and t.has_method("toggle_trick_room"):
				var on: bool = t.toggle_trick_room()
				arena.popup(
					user.position + Vector3(0, 1.6, 0),
					"Dimensões distorcidas!" if on else "As dimensões voltaram ao normal!",
					Dex.type_color("psychic")
				)
			else:
				_fail(user)
		"grassy_terrain":
			_set_terrain("grassy", user, "Campo de grama!", "grass")
		"electric_terrain":
			_set_terrain("electric", user, "Campo elétrico!", "electric")
		"misty_terrain":
			_set_terrain("misty", user, "Campo de névoa!", "fairy")
		"sunny_day":
			set_weather("sun", FIELD_TURNS, user)
			arena.popup(
				user.position + Vector3(0, 1.6, 0), "O sol ficou forte!", Dex.type_color("fire")
			)
		"endure":
			set_rounds(s, "endure", 1)
			user.popup("Aguentar!", Color(1, 0.85, 0.5), 1.1)
			_vfx("protect_shield", [user, round_left()])
		"wide_guard":
			set_rounds(sd, "wide_guard", 1)
			user.popup("Guarda Ampla!", Color(0.6, 0.9, 1.0))
			_vfx("protect_shield", [user, round_left()])
		"counter":
			s.counter = now + COUNTER_TIME
			s.counter_cat = String(mv.get("counter_cat", "physical"))
			user.root_t = maxf(user.root_t, COUNTER_TIME)
			user.popup("Em guarda!", Color(1, 0.7, 0.4))
			_vfx("protect_shield", [user, COUNTER_TIME])
		"substitute":
			var cost := maxi(1, user.max_hp / 4)
			if int(s.sub) > 0 or user.hp <= cost:
				_fail(user)
				return true
			user.take_damage(cost, Vector3.ZERO, 0.0)
			s.sub = cost
			user.popup("Criou um substituto!", Color(0.9, 0.9, 0.95))
			_vfx("substitute", [user, true])
		"belly_drum":
			if user.hp <= user.max_hp / 2:
				_fail(user)
				return true
			user.take_damage(user.max_hp / 2, Vector3.ZERO, 0.0)
			arena.moves.change_stage(user, "atk", 12)
			user.popup("Ataque no máximo!", Color(1, 0.6, 0.3))
		"howl":
			for f in [user, partner(user)]:
				if f != null:
					arena.moves.change_stage(f, "atk", 1)
		"dragon_cheer":
			var dc := partner(user)
			if dc == null:
				_fail(user)
			else:
				dc.crit_stage = mini(dc.crit_stage + (2 if "dragon" in dc.types else 1), 4)
				dc.popup("Ânimo de dragão!", Dex.type_color("dragon"))
		"heal_pulse":
			var hp_to := partner(user)
			if hp_to == null:
				hp_to = user
			_heal(hp_to, int(ceil(hp_to.max_hp * 0.5)))
		"psych_up":
			var foe2 := user.opponent
			if not is_instance_valid(foe2) or not foe2.active():
				_fail(user)
			else:
				for k in foe2.stages:
					user.stages[k] = int(foe2.stages[k])
				user.crit_stage = foe2.crit_stage
				user.popup("Copiou os atributos!", Color(0.9, 0.9, 1.0))
		"regen":
			# Ingrain / Aqua Ring: 1/16 no fim de cada turno (BattleEndTurn), até sair de campo
			var root := bool(mv.get("rooted", false))
			var key := "ingrain" if root else "aqua_ring"
			if bool(s.get(key, false)):
				_fail(user)
				return true
			s[key] = true
			s.regen = true
			if root:
				s.rooted = true
				s.trapped = true
			user.popup("Criou raízes!" if root else "Anel de água!", HEAL_COL)
		"defog":
			var foe3 := user.opponent
			if is_instance_valid(foe3) and foe3.active():
				foe3.evasion_t = 0.0
			var other := _sd(1 - user.side)
			for k in ["light_screen", "reflect", "safeguard", "mist"]:
				other.erase(k)
			spikes.clear()
			if arena.field and arena.field.has_method("clear_spikes"):
				arena.field.clear_spikes(-1)
			_clear_terrain(user)
			user.popup("O vento limpou o campo!", Dex.type_color("flying"))
		"spikes":
			var foes := _foes(user)
			if foes.is_empty() or not arena.field:
				_fail(user)
				return true
			for foe in foes:
				arena.field.add_spikes(user.side, foe.position)
			user.popup("Espinhos!", Dex.type_color("ground"))
		"stealth_rock":
			_lay_stealth_rock(user)
		"baton_pass":
			user.popup("Passou o bastão!", Color(0.8, 0.9, 1.0))
			arena.later(0.05, func() -> void: _switch(user, true))
		"wish":
			var w: Array = sd.get("wishes", [])
			w.append(
				{
					"rounds": WISH_TURNS,
					"amt": user.paced(int(ceil(user.max_hp / 2.0))),
					"id": user.get_instance_id(),
					"pos": user.position
				}
			)
			sd["wishes"] = w
			user.popup("Fez um desejo!", Color(1, 0.85, 0.95))
		"sleep_talk":
			var pool2: Array = user.moves.filter(
				func(x):
					return (
						_copyable(String(x)) != ""
						and not String(Dex.move(String(x)).get("special", "")) in SLEEP_MOVES
					)
			)
			if pool2.is_empty():
				_fail(user)
			else:
				_call(user, String(pool2[rng.randi() % pool2.size()]))
		"sandstorm":
			set_weather("sand", FIELD_TURNS, user)
			arena.popup(
				user.position + Vector3(0, 1.6, 0), "Tempestade de areia!", Dex.type_color("rock")
			)
		"rain_dance":
			set_weather("rain", FIELD_TURNS, user)
			arena.popup(
				user.position + Vector3(0, 1.6, 0), "Começou a chover!", Dex.type_color("water")
			)
		"snowscape":
			set_weather("hail", FIELD_TURNS, user)
			arena.popup(
				user.position + Vector3(0, 1.6, 0), "Começou a nevar!", Dex.type_color("ice")
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
			return BattleKanto.self_move(self, user, mv) or BattleMore.self_move(self, user, mv)
	return true


## Protect seguido (oficial): 1/3^n de chance, n = usos com sucesso em rodadas seguidas. Sucesso
## conta mais um; falha zera.
func _stall_ok(s: Dictionary) -> bool:
	var r := _round_id()
	var n := int(s.get("stall_n", 0))
	var last := int(s.get("stall_round", -99))
	if last < r - 1:
		n = 0
	if n > 0 and rng.randf() >= pow(1.0 / 3.0, n):
		s.stall_n = 0
		s.stall_round = -99
		return false
	s.stall_n = n + 1
	s.stall_round = r
	return true


func _call(user: BattleFighter, id: String) -> void:
	var mv := Dex.move(id)
	user.popup("→ %s!" % mv.get("name", id), Color(1, 0.95, 0.7), 1.0, 0.5)
	if user.status == "sleep":
		# Sleep Talk: o golpe chamado sai dormindo (o lutador age só durante ele).
		user.sleep_act_t = maxf(
			user.sleep_act_t, 0.65 + float(mv.get("windup", 0.0)) + float(mv.get("duration", 0.0))
		)
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


func _aromatherapy(user: BattleFighter, bell := false) -> void:
	var cured := 0
	for f in arena.fighters:
		if is_instance_valid(f) and f.active() and f.side == user.side and f.status in MAJOR:
			f.clear_status()
			cured += 1
	var list = arena.get("party") if user.side == 0 else arena.get("enemies")
	if list is Array:
		for m in list:
			if m is Mon and m.hp > 0 and (m.status != "" or m.battle_status != ""):
				m.cure()
				cured += 1
	var said := "Sinos curativos!" if bell else "Aroma calmante!"
	user.popup(said if cured > 0 else "Ninguém precisava.", Color(0.7, 1.0, 0.7))


func _lay_toxic_spikes(user: BattleFighter) -> void:
	var foes := _foes(user)
	if foes.is_empty():
		_fail(user)
		return
	for foe in foes:
		var at := Vector3(foe.position.x, 0.0, foe.position.z)
		var layered := false
		for z in spikes:
			if (
				int(z.side) == user.side
				and not z.get("rock", false)
				and Vector3(z.pos - at).length() < TOXIC_SPIKE_R + 0.5
			):
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


## Stealth Rock: pedras flutuando em volta de cada adversário; pega até quem voa (dano pela eficácia de Pedra).
func _lay_stealth_rock(user: BattleFighter) -> void:
	var foes := _foes(user)
	if foes.is_empty():
		_fail(user)
		return
	for foe in foes:
		var at := Vector3(foe.position.x, 0.0, foe.position.z)
		var t := now + TOXIC_SPIKE_LIFE
		spikes.append({"pos": at, "side": user.side, "layers": 1, "t": t, "hit": {}, "rock": true})
		arena.fx_disc(at, STEALTH_R, Dex.type_color("rock") * Color(1, 1, 1, 0.3), TOXIC_SPIKE_LIFE)
		_vfx("stealth_rock", [user.side, at, STEALTH_R, TOXIC_SPIKE_LIFE])
	user.popup("Pedras flutuantes!", Dex.type_color("rock"))


func _drop_spike(z: Dictionary) -> void:
	spikes.erase(z)


# --- Por frame (arena._fight_step) ---


func tick(dt: float) -> void:
	now += dt
	var gravity := active(field, "gravity")
	for f in arena.fighters:
		if not is_instance_valid(f) or not f.active():
			continue
		var s := st(f)
		if s.has("roost_types") and not active(s, "roost"):
			f.types = s.roost_types
			s.erase("roost_types")
		if active(s, "magnet") and gravity:
			s.erase("magnet")  # Gravity derruba quem levitava
		var mag_on := bool(s.get("mag", false))
		if active(s, "magnet"):
			f.fly_target = maxf(float(f.prof.get("fly", 0.0)), MAGNET_H)
			s["mag"] = true
		elif mag_on:
			s["mag"] = false
			f.fly_target = float(f.prof.get("fly", 0.0))
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
	_tick_spikes()
	_tick_wish()
	BattleMore.tick(self, dt)


func _tick_spikes() -> void:
	for z in spikes.duplicate():
		if now >= float(z.t):
			_drop_spike(z)
			continue
		for f in arena.fighters:
			if not is_instance_valid(f) or not f.active() or f.side == int(z.side):
				continue
			var id: int = f.get_instance_id()
			var rock := bool(z.get("rock", false))
			if z.hit.has(id) or (not rock and (not grounded(f) or f.position.y > 0.3)):
				continue
			if (
				Vector3(f.position.x - z.pos.x, 0.0, f.position.z - z.pos.z).length()
				> (STEALTH_R if rock else TOXIC_SPIKE_R)
			):
				continue
			z.hit[id] = true
			if rock:
				var ab = arena.abilities
				if ab and ab.has_method("no_indirect") and ab.no_indirect(f):
					continue
				var d: int = f.paced(
					maxi(1, int(f.max_hp / 8.0 * Dex.effectiveness("rock", f.types)))
				)
				f.popup("-%d pedras" % d, Dex.type_color("rock"), 0.8)
				f.take_damage(d, Vector3.ZERO, 0.0)
				continue
			if "poison" in f.types:
				f.popup("Absorveu os espinhos!", Dex.type_color("poison"))
				_drop_spike(z)
				break
			_status(null, f, "toxic" if int(z.layers) >= 2 else "poison")


## Healing Wish: quem entra no lugar de quem se sacrificou volta cheio (na hora, como o oficial).
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


# --- Fim de turno (BattleEndTurn) ---


## Future Sight: guarda o golpe para cair no fim do 2º turno depois deste (BattleMoves._future_sight).
func add_future(user: BattleFighter, mv: Dictionary, miss: BattleFighter) -> void:
	futures.append({"user": user, "mv": mv, "miss": miss, "rounds": FUTURE_TURNS})


## Passo 2: conta os Future Sight no ar; os que chegam no zero caem agora. Devolve quem soltou.
func end_turn_future() -> Array:
	var out := []
	for e in futures.duplicate():
		e.rounds = int(e.rounds) - 1
		if int(e.rounds) > 0:
			continue
		futures.erase(e)
		var u = e.user
		if is_instance_valid(u) and u.alive():
			u.popup("O futuro chegou!", Dex.type_color("psychic"), 0.9)
			arena.moves.land_future(u, e.mv, e.miss)
			out.append(u)
	return out


## Passo 3: Wish cura metade do HP de quem desejou no fim do turno seguinte (ele mesmo ou quem está no
## lugar dele, o mais perto do lugar). Devolve quem foi curado.
func end_turn_wish() -> Array:
	var out := []
	for side in 2:
		var ws: Array = sides[side].get("wishes", [])
		for w in ws.duplicate():
			w.rounds = int(w.get("rounds", 1)) - 1
			if int(w.rounds) > 0:
				continue
			ws.erase(w)
			var to: BattleFighter = null
			var best := INF
			for f in arena.fighters:
				if not is_instance_valid(f) or not f.active() or f.side != side:
					continue
				var d: float = (
					-1.0
					if f.get_instance_id() == int(w.id)
					else Vector3(f.position - w.pos).length()
				)
				if d < best:
					best = d
					to = f
			if to != null:
				to.popup("O desejo se realizou!", Color(1, 0.8, 0.95), 1.1)
				to.residual_heal(int(w.amt), "Wish")
				out.append(to)
	return out


## Passo 12: o Yawn chegou ao fim. Dorme se ainda está sem status (Safeguard, Electric Terrain...).
func yawn_sleep(f: BattleFighter) -> void:
	var s := st(f)
	var by = s.get("yawn_by")
	s.erase("yawn_by")
	if f.active() and f.status == "":
		_status(by if is_instance_valid(by) else null, f, "sleep")


## O Encore acabou (ou foi refeito): destrava os outros golpes.
func end_encore(f: BattleFighter) -> void:
	var s := st(f)
	var keep := String(s.get("encore_move", ""))
	if keep == "":
		return
	for mid in f.moves:
		if String(mid) != keep and float(f.move_cd.get(mid, 0.0)) >= LOCK_CD * 0.5:
			f.move_cd[mid] = 0.0
	s.erase("encore_move")


## O Disable acabou (ou foi refeito): destrava o golpe.
func end_disable(f: BattleFighter) -> void:
	var s := st(f)
	var id := String(s.get("disable_move", ""))
	if id != "" and float(f.move_cd.get(id, 0.0)) >= LOCK_CD * 0.5:
		f.move_cd[id] = 0.0
	s.erase("disable_move")


## Solta do Wrap/Bind (acabou, quem prendeu saiu, Rapid Spin).
func free_bind(f: BattleFighter) -> void:
	var s := st(f)
	s.erase("bound")
	s.erase("bound#")
	s.erase("bound_by")


## Passo 17: o que vale só a rodada em que saiu (Protect, Endure, Quick/Wide Guard, Roost, Follow
## Me) e o Laser Focus (até o fim do turno seguinte).
func end_turn_only() -> void:
	for id in _st:
		var s: Dictionary = _st[id]
		for k in ["protect", "endure", "roost", "follow", "laser", "lock", "coat"]:
			count_round(s, k)
	for sd in sides:
		for k in ["quick_guard", "wide_guard"]:
			count_round(sd, k)


# --- Consultas de fora ---


func speed_mult(f: BattleFighter) -> float:
	return 2.0 if active(_sd(f.side), "tailwind") else 1.0


func no_jump() -> bool:
	return active(field, "gravity")


func cant_escape(f: BattleFighter) -> bool:
	if not is_instance_valid(f) or "ghost" in f.types:
		return false
	return bool(st(f).trapped) or active(st(f), "bound")


## Dano esperado de OHKO/Endeavor para a IA (-1 = use a fórmula).
func expected_exact(user: BattleFighter, target: BattleFighter, mv: Dictionary) -> float:
	match String(mv.get("special", "")):
		"ohko":
			if target.level > user.level:
				return 0.0
			return float(target.hp) * clampf(accuracy_of(user, mv) / 100.0, 0.0, 1.0)
		"endeavor":
			return float(maxi(target.hp - user.hp, 0))
		"metal_burst":
			return float(BattleKanto.burst_amount(self, user)) if usable(user, mv) else 0.0
		"final_gambit":
			# Só vale como último recurso: HP baixo e o golpe derruba.
			if (
				Dex.effectiveness(String(mv.get("type", "")), target.types) == 0.0
				or float(user.hp) / maxf(float(user.max_hp), 1.0) > 0.4
				or user.hp < target.hp
			):
				return 0.0
			return float(target.hp)
	return -1.0


## Poder para a IA (variável ou guardado). Sem Stockpile o Spit Up vale 0.
func ai_power(user: BattleFighter, target: BattleFighter, mv: Dictionary) -> float:
	if float(mv.get("power", 0)) <= 0.0:
		return 0.0
	if not usable(user, mv):
		return 0.0
	match String(mv.get("special", "")):
		"spit_up":
			return 100.0 * int(st(user).stock)
		"triple_axel":
			return float(mv.power) * 2.0  # 1x, 2x e 3x: média de 2x por acerto
		"beat_up":
			var tot := 0.0
			for x in _beat_powers(user):
				tot += float(x)
			return tot
		"present":
			return 40.0  # média dos 40/80/120 descontando a cura
		"body_press":
			return float(mv.power) * user.stat("def") / maxf(user.stat("atk"), 1.0)
		"foul_play":
			return float(mv.power) * target.stat("atk") / maxf(user.stat("atk"), 1.0)
		"psyshock":
			return float(mv.power) * target.stat("spd") / maxf(target.stat("def"), 1.0)
	var p := float(adjust_move(user, target, mv).get("power", 0))
	if String(mv.get("special", "")) == "facade" and user.status == "burn":
		p *= 2.0  # a IA aplica a queimadura no Ataque; o Facade não sofre
	return p


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
		"roost", "heal_weather", "heal_half":
			return hp < 0.5
		"magnet_rise":
			return not active(s, "magnet") and has_opp and _has_type_hit(opp, "ground")
		"wonder_room":
			return not active(field, "wonder") and has_opp and opp.stat("spd") > opp.stat("def")
		"psychic_terrain":
			return not active(field, "psychic") and _has_type_hit(f, "psychic")
		"destiny_bond":
			return hp < 0.4 and _threatened(f)
		"coaching":
			return partner(f) != null
		"acupressure":
			return _stage_sum(f) < 2
		"recycle":
			return f.item_used and f.trainer_item != ""
		"magnetic_flux":
			return _ability(f) in ["plus", "minus"]
		"ally_switch":
			return false
		"lock_on":
			return has_opp and not active(s, "lock")
		"soak", "simple_beam":
			return has_opp
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
		"reflect":
			return not active(sd, sp) and has_opp and _has_cat(opp, "physical")
		"mist":
			return not active(sd, sp) and has_opp and _has_debuff(opp)
		"endure":
			return hp < 0.3 and _threatened(f)
		"wide_guard":
			return partner(f) != null and _threatened(f)
		"counter":
			return (
				has_opp
				and _threatened(f)
				and _has_cat(opp, String(mv.get("counter_cat", "physical")))
			)
		"substitute":
			return int(s.sub) <= 0 and hp > 0.5
		"belly_drum":
			return hp > 0.75 and int(f.stages.get("atk", 0)) < 2 and _has_cat(f, "physical")
		"howl":
			return int(f.stages.get("atk", 0)) < 2
		"dragon_cheer":
			var dp := partner(f)
			return dp != null and dp.crit_stage < 2
		"heal_pulse":
			var hp2 := partner(f)
			if hp2 == null:
				return hp < 0.5
			return float(hp2.hp) / maxf(hp2.max_hp, 1) < 0.5
		"wish":
			return hp < 0.6
		"regen":
			var rk := "ingrain" if bool(mv.get("rooted", false)) else "aqua_ring"
			return not bool(s.get(rk, false)) and hp < 0.9
		"psych_up":
			return has_opp and _stage_sum(opp) - _stage_sum(f) >= 2
		"baton_pass":
			return _stage_sum(f) >= 2
		"electric_terrain":
			return not active(field, "electric") and _has_type_hit(f, "electric")
		"misty_terrain":
			return (
				not active(field, "misty")
				and has_opp
				and (_has_type_hit(opp, "dragon") or _has_cat(opp, "status"))
			)
		"sunny_day":
			return weather() != "sun"
		"defog":
			var mine_hz := spikes.any(func(z): return int(z.side) != f.side)
			var walls := (
				has_opp
				and (active(_sd(opp.side), "reflect") or active(_sd(opp.side), "light_screen"))
			)
			return mine_hz or walls
		"spikes":
			return has_opp and not _spikes_laid(f.side)
		"stealth_rock":
			return (
				has_opp
				and not spikes.any(
					func(z): return int(z.side) == f.side and bool(z.get("rock", false))
				)
			)
		"sleep_talk":
			return f.status == "sleep"
		"attract":
			return (
				has_opp
				and not active(st(opp), "attract")
				and f.mon.gender != ""
				and opp.mon.gender != ""
				and f.mon.gender != opp.mon.gender
			)
		"taunt":
			return has_opp and not active(st(opp), "taunt") and _has_cat(opp, "status")
		"memento":
			return hp < 0.25
		"pain_split":
			return has_opp and hp < 0.5 and opp.hp > f.hp
		"strength_sap":
			return has_opp and hp < 0.6 and int(opp.stages.get("atk", 0)) > -6
		"skill_swap":
			return has_opp and _ability(opp) != _ability(f) and _ability(opp) != ""
		"trick":
			return has_opp and _has_item(opp) and not _has_item(f)
		"teeter_dance":
			return has_opp and opp.confusion_t <= 0.0
		"venom_drench":
			return has_opp and opp.status in ["poison", "toxic"]
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
		"snowscape":
			return weather() != "hail" and ("ice" in f.types or _has_type_hit(f, "ice"))
		"toxic_spikes":
			return (
				has_opp
				and opp.status == ""
				and not ("poison" in opp.types or "steel" in opp.types)
				and not spikes.any(
					func(z): return int(z.side) == f.side and not z.get("rock", false)
				)
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
	var k = BattleKanto.ai_worth(self, f, mv)
	if k != null:
		return k
	return BattleMore.ai_worth(self, f, mv)


func _has_type_hit(f: BattleFighter, type: String) -> bool:
	return f.moves.any(
		func(m):
			var mv := Dex.move(String(m))
			return float(mv.get("power", 0)) > 0.0 and String(mv.get("type", "")) == type
	)


## Tem golpe da categoria (physical / special / status).
func _has_cat(f: BattleFighter, cat: String) -> bool:
	return f.moves.any(func(m): return String(Dex.move(String(m)).get("category", "")) == cat)


## Tem golpe que baixa atributo do outro (Growl, Screech, efeito de golpe...).
func _has_debuff(f: BattleFighter) -> bool:
	return f.moves.any(
		func(m):
			var mv := Dex.move(String(m))
			var ef = mv.get("effect")
			return (
				(String(mv.get("kind", "")) == "debuff_aoe" and int(mv.get("stages", 0)) < 0)
				or (ef is Dictionary and int(ef.get("stages", 0)) < 0 and not ef.get("self", false))
			)
	)


func _stage_sum(f: BattleFighter) -> int:
	var n := 0
	for k in f.stages:
		n += int(f.stages[k])
	return n


func _spikes_laid(side: int) -> bool:
	var fl = arena.get("field")
	return fl != null and fl.marks.any(func(m): return m.kind == "spikes" and int(m.side) == side)


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

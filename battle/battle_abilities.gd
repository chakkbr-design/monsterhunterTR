class_name BattleAbilities
extends RefCounted
## Efeitos das habilidades (data/abilities.json) na luta em tempo real, com a faixa de habilidade no HUD.
## A arena cria um por luta (arena.abilities) e chama os ganchos abaixo.
## Extras que a arena/moves/IA podem consultar: walk_mult(f), cast_speed_mult(f, mv), profile_bias(f),
## blocks_stage_drop(f, stat).
## Clima: `weather_now()` ("" | sun | rain | sand | hail) vem de set_weather() (golpe ou habilidade, com
## duração em segundos) ou de arena.opts.weather (a arena toda, sem fim). Cloud Nine/Air Lock o suprimem.

const PINCH := {"blaze": "fire", "torrent": "water", "overgrow": "grass", "swarm": "bug"}
const PINCH_MULT := 1.5
const CONTACT_KINDS := ["dash", "arc", "multi_arc", "lunge"]
const CONTACT_CHANCE := 0.3
## Efeito por contato: habilidade -> status possíveis em quem encosta.
const CONTACT_STATUS := {
	"static": ["paralysis"],
	"poison_point": ["poison"],
	"flame_body": ["burn"],
	"effect_spore": ["poison", "paralysis", "sleep"],
}
const SOUND_MOVES := [
	"growl", "sing", "supersonic", "screech", "metal_sound", "bug_buzz", "sonic_boom", "hyper_beam"
]
const PUNCH_MOVES := [
	"karate_chop",
	"cross_chop",
	"close_combat",
	"submission",
	"rage",
	"double_slap",
	"pound",
	"metal_claw"
]
const BITE_MOVES := ["bite", "crunch", "fire_fang", "hyper_fang", "super_fang"]
const RECKLESS_MOVES := ["submission", "volt_tackle", "thrash", "self_destruct", "flail"]
## Habilidades que seguram a intimidação.
const INTIMIDATE_PROOF := [
	"inner_focus", "oblivious", "own_tempo", "clear_body", "hyper_cutter", "defiant", "competitive"
]
## Status bloqueado por habilidade.
const BLOCKS := {
	"inner_focus": ["flinch"],
	"own_tempo": ["confusion"],
	"vital_spirit": ["sleep"],
	"insomnia": ["sleep"],
	"water_veil": ["burn"],
	"limber": ["paralysis"],
	"immunity": ["poison"],
}
## Queda de atributo anulada: habilidade -> chaves (vazio = todas).
const KEEP_STAT := {
	"clear_body": [],
	"hyper_cutter": ["atk"],
	"keen_eye": ["acc"],
	"big_pecks": ["def"],
}
const STAGE_KEYS := ["atk", "def", "spa", "spd", "spe", "acc"]
## Clima (tempo real): duração do que uma habilidade/golpe cria e o intervalo do "turno" do clima.
const WEATHER_SECS := 25.0
const WEATHER_TICK := 2.0
const WEATHER_ALIAS := {
	"sunny": "sun",
	"sunny_day": "sun",
	"harsh_sunlight": "sun",
	"rainy": "rain",
	"rain_dance": "rain",
	"sandstorm": "sand",
	"hail": "hail",
	"snow": "hail",
	"snowstorm": "hail",
}
const SANDPROOF_TYPES := ["rock", "ground", "steel"]
const SANDPROOF := ["sand_rush", "sand_force", "sand_veil", "magic_guard", "overcoat"]
const DOT_STATUS := ["burn", "poison", "leech"]
const BANNER_GAP := 3.0
const POPUP_GAP := 1.0
const COL_DEFAULT := Color(1.0, 0.85, 0.4)

## Perfis de movimento sugeridos (brawler, shooter, skirmisher, wall, trickster, flyer).
const PROFILES := {
	"levitate": "flyer",
	"gale_wings": "flyer",
	"big_pecks": "flyer",
	"sturdy": "wall",
	"shell_armor": "wall",
	"battle_armor": "wall",
	"multiscale": "wall",
	"thick_fat": "wall",
	"filter": "wall",
	"marvel_scale": "wall",
	"regenerator": "wall",
	"rough_skin": "wall",
	"speed_boost": "skirmisher",
	"quick_feet": "skirmisher",
	"swift_swim": "skirmisher",
	"chlorophyll": "skirmisher",
	"run_away": "skirmisher",
	"unburden": "skirmisher",
	"motor_drive": "skirmisher",
	"prankster": "trickster",
	"serene_grace": "trickster",
	"effect_spore": "trickster",
	"cute_charm": "trickster",
	"stench": "trickster",
	"shield_dust": "trickster",
	"iron_fist": "brawler",
	"guts": "brawler",
	"moxie": "brawler",
	"tough_claws": "brawler",
	"strong_jaw": "brawler",
	"huge_power": "brawler",
	"reckless": "brawler",
	"defiant": "brawler",
	"sheer_force": "brawler",
	"intimidate": "brawler",
	"sniper": "shooter",
	"compound_eyes": "shooter",
	"no_guard": "shooter",
	"technician": "shooter",
	"lightning_rod": "shooter",
	"storm_drain": "shooter",
	"competitive": "shooter",
	"plus": "shooter",
	"minus": "shooter",
	"skill_link": "shooter",
}

var arena: Node
## Faixas realmente mostradas (depois do limite de 3 s) e a última, para testes.
var banners_shown := 0
var last_banner := ""

var _now := 0.0
var _st := {}  ## id do lutador -> estado (timers, marcas)
var _pending_intimidate: Array = []
var _pending_enter: Array = []  ## Drought, Frisk: precisam de campo/inimigo prontos
var weather := ""  ## clima criado por golpe/habilidade
var weather_t := 0.0


func _init(a: Node) -> void:
	arena = a


# --- Utilidades ---


## Magic Guard: sem dano indireto (veneno, queimadura, semente).
func no_indirect(f: BattleFighter) -> bool:
	return ability_of(f) == "magic_guard"


func ability_of(f: BattleFighter) -> String:
	if not is_instance_valid(f) or f.mon == null:
		return ""
	if f.has_meta("ability_override"):  # Gastro Acid / Worry Seed
		return String(f.get_meta("ability_override"))
	return f.mon.ability


func _state(f: BattleFighter) -> Dictionary:
	var id := f.get_instance_id()
	if not _st.has(id):
		_st[id] = {
			"banner": -99.0,
			"popup": -99.0,
			"stages": f.stages.duplicate(),
			"status_age": 0.0,
			"shed": 0.0,
			"regen": 0.0,
			"speed": 0.0,
			"unburdened": f.item_used,
			"flash": false,
			"wx": 0.0,
			"item": "",
		}
	return _st[id]


func partner_of(f: BattleFighter) -> BattleFighter:
	for g in arena.fighters:
		if g != f and is_instance_valid(g) and g.side == f.side and g.active():
			return g
	return null


func _is_contact(mv: Dictionary) -> bool:
	return bool(mv.get("contact", false)) or String(mv.get("kind", "")) in CONTACT_KINDS


func _is_sound(mv: Dictionary) -> bool:
	return bool(mv.get("sound", false)) or String(mv.get("id", "")) in SOUND_MOVES


## Mostra a habilidade agindo: popup curto (no máx. 1/s) e faixa no HUD (no máx. 1 a cada 3 s).
func _fire(f: BattleFighter, col := COL_DEFAULT) -> void:
	if not is_instance_valid(f):
		return
	var id := ability_of(f)
	var nm := String(Dex.ability(id).get("name", id.to_upper()))
	var s := _state(f)
	if _now - float(s.popup) >= POPUP_GAP:
		s.popup = _now
		f.popup(nm, col, 0.8, 0.5)
	if _now - float(s.banner) >= BANNER_GAP:
		s.banner = _now
		banners_shown += 1
		last_banner = nm
		if arena.hud and arena.hud.has_method("ability_banner"):
			arena.hud.ability_banner(f, nm)


func _stage_up(f: BattleFighter, k: String, n: int) -> void:
	if f.alive() and int(f.stages.get(k, 0)) < 6:
		arena.moves.change_stage(f, k, n)


func _heal_pct(f: BattleFighter, pct: float) -> void:
	if f.alive() and f.hp < f.max_hp:
		f.heal(maxi(1, int(float(f.max_hp) * pct)))


func _roll(chance: float) -> bool:
	return arena.rng.randf() < chance


# --- Ganchos ---


## Lutador entrou em campo (Intimidate etc.).
func on_enter(f: BattleFighter) -> void:
	var a := ability_of(f)
	_state(f)
	if a == "intimidate":
		_pending_intimidate.append(f)
	elif a == "super_luck":
		f.crit_stage += 1
	elif a in ["drought", "frisk"]:
		_pending_enter.append(f)


# --- Clima ---


## Cria clima por `secs` s (-1 = sem fim). Devolve falso se já há o mesmo clima ativo.
func set_weather(kind: String, secs := WEATHER_SECS) -> bool:
	kind = String(WEATHER_ALIAS.get(kind, kind))
	if kind == "" or (weather == kind and (weather_t > 0.0 or weather_t < 0.0)):
		return false
	weather = kind
	weather_t = secs
	return true


func _suppressed() -> bool:
	for g in arena.fighters:
		if is_instance_valid(g) and g.active() and ability_of(g) in ["cloud_nine", "air_lock"]:
			return true
	return false


## Clima que vale agora ("" = nenhum ou suprimido por Cloud Nine).
func weather_now() -> String:
	var w := weather
	if w == "":
		w = String(
			WEATHER_ALIAS.get(String(arena.opts.get("weather", "")), arena.opts.get("weather", ""))
		)
	if w == "" or _suppressed():
		return ""
	return w


## Frisk: mostra o item do inimigo.
func _do_frisk(f: BattleFighter) -> bool:
	var foes: Array = arena.targets_of(f)
	if foes.is_empty():
		return false
	_fire(f, Color(0.7, 0.9, 1.0))
	for t in foes:
		var it := String(Dex.item(t.trainer_item).get("name", t.trainer_item))
		var held: String = _state(t).item
		if held != "":
			it = String(Dex.item(held).get("name", held))
		f.popup(
			"%s: %s" % [t.mon.display_name, it if it != "" else "sem item"],
			Color(0.7, 0.9, 1.0),
			0.8,
			0.9
		)
	return true


## Intimidate: -1 ATK nos inimigos ativos. Falso se ainda não há inimigo em campo.
func _do_intimidate(f: BattleFighter) -> bool:
	var foes: Array = arena.targets_of(f)
	if foes.is_empty():
		return false
	_fire(f, Color(1.0, 0.5, 0.35))
	for t in foes:
		if ability_of(t) in INTIMIDATE_PROOF:
			_fire(t)
		else:
			arena.moves.change_stage(t, "atk", -1)
	return true


## Multiplicadores de dano de cada lado (sem efeitos colaterais).
func _mults(user: BattleFighter, target: BattleFighter, mv: Dictionary) -> Dictionary:
	var ua := ability_of(user)
	var ta := ability_of(target)
	var um := 1.0
	var tm := 1.0
	var type := String(mv.get("type", "normal"))
	var power := float(mv.get("power", 0))
	var cat := String(mv.get("category", ""))
	var kind := String(mv.get("kind", ""))
	var id := String(mv.get("id", ""))
	if PINCH.get(ua, "") == type and user.hp * 3 <= user.max_hp:
		um *= PINCH_MULT
	var wx := weather_now()
	if power > 0.0:
		if (wx == "sun" and type == "fire") or (wx == "rain" and type == "water"):
			um *= 1.5
		elif (wx == "sun" and type == "water") or (wx == "rain" and type == "fire"):
			um *= 0.5
	match ua:
		"guts":
			if cat == "physical" and user.status != "":
				um *= 1.5
		"huge_power":
			if cat == "physical":
				um *= 1.5
		"hustle":
			if cat == "physical":
				um *= 1.2
		"technician":
			if power > 0.0 and power <= 60.0:
				um *= 1.5
		"adaptability":
			if power > 0.0 and type in user.types:
				um *= 1.33
		"sheer_force":
			if mv.get("effect") is Dictionary:
				um *= 1.3
		"iron_fist":
			if id in PUNCH_MOVES:
				um *= 1.3
		"strong_jaw":
			if id in BITE_MOVES:
				um *= 1.5
		"tough_claws":
			if _is_contact(mv):
				um *= 1.3
		"reckless":
			if id in RECKLESS_MOVES:
				um *= 1.2
		"skill_link":
			if kind == "multi_arc":
				um *= 1.2
		"sniper":
			if kind in ["projectile", "beam", "stream"] and user.flat_to(target).length() >= 5.0:
				um *= 1.4
		"flash_fire":
			if type == "fire" and _state(user).flash:
				um *= 1.5
		"plus", "minus":
			if cat == "special":
				var p := partner_of(user)
				if p != null and ability_of(p) in ["plus", "minus"]:
					um *= 1.5
		"tinted_lens":
			if power > 0.0 and Dex.effectiveness(type, target.types) < 1.0:
				um *= 1.5
		"solar_power":
			if cat == "special" and wx == "sun":
				um *= 1.5
		"sand_force":
			if power > 0.0 and wx == "sand" and type in SANDPROOF_TYPES:
				um *= 1.3
		"rivalry":
			var g1: String = user.mon.gender
			var g2: String = target.mon.gender
			if power > 0.0 and g1 != "" and g2 != "":
				um *= 1.25 if g1 == g2 else 0.75
		"unaware":
			# ignora os estágios de defesa do alvo
			if power > 0.0 and cat in ["physical", "special"]:
				var dk := "def" if cat == "physical" else "spd"
				um *= StatCalc.stage_mult(int(target.stages.get(dk, 0)))
	match ta:
		"thick_fat":
			if type in ["fire", "ice"]:
				tm *= 0.5
		"multiscale":
			if target.hp >= target.max_hp:
				tm *= 0.5
		"shell_armor", "battle_armor":
			tm *= 0.9
		"marvel_scale":
			if target.status != "":
				tm *= 0.67
		"filter":
			if power > 0.0 and Dex.effectiveness(type, target.types) > 1.0:
				tm *= 0.75
		"damp":
			if id == "self_destruct":
				tm *= 0.5
		"dry_skin":
			if type == "fire":
				tm *= 1.25
		"unaware":
			# ignora os estágios de ataque de quem bate
			if power > 0.0 and cat in ["physical", "special"]:
				var ak := "atk" if cat == "physical" else "spa"
				tm /= StatCalc.stage_mult(int(user.stages.get(ak, 0)))
	var pa := partner_of(target)
	if pa != null and ability_of(pa) == "friend_guard" and ua != "infiltrator":
		tm *= 0.75
	return {"user": um, "target": tm}


## Multiplicador no fim da fórmula de dano (Blaze/Torrent/Overgrow/Swarm, Thick Fat...).
func damage_mult(user: BattleFighter, target: BattleFighter, mv: Dictionary) -> float:
	var m := _mults(user, target, mv)
	return float(m.user) * float(m.target)


## true = o alvo é imune a este golpe pela habilidade (Levitate, Water Absorb, Soundproof...).
func immune(user: BattleFighter, target: BattleFighter, mv: Dictionary) -> bool:
	var type := String(mv.get("type", "normal"))
	var id := String(mv.get("id", ""))
	if _absorbs(target, target, type):
		return true
	# Para-raios / Dreno: o parceiro do portador atrai o golpe e absorve por ele.
	var p := partner_of(target)
	if p != null and user.side != target.side and _absorbs(p, target, type):
		return true
	match ability_of(target):
		"wonder_skin":
			# golpe de status de inimigo: precisão cai para 50%
			var acc := float(mv.get("accuracy", 0.0))
			if (
				String(mv.get("category", "")) == "status"
				and user.side != target.side
				and acc > 50.0
				and _roll(0.5)
			):
				_fire(target)
				return true
		"levitate":
			if type == "ground":
				_fire(target)
				return true
		"soundproof":
			if _is_sound(mv):
				_fire(target)
				return true
		"sticky_hold":
			if id == "thief":
				_fire(target)
				return true
		"damp":
			if id == "self_destruct":
				_fire(target)
				return true
		"telepathy":
			if user.side == target.side and user != target:
				_fire(target)
				return true
	return false


## Habilidades que absorvem um tipo. `hit` é quem foi atingido; se não for o portador, só vale
## Para-raios/Dreno (que puxam o golpe do parceiro).
func _absorbs(owner: BattleFighter, hit: BattleFighter, type: String) -> bool:
	var oa := ability_of(owner)
	if hit != owner and not oa in ["lightning_rod", "storm_drain"]:
		return false
	var col := Dex.type_color(type)
	match oa:
		"water_absorb":
			if type == "water":
				_heal_pct(owner, 0.25)
				_fire(owner, col)
				return true
		"dry_skin":
			if type == "water":
				_heal_pct(owner, 0.25)
				_fire(owner, col)
				return true
		"volt_absorb":
			if type == "electric":
				_heal_pct(owner, 0.25)
				_fire(owner, col)
				return true
		"motor_drive":
			if type == "electric":
				_stage_up(owner, "spe", 1)
				_fire(owner, col)
				return true
		"sap_sipper":
			if type == "grass":
				_stage_up(owner, "atk", 1)
				_fire(owner, col)
				return true
		"lightning_rod":
			if type == "electric":
				_stage_up(owner, "spa", 1)
				_fire(owner, col)
				return true
		"storm_drain":
			if type == "water":
				_stage_up(owner, "spa", 1)
				_fire(owner, col)
				return true
		"flash_fire":
			if type == "fire":
				_state(owner).flash = true
				_fire(owner, col)
				return true
	return false


## Dano final ajustado (Sturdy segura com 1 HP etc.). Devolve o dano a aplicar.
func adjust_damage(_user: BattleFighter, target: BattleFighter, _mv: Dictionary, dmg: int) -> int:
	if ability_of(target) == "sturdy" and target.hp >= target.max_hp and dmg >= target.hp:
		_fire(target, Color(0.8, 0.8, 0.9))
		return maxi(target.hp - 1, 0)
	return dmg


## Depois do acerto (Static, Poison Point, Effect Spore ao contato...).
func on_hit(user: BattleFighter, target: BattleFighter, mv: Dictionary, _dmg: int) -> void:
	if not is_instance_valid(user) or not is_instance_valid(target):
		return
	var ua := ability_of(user)
	var ta := ability_of(target)
	var m := _mults(user, target, mv)
	if float(m.user) != 1.0:
		_fire(user)
	if float(m.target) != 1.0:
		_fire(target)
	var contact := _is_contact(mv)
	if contact and user.alive():
		if CONTACT_STATUS.has(ta) and _roll(CONTACT_CHANCE):
			var opts: Array = CONTACT_STATUS[ta]
			var st := String(opts[arena.rng.randi() % opts.size()])
			if (
				not BattleMoves.STATUS_IMMUNE.get(st, "-") in user.types
				and not blocks_status(user, st)
				and user.apply_status(st, target)
			):
				_fire(target)
				user.popup(
					String(BattleMoves.STATUS_WORDS.get(st, st.to_upper() + "!")),
					Color(1, 0.9, 0.6)
				)
		elif ta == "cute_charm" and ua != "oblivious" and _roll(CONTACT_CHANCE):
			user.gcd_t += 1.2
			user.popup("Enfeitiçado!", Color(1.0, 0.55, 0.75))
			_fire(target, Color(1.0, 0.55, 0.75))
		elif ta == "rough_skin" and ua != "magic_guard":
			var chip := maxi(1, int(user.max_hp / 16.0))
			_fire(target)
			user.popup("-%d" % chip, Color(0.8, 0.6, 0.4), 0.8)
			user.take_damage(chip, Vector3.ZERO, 0.0)
	if ua == "stench" and target.alive() and _roll(0.1) and not blocks_status(target, "flinch"):
		target.apply_status("flinch", user)
		_fire(user, Color(0.6, 0.5, 0.7))
	if ua == "serene_grace" and target.alive():
		_serene(user, target, mv)
	if ta == "justified" and String(mv.get("type", "")) == "dark":
		_stage_up(target, "atk", 1)
		_fire(target)
	if target.hp <= 0:
		if ua == "moxie":
			_stage_up(user, "atk", 1)
			_fire(user)
		if ta == "aftermath" and user.alive() and ua != "magic_guard":
			_fire(target)
			user.take_damage(maxi(1, int(user.max_hp / 4.0)), Vector3.ZERO, 0.0)


## Serene Grace: segunda chance para o efeito extra do golpe.
func _serene(user: BattleFighter, target: BattleFighter, mv: Dictionary) -> void:
	var ef = mv.get("effect")
	if not ef is Dictionary or not _roll(float(ef.get("chance", 0.0))):
		return
	if ef.has("stat"):
		var who: BattleFighter = user if ef.get("self", false) else target
		arena.moves.change_stage(who, String(ef.stat), int(ef.stages))
	else:
		var st := String(ef.status)
		if (
			BattleMoves.STATUS_IMMUNE.get(st, "-") in target.types
			or blocks_status(target, st)
			or not target.apply_status(st, user)
		):
			return
	_fire(user)


## true = a habilidade bloqueia esse status (Inner Focus, Own Tempo, Vital Spirit...).
func blocks_status(f: BattleFighter, status: String) -> bool:
	var a := ability_of(f)
	if a == "shield_dust" or (BLOCKS.has(a) and status in BLOCKS[a]):
		_fire(f)
		return true
	if a == "steadfast" and status == "flinch":
		_stage_up(f, "spe", 1)
		_fire(f)
	return false


## Queda de atributo que a habilidade impede (Clear Body, Hyper Cutter, Keen Eye, Big Pecks).
func blocks_stage_drop(f: BattleFighter, k: String) -> bool:
	var a := ability_of(f)
	if not KEEP_STAT.has(a):
		return false
	var keys: Array = KEEP_STAT[a]
	return keys.is_empty() or k in keys


## Multiplicador de precisão do usuário (Compound Eyes).
func acc_mult(f: BattleFighter) -> float:
	match ability_of(f):
		"compound_eyes":
			return 1.3
		"illuminate":
			return 1.05
		"no_guard":
			return 1.4
		"hustle":
			return 0.9
	return 1.0


## Multiplicador da velocidade de andar (a arena aplica em Fighter.drive).
func walk_mult(f: BattleFighter) -> float:
	var m := 1.0
	var a := ability_of(f)
	match a:
		"run_away":
			m *= 1.1
		"quick_feet":
			if f.status != "":
				m *= 1.3
	m *= _weather_speed(a)
	for t in arena.targets_of(f):
		var ta := ability_of(t)
		if ta == "arena_trap" and not f.is_airborne() and a != "levitate":
			m *= 0.9
		elif ta == "magnet_pull" and "steel" in f.types:
			m *= 0.9
	return m


## Speed dobrada no clima certo (Chlorophyll no sol, Swift Swim na chuva, Sand Rush na areia),
## expressa como x1,5 no andar e no preparo dos golpes.
func _weather_speed(a: String) -> float:
	var wx := weather_now()
	if (
		(a == "chlorophyll" and wx == "sun")
		or (a == "swift_swim" and wx == "rain")
		or (a == "sand_rush" and wx == "sand")
	):
		return 1.5
	return 1.0


## Multiplicador da velocidade de lançar o golpe (Prankster etc.): >1 = sai mais rápido.
func cast_speed_mult(f: BattleFighter, mv: Dictionary) -> float:
	var ws := _weather_speed(ability_of(f))
	if ws > 1.0:
		return ws
	match ability_of(f):
		"prankster":
			if String(mv.get("category", "")) == "status":
				return 1.5
		"gale_wings":
			if String(mv.get("type", "")) == "flying":
				return 1.4
		"quick_feet":
			if f.status != "":
				return 1.2
	return 1.0


## Perfil de movimento sugerido pela habilidade ("" = nenhum).
func profile_bias(f: BattleFighter) -> String:
	return String(PROFILES.get(ability_of(f), ""))


# --- Por frame ---


func tick(dt: float) -> void:
	_now += dt
	if not _pending_intimidate.is_empty() and arena.state == "fight":
		var keep: Array = []
		for f in _pending_intimidate:
			if is_instance_valid(f) and f.active() and not _do_intimidate(f):
				keep.append(f)
		_pending_intimidate = keep
	if not _pending_enter.is_empty() and arena.state == "fight":
		var keep2: Array = []
		for f in _pending_enter:
			if not is_instance_valid(f) or not f.active():
				continue
			if ability_of(f) == "drought":
				set_weather("sun")
				_fire(f, Color(1.0, 0.75, 0.3))
			elif not _do_frisk(f):
				keep2.append(f)
		_pending_enter = keep2
	if weather_t > 0.0:
		weather_t -= dt
		if weather_t <= 0.0:
			weather = ""
			weather_t = 0.0
	for f in arena.fighters:
		if is_instance_valid(f) and f.active():
			_unnerve(f)
			_tick_fighter(f, dt)


## Unnerve: enquanto há um inimigo com Unnerve em campo, o item do treinador não é usado.
func _unnerve(f: BattleFighter) -> void:
	var s := _state(f)
	var held := false
	for t in arena.targets_of(f):
		if ability_of(t) == "unnerve":
			held = true
	if held and f.trainer_item != "" and not f.item_used:
		s.item = f.trainer_item
		f.trainer_item = ""
		for t in arena.targets_of(f):
			if ability_of(t) == "unnerve":
				_fire(t)
	elif not held and s.item != "":
		f.trainer_item = String(s.item)
		s.item = ""


## Efeitos do clima a cada WEATHER_TICK s (Rain Dish, Dry Skin, Solar Power, areia/granizo).
func _weather_tick(f: BattleFighter, a: String, s: Dictionary, dt: float) -> void:
	var wx := weather_now()
	if wx == "":
		s.wx = 0.0
		return
	s.wx = float(s.wx) + dt
	if float(s.wx) < WEATHER_TICK:
		return
	s.wx = 0.0
	var guard := a == "magic_guard"
	match wx:
		"rain":
			if a == "rain_dish":
				_heal_pct(f, 1.0 / 16.0)
				_fire(f, Color(0.5, 0.7, 1.0))
			elif a == "dry_skin":
				_heal_pct(f, 1.0 / 8.0)
				_fire(f, Color(0.5, 0.7, 1.0))
		"sun":
			if a in ["dry_skin", "solar_power"] and not guard:
				_weather_chip(f, 1.0 / 8.0, Color(1.0, 0.75, 0.3))
				_fire(f, Color(1.0, 0.75, 0.3))
		"sand":
			if not _sand_proof(f, a):
				_weather_chip(f, 1.0 / 16.0, Color(0.8, 0.7, 0.4))
		"hail":
			if not guard and not "ice" in f.types:
				_weather_chip(f, 1.0 / 16.0, Color(0.7, 0.9, 1.0))


func _sand_proof(f: BattleFighter, a: String) -> bool:
	if a in SANDPROOF:
		return true
	for t in f.types:
		if t in SANDPROOF_TYPES:
			return true
	return false


func _weather_chip(f: BattleFighter, pct: float, col: Color) -> void:
	var d := maxi(1, int(float(f.max_hp) * pct * f.dot_scale()))
	f.popup("-%d" % d, col, 0.8)
	f.take_damage(d, Vector3.ZERO, 0.0)


func _tick_fighter(f: BattleFighter, dt: float) -> void:
	var a := ability_of(f)
	if a == "":
		return
	var s := _state(f)
	_watch_stages(f, a, s)
	_weather_tick(f, a, s, dt)
	if f.confusion_t > 0.0 and a == "tangled_feet" and f.evasion_t <= 0.0:
		f.evasion = 0.2
		f.evasion_t = 0.5
	match a:
		"speed_boost":
			s.speed = float(s.speed) + dt
			if s.speed >= 8.0:
				s.speed = 0.0
				if int(f.stages.get("spe", 0)) < 6:
					_stage_up(f, "spe", 1)
					_fire(f)
		"regenerator":
			_slow_heal(f, s, dt, 3.0, 0.04)
		"pickup":
			_slow_heal(f, s, dt, 10.0, 0.05)
		"poison_heal":
			if f.status == "poison":
				_slow_heal(f, s, dt, 2.0, 0.08)
		"unburden":
			if f.item_used and not s.unburdened:
				s.unburdened = true
				_stage_up(f, "spe", 2)
				_fire(f)
		"shed_skin":
			if f.status != "":
				s.shed = float(s.shed) + dt
				if s.shed >= 3.0:
					s.shed = 0.0
					if _roll(0.33):
						f.clear_status()
						_fire(f)
		"natural_cure":
			if f.status != "":
				s.status_age = float(s.status_age) + dt
				if s.status_age >= 2.0:
					s.status_age = 0.0
					f.clear_status()
					_fire(f, Color(0.6, 1.0, 0.7))
			else:
				s.status_age = 0.0
		"sand_veil":
			if f.evasion_t <= 0.0 and weather_now() == "sand":
				f.evasion = 0.2
				f.evasion_t = 0.5
		"magic_guard":
			# sem dano indireto: veneno, queimadura e semente não tiram HP
			if f.status in DOT_STATUS:
				f.status_tick = maxf(f.status_tick, 0.5)
		"rock_head":
			if f.stagger_t > 1.2:
				f.stagger_t = 1.2
				_fire(f)


func _slow_heal(f: BattleFighter, s: Dictionary, dt: float, every: float, pct: float) -> void:
	s.regen = float(s.regen) + dt
	if s.regen >= every:
		s.regen = 0.0
		if f.hp < f.max_hp:
			_heal_pct(f, pct)
			_fire(f, Color(0.5, 1.0, 0.6))


## Quedas de atributo: Clear Body & cia. desfazem; Defiant/Competitive reagem.
func _watch_stages(f: BattleFighter, a: String, s: Dictionary) -> void:
	var prev: Dictionary = s.stages
	var dropped := false
	for k in STAGE_KEYS:
		var cur := int(f.stages.get(k, 0))
		var was := int(prev.get(k, 0))
		if cur < was:
			if blocks_stage_drop(f, k):
				f.stages[k] = was
				_fire(f)
			else:
				dropped = true
	if dropped and a in ["defiant", "competitive"]:
		var key := "atk" if a == "defiant" else "spa"
		_stage_up(f, key, 2)
		_fire(f, Color(1.0, 0.5, 0.4))
	s.stages = f.stages.duplicate()

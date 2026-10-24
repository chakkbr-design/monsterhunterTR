class_name BattleAbilities
extends RefCounted
## Efeitos das habilidades (data/abilities.json) na luta em tempo real, com a faixa de habilidade no HUD.
## A arena cria um por luta (arena.abilities) e chama os ganchos abaixo.
## Regras oficiais (Gen 9, VGC) adaptadas à rodada (BattleTurns): o "fim de turno" do oficial roda em
## BattleEndTurn.run(), que chama os passos daqui na ordem oficial (count_weather_round +
## weather_residual, shed_skin, Poison Heal no passo do veneno, late_residual); on_round_end() faz só
## a parte das habilidades. "Ao entrar" dispara na troca e na substituição, em ordem pela Speed (do mais
## rápido ao mais lento; Trick Room inverte).
## Extras que a arena/moves/IA/turnos podem consultar: walk_mult(f), cast_speed_mult(f, mv),
## order_speed_mult(f), priority_bonus(f, mv), redirect(user, target, mv), profile_bias(f),
## blocks_stage_drop(f, stat).
## Clima: `weather_now()` ("" | sun | rain | sand | hail) vem de set_weather_rounds() (golpe e
## habilidade, 5 rodadas como os 5 turnos do oficial, contadas no fim de turno), de set_weather() (em
## segundos, para testes e efeitos de tempo real) ou de arena.opts.weather (a arena toda, sem fim). Cloud Nine/Air Lock o suprimem. "hail" é a neve da Gen 9
## (sem dano).

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
## Golpes de som oficiais (Soundproof).
const SOUND_MOVES := [
	"growl",
	"sing",
	"supersonic",
	"screech",
	"metal_sound",
	"bug_buzz",
	"hyper_voice",
	"disarming_voice",
	"echoed_voice",
	"round",
	"roar",
	"snore",
	"uproar",
	"perish_song",
	"grass_whistle",
	"heal_bell",
	"boomburst",
	"noble_roar",
	"parting_shot",
	"relic_song",
	"sparkling_aria",
	"overdrive",
	"torch_song",
	"alluring_voice",
	"psychic_noise",
	"chatter",
	"clanging_scales",
]
## Golpes de soco oficiais (Iron Fist).
const PUNCH_MOVES := [
	"thunder_punch",
	"fire_punch",
	"ice_punch",
	"mega_punch",
	"comet_punch",
	"dizzy_punch",
	"dynamic_punch",
	"mach_punch",
	"bullet_punch",
	"drain_punch",
	"focus_punch",
	"power_up_punch",
	"shadow_punch",
	"hammer_arm",
	"sky_uppercut",
	"meteor_mash",
	"ice_hammer",
	"jet_punch",
	"rage_fist",
	"double_iron_bash",
	"plasma_fists",
	"headlong_rush",
	"wicked_blow",
	"surging_strikes",
]
## Mordidas oficiais (Strong Jaw).
const BITE_MOVES := [
	"bite",
	"crunch",
	"fire_fang",
	"ice_fang",
	"thunder_fang",
	"poison_fang",
	"hyper_fang",
	"psychic_fangs",
	"jaw_lock",
	"fishious_rend",
]
## Reckless: golpes com recuo ("recoil" nos dados) e os de queda (erro machuca).
const RECKLESS_MOVES := ["jump_kick", "high_jump_kick", "axe_kick", "supercell_slam", "head_smash"]
## Golpes que explodem (Damp impede).
const EXPLODE_MOVES := ["self_destruct", "explosion", "misty_explosion", "mind_blown"]
## Habilidades que seguram a intimidação (Gen 8+) e as que não deixam o Ataque cair.
## Defiant/Competitive não seguram: tomam o -1 e reagem com +2.
const INTIMIDATE_PROOF := [
	"inner_focus", "oblivious", "own_tempo", "scrappy", "clear_body", "hyper_cutter"
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
	"illuminate": ["acc"],
	"big_pecks": ["def"],
}
const STAGE_KEYS := ["atk", "def", "spa", "spd", "spe", "acc"]
## Habilidades que agem ao entrar (troca, substituição, começo da luta), em ordem pela Speed.
const ENTRY := ["intimidate", "drought", "frisk", "unnerve", "cloud_nine", "air_lock"]
## Clima: duração padrão de set_weather (s, tempo real) e rodadas do clima de golpe/habilidade (5 turnos).
const WEATHER_SECS := 25.0
const WEATHER_ROUNDS := 5
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
## Speed na ordem da rodada (oficial) e no andar/preparo (tempo real) dos que dobram a Speed.
const SPEED_DOUBLE := 2.0
const SPEED_WALK := 1.5
## No Guard: os golpes dele não erram (multiplicador de precisão que passa de 100%).
const NO_GUARD_ACC := 100.0
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
## Fins de rodada já passados (on_round_end).
var rounds := 0
## Ordem da última ativação "ao entrar" e do último fim de rodada (para testes).
var last_entry_order: Array = []
var last_round_order: Array = []

var _now := 0.0
var _st := {}  ## id do lutador -> estado (marcas)
var _pending_enter: Array = []  ## Intimidate, Drought, Frisk...: precisam de campo/inimigo prontos
var _field := {}  ## id -> lutador ativo no frame anterior (para ver quem saiu na troca)
var weather := ""  ## clima criado por golpe/habilidade
var weather_t := 0.0  ## segundos restantes (-1 = sem fim em segundos)
var weather_rounds := 0  ## rodadas restantes do clima de golpe/habilidade (0 = não conta rodada)
var weather_ended := ""  ## clima que acabou no último fim de turno (count_weather_round)


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
			"enter_round": rounds,
			"unburdened": f.item_used,
			"flash": false,
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


## Alguém ativo em campo com a habilidade `a`.
func _on_field(a: String) -> BattleFighter:
	for g in arena.fighters:
		if is_instance_valid(g) and g.active() and ability_of(g) == a:
			return g
	return null


## Ordem pela Speed (a da rodada: BattleTurns.speed_order, com Trick Room e sorteio no empate);
## sem turnos, pela Speed efetiva com order_speed_mult.
func _by_speed(list: Array) -> Array:
	var t = arena.get("turns")
	if t and t.has_method("speed_order"):
		return t.speed_order(list)
	var out := list.filter(func(f): return is_instance_valid(f))
	out.sort_custom(
		func(a, b): return a.eff_spe() * order_speed_mult(a) > b.eff_spe() * order_speed_mult(b)
	)
	return out


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


## Lutador entrou em campo (começo, troca ou substituição): Intimidate, Drought, Frisk...
## A ativação espera o campo pronto e sai em ordem pela Speed no próximo frame de luta.
func on_enter(f: BattleFighter) -> void:
	var a := ability_of(f)
	var s := _state(f)
	s.enter_round = rounds
	if a == "super_luck":
		f.crit_stage += 1
	elif a in ENTRY:
		_pending_enter.append(f)


## Ativação ao entrar. Falso = ainda não há inimigo em campo (tenta de novo no próximo frame).
func _entry(f: BattleFighter) -> bool:
	match ability_of(f):
		"intimidate":
			return _do_intimidate(f)
		"drought":
			set_weather_rounds("sun")
			_fire(f, Color(1.0, 0.75, 0.3))
		"frisk":
			return _do_frisk(f)
		"unnerve":
			if arena.targets_of(f).is_empty():
				return false
			_fire(f, Color(0.75, 0.6, 0.9))
		"cloud_nine", "air_lock":
			_fire(f, Color(0.8, 0.9, 1.0))
	return true


# --- Clima ---


## Cria clima por `secs` s (-1 = sem fim). Devolve falso se já há o mesmo clima ativo.
func set_weather(kind: String, secs := WEATHER_SECS) -> bool:
	kind = String(WEATHER_ALIAS.get(kind, kind))
	if kind == "" or _weather_on(kind):
		return false
	weather = kind
	weather_t = secs
	weather_rounds = 0
	return true


## Clima de golpe ou habilidade (Rain Dance, Drought): dura `n` rodadas, como os 5 turnos do oficial.
func set_weather_rounds(kind: String, n := WEATHER_ROUNDS) -> bool:
	kind = String(WEATHER_ALIAS.get(kind, kind))
	if kind == "" or _weather_on(kind):
		return false
	weather = kind
	weather_t = -1.0
	weather_rounds = n
	return true


func _weather_on(kind: String) -> bool:
	return weather == kind and (weather_t != 0.0 or weather_rounds > 0)


func _suppressed() -> bool:
	return _on_field("cloud_nine") != null or _on_field("air_lock") != null


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


## Frisk: mostra o item dos inimigos.
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


## Intimidate: -1 ATK em todos os inimigos ativos (os dois no 2x2). Falso se ainda não há inimigo.
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


# --- Dano ---


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
				um *= 2.0
		"hustle":
			if cat == "physical":
				um *= 1.5
		"technician":
			if power > 0.0 and power <= 60.0:
				um *= 1.5
		"adaptability":
			# STAB 2,0 no lugar de 1,5
			if power > 0.0 and type in user.types:
				um *= 4.0 / 3.0
		"sheer_force":
			if mv.get("effect") is Dictionary:
				um *= 1.3
		"iron_fist":
			if id in PUNCH_MOVES:
				um *= 1.2
		"strong_jaw":
			if id in BITE_MOVES:
				um *= 1.5
		"tough_claws":
			if _is_contact(mv):
				um *= 1.3
		"reckless":
			if mv.has("recoil") or id in RECKLESS_MOVES:
				um *= 1.2
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
				um *= 2.0
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
		"marvel_scale":
			# Defesa x1,5 com status: só no físico
			if target.status != "" and cat == "physical":
				tm *= 2.0 / 3.0
		"filter":
			if power > 0.0 and Dex.effectiveness(type, target.types) > 1.0:
				tm *= 0.75
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


## Shell Armor / Battle Armor: não leva crítico (oficial).
func no_crit(f: BattleFighter) -> bool:
	return ability_of(f) in ["shell_armor", "battle_armor"]


## Sniper: o crítico dá 2,25x em vez de 1,5x (o fator extra por cima do CRIT_MULT).
func crit_bonus(user: BattleFighter) -> float:
	return 2.25 / StatCalc.CRIT_MULT if ability_of(user) == "sniper" else 1.0


## Multiplicador no fim da fórmula de dano (Blaze/Torrent/Overgrow/Swarm, Thick Fat...).
func damage_mult(user: BattleFighter, target: BattleFighter, mv: Dictionary) -> float:
	var m := _mults(user, target, mv)
	return float(m.user) * float(m.target)


# --- Alvo e imunidade ---


## Habilidade que puxa golpes de alvo único do tipo (Lightning Rod, Storm Drain) ou "".
static func _rod_for(type: String) -> String:
	match type:
		"electric":
			return "lightning_rod"
		"water":
			return "storm_drain"
	return ""


## Para-raios / Dreno no 2x2: golpe inimigo de ALVO ÚNICO do tipo mirado no parceiro vai para o
## portador (que absorve em immune()). Golpe de vários alvos (Discharge, Bubble...) não é puxado.
## BattleMoves.hit chama antes de immune(); devolve quem leva o golpe.
func redirect(user: BattleFighter, target: BattleFighter, mv: Dictionary) -> BattleFighter:
	if not is_instance_valid(user) or not is_instance_valid(target) or user.side == target.side:
		return target
	if BattleMoves.multi_target(mv) != "":
		return target
	var rod := _rod_for(String(mv.get("type", "")))
	if rod == "" or ability_of(target) == rod:
		return target
	var p := partner_of(target)
	if p != null and ability_of(p) == rod:
		return p
	return target


## true = o alvo é imune a este golpe pela habilidade (Levitate, Water Absorb, Soundproof...).
func immune(user: BattleFighter, target: BattleFighter, mv: Dictionary) -> bool:
	var type := String(mv.get("type", "normal"))
	var id := String(mv.get("id", ""))
	var cat := String(mv.get("category", ""))
	# Damp: ninguém explode enquanto ele está em campo.
	if id in EXPLODE_MOVES:
		var d := _on_field("damp")
		if d != null:
			_fire(d)
			return true
	# Prankster: o golpe de status acelerado não pega em inimigo Sombrio (Gen 7+).
	if (
		ability_of(user) == "prankster"
		and cat == "status"
		and user.side != target.side
		and "dark" in target.types
	):
		target.popup("Não afeta...", Color(0.7, 0.7, 0.7))
		return true
	if _absorbs(target, type):
		return true
	match ability_of(target):
		"wonder_skin":
			# golpe de status de inimigo: precisão cai para 50%
			var acc := float(mv.get("accuracy", 0.0))
			if cat == "status" and user.side != target.side and acc > 50.0 and _roll(0.5):
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
		"telepathy":
			# não leva golpe de dano do parceiro (Earthquake, Discharge...)
			if user.side == target.side and user != target and float(mv.get("power", 0)) > 0.0:
				_fire(target)
				return true
	return false


## Habilidades que absorvem um tipo (o golpe não causa dano).
func _absorbs(owner: BattleFighter, type: String) -> bool:
	var col := Dex.type_color(type)
	match ability_of(owner):
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
			var spore_proof: bool = (
				ta == "effect_spore" and ("grass" in user.types or ua == "overcoat")
			)
			if (
				not spore_proof
				and not BattleMoves.STATUS_IMMUNE.get(st, "-") in user.types
				and not blocks_status(user, st)
				and user.apply_status(st, target)
			):
				_fire(target)
				user.popup(
					String(BattleMoves.STATUS_WORDS.get(st, st.to_upper() + "!")),
					Color(1, 0.9, 0.6)
				)
		elif ta == "cute_charm" and ua != "oblivious" and _attracts(user, target):
			user.gcd_t += 1.2
			user.popup("Enfeitiçado!", Color(1.0, 0.55, 0.75))
			_fire(target, Color(1.0, 0.55, 0.75))
		elif ta == "rough_skin" and ua != "magic_guard":
			var chip := maxi(1, int(user.max_hp / 8.0))
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
		if (
			ta == "aftermath"
			and contact
			and user.alive()
			and ua != "magic_guard"
			and _on_field("damp") == null
		):
			_fire(target)
			user.take_damage(maxi(1, int(user.max_hp / 4.0)), Vector3.ZERO, 0.0)


## Cute Charm: 30% ao contato, só entre sexos opostos (sem sexo não se enfeitiça).
func _attracts(user: BattleFighter, target: BattleFighter) -> bool:
	var g1: String = user.mon.gender
	var g2: String = target.mon.gender
	return g1 != "" and g2 != "" and g1 != g2 and _roll(CONTACT_CHANCE)


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


## Multiplicador de precisão do usuário (Compound Eyes, Hustle, No Guard).
func acc_mult(f: BattleFighter) -> float:
	match ability_of(f):
		"compound_eyes":
			return 1.3
		"no_guard":
			return NO_GUARD_ACC
		"hustle":
			return 0.8
	return 1.0


# --- Speed: ordem da rodada, andar e preparo ---


## Multiplicador da Speed na ordem da rodada (BattleTurns.order_speed, por cima de eff_spe):
## Chlorophyll/Swift Swim/Sand Rush 2x no clima, Quick Feet 1,5x com status (e sem o corte da
## paralisia), Unburden 2x depois de usar o item.
func order_speed_mult(f: BattleFighter) -> float:
	var a := ability_of(f)
	if _weather_speed(a):
		return SPEED_DOUBLE
	match a:
		"quick_feet":
			if f.status != "":
				return 1.5 * (2.0 if f.status == "paralysis" else 1.0)
		"unburden":
			if f.item_used:
				return SPEED_DOUBLE
	return 1.0


## Prioridade extra do golpe (BattleTurns.priority_of): Prankster +1 em status, Gale Wings +1 em
## Voador com HP cheio (Gen 7+).
func priority_bonus(f: BattleFighter, mv: Dictionary) -> int:
	match ability_of(f):
		"prankster":
			if String(mv.get("category", "")) == "status":
				return 1
		"gale_wings":
			if String(mv.get("type", "")) == "flying" and f.hp >= f.max_hp:
				return 1
	return 0


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
		"unburden":
			if f.item_used:
				m *= SPEED_WALK
	if _weather_speed(a):
		m *= SPEED_WALK
	for t in arena.targets_of(f):
		var ta := ability_of(t)
		if ta == "arena_trap" and not f.is_airborne() and a != "levitate":
			m *= 0.9
		elif ta == "magnet_pull" and "steel" in f.types:
			m *= 0.9
	return m


## Speed dobrada no clima certo (Chlorophyll no sol, Swift Swim na chuva, Sand Rush na areia).
func _weather_speed(a: String) -> bool:
	var wx := weather_now()
	return (
		(a == "chlorophyll" and wx == "sun")
		or (a == "swift_swim" and wx == "rain")
		or (a == "sand_rush" and wx == "sand")
	)


## Multiplicador da velocidade de lançar o golpe (o preparo em tempo real): >1 = sai mais rápido.
## A ordem da rodada vem de order_speed_mult/priority_bonus.
func cast_speed_mult(f: BattleFighter, mv: Dictionary) -> float:
	var a := ability_of(f)
	if _weather_speed(a) or (a == "unburden" and f.item_used):
		return SPEED_WALK
	match a:
		"prankster":
			if String(mv.get("category", "")) == "status":
				return 1.5
		"gale_wings":
			if String(mv.get("type", "")) == "flying" and f.hp >= f.max_hp:
				return 1.4
		"quick_feet":
			if f.status != "":
				return 1.2
	return 1.0


## Perfil de movimento sugerido pela habilidade ("" = nenhum).
func profile_bias(f: BattleFighter) -> String:
	return String(PROFILES.get(ability_of(f), ""))


# --- Fim de rodada (o "fim de turno" do oficial) ---


## Fim de turno só das habilidades, na ordem oficial (clima; Shed Skin; Poison Heal; Speed Boost e
## o resto), pela Speed. A luta usa BattleEndTurn.run(), que chama os mesmos passos intercalados com
## status, itens e campo; este atalho serve aos testes e a quem não tem BattleEndTurn.
func on_round_end() -> void:
	var order := round_order()
	if count_weather_round():
		for f in order:
			if f.active():
				weather_residual(f)
	for f in order:
		if f.active():
			shed_skin(f)
	for f in order:
		if f.active() and ability_of(f) == "poison_heal" and f.status in ["poison", "toxic"]:
			_round_heal(f, 1.0 / 8.0)
	for f in order:
		if f.active():
			late_residual(f)
	finish_round(order)


## Lutadores ativos na ordem do fim de turno (Speed; Trick Room inverte).
func round_order() -> Array:
	return _by_speed(arena.fighters.filter(func(g): return is_instance_valid(g) and g.active()))


## Fecha o fim de turno: guarda a ordem (testes) e conta a rodada (Speed Boost olha a de entrada).
func finish_round(order: Array) -> void:
	last_round_order = order
	rounds += 1


## Passo 1 do fim de turno: conta a rodada do clima de golpe/habilidade (como o oficial, conta antes:
## no turno em que acaba não tira HP). true = o clima segue valendo e age (areia, Rain Dish...).
## weather_ended guarda o clima que acabou agora ("" se nenhum).
func count_weather_round() -> bool:
	weather_ended = ""
	if weather_rounds > 0:
		weather_rounds -= 1
		if weather_rounds == 0:
			weather_ended = weather
			weather = ""
			weather_t = 0.0
			return false
	return weather_now() != ""


## Clima no fim do turno, para um lutador: Rain Dish 1/16, Dry Skin +1/8 na chuva e -1/8 no sol,
## Solar Power -1/8, areia -1/16 em quem não é Pedra/Terra/Aço (nem Sand Veil/Rush/Force, Magic Guard,
## Overcoat). A neve (hail) da Gen 9 não tira HP.
func weather_residual(f: BattleFighter) -> void:
	var a := ability_of(f)
	var guard := a == "magic_guard"
	match weather_now():
		"rain":
			if a == "rain_dish":
				_round_heal(f, 1.0 / 16.0, "Rain Dish")
			elif a == "dry_skin":
				_round_heal(f, 1.0 / 8.0, "Dry Skin")
		"sun":
			if a in ["dry_skin", "solar_power"] and not guard:
				_weather_chip(f, 1.0 / 8.0, Color(1.0, 0.75, 0.3), "sol")
				_fire(f, Color(1.0, 0.75, 0.3))
		"sand":
			if not _sand_proof(f, a):
				_weather_chip(f, 1.0 / 16.0, Color(0.85, 0.72, 0.42), "areia")


## Passo 4 (junto do Leftovers): Shed Skin, 1/3 de curar o status. true = curou.
func shed_skin(f: BattleFighter) -> bool:
	if ability_of(f) != "shed_skin" or not f.status in Mon.PERSIST_STATUS + ["toxic", "freeze"]:
		return false
	if not _roll(1.0 / 3.0):
		return false
	f.clear_status()
	_fire(f)
	return true


## Passo final das habilidades (oficial: Speed Boost, Moody, Pickup... depois dos efeitos de campo):
## Speed Boost +1 (não no turno em que entrou); adaptados ao tempo real: Natural Cure cura em campo,
## Regenerator 1/16, Pickup 2%.
func late_residual(f: BattleFighter) -> void:
	var a := ability_of(f)
	var s := _state(f)
	match a:
		"speed_boost":
			# não na rodada em que entrou (oficial: não no turno da troca)
			if int(s.enter_round) < rounds and int(f.stages.get("spe", 0)) < 6:
				_stage_up(f, "spe", 1)
				_fire(f)
		"natural_cure":
			# oficial: cura ao sair; em campo (tempo real) cura no fim da rodada
			if f.status in Mon.PERSIST_STATUS + ["toxic", "freeze"]:
				f.clear_status()
				_fire(f, Color(0.6, 1.0, 0.7))
		"regenerator":
			# oficial: 1/3 ao sair; em campo, 1/16 por rodada
			_round_heal(f, 1.0 / 16.0)
		"pickup":
			_round_heal(f, 0.02)


func _round_heal(f: BattleFighter, pct: float, why := "") -> void:
	if f.hp < f.max_hp:
		f.residual_heal(maxi(1, int(float(f.max_hp) * pct)), why)
		_fire(f, Color(0.5, 1.0, 0.6))


func _sand_proof(f: BattleFighter, a: String) -> bool:
	if a in SANDPROOF:
		return true
	for t in f.types:
		if t in SANDPROOF_TYPES:
			return true
	return false


## Dano de clima: oficial puro (sem o ritmo de dano dos golpes).
func _weather_chip(f: BattleFighter, pct: float, col: Color, why: String) -> void:
	f.residual_damage(maxi(1, int(float(f.max_hp) * pct)), why, col)


# --- Troca ---


## Saiu de campo vivo (troca): Natural Cure cura o status, Regenerator cura 1/3 do HP (oficial).
func _switched_out(f: BattleFighter) -> void:
	match ability_of(f):
		"natural_cure":
			if f.status != "" or f.mon.status != "":
				f.clear_status()
				_fire(f, Color(0.6, 1.0, 0.7))
		"regenerator":
			var m: Mon = f.mon
			if m.hp > 0 and m.hp < m.max_hp:
				m.hp = mini(m.max_hp, m.hp + maxi(1, int(m.max_hp / 3.0)))
				f.hp = m.hp
				_fire(f, Color(0.5, 1.0, 0.6))


## Quem estava em campo e saiu vivo (arena._recall) foi trocado.
func _watch_switches() -> void:
	for id in _field.keys():
		var f = _field[id]
		if not is_instance_valid(f):
			_field.erase(id)
		elif not f.on_field:
			_field.erase(id)
			if f.hp > 0:
				_switched_out(f)
	for f in arena.fighters:
		if is_instance_valid(f) and f.active():
			_field[f.get_instance_id()] = f


# --- Por frame ---


func tick(dt: float) -> void:
	_now += dt
	_watch_switches()
	if not _pending_enter.is_empty() and arena.state == "fight":
		var keep: Array = []
		last_entry_order = []
		for f in _by_speed(_pending_enter):
			if not is_instance_valid(f) or not f.active():
				continue
			if _entry(f):
				last_entry_order.append(f)
			else:
				keep.append(f)
		_pending_enter = keep
	if weather_t > 0.0:
		weather_t -= dt
		if weather_t <= 0.0:
			weather = ""
			weather_t = 0.0
	for f in arena.fighters:
		if is_instance_valid(f) and f.active():
			_unnerve(f)
			_tick_fighter(f)


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


## Efeitos contínuos (não são de fim de turno no oficial): estágios, esquiva, Magic Guard...
func _tick_fighter(f: BattleFighter) -> void:
	var a := ability_of(f)
	if a == "":
		return
	var s := _state(f)
	_watch_stages(f, a, s)
	if f.confusion_t > 0.0 and a == "tangled_feet" and f.evasion_t <= 0.0:
		f.evasion = 0.2
		f.evasion_t = 0.5
	match a:
		"unburden":
			if f.item_used and not s.unburdened:
				s.unburdened = true
				_fire(f)
		"sand_veil":
			if f.evasion_t <= 0.0 and weather_now() == "sand":
				f.evasion = 0.2
				f.evasion_t = 0.5


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

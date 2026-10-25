class_name BattleKanto
extends RefCounted
## Mecânicas dos 57 golpes que faltavam para os 151 de Kanto (tools/gen9_new_moves.py, bloco "Kanto").
## Tudo estático: BattleMoveEffects (fx) chama daqui pelos ganchos de sempre (usable, blocks_hit,
## after_hit, self_move, ai_worth...) e passa a si mesmo, sem referência de volta (evita ciclo).
##   - estado do lutador em fx.st(f): coat (Magic Coat), perish, last_dmg/last_by/last_type (Metal Burst,
##     Conversion 2), roll_from (Steel Roller); do campo em fx.field: magic (Magic Room);
##     do lado em fx._sd(side): faint_t (Retaliate).
##   - Transform vive em battle_transform.gd; o salto, o sumiço e o teleporte em battle_physics.gd.
## Um turno do oficial = uma rodada (4 s): Perish Song, Magic Coat e Magic Room contam rodadas.

## Perish Song: rodadas até desmaiar (a do uso conta) e alcance (m) de quem ouve.
const PERISH_TURNS := 3
const PERISH_R := 7.0
const PERISH_COL := Color(0.6, 0.45, 0.8)
## Metal Burst: segundos depois de levar o golpe em que ainda dá para revidar, e o fator do oficial.
const BURST_WINDOW := 2.5
const BURST_MULT := 1.5
## Retaliate: segundos em que "um aliado desmaiou há pouco" vale (uma rodada, com folga).
const RETALIATE_WINDOW := 8.0
## Poltergeist: até onde (m) enxerga caixa ou pedra para arremessar. Steel Roller: até onde acha relevo.
const PROP_REACH := 8.0
const ROLL_REACH := 8.0
## Teleporte: sorteios de destino e folga da parede.
const TELEPORT_TRIES := 32
const TELEPORT_WALL := 1.6
const TYPES := [
	"normal",
	"fire",
	"water",
	"electric",
	"grass",
	"ice",
	"fighting",
	"poison",
	"ground",
	"flying",
	"psychic",
	"bug",
	"rock",
	"ghost",
	"dragon",
	"dark",
	"steel",
	"fairy"
]
## O chão sob o usuário: terreno de campo ou relevo da quadra -> tipo (Terrain Pulse) e golpe (Nature Power).
const GROUND_TYPE := {
	"grassy": "grass",
	"electric": "electric",
	"misty": "fairy",
	"psychic": "psychic",
	"pond": "water",
	"ice_pond": "ice",
	"high": "rock",
	"mud": "ground",
	"ice": "ice",
	"puddle": "water",
	"ember": "fire",
}
const NATURE := {
	"grassy": "energy_ball",
	"electric": "thunderbolt",
	"misty": "moonblast",
	"psychic": "psychic",
	"pond": "hydro_pump",
	"ice_pond": "ice_beam",
	"high": "rock_slide",
	"mud": "earth_power",
	"ice": "ice_beam",
	"puddle": "hydro_pump",
	"ember": "flamethrower",
}
## Habilidades ruins para quem as recebe (Entrainment só vale a pena com elas).
const BAD_ABILITIES := ["truant", "slow_start", "defeatist", "klutz", "stall"]


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# --- Gancho de usable() ---


## Motivo de o golpe não poder sair agora ("" = pode).
static func blocked(fx: BattleMoveEffects, user: BattleFighter, mv: Dictionary) -> String:
	var s := fx.st(user)
	var foe := user.opponent
	var foe_ok := is_instance_valid(foe) and foe.active()
	match String(mv.get("special", "")):
		"first_move":
			# First Impression: só como primeiro golpe da luta do usuário (o "primeiro turno" do oficial).
			if not (s.used as Dictionary).is_empty():
				return "Só como primeiro golpe!"
		"steel_roller":
			if not rollable(fx, user):
				return "Nada para aplainar!"
		"poltergeist":
			if foe_ok and not fx._has_item(foe) and nearest_prop(fx, user).is_empty():
				return "Nada para arremessar!"
		"metal_burst":
			if fx.now - float(s.hurt_t) > BURST_WINDOW or int(s.get("last_dmg", 0)) <= 0:
				return "Ninguém me acertou!"
		"dream_eater":
			if foe_ok and foe.status != "sleep":
				return "O alvo está acordado!"
	return ""


## Steel Roller tem o que aplainar: terreno de campo no ar ou um morro/pico ao alcance.
static func rollable(fx: BattleMoveEffects, user: BattleFighter) -> bool:
	for k in BattleMoveEffects.TERRAINS:
		if fx.active(fx.field, String(k)):
			return true
	var ter = fx.arena.get("terrain")
	if ter != null:
		for o in ter.obstacles:
			if o.kind != "pond" and _flat(o.pos, user.position) <= ROLL_REACH + float(o.r):
				return true
	return false


## Caixa ou pedra mais perto do usuário (Poltergeist ergue); {} se nada ao alcance.
static func nearest_prop(fx: BattleMoveEffects, user: BattleFighter) -> Dictionary:
	var fl = fx.arena.get("field")
	if fl == null:
		return {}
	var best := {}
	var bd := PROP_REACH
	for o in fl.objects:
		var d := _flat(o.pos, user.position)
		if d <= bd:
			bd = d
			best = o
	return best


# --- Gancho de on_use() ---


static func on_use(fx: BattleMoveEffects, user: BattleFighter, mv: Dictionary) -> void:
	match String(mv.get("special", "")):
		"steel_roller":
			fx.st(user)["roll_from"] = user.position
		"poltergeist":
			var foe := user.opponent
			if is_instance_valid(foe) and fx._has_item(foe):
				user.popup("Controlou %s!" % fx._item_name(foe), Dex.type_color("ghost"), 0.9)
				return
			var prop := nearest_prop(fx, user)
			if not prop.is_empty():
				user.popup(
					"Ergueu %s!" % ("a pedra" if prop.rock else "a caixa"),
					Dex.type_color("ghost"),
					0.9
				)
				fx.arena.field._break(prop)


# --- Gancho de blocks_hit() ---


## Dream Eater só em quem dorme; Magic Coat devolve o golpe de estado. true = o golpe parou aqui.
static func blocks_hit(
	fx: BattleMoveEffects, user: BattleFighter, target: BattleFighter, mv: Dictionary
) -> bool:
	if String(mv.get("special", "")) == "dream_eater" and target.status != "sleep":
		target.popup("Não afetou!", Color(0.8, 0.8, 0.8))
		fx.note_fail(user)
		return true
	var ts := fx.st(target)
	if (
		String(mv.get("category", "")) == "status"
		and float(mv.get("power", 0)) <= 0.0
		and fx.active(ts, "coat")
	):
		ts.erase("coat")
		ts.erase("coat#")
		target.popup("Rebateu!", Dex.type_color("psychic"), 1.1)
		_reflect(fx, user, target, mv)
		return true
	return false


## O golpe de estado volta contra quem usou (o alvo é quem estava com a Magic Coat).
static func _reflect(
	fx: BattleMoveEffects, user: BattleFighter, coat: BattleFighter, mv: Dictionary
) -> void:
	var m: Dictionary = fx.arena.moves._cast_copy(coat, mv)
	if String(mv.get("kind", "")) == "debuff_aoe":
		if not fx.debuff_move(coat, user, m) and mv.has("stat"):
			fx.arena.moves.change_stage(user, String(mv.stat), int(mv.get("stages", -1)), coat)
		return
	var d := coat.flat_to(user)
	fx.arena.moves.hit(coat, user, m, d.normalized() if d.length() > 0.01 else coat.facing)


## Detect leu o golpe: o próximo acerto do usuário sai crítico.
static func on_protected(fx: BattleMoveEffects, target: BattleFighter) -> void:
	var ts := fx.st(target)
	if bool(ts.get("insight", false)):
		fx.set_rounds(ts, "laser", BattleMoveEffects.LASER_TURNS)
		target.popup("Leu o golpe!", Color(1, 0.6, 0.3), 0.9, 0.8)


# --- Dano guardado (Metal Burst, Conversion 2) e Retaliate ---


## Quem levou o golpe guarda o dano, quem bateu e o tipo.
static func note_damage(
	fx: BattleMoveEffects, user: BattleFighter, target: BattleFighter, mv: Dictionary, dealt: int
) -> void:
	if user.side == target.side:
		return
	var s := fx.st(target)
	s["last_dmg"] = dealt
	s["last_by"] = user
	s["last_type"] = String(mv.get("type", ""))


static func burst_amount(fx: BattleMoveEffects, user: BattleFighter) -> int:
	return maxi(1, int(BURST_MULT * float(fx.st(user).get("last_dmg", 0))))


static func note_faint(fx: BattleMoveEffects, f: BattleFighter) -> void:
	fx._sd(f.side)["faint_t"] = fx.now


static func ally_fell(fx: BattleMoveEffects, user: BattleFighter) -> bool:
	return fx.now - float(fx._sd(user.side).get("faint_t", -99.0)) <= RETALIATE_WINDOW


## Triple Axel: qual acerto deste uso no alvo (1, 2, 3): o poder sobe 100% a cada um.
static func hit_number(mv: Dictionary, target: BattleFighter) -> float:
	var ctx = mv.get("_cast")
	if ctx is Dictionary:
		var got: Dictionary = ctx.get("landed", {})
		return float(maxi(int(got.get(target.get_instance_id(), 1)), 1))
	return 1.0


# --- Chão (Terrain Pulse, Nature Power) ---


## O que há sob o usuário: terreno de campo (grassy, electric, misty, psychic) ou relevo da quadra
## (pond, ice_pond = lago congelado, high = em cima de morro ou pico) ou chão vivo (mud, ice, puddle,
## ember = marca de golpe). "" = chão comum ou no ar.
static func ground_kind(fx: BattleMoveEffects, user: BattleFighter) -> String:
	if not fx.grounded(user):
		return ""
	for k in BattleMoveEffects.TERRAINS:
		if fx.active(fx.field, String(k)):
			return String(k)
	var ter = fx.arena.get("terrain")
	if ter != null:
		var pond: Dictionary = ter.pond_at(user.position)
		if not pond.is_empty():
			return "ice_pond" if float(pond.ice_t) > 0.0 else "pond"
		if ter.on_high(user):
			return "high"
		var g = ter.get("ground")  # chão vivo: lama e marcas de golpe (BattleGround)
		if g != null and g.on:
			for k in ["ice", "puddle", "ember"]:
				if g.on_mark(user, k):
					return k
			if g.in_mud(user):
				return "mud"
	return ""


## Tipo do Terrain Pulse agora ("" = sem terreno: normal, poder base).
static func pulse_type(fx: BattleMoveEffects, user: BattleFighter) -> String:
	return String(GROUND_TYPE.get(ground_kind(fx, user), ""))


## O golpe em que Nature Power vira.
static func nature_move(fx: BattleMoveEffects, user: BattleFighter) -> String:
	var k := ground_kind(fx, user)
	if NATURE.has(k):
		return String(NATURE[k])
	match fx.weather():
		"sand":
			return "earth_power"
		"hail":
			return "ice_beam"
	return "tri_attack"


# --- Tipos no cálculo de dano ---


## Freeze-Dry: a resistência da Água ao Gelo vira fraqueza (a Água entra como Planta só na conta).
static func freeze_types(types: Array) -> Array:
	var out: Array = types.duplicate()
	var i := out.find("water")
	if i >= 0:
		out[i] = "grass"
	return out


# --- self_buff ---


## true = resolvido aqui.
static func self_move(fx: BattleMoveEffects, user: BattleFighter, mv: Dictionary) -> bool:
	var s := fx.st(user)
	match String(mv.get("special", "")):
		"conversion":
			_conversion(fx, user)
		"conversion_2":
			_conversion_2(fx, user, s)
		"magic_coat":
			fx.set_rounds(s, "coat", 1)
			user.popup("Capa mágica!", Dex.type_color("psychic"), 1.1)
			fx._vfx("protect_shield", [user, fx.round_left()])
		"magic_room":
			_magic_room(fx, user)
		"nature_power":
			var id := nature_move(fx, user)
			user.popup(
				"Poder da natureza: %s!" % Dex.move(id).get("name", id), Color(0.6, 1.0, 0.6), 0.9
			)
			fx._call(user, id)
		"perish_song":
			_perish(fx, user)
		"teleport":
			_teleport(fx, user)
		"transform":
			if not BattleTransform.apply(fx.arena, user, user.opponent):
				fx._fail(user)
		_:
			return false
	return true


static func _set_types(user: BattleFighter, t: String) -> void:
	user.types = [t]
	user.popup("Virou %s!" % t.capitalize(), Dex.type_color(t), 1.0, 0.8)


## Conversion: vira o tipo de um dos próprios golpes (um que ainda não é o seu).
static func _conversion(fx: BattleMoveEffects, user: BattleFighter) -> void:
	var pool: Array = []
	for id in user.moves:
		var t := String(Dex.move(String(id)).get("type", ""))
		if t in TYPES and not t in pool and [t] != user.types:
			pool.append(t)
	if pool.is_empty():
		fx._fail(user)
		return
	_set_types(user, String(pool[fx.rng.randi() % pool.size()]))


## Conversion 2: vira um tipo que resiste (ou é imune) ao último golpe que acertou o usuário.
static func _conversion_2(fx: BattleMoveEffects, user: BattleFighter, s: Dictionary) -> void:
	var last := String(s.get("last_type", ""))
	var pool: Array = []
	if last != "":
		pool = TYPES.filter(
			func(t): return Dex.effectiveness(last, [t]) < 1.0 and [t] != user.types
		)
	if pool.is_empty():
		fx._fail(user)
		return
	_set_types(user, String(pool[fx.rng.randi() % pool.size()]))


## Magic Room: itens segurados sem efeito por 5 rodadas; usar de novo desliga.
static func _magic_room(fx: BattleMoveEffects, user: BattleFighter) -> void:
	var at := user.position + Vector3(0, 1.6, 0)
	if fx.active(fx.field, "magic"):
		fx.field.erase("magic")
		fx.field.erase("magic#")
		fx.arena.popup(at, "Os itens voltaram a funcionar!", Dex.type_color("psychic"))
		return
	fx.set_rounds(fx.field, "magic", BattleMoveEffects.FIELD_TURNS)
	fx.arena.popup(at, "Itens anulados!", Dex.type_color("psychic"))
	fx._vfx("gravity", [BattleMoveEffects.rounds_secs(BattleMoveEffects.FIELD_TURNS)])


## Perish Song: todos a PERISH_R m (e o usuário) ganham a contagem; desmaiam no fim da 3ª rodada
## (BattleEndTurn chama perish_tick). Soundproof não ouve.
static func _perish(fx: BattleMoveEffects, user: BattleFighter) -> void:
	var n := 0
	for f in fx.arena.fighters:
		if not is_instance_valid(f) or not f.active():
			continue
		if f != user and _flat(f.position, user.position) > PERISH_R:
			continue
		if fx._ability(f) == "soundproof":
			f.popup("Não ouve!", Color(0.8, 0.8, 0.8))
			continue
		var fs := fx.st(f)
		if fx.active(fs, "perish"):
			continue
		fx.set_rounds(fs, "perish", PERISH_TURNS)
		f.popup("Canção da morte: %d" % PERISH_TURNS, PERISH_COL, 1.0, 0.7)
		n += 1
	if n == 0:
		fx._fail(user)
		return
	fx.arena.fx_disc(user.position, PERISH_R, PERISH_COL * Color(1, 1, 1, 0.25), 0.8)


## Fim da rodada: conta a canção. true = desmaiou agora.
static func perish_tick(fx: BattleMoveEffects, f: BattleFighter) -> bool:
	var s := fx.st(f)
	if not fx.active(s, "perish"):
		return false
	if fx.count_round(s, "perish"):
		f.popup("A canção chegou ao fim!", PERISH_COL, 1.2, 0.8)
		f.take_damage(f.hp, Vector3.ZERO, 0.0)
		return true
	f.popup("Canção da morte: %d" % fx.rounds_left(s, "perish"), PERISH_COL, 1.0, 0.7)
	return false


## Teleport: some e reaparece num ponto livre da quadra, o mais longe dos inimigos que o sorteio achar;
## solta de Wrap/Bind, Mean Look e de qualquer prisão.
static func _teleport(fx: BattleMoveEffects, user: BattleFighter) -> void:
	user.trap_t = 0.0
	fx.free_bind(user)
	fx.st(user).trapped = false
	fx.arena.moves.phys.start_teleport(user, teleport_spot(fx, user))


static func teleport_spot(fx: BattleMoveEffects, user: BattleFighter) -> Vector3:
	var arena: Node = fx.arena
	var r: Rect2 = arena.rect.grow(-TELEPORT_WALL)
	var foes := fx._foes(user)
	var best := user.position
	var best_score := -INF
	for i in TELEPORT_TRIES:
		var p := Vector3(
			fx.rng.randf_range(r.position.x, r.end.x),
			0.0,
			fx.rng.randf_range(r.position.y, r.end.y)
		)
		if not _free_spot(arena, p):
			continue
		var near := INF
		for foe in foes:
			near = minf(near, _flat(foe.position, p))
		var score := (near if near < INF else 0.0) + fx.rng.randf() * 1.5
		if score > best_score:
			best_score = score
			best = p
	best.y = 0.0
	return best


static func _free_spot(arena: Node, p: Vector3) -> bool:
	var ter = arena.get("terrain")
	if ter != null and (ter.height_at(p) > 0.3 or not ter.pond_at(p).is_empty()):
		return false
	var fl = arena.get("field")
	if fl != null:
		for o in fl.objects:
			if _flat(o.pos, p) < BattleField.OBJ_R + BattleField.BODY_R + 0.4:
				return false
	return true


# --- Depois do acerto ---


static func after_hit(
	fx: BattleMoveEffects, user: BattleFighter, target: BattleFighter, mv: Dictionary, dealt: int
) -> void:
	match String(mv.get("special", "")):
		"reflect_type":
			if target.types.is_empty():
				fx._fail(user)
			else:
				user.types = target.types.duplicate()
				user.popup(
					"Virou %s!" % "/".join(user.types.map(func(t): return String(t).capitalize())),
					Dex.type_color(String(user.types[0])),
					1.0,
					0.8
				)
		"role_play":
			var ab := fx._ability(target)
			if ab == "" or ab == fx._ability(user):
				fx._fail(user)
			else:
				user.set_meta("ability_override", ab)
				user.popup(
					"Copiou %s!" % ab.capitalize().replace("_", " "), Dex.type_color("psychic")
				)
		"entrainment":
			var mine := fx._ability(user)
			if mine == "" or mine == fx._ability(target):
				fx._fail(user)
			else:
				target.set_meta("ability_override", mine)
				target.popup(
					"Ganhou %s!" % mine.capitalize().replace("_", " "), Color(0.9, 0.85, 0.7)
				)
		"split_stats":
			for k in mv.get("swap", []):
				var avg := floorf(
					(float(user.stats.get(k, 10)) + float(target.stats.get(k, 10))) / 2.0
				)
				user.stats[k] = avg
				target.stats[k] = avg
			user.popup("Dividiu os atributos!", Dex.type_color("psychic"), 0.9)
		"swap_stages":
			for k in mv.get("swap", []):
				var t := int(user.stages.get(k, 0))
				user.stages[k] = int(target.stages.get(k, 0))
				target.stages[k] = t
			user.popup("Trocou as mudanças!", Dex.type_color("psychic"), 0.9)
		"swap_stats":
			for k in mv.get("swap", []):
				var t2 = user.stats.get(k, 10)
				user.stats[k] = target.stats.get(k, 10)
				target.stats[k] = t2
			user.popup("Trocou a Velocidade!", Dex.type_color("psychic"), 0.9)
		"cure_burn":
			if target.alive() and target.status == "burn" and not fx.sheer_force(user, mv):
				target.clear_status()
				target.popup("Queimadura curada!", Color(0.6, 0.9, 1.0), 0.9)
		"steel_roller":
			if dealt > 0:
				_flatten(fx, user, target)


## Steel Roller acertou: some o terreno de campo e morros/picos por onde passou perdem 2 de vida.
static func _flatten(fx: BattleMoveEffects, user: BattleFighter, target: BattleFighter) -> void:
	fx._clear_terrain(target)
	var ter = fx.arena.get("terrain")
	if ter == null:
		return
	var from: Vector3 = fx.st(user).get("roll_from", user.position)
	for o in ter.obstacles.duplicate():
		if o.kind != "pond" and _seg_dist(o.pos, from, target.position) <= float(o.r) + 1.0:
			ter.damage(o, 2, user)


## Distância (plano) de um ponto a um segmento.
static func _seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := Vector2(b.x - a.x, b.z - a.z)
	var ap := Vector2(p.x - a.x, p.z - a.z)
	var t := (
		0.0 if ab.length_squared() < 0.0001 else clampf(ap.dot(ab) / ab.length_squared(), 0.0, 1.0)
	)
	return (ap - ab * t).length()


# --- IA ---


static func _max_eff(foe: BattleFighter, types: Array) -> float:
	var best := 0.0
	for id in foe.moves:
		var mv := Dex.move(String(id))
		if float(mv.get("power", 0)) > 0.0:
			best = maxf(best, Dex.effectiveness(String(mv.get("type", "")), types))
	return best


static func _sum(f: BattleFighter, keys: Array, stages: bool) -> float:
	var n := 0.0
	for k in keys:
		n += float(f.stages.get(k, 0)) if stages else float(f.stats.get(k, 10))
	return n


## A IA usa este golpe de estado agora? null = critério padrão.
static func ai_worth(fx: BattleMoveEffects, f: BattleFighter, mv: Dictionary) -> Variant:
	var opp := f.opponent
	var has_opp := is_instance_valid(opp) and opp.active()
	var hp := float(f.hp) / maxf(float(f.max_hp), 1.0)
	var s := fx.st(f)
	var keys: Array = mv.get("swap", [])
	match String(mv.get("special", "")):
		"conversion":
			if not has_opp or _max_eff(opp, f.types) <= 1.0:
				return false
			return f.moves.any(
				func(id):
					var t := String(Dex.move(String(id)).get("type", ""))
					return t in TYPES and [t] != f.types and _max_eff(opp, [t]) <= 1.0
			)
		"conversion_2":
			var last := String(s.get("last_type", ""))
			return last != "" and Dex.effectiveness(last, f.types) >= 1.0
		"reflect_type":
			return (
				has_opp
				and opp.types != f.types
				and _max_eff(opp, f.types) > 1.0
				and _max_eff(opp, opp.types) <= 1.0
			)
		"role_play":
			return has_opp and fx._ability(opp) != "" and fx._ability(opp) != fx._ability(f)
		"entrainment":
			return (
				has_opp and fx._ability(f) in BAD_ABILITIES and fx._ability(opp) != fx._ability(f)
			)
		"split_stats":
			return has_opp and _sum(opp, keys, false) > _sum(f, keys, false) * 1.12
		"swap_stages":
			return has_opp and _sum(opp, keys, true) - _sum(f, keys, true) >= 2.0
		"swap_stats":
			return has_opp and float(opp.stats.get("spe", 0)) > float(f.stats.get("spe", 0)) * 1.2
		"magic_coat":
			return (
				has_opp
				and not fx.active(s, "coat")
				and fx._has_cat(opp, "status")
				and fx._threatened(f)
			)
		"magic_room":
			return has_opp and not fx.active(fx.field, "magic") and fx._has_item(opp)
		"nature_power":
			return has_opp
		"perish_song":
			return has_opp and hp < 0.4 and not fx.active(s, "perish")
		"teleport":
			return (
				has_opp
				and (
					(hp < 0.5 and f.flat_to(opp).length() < 5.5)
					or f.trap_t > 0.0
					or fx.cant_escape(f)
				)
			)
		"transform":
			return (
				has_opp
				and not BattleTransform.is_transformed(f)
				and (
					_sum(opp, BattleTransform.COPY_STATS, false)
					>= _sum(f, BattleTransform.COPY_STATS, false) * 0.95
				)
			)
	return null

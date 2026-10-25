class_name BattleCombos
extends RefCounted
## Marcas de tipo, reações entre parceiros, Ressonância, golpes de dupla e a Sintonia de cada lado.
## A arena cria um por luta (arena.combos) e chama os ganchos abaixo; tudo aqui é opcional para o resto.

## Duração da marca (5 s desde 2026-10-25: com 3 s o parceiro quase nunca chegava a tempo).
const MARK_TIME := 5.0
const REACT_ICD := 2.5
const MULT_CAP := 1.5
const RESONANCE_WINDOW := 1.0
const RESONANCE_MULT := 1.25
## Janela entre os dois golpes de tipos que formam a dupla (2 s desde 2026-10-25: com 1,2 s a IA quase
## nunca fechava o par).
const DUO_WINDOW := 2.0
const DUO_CHANCE := 0.06
## Chance da dupla com a Sintonia cheia pela metade ou mais (sobe linear de DUO_CHANCE até aqui).
const DUO_CHANCE_SYNC := 0.15
## Sintonia a partir da qual a IA do par escolhe de propósito golpes que fecham reação ou dupla.
const SYNC_COORD := 0.3
const DUO_COOLDOWN := 12.0
const DUO_DELAY := 0.5
const SYNC_NEAR_WINDOW := 1.5
const SYNC_HIT := 0.1
const SYNC_REACT := 0.25
const SYNC_RESONANCE := 0.25
const SYNC_DECAY := 0.04
const SYNC_IDLE := 2.0
const CONTACT_KINDS := ["dash", "arc", "multi_arc", "whip"]
const KNOCKDOWN := 7.0
const DUO_PATH := "res://data/duo_moves.json"
const STAT_WORDS := {
	"atk": "Ataque",
	"def": "Defesa",
	"spa": "At. Esp.",
	"spd": "Def. Esp.",
	"spe": "Velocidade",
	"acc": "Precisão"
}

## Marcas: id -> nome, tipo da cor.
const MARKS := {
	"wet": {"name": "Molhado", "color": "water"},
	"burning": {"name": "Em brasa", "color": "fire"},
	"pollen": {"name": "Pólen", "color": "grass"},
	"dust": {"name": "Pó", "color": "ground"},
	"down": {"name": "Derrubado", "color": "fighting"},
	"psy": {"name": "Confuso", "color": "psychic"},
	"slow": {"name": "Lento", "color": "ice"},
}
## Tipo do golpe -> marca que ele deixa (derrubado/lento têm regra própria em _mark_for).
const TYPE_MARK := {
	"water": "wet",
	"fire": "burning",
	"grass": "pollen",
	"ground": "dust",
	"rock": "dust",
	"psychic": "psy",
	"ice": "slow",
}
## Reações: marca + tipos que reagem (ou "contact") -> multiplicador e efeitos. Uma por acerto.
const REACTIONS := [
	{
		"id": "shock",
		"mark": "wet",
		"by": ["electric"],
		"name": "Eletrocutado!",
		"color": "electric",
		"mult": 1.35,
		"status": ["paralysis", 0.4]
	},
	{
		"id": "freeze",
		"mark": "wet",
		"by": ["ice"],
		"name": "Congelou!",
		"color": "ice",
		"mult": 1.15,
		"root": 1.2,
		"slow": 4.0
	},
	{
		"id": "venom",
		"mark": "wet",
		"by": ["poison"],
		"name": "Veneno diluído!",
		"color": "poison",
		"mult": 1.25,
		"status": ["poison", 0.5]
	},
	{
		"id": "blaze_grass",
		"mark": "burning",
		"by": ["grass"],
		"name": "Incêndio!",
		"color": "fire",
		"mult": 1.2,
		"area": [40, 1.8, "fire"]
	},
	{
		"id": "blaze_wind",
		"mark": "burning",
		"by": ["flying"],
		"name": "Incêndio!",
		"color": "fire",
		"mult": 1.2,
		"area": [40, 1.8, "fire"]
	},
	{
		"id": "pollen_blast",
		"mark": "pollen",
		"by": ["fire"],
		"name": "Explosão de pólen!",
		"color": "grass",
		"mult": 1.4,
		"area": [35, 1.6, "grass"]
	},
	{
		"id": "mud",
		"mark": "dust",
		"by": ["water"],
		"name": "Lama!",
		"color": "ground",
		"mult": 1.1,
		"slow": 4.0,
		"acc": 4.0
	},
	{
		"id": "sandstorm",
		"mark": "dust",
		"by": ["flying"],
		"name": "Tempestade de areia!",
		"color": "rock",
		"mult": 1.15,
		"acc": 4.0,
		"area": [30, 2.0, "rock"]
	},
	{
		"id": "ground_combo",
		"mark": "down",
		"contact": true,
		"name": "Combo de chão!",
		"color": "fighting",
		"mult": 1.35
	},
	{
		"id": "melt",
		"mark": "slow",
		"by": ["fire"],
		"name": "Derreteu!",
		"color": "fire",
		"mult": 1.3
	},
	{
		"id": "nightmare",
		"mark": "psy",
		"by": ["ghost", "dark"],
		"name": "Pesadelo!",
		"color": "ghost",
		"mult": 1.3,
		"confuse": true
	},
]

var arena: Node
var _clock := 0.0
var _marks := {}  ## id do alvo -> {f, m: {mark_id: {t, side, by}}}
var _icd := {}  ## id do alvo -> segundos restantes
var _last_hit := {}  ## id do alvo -> {user, type, t, used}
var _user_hit := {}  ## id do atacante -> {side, t}
var _used := {}  ## id do atacante -> {user, type, t}
var _sync := [0.0, 0.0]
var _idle := [0.0, 0.0]
var _duo_cd := [0.0, 0.0]
var _duos: Array = []
var _pending := {}  ## cálculo de damage_mult reaproveitado no on_hit


func _init(a: Node) -> void:
	arena = a
	var txt := FileAccess.get_file_as_string(DUO_PATH)
	var j = JSON.parse_string(txt)
	if j is Dictionary:
		_duos = j.get("duo_moves", [])


## Avança durações das marcas, ICDs e a Sintonia. dt já escalado pela velocidade da luta.
func tick(dt: float) -> void:
	_clock += dt
	for k in _marks.keys():
		var e: Dictionary = _marks[k]
		if not is_instance_valid(e.f) or not e.f.alive():
			_marks.erase(k)
			continue
		for mid in e.m.keys():
			e.m[mid].t -= dt
			if e.m[mid].t <= 0.0:
				e.m.erase(mid)
		if e.m.is_empty():
			_marks.erase(k)
	for k in _icd.keys():
		_icd[k] -= dt
		if _icd[k] <= 0.0:
			_icd.erase(k)
	for s in 2:
		_idle[s] += dt
		_duo_cd[s] = maxf(0.0, _duo_cd[s] - dt)
		if _idle[s] > SYNC_IDLE:
			_sync[s] = maxf(0.0, _sync[s] - SYNC_DECAY * dt)


## Multiplicador aplicado no fim da fórmula de dano (1.0 = nada). Chamado antes de cada acerto com dano.
func damage_mult(user: BattleFighter, target: BattleFighter, mv: Dictionary) -> float:
	_pending = {}
	if bool(mv.get("combo", false)) or not _ok(user) or not _ok(target):
		return 1.0
	var react := _find_reaction(user, target, mv)
	var reson := _resonates(user, target, mv)
	var m := 1.0
	if not react.is_empty():
		m *= float(react.mult)
	if reson:
		m *= RESONANCE_MULT
	m = minf(m, MULT_CAP)
	_pending = {"mv": mv, "user": user, "target": target, "react": react, "reson": reson}
	return m


## Depois de um acerto (com ou sem dano): coloca marcas, detona reações do parceiro.
func on_hit(user: BattleFighter, target: BattleFighter, mv: Dictionary, _dmg: int) -> void:
	if bool(mv.get("combo", false)) or not _ok(user) or not _ok(target):
		return
	var react: Dictionary = {}
	var reson := false
	if (
		not _pending.is_empty()
		and is_same(_pending.mv, mv)
		and _pending.user == user
		and _pending.target == target
	):
		react = _pending.react
		reson = _pending.reson
	else:
		react = _find_reaction(user, target, mv)
		reson = _resonates(user, target, mv)
	_pending = {}
	var tid := target.get_instance_id()
	var side := user.side
	_note_near(user)
	if reson:
		_hit_resonance(user, target, mv)
		_add_sync(side, SYNC_RESONANCE)
	if not react.is_empty():
		_detonate(user, target, react)
		_add_sync(side, SYNC_REACT)
	_last_hit[tid] = {"user": user, "type": String(mv.get("type", "")), "t": _clock, "used": reson}
	if target.alive():
		_place_mark(user, target, mv)


## Golpe saiu (antes da entrega).
func on_move_used(user: BattleFighter, mv: Dictionary) -> void:
	if not _ok(user) or bool(mv.get("combo", false)):
		return
	if String(mv.get("category", "")) == "status":
		return
	var ty := String(mv.get("type", ""))
	_used[user.get_instance_id()] = {"user": user, "type": ty, "t": _clock}
	if _duo_cd[user.side] > 0.0:
		return
	for k in _used.keys():
		var u: Dictionary = _used[k]
		if u.user == user or not _ok(u.user) or u.user.side != user.side:
			continue
		if _clock - float(u.t) > DUO_WINDOW:
			continue
		var duo := _find_duo(String(u.type), ty)
		if duo.is_empty():
			continue
		var full: bool = _sync[user.side] >= 0.999
		var chance := lerpf(DUO_CHANCE, DUO_CHANCE_SYNC, clampf(_sync[user.side] * 2.0, 0.0, 1.0))
		if full or arena.rng.randf() < chance:
			if full:
				_sync[user.side] = 0.0
			_fire_duo(user, u.user, duo)
			return


## Para a IA do par: o golpe `mv` de `user` fecha uma dupla com o último golpe do parceiro (dentro da
## DUO_WINDOW) e a dupla está livre?
func completes_duo(user: BattleFighter, mv: Dictionary) -> bool:
	if not _ok(user) or bool(mv.get("combo", false)) or _duo_cd[user.side] > 0.0:
		return false
	if String(mv.get("category", "")) == "status" or float(mv.get("power", 0)) <= 0.0:
		return false
	var ty := String(mv.get("type", ""))
	for k in _used:
		var u: Dictionary = _used[k]
		if u.user == user or not _ok(u.user) or u.user.side != user.side:
			continue
		if _clock - float(u.t) <= DUO_WINDOW and not _find_duo(String(u.type), ty).is_empty():
			return true
	return false


## Para a IA do par: o golpe `mv` deixa uma marca que algum golpe do parceiro detona?
func sets_up_reaction(user: BattleFighter, partner: BattleFighter, mv: Dictionary) -> bool:
	var mid := _mark_for(mv)
	if mid == "" or not _ok(partner):
		return false
	for pid in partner.moves:
		var pm: Dictionary = Dex.move(String(pid))
		if float(pm.get("power", 0)) <= 0.0:
			continue
		var pt := String(pm.get("type", ""))
		for r in REACTIONS:
			if r.mark != mid:
				continue
			if (r.get("contact", false) and _is_contact(pm)) or pt in r.get("by", []):
				return true
	return false


## Sintonia do lado (0..1) para o HUD.
func sync_of(side: int) -> float:
	if side < 0 or side > 1:
		return 0.0
	return clampf(_sync[side], 0.0, 1.0)


## Marcas ativas no lutador para o HUD: [{id, name, color, t}].
func marks_of(f: BattleFighter) -> Array:
	var out: Array = []
	if not is_instance_valid(f) or not _marks.has(f.get_instance_id()):
		return out
	var m: Dictionary = _marks[f.get_instance_id()].m
	for mid in m:
		var d: Dictionary = MARKS[mid]
		out.append(
			{"id": mid, "name": d.name, "color": Dex.type_color(d.color), "t": float(m[mid].t)}
		)
	return out


# --- Marcas e reações ---


func _ok(f: Variant) -> bool:
	return is_instance_valid(f) and f.active()


func _is_contact(mv: Dictionary) -> bool:
	return (
		String(mv.get("kind", "")) in CONTACT_KINDS and String(mv.get("category", "")) == "physical"
	)


func _mark_for(mv: Dictionary) -> String:
	var ty := String(mv.get("type", ""))
	if ty in ["fighting", "normal"]:
		return "down" if float(mv.get("knockback", 0.0)) >= KNOCKDOWN else ""
	if ty == "bug":
		var id := String(mv.get("id", ""))
		return "slow" if "web" in id or "string" in id else ""
	return String(TYPE_MARK.get(ty, ""))


func _place_mark(user: BattleFighter, target: BattleFighter, mv: Dictionary) -> void:
	var mid := _mark_for(mv)
	if mid == "":
		return
	var tid := target.get_instance_id()
	if not _marks.has(tid):
		_marks[tid] = {"f": target, "m": {}}
	var fresh: bool = not _marks[tid].m.has(mid)
	_marks[tid].m[mid] = {"t": MARK_TIME, "side": user.side, "by": user.get_instance_id()}
	if fresh:
		var d: Dictionary = MARKS[mid]
		target.popup(String(d.name), Dex.type_color(d.color), 0.7, 0.55, "status")


## Primeira reação da tabela que casa com uma marca do parceiro e o golpe.
func _find_reaction(user: BattleFighter, target: BattleFighter, mv: Dictionary) -> Dictionary:
	var tid := target.get_instance_id()
	if not _marks.has(tid) or _icd.has(tid):
		return {}
	var ty := String(mv.get("type", ""))
	var m: Dictionary = _marks[tid].m
	for r in REACTIONS:
		if not m.has(r.mark):
			continue
		var mk: Dictionary = m[r.mark]
		if int(mk.side) != user.side or int(mk.by) == user.get_instance_id():
			continue
		if r.get("contact", false):
			if _is_contact(mv):
				return r
		elif ty in r.by:
			return r
	return {}


func _detonate(user: BattleFighter, target: BattleFighter, r: Dictionary) -> void:
	var tel = arena.get("telemetry")
	if tel:
		tel.note(
			"combo",
			{
				"who": tel.uid(user),
				"tgt": tel.uid(target),
				"r": String(r.get("name", r.get("id", "")))
			}
		)
	var tid := target.get_instance_id()
	_icd[tid] = REACT_ICD
	if _marks.has(tid):
		_marks[tid].m.erase(r.mark)
	var col := Dex.type_color(String(r.color))
	_notify(String(r.name), col)
	arena.fx_disc(target.pos2(target.position), 1.2, col * Color(1, 1, 1, 0.6), 0.35)
	_pixel_burst(target, String(r.color), 2.0 if not r.has("area") else float(r.area[1]) * 1.6)
	if String(r.id) == "freeze":
		_pixel_burst_key(target, "snow", 1.2, 0.6)
	if r.has("status") and target.alive():
		if arena.rng.randf() < float(r.status[1]):
			_status(user, target, String(r.status[0]))
	if r.get("confuse", false) and target.alive():
		_status(user, target, "confusion")
	if r.has("root") and target.alive():
		target.root_t = maxf(target.root_t, float(r.root))
	if r.has("slow") and target.alive():
		_temp_stage(target, "spe", -1, float(r.slow))
	if r.has("acc") and target.alive():
		_temp_stage(target, "acc", -1, float(r.acc))
	if r.has("area"):
		var a: Array = r.area
		_area_hit(user, target, float(a[0]), float(a[1]), String(a[2]), false)


## Estouro de pixel art no alvo, pela cor/tipo (Sprite3D animado; sem arte nada acontece).
func _pixel_burst(target: BattleFighter, type: String, size: float) -> void:
	_pixel_burst_key(target, PixelFx.key_for_type(type), size, 0.5)


func _pixel_burst_key(target: BattleFighter, key: String, size: float, life: float) -> void:
	var at := target.pos2(target.position)
	PixelFx.pop(arena, key, Vector3(at.x, maxf(target.look_h, 0.8) * 0.6, at.z), size, life)


func _resonates(user: BattleFighter, target: BattleFighter, mv: Dictionary) -> bool:
	var rec = _last_hit.get(target.get_instance_id())
	if rec == null or bool(rec.used):
		return false
	return (
		is_instance_valid(rec.user)
		and rec.user != user
		and rec.user.side == user.side
		and String(rec.type) == String(mv.get("type", ""))
		and _clock - float(rec.t) <= RESONANCE_WINDOW
	)


func _hit_resonance(_user: BattleFighter, _target: BattleFighter, mv: Dictionary) -> void:
	var col := Dex.type_color(String(mv.get("type", "normal")))
	_notify("Ressonância!", col)


## Acertos dos dois parceiros próximos no tempo enchem a Sintonia.
func _note_near(user: BattleFighter) -> void:
	_user_hit[user.get_instance_id()] = {"side": user.side, "t": _clock}
	for k in _user_hit:
		if k == user.get_instance_id():
			continue
		var u: Dictionary = _user_hit[k]
		if int(u.side) == user.side and _clock - float(u.t) <= SYNC_NEAR_WINDOW:
			_add_sync(user.side, SYNC_HIT)
			return
	_idle[user.side] = 0.0


func _add_sync(side: int, v: float) -> void:
	_sync[side] = clampf(_sync[side] + v, 0.0, 1.0)
	_idle[side] = 0.0


# --- Efeitos ---


## Reações, Ressonância e combos de dupla avisam embaixo da arena (BattleHUD.warn), nunca sobre o Pokémon.
func _notify(text: String, col: Color) -> void:
	if arena.hud and arena.hud.has_method("warn"):
		arena.hud.warn(text, col)


func _status(user: BattleFighter, target: BattleFighter, st: String) -> void:
	var mvs = arena.moves
	if mvs.STATUS_IMMUNE.get(st, "-") in target.types:
		return
	if arena.abilities and arena.abilities.blocks_status(target, st):
		return
	if target.apply_status(st, user):
		target.popup(
			String(mvs.STATUS_WORDS.get(st, st.to_upper() + "!")),
			Color(1, 0.9, 0.6),
			1.0,
			0.15,
			"status"
		)


## Estágio temporário sem popup de estágio (volta sozinho).
func _temp_stage(f: BattleFighter, key: String, delta: int, dur: float) -> void:
	var cur := int(f.stages.get(key, 0))
	var nv := clampi(cur + delta, -6, 6)
	if nv == cur:
		return
	f.stages[key] = nv
	var applied := nv - cur
	arena.later(
		dur,
		func() -> void:
			if is_instance_valid(f):
				f.stages[key] = clampi(int(f.stages.get(key, 0)) - applied, -6, 6)
	)


## Golpe sintético de área; combo = true não marca nem reage.
func _synth(id: String, name: String, ty: String, power: float, radius: float) -> Dictionary:
	return {
		"id": id,
		"name": name,
		"type": ty,
		"category": "special",
		"kind": "aoe_target",
		"power": power,
		"radius": radius,
		"knockback": 5.0,
		"combo": true
	}


## Dano em área ao redor do alvo (inimigos de user dentro do raio).
func _area_hit(
	user: BattleFighter,
	center: BattleFighter,
	power: float,
	radius: float,
	ty: String,
	include_center: bool,
	extra := {}
) -> void:
	var at := center.pos2(center.position)
	var mv := _synth("combo_area", "Combo", ty, power, radius)
	mv.merge(extra, true)
	arena.fx_disc(at, radius, Dex.type_color(ty) * Color(1, 1, 1, 0.45), 0.3)
	arena.later(
		0.05,
		func() -> void:
			if not is_instance_valid(user):
				return
			for t in arena.targets_of(user):
				if t == center and not include_center:
					continue
				var to: Vector3 = t.pos2(t.position) - at
				if to.length() <= radius:
					arena.moves.hit(
						user, t, mv, to.normalized() if to.length() > 0.05 else Vector3.RIGHT
					)
	)


# --- Golpes de dupla ---


func _find_duo(a: String, b: String) -> Dictionary:
	var any_match := {}
	for d in _duos:
		var t: Array = d.types
		if t[1] == "any":
			if a != b and (a == t[0] or b == t[0]):
				any_match = d
		elif (a == t[0] and b == t[1]) or (a == t[1] and b == t[0]):
			return d
	return any_match


func _fire_duo(u1: BattleFighter, u2: BattleFighter, duo: Dictionary) -> void:
	var tel = arena.get("telemetry")
	if tel:
		tel.note("duo", {"a": tel.uid(u1), "b": tel.uid(u2), "id": String(duo.get("id", ""))})
	var foes: Array = arena.targets_of(u1)
	if foes.is_empty():
		return
	foes.sort_custom(
		func(a: BattleFighter, b: BattleFighter) -> bool:
			return u1.flat_to(a).length() < u1.flat_to(b).length()
	)
	var target: BattleFighter = foes[0]
	var col := Dex.type_color(String(duo.type))
	_duo_cd[u1.side] = DUO_COOLDOWN
	_used.clear()
	_add_sync(u1.side, 0.0)
	_notify("COMBO! %s" % String(duo.name), col)
	var mid_at := (u1.pos2(u1.position) + u2.pos2(u2.position)) * 0.5
	arena.popup(mid_at + Vector3(0, 2.2, 0), String(duo.name).to_upper() + "!", col, 2.2, "super")
	arena.fx_disc(u1.pos2(u1.position), 1.2, col * Color(1, 1, 1, 0.5), 0.5)
	arena.fx_disc(u2.pos2(u2.position), 1.2, col * Color(1, 1, 1, 0.5), 0.5)
	_pixel_burst_key(u1, "sparkle", 1.4, 0.5)
	_pixel_burst_key(u2, "sparkle", 1.4, 0.5)
	arena.later(DUO_DELAY, func() -> void: _duo_effect(u1, u2, target, duo))


func _duo_effect(
	u1: BattleFighter, u2: BattleFighter, target: BattleFighter, duo: Dictionary
) -> void:
	if not is_instance_valid(u1) or not is_instance_valid(target) or not target.active():
		return
	var ty := String(duo.type)
	var radius := float(duo.radius)
	var at := target.pos2(target.position)
	var extra := {}
	_pixel_burst(target, ty, clampf(radius * 2.2, 2.0, 5.0))
	_duo_vis(at, duo)
	if duo.has("status"):
		extra.effect = {"status": duo.status.id, "chance": float(duo.status.chance)}
	match String(duo.effect):
		"field":
			_run_field(u1, at, duo, extra, int(ceil(float(duo.duration) / float(duo.tick))))
			arena.fx_disc(
				at, radius, Dex.type_color(ty) * Color(1, 1, 1, 0.35), float(duo.duration)
			)
		"buff_team":
			for f in [u1, u2]:
				if _ok(f):
					_temp_stage(f, String(duo.stat), int(duo.stages), float(duo.dur))
					f.popup(
						"%s do time!" % String(STAT_WORDS.get(String(duo.stat), "Status")),
						Dex.type_color(ty),
						1.0,
						0.5,
						"stat_up"
					)
					if duo.has("heal"):
						f.heal(f.paced(maxi(1, int(float(f.max_hp) * float(duo.heal)))))
			_area_hit(u1, target, float(duo.power), radius, ty, true, extra)
		"debuff_foes":
			for t in arena.targets_of(u1):
				if (t.pos2(t.position) - at).length() <= radius:
					_temp_stage(t, String(duo.stat), int(duo.stages), float(duo.dur))
					if duo.has("root"):
						t.root_t = maxf(t.root_t, float(duo.root))
			_area_hit(u1, target, float(duo.power), radius, ty, true, extra)
		_:
			if duo.has("root"):
				for t in arena.targets_of(u1):
					if (t.pos2(t.position) - at).length() <= radius:
						t.root_t = maxf(t.root_t, float(duo.root))
			_area_hit(u1, target, float(duo.power), radius, ty, true, extra)


func _run_field(
	user: BattleFighter, at: Vector3, duo: Dictionary, extra: Dictionary, left: int
) -> void:
	if left <= 0 or not is_instance_valid(user):
		return
	var mv := _synth(
		"combo_field", String(duo.name), String(duo.type), float(duo.power), float(duo.radius)
	)
	mv.merge(extra, true)
	if left < int(ceil(float(duo.duration) / float(duo.tick))):
		PixelFx.pop(
			arena,
			PixelFx.key_for_type(String(duo.type)),
			Vector3(at.x, 0.6, at.z),
			float(duo.radius) * 1.4,
			0.4
		)
	for t in arena.targets_of(user):
		if (t.pos2(t.position) - at).length() <= float(duo.radius):
			arena.moves.hit(user, t, mv, Vector3.ZERO)
			if duo.has("slow") and t.alive():
				_temp_stage(t, "spe", -1, float(duo.tick) + 0.3)
	arena.later(float(duo.tick), func() -> void: _run_field(user, at, duo, extra, left - 1))


## Desenho do golpe de dupla com os PixelFx do tipo (sem arte nada acontece): ring = anel de estouros
## na borda, pillar = coluna subindo, rain = chuva caindo do alto, bolts = raios espalhados,
## spiral = espiral subindo, sparkle = faíscas em volta. Cada estouro entra com um atraso curto.
func _duo_vis(at: Vector3, duo: Dictionary) -> void:
	if bool(arena.opts.get("fast_sim", false)):
		return
	var ty := String(duo.type)
	var key := PixelFx.key_for_type(ty)
	var r := float(duo.radius)
	var style := String(duo.get("vis", "ring"))
	if style == "bolts":
		key = "electric" if ty in ["electric", "ground", "steel"] else key
	for i in 8:
		var a := TAU * float(i) / 8.0
		var pos := at
		var delay := 0.05 * float(i)
		var size := r * 0.9
		match style:
			"ring":
				pos += Vector3(cos(a), 0.4, sin(a)) * r * 0.8
			"pillar":
				pos += Vector3(0, 0.3 + 0.45 * float(i), 0)
				delay = 0.04 * float(i)
				size = r * 0.8
			"rain":
				pos += Vector3(cos(a * 2.3) * r * 0.7, 3.2, sin(a * 3.1) * r * 0.7)
				pos.y = 3.2 - 0.4 * float(i % 4)
				size = r * 0.6
			"bolts":
				pos += Vector3(
					cos(a * 1.7) * r * 0.8, 0.9 + 0.4 * float(i % 3), sin(a * 2.9) * r * 0.8
				)
				delay = 0.07 * float(i)
			"spiral":
				pos += (
					Vector3(cos(a), 0.3 + 0.35 * float(i), sin(a)) * Vector3(r * 0.7, 1.0, r * 0.7)
				)
				delay = 0.05 * float(i)
			_:
				pos += Vector3(cos(a), 0.8, sin(a)) * r
				size = r * 0.5
		arena.later(delay + 0.01, func() -> void: PixelFx.pop(arena, key, pos, size, 0.5))
	arena.fx_disc(at, r, Dex.type_color(ty) * Color(1, 1, 1, 0.3), 0.6)

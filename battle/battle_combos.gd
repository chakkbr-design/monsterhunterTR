class_name BattleCombos
extends RefCounted
## Golpes de dupla e a Sintonia de cada lado. A arena cria um por luta (arena.combos) e chama os
## ganchos abaixo; tudo aqui é opcional para o resto. Sem marcas de tipo, reações nem Ressonância
## (Caio, 2026-10-26: não são mecânicas oficiais); o nome da dupla sai no balão normal de golpe.

## Janela entre os dois golpes de tipos que formam a dupla (2 s desde 2026-10-25: com 1,2 s a IA quase
## nunca fechava o par).
const DUO_WINDOW := 2.0
const DUO_CHANCE := 0.06
## Chance da dupla com a Sintonia cheia pela metade ou mais (sobe linear de DUO_CHANCE até aqui).
const DUO_CHANCE_SYNC := 0.15
## Sintonia a partir da qual a IA do par escolhe de propósito golpes que fecham a dupla.
const SYNC_COORD := 0.3
const DUO_COOLDOWN := 12.0
const DUO_DELAY := 0.5
const SYNC_NEAR_WINDOW := 1.5
const SYNC_HIT := 0.1
const SYNC_DECAY := 0.04
const SYNC_IDLE := 2.0
const DUO_PATH := "res://data/duo_moves.json"
const STAT_WORDS := {
	"atk": "Attack",
	"def": "Defense",
	"spa": "Sp. Atk",
	"spd": "Sp. Def",
	"spe": "Speed",
	"acc": "Accuracy"
}

var arena: Node
var _clock := 0.0
var _user_hit := {}  ## id do atacante -> {side, t}
var _used := {}  ## id do atacante -> {user, type, t}
var _sync := [0.0, 0.0]
var _idle := [0.0, 0.0]
var _duo_cd := [0.0, 0.0]
var _duos: Array = []


func _init(a: Node) -> void:
	arena = a
	var txt := FileAccess.get_file_as_string(DUO_PATH)
	var j = JSON.parse_string(txt)
	if j is Dictionary:
		_duos = j.get("duo_moves", [])


## Avança a Sintonia e o intervalo das duplas. dt já escalado pela velocidade da luta.
func tick(dt: float) -> void:
	_clock += dt
	for s in 2:
		_idle[s] += dt
		_duo_cd[s] = maxf(0.0, _duo_cd[s] - dt)
		if _idle[s] > SYNC_IDLE:
			_sync[s] = maxf(0.0, _sync[s] - SYNC_DECAY * dt)


## Depois de um acerto (com ou sem dano): enche a Sintonia (golpes de dupla).
func on_hit(user: BattleFighter, target: BattleFighter, mv: Dictionary, _dmg: int) -> void:
	if bool(mv.get("combo", false)) or not _ok(user) or not _ok(target):
		return
	_note_near(user)


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


## Sintonia do lado (0..1) para o HUD.
func sync_of(side: int) -> float:
	if side < 0 or side > 1:
		return 0.0
	return clampf(_sync[side], 0.0, 1.0)


func _ok(f: Variant) -> bool:
	return is_instance_valid(f) and f.active()


## Estouro de pixel art no alvo, pela cor/tipo (Sprite3D animado; sem arte nada acontece).
func _pixel_burst(target: BattleFighter, type: String, size: float) -> void:
	if _fx3d():
		var fx: MoveFx3D = arena.vfx.fx3d
		fx.scope([target])
		var c := fx.center(target, 0.5)
		fx.element(type, c, int(10 + size * 6.0), {"k": clampf(size * 0.5, 0.6, 1.8)})
		fx.flash(c, size * 0.6, Fx3DKit.core(type), 0.14)
		fx.light(c, Fx3DKit.lightc(type), 3.0, size * 2.0 + 2.0, 0.3)
		return
	_pixel_burst_key(target, PixelFx.key_for_type(type), size, 0.5)


## Golpes e combos usam os efeitos 3D (gfx/fx3d) quando há efeitos.
func _fx3d() -> bool:
	return arena.vfx != null and arena.vfx.use3d()


func _pixel_burst_key(target: BattleFighter, key: String, size: float, life: float) -> void:
	if _fx3d():
		var t3 := {"snow": "ice", "sparkle": "fairy"}.get(key, "normal") as String
		arena.vfx.fx3d.element(
			t3, arena.vfx.fx3d.center(target, 0.5), int(8 + size * 6.0), {"k": 0.9}
		)
		return
	var at := target.pos2(target.position)
	PixelFx.pop(arena, key, Vector3(at.x, maxf(target.look_h, 0.8) * 0.6, at.z), size, life)


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
	if _fx3d():
		arena.vfx.fx3d.scope([])
		arena.vfx.fx3d.burst_area(mv, arena.vfx.fx3d.gpos(at), radius, 0.9)
	else:
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
	# O nome da dupla sai no balão de golpe de quem fechou, como um golpe normal.
	arena.say("%s and %s: %s!" % [u1.mon.display_name, u2.mon.display_name, String(duo.name)])
	if arena.hud and arena.hud.has_method("callout"):
		arena.hud.callout(u1, String(duo.name), col)
	if _fx3d():
		for u in [u1, u2]:
			arena.vfx.fx3d.scope([u])
			arena.vfx.fx3d.charge(u, {"type": String(duo.type), "power": 90}, DUO_DELAY, 1.1)
	else:
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
			if _fx3d():
				arena.vfx.fx3d.scope([])
				arena.vfx.fx3d.vortex(
					{"type": ty, "power": float(duo.power)},
					arena.vfx.fx3d.gpos(at),
					radius,
					float(duo.duration)
				)
			else:
				arena.fx_disc(
					at, radius, Dex.type_color(ty) * Color(1, 1, 1, 0.35), float(duo.duration)
				)
		"buff_team":
			for f in [u1, u2]:
				if _ok(f):
					_temp_stage(f, String(duo.stat), int(duo.stages), float(duo.dur))
					f.popup(
						"Team %s!" % String(STAT_WORDS.get(String(duo.stat), "Status")),
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
	if left < int(ceil(float(duo.duration) / float(duo.tick))) and not _fx3d():
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
	if _fx3d():
		_duo_vis3d(at, duo)
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


## Golpe de dupla em 3D (mesmos estilos do _duo_vis): ring, pillar, rain, bolts, spiral, sparkle.
func _duo_vis3d(at_local: Vector3, duo: Dictionary) -> void:
	var fx: MoveFx3D = arena.vfx.fx3d
	fx.scope([])
	var ty := String(duo.type)
	var r := float(duo.radius)
	var mv := {"type": ty, "power": maxf(float(duo.get("power", 90)), 90.0), "category": "special"}
	var at := fx.gpos(at_local)
	at.y = fx.floor_y()
	match String(duo.get("vis", "ring")):
		"pillar":
			fx.tube(
				at, Vector3.UP, 5.0, r * 0.45, Fx3DKit.mid(ty, 0.9), 0.7, {"noise": 0.8, "l0": 0.1}
			)
			fx.tube(at, Vector3.UP, 5.0, r * 0.2, Fx3DKit.core(ty), 0.6, {"noise": 0.4, "l0": 0.1})
			fx.element(
				ty,
				at + Vector3(0, 0.5, 0),
				40,
				{"dir": Vector3.UP, "spread": 0.3, "speed": [4.0, 9.0], "k": 1.3, "r": r * 0.4}
			)
		"rain":
			for i in 14:
				var q := (
					at
					+ (
						Vector3(randf_range(-r, r), 5.0 + randf() * 2.0, randf_range(-r, r))
						* Vector3(0.8, 1, 0.8)
					)
				)
				fx.later(
					randf() * 0.4,
					func() -> void:
						fx.burst(
							q,
							{
								"n": 6,
								"shape": Fx3D.Shape.SPARK,
								"stretch": 0.06,
								"speed": [8.0, 11.0],
								"life": [0.5, 0.6],
								"size": [0.2, 0.12],
								"col": [Fx3DKit.core(ty), Fx3DKit.mid(ty, 0.6)],
								"dir": Vector3.DOWN,
								"spread": 0.05,
								"floor": true
							}
						)
				)
			fx.later(0.5, fx.burst_area.bind(mv, at, r, 1.0))
		"bolts":
			for i in 6:
				var q2 := at + Vector3(randf_range(-r, r) * 0.8, 0, randf_range(-r, r) * 0.8)
				fx.later(
					0.07 * i,
					func() -> void:
						fx.bolt(
							q2 + Vector3(0, 6, 0),
							q2,
							Fx3DKit.mid(
								"electric" if ty in ["electric", "ground", "steel"] else ty
							),
							0.06,
							0.25,
							{"branches": 1}
						)
						fx.element(
							ty, q2 + Vector3(0, 0.2, 0), 10, {"dir": Vector3.UP, "spread": 1.0}
						)
				)
		"spiral":
			fx.vortex(mv, at, r, 0.9, 1.3)
		_:
			fx.burst_area(mv, at, r, 1.2)
			for i in 8:
				var a := TAU * float(i) / 8.0
				var q3 := at + Vector3(cos(a), 0.3, sin(a)) * r * 0.8
				fx.later(
					0.04 * i,
					func() -> void:
						fx.element(ty, q3, 10, {"dir": Vector3.UP, "spread": 0.6, "k": 1.1})
				)
	fx.light(at + Vector3(0, 1.5, 0), Fx3DKit.lightc(ty), 8.0, r * 3.0 + 3.0, 0.8, {"attack": 0.1})
	fx.shake(0.12, 0.4)

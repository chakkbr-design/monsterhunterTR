class_name MoveFx3DSig
extends RefCounted
## Receitas próprias dos golpes marcantes (inspiradas nas animações oficiais). Cada fase devolve
## true quando cuidou do efeito; false deixa a receita genérica de MoveFx3D (kind + tipo + força).

var fx: MoveFx3D


func _init(f: MoveFx3D) -> void:
	fx = f


static func _id(mv: Dictionary) -> String:
	return String(mv.get("id", ""))


func prepare(user: BattleFighter, mv: Dictionary, secs: float) -> bool:
	match _id(mv):
		"solar_beam", "solar_blade":
			sunlight(user, mv, secs)
			return false  # a carga genérica também roda
	return false


func cast(user: BattleFighter, mv: Dictionary, gd: Vector3) -> bool:
	match _id(mv):
		"solar_beam":
			fx.charge(user, mv, float(mv.get("windup", 1.1)), 1.5)
			sunlight(user, mv, float(mv.get("windup", 1.1)))
			return true
	return false


# --- Projéteis ---


func projectile(p: Node3D, mv: Dictionary, gd: Vector3) -> bool:
	var id := _id(mv)
	var type := String(mv.get("type", ""))
	if type == "electric" and String(mv.get("category", "")) == "special" and id != "electro_ball":
		elec_arc(p, mv)
		return true
	match id:
		"aura_sphere", "focus_blast":
			var col := Color(0.35, 0.65, 1.0) if id == "aura_sphere" else Color(1.0, 0.6, 0.25)
			fx.shell(
				p.global_position,
				0.25,
				0.3,
				col,
				6.0,
				{"follow": p, "noise": 0.7, "phase": 8.0, "fade_out": 0.02}
			)
			fx._die_with(
				fx.shell(
					p.global_position, 0.12, 0.14, Color.WHITE, 6.0, {"follow": p, "fade_out": 0.02}
				),
				p
			)
			fx.emitter(
				Vector3.ZERO,
				6.0,
				60.0,
				{
					"shape": Fx3D.Shape.EMBER,
					"life": [0.2, 0.35],
					"size": [0.3, 0.05],
					"col":
					[
						Color(0.8, 0.95, 1.0) if id == "aura_sphere" else Color(1, 0.9, 0.6),
						Color(col, 0.0)
					],
					"speed": [0.2, 0.8],
					"turb": 8.0
				},
				func():
					return (
						p.global_position
						if is_instance_valid(p) and p.is_inside_tree() and not p.get("done")
						else null
					)
			)
			var l := fx.light(p.global_position, col, 3.0, 4.0, 6.0, {"follow": p, "hold": 0.95})
			fx._die_with(l, p)
			return true
		"fire_blast":
			fireball(p, mv, 1.5)
			return true
		"flame_charge", "ember", "flame_burst", "mystical_fire", "heat_crash":
			fireball(p, mv, 0.7 if id == "ember" else 1.0)
			return true
		"air_slash", "air_cutter", "razor_wind":
			wind_blade(p, mv)
			return true
		"razor_leaf", "magical_leaf", "leafage":
			for i in 3:
				var m := fx.solid(
					p.global_position,
					{
						"kind": "leaf",
						"col": Color(0.45, 0.9, 0.35),
						"emit": 0.5,
						"size": 0.32,
						"life": 6.0,
						"spin": 20.0,
						"floor": false,
						"follow": p,
						"off": MoveFx3D.rand_dir() * 0.12
					}
				)
				fx._die_with(m, p)
			var tr := fx.trail_opts("grass", 0.9)
			tr.follow = p
			fx.emitter(
				Vector3.ZERO,
				6.0,
				20.0,
				tr,
				func():
					return (
						p.global_position
						if is_instance_valid(p) and p.is_inside_tree() and not p.get("done")
						else null
					)
			)
			return true
	return false


## Thunderbolt e cia.: um raio liga o usuário à cabeça do projétil enquanto ele voa, e fica um
## instante depois do acerto (como o arco da animação oficial).
func elec_arc(p: Node3D, mv: Dictionary) -> void:
	var t := Fx3DKit.tier(mv)
	var user: BattleFighter = p.get("user")
	var w: float = [0.03, 0.03, 0.045, 0.065, 0.09][t]
	var col := Fx3DKit.mid("electric")
	var last := {"pos": p.global_position}
	var head := func() -> Vector3:
		if is_instance_valid(p) and p.is_inside_tree() and not p.get("done"):
			last.pos = p.global_position
		return last.pos
	var tail := func() -> Vector3:
		return (
			fx.center(user, 0.5) if is_instance_valid(user) and user.is_inside_tree() else last.pos
		)
	var rbs := fx.bolt(
		tail.call(),
		head.call(),
		col,
		w,
		6.0,
		{
			"a_fn": tail,
			"b_fn": head,
			"every": 0.035,
			"segs": 10,
			"amp": 0.18 + 0.05 * t,
			"fade_out": 0.02,
			"boost": 3.2
		}
	)
	if t >= 3:
		rbs.append_array(
			fx.bolt(
				tail.call(),
				head.call(),
				Fx3DKit.accent("electric", 0.8),
				w * 0.5,
				6.0,
				{
					"a_fn": tail,
					"b_fn": head,
					"every": 0.05,
					"segs": 8,
					"amp": 0.35,
					"core": false,
					"fade_out": 0.02
				}
			)
		)
	# Cabeça brilhando com faíscas.
	fx.emitter(
		Vector3.ZERO,
		6.0,
		40.0 + 10.0 * t,
		{
			"shape": Fx3D.Shape.SPARK,
			"stretch": 0.03,
			"life": [0.08, 0.18],
			"size": [0.09, 0.03],
			"col": [Color.WHITE, Color(col, 0.0)],
			"speed": [2.0, 5.0],
			"drag": 3.0,
			"boost": 3.0
		},
		func():
			return (
				p.global_position
				if is_instance_valid(p) and p.is_inside_tree() and not p.get("done")
				else null
			)
	)
	fx.emitter(
		Vector3.ZERO,
		6.0,
		40.0,
		{
			"shape": Fx3D.Shape.GLOW,
			"life": [0.06, 0.1],
			"size": [0.5 + 0.1 * t, 0.4],
			"col": [Fx3DKit.core("electric", 0.9), Color(col, 0.3)],
			"speed": [0, 0],
			"fade_in": 0.0,
			"boost": 3.0
		},
		func():
			return (
				p.global_position
				if is_instance_valid(p) and p.is_inside_tree() and not p.get("done")
				else null
			)
	)
	var l := fx.light(
		p.global_position,
		Fx3DKit.lightc("electric"),
		2.0 + t,
		3.0 + t,
		6.0,
		{"follow": p, "hold": 0.95, "flicker": 0.4}
	)
	fx._die_with(l, p)
	# Quando o projétil acaba, o arco fica 0,15 s e some.
	fx.repeat(
		0.03,
		6.0,
		func(_i: int) -> bool:
			if is_instance_valid(p) and p.is_inside_tree() and not p.get("done"):
				return true
			for r in rbs:
				if is_instance_valid(r):
					var rb := r as Fx3DRibbon
					rb.life = minf(rb.life, rb.age + 0.15)
					rb.fade_out = 0.9
			return false
	)


## Bola de fogo com rabo de chamas e fumaça (Fire Blast: maior e com estrela de fogo no acerto).
func fireball(p: Node3D, mv: Dictionary, k: float) -> void:
	var live := func():
		return (
			p.global_position
			if is_instance_valid(p) and p.is_inside_tree() and not p.get("done")
			else null
		)
	var core := fx.shell(
		p.global_position,
		0.2 * k,
		0.24 * k,
		Fx3DKit.mid("fire"),
		6.0,
		{"follow": p, "noise": 0.8, "phase": 9.0, "fade_out": 0.02}
	)
	fx._die_with(core, p)
	fx.emitter(
		Vector3.ZERO,
		6.0,
		60.0 * k,
		{
			"follow": p,
			"carry": 0.6,
			"shape": Fx3D.Shape.EMBER,
			"life": [0.2, 0.45],
			"size": [0.45 * k, 0.08 * k],
			"col": [Fx3DKit.core("fire"), Fx3DKit.deep("fire", 0.0)],
			"speed": [0.2, 0.9],
			"turb": 8.0,
			"up": 0.6
		},
		live
	)
	fx.emitter(
		Vector3.ZERO,
		6.0,
		14.0 * k,
		{
			"shape": Fx3D.Shape.SMOKE,
			"add": false,
			"life": [0.5, 0.9],
			"size": [0.25 * k, 0.8 * k],
			"col": [Color(0.2, 0.17, 0.15, 0.5), Color(0.1, 0.1, 0.1, 0.0)],
			"speed": [0.1, 0.4],
			"up": 0.9,
			"drag": 1.0
		},
		live
	)
	var l := fx.light(
		p.global_position,
		Fx3DKit.lightc("fire"),
		2.5 * k + 1.0,
		3.5 + k,
		6.0,
		{"follow": p, "hold": 0.95, "flicker": 0.25}
	)
	fx._die_with(l, p)


## Lâmina de ar: meia-lua branca girando que viaja com o projétil.
func wind_blade(p: Node3D, mv: Dictionary) -> void:
	var rb := Fx3DRibbon.make(
		Fx3D.mesh_mat(Fx3D.Mode.RIBBON, 2.2, 0.0, 0.6),
		Color(0.9, 0.97, 1.0, 0.9),
		0.14,
		6.0,
		fx.cam()
	)
	rb.fade_in = 0.0
	rb.fade_out = 0.02
	rb.shape = func(r: Fx3DRibbon, _k: float) -> void:
		if not is_instance_valid(p) or not p.is_inside_tree() or p.get("done"):
			r.life = minf(r.life, r.age + 0.05)
			return
		var v: Vector3 = p.get("vel")
		var f := (
			Vector3(v.x, 0, v.z).normalized()
			if Vector3(v.x, 0, v.z).length() > 0.01
			else Vector3.FORWARD
		)
		var side := f.cross(Vector3.UP)
		var c := p.global_position
		var pts := PackedVector3Array()
		var ws := PackedFloat32Array()
		for i in 12:
			var u := float(i) / 11.0
			var a := lerpf(-1.2, 1.2, u)
			pts.append(c + side * sin(a) * 0.55 - f * (1.0 - cos(a)) * 0.35)
			ws.append(0.16 * sin(u * PI))
		r.pts = pts
		r.widths = ws
	fx._add(rb)
	rb.shape.call(rb, 0.0)
	rb.rebuild()
	var tr := fx.trail_opts("flying", 1.0)
	tr.follow = p
	fx.emitter(
		Vector3.ZERO,
		6.0,
		30.0,
		tr,
		func():
			return (
				p.global_position
				if is_instance_valid(p) and p.is_inside_tree() and not p.get("done")
				else null
			)
	)


# --- Jorro ---


func stream(user: BattleFighter, mv: Dictionary, gd: Vector3, length: float, dur: float) -> bool:
	if String(mv.get("type", "")) == "fire":
		flame_jet(user, mv, gd, length, dur)
		return true
	return false


## Lança-chamas: chamas que nascem pequenas e brancas na boca e crescem laranja/vermelhas até o
## fim do cone, com fumaça escura em cima e luz tremendo.
func flame_jet(user: BattleFighter, mv: Dictionary, gd: Vector3, length: float, dur: float) -> void:
	var t := Fx3DKit.tier(mv)
	var s := MoveFx3D.kpow(t)
	var half := deg_to_rad(float(mv.get("angle", 35))) / 2.0
	var face := func() -> Vector3:
		return (
			fx.gdir(user.facing) if is_instance_valid(user) and user.facing.length() > 0.01 else gd
		)
	var live := func():
		return (
			fx.mouth(user, face.call())
			if is_instance_valid(user) and user.is_inside_tree() and user.active()
			else null
		)
	var travel := 0.42
	var speed := length / travel
	var layers := [
		{
			"shape": Fx3D.Shape.EMBER,
			"life": [travel * 0.9, travel * 1.1],
			"size": [0.12 * s, 1.0 * s],
			"col": [Color(1.0, 0.95, 0.7), Color(0.9, 0.18, 0.02, 0.0)],
			"rate": 110.0,
			"sp": 1.0,
			"spr": 0.8
		},
		{
			"shape": Fx3D.Shape.GLOW,
			"life": [travel * 0.5, travel * 0.7],
			"size": [0.2 * s, 0.5 * s],
			"col": [Color(1.0, 1.0, 0.85), Color(1.0, 0.6, 0.1, 0.0)],
			"rate": 60.0,
			"sp": 0.9,
			"spr": 0.35
		},
		{
			"shape": Fx3D.Shape.SMOKE,
			"add": false,
			"life": [0.7, 1.0],
			"size": [0.3 * s, 1.3 * s],
			"col": [Color(0.18, 0.14, 0.12, 0.55), Color(0.12, 0.1, 0.1, 0.0)],
			"rate": 22.0,
			"sp": 0.7,
			"spr": 1.0,
			"up": 1.6
		},
	]
	for L in layers:
		var o: Dictionary = L.duplicate()
		o.speed = [speed * float(L.sp) * 0.8, speed * float(L.sp)]
		o.spread = half * float(L.spr)
		o.drag = 0.8
		o.turb = 6.0
		o.fade_in = 0.05
		var e := fx.emitter(Vector3.ZERO, dur, float(L.rate) * (0.7 + 0.15 * t), o, live)
		e.spawn = func(pp: Fx3DParticles) -> void:
			var at = live.call()
			if at == null:
				pp.emit_for = 0.0
				return
			o.dir = face.call()
			fx._emit_one(pp, at, o)
		if L.shape == Fx3D.Shape.SMOKE:
			e.fade_in = 0.35  # a fumaça aparece só no fim do jato
	fx.light(
		fx.mouth(user, gd),
		Fx3DKit.lightc("fire"),
		3.0 + t,
		3.0,
		dur + 0.1,
		{
			"follow": user,
			"off": Vector3(0, fx.height(user) * 0.5, 0) + gd * 0.6,
			"attack": 0.06,
			"hold": 0.85,
			"flicker": 0.3
		}
	)
	fx.light(
		fx.mouth(user, gd) + gd * length * 0.6,
		Color(1.0, 0.45, 0.1),
		3.0 + t,
		length,
		dur + 0.15,
		{
			"follow": user,
			"off": Vector3(0, fx.height(user) * 0.5, 0) + gd * length * 0.6,
			"attack": 0.15,
			"hold": 0.8,
			"flicker": 0.35
		}
	)


# --- Feixes ---


func beam(user: BattleFighter, mv: Dictionary, gd: Vector3, length: float, dur: float) -> bool:
	match _id(mv):
		"hydro_pump", "hydro_cannon":
			fx.beam_body(
				user,
				mv,
				gd,
				length,
				dur,
				{"col": Color(0.3, 0.6, 1.0, 0.9), "inner": Color(0.85, 0.97, 1.0), "noise": 1.0}
			)
			var from := fx.mouth(user, gd)
			fx.emitter(
				Vector3.ZERO,
				dur,
				120.0,
				{
					"shape": Fx3D.Shape.SPARK,
					"stretch": 0.04,
					"life": [0.3, 0.5],
					"size": [0.16, 0.08],
					"col": [Color(0.9, 0.98, 1.0), Color(0.4, 0.7, 1.0, 0.0)],
					"speed": [length * 1.6, length * 2.2],
					"dir": gd,
					"spread": 0.06,
					"grav": 3.0
				},
				func(): return from
			)
			fx.emitter(
				Vector3.ZERO,
				dur,
				40.0,
				{
					"shape": Fx3D.Shape.SMOKE,
					"add": false,
					"life": [0.5, 0.9],
					"size": [0.4, 1.2],
					"col": [Color(0.85, 0.95, 1.0, 0.45), Color(0.85, 0.95, 1.0, 0.0)],
					"speed": [1.0, 3.0],
					"dir": Vector3.UP,
					"spread": 1.2
				},
				func(): return from + gd * length
			)
			return true
		"ice_beam":
			fx.beam_body(
				user,
				mv,
				gd,
				length,
				dur,
				{"col": Color(0.55, 0.9, 1.0), "inner": Color.WHITE, "noise": 0.5}
			)
			var from2 := fx.mouth(user, gd)
			for i in 9:
				var at := from2 + gd * length * (float(i) + 0.6) / 9.0 + MoveFx3D.rand_dir() * 0.25
				fx.later(
					dur * float(i) / 12.0,
					func() -> void:
						fx.solid(
							at,
							{
								"kind": "crystal",
								"col": Color(0.75, 0.94, 1.0, 0.85),
								"emit": 1.6,
								"size": randf_range(0.25, 0.45),
								"life": dur + 0.5,
								"spin": 0.5,
								"floor": false,
								"grow0": 0.1
							}
						)
				)
			return true
		"solar_beam":
			fx.beam_body(
				user,
				mv,
				gd,
				length,
				dur,
				{"col": Color(1.0, 0.92, 0.45), "inner": Color(1, 1, 0.95), "k": 1.25}
			)
			return true
		"psybeam":
			fx.beam_body(user, mv, gd, length, dur, {"noise": 0.4})
			var from3 := fx.mouth(user, gd)
			fx.repeat(
				0.06,
				dur,
				func(i: int) -> bool:
					var rg := fx.ring(
						from3,
						0.25,
						0.45,
						Color.from_hsv(fmod(0.85 + i * 0.07, 1.0), 0.6, 1.0, 0.9),
						0.4,
						{"normal": gd, "inner": 0.75}
					)
					rg.vel = gd * length * 2.2
					return true
			)
			return true
	return false


# --- Acerto ---


func hit(
	user: BattleFighter, target: BattleFighter, mv: Dictionary, gd: Vector3, crit: bool, eff: float
) -> bool:
	var type := String(mv.get("type", ""))
	if type == "electric" and String(mv.get("category", "")) != "status":
		fx.impact(target, mv, gd, crit, eff)
		# Raios correndo pelo corpo de quem levou.
		var t := Fx3DKit.tier(mv)
		fx.repeat(
			0.05,
			0.12 + 0.05 * t,
			func(_i: int) -> bool:
				if not is_instance_valid(target) or not target.is_inside_tree():
					return false
				var c := fx.center(target, 0.5)
				var h := fx.height(target)
				for k in 1 + t / 2:
					fx.bolt(
						c + MoveFx3D.rand_dir() * h * 0.5,
						c + MoveFx3D.rand_dir() * h * 0.5,
						Fx3DKit.mid("electric"),
						0.03,
						0.08,
						{"segs": 6, "amp": 0.12}
					)
				return true
		)
		return true
	if _id(mv) == "fire_blast":
		fx.impact(target, mv, gd, crit, eff, 1.2)
		# A estrela de fogo (大) em pé virada para a câmera.
		var c2 := fx.center(target, 0.55)
		var cd := (fx.cam_pos(c2) - c2).normalized()
		var side := cd.cross(Vector3.UP).normalized()
		var arms := [
			Vector3.UP,
			-Vector3.UP * 0.2 + side,
			-Vector3.UP * 0.2 - side,
			-Vector3.UP + side * 0.6,
			-Vector3.UP - side * 0.6
		]
		for a in arms:
			fx.burst(
				c2,
				{
					"n": 18,
					"shape": Fx3D.Shape.EMBER,
					"speed": [3.0, 6.0],
					"life": [0.35, 0.55],
					"size": [0.5, 0.1],
					"col": [Color(1, 0.95, 0.7), Color(0.8, 0.15, 0.0, 0.0)],
					"dir": (a as Vector3).normalized(),
					"spread": 0.12,
					"drag": 3.0
				}
			)
		fx.light(c2, Color(1, 0.55, 0.2), 8.0, 6.0, 0.5)
		return true
	return false


# --- Áreas ---


func area_pre(user: BattleFighter, mv: Dictionary, at: Vector3, r: float, windup: float) -> bool:
	var id := _id(mv)
	var type := String(mv.get("type", ""))
	if (
		id in ["thunder", "thunder_cage", "wildbolt_storm", "bolt_strike"]
		or (type == "electric" and String(mv.get("category", "")) != "status")
	):
		storm(at, r, windup, mv)
		return true
	if id in ["rock_slide", "rock_tomb", "avalanche", "draco_meteor", "meteor_mash"]:
		sky_rocks(at, r, windup, mv)
		return true
	if type == "psychic" and String(mv.get("category", "")) != "status":
		psy_gather(at, r, windup, mv)
		return true
	if fx._has_word(id, ["powder", "spore", "pollen"]):
		powder(at, r, windup, mv)
		return true
	if id in ["sing", "perish_song", "grass_whistle"]:
		notes(at, r, windup, mv)
		return true
	return false


func area_land(
	user: BattleFighter, mv: Dictionary, at: Vector3, r: float, around_user: bool
) -> bool:
	var id := _id(mv)
	var type := String(mv.get("type", ""))
	var t := Fx3DKit.tier(mv)
	if around_user:
		if type == "ground" and String(mv.get("category", "")) == "physical":
			quake(at, r, mv)
			return true
		if id in ["explosion", "self_destruct", "misty_explosion", "mind_blown"]:
			explosion(at, r, mv)
			return true
		if id in ["surf", "muddy_water", "water_spout", "sparkling_aria"]:
			wave(at, r, mv)
			return true
		if type == "electric":
			fx.burst_area(mv, at, r, 0.8)
			for i in 6 + 2 * t:
				var a := TAU * i / (6 + 2 * t) + randf() * 0.3
				var e := (
					at + Vector3(cos(a), 0, sin(a)) * r * randf_range(0.6, 1.0) + Vector3(0, 0.2, 0)
				)
				fx.bolt(
					at + Vector3(0, fx.height(user) * 0.5 if is_instance_valid(user) else 0.5, 0),
					e,
					Fx3DKit.mid("electric"),
					0.05,
					0.22,
					{"branches": 1}
				)
			return true
		return false
	if (
		id in ["thunder", "thunder_cage", "wildbolt_storm", "bolt_strike"]
		or (type == "electric" and String(mv.get("category", "")) != "status")
	):
		sky_bolt(at, r, mv)
		return true
	if id in ["rock_slide", "rock_tomb", "avalanche", "draco_meteor", "meteor_mash"]:
		fx.burst_area(mv, at, r, 0.9)
		return true
	if (
		(
			id
			in [
				"stone_edge",
				"stone_axe",
				"spikes",
				"earth_power",
				"fissure",
				"precipice_blades",
				"headlong_rush"
			]
		)
		or (type == "ground" and t >= 3)
	):
		erupt(at, r, mv)
		return true
	return false


## Nuvem de tempestade se fecha sobre o alvo, piscando por dentro.
func storm(at: Vector3, r: float, windup: float, mv: Dictionary) -> void:
	var top := at + Vector3(0, 5.5, 0)
	var cloud := fx.emitter(
		Vector3.ZERO,
		windup + 0.2,
		60.0,
		{
			"shape": Fx3D.Shape.SMOKE,
			"add": false,
			"life": [0.7, 1.1],
			"size": [1.0, 2.2],
			"col": [Color(0.22, 0.22, 0.3, 0.9), Color(0.15, 0.15, 0.22, 0.0)],
			"speed": [0.1, 0.5],
			"fade_in": 0.3
		},
		func():
			return (
				top
				+ Vector3(randf_range(-1, 1), randf_range(-0.2, 0.3), randf_range(-1, 1)) * r * 1.1
			)
	)
	cloud.attract_point = top
	cloud.orbit_k = 4.0
	fx.light(
		top - Vector3(0, 1.0, 0),
		Fx3DKit.lightc("electric"),
		3.0,
		8.0,
		windup + 0.2,
		{"attack": windup * 0.6, "hold": 0.9, "flicker": 0.8}
	)
	fx.repeat(
		0.09,
		windup,
		func(_i: int) -> bool:
			var a := (
				top + Vector3(randf_range(-1, 1), randf_range(-0.3, 0.2), randf_range(-1, 1)) * r
			)
			fx.bolt(
				a,
				(
					a
					+ (
						Vector3(randf_range(-1, 1), randf_range(-0.6, 0.0), randf_range(-1, 1))
						* r
						* 0.8
					)
				),
				Fx3DKit.mid("electric", 0.9),
				0.025,
				0.07,
				{"segs": 6, "amp": 0.2, "core": false}
			)
			return true
	)
	# Faíscas no chão sobem conforme a carga cresce (aviso vivo no lugar do disco).
	fx.emitter(
		Vector3.ZERO,
		windup,
		30.0,
		{
			"shape": Fx3D.Shape.SPARK,
			"stretch": 0.04,
			"life": [0.12, 0.25],
			"size": [0.07, 0.02],
			"col": [Color.WHITE, Color(Fx3DKit.mid("electric"), 0.0)],
			"speed": [1.0, 3.0],
			"dir": Vector3.UP,
			"spread": 0.6,
			"flat": true,
			"r": r * 0.8
		},
		func(): return at
	)


## Raio do céu: dois raios grossos com galhos, clarão, luz forte e tremor.
func sky_bolt(at: Vector3, r: float, mv: Dictionary) -> void:
	var t := Fx3DKit.tier(mv)
	var top := at + Vector3(randf_range(-0.5, 0.5), 6.0, randf_range(-0.5, 0.5))
	var col := Fx3DKit.mid("electric")
	fx.bolt(
		top, at, col, 0.08 + 0.02 * t, 0.35, {"branches": 3, "segs": 16, "amp": 0.6, "every": 0.05}
	)
	fx.later(
		0.07,
		func() -> void:
			fx.bolt(
				top + Vector3(0.3, 0, 0.2),
				at,
				Fx3DKit.accent("electric"),
				0.05,
				0.25,
				{"branches": 2, "segs": 14, "amp": 0.7}
			)
	)
	fx.flash(at + Vector3(0, 0.8, 0), 3.0, Color.WHITE, 0.2)
	fx.light(at + Vector3(0, 2.0, 0), Color(0.85, 0.9, 1.0), 10.0, 12.0, 0.4, {"flicker": 0.5})
	fx.burst_area(mv, at, r, 1.0)
	fx.burst(
		at + Vector3(0, 0.2, 0),
		{
			"n": 40,
			"shape": Fx3D.Shape.SPARK,
			"stretch": 0.04,
			"speed": [4.0, 10.0],
			"life": [0.2, 0.45],
			"size": [0.1, 0.03],
			"col": [Color.WHITE, Color(col, 0.0)],
			"dir": Vector3.UP,
			"spread": 1.3,
			"grav": 9.0,
			"boost": 3.0
		}
	)
	fx.shake(0.12, 0.3)


## Pedras surgem no alto e caem quando a área cai.
func sky_rocks(at: Vector3, r: float, windup: float, mv: Dictionary) -> void:
	var id := _id(mv)
	var t := Fx3DKit.tier(mv)
	var n := 3 + t
	var col := Color(0.58, 0.5, 0.4)
	var kind := "rock"
	var emit := 0.0
	if id == "avalanche":
		col = Color(0.85, 0.95, 1.0)
		kind = "crystal"
		emit = 0.8
	elif id in ["draco_meteor", "meteor_mash"]:
		col = Fx3DKit.mid("dragon") if id == "draco_meteor" else Fx3DKit.mid("steel")
		emit = 2.0
	for i in n:
		var q := (
			at + Vector3(randf_range(-r, r) * 0.8, 4.5 + randf() * 1.5, randf_range(-r, r) * 0.8)
		)
		var drop := randf() * 0.15
		var m := fx.solid(
			q,
			{
				"kind": kind,
				"col": col,
				"emit": emit,
				"size": randf_range(0.35, 0.6) * (1.0 + 0.1 * t),
				"life": windup + 1.4,
				"spin": 3.0,
				"grow0": 0.05,
				"fade_in": 0.3
			}
		)
		m.gravity = 0.0
		var fall_at := maxf(windup - 0.3 - drop, 0.05)
		fx.later(
			fall_at,
			func() -> void:
				if is_instance_valid(m):
					m.vel = Vector3(0, -6.0, 0)
					m.gravity = 30.0
		)
		m.on_floor = func(mm: Fx3DMesh) -> void:
			fx.element(
				"rock" if kind == "rock" else ("ice" if id == "avalanche" else "dragon"),
				mm.global_position,
				8,
				{"dir": Vector3.UP, "spread": 1.1, "speed": [1.5, 4.0], "k": 0.8}
			)
			mm.life = minf(mm.life, mm.age + 0.6)
		if emit > 0.0:
			var tr := fx.trail_opts("dragon" if id == "draco_meteor" else "ice", 1.2)
			tr.follow = m
			fx.emitter(
				Vector3.ZERO,
				windup + 0.8,
				24.0,
				tr,
				func():
					return (
						m.global_position if is_instance_valid(m) and m.is_inside_tree() else null
					)
			)
	# Sombra das pedras aparecendo (escurece o chão por baixo: aviso natural).
	fx.emitter(
		Vector3.ZERO,
		windup,
		14.0,
		{
			"shape": Fx3D.Shape.SMOKE,
			"add": false,
			"life": [0.4, 0.7],
			"size": [0.4, 0.8],
			"col": [Color(0.75, 0.68, 0.55, 0.0), Color(0.75, 0.68, 0.55, 0.4)],
			"speed": [0.1, 0.3],
			"flat": true,
			"r": r * 0.8
		},
		func(): return at + Vector3(0, 0.1, 0)
	)


## Pó (Sleep Powder, Stun Spore, Spore...): nuvem colorida que desce girando sobre o alvo.
func powder(at: Vector3, r: float, windup: float, mv: Dictionary) -> void:
	var id := _id(mv)
	var col := Color(0.55, 0.75, 1.0)
	if id.contains("stun"):
		col = Color(1.0, 0.92, 0.3)
	elif id.contains("poison"):
		col = Color(0.75, 0.4, 1.0)
	elif id.contains("spore"):
		col = Color(0.75, 0.95, 0.5)
	var e := fx.emitter(
		Vector3.ZERO,
		windup + 0.3,
		70.0,
		{
			"shape": Fx3D.Shape.GLOW,
			"life": [0.7, 1.1],
			"size": [0.14, 0.06],
			"col": [col.lightened(0.4), Color(col, 0.0)],
			"speed": [0.0, 0.3],
			"grav": 1.2,
			"turb": 5.0,
			"fade_in": 0.2
		},
		func():
			return at + Vector3(randf_range(-1, 1) * r, 2.2 + randf() * 0.8, randf_range(-1, 1) * r)
	)
	e.attract_point = at + Vector3(0, 1.0, 0)
	e.orbit_k = 6.0
	fx.light(at + Vector3(0, 1.2, 0), col, 1.5, r * 2.5, windup + 0.4, {"attack": 0.3, "hold": 0.8})


func notes(at: Vector3, r: float, windup: float, mv: Dictionary) -> void:
	var e := fx.emitter(
		Vector3.ZERO,
		windup + 0.2,
		16.0,
		{
			"shape": Fx3D.Shape.TEX,
			"tex": "note",
			"add": false,
			"life": [0.8, 1.2],
			"size": [0.35, 0.3],
			"col": [Color.from_hsv(randf(), 0.4, 1.0), Color(1, 1, 1, 0.0)],
			"col2": [Color(0.7, 0.85, 1.0), Color(1, 1, 1, 0.0)],
			"speed": [0.2, 0.5],
			"fade_in": 0.2
		},
		func():
			return (
				at
				+ Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * r
				+ Vector3(0, 0.6 + randf() * 1.0, 0)
			)
	)
	e.attract_point = at + Vector3(0, 1.0, 0)
	e.orbit_k = 10.0
	e.attract_k = 2.0


## Anéis psíquicos se fecham sobre o alvo e o ar em volta brilha rosa.
func psy_gather(at: Vector3, r: float, windup: float, mv: Dictionary) -> void:
	var c := at + Vector3(0, 0.8, 0)
	fx.repeat(
		maxf(windup / 4.0, 0.1),
		windup,
		func(i: int) -> bool:
			var cd := (fx.cam_pos(c) - c).normalized()
			fx.ring(
				c,
				r * 1.4,
				0.2,
				Color.from_hsv(fmod(0.88 + i * 0.05, 1.0), 0.65, 1.0, 0.9),
				0.35,
				{"normal": cd, "inner": 0.86}
			)
			fx.ring(
				at + Vector3(0, 0.05, 0),
				r * 1.2,
				0.3,
				Fx3DKit.mid("psychic", 0.6),
				0.35,
				{"inner": 0.9}
			)
			return true
	)
	fx.shell(
		c,
		0.1,
		r * 0.6,
		Fx3DKit.mid("psychic", 0.5),
		windup + 0.05,
		{"noise": 0.7, "phase": 4.0, "fade_in": 0.5, "fade_out": 0.1}
	)
	fx.light(
		c,
		Fx3DKit.lightc("psychic"),
		3.0,
		r * 3.0,
		windup + 0.1,
		{"attack": windup * 0.8, "hold": 0.9}
	)


# --- Golpes em volta do usuário ---


## Terremoto: rachaduras brilhando saem do usuário, pedras pulam, anéis de poeira e tremor forte.
func quake(at: Vector3, r: float, mv: Dictionary) -> void:
	var t := Fx3DKit.tier(mv)
	var cracks := 6 + t * 2
	var col := Color(1.0, 0.62, 0.25)
	for i in cracks:
		var a := TAU * i / cracks + randf_range(-0.2, 0.2)
		var d := Vector3(cos(a), 0, sin(a))
		var end := at + d * r * randf_range(0.7, 1.05)
		var rb := Fx3DRibbon.make(Fx3D.mesh_mat(Fx3D.Mode.CRACK, 2.4), col, 0.12, 0.9, fx.cam())
		var pts := Fx3DRibbon.jag(
			at + Vector3(0, 0.04, 0), end + Vector3(0, 0.04, 0), 8, 0.3, Vector3.UP
		)
		for k in pts.size():
			var v := pts[k]
			v.y = at.y + 0.04
			pts[k] = v
		rb.fade_in = 0.0
		rb.shape = func(r2: Fx3DRibbon, k2: float) -> void:
			var reach := clampf(k2 / 0.25, 0.0, 1.0)
			var n := maxi(int(pts.size() * reach), 2)
			r2.pts = pts.slice(0, n)
		fx._add(rb)
		rb.shape.call(rb, 0.0)
		rb.rebuild()
	for k in 3:
		fx.later(
			0.07 * k,
			fx.ring.bind(
				at + Vector3(0, 0.06, 0),
				0.4,
				r * (0.8 + 0.25 * k),
				Color(0.95, 0.8, 0.55, 0.8),
				0.5,
				{"noise": 0.7, "soft": 0.6}
			)
		)
	for i in 10 + 3 * t:
		var a2 := randf() * TAU
		var q := at + Vector3(cos(a2), 0, sin(a2)) * r * randf_range(0.3, 1.0)
		fx.solid(
			q,
			{
				"kind": "rock",
				"col": Color(0.52, 0.4, 0.28),
				"size": randf_range(0.15, 0.32),
				"vel": Vector3(randf_range(-1, 1), randf_range(4.0, 7.0), randf_range(-1, 1)),
				"grav": 16.0,
				"life": 1.2
			}
		)
	fx.burst(
		at,
		{
			"n": 24,
			"shape": Fx3D.Shape.SMOKE,
			"add": false,
			"speed": [2.0, 4.5],
			"life": [0.7, 1.2],
			"size": [0.6, 1.6],
			"col": [Color(0.8, 0.68, 0.5, 0.7), Color(0.7, 0.6, 0.5, 0.0)],
			"dir": Vector3.UP,
			"spread": 1.45,
			"drag": 2.5,
			"flat": true,
			"r": r * 0.7
		}
	)
	fx.light(at + Vector3(0, 0.5, 0), col, 4.0, r * 2.0, 0.6)
	fx.shake(0.18 + 0.03 * t, 0.6)


## Explosão: bola de fogo que cresce, anel de choque, brasas, fumaça e um clarão enorme.
func explosion(at: Vector3, r: float, mv: Dictionary) -> void:
	var c := at + Vector3(0, 0.8, 0)
	var misty := _id(mv) == "misty_explosion"
	var col := Color(1.0, 0.55, 0.15) if not misty else Fx3DKit.mid("fairy")
	fx.flash(c, r * 2.0, Color.WHITE, 0.2)
	fx.shell(c, 0.3, r * 0.9, col, 0.55, {"noise": 0.9, "phase": 6.0, "fade_out": 0.6})
	fx.shell(c, 0.2, r * 0.6, Color(1, 0.95, 0.7), 0.35, {"noise": 0.6, "phase": 8.0})
	fx.ring(at + Vector3(0, 0.08, 0), 0.4, r * 1.5, Color(1, 0.85, 0.6, 0.9), 0.5, {"noise": 0.5})
	fx.element("fire" if not misty else "fairy", c, 50, {"speed": [4.0, 9.0], "k": 1.6})
	fx.burst(
		c,
		{
			"n": 30,
			"shape": Fx3D.Shape.SMOKE,
			"add": false,
			"speed": [1.5, 4.0],
			"life": [1.0, 1.8],
			"size": [0.8, 2.4],
			"col": [Color(0.25, 0.22, 0.2, 0.8), Color(0.2, 0.2, 0.2, 0.0)],
			"up": 1.5,
			"drag": 2.0
		}
	)
	fx.light(c, col, 14.0, r * 3.5, 0.7)
	fx.shake(0.3, 0.6)


## Onda (Surf): parede de água em anel que cresce, espuma e gotas.
func wave(at: Vector3, r: float, mv: Dictionary) -> void:
	var w := fx.shell(
		at,
		0,
		0,
		Color(0.35, 0.65, 1.0, 0.9),
		0.7,
		{
			"mesh": Fx3D.tube(),
			"noise": 0.9,
			"phase": 3.0,
			"s0v": Vector3(0.5, 1.6, 0.5),
			"s1v": Vector3(r * 1.2, 0.6, r * 1.2),
			"fade_out": 0.4
		}
	)
	w.grow_ease = true
	fx.ring(
		at + Vector3(0, 0.08, 0), 0.4, r * 1.25, Color(0.9, 0.97, 1.0, 0.9), 0.7, {"noise": 0.8}
	)
	for i in 40:
		var a := randf() * TAU
		var d := Vector3(cos(a), 0, sin(a))
		fx.burst(
			at + d * 0.5 + Vector3(0, 0.3, 0),
			{
				"n": 3,
				"shape": Fx3D.Shape.SPARK,
				"stretch": 0.04,
				"speed": [r * 1.4, r * 2.0],
				"life": [0.4, 0.6],
				"size": [0.16, 0.08],
				"col": [Color(0.9, 0.98, 1.0), Color(0.4, 0.7, 1.0, 0.0)],
				"dir": (d + Vector3(0, 0.9, 0)).normalized(),
				"spread": 0.2,
				"grav": 9.0
			}
		)
	fx.light(at + Vector3(0, 1.0, 0), Fx3DKit.lightc("water"), 3.0, r * 2.5, 0.6)
	fx.shake(0.06, 0.3)


## Pedras pontudas (Stone Edge) ou terra explodindo do chão (Earth Power) sob o alvo.
func erupt(at: Vector3, r: float, mv: Dictionary) -> void:
	var type := String(mv.get("type", ""))
	var t := Fx3DKit.tier(mv)
	if type == "rock":
		for i in 5 + t:
			var a := TAU * i / (5 + t) + randf() * 0.4
			var q := at + Vector3(cos(a), 0, sin(a)) * r * randf_range(0.0, 0.7)
			var tilt := Basis(
				Vector3(cos(a + PI / 2), 0, sin(a + PI / 2)), randf_range(-0.35, 0.35)
			)
			var m := fx.solid(
				q,
				{
					"kind": "crystal",
					"col": Color(0.62, 0.55, 0.45),
					"size": randf_range(0.6, 1.0),
					"life": 1.1,
					"spin": 0.0,
					"floor": false,
					"grow0": 0.05,
					"basis": tilt
				}
			)
			m.s0 = Vector3(0.3, 0.05, 0.3) * m.s1.x
			m.s1 = Vector3(0.45, 1.6, 0.45) * m.s1.x
			m.fade_out = 0.3
		fx.burst_area(mv, at, r, 0.8)
		return
	# Terra/fogo do chão: coluna subindo com brasas.
	var col := Color(1.0, 0.55, 0.2)
	fx.burst(
		at,
		{
			"n": 40 + 10 * t,
			"shape": Fx3D.Shape.EMBER,
			"speed": [4.0, 9.0],
			"life": [0.4, 0.8],
			"size": [0.4, 0.1],
			"col": [Color(1, 0.9, 0.6), Color(0.8, 0.2, 0.0, 0.0)],
			"dir": Vector3.UP,
			"spread": 0.35,
			"grav": 6.0,
			"flat": true,
			"r": r * 0.5
		}
	)
	fx.element(
		"ground",
		at,
		20,
		{"dir": Vector3.UP, "spread": 0.6, "speed": [3.0, 7.0], "k": 1.3, "r": r * 0.5}
	)
	fx.ring(at + Vector3(0, 0.06, 0), 0.3, r * 1.2, col, 0.45, {"noise": 0.6})
	fx.light(at + Vector3(0, 1.0, 0), col, 6.0, r * 3.0, 0.5)
	fx.shake(0.1, 0.35)


# --- Zonas ---


func zone(user: BattleFighter, mv: Dictionary, at: Vector3, r: float, dur: float) -> bool:
	if _id(mv) == "magma_storm":
		fx.vortex(mv, at, r, dur, 1.4)
		return true
	return false


## Luz do sol caindo do céu no usuário (Solar Beam carregando).
func sunlight(user: BattleFighter, mv: Dictionary, secs: float) -> void:
	if not is_instance_valid(user):
		return
	var top := user.global_position + Vector3(0, 7.0, 0)
	fx.tube(
		top,
		Vector3.DOWN,
		7.0,
		0.6,
		Color(1.0, 0.95, 0.6, 0.6),
		secs + 0.1,
		{"noise": 0.4, "w0": 0.1, "fade_in": 0.4}
	)
	var e := fx.emitter(
		Vector3.ZERO,
		secs,
		50.0,
		{
			"shape": Fx3D.Shape.STAR,
			"life": [0.6, 1.0],
			"size": [0.22, 0.06],
			"col": [Color(1, 1, 0.8), Color(1, 0.9, 0.4, 0.0)],
			"speed": [3.0, 5.0],
			"dir": Vector3.DOWN,
			"spread": 0.2
		},
		func():
			return (
				(
					user.global_position
					+ Vector3(randf_range(-1.5, 1.5), 4.0 + randf() * 2.0, randf_range(-1.5, 1.5))
				)
				if is_instance_valid(user) and user.is_inside_tree()
				else null
			)
	)
	e.attract_node = user
	e.attract_off = Vector3(0, fx.height(user) * 0.5, 0)
	e.attract_k = 10.0
	e.kill_near = 0.25
	fx.light(
		user.global_position + Vector3(0, 2.0, 0),
		Color(1.0, 0.95, 0.7),
		5.0,
		6.0,
		secs + 0.2,
		{"attack": secs * 0.8, "hold": 0.9}
	)

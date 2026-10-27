class_name FieldFx3D
extends RefCounted
## Efeitos 3D das mecânicas em volta dos golpes no modo de energia: escudos (Protect, telas),
## cura, holofote, névoa, espinhos, Cavar (buraco, rastro, saída), arremesso, batida, sumiço
## (Aerial Ace), fumaça de entrada, clima/terreno/gravidade lançados. Mesmas chamadas do MoveShow.

const SCREEN_COLS := {
	"light_screen": Color(1.0, 0.85, 0.5),
	"reflect": Color(0.5, 0.75, 1.0),
	"safeguard": Color(0.8, 0.7, 1.0),
	"quick_guard": Color(1.0, 0.65, 0.3),
	"tailwind": Color(0.8, 0.95, 1.0)
}

var fx: MoveFx3D


func _init(f: MoveFx3D) -> void:
	fx = f


func _side(side: int) -> Array:
	var out := []
	var fs = fx.arena.get("fighters")
	if fs is Array:
		for f in fs:
			if is_instance_valid(f) and f.is_inside_tree() and f.active() and int(f.side) == side:
				out.append(f)
	return out


func _all() -> Array:
	var out := []
	var fs = fx.arena.get("fighters")
	if fs is Array:
		for f in fs:
			if is_instance_valid(f) and f.is_inside_tree() and f.active():
				out.append(f)
	return out


## Bolha de energia em volta do lutador (Protect e cia.) com brilho hexagonal piscando.
func bubble(f: BattleFighter, col: Color, secs: float, k := 1.0) -> void:
	var h := fx.height(f)
	var r := maxf(h * 0.75, 0.7) * k
	var off := Vector3(0, h * 0.5, 0)
	fx.shell(
		fx.center(f, 0.5),
		r * 0.6,
		r,
		col,
		secs,
		{
			"follow": f,
			"off": off,
			"noise": 0.35,
			"phase": 2.0,
			"fade_in": 0.12,
			"fade_out": 0.2,
			"soft": 0.7
		}
	)
	fx.shell(
		fx.center(f, 0.5),
		r * 0.4,
		r * 1.05,
		Color.WHITE,
		0.25,
		{"follow": f, "off": off, "fade_out": 0.8}
	)
	fx.light(
		fx.center(f, 0.5),
		col,
		2.0,
		r * 3.0,
		secs,
		{"follow": f, "off": off, "attack": 0.1, "hold": 0.85}
	)
	fx.burst(
		fx.center(f, 0.5),
		{
			"n": 16,
			"shape": Fx3D.Shape.STAR,
			"speed": [1.0, 2.5],
			"life": [0.3, 0.5],
			"size": [0.2, 0.05],
			"col": [Color.WHITE, Color(col, 0.0)],
			"r": r * 0.8
		}
	)


func protect_shield(f: BattleFighter, secs: float) -> void:
	if is_instance_valid(f):
		bubble(f, Color(0.45, 1.0, 0.6), secs)


## Holofote (Follow Me, Rage Powder): cone de luz de cima seguindo o lutador.
func spotlight(f: BattleFighter, secs: float) -> void:
	if not is_instance_valid(f):
		return
	var top := f.global_position + Vector3(0, 6.0, 0)
	var t := fx.tube(
		top,
		Vector3.DOWN,
		6.0,
		0.9,
		Color(1, 0.95, 0.6, 0.45),
		secs,
		{"noise": 0.3, "w0": 1.0, "fade_in": 0.15, "fade_out": 0.15, "boost": 1.4}
	)
	t.follow = f
	t.follow_off = Vector3(0, 6.0, 0)
	fx.ring(
		fx.feet(f),
		0.9,
		1.1,
		Color(1, 0.95, 0.6, 0.8),
		secs,
		{"follow": f, "off": Vector3(0, 0.05, 0), "fade_in": 0.15, "fade_out": 0.15}
	)
	var l := fx.light(
		top,
		Color(1, 0.95, 0.75),
		4.0,
		8.0,
		secs,
		{"follow": f, "off": Vector3(0, 3.0, 0), "attack": 0.2, "hold": 0.9}
	)


## Tela do lado (Light Screen, Reflect...): parede de luz em volta de cada lutador do lado.
func screen(side: int, kind: String, secs: float) -> void:
	var col: Color = SCREEN_COLS.get(kind, Color(0.8, 0.9, 1.0))
	for f in _side(side):
		if kind == "tailwind":
			var e := fx.emitter(
				Vector3.ZERO,
				minf(secs, 2.0),
				40.0,
				{
					"shape": Fx3D.Shape.SPARK,
					"stretch": 0.12,
					"life": [0.3, 0.5],
					"size": [0.07, 0.02],
					"col": [Color(1, 1, 1, 0.8), Color(col, 0.0)],
					"speed": [5.0, 8.0],
					"dir": fx.gdir((f as BattleFighter).facing),
					"spread": 0.2,
					"r": 1.2,
					"follow": f
				},
				func():
					return (
						fx.center(f, 0.5) if is_instance_valid(f) and f.is_inside_tree() else null
					)
			)
			continue
		bubble(f, col, minf(secs, 1.2), 1.15)
		fx.ring(fx.feet(f), 0.3, 1.4, col, 0.6, {"noise": 0.4})


func heal(f: BattleFighter, col := Color(0.6, 1.0, 0.6), secs := 0.7) -> void:
	if not is_instance_valid(f):
		return
	var h := fx.height(f)
	fx.emitter(
		Vector3.ZERO,
		secs,
		40.0,
		{
			"follow": f,
			"shape": Fx3D.Shape.STAR,
			"life": [0.5, 0.8],
			"size": [0.18, 0.05],
			"col": [col.lightened(0.5), Color(col, 0.0)],
			"speed": [0.8, 1.6],
			"dir": Vector3.UP,
			"spread": 0.2,
			"flat": true,
			"r": 0.6
		},
		func(): return fx.feet(f) if is_instance_valid(f) and f.is_inside_tree() else null
	)
	fx.ring(
		fx.feet(f), 0.3, 1.0, col, secs, {"follow": f, "off": Vector3(0, 0.05, 0), "noise": 0.3}
	)
	fx.shell(
		fx.center(f, 0.5),
		h * 0.4,
		h * 0.65,
		col,
		secs,
		{"follow": f, "off": Vector3(0, h * 0.5, 0), "noise": 0.4, "phase": 2.0}
	)
	fx.light(
		fx.center(f, 0.5),
		col,
		2.5,
		3.5,
		secs,
		{"follow": f, "off": Vector3(0, h * 0.5, 0), "attack": 0.2}
	)


func haze(user: BattleFighter) -> void:
	var c := fx.center(user, 0.4) if is_instance_valid(user) else fx.arena.global_position
	fx.burst(
		c,
		{
			"n": 40,
			"shape": Fx3D.Shape.SMOKE,
			"add": false,
			"speed": [1.0, 4.0],
			"life": [1.0, 1.6],
			"size": [0.6, 2.0],
			"col": [Color(0.85, 0.88, 0.95, 0.6), Color(0.85, 0.88, 0.95, 0.0)],
			"drag": 1.5,
			"flat": true,
			"r": 1.5,
			"h": 0.6
		}
	)


## Espinhos tóxicos: pontas roxas de verdade no chão, brilhando enquanto duram.
func toxic_spikes(_side: int, at_local: Vector3, r: float, life: float) -> void:
	var at := fx.gpos(at_local)
	at.y = fx.floor_y()
	for i in 7:
		var a := TAU * i / 7.0 + randf() * 0.4
		var q := at + Vector3(cos(a), 0, sin(a)) * r * randf_range(0.2, 0.8)
		var m := fx.solid(
			q,
			{
				"kind": "crystal",
				"col": Color(0.65, 0.3, 0.85),
				"emit": 0.8,
				"size": randf_range(0.18, 0.28),
				"life": life,
				"spin": 0.0,
				"floor": false,
				"grow0": 0.1,
				"basis": Basis()
			}
		)
		m.fade_out = 0.05


## Stealth Rock: pedras pontudas flutuando devagar em volta do ponto, enquanto duram.
func stealth_rock(_side: int, at_local: Vector3, r: float, life: float) -> void:
	var at := fx.gpos(at_local)
	for i in 5:
		var a := TAU * i / 5.0 + randf() * 0.5
		var q := at + Vector3(cos(a) * r * 0.8, randf_range(0.5, 1.1), sin(a) * r * 0.8)
		var m := fx.solid(
			q,
			{
				"kind": "shard",
				"col": Color(0.62, 0.52, 0.4),
				"emit": 0.15,
				"size": randf_range(0.16, 0.24),
				"life": life,
				"spin": 0.8,
				"floor": false,
				"grow0": 0.1
			}
		)
		m.fade_out = 0.05


func burrow(user: BattleFighter) -> void:
	if not is_instance_valid(user):
		return
	fx.element(
		"ground",
		fx.feet(user),
		24,
		{"dir": Vector3.UP, "spread": 1.0, "speed": [1.5, 4.0], "k": 1.1}
	)
	fx.ring(
		fx.feet(user) + Vector3(0, 0.04, 0),
		0.2,
		1.1,
		Color(0.85, 0.7, 0.5, 0.8),
		0.4,
		{"noise": 0.6}
	)


func unburrow(user: BattleFighter) -> void:
	if not is_instance_valid(user):
		return
	fx.element(
		"ground",
		fx.feet(user),
		36,
		{"dir": Vector3.UP, "spread": 0.7, "speed": [3.0, 7.0], "k": 1.3, "r": 0.4}
	)
	fx.ring(
		fx.feet(user) + Vector3(0, 0.04, 0),
		0.3,
		1.6,
		Color(0.9, 0.75, 0.5, 0.9),
		0.45,
		{"noise": 0.6}
	)
	fx.shake(0.06, 0.25)


## Rastro de terra que avança pelo chão (Cavar/Mergulho).
func dig_trail(user: BattleFighter, from: Vector3, to: Vector3, duration: float) -> void:
	var a := fx.gpos(from)
	var b := fx.gpos(to)
	a.y = fx.floor_y()
	b.y = fx.floor_y()
	var start := {"t": 0.0}
	var e := fx.emitter(
		Vector3.ZERO,
		duration,
		50.0,
		{
			"shape": Fx3D.Shape.SMOKE,
			"add": false,
			"life": [0.5, 0.9],
			"size": [0.25, 0.7],
			"col": [Color(0.75, 0.62, 0.45, 0.7), Color(0.6, 0.5, 0.4, 0.0)],
			"speed": [0.5, 1.5],
			"dir": Vector3.UP,
			"spread": 0.6,
			"drag": 2.0
		},
		func():
			start.t += 1.0 / 50.0
			return a.lerp(b, clampf(start.t / maxf(duration, 0.05), 0.0, 1.0))
	)
	e.floor_y = fx.floor_y()


func crash(f: BattleFighter, at_local: Vector3, _what: String) -> void:
	var at := fx.gpos(at_local) + Vector3(0, 0.5, 0)
	fx.flash(at, 1.0, Color.WHITE, 0.12)
	fx.element("rock", at, 10, {"k": 0.8})
	fx.burst(
		at,
		{
			"n": 8,
			"shape": Fx3D.Shape.STAR,
			"speed": [1.0, 2.5],
			"life": [0.3, 0.5],
			"size": [0.3, 0.08],
			"col": [Color(1, 1, 0.7), Color(1, 0.9, 0.5, 0.0)],
			"up": 1.0
		}
	)
	fx.shake(0.06, 0.2)


## Arremesso forte: riscos de vento seguindo o lutador.
func launch(f: BattleFighter, dir: Vector3, dist: float) -> void:
	if not is_instance_valid(f):
		return
	var gd := fx.gdir(dir)
	fx.emitter(
		Vector3.ZERO,
		clampf(dist * 0.12, 0.2, 0.7),
		60.0,
		{
			"follow": f,
			"shape": Fx3D.Shape.SPARK,
			"stretch": 0.1,
			"life": [0.15, 0.3],
			"size": [0.07, 0.02],
			"col": [Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.0)],
			"speed": [1.0, 3.0],
			"dir": -gd,
			"spread": 0.3,
			"r": fx.height(f) * 0.4
		},
		func(): return fx.center(f, 0.5) if is_instance_valid(f) and f.is_inside_tree() else null
	)


func blink(f: BattleFighter) -> void:
	if not is_instance_valid(f):
		return
	var c := fx.center(f, 0.5)
	fx.flash(c, 1.4, Color.WHITE, 0.14)
	fx.burst(
		c,
		{
			"n": 14,
			"shape": Fx3D.Shape.SPARK,
			"stretch": 0.08,
			"speed": [4.0, 8.0],
			"life": [0.12, 0.22],
			"size": [0.07, 0.02],
			"col": [Color.WHITE, Color(0.8, 0.9, 1.0, 0.0)],
			"drag": 4.0
		}
	)
	fx.ring(
		c,
		0.1,
		1.0,
		Color(0.9, 0.95, 1.0, 0.9),
		0.2,
		{"normal": (fx.cam_pos(c) - c).normalized(), "inner": 0.85}
	)


## Clima/terreno lançado: pulso de luz e partículas na arena toda.
func weather(kind: String, _secs: float) -> void:
	var col := (
		(
			{
				"sun": Color(1.0, 0.85, 0.4),
				"rain": Color(0.5, 0.7, 1.0),
				"sand": Color(0.85, 0.7, 0.45),
				"hail": Color(0.85, 0.95, 1.0),
				"snow": Color(0.85, 0.95, 1.0)
			}
			. get(kind, Color.WHITE)
		)
		as Color
	)
	for f in _all():
		fx.ring(fx.feet(f), 0.4, 2.0, col, 0.7, {"noise": 0.5})
	var c := fx.arena.global_position + Vector3(0, 4.0, 0)
	fx.light(c, col, 4.0, 30.0, 0.8, {"attack": 0.2})


func terrain(kind: String, secs: float) -> void:
	var col := Color(0.5, 1.0, 0.5) if kind == "grassy" else Color(1.0, 0.7, 0.95)
	for f in _all():
		fx.emitter(
			Vector3.ZERO,
			minf(secs, 1.5),
			20.0,
			{
				"shape": Fx3D.Shape.GLOW,
				"life": [0.6, 1.0],
				"size": [0.14, 0.04],
				"col": [col, Color(col, 0.0)],
				"speed": [0.4, 1.0],
				"dir": Vector3.UP,
				"spread": 0.3,
				"flat": true,
				"r": 1.6
			},
			func(): return fx.feet(f) if is_instance_valid(f) and f.is_inside_tree() else null
		)


func gravity(_secs: float) -> void:
	for f in _all():
		fx.ring(
			fx.feet(f) + Vector3(0, 2.5, 0),
			1.6,
			0.3,
			Color(0.7, 0.5, 1.0, 0.8),
			0.6,
			{"inner": 0.85}
		)
		fx.emitter(
			Vector3.ZERO,
			0.6,
			30.0,
			{
				"shape": Fx3D.Shape.SPARK,
				"stretch": 0.1,
				"life": [0.3, 0.4],
				"size": [0.06, 0.02],
				"col": [Color(0.85, 0.7, 1.0), Color(0.5, 0.3, 1.0, 0.0)],
				"speed": [4.0, 6.0],
				"dir": Vector3.DOWN,
				"spread": 0.05,
				"flat": true,
				"r": 1.2
			},
			func():
				return (
					fx.feet(f) + Vector3(0, 2.6, 0)
					if is_instance_valid(f) and f.is_inside_tree()
					else null
				)
		)

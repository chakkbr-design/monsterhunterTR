class_name Fx3DKit
extends RefCounted
## Caixa de ferramentas dos efeitos 3D dos golpes: rajadas de partículas, emissores contínuos, luzes,
## anéis de choque, cascas de energia, raios elétricos, cortes, feixes, pedras e tremor de câmera.
## Cada tipo tem paleta e "matéria" própria (brasa, gota, faísca, folha, cristal, pó...), em TYPES.
## Só visual: nada aqui muda dano, alcance ou tempo. Tudo entra em BattleVfx.nodes (tick(dt)).

const LEAF := "res://assets/pixellab/fx/leaf.png"
const SNOW := "res://assets/pixellab/fx/snowflake.png"

## Paleta por tipo: core (miolo quase branco), mid (cor do tipo), deep (sombra), luz.
## bits: as partículas da matéria do tipo (ver element()).
const TYPES := {
	"normal": {"core": "fffdf2", "mid": "f4ecd6", "deep": "a89c86", "light": "fff4dc"},
	"fire": {"core": "ffd98a", "mid": "ff6a12", "deep": "b81e06", "light": "ff8a2e"},
	"water": {"core": "eafcff", "mid": "47a6ff", "deep": "1747b8", "light": "6cc0ff"},
	"electric": {"core": "ffffff", "mid": "ffe83a", "deep": "ffae00", "light": "fff27a"},
	"grass": {"core": "f0ffc8", "mid": "62d43c", "deep": "1e7a2c", "light": "a6ff7a"},
	"ice": {"core": "ffffff", "mid": "a6ecff", "deep": "3c96d8", "light": "bff4ff"},
	"fighting": {"core": "fff2d6", "mid": "ff7a2a", "deep": "b2321a", "light": "ffa060"},
	"poison": {"core": "f6d0ff", "mid": "b24ee8", "deep": "561880", "light": "d07aff"},
	"ground": {"core": "fbe8bc", "mid": "cc964c", "deep": "6a4322", "light": "ffcc80"},
	"flying": {"core": "ffffff", "mid": "cce8ff", "deep": "7aa6e6", "light": "e0f2ff"},
	"psychic": {"core": "ffe2f4", "mid": "ff5cb8", "deep": "9c1c78", "light": "ff8ad0"},
	"bug": {"core": "f4ffb6", "mid": "a8d42a", "deep": "4c7a10", "light": "d4ff5a"},
	"rock": {"core": "f4e6c6", "mid": "b09060", "deep": "5a4630", "light": "ffd9a0"},
	"ghost": {"core": "eadcff", "mid": "8c5ce4", "deep": "2c1250", "light": "a070ff"},
	"dragon": {"core": "e6ecff", "mid": "7a5cff", "deep": "2a1a92", "light": "8a9cff"},
	"dark": {"core": "e2ccf4", "mid": "6a3e8c", "deep": "160a20", "light": "9a5ad0"},
	"steel": {"core": "ffffff", "mid": "c8dae8", "deep": "687a8c", "light": "e6f2ff"},
	"fairy": {"core": "fff0fa", "mid": "ff9ad8", "deep": "dc58a8", "light": "ffb8e6"},
}
## Segunda cor de destaque (dragão azul, fantasma, escuridão...).
const ACCENT := {
	"dragon": "40d8ff",
	"ghost": "ff5ad8",
	"dark": "ff4a6a",
	"psychic": "8a7aff",
	"poison": "7aff6a",
	"fairy": "ffffff",
	"electric": "9fe8ff",
	"ice": "ffffff",
	"steel": "ffe6a0",
}

var vfx: BattleVfx
var arena: Node3D
var _events: Array = []  ## {t, cb}


func _init(v: BattleVfx) -> void:
	vfx = v
	arena = v.arena


## Agenda `cb` daqui a `delay` s (tempo da luta).
func later(delay: float, cb: Callable) -> void:
	if delay <= 0.0:
		cb.call()
	else:
		_events.append({"t": delay, "cb": cb})


func tick_events(dt: float) -> void:
	if _events.is_empty():
		return
	var evs := _events
	_events = []
	for e in evs:
		e.t -= dt
		if e.t <= 0.0:
			e.cb.call()
		else:
			_events.append(e)


func clear() -> void:
	_events.clear()


# --- Cores e posições ---


static func hexc(s: String, a := 1.0) -> Color:
	var c := Color(s)
	c.a = a
	return c


static func pal(type: String) -> Dictionary:
	return TYPES.get(type, TYPES.normal)


static func core(type: String, a := 1.0) -> Color:
	return hexc(String(pal(type).core), a)


static func mid(type: String, a := 1.0) -> Color:
	return hexc(String(pal(type).mid), a)


static func deep(type: String, a := 1.0) -> Color:
	return hexc(String(pal(type).deep), a)


static func lightc(type: String) -> Color:
	return hexc(String(pal(type).light))


static func accent(type: String, a := 1.0) -> Color:
	return hexc(String(ACCENT.get(type, pal(type).core)), a)


## 0 = status, 1 fraco (até 40), 2 médio (até 70), 3 forte (até 95), 4 muito forte (acima).
static func tier(mv: Dictionary) -> int:
	if String(mv.get("category", "")) == "status":
		return 0
	var p := float(mv.get("power", mv.get("bp", 0)))
	if p <= 0.0:
		return 2
	if p <= 40.0:
		return 1
	if p <= 70.0:
		return 2
	if p <= 95.0:
		return 3
	return 4


func cam() -> Camera3D:
	return vfx.cam()


func cam_pos(fallback := Vector3.ZERO) -> Vector3:
	return vfx._cam_pos(fallback)


func gpos(local: Vector3) -> Vector3:
	return arena.to_global(local) if arena.is_inside_tree() else local


func gdir(local_dir: Vector3) -> Vector3:
	var d := arena.global_basis * local_dir
	d.y = 0.0
	return d.normalized() if d.length() > 0.001 else Vector3.FORWARD


func center(f: Node3D, k := 0.5) -> Vector3:
	if not is_instance_valid(f) or not f.is_inside_tree():
		return Vector3.ZERO
	var h := 1.0
	if f is BattleFighter:
		h = (f as BattleFighter).visual_height()
	return f.to_global(Vector3(0, h * k, 0))


func height(f: Node3D) -> float:
	return (
		(f as BattleFighter).visual_height() if f is BattleFighter and is_instance_valid(f) else 1.0
	)


func feet(f: Node3D) -> Vector3:
	return (
		f.global_position + Vector3(0, 0.04, 0)
		if is_instance_valid(f) and f.is_inside_tree()
		else Vector3.ZERO
	)


func floor_y() -> float:
	return arena.global_position.y + 0.02 if arena.is_inside_tree() else 0.02


func _add(n: Node3D) -> Node3D:
	arena.add_child(n)
	vfx._track(n)
	return n


static func rand_dir() -> Vector3:
	var v := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1))
	return v.normalized() if v.length() > 0.01 else Vector3.UP


## Direção aleatória num cone de meia-abertura `spread` (rad) em volta de `axis`.
static func cone_dir(axis: Vector3, spread: float) -> Vector3:
	var b := Fx3D.basis_y(axis)
	var a := randf() * TAU
	var r := spread * sqrt(randf())
	return (b * Vector3(sin(r) * cos(a), cos(r), sin(r) * sin(a))).normalized()


# --- Peças ---


## Rajada de partículas. o: shape, add, stretch, tex, n, speed [min,max], dir (eixo), spread (rad),
## life [min,max], size [a,b], col [a,b] (ou col2 para variar entre duas), grav (m/s², para baixo),
## up (m/s somado), drag, spin, r (raio de nascimento), floor, fade_in, fade_out, boost.
func burst(at: Vector3, o: Dictionary) -> Fx3DParticles:
	var n := int(o.get("n", 12))
	if n <= 0:
		return null
	var p := _parts(o, n)
	_add(p)
	for i in n:
		_emit_one(p, at, o)
	return p


func _parts(o: Dictionary, cap: int) -> Fx3DParticles:
	var mat := Fx3D.particle_mat(
		int(o.get("shape", Fx3D.Shape.GLOW)),
		bool(o.get("add", true)),
		float(o.get("stretch", 0.0)),
		String(o.get("tex", "")),
		float(o.get("boost", 2.0))
	)
	var p := Fx3DParticles.make(mat, cap)
	p.gravity = Vector3(0, -float(o.get("grav", 0.0)), 0)
	p.drag = float(o.get("drag", 0.0))
	p.fade_in = float(o.get("fade_in", 0.1))
	p.fade_out = float(o.get("fade_out", 0.5))
	p.turb = float(o.get("turb", 0.0))
	if o.get("floor", false):
		p.floor_y = floor_y()
	return p


func _emit_one(p: Fx3DParticles, at: Vector3, o: Dictionary) -> void:
	var sp: Array = o.get("speed", [1.0, 3.0])
	var lf: Array = o.get("life", [0.3, 0.6])
	var sz: Array = o.get("size", [0.2, 0.05])
	var cols: Array = o.get("col", [Color.WHITE, Color.WHITE])
	var axis: Vector3 = o.get("dir", Vector3.ZERO)
	var d := rand_dir() if axis == Vector3.ZERO else cone_dir(axis, float(o.get("spread", 0.6)))
	var rr := float(o.get("r", 0.0))
	var q := at
	if rr > 0.0:
		var flat := bool(o.get("flat", false))
		var off := rand_dir() * rr * sqrt(randf())
		if flat:
			var a := randf() * TAU
			var rad := rr * sqrt(randf())
			off = Vector3(cos(a) * rad, randf() * float(o.get("h", 0.0)), sin(a) * rad)
		q += off
	var v := d * randf_range(float(sp[0]), float(sp[1]))
	v.y += float(o.get("up", 0.0))
	var ca: Color = cols[0]
	var cb: Color = cols[1] if cols.size() > 1 else cols[0]
	if o.has("col2") and randf() < 0.5:
		var c2: Array = o.col2
		ca = c2[0]
		cb = c2[1] if c2.size() > 1 else c2[0]
	var s := randf_range(0.75, 1.25)
	var spin := float(o.get("spin", 0.0))
	p.emit(
		q,
		v,
		randf_range(float(lf[0]), float(lf[1])),
		float(sz[0]) * s,
		float(sz[1]) * s,
		ca,
		cb,
		randf() * TAU,
		randf_range(-spin, spin)
	)


## Emissor contínuo: `rate` por s durante `secs`, cada um nascendo onde `where.call()` disser
## (ou em `at`), com as opções de burst. follow = nó que o emissor acompanha.
func emitter(
	at: Vector3, secs: float, rate: float, o: Dictionary, where := Callable()
) -> Fx3DParticles:
	var cap := int(
		o.get(
			"cap",
			clampi(int(rate * float((o.get("life", [0.4, 0.6]) as Array)[1]) * 1.3) + 8, 8, 600)
		)
	)
	var p := _parts(o, cap)
	_add(p)
	p.rate = rate
	p.emit_for = secs
	p.max_t = secs + 4.0
	var fol: Node3D = o.get("follow")
	if fol != null:
		p.follow = fol
		p.carry = float(o.get("carry", 0.0))
	p.spawn = func(pp: Fx3DParticles) -> void:
		var q: Vector3 = at
		if where.is_valid():
			var w = where.call()
			if w == null:
				pp.emit_for = 0.0
				return
			q = w
		_emit_one(pp, q, o)
	return p


## Luz que acende e apaga. follow = acompanha o nó.
func light(
	at: Vector3, col: Color, energy: float, radius: float, secs: float, o := {}
) -> Fx3DLight:
	if not vfx.lights_on:
		return null
	var l := Fx3DLight.make(col, energy, radius, secs)
	if l == null:
		return null
	_add(l)
	l.global_position = at
	l.attack = float(o.get("attack", 0.04))
	l.hold = float(o.get("hold", 0.0))
	l.flicker = float(o.get("flicker", 0.0))
	var fol: Node3D = o.get("follow")
	if fol != null:
		l.follow = fol
		l.follow_off = o.get("off", Vector3.ZERO)
	return l


## Anel de choque. Deitado no chão (padrão) ou em pé virado para `normal`.
## o: inner, normal, mode (RING), noise, soft, boost, fade_in, fade_out, follow.
func ring(at: Vector3, r0: float, r1: float, col: Color, secs: float, o := {}) -> Fx3DMesh:
	var m := Fx3DMesh.make(
		Fx3D.annulus(float(o.get("inner", 0.72))),
		Fx3D.mesh_mat(
			Fx3D.Mode.RING,
			float(o.get("boost", 2.0)),
			float(o.get("noise", 0.0)),
			float(o.get("soft", 1.0))
		),
		col
	)
	m.life = secs
	m.s0 = Vector3.ONE * maxf(r0, 0.01)
	m.s1 = Vector3.ONE * maxf(r1, 0.01)
	m.fade_in = float(o.get("fade_in", 0.05))
	m.fade_out = float(o.get("fade_out", 0.6))
	var b := Basis()
	var nrm: Vector3 = o.get("normal", Vector3.UP)
	if nrm != Vector3.UP:
		b = Fx3D.basis_y(nrm)
	if o.has("spin"):
		m.spin = Vector3(0, float(o.spin), 0)
	_add(m)
	m.place(at, b)
	if o.get("follow") != null:
		m.follow = o.follow
		m.follow_off = o.get("off", Vector3.ZERO)
	return m


## Casca de energia (esfera com borda brilhante): explosão, escudo, orbe.
func shell(at: Vector3, r0: float, r1: float, col: Color, secs: float, o := {}) -> Fx3DMesh:
	var m := Fx3DMesh.make(
		o.get("mesh", Fx3D.sphere()),
		Fx3D.mesh_mat(
			Fx3D.Mode.SHELL,
			float(o.get("boost", 2.0)),
			float(o.get("noise", 0.0)),
			float(o.get("soft", 1.0))
		),
		col
	)
	m.life = secs
	m.s0 = o.get("s0v", Vector3.ONE * maxf(r0, 0.01))
	m.s1 = o.get("s1v", Vector3.ONE * maxf(r1, 0.01))
	m.fade_in = float(o.get("fade_in", 0.05))
	m.fade_out = float(o.get("fade_out", 0.6))
	m.phase_speed = float(o.get("phase", 1.0))
	if o.has("spin"):
		m.spin = o.spin if o.spin is Vector3 else Vector3(0, float(o.spin), 0)
	_add(m)
	m.place(at, o.get("basis", Basis()))
	if o.get("follow") != null:
		m.follow = o.follow
		m.follow_off = o.get("off", Vector3.ZERO)
	return m


## Feixe: tubo de `from` na direção `dir`, `length` m, raio `r`. Modo BEAM (ruído correndo).
func tube(
	from: Vector3, dir: Vector3, length: float, r: float, col: Color, secs: float, o := {}
) -> Fx3DMesh:
	var m := Fx3DMesh.make(
		Fx3D.tube(),
		Fx3D.mesh_mat(
			int(o.get("mode", Fx3D.Mode.BEAM)),
			float(o.get("boost", 2.2)),
			float(o.get("noise", 0.6)),
			float(o.get("soft", 1.0))
		),
		col
	)
	m.life = secs
	m.s0 = Vector3(
		r * float(o.get("w0", 0.3)), length * float(o.get("l0", 1.0)), r * float(o.get("w0", 0.3))
	)
	m.s1 = Vector3(r, length, r)
	m.fade_in = float(o.get("fade_in", 0.12))
	m.fade_out = float(o.get("fade_out", 0.35))
	m.phase_speed = float(o.get("phase", 1.0))
	m.grow_ease = true
	_add(m)
	m.place(from, Fx3D.basis_y(dir))
	return m


## Raio elétrico de `a` até `b` (re-sorteia o zigue-zague a cada `every` s). o: segs, amp, branches,
## core (fita branca de dentro), a_fn/b_fn (Callable -> Vector3 que movem as pontas).
func bolt(a: Vector3, b: Vector3, col: Color, width: float, secs: float, o := {}) -> Array:
	var out: Array = []
	var segs := int(o.get("segs", maxi(int(a.distance_to(b) / 0.35), 4)))
	var amp := float(o.get("amp", clampf(a.distance_to(b) * 0.08, 0.08, 0.9)))
	var a_fn: Callable = o.get("a_fn", Callable())
	var b_fn: Callable = o.get("b_fn", Callable())
	var every := float(o.get("every", 0.04))
	var c := cam()
	var layers := [[col, width * 2.6, 1.0], [Color(1, 1, 1, col.a), width * 0.7, 1.0]]
	if not o.get("core", true):
		layers = [[col, width * 2.0, 1.0]]
	var shared := {"pts": PackedVector3Array(), "t": -1.0}
	for L in layers:
		var r := Fx3DRibbon.make(
			Fx3D.mesh_mat(Fx3D.Mode.RIBBON, float(o.get("boost", 3.0))), L[0], L[1], secs, c
		)
		r.fade_in = 0.0
		r.fade_out = float(o.get("fade_out", 0.4))
		r.jitter_every = every
		r.shape = func(rb: Fx3DRibbon, _k: float) -> void:
			if shared.t != rb.age:
				var pa: Vector3 = a_fn.call() if a_fn.is_valid() else a
				var pb: Vector3 = b_fn.call() if b_fn.is_valid() else b
				var cd := (cam_pos(pa) - pa).normalized()
				shared.pts = Fx3DRibbon.jag(pa, pb, segs, amp, cd)
				shared.t = rb.age
			rb.pts = shared.pts
		_add(r)
		r.shape.call(r, 0.0)
		r.rebuild()
		out.append(r)
	var nb := int(o.get("branches", 0))
	for i in nb:
		var k0 := randf_range(0.2, 0.75)
		var pa := a.lerp(b, k0)
		var pb := (
			pa
			+ (
				(b - a).normalized().rotated(rand_dir(), randf_range(0.4, 1.0))
				* a.distance_to(b)
				* randf_range(0.15, 0.35)
			)
		)
		var r2 := Fx3DRibbon.make(
			Fx3D.mesh_mat(Fx3D.Mode.RIBBON, 2.5), col, width * 1.2, secs * randf_range(0.4, 0.9), c
		)
		r2.pts = Fx3DRibbon.jag(pa, pb, 5, amp * 0.6, (cam_pos(pa) - pa).normalized())
		r2.fade_in = 0.0
		_add(r2)
		r2.rebuild()
		out.append(r2)
	return out


## Corte em arco: fita que varre de `a0` a `a1` (graus) em volta do eixo `axis`, raio `r`, centro `at`,
## começando na direção `start` (perpendicular ao eixo). sweep = fração da vida para varrer.
func slash(
	at: Vector3,
	axis: Vector3,
	start: Vector3,
	r: float,
	arc_deg: float,
	col: Color,
	width: float,
	secs: float,
	o := {}
) -> Fx3DRibbon:
	var c := cam()
	var rb := Fx3DRibbon.make(
		Fx3D.mesh_mat(Fx3D.Mode.RIBBON, float(o.get("boost", 2.6)), 0.0, 0.7), col, width, secs, c
	)
	rb.fade_in = 0.0
	rb.fade_out = float(o.get("fade_out", 0.55))
	var sweep := float(o.get("sweep", 0.4))
	var n := 18
	var ax := axis.normalized()
	var st := start.normalized()
	var tail := float(o.get("tail", 0.75))
	rb.shape = func(rbb: Fx3DRibbon, k: float) -> void:
		var head := clampf(k / maxf(sweep, 0.01), 0.0, 1.0)
		var p := PackedVector3Array()
		var w := PackedFloat32Array()
		var al := PackedFloat32Array()
		for i in n:
			var u := float(i) / (n - 1)
			var f := lerpf(maxf(head - tail, 0.0), head, u)
			var ang := deg_to_rad(arc_deg) * (f - 0.5)
			p.append(at + st.rotated(ax, ang) * r)
			w.append(width * sin(u * PI * 0.5 + 0.0001) * (0.4 + 0.6 * u))
			al.append(u)
		rbb.pts = p
		rbb.widths = w
		rbb.alphas = al
	_add(rb)
	rb.shape.call(rb, 0.0)
	rb.rebuild()
	return rb


## Pedra/cristal/folha de verdade voando (sombreado). o: kind, col, emit, size, vel, grav, spin, life.
func solid(at: Vector3, o: Dictionary) -> Fx3DMesh:
	var m := Fx3DMesh.make_solid(
		Fx3D.solid(String(o.get("kind", "rock"))),
		o.get("col", Color(0.55, 0.47, 0.38)),
		float(o.get("emit", 0.0)),
		float(o.get("metal", 0.0))
	)
	var s := float(o.get("size", 0.3))
	m.life = float(o.get("life", 1.0))
	m.s0 = Vector3.ONE * s * float(o.get("grow0", 1.0))
	m.s1 = Vector3.ONE * s
	m.fade_in = float(o.get("fade_in", 0.0))
	m.fade_out = float(o.get("fade_out", 0.25))
	m.vel = o.get("vel", Vector3.ZERO)
	m.gravity = float(o.get("grav", 0.0))
	m.floor_y = floor_y() + s * 0.3 if o.get("floor", true) else -INF
	var sp := float(o.get("spin", 6.0))
	m.spin = Vector3(randf_range(-sp, sp), randf_range(-sp, sp), randf_range(-sp, sp))
	if o.has("on_floor"):
		m.on_floor = o.on_floor
	_add(m)
	m.place(at, o.get("basis", Basis.from_euler(rand_dir() * PI)))
	if o.get("follow") != null:
		m.follow = o.follow
		m.follow_off = o.get("off", Vector3.ZERO)
	return m


## Tremor da câmera (h/v_offset), some sozinho.
func shake(amp: float, secs: float) -> void:
	vfx.shake(amp, secs)


## Clarão: um brilho grande e curto (sem luz).
func flash(at: Vector3, size: float, col: Color, secs := 0.18) -> void:
	burst(
		at,
		{
			"n": 1,
			"speed": [0.0, 0.0],
			"life": [secs, secs],
			"size": [size * 0.6, size * 1.3],
			"col": [col, col],
			"fade_in": 0.0,
			"fade_out": 0.8,
			"boost": 3.0
		}
	)


# --- Matéria de cada tipo ---


## Partículas do tipo saindo de `at`: n, dir (eixo, ZERO = todo lado), spread, speed, k (escala).
## É o que dá cara a cada tipo em impacto, rastro, carga e área.
func element(type: String, at: Vector3, n: int, o := {}) -> void:
	var k := float(o.get("k", 1.0))
	var dir: Vector3 = o.get("dir", Vector3.ZERO)
	var spread := float(o.get("spread", 0.7))
	var sp: Array = o.get("speed", [1.5 * k, 4.5 * k])
	var r := float(o.get("r", 0.0))
	var base := {"dir": dir, "spread": spread, "speed": sp, "r": r}
	match type:
		"fire":
			burst(
				at,
				_m(
					base,
					{
						"n": n,
						"shape": Fx3D.Shape.EMBER,
						"life": [0.3, 0.7],
						"size": [0.32 * k, 0.08 * k],
						"col": [core(type), deep(type, 0.0)],
						"up": 1.4,
						"drag": 1.5,
						"turb": 6.0
					}
				)
			)
			burst(
				at,
				_m(
					base,
					{
						"n": n / 3,
						"shape": Fx3D.Shape.SMOKE,
						"add": false,
						"life": [0.6, 1.1],
						"size": [0.3 * k, 0.9 * k],
						"col": [Color(0.22, 0.18, 0.16, 0.55), Color(0.1, 0.1, 0.1, 0.0)],
						"up": 1.2,
						"drag": 2.0,
						"speed": [0.3, 1.2]
					}
				)
			)
		"water":
			burst(
				at,
				_m(
					base,
					{
						"n": n,
						"shape": Fx3D.Shape.SPARK,
						"stretch": 0.05,
						"life": [0.35, 0.7],
						"size": [0.13 * k, 0.07 * k],
						"col": [core(type), mid(type, 0.6)],
						"grav": 9.0,
						"up": 1.5
					}
				)
			)
			burst(
				at,
				_m(
					base,
					{
						"n": n / 3,
						"shape": Fx3D.Shape.BUBBLE,
						"add": false,
						"life": [0.4, 0.8],
						"size": [0.12 * k, 0.2 * k],
						"col": [Color(0.8, 0.95, 1.0, 0.8), Color(0.8, 0.95, 1.0, 0.0)],
						"drag": 2.0,
						"up": 0.6
					}
				)
			)
		"electric":
			burst(
				at,
				_m(
					base,
					{
						"n": n,
						"shape": Fx3D.Shape.SPARK,
						"stretch": 0.04,
						"life": [0.12, 0.3],
						"size": [0.09 * k, 0.04 * k],
						"col": [Color.WHITE, mid(type)],
						"speed": [sp[0] * 1.8, sp[1] * 2.0],
						"drag": 3.0,
						"boost": 3.0
					}
				)
			)
			var c0 := at
			for i in clampi(n / 6, 1, 5):
				var e := c0 + rand_dir() * randf_range(0.4, 0.9) * k
				bolt(
					c0,
					e,
					mid(type),
					0.035 * k,
					randf_range(0.1, 0.2),
					{"segs": 5, "amp": 0.12 * k, "core": false}
				)
		"grass":
			burst(
				at,
				_m(
					base,
					{
						"n": n / 2 + 1,
						"shape": Fx3D.Shape.TEX,
						"tex": LEAF,
						"add": false,
						"life": [0.5, 0.9],
						"size": [0.3 * k, 0.24 * k],
						"col": [Color.WHITE, Color(1, 1, 1, 0.9)],
						"spin": 8.0,
						"drag": 2.0,
						"grav": 1.5
					}
				)
			)
			burst(
				at,
				_m(
					base,
					{
						"n": n / 2,
						"shape": Fx3D.Shape.GLOW,
						"life": [0.3, 0.6],
						"size": [0.14 * k, 0.04 * k],
						"col": [core(type), mid(type, 0.0)],
						"drag": 2.0
					}
				)
			)
		"ice":
			for i in clampi(n / 4, 1, 8):
				solid(
					at,
					{
						"kind": "shard",
						"col": Color(0.75, 0.93, 1.0, 0.85),
						"emit": 1.2,
						"size": randf_range(0.18, 0.32) * k,
						"vel":
						(
							(cone_dir(dir, spread) if dir != Vector3.ZERO else rand_dir())
							* randf_range(sp[0], sp[1])
						),
						"grav": 6.0,
						"life": randf_range(0.4, 0.7)
					}
				)
			burst(
				at,
				_m(
					base,
					{
						"n": n,
						"shape": Fx3D.Shape.STAR,
						"life": [0.3, 0.6],
						"size": [0.18 * k, 0.05 * k],
						"col": [Color.WHITE, mid(type, 0.0)],
						"drag": 2.5
					}
				)
			)
			burst(
				at,
				_m(
					base,
					{
						"n": n / 3,
						"shape": Fx3D.Shape.TEX,
						"tex": SNOW,
						"add": false,
						"life": [0.5, 1.0],
						"size": [0.2 * k, 0.16 * k],
						"col": [Color.WHITE, Color(1, 1, 1, 0.8)],
						"spin": 3.0,
						"drag": 2.0,
						"grav": 0.8,
						"speed": [0.4, 1.6]
					}
				)
			)
		"fighting":
			burst(
				at,
				_m(
					base,
					{
						"n": n,
						"shape": Fx3D.Shape.SPARK,
						"stretch": 0.05,
						"life": [0.15, 0.35],
						"size": [0.12 * k, 0.05 * k],
						"col": [core(type), mid(type, 0.0)],
						"speed": [sp[0] * 1.5, sp[1] * 1.6],
						"drag": 3.0
					}
				)
			)
			burst(
				at,
				_m(
					base,
					{
						"n": n / 4 + 1,
						"shape": Fx3D.Shape.STAR,
						"life": [0.2, 0.35],
						"size": [0.5 * k, 0.15 * k],
						"col": [core(type), mid(type, 0.0)],
						"speed": [0.5, 1.5]
					}
				)
			)
		"poison":
			burst(
				at,
				_m(
					base,
					{
						"n": n,
						"shape": Fx3D.Shape.BUBBLE,
						"add": false,
						"life": [0.4, 0.9],
						"size": [0.12 * k, 0.26 * k],
						"col": [mid(type, 0.9), deep(type, 0.0)],
						"up": 0.8,
						"drag": 2.0
					}
				)
			)
			burst(
				at,
				_m(
					base,
					{
						"n": n / 2,
						"shape": Fx3D.Shape.GLOW,
						"life": [0.3, 0.6],
						"size": [0.22 * k, 0.05 * k],
						"col": [accent(type, 0.8), mid(type, 0.0)],
						"grav": 6.0
					}
				)
			)
		"ground":
			burst(
				at,
				_m(
					base,
					{
						"n": n / 2 + 1,
						"shape": Fx3D.Shape.SMOKE,
						"add": false,
						"life": [0.6, 1.2],
						"size": [0.4 * k, 1.1 * k],
						"col": [Color(0.78, 0.66, 0.48, 0.75), Color(0.6, 0.5, 0.38, 0.0)],
						"drag": 2.5,
						"up": 0.6,
						"speed": [sp[0] * 0.6, sp[1] * 0.6]
					}
				)
			)
			for i in clampi(n / 5, 1, 6):
				solid(
					at,
					{
						"kind": "rock",
						"col": Color(0.5, 0.36, 0.22),
						"size": randf_range(0.08, 0.16) * k,
						"vel":
						(
							(
								(
									cone_dir(dir, spread)
									if dir != Vector3.ZERO
									else cone_dir(Vector3.UP, 1.0)
								)
								* randf_range(sp[0], sp[1])
							)
							+ Vector3(0, 2.0, 0)
						),
						"grav": 12.0,
						"life": 0.9
					}
				)
		"rock":
			for i in clampi(n / 4, 1, 7):
				solid(
					at,
					{
						"kind": "rock",
						"col": Color(0.58, 0.5, 0.4),
						"size": randf_range(0.12, 0.26) * k,
						"vel":
						(
							(
								(
									cone_dir(dir, spread)
									if dir != Vector3.ZERO
									else cone_dir(Vector3.UP, 1.1)
								)
								* randf_range(sp[0], sp[1])
							)
							+ Vector3(0, 2.5, 0)
						),
						"grav": 14.0,
						"life": 1.0
					}
				)
			burst(
				at,
				_m(
					base,
					{
						"n": n / 2,
						"shape": Fx3D.Shape.SMOKE,
						"add": false,
						"life": [0.5, 1.0],
						"size": [0.35 * k, 0.9 * k],
						"col": [Color(0.7, 0.64, 0.55, 0.7), Color(0.6, 0.55, 0.5, 0.0)],
						"drag": 2.5,
						"speed": [sp[0] * 0.5, sp[1] * 0.5]
					}
				)
			)
		"flying":
			burst(
				at,
				_m(
					base,
					{
						"n": n,
						"shape": Fx3D.Shape.SPARK,
						"stretch": 0.09,
						"life": [0.2, 0.4],
						"size": [0.07 * k, 0.03 * k],
						"col": [Color(1, 1, 1, 0.9), mid(type, 0.0)],
						"speed": [sp[0] * 1.6, sp[1] * 1.8],
						"drag": 2.0
					}
				)
			)
			burst(
				at,
				_m(
					base,
					{
						"n": n / 4 + 1,
						"shape": Fx3D.Shape.TEX,
						"tex": "feather",
						"add": false,
						"life": [0.6, 1.0],
						"size": [0.26 * k, 0.22 * k],
						"col": [Color.WHITE, Color(1, 1, 1, 0.8)],
						"spin": 5.0,
						"drag": 3.0,
						"grav": 1.0,
						"speed": [0.6, 2.0]
					}
				)
			)
		"psychic":
			burst(
				at,
				_m(
					base,
					{
						"n": n / 3 + 1,
						"shape": Fx3D.Shape.RING,
						"life": [0.3, 0.55],
						"size": [0.1 * k, 0.6 * k],
						"col": [mid(type), accent(type, 0.0)],
						"speed": [0.2, 1.0]
					}
				)
			)
			burst(
				at,
				_m(
					base,
					{
						"n": n,
						"shape": Fx3D.Shape.GLOW,
						"life": [0.3, 0.6],
						"size": [0.16 * k, 0.04 * k],
						"col": [core(type), mid(type, 0.0)],
						"drag": 2.0
					}
				)
			)
		"bug":
			burst(
				at,
				_m(
					base,
					{
						"n": n,
						"shape": Fx3D.Shape.GLOW,
						"life": [0.3, 0.7],
						"size": [0.12 * k, 0.03 * k],
						"col": [core(type), mid(type, 0.0)],
						"drag": 1.5,
						"turb": 14.0
					}
				)
			)
			burst(
				at,
				_m(
					base,
					{
						"n": n / 2,
						"shape": Fx3D.Shape.SPARK,
						"stretch": 0.05,
						"life": [0.15, 0.3],
						"size": [0.06 * k, 0.02 * k],
						"col": [Color.WHITE, mid(type, 0.0)],
						"drag": 3.0
					}
				)
			)
		"ghost":
			burst(
				at,
				_m(
					base,
					{
						"n": n,
						"shape": Fx3D.Shape.SMOKE,
						"life": [0.5, 1.0],
						"size": [0.25 * k, 0.7 * k],
						"col": [mid(type, 0.8), deep(type, 0.0)],
						"drag": 2.0,
						"up": 0.8,
						"turb": 4.0
					}
				)
			)
			burst(
				at,
				_m(
					base,
					{
						"n": n / 3,
						"shape": Fx3D.Shape.GLOW,
						"life": [0.3, 0.6],
						"size": [0.16 * k, 0.04 * k],
						"col": [accent(type), mid(type, 0.0)]
					}
				)
			)
		"dragon":
			burst(
				at,
				_m(
					base,
					{
						"n": n,
						"shape": Fx3D.Shape.EMBER,
						"life": [0.3, 0.6],
						"size": [0.28 * k, 0.06 * k],
						"col": [core(type), mid(type, 0.0)],
						"col2": [accent(type), deep(type, 0.0)],
						"drag": 2.0,
						"turb": 5.0
					}
				)
			)
			burst(
				at,
				_m(
					base,
					{
						"n": n / 3,
						"shape": Fx3D.Shape.STAR,
						"life": [0.2, 0.4],
						"size": [0.3 * k, 0.1 * k],
						"col": [accent(type), mid(type, 0.0)]
					}
				)
			)
		"dark":
			burst(
				at,
				_m(
					base,
					{
						"n": n,
						"shape": Fx3D.Shape.SMOKE,
						"add": false,
						"life": [0.5, 1.0],
						"size": [0.3 * k, 0.8 * k],
						"col": [Color(0.1, 0.04, 0.14, 0.85), Color(0.05, 0.0, 0.08, 0.0)],
						"drag": 2.5,
						"turb": 3.0
					}
				)
			)
			burst(
				at,
				_m(
					base,
					{
						"n": n / 2,
						"shape": Fx3D.Shape.SPARK,
						"stretch": 0.05,
						"life": [0.15, 0.3],
						"size": [0.08 * k, 0.03 * k],
						"col": [accent(type), mid(type, 0.0)],
						"drag": 3.0,
						"speed": [sp[0] * 1.5, sp[1] * 1.5]
					}
				)
			)
		"steel":
			burst(
				at,
				_m(
					base,
					{
						"n": n,
						"shape": Fx3D.Shape.SPARK,
						"stretch": 0.06,
						"life": [0.15, 0.4],
						"size": [0.07 * k, 0.03 * k],
						"col": [Color.WHITE, accent(type, 0.0)],
						"grav": 9.0,
						"speed": [sp[0] * 1.6, sp[1] * 1.8]
					}
				)
			)
			burst(
				at,
				_m(
					base,
					{
						"n": n / 4 + 1,
						"shape": Fx3D.Shape.STAR,
						"life": [0.2, 0.4],
						"size": [0.4 * k, 0.1 * k],
						"col": [Color.WHITE, mid(type, 0.0)],
						"speed": [0.2, 1.0]
					}
				)
			)
		"fairy":
			burst(
				at,
				_m(
					base,
					{
						"n": n,
						"shape": Fx3D.Shape.STAR,
						"life": [0.35, 0.7],
						"size": [0.22 * k, 0.05 * k],
						"col": [core(type), mid(type, 0.0)],
						"drag": 2.0
					}
				)
			)
			burst(
				at,
				_m(
					base,
					{
						"n": n / 4 + 1,
						"shape": Fx3D.Shape.TEX,
						"tex": "heart",
						"add": false,
						"life": [0.5, 0.9],
						"size": [0.24 * k, 0.2 * k],
						"col": [mid(type), Color(1, 0.7, 0.9, 0.0)],
						"drag": 2.0,
						"up": 0.8
					}
				)
			)
		_:
			burst(
				at,
				_m(
					base,
					{
						"n": n,
						"shape": Fx3D.Shape.STAR,
						"life": [0.2, 0.45],
						"size": [0.24 * k, 0.05 * k],
						"col": [Color.WHITE, mid(type, 0.0)],
						"drag": 2.5
					}
				)
			)
			burst(
				at,
				_m(
					base,
					{
						"n": n / 2,
						"shape": Fx3D.Shape.SPARK,
						"stretch": 0.05,
						"life": [0.12, 0.3],
						"size": [0.08 * k, 0.03 * k],
						"col": [Color.WHITE, core(type, 0.0)],
						"drag": 3.0
					}
				)
			)


static func _m(a: Dictionary, b: Dictionary) -> Dictionary:
	var o := a.duplicate()
	o.merge(b, true)
	return o


## Opções de partícula da matéria do tipo para emissores contínuos (rastro, jorro, aura).
func trail_opts(type: String, k := 1.0) -> Dictionary:
	match type:
		"fire":
			return {
				"shape": Fx3D.Shape.EMBER,
				"life": [0.25, 0.5],
				"size": [0.3 * k, 0.06 * k],
				"col": [core(type), deep(type, 0.0)],
				"up": 1.0,
				"turb": 4.0,
				"drag": 1.0
			}
		"water":
			return {
				"shape": Fx3D.Shape.SPARK,
				"stretch": 0.04,
				"life": [0.25, 0.45],
				"size": [0.12 * k, 0.05 * k],
				"col": [core(type), mid(type, 0.0)],
				"grav": 6.0
			}
		"electric":
			return {
				"shape": Fx3D.Shape.SPARK,
				"stretch": 0.03,
				"life": [0.1, 0.22],
				"size": [0.08 * k, 0.03 * k],
				"col": [Color.WHITE, mid(type, 0.0)],
				"turb": 30.0,
				"boost": 3.0
			}
		"grass":
			return {
				"shape": Fx3D.Shape.TEX,
				"tex": LEAF,
				"add": false,
				"life": [0.35, 0.6],
				"size": [0.22 * k, 0.16 * k],
				"col": [Color.WHITE, Color(1, 1, 1, 0.8)],
				"spin": 8.0
			}
		"ice":
			return {
				"shape": Fx3D.Shape.STAR,
				"life": [0.3, 0.6],
				"size": [0.16 * k, 0.04 * k],
				"col": [Color.WHITE, mid(type, 0.0)],
				"grav": 0.5
			}
		"poison":
			return {
				"shape": Fx3D.Shape.BUBBLE,
				"add": false,
				"life": [0.3, 0.6],
				"size": [0.1 * k, 0.2 * k],
				"col": [mid(type, 0.9), deep(type, 0.0)],
				"up": 0.5
			}
		"ground", "rock":
			return {
				"shape": Fx3D.Shape.SMOKE,
				"add": false,
				"life": [0.4, 0.8],
				"size": [0.25 * k, 0.6 * k],
				"col": [Color(0.78, 0.66, 0.5, 0.6), Color(0.6, 0.5, 0.4, 0.0)],
				"drag": 2.0,
				"up": 0.4
			}
		"ghost":
			return {
				"shape": Fx3D.Shape.SMOKE,
				"life": [0.4, 0.8],
				"size": [0.22 * k, 0.5 * k],
				"col": [mid(type, 0.7), deep(type, 0.0)],
				"turb": 3.0,
				"up": 0.3
			}
		"dark":
			return {
				"shape": Fx3D.Shape.SMOKE,
				"add": false,
				"life": [0.4, 0.8],
				"size": [0.22 * k, 0.55 * k],
				"col": [Color(0.12, 0.05, 0.16, 0.8), Color(0.05, 0.0, 0.08, 0.0)],
				"turb": 3.0
			}
		"dragon":
			return {
				"shape": Fx3D.Shape.EMBER,
				"life": [0.25, 0.5],
				"size": [0.26 * k, 0.05 * k],
				"col": [core(type), mid(type, 0.0)],
				"col2": [accent(type), deep(type, 0.0)],
				"turb": 4.0
			}
		"psychic":
			return {
				"shape": Fx3D.Shape.GLOW,
				"life": [0.3, 0.5],
				"size": [0.2 * k, 0.04 * k],
				"col": [mid(type), accent(type, 0.0)]
			}
		"fairy":
			return {
				"shape": Fx3D.Shape.STAR,
				"life": [0.3, 0.6],
				"size": [0.18 * k, 0.04 * k],
				"col": [core(type), mid(type, 0.0)]
			}
		"flying":
			return {
				"shape": Fx3D.Shape.SPARK,
				"stretch": 0.08,
				"life": [0.15, 0.3],
				"size": [0.06 * k, 0.02 * k],
				"col": [Color(1, 1, 1, 0.8), mid(type, 0.0)]
			}
		"steel":
			return {
				"shape": Fx3D.Shape.SPARK,
				"stretch": 0.05,
				"life": [0.12, 0.3],
				"size": [0.06 * k, 0.02 * k],
				"col": [Color.WHITE, accent(type, 0.0)],
				"grav": 4.0
			}
		"bug":
			return {
				"shape": Fx3D.Shape.GLOW,
				"life": [0.25, 0.5],
				"size": [0.12 * k, 0.03 * k],
				"col": [core(type), mid(type, 0.0)],
				"turb": 10.0
			}
		"fighting":
			return {
				"shape": Fx3D.Shape.GLOW,
				"life": [0.2, 0.4],
				"size": [0.24 * k, 0.05 * k],
				"col": [core(type), mid(type, 0.0)]
			}
	return {
		"shape": Fx3D.Shape.GLOW,
		"life": [0.2, 0.4],
		"size": [0.2 * k, 0.04 * k],
		"col": [Color.WHITE, mid(type, 0.0)]
	}

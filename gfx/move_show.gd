class_name MoveShow
extends RefCounted
## Espetáculo de cada golpe por cima dos efeitos PMD: rastro de investida (fantasmas, linhas de
## velocidade, poeira), cortes/garras/presas/punhos desenhados, partículas do tipo, anéis no chão,
## pedras caindo, nuvem antes do raio, ondas de som, corações, escudos, auras e o Cavar.
## Lê o "look" de cada golpe em data/move_fx.json (moves.<id>.look) com padrões pelo kind/tipo.
## Só visual: nada aqui muda dano, alcance ou tempo. Tudo entra em BattleVfx.nodes (tick(dt)).

const GROUND_Y := 0.06
const PX := "res://assets/pixellab/"
## Partícula de cada tipo: textura, cor, aditivo, gravidade (m/s²), subida (m/s), tamanho (m), giro.
const STYLE := {
	"normal": {"tex": "star4", "col": [1.0, 1.0, 0.95], "add": true, "sz": 0.3},
	"fire":
	{"tex": "dot", "col": [1.0, 0.5, 0.1], "col2": [1.0, 0.88, 0.3], "add": true, "rise": 1.6},
	"water": {"tex": "drop", "col": [0.5, 0.78, 1.0], "grav": 9.0, "sz": 0.26},
	"electric": {"tex": "star4", "col": [1.0, 0.95, 0.35], "add": true, "sz": 0.34},
	"grass":
	{"tex": PX + "fx/leaf.png", "col": [1.0, 1.0, 1.0], "sz": 0.32, "spin": 7.0, "grav": 1.5},
	"ice": {"tex": PX + "fx/snowflake.png", "col": [0.85, 0.95, 1.0], "sz": 0.34, "spin": 3.0},
	"fighting": {"tex": "star4", "col": [1.0, 0.55, 0.25], "add": true, "sz": 0.34},
	"poison": {"tex": PX + "fx/bubble.png", "col": [0.8, 0.45, 1.0], "sz": 0.24, "rise": 0.9},
	"ground": {"tex": "clod", "col": [1.0, 1.0, 1.0], "grav": 10.0, "sz": 0.22, "spin": 6.0},
	"flying": {"tex": "feather", "col": [1.0, 1.0, 1.0], "sz": 0.3, "grav": 1.0, "spin": 4.0},
	"psychic": {"tex": "ring", "col": [1.0, 0.45, 0.85], "add": true, "sz": 0.36},
	"bug": {"tex": "dot", "col": [0.7, 0.9, 0.2], "add": true, "sz": 0.22},
	"rock":
	{
		"tex": PX + "objects/debris_rock.png",
		"col": [1.0, 1.0, 1.0],
		"grav": 10.0,
		"sz": 0.36,
		"spin": 5.0
	},
	"ghost": {"tex": "dot", "col": [0.55, 0.35, 0.9], "add": true, "rise": 1.2},
	"dragon": {"tex": "dot", "col": [0.55, 0.42, 1.0], "col2": [0.4, 0.75, 1.0], "add": true},
	"dark": {"tex": "dot", "col": [0.28, 0.16, 0.34], "rise": 0.6, "sz": 0.3},
	"steel": {"tex": "star4", "col": [0.85, 0.92, 1.0], "add": true, "sz": 0.32},
	"fairy": {"tex": "heart", "col": [1.0, 0.6, 0.85], "sz": 0.3, "rise": 1.0},
}
## Ícones: gerados em código (ProcFx) ou do Pixel Lab já baixados (assets/pixellab/icons).
const ICONS := {
	"heart": "heart",
	"note": "note",
	"moon": "moon",
	"star": "star5",
	"arrow": "arrow",
	"spike": "spike",
	"fang": "fang",
	"claw": "claw",
	"shield": PX + "icons/cmd_defensivo.png",
	"swords": PX + "icons/cmd_ofensivo.png",
	"wings": PX + "icons/cmd_livre.png",
	"heal": PX + "icons/cmd_suporte.png",
	"drop": PX + "icons/mark_wet.png",
	"flame": PX + "icons/mark_burning.png",
	"flower": PX + "icons/mark_pollen.png",
	"swirl": PX + "icons/mark_psy.png",
	"snow": PX + "icons/mark_slow.png",
	"rocks": PX + "icons/mark_dust.png",
	"bolt": PX + "icons/sync.png",
	"fist": PX + "icons/mark_down.png",
}
## Ícone padrão de quem sobe/desce cada estágio.
const STAT_ICON := {
	"atk": "swords", "def": "shield", "spa": "bolt", "spd": "shield", "spe": "wings", "crit": "star"
}
const STAT_COL := {
	"atk": Color(1.0, 0.4, 0.3),
	"def": Color(0.4, 0.65, 1.0),
	"spa": Color(0.8, 0.45, 1.0),
	"spd": Color(0.45, 0.9, 0.55),
	"spe": Color(1.0, 0.9, 0.3),
	"acc": Color(0.95, 0.95, 0.95),
	"eva": Color(1.0, 0.6, 0.85),
	"crit": Color(1.0, 0.55, 0.3),
}

const LAND_SHAPES := [
	"quake",
	"burst",
	"ring",
	"rocks",
	"powder",
	"notes",
	"pillar",
	"splash",
	"vortex",
	"hearts",
	"sparkles",
	"fire",
	"sludge",
	"flash",
	"sound",
	"bolt",
	"shock",
	"spikes",
	"dust",
	"cloud",
	"petals",
	"edges"
]

## Nomes válidos de cada chave do look (o teste confere o move_fx.json contra isto).
const VOCAB := {
	"cast":
	[
		"aura",
		"icon",
		"shield",
		"heal",
		"charge",
		"sound",
		"hearts",
		"notes",
		"sparkles",
		"spin",
		"smoke",
		"glow",
		"stomp",
		"wind",
		"flames",
		"dance",
		"metal",
		"emanate",
		"dust",
		"drain_self",
		"rain",
		"zone_here",
		"gravity",
		"storm",
		"powder",
		"feathers",
		"splash",
		"beam_down",
		"shatter"
	],
	"swing":
	[
		"slash",
		"tail",
		"slap",
		"chop",
		"x",
		"claw",
		"fang",
		"fist",
		"kick",
		"jab",
		"horn",
		"sting",
		"wing",
		"spin",
		"hearts",
		"rough",
		"burst",
		"pellets"
	],
	"trail":
	[
		"speed",
		"spin",
		"fire",
		"water",
		"spark",
		"normal",
		"grass",
		"electric",
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
		"fairy",
		"sparkle"
	],
	"proj":
	[
		"fire",
		"spark",
		"sparkle",
		"heart",
		"note",
		"glow",
		"smoke",
		"water",
		"wind",
		"none",
		"normal",
		"grass",
		"electric",
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
	],
	"pre": ["cloud", "rocks", "meteor", "powder", "notes", "glow", "hearts", "sparkles", "swirl"],
	"zone": ["vortex", "fire", "sand", "water", "cloud", "petals", "spikes", "grass", "sparkles"],
	"impact": ["dust", "crater", "drain", "splash", "sparks", "stars", "pillar", "fire", "shock"],
	"status_hit": ["flash", "hearts", "icon", "cloud", "web", "sparks", "rings", "fire", "pmd"],
	"to_targets": ["hearts", "notes", "feathers", "sparkles", "glare", "sound", "smoke", "wind"],
}

## BattleVfx dono (referência fraca: ele guarda este objeto, e um ciclo de RefCounted vazaria).
## Sorteio só dos efeitos: não mexe no randf() global que a jogabilidade usa.
static var _rng := RandomNumberGenerator.new()

var vfx: BattleVfx:
	get:
		return _vfx_ref.get_ref() as BattleVfx
var _vfx_ref: WeakRef
## Nós da chamada em curso (quem usa, alvo): os repeat() criados agora param sozinhos quando um
## deles é liberado, sem chamar o lambda que o capturou (o Godot reclamaria do nó liberado).
var ctx: Array = []
var _pending := {}  ## move_id -> {user, at, r} do golpe em área que ainda vai cair


func _init(v: BattleVfx) -> void:
	_vfx_ref = weakref(v)


# --- Infra ---


func _ok() -> bool:
	return vfx.enabled and vfx.arena.is_inside_tree()


func cam() -> Camera3D:
	return vfx.cam()


## Look do golpe (move_fx.json moves.<id>.look) com os padrões do kind/tipo por baixo.
func look(mv: Dictionary) -> Dictionary:
	var lk := _defaults(mv)
	var m = PmdFx.move_roles(String(mv.get("id", ""))).get("look")
	if m is Dictionary:
		for k in m:
			lk[k] = m[k]
	return lk


func _defaults(mv: Dictionary) -> Dictionary:
	var kind := String(mv.get("kind", ""))
	var type := String(mv.get("type", "normal"))
	var power := float(mv.get("power", 0))
	var lk := {}
	match kind:
		"dash":
			lk.trail = type
			lk.ghosts = float(mv.get("speed", 12.0)) >= 13.5 or int(mv.get("priority", 0)) > 0
		"arc", "multi_arc":
			lk.swing = (
				"fist"
				if type == "fighting"
				else ("claw" if type in ["steel", "dragon"] else "slash")
			)
		"aoe_self":
			lk.land = "quake" if type == "ground" else "burst"
		"aoe_target":
			lk.land = "burst" if power > 0.0 else "powder"
		"zone":
			lk.zone = "vortex"
		"self_buff":
			lk.cast = ["aura"]
		"debuff_aoe":
			lk.cast = ["emanate"]
	return lk


func col_of(mv: Dictionary, lk: Dictionary, key := "color") -> Color:
	var c = lk.get(key)
	if c is Array and (c as Array).size() >= 3:
		return Color(float(c[0]), float(c[1]), float(c[2]), float(c[3]) if c.size() > 3 else 1.0)
	return Dex.type_color(String(mv.get("type", "normal"))).lightened(0.15)


func _style(type: String) -> Dictionary:
	return STYLE.get(type, STYLE.normal)


static func _c(a: Array) -> Color:
	return Color(float(a[0]), float(a[1]), float(a[2]))


func _gpos(local: Vector3) -> Vector3:
	return vfx.arena.to_global(local)


func _gdir(local_dir: Vector3) -> Vector3:
	var d := vfx.arena.global_basis * local_dir
	d.y = 0.0
	return d.normalized() if d.length() > 0.001 else Vector3.FORWARD


func ground(at: Vector3) -> Vector3:
	return Vector3(at.x, vfx.arena.global_position.y + GROUND_Y, at.z)


func toward_cam(at: Vector3, k := 1.0) -> Vector3:
	return at + PmdFx.toward_camera(at, cam()) * k


func center(f: BattleFighter, k := 0.5) -> Vector3:
	return vfx._center(f, k)


## Ao lado da cabeça (o balão com o nome do golpe fica em cima).
func head_side(f: BattleFighter) -> Vector3:
	var c := cam()
	var right := c.global_basis.x if c else Vector3.RIGHT
	return center(f, 0.85) + right * maxf(0.55, f.visual_height() * 0.45) + Vector3(0, 0.1, 0)


func roll_of(dir_global: Vector3) -> float:
	var sd := PmdFx.screen_dir(dir_global, cam())
	return atan2(sd.y, sd.x)


## Peça solta no mundo (global). o: life, vel, grav, drag, grow (Vector2), pop, fade, fade_in, spin,
## add, face, roll, follow/follow_off, seek/seek_off/seek_speed, wobble, ground_y, flip_v, on_end.
func bit(tex: String, at: Vector3, size: float, col: Color, o := {}) -> ProcFx:
	if not _ok() or size <= 0.0:
		return null
	var f := ProcFx.make(
		tex, size, col, int(o.get("face", ProcFx.Face.BILLBOARD)), bool(o.get("add", false))
	)
	if f == null:
		return null
	_setup(f, o)
	return _add(f, at)


func _setup(f: ProcFx, o: Dictionary) -> void:
	f.life = float(o.get("life", 0.4))
	f.velocity = o.get("vel", Vector3.ZERO)
	f.gravity = float(o.get("grav", 0.0))
	f.drag = float(o.get("drag", 0.0))
	f.grow = o.get("grow", Vector2(1.0, 1.0))
	f.pop = float(o.get("pop", 0.0))
	f.fade = float(o.get("fade", 0.35))
	f.fade_in = float(o.get("fade_in", 0.0))
	f.spin = float(o.get("spin", 0.0))
	f.wobble = float(o.get("wobble", 0.0))
	f.ground_y = float(o.get("ground_y", -1000.0))
	if o.has("roll"):
		f._roll = float(o.roll)
		f._cam = cam()
	if o.has("follow"):
		f.follow = o.follow
		f.follow_off = o.get("follow_off", Vector3.ZERO)
	if o.has("seek"):
		f.seek = o.seek
		f.seek_off = o.get("seek_off", Vector3.ZERO)
		f.seek_speed = float(o.get("seek_speed", 6.0))
	if o.get("flip_v", false):
		f.spr.flip_v = true
	if o.get("flip_h", false):
		f.spr.flip_h = true
	if o.has("on_end"):
		f.on_end = o.on_end


func _add(f: ProcFx, at: Vector3) -> ProcFx:
	if not _ok():
		f.free()
		return null
	vfx.arena.add_child(f)
	f.global_position = at
	if f.follow:
		f.follow_off = at - f.follow.global_position if f.follow.is_inside_tree() else f.follow_off
	f._orient()
	vfx._track(f)
	return f


## Chama cb(i, idade) a cada `every` s por `dur` s (cb devolve false para parar); done no fim.
func repeat(every: float, dur: float, cb: Callable, done := Callable(), now := true) -> Ticker:
	if not _ok():
		return null
	var t := Ticker.new(every, dur, cb, done)
	t.watch = ctx.filter(func(o): return typeof(o) == TYPE_OBJECT)  # solto também: o Ticker para
	if now:
		t.acc = every
	vfx._track(t)
	return t


func later(delay: float, cb: Callable) -> void:
	if delay <= 0.0:
		cb.call()
		return
	repeat(
		delay,
		delay + 0.001,
		func(_i: int, _a: float) -> bool:
			cb.call()
			return false,
		Callable(),
		false
	)


# --- Peças compostas ---


func flash(at: Vector3, size: float, col := Color.WHITE, life := 0.16) -> void:
	var p := toward_cam(at)
	bit("star4", p, size, col, {"add": true, "life": life, "grow": Vector2(0.5, 1.5), "fade": 0.6})
	bit(
		"glow",
		p,
		size * 1.1,
		Color(1, 1, 1, 0.45),
		{"add": true, "life": life * 0.7, "grow": Vector2(0.7, 1.2)}
	)


func rays(at: Vector3, size: float, col: Color, life := 0.35) -> void:
	bit(
		"rays",
		toward_cam(at),
		size,
		col,
		{
			"add": true,
			"life": life,
			"grow": Vector2(0.4, 1.3),
			"fade": 0.5,
			"spin": 1.2,
			"face": ProcFx.Face.ROLL,
			"roll": _rng.randf() * TAU
		}
	)


func ring_ground(
	at: Vector3, r0: float, r1: float, col: Color, life := 0.45, tex := "ring"
) -> void:
	var size := 2.0 * r1 / 0.86
	bit(
		tex,
		ground(at),
		size,
		col,
		{
			"face": ProcFx.Face.GROUND,
			"life": life,
			"grow": Vector2(r0 / maxf(r1, 0.01), 1.0),
			"fade": 0.55,
			"add": true
		}
	)


func ring_air(at: Vector3, r0: float, r1: float, col: Color, life := 0.4) -> void:
	bit(
		"ring",
		toward_cam(at),
		2.0 * r1 / 0.86,
		col,
		{"life": life, "grow": Vector2(r0 / maxf(r1, 0.01), 1.0), "fade": 0.6, "add": true}
	)


## Explosão de partículas do tipo (n peças, velocidade m/s).
func burst(
	type: String, at: Vector3, n: int, speed := 3.0, size_k := 1.0, up := 0.6, col_over = null
) -> void:
	var st := _style(type)
	var c1 := _c(st.col) if col_over == null else Color(col_over)
	var c2 := _c(st.get("col2", st.col)) if col_over == null else Color(col_over).lightened(0.3)
	var icon := not (String(st.tex) in ["dot", "star4", "ring", "glow"])
	for i in n:
		var a := _rng.randf() * TAU
		var d := Vector3(cos(a), _rng.randf_range(-0.2, 1.0) * up + up * 0.4, sin(a)).normalized()
		var v := d * speed * _rng.randf_range(0.45, 1.0)
		v.y += float(st.get("rise", 0.0))
		bit(
			String(st.tex),
			toward_cam(at, 0.6),
			float(st.get("sz", 0.28)) * size_k * _rng.randf_range(0.7, 1.15),
			c1.lerp(c2, _rng.randf()),
			{
				"add": bool(st.get("add", false)),
				"vel": v,
				"grav": float(st.get("grav", 0.0)),
				"drag": 1.5,
				"life": _rng.randf_range(0.3, 0.55),
				"grow": Vector2(1.0, 1.0 if icon else 0.35),
				"spin": _rng.randf_range(-1.0, 1.0) * float(st.get("spin", 0.0)),
				"face": ProcFx.Face.ROLL if icon else ProcFx.Face.BILLBOARD,
				"roll": _rng.randf() * TAU,
			}
		)


func dust(at: Vector3, n: int, r := 0.6, col := Color(0.78, 0.68, 0.52, 0.8)) -> void:
	for i in n:
		var a := TAU * float(i) / float(maxi(n, 1)) + _rng.randf() * 0.4
		var p := ground(at) + Vector3(cos(a), 0.1, sin(a)) * r * _rng.randf_range(0.6, 1.0)
		bit(
			"glow",
			p,
			_rng.randf_range(0.5, 0.8),
			col,
			{
				"vel": Vector3(cos(a), 0.5, sin(a)) * _rng.randf_range(0.8, 1.6),
				"drag": 3.0,
				"life": _rng.randf_range(0.4, 0.65),
				"grow": Vector2(0.6, 1.4),
				"fade": 0.6
			}
		)


func clods(at: Vector3, n: int, speed := 4.0, tex := "clod", size := 0.24) -> void:
	for i in n:
		var a := _rng.randf() * TAU
		var v := Vector3(
			cos(a) * _rng.randf_range(0.3, 1.0),
			_rng.randf_range(1.2, 2.0),
			sin(a) * _rng.randf_range(0.3, 1.0)
		)
		bit(
			tex,
			ground(at) + Vector3(0, 0.15, 0),
			size * _rng.randf_range(0.7, 1.3),
			Color.WHITE,
			{
				"vel": v * speed * 0.6,
				"grav": 14.0,
				"life": _rng.randf_range(0.5, 0.8),
				"face": ProcFx.Face.ROLL,
				"roll": _rng.randf() * TAU,
				"spin": _rng.randf_range(-8, 8),
				"fade": 0.25,
				"ground_y": vfx.arena.global_position.y + 0.05
			}
		)


func icon_pop(
	icon: String, at: Vector3, size := 0.55, col := Color.WHITE, life := 0.8, rise := 0.7
) -> ProcFx:
	return bit(
		String(ICONS.get(icon, icon)),
		toward_cam(at),
		size,
		col,
		{"life": life, "pop": 0.18, "vel": Vector3(0, rise, 0), "fade": 0.35}
	)


## Peças que voam de `from` (global) até o lutador (corações do Charm, gotas do dreno).
func seekers(
	tex: String,
	from: Vector3,
	to: BattleFighter,
	n: int,
	col: Color,
	size := 0.3,
	speed := 6.0,
	add := false
) -> void:
	if not is_instance_valid(to):
		return
	for i in n:
		var a := _rng.randf() * TAU
		bit(
			tex,
			from + Vector3(cos(a) * 0.3, _rng.randf_range(-0.1, 0.3), sin(a) * 0.3),
			size * _rng.randf_range(0.8, 1.15),
			col,
			{
				"seek": to,
				"seek_off": Vector3(0, to.visual_height() * 0.5, 0),
				"seek_speed": speed * _rng.randf_range(0.8, 1.2),
				"vel": Vector3(cos(a), 1.2, sin(a)) * 2.5,
				"life": 1.6,
				"fade": 0.1,
				"add": add
			}
		)


# --- Ao lançar ---


func on_cast(user: BattleFighter, mv: Dictionary, dir: Vector3) -> void:
	if not _ok() or not is_instance_valid(user) or not user.is_inside_tree():
		return
	var lk := look(mv)
	var kind := String(mv.get("kind", ""))
	var gdir := _gdir(dir)
	var cast = lk.get("cast", [])
	if cast is String:
		cast = [cast]
	for s in cast:
		cast_shape(String(s), user, mv, lk, gdir)
	match kind:
		"dash":
			dash_trail(user, mv, lk, gdir)
		"arc":
			swing(user, mv, lk, gdir)
		"multi_arc":
			var hits := int(mv.get("hits", 3))
			var every := float(mv.get("interval", 0.2))
			for i in hits:
				later(
					every * i,
					func() -> void:
						if is_instance_valid(user) and user.active():
							swing(user, mv, lk, _gdir(user.aim_dir()), i)
				)
		"beam":
			charge(user, mv, lk, float(mv.get("windup", 0.6)))
		"aoe_self":
			var w := float(mv.get("windup", 0.4))
			if w > 0.25:
				charge(user, mv, lk, w, 0.7)
			later(
				w,
				func() -> void:
					if is_instance_valid(user) and user.alive():
						land(user, mv, lk, user.global_position, float(mv.get("radius", 3.0)), true)
			)
		"aoe_target":
			var n0 = vfx.arena.get("_tele_n")
			later(0.0, _read_telegraph.bind(user, mv, lk, gdir, int(n0) if n0 != null else 0))
		"zone":
			zone(user, mv, lk, _zone_point(user, mv, dir))


func _read_telegraph(
	user: BattleFighter, mv: Dictionary, lk: Dictionary, gdir: Vector3, n0: int
) -> void:
	var at := Vector3.ZERO
	var found := false
	var tele = vfx.arena.get("telegraphs")
	if tele is Array:
		for e in tele:
			if (
				int(e.get("id", 0)) > n0
				and int(e.get("side", -1)) == user.side
				and e.get("at") is Vector3
			):
				at = _gpos(e.at)
				found = true
	if not found:
		at = _gpos(_zone_point(user, mv, vfx.arena.global_basis.inverse() * gdir))
	_pending[String(mv.get("id", ""))] = {"user": user, "at": at}
	pre(user, mv, lk, at, float(mv.get("radius", 2.0)), float(mv.get("windup", 1.0)))


func _zone_point(user: BattleFighter, mv: Dictionary, dir: Vector3) -> Vector3:
	var rng_m := float(mv.get("range", 8.0))
	var at := user.pos2(user.position) + dir * rng_m * 0.6
	var t: BattleFighter = user.opponent
	if is_instance_valid(t) and t.active() and user.flat_to(t).length() <= rng_m:
		at = user.pos2(t.position)
	return at


func cast_shape(
	s: String, user: BattleFighter, mv: Dictionary, lk: Dictionary, gdir: Vector3
) -> void:
	var col := col_of(mv, lk)
	var c := center(user, 0.5)
	var h := user.visual_height()
	var type := String(mv.get("type", "normal"))
	match s:
		"aura":
			ring_ground(user.global_position, 0.2, 1.1, col, 0.55)
			repeat(
				0.05,
				0.6,
				func(_i: int, _a: float) -> bool:
					if not is_instance_valid(user) or not user.is_inside_tree():
						return false
					var a := _rng.randf() * TAU
					var p := (
						ground(user.global_position)
						+ Vector3(cos(a) * 0.5, _rng.randf_range(0.0, h * 0.6), sin(a) * 0.5)
					)
					bit(
						"dot",
						toward_cam(p, 0.5),
						_rng.randf_range(0.18, 0.3),
						col.lightened(0.3),
						{
							"add": true,
							"vel": Vector3(0, _rng.randf_range(1.5, 2.6), 0),
							"life": 0.5,
							"grow": Vector2(1.0, 0.3)
						}
					)
					return true
			)
			bit(
				"glow",
				toward_cam(c),
				h * 1.6,
				Color(col, 0.55),
				{"add": true, "life": 0.45, "grow": Vector2(0.6, 1.1), "fade": 0.6}
			)
			var st := String(mv.get("stat", ""))
			var ic := String(lk.get("icon", STAT_ICON.get(st, "")))
			if ic != "":
				icon_pop(ic, head_side(user), 0.6)
		"icon":
			icon_pop(String(lk.get("icon", "star")), head_side(user), 0.6, Color.WHITE, 0.9)
		"shield":
			shield(
				user,
				col,
				float(lk.get("dur", mv.get("duration", 1.4))),
				String(lk.get("shield_tex", "hex"))
			)
		"heal":
			heal(user, col)
		"charge":
			charge(user, mv, lk, float(lk.get("charge_t", 0.45)))
		"sound":
			sound(user, col, float(mv.get("radius", 3.0)), int(lk.get("waves", 3)))
		"hearts":
			for i in 7:
				var a := _rng.randf() * TAU
				bit(
					"heart",
					toward_cam(c),
					_rng.randf_range(0.26, 0.4),
					Color(1, 0.55, 0.8),
					{
						"vel": Vector3(cos(a) * 1.6, _rng.randf_range(1.0, 2.4), sin(a) * 1.6),
						"drag": 1.5,
						"life": 0.8,
						"pop": 0.15,
						"wobble": 0.05
					}
				)
		"notes":
			for i in 6:
				var a := _rng.randf() * TAU
				bit(
					"note",
					toward_cam(c + Vector3(0, h * 0.3, 0)),
					_rng.randf_range(0.3, 0.42),
					Color.from_hsv(_rng.randf(), 0.35, 1.0),
					{
						"vel": Vector3(cos(a) * 1.2, _rng.randf_range(0.8, 1.6), sin(a) * 1.2),
						"drag": 1.0,
						"life": 1.0,
						"pop": 0.15,
						"wobble": 0.08
					}
				)
		"sparkles":
			for i in 10:
				var p := (
					c
					+ Vector3(
						_rng.randf_range(-0.6, 0.6),
						_rng.randf_range(-0.3, h * 0.6),
						_rng.randf_range(-0.6, 0.6)
					)
				)
				bit(
					"star4",
					toward_cam(p),
					_rng.randf_range(0.25, 0.45),
					col.lightened(0.4),
					{
						"add": true,
						"life": _rng.randf_range(0.3, 0.6),
						"fade_in": 0.1,
						"grow": Vector2(0.4, 1.0),
						"fade": 0.5
					}
				)
		"spin":
			for i in 3:
				later(
					i * 0.1,
					func() -> void:
						if is_instance_valid(user):
							ring_ground(
								user.global_position, 0.3, 1.3, col.lightened(0.3), 0.3, "swirl"
							)
				)
		"smoke":
			for i in 12:
				var a := TAU * i / 12.0
				var p := ground(user.global_position) + Vector3(cos(a) * 0.4, 0.3, sin(a) * 0.4)
				bit(
					"cloud",
					p,
					_rng.randf_range(0.8, 1.2),
					Color(0.25, 0.24, 0.28, 0.85),
					{
						"vel": Vector3(cos(a), 0.4, sin(a)) * 2.2,
						"drag": 2.0,
						"life": 1.0,
						"grow": Vector2(0.5, 1.6),
						"fade": 0.5
					}
				)
		"glow":
			bit(
				"glow",
				toward_cam(c),
				h * 1.8,
				Color(col, 0.7),
				{"add": true, "life": 0.5, "grow": Vector2(0.5, 1.2), "fade": 0.6}
			)
		"stomp":
			ring_ground(user.global_position, 0.2, 1.6, Color(0.85, 0.75, 0.55), 0.4)
			dust(user.global_position, 8, 0.5)
		"wind":
			wind(user, col)
		"flames":
			repeat(
				0.04,
				0.6,
				func(_i: int, _a: float) -> bool:
					if not is_instance_valid(user) or not user.is_inside_tree():
						return false
					var a := _rng.randf() * TAU
					var p := (
						ground(user.global_position) + Vector3(cos(a) * 0.55, 0.1, sin(a) * 0.55)
					)
					bit(
						"dot",
						toward_cam(p, 0.5),
						_rng.randf_range(0.3, 0.5),
						Color(1, _rng.randf_range(0.4, 0.8), 0.1),
						{
							"add": true,
							"vel": Vector3(0, _rng.randf_range(2.0, 3.0), 0),
							"life": 0.45,
							"grow": Vector2(1.0, 0.2)
						}
					)
					return true
			)
		"dance":
			var ic2 := String(lk.get("icon", "swords"))
			for i in 4:
				var a := TAU * i / 4.0
				bit(
					String(ICONS.get(ic2, ic2)),
					toward_cam(c + Vector3(cos(a) * 0.7, 0.1, sin(a) * 0.7)),
					0.55,
					Color.WHITE,
					{
						"vel": Vector3(-sin(a), 0.6, cos(a)) * 1.8,
						"life": 0.8,
						"pop": 0.15,
						"fade": 0.4
					}
				)
			ring_ground(user.global_position, 0.3, 1.2, col, 0.6)
		"metal":
			bit(
				"star4",
				toward_cam(c + Vector3(0.15, h * 0.25, 0)),
				0.9,
				Color(1, 1, 1),
				{
					"add": true,
					"life": 0.45,
					"grow": Vector2(0.2, 1.2),
					"spin": 3.0,
					"face": ProcFx.Face.ROLL,
					"roll": 0.3
				}
			)
			bit(
				"glow",
				toward_cam(c),
				h * 1.5,
				Color(0.8, 0.85, 0.95, 0.6),
				{"add": true, "life": 0.4, "grow": Vector2(0.8, 1.1)}
			)
		"emanate":
			emanate(user, mv, lk, col)
		"dust":
			for i in 10:
				var d := gdir.rotated(Vector3.UP, _rng.randf_range(-0.5, 0.5))
				bit(
					"glow",
					ground(user.global_position) + Vector3(0, 0.25, 0) + d * 0.4,
					_rng.randf_range(0.35, 0.6),
					Color(0.85, 0.72, 0.5, 0.9),
					{
						"vel": d * _rng.randf_range(3.0, 5.0) + Vector3(0, 0.8, 0),
						"drag": 2.5,
						"life": 0.6,
						"grow": Vector2(0.6, 1.5)
					}
				)
		"drain_self":
			heal(user, Color(0.5, 1.0, 0.5))
		"rain":
			repeat(
				0.02,
				1.1,
				func(_i: int, _a: float) -> bool:
					if not is_instance_valid(user) or not user.is_inside_tree():
						return false
					var q := (
						ground(user.global_position)
						+ Vector3(
							_rng.randf_range(-3.0, 3.0),
							_rng.randf_range(2.5, 3.2),
							_rng.randf_range(-2.5, 2.5)
						)
					)
					bit(
						"streak",
						q,
						0.5,
						Color(0.7, 0.85, 1.0, 0.8),
						{
							"face": ProcFx.Face.ROLL,
							"roll": -PI * 0.5 - 0.15,
							"vel": Vector3(0.6, -9.0, 0),
							"life": 0.32,
							"fade": 0.2
						}
					)
					return true
			)
		"zone_here":
			zone(user, mv, lk, user.position)
		"gravity":
			for i in 3:
				later(
					i * 0.15,
					func() -> void:
						if is_instance_valid(user):
							ring_ground(user.global_position, 3.5, 0.3, Color(col, 0.85), 0.5)
				)
			repeat(
				0.03,
				0.8,
				func(_i: int, _a: float) -> bool:
					if not is_instance_valid(user):
						return false
					var q := (
						ground(user.global_position)
						+ Vector3(
							_rng.randf_range(-3.0, 3.0),
							_rng.randf_range(2.0, 3.0),
							_rng.randf_range(-2.5, 2.5)
						)
					)
					bit(
						"streak",
						q,
						0.8,
						Color(col.lightened(0.3), 0.8),
						{
							"face": ProcFx.Face.ROLL,
							"roll": -PI * 0.5,
							"vel": Vector3(0, -7.0, 0),
							"life": 0.3,
							"add": true
						}
					)
					return true
			)
		"storm":
			repeat(
				0.02,
				1.4,
				func(_i: int, _a: float) -> bool:
					if not is_instance_valid(user):
						return false
					var q := (
						ground(user.global_position)
						+ Vector3(-4.0, _rng.randf_range(0.1, 2.0), _rng.randf_range(-3.0, 3.0))
					)
					bit(
						"glow",
						q,
						_rng.randf_range(0.4, 0.7),
						Color(0.85, 0.72, 0.5, 0.75),
						{
							"vel":
							Vector3(_rng.randf_range(6.0, 9.0), _rng.randf_range(-0.5, 0.5), 0),
							"life": 0.9,
							"grow": Vector2(0.6, 1.2)
						}
					)
					if _rng.randf() < 0.3:
						bit(
							"clod",
							q,
							0.18,
							Color.WHITE,
							{
								"vel": Vector3(_rng.randf_range(7.0, 10.0), 0, 0),
								"life": 0.8,
								"face": ProcFx.Face.ROLL,
								"roll": 0.0,
								"spin": 9.0
							}
						)
					return true
			)
		"powder":
			for i in 14:
				var a := _rng.randf() * TAU
				bit(
					"dot",
					toward_cam(
						c + Vector3(cos(a) * 0.5, _rng.randf_range(0.0, h * 0.5), sin(a) * 0.5)
					),
					_rng.randf_range(0.18, 0.28),
					col.lightened(0.3),
					{
						"vel": Vector3(cos(a) * 1.5, _rng.randf_range(0.2, 1.0), sin(a) * 1.5),
						"drag": 1.5,
						"life": 1.0,
						"wobble": 0.08
					}
				)
		"feathers":
			for i in 8:
				bit(
					"feather",
					(
						center(user, 1.0)
						+ Vector3(
							_rng.randf_range(-0.6, 0.6),
							0.8 + _rng.randf() * 0.6,
							_rng.randf_range(-0.3, 0.3)
						)
					),
					0.34,
					Color.WHITE,
					{
						"vel": Vector3(0, -1.0, 0),
						"life": 1.1,
						"wobble": 0.2,
						"face": ProcFx.Face.ROLL,
						"roll": _rng.randf() * TAU,
						"spin": 2.0,
						"fade": 0.3
					}
				)
		"splash":
			for i in 12:
				var a := _rng.randf() * TAU
				bit(
					"drop",
					toward_cam(c),
					0.3,
					Color(0.6, 0.85, 1.0),
					{
						"vel": Vector3(cos(a) * 1.8, _rng.randf_range(2.5, 4.0), sin(a) * 1.8),
						"grav": 12.0,
						"life": 0.7,
						"face": ProcFx.Face.ROLL,
						"roll": _rng.randf() * TAU
					}
				)
			ring_ground(user.global_position, 0.3, 1.2, Color(0.6, 0.85, 1.0), 0.45)
		"beam_down":
			pillar(user.global_position, col, 0.9, 0.7)
			bit(
				String(ICONS.moon),
				center(user, 1.0) + Vector3(0, 1.6, 0),
				0.7,
				Color.WHITE,
				{"vel": Vector3(0, -1.2, 0), "life": 0.8, "pop": 0.15}
			)
		"shatter":
			for i in 12:
				var a := _rng.randf() * TAU
				bit(
					PX + "objects/debris_rock.png",
					toward_cam(c),
					_rng.randf_range(0.25, 0.4),
					Color(0.95, 0.9, 0.8),
					{
						"vel": Vector3(cos(a) * 3.0, _rng.randf_range(1.5, 3.0), sin(a) * 3.0),
						"grav": 12.0,
						"life": 0.6,
						"face": ProcFx.Face.ROLL,
						"roll": _rng.randf() * TAU,
						"spin": _rng.randf_range(-9, 9)
					}
				)
			flash(c, 1.2, Color(1, 0.8, 0.6))


# --- Investida ---


func dash_trail(user: BattleFighter, mv: Dictionary, lk: Dictionary, gdir: Vector3) -> void:
	var style := String(lk.get("trail", mv.get("type", "normal")))
	var type := String(mv.get("type", "normal"))
	var col := col_of(mv, lk)
	var ghosts := bool(lk.get("ghosts", false))
	var lines := bool(lk.get("lines", true))
	var dur := (
		float(mv.get("range", 3.0)) / maxf(float(mv.get("speed", 12.0)), 0.1)
		+ float(mv.get("windup", 0.0))
		+ 0.15
	)
	if style == "spin":
		later(0.0, func() -> void: _spin_ball(user, col, dur))
	repeat(
		0.03,
		minf(dur, 1.6),
		func(i: int, a: float) -> bool:
			if not is_instance_valid(user) or not user.is_inside_tree() or not user.alive():
				return false
			if user.dash_t <= 0.0 and a > 0.08:
				return false
			var d := _gdir(user.dash_dir if user.dash_dir.length() > 0.01 else user.facing)
			var c := center(user, 0.5)
			var h := user.visual_height()
			if ghosts and i % 2 == 0 and user.look:
				var g := ProcFx.ghost(user.look.sprite(), Color(col.lightened(0.35), 0.5))
				if g:
					g.life = 0.22
					g.fade = 0.9
					_add(g, user.look.sprite().global_position)
			if lines:
				for k in 2:
					var side := d.cross(Vector3.UP).normalized() * _rng.randf_range(-0.45, 0.45)
					var p := (
						c
						+ side
						+ Vector3(0, _rng.randf_range(-h * 0.3, h * 0.35), 0)
						- d * _rng.randf_range(0.2, 0.7)
					)
					bit(
						"streak",
						toward_cam(p, 0.6),
						_rng.randf_range(0.7, 1.2),
						Color(1, 1, 1, 0.85) if k == 0 else Color(col.lightened(0.4), 0.85),
						{
							"face": ProcFx.Face.ROLL,
							"roll": roll_of(d),
							"vel": -d * 2.0,
							"life": 0.16,
							"fade": 0.6,
							"add": true
						}
					)
			_trail_bits(style, type, user, c, d, h, i, col)
			if i % 3 == 0 and not user.is_airborne() and user.height() < 0.2 and style != "water":
				var fp := ground(user.global_position) - d * 0.3
				bit(
					"glow",
					fp,
					_rng.randf_range(0.45, 0.7),
					Color(0.82, 0.72, 0.55, 0.75),
					{
						"vel": -d * 1.2 + Vector3(0, 0.4, 0),
						"drag": 2.0,
						"life": 0.45,
						"grow": Vector2(0.5, 1.4),
						"fade": 0.6
					}
				)
			return true
	)


func _trail_bits(
	style: String,
	type: String,
	user: BattleFighter,
	c: Vector3,
	d: Vector3,
	h: float,
	i: int,
	col: Color
) -> void:
	var back := c - d * 0.35
	match style:
		"fire":
			for k in 2:
				bit(
					"dot",
					toward_cam(
						(
							back
							+ Vector3(
								_rng.randf_range(-0.3, 0.3),
								_rng.randf_range(-h * 0.4, h * 0.3),
								_rng.randf_range(-0.3, 0.3)
							)
						),
						0.5
					),
					_rng.randf_range(0.4, 0.65),
					Color(1, _rng.randf_range(0.35, 0.75), 0.08),
					{
						"add": true,
						"vel": Vector3(0, 2.2, 0) - d,
						"life": 0.35,
						"grow": Vector2(1.0, 0.2)
					}
				)
		"water":
			bit(
				"drop",
				toward_cam(
					back + Vector3(_rng.randf_range(-0.3, 0.3), _rng.randf_range(0.0, h * 0.4), 0),
					0.5
				),
				0.28,
				Color(0.6, 0.85, 1.0),
				{
					"vel": Vector3(_rng.randf_range(-1, 1), 2.5, _rng.randf_range(-1, 1)) - d * 1.5,
					"grav": 10.0,
					"life": 0.5,
					"face": ProcFx.Face.ROLL,
					"roll": _rng.randf() * TAU
				}
			)
			if i % 2 == 0:
				bit(
					"ring_soft",
					toward_cam(back, 0.4),
					h * 1.1,
					Color(0.55, 0.8, 1.0, 0.55),
					{"add": true, "life": 0.25, "grow": Vector2(0.6, 1.1)}
				)
		"spark":
			if i % 2 == 0:
				vfx.pmd(
					"spark",
					toward_cam(
						(
							back
							+ Vector3(
								_rng.randf_range(-0.3, 0.3), _rng.randf_range(-h * 0.3, h * 0.3), 0
							)
						),
						0.5
					),
					d,
					{"scale": _rng.randf_range(0.3, 0.45), "billboard": true}
				)
		"spin":
			pass
		"speed":
			pass
		_:
			if i % 2 == 0:
				burst(style if STYLE.has(style) else type, back, 1, 1.0, 0.9, 0.3)


func _spin_ball(user: BattleFighter, col: Color, dur: float) -> void:
	if not is_instance_valid(user):
		return
	var h := user.visual_height()
	bit(
		"swirl",
		toward_cam(center(user, 0.5)),
		h * 1.4,
		Color(col.lightened(0.3), 0.85),
		{
			"add": true,
			"follow": user,
			"life": dur,
			"spin": 14.0,
			"face": ProcFx.Face.ROLL,
			"roll": 0.0,
			"fade": 0.2
		}
	)


# --- Corpo a corpo ---


## Corte/garra/presa/punho na frente do usuário (ou no alvo mais perto dentro do alcance).
func swing(user: BattleFighter, mv: Dictionary, lk: Dictionary, gdir: Vector3, i := 0) -> void:
	if not is_instance_valid(user) or not user.is_inside_tree():
		return
	var shape := String(lk.get("swing", "slash"))
	var rng_m := float(mv.get("range", 1.9))
	var at := center(user, 0.5) + gdir * rng_m * 0.6
	var tgt := _front_target(user, mv, _local_dir(gdir))
	if tgt:
		at = center(tgt, 0.5)
	strike(shape, at, gdir, mv, lk, i, user)


func _local_dir(gdir: Vector3) -> Vector3:
	return (vfx.arena.global_basis.inverse() * gdir).normalized()


func _front_target(user: BattleFighter, mv: Dictionary, dir: Vector3) -> BattleFighter:
	var best: BattleFighter = null
	var best_d := float(mv.get("range", 1.9)) + 0.7
	var arena = vfx.arena
	if not arena.has_method("targets_of"):
		return null
	for t in arena.targets_of(user):
		if not is_instance_valid(t) or not t.active():
			continue
		var to: Vector3 = user.flat_to(t)
		var d := to.length()
		if d < best_d and (d < 0.5 or dir.dot(to / d) > 0.35):
			best_d = d
			best = t
	return best


## Desenha a forma do golpe em `at` (global). Usado no corpo a corpo e no impacto.
func strike(
	shape: String,
	at: Vector3,
	gdir: Vector3,
	mv: Dictionary,
	lk: Dictionary,
	i := 0,
	user: BattleFighter = null
) -> void:
	var col := col_of(mv, lk)
	var type := String(mv.get("type", "normal"))
	var roll := roll_of(gdir)
	var k := float(lk.get("size", 1.0))
	var p := toward_cam(at)
	var flip := 1.0 if i % 2 == 0 else -1.0
	match shape:
		"slash", "tail", "slap", "chop":
			var sz := float({"slash": 1.6, "tail": 2.2, "slap": 1.0, "chop": 1.6}[shape]) * k
			var r := roll + (deg_to_rad(-90.0) if shape == "chop" else deg_to_rad(25.0 * flip))
			var cut_col := col.lightened(0.25)
			bit(
				"crescent",
				p,
				sz,
				Color(cut_col, 0.95),
				{
					"face": ProcFx.Face.ROLL,
					"roll": r,
					"spin": -9.0 * flip,
					"life": 0.18,
					"grow": Vector2(0.7, 1.15),
					"fade": 0.5,
					"add":
					(
						type
						in [
							"fire",
							"electric",
							"psychic",
							"dragon",
							"fairy",
							"ghost",
							"grass",
							"ice",
							"water"
						]
					)
				}
			)
			bit(
				"arc",
				p,
				sz * 0.92,
				Color(1, 1, 1, 0.95),
				{
					"face": ProcFx.Face.ROLL,
					"roll": r,
					"spin": -9.0 * flip,
					"life": 0.13,
					"grow": Vector2(0.7, 1.15),
					"fade": 0.5,
					"add": true
				}
			)
			if shape == "tail":
				burst(type, p, 5, 2.5, 0.9)
		"x":
			for s in [-1.0, 1.0]:
				var rr: float = s * PI * 0.25 + PI * 0.5
				var o1 := {
					"face": ProcFx.Face.ROLL, "roll": rr, "life": 0.28, "pop": 0.07, "fade": 0.5
				}
				bit("blade", p, 2.0 * k, Color(col.darkened(0.1), 1.0), o1)
				var o2 := o1.duplicate()
				o2.add = true
				o2.life = 0.2
				bit("blade", p, 1.7 * k, Color(1, 1, 1, 0.95), o2)
			later(0.08, func() -> void: flash(at, 0.7 * k, col.lightened(0.5)))
		"claw":
			bit(
				"claw",
				p,
				1.1 * k,
				Color(col.lightened(0.45)),
				{
					"face": ProcFx.Face.ROLL,
					"roll": roll * 0.0 + flip * 0.15,
					"life": 0.3,
					"pop": 0.08,
					"fade": 0.5,
					"flip_h": flip < 0.0
				}
			)
			bit("glow", p, 0.9 * k, Color(col, 0.5), {"add": true, "life": 0.15})
		"fang":
			var off := 0.5 * k
			var fc := Color(1, 1, 1) if type in ["normal", "dark"] else col.lightened(0.5)
			bit(
				"glow",
				p,
				1.3 * k,
				Color(col.darkened(0.2) if type == "dark" else col, 0.55),
				{"life": 0.3, "grow": Vector2(0.6, 1.1), "add": type != "dark"}
			)
			bit(
				"fang",
				p + Vector3(0, off, 0),
				1.1 * k,
				fc,
				{"vel": Vector3(0, -off / 0.13, 0), "life": 0.13, "fade": 0.0, "pop": 0.05}
			)
			bit(
				"fang",
				p - Vector3(0, off, 0),
				1.1 * k,
				fc,
				{
					"vel": Vector3(0, off / 0.13, 0),
					"life": 0.13,
					"fade": 0.0,
					"pop": 0.05,
					"flip_v": true
				}
			)
			later(
				0.13,
				func() -> void:
					bit(
						"fang", p + Vector3(0, 0.2 * k, 0), 1.1 * k, fc, {"life": 0.16, "fade": 0.7}
					)
					bit(
						"fang",
						p - Vector3(0, 0.2 * k, 0),
						1.1 * k,
						fc,
						{"life": 0.16, "fade": 0.7, "flip_v": true}
					)
					flash(at, 0.8 * k, col.lightened(0.4))
					if type != "normal" and type != "dark":
						burst(type, at, 6, 2.5)
			)
		"fist":
			var fist := bit(
				ICONS.fist,
				p - gdir * 0.25,
				0.75 * k,
				Color(1, 1, 1) if type in ["normal", "fighting"] else col.lightened(0.55),
				{"vel": gdir * 2.5, "life": 0.2, "pop": 0.06, "fade": 0.4}
			)
			later(
				0.07,
				func() -> void:
					flash(at, 1.0 * k, col.lightened(0.4))
					burst(type, at, 6, 3.0)
			)
		"kick":
			bit(
				"arc",
				p - Vector3(0, 0.2, 0),
				1.1 * k,
				Color(1, 1, 1),
				{
					"face": ProcFx.Face.ROLL,
					"roll": roll - 0.6,
					"spin": 8.0,
					"life": 0.14,
					"add": true
				}
			)
			later(
				0.06, func() -> void: flash(at - Vector3(0, 0.15, 0), 0.9 * k, col.lightened(0.4))
			)
		"jab", "horn", "sting":
			bit(
				"streak",
				p - gdir * 0.6,
				1.6 * k,
				Color(col.lightened(0.4)),
				{
					"face": ProcFx.Face.ROLL,
					"roll": roll,
					"vel": gdir * 5.0,
					"life": 0.13,
					"add": true
				}
			)
			later(
				0.1,
				func() -> void:
					flash(at, 0.7 * k, col.lightened(0.5))
					if type != "normal":
						burst(type, at, 5, 2.4)
			)
		"wing":
			for s in [-1.0, 1.0]:
				bit(
					"crescent",
					p,
					1.3 * k,
					Color(1, 1, 1, 0.9),
					{
						"face": ProcFx.Face.ROLL,
						"roll": roll + s * 0.9,
						"spin": -s * 6.0,
						"life": 0.18,
						"add": true
					}
				)
			burst("flying", at, 4, 2.0)
		"spin":
			if user:
				ring_ground(user.global_position, 0.3, 1.4, col.lightened(0.3), 0.3, "swirl")
		"hearts":
			for n in 6:
				var a := _rng.randf() * TAU
				bit(
					"heart",
					p,
					_rng.randf_range(0.28, 0.42),
					Color(1, 0.55, 0.8),
					{
						"vel": Vector3(cos(a) * 2.0, _rng.randf_range(1.0, 2.5), sin(a) * 2.0),
						"drag": 1.6,
						"life": 0.7,
						"pop": 0.12
					}
				)
		"rough":
			for n in 5:
				later(
					n * 0.06,
					func() -> void:
						var q := (
							at
							+ Vector3(
								_rng.randf_range(-0.4, 0.4),
								_rng.randf_range(-0.3, 0.3),
								_rng.randf_range(-0.2, 0.2)
							)
						)
						bit(
							"cloud",
							toward_cam(q),
							_rng.randf_range(0.7, 1.0),
							Color(1, 0.85, 0.92, 0.9),
							{"life": 0.3, "grow": Vector2(0.6, 1.2)}
						)
						flash(q, 0.6, Color(1, 0.7, 0.9))
				)
			for n in 5:
				var a2 := _rng.randf() * TAU
				bit(
					"heart",
					p,
					0.32,
					Color(1, 0.5, 0.8),
					{
						"vel": Vector3(cos(a2) * 2.2, 2.0, sin(a2) * 2.2),
						"drag": 1.5,
						"life": 0.7,
						"pop": 0.1
					}
				)
				bit(
					"star5",
					p,
					0.3,
					Color(1, 0.95, 0.5),
					{
						"vel": Vector3(-cos(a2) * 2.0, 1.6, -sin(a2) * 2.0),
						"drag": 1.5,
						"life": 0.6,
						"pop": 0.1
					}
				)
		"burst":
			rays(at, 1.6 * k, col.lightened(0.3))
			burst(type, at, 8, 3.0)
		"pellets":
			var from := at - gdir * 1.4
			for n in 3:
				later(
					n * 0.04,
					func() -> void:
						var q := toward_cam(
							(
								from
								+ Vector3(
									_rng.randf_range(-0.15, 0.15), _rng.randf_range(-0.1, 0.15), 0
								)
							)
						)
						vfx.pmd(
							"seed_rse", q, gdir, {"scale": 1.4, "billboard": true, "life": 0.14}
						)
						bit(
							"dot",
							q,
							0.26,
							Color(0.7, 1.0, 0.4),
							{"vel": gdir * 10.0, "life": 0.14, "add": true}
						)
				)
			later(0.13, func() -> void: flash(at, 0.6, col.lightened(0.4)))


# --- Impacto ---


func on_hit(
	user: BattleFighter, target: BattleFighter, mv: Dictionary, dir: Vector3, crit: bool, eff: float
) -> void:
	if not _ok() or not is_instance_valid(target) or not target.is_inside_tree():
		return
	var lk := look(mv)
	var kind := String(mv.get("kind", ""))
	var type := String(mv.get("type", "normal"))
	var power := float(mv.get("power", 0))
	var col := col_of(mv, lk)
	var at := center(target, 0.5)
	var gdir := _gdir(dir)
	var big := power >= 80.0 or crit or eff > 1.0
	var k := clampf(0.7 + power / 160.0, 0.75, 1.5) * (1.25 if crit or eff > 1.0 else 1.0)
	if kind in ["stream", "multi_arc"] or mv.has("count"):
		k *= 0.75
	flash(at, 0.65 * k, Color(1, 1, 1).lerp(col, 0.45))
	burst(type, at, int(4 + power / 25.0), 2.6 * k, 1.0)
	if big:
		ring_air(at, 0.2, 0.8 * k, Color(Color.WHITE.lerp(col, 0.4), 0.5), 0.25)
	if crit or eff > 1.0:
		rays(at, 1.8 * k, col.lightened(0.4), 0.3)
	var physical := String(mv.get("category", "")) == "physical"
	if (
		physical
		and power >= 75.0
		and kind in ["dash", "arc", "aoe_target"]
		and target.height() < 0.3
	):
		ring_ground(target.global_position, 0.2, 1.0 * k, Color(0.9, 0.8, 0.6), 0.35)
		dust(target.global_position, 6, 0.4)
	var imp = lk.get("impact", [])
	if imp is String:
		imp = [imp]
	for s in imp:
		impact_shape(String(s), user, target, mv, lk, at, gdir, k)
	if kind == "dash" and lk.has("swing"):
		strike(String(lk.swing), at, gdir, mv, lk, 0, user)


func impact_shape(
	s: String,
	user: BattleFighter,
	target: BattleFighter,
	mv: Dictionary,
	lk: Dictionary,
	at: Vector3,
	gdir: Vector3,
	k: float
) -> void:
	var col := col_of(mv, lk)
	var type := String(mv.get("type", "normal"))
	match s:
		"dust":
			ring_ground(target.global_position, 0.2, 1.3 * k, Color(0.9, 0.8, 0.6), 0.4)
			dust(target.global_position, 10, 0.5)
		"crater":
			ring_ground(target.global_position, 0.2, 1.6 * k, Color(0.9, 0.8, 0.6), 0.45)
			bit(
				"crack",
				ground(target.global_position),
				2.0 * k,
				Color(1, 1, 1, 0.9),
				{"face": ProcFx.Face.GROUND, "life": 1.6, "fade": 0.4, "spin": 0.0}
			)
			clods(target.global_position, 8, 4.0)
			dust(target.global_position, 10, 0.6)
		"drain":
			if is_instance_valid(user):
				seekers("dot", at, user, 8, Color(0.55, 1.0, 0.45), 0.3, 5.0, true)
				later(
					0.45,
					func() -> void:
						if is_instance_valid(user):
							heal(user, Color(0.5, 1.0, 0.5), 0.5)
				)
		"splash":
			for n in 10:
				var a := _rng.randf() * TAU
				bit(
					"drop",
					toward_cam(at),
					0.3,
					Color(0.6, 0.85, 1.0),
					{
						"vel": Vector3(cos(a) * 2.0, _rng.randf_range(2.0, 4.0), sin(a) * 2.0),
						"grav": 12.0,
						"life": 0.6,
						"face": ProcFx.Face.ROLL,
						"roll": _rng.randf() * TAU
					}
				)
			ring_ground(target.global_position, 0.3, 1.2, Color(0.6, 0.85, 1.0), 0.4)
		"sparks":
			for n in 3:
				vfx.pmd(
					"spark",
					toward_cam(
						at + Vector3(_rng.randf_range(-0.4, 0.4), _rng.randf_range(-0.3, 0.4), 0)
					),
					gdir,
					{"scale": _rng.randf_range(0.4, 0.6), "billboard": true}
				)
		"stars":
			for n in 6:
				var a := _rng.randf() * TAU
				bit(
					"star5",
					toward_cam(at),
					0.3,
					Color(1, 0.95, 0.45),
					{
						"vel": Vector3(cos(a) * 2.2, _rng.randf_range(1.0, 2.2), sin(a) * 2.2),
						"drag": 1.2,
						"life": 0.6,
						"spin": 6.0,
						"face": ProcFx.Face.ROLL,
						"roll": 0.0
					}
				)
		"pillar":
			pillar(target.global_position, col, 0.6)
		"fire":
			for n in 8:
				bit(
					"dot",
					toward_cam(
						at + Vector3(_rng.randf_range(-0.4, 0.4), _rng.randf_range(-0.4, 0.2), 0)
					),
					_rng.randf_range(0.4, 0.6),
					Color(1, _rng.randf_range(0.35, 0.8), 0.1),
					{
						"add": true,
						"vel": Vector3(_rng.randf_range(-0.5, 0.5), _rng.randf_range(1.8, 3.0), 0),
						"life": 0.45,
						"grow": Vector2(1.0, 0.2)
					}
				)
		"shock":
			ring_air(at, 0.2, 1.2 * k, Color(1, 1, 1, 0.9), 0.25)
		_:
			if s in LAND_SHAPES:
				var l2 := lk.duplicate()
				l2.land = [s]
				land(user, mv, l2, target.global_position, 1.2, false)
			else:
				strike(s, at, gdir, mv, lk, 0, user)


# --- Raio / carga ---


## Orbe que cresce no usuário com partículas convergindo (Solar Beam, Hyper Beam, Aura...).
func charge(user: BattleFighter, mv: Dictionary, lk: Dictionary, secs: float, k := 1.0) -> void:
	if secs <= 0.05 or not is_instance_valid(user):
		return
	var col := col_of(mv, lk)
	var c := center(user, 0.5)
	var h := user.visual_height()
	bit(
		"glow",
		toward_cam(c, 1.2),
		h * 0.9 * k,
		Color(col, 0.6),
		{"add": true, "follow": user, "life": secs + 0.1, "grow": Vector2(0.15, 1.0), "fade": 0.15}
	)
	repeat(
		0.04,
		secs,
		func(_i: int, _a: float) -> bool:
			if not is_instance_valid(user) or not user.is_inside_tree():
				return false
			var a := _rng.randf() * TAU
			var b := _rng.randf_range(-0.6, 0.9)
			var from := center(user, 0.5) + Vector3(cos(a), b, sin(a)).normalized() * 1.3 * k
			bit(
				"dot",
				toward_cam(from, 0.8),
				0.22 * k,
				col.lightened(0.5),
				{
					"add": true,
					"seek": user,
					"seek_off": Vector3(0, h * 0.5, 0),
					"seek_speed": 5.0,
					"life": 0.5,
					"fade": 0.2
				}
			)
			return true
	)


# --- Áreas ---


## Antes de cair (golpe em área no alvo): nuvem, pedras no alto, pó, notas.
func pre(
	user: BattleFighter, mv: Dictionary, lk: Dictionary, at: Vector3, r: float, windup: float
) -> void:
	var col := col_of(mv, lk)
	var p = lk.get("pre", [])
	if p is String:
		p = [p]
	for s in p:
		match String(s):
			"cloud":
				storm_cloud(at, windup + 0.25, Color(0.32, 0.32, 0.4, 0.95))
			"rocks":
				falling(
					at,
					r,
					int(lk.get("rocks", 5)),
					windup,
					String(lk.get("rock_tex", PX + "objects/rock.png")),
					float(lk.get("rock_size", 0.75))
				)
			"meteor":
				falling(at, r * 0.3, 1, windup, String(lk.get("rock_tex", "star5")), 0.8, col)
			"powder":
				powder(at, r, windup, col, String(lk.get("spore", "")))
			"notes":
				for i in 8:
					var a := TAU * i / 8.0
					bit(
						"note",
						ground(at) + Vector3(cos(a) * r * 0.8, 0.9, sin(a) * r * 0.8),
						0.4,
						Color.from_hsv(float(i) / 8.0, 0.3, 1.0),
						{
							"seek_speed": 0.0,
							"vel": Vector3(-cos(a), 0.3, -sin(a)) * r * 0.6 / maxf(windup, 0.2),
							"life": windup + 0.2,
							"fade_in": 0.15,
							"wobble": 0.08,
							"fade": 0.2
						}
					)
			"glow":
				bit(
					"glow",
					ground(at) + Vector3(0, 0.5, 0),
					r * 1.6,
					Color(col, 0.6),
					{"add": true, "life": windup, "grow": Vector2(0.2, 1.0), "fade": 0.1}
				)
			"hearts":
				for i in 6:
					var a := TAU * i / 6.0
					bit(
						"heart",
						ground(at) + Vector3(cos(a) * r, 1.0, sin(a) * r),
						0.4,
						Color(1, 0.55, 0.8),
						{
							"vel": Vector3(-cos(a), 0, -sin(a)) * r / maxf(windup, 0.2),
							"life": windup,
							"fade_in": 0.1,
							"fade": 0.15
						}
					)
			"sparkles":
				repeat(
					0.05,
					windup,
					func(_i: int, _a: float) -> bool:
						var q := (
							ground(at)
							+ Vector3(
								_rng.randf_range(-r, r),
								_rng.randf_range(0.2, 1.4),
								_rng.randf_range(-r, r)
							)
						)
						bit(
							"star4",
							toward_cam(q),
							_rng.randf_range(0.25, 0.4),
							col.lightened(0.4),
							{"add": true, "life": 0.4, "grow": Vector2(0.3, 1.0)}
						)
						return true
				)
			"swirl":
				bit(
					"swirl",
					ground(at),
					r * 2.2,
					Color(col, 0.8),
					{
						"face": ProcFx.Face.GROUND,
						"life": windup + 0.1,
						"spin": 6.0,
						"add": true,
						"grow": Vector2(1.2, 0.5),
						"fade_in": 0.1,
						"fade": 0.2
					}
				)


## Hook do golpe em área no alvo quando cai (BattleVfx.sky_bolt).
func landed(move_id: String, at: Vector3) -> void:
	var mv := Dex.move(move_id)
	if mv.is_empty() or not _ok():
		return
	var pend: Dictionary = _pending.get(move_id, {})
	_pending.erase(move_id)
	var user: BattleFighter = pend.get("user") if is_instance_valid(pend.get("user")) else null
	land(user, mv, look(mv), at, float(mv.get("radius", 2.0)), false)


## Efeito quando a área cai (em `at` global, raio r).
func land(
	user: BattleFighter, mv: Dictionary, lk: Dictionary, at: Vector3, r: float, around_user: bool
) -> void:
	var col := col_of(mv, lk)
	var type := String(mv.get("type", "normal"))
	var l = lk.get("land", [])
	if l is String:
		l = [l]
	var c := ground(at) + Vector3(0, 0.6, 0)
	for s in l:
		match String(s):
			"quake":
				quake(at, r, col)
			"burst":
				ring_ground(at, 0.2, r, col, 0.4)
				rays(c, minf(r, 2.5) * 0.9, Color(col.lightened(0.35), 0.75), 0.35)
				burst(type, c, 12, 3.5)
			"ring":
				ring_ground(at, 0.2, r, col, 0.45)
				ring_ground(at, 0.1, r * 0.7, col.lightened(0.4), 0.35)
			"rocks":
				ring_ground(at, 0.2, r, Color(0.85, 0.75, 0.6), 0.4)
				clods(at, 10, 4.0, PX + "objects/debris_rock.png", 0.34)
				dust(at, 12, r * 0.7)
			"powder":
				var sp := String(lk.get("spore", "spores_rse_green"))
				for i in 6:
					var a := TAU * i / 6.0
					vfx.pmd(
						sp,
						toward_cam(ground(at) + Vector3(cos(a) * r * 0.5, 0.4, sin(a) * r * 0.5)),
						Vector3.FORWARD,
						{"scale": 1.4, "billboard": true}
					)
				for i in 10:
					var a := _rng.randf() * TAU
					bit(
						"cloud",
						ground(at) + Vector3(cos(a) * r * 0.6, 0.3, sin(a) * r * 0.6),
						_rng.randf_range(0.7, 1.1),
						Color(col.lightened(0.3), 0.6),
						{
							"vel": Vector3(cos(a), 0.3, sin(a)) * 1.2,
							"drag": 2.0,
							"life": 0.8,
							"grow": Vector2(0.6, 1.4),
							"fade": 0.6
						}
					)
			"notes":
				for i in 8:
					var a := _rng.randf() * TAU
					bit(
						"note",
						toward_cam(c),
						_rng.randf_range(0.32, 0.45),
						Color.from_hsv(_rng.randf(), 0.3, 1.0),
						{
							"vel": Vector3(cos(a) * 1.5, _rng.randf_range(1.0, 2.0), sin(a) * 1.5),
							"drag": 1.2,
							"life": 0.9,
							"pop": 0.1,
							"wobble": 0.08
						}
					)
				ring_air(c, 0.3, r, Color(1, 1, 1, 0.7), 0.4)
			"pillar":
				pillar(at, col, 0.7, r)
			"splash":
				for i in 14:
					var a := _rng.randf() * TAU
					bit(
						"drop",
						c,
						0.32,
						Color(0.6, 0.85, 1.0),
						{
							"vel": Vector3(cos(a) * r, _rng.randf_range(3.0, 5.0), sin(a) * r),
							"grav": 12.0,
							"life": 0.7,
							"face": ProcFx.Face.ROLL,
							"roll": _rng.randf() * TAU
						}
					)
				ring_ground(at, 0.3, r, Color(0.6, 0.85, 1.0), 0.5)
			"vortex":
				vortex(at, r, col, 0.8)
			"hearts":
				for i in 10:
					var a := _rng.randf() * TAU
					bit(
						"heart",
						c,
						_rng.randf_range(0.3, 0.45),
						Color(1, 0.55, 0.8),
						{
							"vel": Vector3(cos(a) * 2.5, _rng.randf_range(1.5, 3.0), sin(a) * 2.5),
							"drag": 1.4,
							"life": 0.8,
							"pop": 0.1
						}
					)
				rays(c, r * 1.2, Color(1, 0.75, 0.9), 0.4)
			"sparkles":
				for i in 14:
					var q := (
						ground(at)
						+ Vector3(
							_rng.randf_range(-r, r),
							_rng.randf_range(0.2, 1.6),
							_rng.randf_range(-r, r)
						)
					)
					bit(
						"star4",
						toward_cam(q),
						_rng.randf_range(0.3, 0.55),
						col.lightened(0.45),
						{
							"add": true,
							"life": _rng.randf_range(0.3, 0.6),
							"grow": Vector2(0.3, 1.0),
							"fade_in": 0.05
						}
					)
			"fire":
				for i in 16:
					var a := _rng.randf() * TAU
					var q := (
						ground(at) + Vector3(cos(a), 0.0, sin(a)) * r * _rng.randf_range(0.1, 0.9)
					)
					bit(
						"dot",
						toward_cam(q, 0.5),
						_rng.randf_range(0.5, 0.8),
						Color(1, _rng.randf_range(0.35, 0.8), 0.1),
						{
							"add": true,
							"vel": Vector3(0, _rng.randf_range(2.0, 3.5), 0),
							"life": 0.55,
							"grow": Vector2(1.0, 0.25)
						}
					)
				ring_ground(at, 0.2, r, Color(1, 0.5, 0.15), 0.4)
			"sludge":
				for i in 10:
					var a := _rng.randf() * TAU
					bit(
						PX + "fx/bubble.png",
						c,
						_rng.randf_range(0.3, 0.45),
						Color(0.75, 0.35, 0.95),
						{
							"vel": Vector3(cos(a) * 2.0, _rng.randf_range(2.0, 3.5), sin(a) * 2.0),
							"grav": 9.0,
							"life": 0.7
						}
					)
				ring_ground(at, 0.2, r, Color(0.65, 0.3, 0.85), 0.5)
			"flash":
				flash(c, r * 1.5, col.lightened(0.5), 0.25)
			"sound":
				for i in 3:
					later(
						i * 0.1,
						func() -> void:
							ring_air(c, 0.3, r * 1.1, Color(col.lightened(0.5), 0.85), 0.35)
					)
			"bolt":
				vfx.sky_bolt("thunder", at, 0.5, false)
			"shock":
				ring_ground(at, 0.2, r * 1.3, Color(1, 1, 1), 0.3)
				ring_air(c, 0.2, r, Color(1, 1, 1, 0.8), 0.3)
			"spikes":
				spikes(at, r, col, 3.0)
			"dust":
				dust(at, 14, r * 0.7)
			"cloud":
				for i in 6:
					var a := _rng.randf() * TAU
					bit(
						"cloud",
						ground(at) + Vector3(cos(a) * r * 0.4, 0.5, sin(a) * r * 0.4),
						_rng.randf_range(0.8, 1.2),
						Color(col.lightened(0.2), 0.7),
						{
							"vel": Vector3(cos(a), 0.3, sin(a)),
							"drag": 1.5,
							"life": 0.9,
							"grow": Vector2(0.5, 1.4),
							"fade": 0.5
						}
					)
			"petals":
				repeat(
					0.025,
					0.8,
					func(_i: int, age: float) -> bool:
						var a := _rng.randf() * TAU
						var rr := r * clampf(age / 0.5, 0.2, 1.0) * _rng.randf_range(0.5, 1.0)
						var q := (
							ground(at)
							+ Vector3(cos(a) * rr, _rng.randf_range(0.2, 1.5), sin(a) * rr)
						)
						bit(
							"petal",
							toward_cam(q, 0.4),
							_rng.randf_range(0.26, 0.36),
							Color(1, _rng.randf_range(0.6, 0.85), 0.88),
							{
								"vel": Vector3(-sin(a), 0.3, cos(a)) * 4.0,
								"life": 0.5,
								"face": ProcFx.Face.ROLL,
								"roll": _rng.randf() * TAU,
								"spin": 7.0
							}
						)
						return true
				)
			"edges":
				for i in 8:
					var a := TAU * i / 8.0
					var q := ground(at) + Vector3(cos(a), 0, sin(a)) * r * (0.35 + 0.15 * (i % 2))
					later(
						i * 0.05,
						func() -> void:
							bit(
								"spike",
								q + Vector3(0, 0.45, 0),
								0.95,
								Color(0.78, 0.72, 0.62),
								{"face": ProcFx.Face.UPRIGHT, "life": 0.8, "pop": 0.08, "fade": 0.3}
							)
							clods(q, 2, 3.5, PX + "objects/debris_rock.png", 0.26)
					)
				later(
					0.1,
					func() -> void:
						bit(
							"spike",
							ground(at) + Vector3(0, 0.7, 0),
							1.4,
							Color(0.85, 0.8, 0.7),
							{"face": ProcFx.Face.UPRIGHT, "life": 0.8, "pop": 0.08, "fade": 0.3}
						)
				)
				dust(at, 12, r * 0.6)


func quake(at: Vector3, r: float, col := Color(0.85, 0.72, 0.5)) -> void:
	ring_ground(at, 0.2, r, Color(1, 1, 1, 0.9), 0.5)
	later(0.1, func() -> void: ring_ground(at, 0.2, r * 0.75, Color(0.95, 0.85, 0.6), 0.45))
	later(0.2, func() -> void: ring_ground(at, 0.2, r * 1.05, Color(1, 1, 1, 0.7), 0.4))
	bit(
		"crack",
		ground(at),
		minf(r * 1.4, 5.0),
		Color(1, 1, 1, 0.85),
		{"face": ProcFx.Face.GROUND, "life": 1.8, "fade": 0.4, "spin": 0.0}
	)
	for i in 3:
		later(
			i * 0.08,
			func() -> void:
				var a := _rng.randf() * TAU
				var q := at + Vector3(cos(a), 0, sin(a)) * r * _rng.randf_range(0.2, 0.8)
				clods(q, 5, 4.5)
				clods(q, 2, 4.0, PX + "objects/debris_rock.png", 0.36)
		)
	dust(at, 16, r * 0.8)


## Nuvem de tempestade em cima do ponto (aviso do Thunder).
func storm_cloud(at: Vector3, life: float, col: Color) -> void:
	var top := ground(at) + Vector3(0, 2.1, 0)
	for i in 5:
		var off := Vector3(
			_rng.randf_range(-0.9, 0.9), _rng.randf_range(-0.15, 0.2), _rng.randf_range(-0.4, 0.4)
		)
		bit(
			"cloud",
			top + off,
			_rng.randf_range(1.3, 1.8),
			col.lightened(_rng.randf_range(-0.05, 0.12)),
			{"life": life, "grow": Vector2(0.5, 1.05), "fade_in": 0.2, "fade": 0.2, "wobble": 0.04}
		)
	repeat(
		0.12,
		life,
		func(_i: int, _a: float) -> bool:
			if _rng.randf() < 0.5:
				bit(
					"star4",
					top + Vector3(_rng.randf_range(-0.8, 0.8), _rng.randf_range(-0.3, 0.1), 0.3),
					0.5,
					Color(1, 0.95, 0.5),
					{"add": true, "life": 0.08}
				)
			return true
	)
	bit(
		"glow",
		ground(at),
		2.0,
		Color(0.1, 0.1, 0.15, 0.45),
		{"face": ProcFx.Face.GROUND, "life": life, "fade_in": 0.2, "fade": 0.2}
	)


## Coisas que caem do alto e chegam ao chão em `t` s (pedras do Rock Slide/Stone Edge, meteoro).
func falling(
	at: Vector3, r: float, n: int, t: float, tex: String, size: float, col := Color.WHITE
) -> void:
	var g := 22.0
	for i in n:
		var a := _rng.randf() * TAU
		var q := ground(at) + Vector3(cos(a), 0, sin(a)) * r * sqrt(_rng.randf()) * 0.8
		var fall := clampf(t - 0.04 * i, 0.15, 0.6)
		var start := maxf(t - fall - 0.04 * i, 0.0)
		later(start, _drop_one.bind(q, fall, g, tex, size, col))


func _drop_one(q: Vector3, fall: float, g: float, tex: String, size: float, col: Color) -> void:
	var h := 0.5 * g * fall * fall
	var o := {
		"grav": g,
		"life": fall,
		"fade": 0.0,
		"face": ProcFx.Face.ROLL,
		"roll": _rng.randf() * TAU,
		"spin": _rng.randf_range(-3, 3),
	}
	var f := bit(tex, q + Vector3(0, h + 0.3, 0), size * _rng.randf_range(0.8, 1.2), col, o)
	if f:
		f.on_end = _rock_landed.bind(q)
	bit(
		"glow",
		q,
		size * 1.2,
		Color(0, 0, 0, 0.5),
		{"face": ProcFx.Face.GROUND, "life": fall, "grow": Vector2(0.3, 1.0), "fade": 0.0}
	)


func _rock_landed(_f: ProcFx, q: Vector3) -> void:
	dust(q, 4, 0.3)
	clods(q, 3, 3.0, PX + "objects/debris_rock.png", 0.26)


## Pó (Sleep Powder, Stun Spore, Spore...) caindo em cima da área.
func powder(at: Vector3, r: float, secs: float, col: Color, spore: String) -> void:
	repeat(
		0.035,
		maxf(secs, 0.3),
		func(_i: int, _a: float) -> bool:
			var q := (
				ground(at)
				+ Vector3(
					_rng.randf_range(-r, r) * 0.8,
					_rng.randf_range(1.8, 2.4),
					_rng.randf_range(-r, r) * 0.8
				)
			)
			bit(
				"dot",
				toward_cam(q, 0.3),
				_rng.randf_range(0.16, 0.26),
				col.lightened(0.35),
				{
					"vel": Vector3(_rng.randf_range(-0.3, 0.3), -_rng.randf_range(2.5, 3.5), 0),
					"life": 0.6,
					"wobble": 0.08,
					"fade": 0.3
				}
			)
			return true
	)
	if spore != "":
		vfx.pmd(
			spore,
			toward_cam(ground(at) + Vector3(0, 1.6, 0)),
			Vector3.FORWARD,
			{"scale": 1.8, "billboard": true}
		)


func pillar(at: Vector3, col: Color, life := 0.6, r := 0.8) -> void:
	bit(
		"column",
		ground(at) + Vector3(0, 2.0, 0),
		r * 1.8,
		Color(col.lightened(0.3), 0.9),
		{
			"face": ProcFx.Face.UPRIGHT,
			"add": true,
			"life": life,
			"grow": Vector2(0.4, 1.1),
			"fade": 0.5
		}
	)
	ring_ground(at, 0.3, r * 1.3, col.lightened(0.3), life)


func vortex(at: Vector3, r: float, col: Color, life: float, tex := "swirl") -> void:
	bit(
		tex,
		ground(at),
		r * 2.3,
		Color(col, 0.85),
		{
			"face": ProcFx.Face.GROUND,
			"life": life,
			"spin": 9.0,
			"add": true,
			"fade_in": 0.15,
			"fade": 0.25
		}
	)
	bit(
		tex,
		ground(at) + Vector3(0, 0.5, 0),
		r * 1.8,
		Color(col.lightened(0.3), 0.6),
		{
			"face": ProcFx.Face.GROUND,
			"life": life,
			"spin": -12.0,
			"add": true,
			"fade_in": 0.15,
			"fade": 0.25
		}
	)


func spikes(at: Vector3, r: float, col: Color, life: float) -> void:
	for i in 7:
		var a := TAU * i / 7.0 + _rng.randf() * 0.4
		var q := (
			ground(at)
			+ Vector3(cos(a), 0, sin(a)) * r * _rng.randf_range(0.2, 0.8)
			+ Vector3(0, 0.15, 0)
		)
		bit(
			"spike",
			q,
			0.35,
			col.lightened(0.2),
			{"face": ProcFx.Face.UPRIGHT, "life": life, "pop": 0.15, "fade": 0.15}
		)


## Zona que fica (Sand Tomb, Fire Spin, Poison Powder, Toxic Spikes, Grassy Terrain...).
func zone(user: BattleFighter, mv: Dictionary, lk: Dictionary, at_local: Vector3) -> void:
	var at := _gpos(at_local)
	var r := float(mv.get("radius", 2.0))
	var dur := float(mv.get("duration", 4.0))
	var col := col_of(mv, lk)
	var type := String(mv.get("type", "normal"))
	var style := String(lk.get("zone", "vortex"))
	match style:
		"vortex", "fire", "sand", "water":
			var tex := "swirl"
			vortex(at, r * 0.75, col, dur)
			repeat(
				0.06,
				dur,
				func(_i: int, _a: float) -> bool:
					var a := _rng.randf() * TAU
					var q := (
						ground(at)
						+ Vector3(cos(a) * r * 0.6, _rng.randf_range(0.0, 0.3), sin(a) * r * 0.6)
					)
					var v := (
						Vector3(-sin(a), 0, cos(a)) * 3.0
						+ Vector3(0, _rng.randf_range(1.5, 2.5), 0)
					)
					match style:
						"fire":
							bit(
								"dot",
								toward_cam(q, 0.4),
								_rng.randf_range(0.4, 0.7),
								Color(1, _rng.randf_range(0.3, 0.7), 0.08),
								{"add": true, "vel": v, "life": 0.5, "grow": Vector2(1.0, 0.2)}
							)
						"sand":
							bit(
								"glow",
								q,
								_rng.randf_range(0.4, 0.6),
								Color(0.86, 0.72, 0.45, 0.8),
								{"vel": v, "life": 0.6, "grow": Vector2(0.6, 1.2)}
							)
							if _rng.randf() < 0.3:
								bit(
									"clod",
									q,
									0.2,
									Color.WHITE,
									{
										"vel": v,
										"life": 0.6,
										"face": ProcFx.Face.ROLL,
										"roll": 0.0,
										"spin": 8.0
									}
								)
						"water":
							bit(
								"drop",
								toward_cam(q, 0.4),
								0.28,
								Color(0.6, 0.85, 1.0),
								{
									"vel": v,
									"life": 0.5,
									"face": ProcFx.Face.ROLL,
									"roll": _rng.randf() * TAU
								}
							)
						_:
							burst(type, q, 1, 1.0, 0.9, 0.5)
					return true
			)
		"cloud":
			repeat(
				0.12,
				dur,
				func(_i: int, _a: float) -> bool:
					var a := _rng.randf() * TAU
					var q := (
						ground(at)
						+ Vector3(cos(a), 0, sin(a)) * r * sqrt(_rng.randf()) * 0.8
						+ Vector3(0, 0.35, 0)
					)
					bit(
						"cloud",
						q,
						_rng.randf_range(0.8, 1.3),
						Color(col.lightened(0.15), 0.55),
						{
							"vel":
							Vector3(_rng.randf_range(-0.3, 0.3), 0.3, _rng.randf_range(-0.3, 0.3)),
							"life": 1.0,
							"fade_in": 0.25,
							"grow": Vector2(0.6, 1.3),
							"fade": 0.5
						}
					)
					if _rng.randf() < 0.4:
						burst(type, q, 1, 0.8, 0.8, 0.4)
					if _i % 6 == 0 and String(lk.get("spore", "")) != "":
						vfx.pmd(
							String(lk.spore),
							toward_cam(q + Vector3(0, 0.4, 0)),
							Vector3.FORWARD,
							{"scale": 1.3, "billboard": true}
						)
					return true
			)
		"petals":
			repeat(
				0.04,
				dur,
				func(_i: int, _a: float) -> bool:
					var a := _rng.randf() * TAU
					var q := (
						ground(at)
						+ Vector3(cos(a) * r * 0.7, _rng.randf_range(0.1, 1.4), sin(a) * r * 0.7)
					)
					bit(
						"petal",
						toward_cam(q, 0.4),
						_rng.randf_range(0.25, 0.35),
						Color(1, _rng.randf_range(0.6, 0.8), 0.85),
						{
							"vel": Vector3(-sin(a), 0.2, cos(a)) * 3.0,
							"life": 0.6,
							"face": ProcFx.Face.ROLL,
							"roll": _rng.randf() * TAU,
							"spin": 6.0
						}
					)
					return true
			)
		"spikes":
			spikes(at, r, col, dur)
		"grass":
			bit(
				"ring_soft",
				ground(at),
				r * 2.3,
				Color(0.4, 0.9, 0.35, 0.5),
				{"face": ProcFx.Face.GROUND, "life": dur, "fade_in": 0.3, "fade": 0.15}
			)
			repeat(
				0.1,
				dur,
				func(_i: int, _a: float) -> bool:
					var q := (
						ground(at)
						+ Vector3(_rng.randf_range(-r, r) * 0.7, 0.1, _rng.randf_range(-r, r) * 0.7)
					)
					bit(
						PX + "fx/leaf.png",
						toward_cam(q, 0.3),
						0.3,
						Color.WHITE,
						{
							"vel": Vector3(0, _rng.randf_range(0.8, 1.4), 0),
							"life": 0.7,
							"face": ProcFx.Face.ROLL,
							"roll": _rng.randf() * TAU,
							"spin": 3.0,
							"wobble": 0.1
						}
					)
					return true
			)
		"sparkles":
			repeat(
				0.06,
				dur,
				func(_i: int, _a: float) -> bool:
					var q := (
						ground(at)
						+ Vector3(
							_rng.randf_range(-r, r) * 0.8,
							_rng.randf_range(0.1, 1.4),
							_rng.randf_range(-r, r) * 0.8
						)
					)
					bit(
						"star4",
						toward_cam(q),
						_rng.randf_range(0.25, 0.45),
						col.lightened(0.45),
						{"add": true, "life": 0.45, "grow": Vector2(0.3, 1.0)}
					)
					return true
			)


# --- Corpo do usuário ---


## Escudo hexagonal em volta do lutador (Protect, Light Screen, Iron Defense...).
func shield(user: BattleFighter, col: Color, dur: float, tex := "hex") -> void:
	if not is_instance_valid(user):
		return
	var h := user.visual_height()
	var c := center(user, 0.5)
	bit(
		tex,
		toward_cam(c, 1.3),
		maxf(h * 1.7, 1.3),
		Color(col.lightened(0.35), 0.85),
		{"add": true, "follow": user, "life": dur, "pop": 0.18, "fade": 0.25}
	)
	ring_air(c, 0.3, maxf(h, 0.8), Color(1, 1, 1, 0.9), 0.3)
	flash(c + Vector3(0.2, h * 0.3, 0), 0.6, Color(1, 1, 1))


## Cura: brilhos verdes/dourados subindo e o ícone de coração com cruz.
func heal(user: BattleFighter, col := Color(0.6, 1.0, 0.6), secs := 0.7) -> void:
	if not is_instance_valid(user):
		return
	var h := user.visual_height()
	ring_ground(user.global_position, 0.2, 1.0, col, 0.5)
	repeat(
		0.045,
		secs,
		func(_i: int, _a: float) -> bool:
			if not is_instance_valid(user) or not user.is_inside_tree():
				return false
			var a := _rng.randf() * TAU
			var q := (
				ground(user.global_position)
				+ Vector3(cos(a) * 0.45, _rng.randf_range(0.0, h * 0.7), sin(a) * 0.45)
			)
			bit(
				"star4" if _rng.randf() < 0.5 else "dot",
				toward_cam(q, 0.6),
				_rng.randf_range(0.2, 0.35),
				col.lightened(0.3),
				{
					"add": true,
					"vel": Vector3(0, _rng.randf_range(1.2, 2.0), 0),
					"life": 0.55,
					"grow": Vector2(1.0, 0.4)
				}
			)
			return true
	)
	icon_pop("heal", head_side(user), 0.55)


## Ondas de som (anéis que crescem a partir do usuário).
func sound(user: BattleFighter, col: Color, r: float, waves := 3) -> void:
	if not is_instance_valid(user):
		return
	var c := center(user, 0.55)
	for i in waves:
		later(
			i * 0.11,
			func() -> void:
				if not is_instance_valid(user):
					return
				ring_air(
					center(user, 0.55), 0.25, minf(r, 1.8), Color(col.lightened(0.45), 0.55), 0.4
				)
				ring_ground(
					user.global_position, 0.2, minf(r, 2.2), Color(col.lightened(0.3), 0.45), 0.4
				)
		)


func wind(user: BattleFighter, col: Color) -> void:
	repeat(
		0.03,
		0.6,
		func(_i: int, _a: float) -> bool:
			if not is_instance_valid(user) or not user.is_inside_tree():
				return false
			var a := _rng.randf() * TAU
			var q := (
				center(user, 0.4) + Vector3(cos(a) * 0.8, _rng.randf_range(-0.3, 0.6), sin(a) * 0.8)
			)
			var tang := Vector3(-sin(a), 0, cos(a))
			bit(
				"streak",
				toward_cam(q, 0.5),
				_rng.randf_range(0.6, 1.0),
				Color(1, 1, 1, 0.8),
				{
					"face": ProcFx.Face.ROLL,
					"roll": roll_of(tang),
					"vel": tang * 4.0,
					"life": 0.18,
					"add": true
				}
			)
			return true
	)


## Debuff em volta: anel saindo do usuário e o efeito indo até cada alvo no raio.
func emanate(user: BattleFighter, mv: Dictionary, lk: Dictionary, col: Color) -> void:
	var r := minf(float(mv.get("radius", 6.0)), 3.0)
	var shape := String(lk.get("to_targets", ""))
	if not bool(lk.get("no_ring", false)):
		ring_ground(user.global_position, 0.2, r, Color(col, 0.8), 0.45)
	if shape == "":
		return
	var arena = vfx.arena
	if not arena.has_method("targets_of"):
		return
	var from := center(user, 0.6)
	for t in arena.targets_of(user):
		if not is_instance_valid(t) or user.flat_to(t).length() > float(mv.get("radius", 6.0)):
			continue
		match shape:
			"hearts":
				seekers("heart", from, t, 4, Color(1, 0.55, 0.8), 0.36, 5.0)
				later(
					0.6,
					func() -> void:
						if is_instance_valid(t):
							icon_pop(
								"heart",
								center(t, 1.0) + Vector3(0, 0.3, 0),
								0.5,
								Color(1, 0.6, 0.85)
							)
				)
			"notes":
				seekers("note", from, t, 4, Color(1, 1, 0.8), 0.36, 4.0)
			"feathers":
				for i in 8:
					bit(
						"feather",
						(
							center(t, 1.0)
							+ Vector3(
								_rng.randf_range(-0.6, 0.6),
								1.0 + _rng.randf() * 0.6,
								_rng.randf_range(-0.3, 0.3)
							)
						),
						0.36,
						Color.WHITE,
						{
							"vel": Vector3(0, -1.2, 0),
							"life": 1.1,
							"wobble": 0.2,
							"face": ProcFx.Face.ROLL,
							"roll": _rng.randf() * TAU,
							"spin": 2.0,
							"fade": 0.3
						}
					)
			"sparkles":
				seekers("star4", from, t, 5, col.lightened(0.5), 0.36, 5.0, true)
			"glare":
				later(
					0.05,
					func() -> void:
						if is_instance_valid(t):
							flash(center(t, 0.6), 0.9, Color(1, 0.4, 0.3))
							rays(center(t, 0.6), 1.3, Color(1, 0.35, 0.3), 0.3)
				)
			"sound":
				later(
					0.15,
					func() -> void:
						if is_instance_valid(t):
							ring_air(center(t, 0.55), 0.2, 0.9, Color(1, 1, 1, 0.9), 0.3)
				)
			"smoke":
				for i in 4:
					bit(
						"cloud",
						center(t, 0.6) + Vector3(_rng.randf_range(-0.4, 0.4), 0, 0.2),
						1.0,
						Color(0.25, 0.24, 0.28, 0.85),
						{"life": 0.9, "grow": Vector2(0.5, 1.4), "fade_in": 0.1, "fade": 0.5}
					)
			"wind":
				for i in 6:
					var d := _gdir(user.flat_to(t))
					bit(
						"streak",
						toward_cam(
							center(t, 0.5) - d * 1.2 + Vector3(0, _rng.randf_range(-0.4, 0.4), 0)
						),
						1.1,
						Color(1, 1, 1, 0.85),
						{
							"face": ProcFx.Face.ROLL,
							"roll": roll_of(d),
							"vel": d * 6.0,
							"life": 0.25,
							"add": true
						}
					)


# --- Projétil ---


## Partículas atrás do projétil; nos golpes de status, um efeito onde ele acertou.
func projectile_trail(p: Node3D, mv: Dictionary) -> void:
	if not _ok():
		return
	var lk := look(mv)
	var style := String(lk.get("proj", mv.get("type", "normal")))
	if style == "none":
		return
	var col := col_of(mv, lk)
	var state := {"last": Vector3.ZERO, "have": false}
	var orb := String(lk.get("orb", ""))
	if orb != "":
		later(
			0.0,
			func() -> void:
				if is_instance_valid(p) and p.is_inside_tree():
					var tex := String(ICONS.get(orb, orb))
					bit(
						tex,
						p.global_position,
						float(lk.get("orb_size", 0.6)),
						(
							Color.WHITE
							if orb in ["moon", "heart", "note", "star"]
							else col.lightened(0.4)
						),
						{
							"follow": p,
							"life": 3.0,
							"fade": 0.02,
							"add": orb in ["glow", "dot", "star4"],
							"spin": float(lk.get("orb_spin", 0.0)),
							"face":
							(
								ProcFx.Face.ROLL
								if float(lk.get("orb_spin", 0.0)) != 0.0
								else ProcFx.Face.BILLBOARD
							),
							"roll": 0.0
						}
					)
					bit(
						"glow",
						p.global_position,
						float(lk.get("orb_size", 0.6)) * 1.8,
						Color(col.lightened(0.3), 0.6),
						{"follow": p, "life": 3.0, "fade": 0.02, "add": true}
					)
		)
	repeat(
		0.03,
		4.0,
		func(i: int, _a: float) -> bool:
			if not is_instance_valid(p) or not p.is_inside_tree() or bool(p.get("done")):
				return false
			var q := p.global_position
			state.last = q
			state.have = true
			match style:
				"fire":
					bit(
						"dot",
						toward_cam(q, 0.4),
						_rng.randf_range(0.3, 0.5),
						Color(1, _rng.randf_range(0.4, 0.8), 0.1),
						{
							"add": true,
							"vel":
							Vector3(_rng.randf_range(-0.4, 0.4), 1.2, _rng.randf_range(-0.4, 0.4)),
							"life": 0.3,
							"grow": Vector2(1.0, 0.2)
						}
					)
				"spark":
					if i % 2 == 0:
						bit(
							"star4",
							toward_cam(
								(
									q
									+ Vector3(
										_rng.randf_range(-0.2, 0.2), _rng.randf_range(-0.2, 0.2), 0
									)
								),
								0.4
							),
							0.3,
							Color(1, 0.95, 0.4),
							{"add": true, "life": 0.15}
						)
				"sparkle":
					bit(
						"star4",
						toward_cam(
							(
								q
								+ Vector3(
									_rng.randf_range(-0.15, 0.15), _rng.randf_range(-0.15, 0.15), 0
								)
							),
							0.4
						),
						_rng.randf_range(0.2, 0.35),
						col.lightened(0.5),
						{"add": true, "life": 0.35, "grow": Vector2(1.0, 0.2)}
					)
				"heart":
					if i % 3 == 0:
						bit(
							"heart",
							toward_cam(q, 0.4),
							0.26,
							Color(1, 0.6, 0.85),
							{"vel": Vector3(0, 0.6, 0), "life": 0.45, "wobble": 0.05}
						)
				"note":
					if i % 3 == 0:
						bit(
							"note",
							toward_cam(q, 0.4),
							0.3,
							Color.from_hsv(_rng.randf(), 0.3, 1.0),
							{"vel": Vector3(0, 0.6, 0), "life": 0.5, "wobble": 0.06}
						)
				"glow":
					bit(
						"dot",
						toward_cam(q, 0.4),
						0.35,
						Color(col.lightened(0.3), 0.8),
						{"add": true, "life": 0.22, "grow": Vector2(1.0, 0.3)}
					)
				"smoke":
					if i % 2 == 0:
						bit(
							"cloud",
							q,
							0.45,
							Color(col.lightened(0.1), 0.6),
							{"life": 0.4, "grow": Vector2(0.6, 1.2)}
						)
				"water":
					if i % 2 == 0:
						bit(
							"drop",
							toward_cam(q, 0.4),
							0.22,
							Color(0.6, 0.85, 1.0),
							{
								"vel": Vector3(_rng.randf_range(-0.5, 0.5), 0.8, 0),
								"grav": 8.0,
								"life": 0.35
							}
						)
				"wind":
					if i % 2 == 0:
						bit(
							"ring",
							toward_cam(q, 0.4),
							0.45,
							Color(1, 1, 1, 0.6),
							{"add": true, "life": 0.2, "grow": Vector2(0.5, 1.2)}
						)
				"none":
					pass
				_:
					if i % 2 == 0:
						burst(
							style if STYLE.has(style) else String(mv.get("type", "normal")),
							q,
							1,
							0.6,
							0.75,
							0.3
						)
			return true,
		func() -> void:
			if state.have and float(mv.get("power", 0)) <= 0.0:
				var travelled := float(p.get("travelled")) if is_instance_valid(p) else 0.0
				var reach := float(mv.get("range", 10.0))
				if travelled < reach - 0.4:
					status_land(mv, lk, state.last)
	)


## Efeito do golpe de status no ponto onde o projétil bateu (sem dano não há on_hit).
func status_land(mv: Dictionary, lk: Dictionary, at: Vector3) -> void:
	var col := col_of(mv, lk)
	var hit = lk.get("status_hit", ["flash"])
	if hit is String:
		hit = [hit]
	for s in hit:
		match String(s):
			"flash":
				flash(at, 0.8, col.lightened(0.4))
				burst(String(mv.get("type", "normal")), at, 6, 2.0)
			"hearts":
				for i in 7:
					var a := _rng.randf() * TAU
					bit(
						"heart",
						toward_cam(at),
						_rng.randf_range(0.28, 0.4),
						Color(1, 0.55, 0.8),
						{
							"vel": Vector3(cos(a) * 2.0, _rng.randf_range(1.0, 2.2), sin(a) * 2.0),
							"drag": 1.5,
							"life": 0.8,
							"pop": 0.1
						}
					)
			"icon":
				icon_pop(String(lk.get("icon", "star")), at + Vector3(0, 0.6, 0), 0.6)
			"cloud":
				for i in 5:
					bit(
						"cloud",
						at + Vector3(_rng.randf_range(-0.4, 0.4), _rng.randf_range(-0.2, 0.3), 0.2),
						_rng.randf_range(0.7, 1.0),
						Color(col.lightened(0.2), 0.75),
						{"life": 0.8, "grow": Vector2(0.5, 1.3), "fade": 0.5}
					)
			"web":
				vfx.pmd(
					"string_shot_web",
					toward_cam(at),
					Vector3.FORWARD,
					{"scale": 1.4, "billboard": true}
				)
			"sparks":
				for i in 3:
					vfx.pmd(
						"spark",
						toward_cam(
							(
								at
								+ Vector3(
									_rng.randf_range(-0.3, 0.3), _rng.randf_range(-0.3, 0.3), 0
								)
							)
						),
						Vector3.FORWARD,
						{"scale": 0.5, "billboard": true}
					)
			"rings":
				for i in 3:
					later(
						i * 0.08,
						func() -> void: ring_air(at, 0.2, 0.9, Color(col.lightened(0.4), 0.9), 0.3)
					)
			"fire":
				for i in 8:
					bit(
						"dot",
						toward_cam(
							(
								at
								+ Vector3(
									_rng.randf_range(-0.3, 0.3), _rng.randf_range(-0.3, 0.2), 0
								)
							)
						),
						_rng.randf_range(0.35, 0.55),
						Color(1, _rng.randf_range(0.35, 0.8), 0.1),
						{
							"add": true,
							"vel": Vector3(0, _rng.randf_range(1.5, 2.5), 0),
							"life": 0.45,
							"grow": Vector2(1.0, 0.2)
						}
					)
			"pmd":
				var r := PmdFx.role(PmdFx.move_roles(String(mv.get("id", ""))), "hit")
				if not r.is_empty():
					vfx.pmd(String(r.fx), toward_cam(at), Vector3.FORWARD, r)
			var other:
				if String(other) in LAND_SHAPES:
					var l2 := lk.duplicate()
					l2.land = [String(other)]
					land(null, mv, l2, at, 1.2, false)


# --- Estágios ---


func stat_change(f: BattleFighter, key: String, up: bool) -> void:
	if not _ok() or not is_instance_valid(f) or not f.is_inside_tree():
		return
	var col: Color = STAT_COL.get(key, Color.WHITE)
	for i in 3:
		var x := (float(i) - 1.0) * 0.32
		var base := center(f, 0.35 if up else 0.95) + Vector3(x, 0, 0)
		later(
			i * 0.07,
			func() -> void:
				if is_instance_valid(f):
					bit(
						"arrow",
						toward_cam(base),
						0.34,
						col,
						{
							"vel": Vector3(0, 1.6 if up else -1.4, 0),
							"life": 0.55,
							"pop": 0.08,
							"flip_v": not up,
							"fade": 0.4
						}
					)
		)


# --- Cavar (ganchos para a mecânica) ---


## Rastro de terra que anda pelo chão de `from` até `to` (local da arena) em `duration` s.
func dig_trail(user: BattleFighter, from: Vector3, to: Vector3, duration: float) -> void:
	if not _ok():
		return
	var a := ground(_gpos(from))
	var b := ground(_gpos(to))
	var d := b - a
	d.y = 0.0
	var dirn := d.normalized() if d.length() > 0.01 else Vector3.FORWARD
	var dur := maxf(duration, 0.1)
	repeat(
		0.04,
		dur,
		func(i: int, age: float) -> bool:
			var p := a.lerp(b, clampf(age / dur, 0.0, 1.0))
			bit(
				"glow",
				p + Vector3(0, 0.12, 0),
				_rng.randf_range(0.6, 0.85),
				Color(0.5, 0.36, 0.22, 0.9),
				{"life": 0.5, "grow": Vector2(1.0, 0.7), "fade": 0.5}
			)
			bit(
				"crack",
				p,
				0.7,
				Color(1, 1, 1, 0.8),
				{"face": ProcFx.Face.GROUND, "life": 1.4, "fade": 0.5}
			)
			if i % 2 == 0:
				clods(p, 2, 3.0)
			if i % 4 == 0:
				bit(
					"glow",
					p + Vector3(0, 0.3, 0),
					_rng.randf_range(0.6, 0.9),
					Color(0.8, 0.68, 0.5, 0.75),
					{
						"vel":
						(
							Vector3(_rng.randf_range(-0.6, 0.6), 0.8, _rng.randf_range(-0.6, 0.6))
							- dirn * 0.6
						),
						"drag": 2.0,
						"life": 0.6,
						"grow": Vector2(0.5, 1.4),
						"fade": 0.6
					}
				)
			return true
	)


## Entrou no chão: terra espirrando e um buraco escuro onde estava.
func burrow(user: BattleFighter) -> void:
	if not _ok() or not is_instance_valid(user) or not user.is_inside_tree():
		return
	var at := user.global_position
	bit(
		"hole",
		ground(at) + Vector3(0, 0.01, 0),
		1.2,
		Color(0.1, 0.07, 0.05, 1.0),
		{"face": ProcFx.Face.GROUND, "life": 2.5, "pop": 0.15, "fade": 0.3}
	)
	clods(at, 12, 4.5)
	dust(at, 10, 0.5, Color(0.65, 0.5, 0.33, 0.85))
	ring_ground(at, 0.2, 1.1, Color(0.7, 0.55, 0.35), 0.35)
	vfx.pmd(
		"dig",
		toward_cam(ground(at) + Vector3(0, 0.5, 0)),
		Vector3.FORWARD,
		{"scale": 1.2, "billboard": true}
	)


## Saiu do chão: estouro de terra e pedras, anel de poeira.
func unburrow(user: BattleFighter) -> void:
	if not _ok() or not is_instance_valid(user) or not user.is_inside_tree():
		return
	var at := user.global_position
	bit(
		"hole",
		ground(at) + Vector3(0, 0.01, 0),
		1.3,
		Color(0.1, 0.07, 0.05, 1.0),
		{"face": ProcFx.Face.GROUND, "life": 1.6, "fade": 0.5}
	)
	clods(at, 16, 6.0)
	clods(at, 5, 5.0, PX + "objects/debris_rock.png", 0.34)
	dust(at, 14, 0.6, Color(0.7, 0.55, 0.38, 0.85))
	ring_ground(at, 0.2, 1.6, Color(0.85, 0.72, 0.5), 0.45)
	flash(ground(at) + Vector3(0, 0.6, 0), 1.0, Color(1, 0.9, 0.7))
	vfx.pmd(
		"dig",
		toward_cam(ground(at) + Vector3(0, 0.6, 0)),
		Vector3.FORWARD,
		{"scale": 1.5, "billboard": true}
	)


# --- Campo, clima e escudos (ganchos da mecânica dos golpes) ---


func _field_center() -> Vector3:
	var sum := Vector3.ZERO
	var n := 0
	var fs = vfx.arena.get("fighters")
	if fs is Array:
		for f in fs:
			if is_instance_valid(f) and f.is_inside_tree() and f.active():
				sum += f.global_position
				n += 1
	return ground(sum / n if n > 0 else vfx.arena.global_position)


func _side_fighters(side: int) -> Array:
	var out := []
	var fs = vfx.arena.get("fighters")
	if fs is Array:
		for f in fs:
			if is_instance_valid(f) and f.is_inside_tree() and f.active() and int(f.side) == side:
				out.append(f)
	return out


## Bolha de Protect por `secs` s.
func protect_shield(f: BattleFighter, secs: float) -> void:
	if _ok() and is_instance_valid(f):
		shield(f, Color(0.45, 1.0, 0.6), secs)


## Holofote (Follow Me, Rage Powder): coluna de luz que segue o lutador e seta em cima.
func spotlight(f: BattleFighter, secs: float) -> void:
	if not _ok() or not is_instance_valid(f):
		return
	bit(
		"column",
		ground(f.global_position) + Vector3(0, 2.0, 0),
		1.4,
		Color(1, 0.95, 0.6, 0.55),
		{
			"face": ProcFx.Face.UPRIGHT,
			"add": true,
			"follow": f,
			"life": secs,
			"fade_in": 0.2,
			"fade": 0.15
		}
	)
	bit(
		"ring_soft",
		ground(f.global_position),
		1.6,
		Color(1, 0.95, 0.6, 0.6),
		{
			"face": ProcFx.Face.GROUND,
			"add": true,
			"follow": f,
			"life": secs,
			"fade_in": 0.2,
			"fade": 0.15
		}
	)
	icon_pop("arrow", center(f, 1.0) + Vector3(0, 0.5, 0), 0.6, Color(1, 0.9, 0.4), 1.0, -0.3)


## Barreira do lado (Light Screen, Reflect, Safeguard, Tailwind...) sobre cada lutador do lado.
func screen(side: int, kind: String, secs: float) -> void:
	if not _ok():
		return
	var cols := {
		"light_screen": Color(1.0, 0.85, 0.5),
		"reflect": Color(0.5, 0.75, 1.0),
		"safeguard": Color(0.8, 0.7, 1.0),
		"quick_guard": Color(1.0, 0.65, 0.3),
		"tailwind": Color(0.8, 0.95, 1.0)
	}
	var col: Color = cols.get(kind, Color(0.8, 0.9, 1.0))
	for f in _side_fighters(side):
		if kind == "tailwind":
			wind(f, col)
			repeat(
				0.25,
				secs,
				func(_i: int, _a: float) -> bool:
					if not is_instance_valid(f) or not f.active():
						return false
					var d := _gdir(f.facing)
					var q := (
						center(f, 0.4)
						+ Vector3(_rng.randf_range(-0.6, 0.6), _rng.randf_range(-0.2, 0.4), 0)
						- d * 0.6
					)
					bit(
						"streak",
						toward_cam(q, 0.5),
						0.7,
						Color(1, 1, 1, 0.6),
						{
							"face": ProcFx.Face.ROLL,
							"roll": roll_of(d),
							"vel": -d * 2.0,
							"life": 0.2,
							"add": true
						}
					)
					return true
			)
			continue
		shield(f, col, 0.9)
		bit(
			"hex",
			toward_cam(center(f, 0.5), 1.3),
			maxf(f.visual_height() * 1.7, 1.3),
			Color(col, 0.18),
			{"add": true, "follow": f, "life": secs, "fade_in": 0.8, "fade": 0.1}
		)


## Clima na quadra inteira: rain, sun, sand, hail.
func weather(kind: String, secs: float) -> void:
	if not _ok():
		return
	var every := 0.03 if kind in ["rain", "hail"] else 0.05
	if kind == "sun":
		every = 0.25
		bit(
			"glow",
			_field_center() + Vector3(0, 0.05, 0),
			12.0,
			Color(1, 0.85, 0.4, 0.22),
			{"face": ProcFx.Face.GROUND, "add": true, "life": secs, "fade_in": 0.8, "fade": 0.1}
		)
	repeat(
		every,
		secs,
		func(_i: int, _a: float) -> bool:
			var q := (
				_field_center()
				+ Vector3(_rng.randf_range(-7.0, 7.0), 0, _rng.randf_range(-5.0, 5.0))
			)
			match kind:
				"rain":
					bit(
						"streak",
						q + Vector3(0, _rng.randf_range(2.6, 3.4), 0),
						0.55,
						Color(0.7, 0.85, 1.0, 0.7),
						{
							"face": ProcFx.Face.ROLL,
							"roll": -PI * 0.5 - 0.15,
							"vel": Vector3(0.6, -10.0, 0),
							"life": 0.3,
							"fade": 0.15
						}
					)
				"hail":
					bit(
						PX + "fx/snowflake.png",
						q + Vector3(0, 3.0, 0),
						0.28,
						Color(0.9, 0.97, 1.0),
						{
							"vel": Vector3(0.4, -5.0, 0),
							"life": 0.6,
							"spin": 3.0,
							"face": ProcFx.Face.ROLL,
							"roll": 0.0,
							"fade": 0.15
						}
					)
				"sand":
					bit(
						"glow",
						q + Vector3(-3.0, _rng.randf_range(0.2, 2.0), 0),
						_rng.randf_range(0.5, 0.8),
						Color(0.86, 0.72, 0.48, 0.6),
						{
							"vel": Vector3(_rng.randf_range(6.0, 9.0), 0, 0),
							"life": 0.9,
							"grow": Vector2(0.6, 1.2)
						}
					)
				"sun":
					bit(
						"star4",
						q + Vector3(0, _rng.randf_range(0.5, 2.5), 0),
						0.4,
						Color(1, 0.9, 0.5),
						{"add": true, "life": 0.5, "grow": Vector2(0.3, 1.0)}
					)
			return true
	)


## Terreno ("grassy"): chão verde em volta da luta, folhas subindo.
func terrain(kind: String, secs: float) -> void:
	if not _ok():
		return
	var col := Color(0.4, 0.9, 0.35) if kind == "grassy" else Color(0.9, 0.8, 1.0)
	if kind == "psychic":
		col = Color(0.95, 0.5, 0.85)
	bit(
		"ring_soft",
		_field_center(),
		12.0,
		Color(col, 0.45),
		{"face": ProcFx.Face.GROUND, "life": secs, "fade_in": 0.5, "fade": 0.1}
	)
	repeat(
		0.12,
		secs,
		func(_i: int, _a: float) -> bool:
			var q := (
				_field_center()
				+ Vector3(_rng.randf_range(-6.0, 6.0), 0.1, _rng.randf_range(-4.0, 4.0))
			)
			bit(
				PX + "fx/leaf.png" if kind == "grassy" else "star4",
				toward_cam(q, 0.3),
				0.3,
				Color.WHITE,
				{
					"vel": Vector3(0, _rng.randf_range(0.6, 1.2), 0),
					"life": 0.8,
					"face": ProcFx.Face.ROLL,
					"roll": _rng.randf() * TAU,
					"spin": 3.0,
					"wobble": 0.1
				}
			)
			return true
	)


## Gravidade: anéis roxos encolhendo e riscos caindo pela quadra.
func gravity(secs: float) -> void:
	if not _ok():
		return
	var c := _field_center()
	for i in 3:
		later(i * 0.15, func() -> void: ring_ground(c, 6.0, 0.4, Color(0.65, 0.45, 1.0, 0.85), 0.6))
	repeat(
		0.08,
		secs,
		func(_i: int, _a: float) -> bool:
			var q := (
				_field_center()
				+ Vector3(
					_rng.randf_range(-6.0, 6.0),
					_rng.randf_range(2.0, 3.0),
					_rng.randf_range(-4.0, 4.0)
				)
			)
			bit(
				"streak",
				q,
				0.7,
				Color(0.75, 0.6, 1.0, 0.6),
				{
					"face": ProcFx.Face.ROLL,
					"roll": -PI * 0.5,
					"vel": Vector3(0, -7.0, 0),
					"life": 0.3,
					"add": true
				}
			)
			return true
	)


## Haze: névoa branca que varre a quadra a partir do usuário.
func haze(user: BattleFighter) -> void:
	if not _ok():
		return
	var c := ground(user.global_position) if is_instance_valid(user) else _field_center()
	for i in 18:
		var a := TAU * i / 18.0
		bit(
			"cloud",
			c + Vector3(cos(a) * 0.5, 0.4, sin(a) * 0.5),
			_rng.randf_range(1.0, 1.4),
			Color(0.88, 0.92, 1.0, 0.7),
			{
				"vel": Vector3(cos(a), 0.15, sin(a)) * 4.0,
				"drag": 1.2,
				"life": 1.4,
				"grow": Vector2(0.6, 2.0),
				"fade": 0.5
			}
		)


## Toxic Spikes no chão do lado (`at` local da arena).
func toxic_spikes(_side: int, at: Vector3, r: float, life: float) -> void:
	if _ok():
		spikes(_gpos(at), r, Color(0.75, 0.4, 0.9), life)


# --- Arremesso e choque (ganchos da física) ---


## Lutador arremessado bateu em algo (`at` local da arena; what = cerca, caixa, pedra, parede...).
func crash(f: BattleFighter, at: Vector3, what: String) -> void:
	if not _ok():
		return
	var p := _gpos(at)
	var h := f.visual_height() if is_instance_valid(f) else 1.0
	var c := ground(p) + Vector3(0, h * 0.5, 0)
	flash(c, 1.1, Color(1, 0.95, 0.8))
	ring_air(c, 0.2, 1.0, Color(1, 1, 1, 0.9), 0.25)
	dust(p, 10, 0.5)
	for n in 5:
		var a := _rng.randf() * TAU
		bit(
			"star5",
			toward_cam(c + Vector3(0, h * 0.3, 0)),
			0.3,
			Color(1, 0.95, 0.45),
			{
				"vel": Vector3(cos(a) * 2.0, _rng.randf_range(1.2, 2.2), sin(a) * 2.0),
				"drag": 1.4,
				"life": 0.6,
				"spin": 6.0,
				"face": ProcFx.Face.ROLL,
				"roll": 0.0
			}
		)
	if what in ["caixa", "crate", "box"]:
		clods(p, 6, 3.5, PX + "objects/debris_crate.png", 0.3)
	elif what in ["pedra", "rock", "parede", "wall"]:
		clods(p, 6, 3.5, PX + "objects/debris_rock.png", 0.3)


## Arremesso forte: rastro de vento e linhas atrás do lutador enquanto voa.
func launch(f: BattleFighter, dir: Vector3, dist: float) -> void:
	if not _ok() or not is_instance_valid(f):
		return
	var d := _gdir(dir)
	ring_air(center(f, 0.5), 0.2, 0.9, Color(1, 1, 1, 0.85), 0.22)
	repeat(
		0.03,
		clampf(dist / 8.0, 0.25, 0.8),
		func(i: int, _a: float) -> bool:
			if not is_instance_valid(f) or not f.is_inside_tree():
				return false
			var c := center(f, 0.5)
			for k in 2:
				var q := (
					c
					+ Vector3(_rng.randf_range(-0.35, 0.35), _rng.randf_range(-0.35, 0.35), 0)
					- d * _rng.randf_range(0.3, 0.8)
				)
				bit(
					"streak",
					toward_cam(q, 0.6),
					_rng.randf_range(0.8, 1.2),
					Color(1, 1, 1, 0.85),
					{
						"face": ProcFx.Face.ROLL,
						"roll": roll_of(d),
						"vel": -d * 2.0,
						"life": 0.16,
						"add": true
					}
				)
			if i % 2 == 0:
				bit(
					"ring",
					toward_cam(c - d * 0.4, 0.5),
					0.7,
					Color(0.9, 0.97, 1.0, 0.6),
					{"life": 0.2, "grow": Vector2(0.5, 1.3), "add": true}
				)
			return true
	)


## Sumiu e reapareceu (Aerial Ace "blink"): flash, anel e linhas onde surge.
func blink(f: BattleFighter) -> void:
	if not _ok() or not is_instance_valid(f) or not f.is_inside_tree():
		return
	var c := center(f, 0.5)
	flash(c, 1.0, Color(0.85, 0.95, 1.0))
	ring_air(c, 0.2, 1.0, Color(1, 1, 1, 0.9), 0.25)
	for n in 6:
		var a := TAU * n / 6.0
		var d := Vector3(cos(a), sin(a) * 0.6, 0)
		bit(
			"streak",
			toward_cam(c + d * 0.9),
			0.8,
			Color(1, 1, 1, 0.9),
			{"face": ProcFx.Face.ROLL, "roll": a + PI, "vel": -d * 3.0, "life": 0.15, "add": true}
		)


## Chama cb(i, idade) a cada `every` s; acaba em `dur` s ou quando cb devolve false.
class Ticker:
	extends RefCounted
	var every := 0.05
	var dur := 1.0
	var age := 0.0
	var acc := 0.0
	var n := 0
	var cb: Callable
	var done_cb: Callable
	var _over := false
	var watch: Array = []

	func _init(e: float, d: float, c: Callable, dn: Callable) -> void:
		every = maxf(e, 0.005)
		dur = d
		cb = c
		done_cb = dn

	func tick(dt: float) -> bool:
		if _over:
			return false
		for o in watch:
			if not is_instance_valid(o):
				_over = true
				return false
		age += dt
		acc += dt
		var go := true
		while acc >= every and go:
			acc -= every
			go = bool(cb.call(n, age))
			n += 1
		if not go or age >= dur:
			_over = true
			if done_cb.is_valid():
				done_cb.call()
			return false
		return true

class_name BattleField
extends RefCounted
## Terreno que muda (crateras, buraco do Dig, poças, gelo, grama queimada, Spikes), objetos que quebram
## e os clones do Double Team. A arena cria um por luta (arena.field) e chama os ganchos abaixo.

const MAX_MARKS := 12
const MARK_Y := 0.02
const OBJ_R := 0.55  ## raio de colisão de caixas/pedras
const BODY_R := 0.4  ## raio do lutador contra os objetos
const OBJ_KEEP := 3.0  ## distância mínima do centro e dos pontos de entrada
const CLONE_HIT := 0.35
## Por tipo de marca: cor, duração (s), multiplicador de andar.
const MARKS := {
	"crater": {"col": Color(0.42, 0.3, 0.2, 0.6), "life": 8.0, "mult": 0.7},
	"hole": {"col": Color(0.12, 0.08, 0.05, 0.75), "life": 8.0, "mult": 0.7},
	"puddle": {"col": Color(0.3, 0.55, 0.95, 0.45), "life": 7.0, "mult": 0.85},
	"ice": {"col": Color(0.7, 0.92, 1.0, 0.5), "life": 7.0, "mult": 1.2},
	"scorch": {"col": Color(0.1, 0.07, 0.05, 0.65), "life": 7.0, "mult": 1.0},
	"dust": {"col": Color(0.85, 0.75, 0.5, 0.35), "life": 5.0, "mult": 0.9},
	"spikes": {"col": Color(0.7, 0.7, 0.75, 0.6), "life": 20.0, "mult": 1.0},
}
## Decalques de pixel art por marca (assets/pixellab/fx): arquivo, lado do PNG em px, cor, fator do raio.
## Sem arte (arquivo ausente) a marca continua sendo o cilindro colorido.
const DECALS := {
	"crater": {"file": "fx/stone_ring.png", "px": 64, "tint": Color(1, 1, 1, 0.9), "k": 1.15},
	"puddle": {"file": "fx/water_swirl.png", "px": 64, "tint": Color(1, 1, 1, 0.75), "k": 1.15},
	"ice": {"file": "fx/ice_patch.png", "px": 84, "tint": Color(1, 1, 1, 0.9), "k": 1.15},
	"scorch":
	{"file": "fx/infernal_circle.png", "px": 64, "tint": Color(0.3, 0.25, 0.25, 0.8), "k": 1.1},
	"dust": {"file": "fx/dust_ring.png", "px": 64, "tint": Color(1, 1, 1, 0.75), "k": 1.2},
}

var arena: Node
var marks: Array = []  ## {node, kind, pos, r, t, side, hit}
var objects: Array = []  ## {node, pos, hp, berry, cd}
var berries: Array = []  ## {node, pos, t}
var shards: Array = []  ## {node, vel, t}
var clones: Array = []  ## {node, owner, ang, t, off}
var _still: Dictionary = {}  ## id do lutador -> {pos, acc}


func _init(a: Node) -> void:
	arena = a


## Monta os objetos da quadra (caixas, pedras) dentro de arena.rect.
func setup() -> void:
	if arena.opts.get("field_objects", true) == false:
		return
	var n: int = arena.rng.randi_range(2, 4)
	var r: Rect2 = arena.rect.grow(-1.2)
	for i in n:
		for _try in 30:
			var p := Vector3(
				arena.rng.randf_range(r.position.x, r.end.x),
				0.0,
				arena.rng.randf_range(r.position.y, r.end.y)
			)
			if _spot_ok(p):
				_add_object(p)
				break


func _spot_ok(p: Vector3) -> bool:
	if p.length() < OBJ_KEEP:
		return false
	for s in [arena.player_spot, arena.enemy_spot]:
		if _flat(p - s).length() < OBJ_KEEP:
			return false
	for o in objects:
		if _flat(p - o.pos).length() < 2.0:
			return false
	return true


func _add_object(p: Vector3) -> void:
	var rock: bool = arena.rng.randf() < 0.5
	var mi: Node3D = PixelFx.prop("objects/rock.png" if rock else "objects/crate.png", 1.0, 32)
	if mi != null:
		mi.position = p
	else:
		mi = _mesh_object(rock, p)
	arena.add_child(mi)
	(
		objects
		. append(
			{
				"node": mi,
				"pos": p,
				"hp": arena.rng.randi_range(1, 2),
				"berry": arena.rng.randf() < 0.35,
				"rock": rock,
				"cd": 0.0,
			}
		)
	)


## Visual antigo (fallback sem arte): esfera cinza ou caixa marrom.
func _mesh_object(rock: bool, p: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	if rock:
		var m := SphereMesh.new()
		m.radius = 0.5
		m.height = 0.8
		mi.mesh = m
		mat.albedo_color = Color(0.5, 0.48, 0.45)
		mi.position = p + Vector3(0, 0.3, 0)
	else:
		var m := BoxMesh.new()
		m.size = Vector3(0.8, 0.8, 0.8)
		mi.mesh = m
		mat.albedo_color = Color(0.62, 0.42, 0.22)
		mi.position = p + Vector3(0, 0.4, 0)
	mi.material_override = mat
	return mi


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func tick(dt: float) -> void:
	_tick_marks(dt)
	_tick_objects(dt)
	_tick_clones(dt)
	_tick_shards(dt)


func _tick_marks(dt: float) -> void:
	for m in marks.duplicate():
		m.t -= dt
		if m.t <= 0.0:
			_drop_mark(m)
			continue
		if m.t < 1.0 and is_instance_valid(m.node):
			if m.node is Sprite3D:
				m.node.modulate.a = float(m.alpha) * m.t
			else:
				var mat: StandardMaterial3D = m.node.material_override
				mat.albedo_color.a = float(MARKS[m.kind].col.a) * m.t
	for f in arena.fighters:
		if not is_instance_valid(f) or not f.active():
			continue
		var id: int = f.get_instance_id()
		var st: Dictionary = _still.get(id, {"pos": f.position, "acc": 0.0})
		var moved := _flat(f.position - st.pos).length()
		st.pos = f.position
		var standing := moved < 0.3 * dt
		for m in marks.duplicate():
			if _flat(f.position - m.pos).length() > m.r:
				continue
			if m.kind == "scorch" and standing:
				st.acc += f.max_hp / 32.0 * f.dot_scale() * dt
				if st.acc >= 1.0:
					var n := mini(int(st.acc), f.hp - 1)
					st.acc -= int(st.acc)
					if n >= 1:
						f.popup("-%d queimado" % n, Dex.type_color("fire"), 0.7)
						f.take_damage(n, Vector3.ZERO, 0.0)
			elif m.kind == "spikes" and f.side != m.side and not m.hit.has(id) and _on_ground(f):
				m.hit[id] = true
				var d := maxi(1, int(f.max_hp / 8.0))
				f.popup("-%d Spikes" % d, Dex.type_color("ground"), 0.8)
				f.take_damage(d, Vector3.ZERO, 0.0)
		_still[id] = st


## Spikes só pegam quem pisa (Voador, Levitate e quem está no ar passam por cima).
func _on_ground(f: BattleFighter) -> bool:
	if f.position.y > 0.3:
		return false
	return not arena.get("moves") or arena.moves.effects.grounded(f)


## Tira os Spikes do lado `side` (-1 = todos): Rapid Spin, Defog.
func clear_spikes(side := -1) -> void:
	for m in marks.duplicate():
		if m.kind == "spikes" and (side < 0 or int(m.side) == side):
			_drop_mark(m)


func _drop_mark(m: Dictionary) -> void:
	marks.erase(m)
	if is_instance_valid(m.node):
		m.node.queue_free()


## Um golpe chegou em `at` (local da arena, y = 0) com raio `radius`: pode deixar marca no chão.
func on_move_landed(user: BattleFighter, mv: Dictionary, at: Vector3, radius: float) -> void:
	_hit_objects(at, radius)
	var kind := _mark_for(mv)
	if kind == "":
		return
	var side := user.side if is_instance_valid(user) else 0
	_add_mark(kind, _flat(at), clampf(radius, 0.8, 2.5), side)


func _mark_for(mv: Dictionary) -> String:
	var type := String(mv.get("type", ""))
	var power := float(mv.get("power", 0))
	if String(mv.get("id", "")) == "dig":
		return "hole"
	if String(mv.get("id", "")) == "spikes":
		return "spikes"
	match type:
		"ground", "rock":
			return "crater" if power >= 50.0 else "dust"
		"water":
			return "puddle" if power > 0.0 else ""
		"ice":
			return "ice" if power > 0.0 else ""
		"fire":
			return "scorch" if power > 0.0 else ""
	return ""


## Spikes do lado `side` em `at` (quem é do outro lado e pisa leva 1/8 do HP).
func add_spikes(side: int, at: Vector3) -> void:
	_add_mark("spikes", _flat(at), 1.4, side)


func _add_mark(kind: String, pos: Vector3, r: float, side: int) -> void:
	var def: Dictionary = MARKS[kind]
	for m in marks:
		if m.kind == kind and _flat(m.pos - pos).length() < 0.6:
			m.t = def.life  # renova em vez de empilhar
			return
	var mi: Node3D = _decal_for(kind, r)
	var alpha: float = float(def.col.a)
	if mi != null:
		alpha = float(DECALS[kind].tint.a)
	else:
		mi = _cylinder_mark(def, r)
	mi.position = Vector3(pos.x, MARK_Y, pos.z)
	arena.add_child(mi)
	marks.append(
		{
			"node": mi,
			"kind": kind,
			"pos": pos,
			"r": r,
			"t": def.life,
			"side": side,
			"hit": {},
			"alpha": alpha
		}
	)
	while marks.size() > MAX_MARKS:
		_drop_mark(marks[0])


## Decalque de pixel art da marca (Sprite3D deitado) ou null se não há arte.
func _decal_for(kind: String, r: float) -> Sprite3D:
	if not DECALS.has(kind):
		return null
	var d: Dictionary = DECALS[kind]
	return PixelFx.decal(String(d.file), r * 2.0 * float(d.k), int(d.px), d.tint)


func _cylinder_mark(def: Dictionary, r: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = r
	cyl.bottom_radius = r
	cyl.height = 0.02
	mi.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = def.col
	mi.material_override = mat
	return mi


## Tipo de terreno em `pos` ("" = chão normal): crater, hole, puddle, ice, scorch, dust, spikes.
func terrain_at(pos: Vector3) -> String:
	for i in range(marks.size() - 1, -1, -1):
		if _flat(pos - marks[i].pos).length() <= marks[i].r:
			return marks[i].kind
	return ""


## Multiplicador da velocidade de andar do lutador pelo chão onde ele está (1.0 = normal).
func move_mult(f: BattleFighter) -> float:
	var k := 1.0
	for m in marks:
		if _flat(f.position - m.pos).length() <= m.r:
			k *= float(MARKS[m.kind].mult)
	return clampf(k, 0.5, 1.2)


# --- objetos que quebram ---


func _hit_objects(at: Vector3, radius: float) -> void:
	for o in objects.duplicate():
		if o.cd > 0.0:
			continue
		if _flat(at - o.pos).length() <= radius + OBJ_R + 0.3:
			o.cd = 0.3
			o.hp -= 1
			if o.hp <= 0:
				_break(o)
			elif is_instance_valid(o.node):
				o.node.scale = Vector3.ONE * 0.85


func _break(o: Dictionary) -> void:
	objects.erase(o)
	var col := Color(0.6, 0.45, 0.3)
	if is_instance_valid(o.node):
		if o.node is MeshInstance3D:
			col = o.node.material_override.albedo_color
		o.node.queue_free()
	for i in 6:
		var mi: Node3D = null
		if i < 4:
			mi = PixelFx.prop(
				"objects/debris_rock.png" if o.rock else "objects/debris_crate.png", 0.3, 32
			)
		if mi != null:
			mi.position = o.pos + Vector3(0, 0.4, 0)
		else:
			mi = _shard_box(col)
			mi.position = o.pos + Vector3(0, 0.4, 0)
		arena.add_child(mi)
		var v := Vector3(
			arena.rng.randf_range(-2, 2), arena.rng.randf_range(2, 4), arena.rng.randf_range(-2, 2)
		)
		shards.append({"node": mi, "vel": v, "t": 0.7})
	if arena.vfx and arena.is_inside_tree():
		arena.vfx.puff(arena.to_global(o.pos + Vector3(0, 0.4, 0)), 1.0)
		PixelFx.pop(arena, "dust", o.pos + Vector3(0, 0.5, 0), 1.3, 0.4)
	if o.berry:
		_add_berry(o.pos)


func _shard_box(col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3.ONE * 0.12
	mi.mesh = b
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mi.material_override = mat
	return mi


func _add_berry(p: Vector3) -> void:
	var mi: Node3D = PixelFx.prop("objects/berry.png", 0.5, 32)
	if mi != null:
		mi.position = p
	else:
		var sph := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.15
		s.height = 0.3
		sph.mesh = s
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.9, 0.2, 0.35)
		sph.material_override = mat
		sph.position = p + Vector3(0, 0.2, 0)
		mi = sph
	arena.add_child(mi)
	berries.append({"node": mi, "pos": p, "t": 15.0})


func _tick_objects(dt: float) -> void:
	for o in objects:
		o.cd = maxf(o.cd - dt, 0.0)
	for f in arena.fighters:
		if is_instance_valid(f) and f.active():
			var p := push_out(f)
			if p != Vector3.ZERO:
				f.position += p
	for b in berries.duplicate():
		b.t -= dt
		var taken := false
		if b.t > 0.0:
			for f in arena.fighters:
				if is_instance_valid(f) and f.active() and _flat(f.position - b.pos).length() < 0.7:
					var n := maxi(1, int(f.max_hp / 10.0))
					f.heal(n)
					f.set_meta("ate_berry", true)  # Belch
					f.popup("+%d Frutinha" % n, Color(0.5, 1.0, 0.5), 0.8)
					taken = true
					break
		if taken or b.t <= 0.0:
			berries.erase(b)
			if is_instance_valid(b.node):
				b.node.queue_free()


## Deslocamento (plano) que tira o lutador de dentro de um objeto; zero se está livre.
func push_out(f: BattleFighter) -> Vector3:
	var out := Vector3.ZERO
	for o in objects:
		var d := _flat(f.position - o.pos)
		var lim := OBJ_R + BODY_R + 0.01
		if d.length() < lim - 0.005:
			if d.length() < 0.001:
				d = Vector3(1, 0, 0)
			out += d.normalized() * (lim - d.length())
	return out


func _tick_shards(dt: float) -> void:
	for s in shards.duplicate():
		s.t -= dt
		s.vel.y -= 9.0 * dt
		if is_instance_valid(s.node):
			s.node.position += s.vel * dt
			s.node.position.y = maxf(s.node.position.y, 0.05)
		if s.t <= 0.0:
			shards.erase(s)
			if is_instance_valid(s.node):
				s.node.queue_free()


# --- clones ---


## Double Team (kind "clones"): cria as cópias em volta do usuário.
func spawn_clones(user: BattleFighter, mv: Dictionary) -> void:
	_drop_clones(user)
	var n := int(mv.get("count", 2))
	var dur := float(mv.get("duration", 5.0))
	for i in n:
		var c := CreatureSprite.new()
		c.manual = true
		c.auto_motion = false
		c.auto_face = false
		c.species = user.mon.species
		arena.add_child(c)
		c.set_alpha(0.5)
		var ang: float = TAU * float(i) / maxf(n, 1) + arena.rng.randf() * 0.5
		clones.append({"node": c, "owner": user, "ang": ang, "t": dur})
		_place_clone(clones[-1])


func _place_clone(c: Dictionary) -> void:
	var u: BattleFighter = c.owner
	c.node.position = u.position + Vector3(cos(c.ang), 0.0, sin(c.ang)) * 1.3
	c.node.position.y = 0.0
	if u.look:
		c.node.facing = u.look.facing


func _tick_clones(dt: float) -> void:
	for c in clones.duplicate():
		c.t -= dt
		if c.t <= 0.0 or not is_instance_valid(c.owner) or not c.owner.active():
			_remove_clone(c, false)
			continue
		c.ang += dt * 1.5
		_place_clone(c)


func _clones_of(f: BattleFighter) -> Array:
	return clones.filter(func(c: Dictionary) -> bool: return c.owner == f)


func _drop_clones(f: BattleFighter) -> void:
	for c in _clones_of(f):
		_remove_clone(c, false)


func _remove_clone(c: Dictionary, fx: bool) -> void:
	clones.erase(c)
	if not is_instance_valid(c.node):
		return
	if fx and arena.vfx and arena.is_inside_tree():
		arena.vfx.puff(c.node.to_global(Vector3(0, 0.45, 0)), 1.2)
	c.node.queue_free()


## Antes do acerto: true se um clone levou o golpe no lugar do alvo (o acerto é cancelado).
func absorb_hit(_user: BattleFighter, target: BattleFighter, _mv: Dictionary) -> bool:
	var cs := _clones_of(target)
	if cs.is_empty() or arena.rng.randf() >= CLONE_HIT:
		return false
	_remove_clone(cs[0], true)
	arena.popup(
		target.position + Vector3(0, target.look_h, 0), "Era um clone!", Color(0.9, 0.9, 1.0)
	)
	return true


## Um golpe errou o alvo pela evasão (clones somem um a um).
func on_evaded(target: BattleFighter) -> void:
	var cs := _clones_of(target)
	if not cs.is_empty():
		_remove_clone(cs[0], true)


## Some com tudo (fim da luta).
func clear() -> void:
	for list in [marks, objects, berries, shards, clones]:
		for e in list:
			if is_instance_valid(e.node):
				e.node.queue_free()
		list.clear()
	_still.clear()

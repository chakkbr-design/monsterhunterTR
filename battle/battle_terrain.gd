class_name BattleTerrain
extends RefCounted
## Relevo da quadra (opts.terrain, o treino liga): morros, picos e lagos como objetos 3D de verdade,
## com texturas de pixel art. A arena cria um por luta (arena.terrain) e chama os ganchos abaixo.
##
## - Morro: tronco de cone baixo com topo de grama; qualquer um sobe pela encosta (mais devagar).
## - Pico: alto e estreito; só sobem os escaladores (Pedra, Terra, Lutador, Voador, Inseto ou Speed alta);
##   para os outros é sólido.
## - Lago: quem não é de Água anda devagar dentro; Água nada rápido e descansa melhor (energia).
##
## No alto (ground_y >= HIGH), golpe à distância ou Voador contra quem está mais baixo acerta mais
## (HIGH_ACC). Golpe de Terra, Pedra ou Lutador que cai num morro ou pico tira vida dele; quando ele
## desaba, quem está em cima cai, toma dano e fica atordoado. Picos, caixas e pedras são cobertura:
## param projéteis e raios. Raio no lago passa a corrente para quem está na mesma água; gelo congela o lago.

const HIGH := 0.6  ## altura do chão a partir da qual o lutador está "no alto"
const HIGH_ACC := 1.2  ## precisão de golpe à distância/Voador de cima para baixo
const HIGH_DIFF := 0.4  ## desnível mínimo para o bônus
const RANGED_KINDS := ["projectile", "homing", "beam", "stream", "aoe_target", "zone", "whip"]
const BREAKERS := ["ground", "rock", "fighting"]
const CLIMB_TYPES := ["rock", "ground", "fighting", "flying", "bug"]
const CLIMB_SPEED := 115.0  ## Speed (stat no Nv da luta) a partir da qual qualquer um escala o pico
const HILL_HP := 4
const PEAK_HP := 3
const STRONG := 80.0  ## poder a partir do qual o golpe tira 2 de vida do relevo
const FALL_FRAC := 0.125  ## dano da queda (fração do HP máximo)
const FALL_STUN := 1.5  ## atordoado depois de cair (s), + FALL_STUN_H por metro
const FALL_STUN_H := 0.4
const UPHILL_MULT := 0.8
const WADE_MULT := 0.6
const SWIM_MULT := 1.3
const ICE_MULT := 1.15
const SWIM_REGEN := 1.3  ## energia de quem é de Água descansando no lago
const RISE := 6.0  ## m/s que o chão sobe sob o lutador (encosta)
const FALL_G := 14.0
const CONDUCT := 0.75  ## poder da corrente que passa pela água (o 0,75x oficial do golpe em área)
const FREEZE_SECS := 10.0
const KEEP_SPOT := 1.8  ## longe dos pontos de entrada
const KEEP_WALL := 1.0
const GAP := 0.9
const HIT_CD := 0.35

var arena: Node
## {kind: "hill"/"peak"/"pond", pos, r, top, h, hp, max_hp, node, cd, ice_t, top_node, mat}
var obstacles: Array = []
var _fall_v := {}  ## id do lutador -> velocidade da queda (m/s)
var _water_t := 0.0

static var _tex := {}


func _init(a: Node) -> void:
	arena = a


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


## Monta o relevo, espelhado pelo centro (os dois lados ficam com o mesmo terreno).
func setup() -> void:
	if not bool(arena.opts.get("terrain", false)):
		return
	var rng: RandomNumberGenerator = arena.rng
	var plan := [
		{"kind": "hill", "r": [1.9, 2.4], "h": [0.9, 1.15]},
		{"kind": "peak", "r": [1.2, 1.45], "h": [1.6, 1.9]},
		{"kind": "pond", "r": [1.5, 2.0], "h": [0.0, 0.0]},
	]
	if arena.rect.size.x >= 20.0:
		plan.append(
			{"kind": "hill" if rng.randf() < 0.5 else "peak", "r": [1.4, 2.0], "h": [1.0, 1.3]}
		)
	for p in plan:
		var r := rng.randf_range(p.r[0], p.r[1])
		var h := rng.randf_range(p.h[0], p.h[1])
		if p.kind == "peak":
			r = minf(r, 1.45)
		for _try in 120:
			var at := _random_spot(rng, r)
			if at == Vector3.INF:
				continue
			_add(String(p.kind), at, r, h)
			_add(String(p.kind), -at, r, h)
			break


func _random_spot(rng: RandomNumberGenerator, r: float) -> Vector3:
	var rc: Rect2 = arena.rect.grow(-(r + KEEP_WALL))
	if rc.size.x <= 0.0 or rc.size.y <= 0.0:
		return Vector3.INF
	var at := Vector3(
		rng.randf_range(rc.position.x, rc.end.x), 0.0, rng.randf_range(rc.position.y, rc.end.y)
	)
	# A metade do jogador: o par espelhado (-at) cai na do adversário.
	if at.dot(arena.axis) > 0.0:
		at = -at
	if at.length() < r + GAP:  # longe do espelho (o par não se encosta no centro)
		return Vector3.INF
	for s in [arena.player_spot, arena.enemy_spot]:
		if _flat(at - s).length() < r + KEEP_SPOT or _flat(-at - s).length() < r + KEEP_SPOT:
			return Vector3.INF
	for o in obstacles:
		if (
			_flat(at - o.pos).length() < r + o.r + GAP
			or _flat(-at - o.pos).length() < r + o.r + GAP
		):
			return Vector3.INF
	return at


func _add(kind: String, at: Vector3, r: float, h: float) -> void:
	var o := {
		"kind": kind,
		"pos": _flat(at),
		"r": r,
		"top": r * 0.55 if kind == "hill" else 0.42,
		"h": h,
		"hp": HILL_HP if kind == "hill" else PEAK_HP,
		"cd": 0.0,
		"ice_t": 0.0,
	}
	o.max_hp = o.hp
	o.h0 = h
	if kind == "pond":
		o.hp = 0
		o.top = r
	_build_node(o)
	obstacles.append(o)


# --- Altura e movimento ---


## Altura do chão (sem o lago) em `p` (local, plano).
func height_at(p: Vector3) -> float:
	var best := 0.0
	for o in obstacles:
		if o.kind == "pond":
			continue
		best = maxf(best, _height_of(o, p))
	return best


func _height_of(o: Dictionary, p: Vector3) -> float:
	var d := _flat(p - o.pos).length()
	if d >= o.r:
		return 0.0
	if d <= o.top:
		return o.h
	return o.h * (1.0 - (d - o.top) / maxf(o.r - o.top, 0.01))


func obstacle_under(f: BattleFighter) -> Dictionary:
	for o in obstacles:
		if o.kind != "pond" and _flat(f.position - o.pos).length() < o.r and f.ground_y > 0.25:
			return o
	return {}


func pond_at(p: Vector3) -> Dictionary:
	for o in obstacles:
		if o.kind == "pond" and _flat(p - o.pos).length() < o.r:
			return o
	return {}


func in_water(f: BattleFighter) -> bool:
	return not pond_at(f.position).is_empty() and _grounded(f) and f.ground_y < 0.1


func _grounded(f: BattleFighter) -> bool:
	if arena.get("moves") and arena.moves.effects.has_method("grounded"):
		return arena.moves.effects.grounded(f)
	return f.height() < 0.3 and not "flying" in f.types


## Sobe no pico: Pedra, Terra, Lutador, Voador, Inseto ou Speed alta.
func climber(f: BattleFighter) -> bool:
	for t in f.types:
		if t in CLIMB_TYPES:
			return true
	return float(f.stats.get("spe", 0)) >= CLIMB_SPEED


func swimmer(f: BattleFighter) -> bool:
	return "water" in f.types


## Para o pico não escalável: o lutador vale como sólido nele.
func blocks(f: BattleFighter, o: Dictionary) -> bool:
	return o.kind == "peak" and not climber(f) and f.height() < o.h


func on_high(f: BattleFighter) -> bool:
	return f.ground_y >= HIGH


## Multiplicador do andar pelo relevo (encosta, água, gelo).
func move_mult(f: BattleFighter) -> float:
	var pond := pond_at(f.position)
	if not pond.is_empty() and _grounded(f):
		if float(pond.ice_t) > 0.0:
			return ICE_MULT
		return SWIM_MULT if swimmer(f) else WADE_MULT
	for o in obstacles:
		if o.kind == "pond":
			continue
		var d := _flat(f.position - o.pos).length()
		if d > o.top and d < o.r:
			var down := _flat(f.position - o.pos).normalized()
			if f.velocity.dot(down) < -0.1:
				return UPHILL_MULT
	return 1.0


## Energia: quem é de Água descansando no lago enche mais rápido.
func regen_mult(f: BattleFighter) -> float:
	return SWIM_REGEN if swimmer(f) and in_water(f) else 1.0


## Deslocamento que tira o lutador de dentro de um pico que ele não escala.
func push_out(f: BattleFighter) -> Vector3:
	var out := Vector3.ZERO
	for o in obstacles:
		if not blocks(f, o):
			continue
		var d := _flat(f.position - o.pos)
		var lim: float = o.r * 0.8 + BattleField.BODY_R
		if d.length() < lim:
			if d.length() < 0.001:
				d = Vector3(1, 0, 0)
			out += d.normalized() * (lim - d.length())
	return out


## Por quadro, depois de cada lutador andar: chão sob ele, queda e o pico sólido.
func settle(f: BattleFighter, dt: float) -> void:
	if obstacles.is_empty() or not f.active():
		return
	f.position += push_out(f)
	if f.motion == "tunnel" or f.hidden != "":
		f.ground_y = 0.0
		return
	var want := height_at(f.position)
	var id := f.get_instance_id()
	if want >= f.ground_y:
		f.ground_y = move_toward(f.ground_y, want, RISE * dt)
		_fall_v.erase(id)
	else:
		var v: float = float(_fall_v.get(id, 0.0)) + FALL_G * dt
		_fall_v[id] = v
		f.ground_y = maxf(f.ground_y - v * dt, want)
	if f.motion == "":
		f.position.y = f.ground_y + f.air_h + f.fly_h


# --- Golpes ---


## Precisão de quem está no alto: golpe à distância ou Voador contra quem está mais baixo.
func acc_mult(user: BattleFighter, mv: Dictionary, target: BattleFighter) -> float:
	if obstacles.is_empty() or not is_instance_valid(target) or not on_high(user):
		return 1.0
	var ranged := (
		String(mv.get("kind", "")) in RANGED_KINDS or String(mv.get("type", "")) == "flying"
	)
	if ranged and user.ground_y - target.ground_y >= HIGH_DIFF:
		return HIGH_ACC
	return 1.0


## Um golpe chegou em `at` (BattleField.on_move_landed): Terra/Pedra/Lutador tiram vida do relevo,
## raio passa pela água, gelo congela o lago.
func on_move_landed(user: BattleFighter, mv: Dictionary, at: Vector3, radius: float) -> void:
	if obstacles.is_empty():
		return
	var type := String(mv.get("type", ""))
	var power := float(mv.get("power", 0))
	if power <= 0.0:
		return
	if type in BREAKERS:
		for o in obstacles.duplicate():
			if o.kind == "pond" or o.cd > 0.0:
				continue
			if _flat(at - o.pos).length() <= o.r + radius * 0.5:
				o.cd = HIT_CD
				damage(o, 2 if power >= STRONG else 1, user)
	var pond := pond_at(at)
	if pond.is_empty():
		return
	if type == "ice":
		freeze(pond)
	elif type == "electric" and not mv.get("conducted", false) and float(pond.ice_t) <= 0.0:
		_conduct(user, mv, pond, at)
	elif type == "fire":
		_steam(pond, at)


## Tira `n` de vida do morro/pico; em 0 ele desaba.
func damage(o: Dictionary, n: int, user: BattleFighter = null) -> void:
	if not obstacles.has(o):
		return
	o.hp -= n
	if o.hp <= 0:
		collapse(o, user)
		return
	# Cada golpe rebaixa um pouco (até 70% da altura no último ponto de vida).
	var k := 0.7 + 0.3 * float(o.hp) / float(o.max_hp)
	o.h = float(o.h0) * k
	if is_instance_valid(o.node):
		o.node.scale = Vector3(1.0, k, 1.0)
	_crumbs(o, 4)
	if arena.vfx and arena.is_inside_tree():
		PixelFx.pop(arena, "dust", o.pos + Vector3(0, o.h * 0.6, 0), 1.6, 0.4)


## O relevo desaba: quem está em cima cai, toma dano e fica atordoado.
func collapse(o: Dictionary, user: BattleFighter = null) -> void:
	obstacles.erase(o)
	_crumbs(o, 10)
	if is_instance_valid(o.node):
		o.node.queue_free()
	if arena.is_inside_tree():
		PixelFx.pop(arena, "dust", o.pos + Vector3(0, 0.6, 0), o.r * 1.6, 0.6)
		PixelFx.pop(arena, "stone", o.pos + Vector3(0, 0.3, 0), o.r * 1.4, 0.5)
	if arena.field:
		arena.field._add_mark("crater", o.pos, clampf(o.r, 0.8, 2.5), 0)
	preload("res://audio/cue.gd").sfx("hit_super")
	var who := "" if user == null else " (%s)" % user.mon.display_name
	arena.say("O %s desabou!%s" % ["morro" if o.kind == "hill" else "pico", who])
	for f in arena.fighters:
		if not is_instance_valid(f) or not f.active():
			continue
		if _flat(f.position - o.pos).length() >= o.r or f.ground_y < 0.25:
			continue
		if not _grounded(f):
			f.popup("Saiu voando!", Color(0.8, 0.9, 1.0), 0.9, 0.6)
			continue
		var n := maxi(1, int(float(f.max_hp) * FALL_FRAC * f.dot_scale()))
		f.stun_t = maxf(f.stun_t, FALL_STUN + FALL_STUN_H * f.ground_y)
		f.interrupt_prepare()
		f.popup("-%d Caiu!" % n, Color(1.0, 0.75, 0.45), 1.1, 0.7)
		f.take_damage(n, Vector3.ZERO, 0.0)
		if arena.has_method("cut_in"):
			arena.cut_in("DESABOU!", Color(0.85, 0.65, 0.4))


func _conduct(user: BattleFighter, mv: Dictionary, pond: Dictionary, at: Vector3) -> void:
	var m := mv.duplicate()
	m.erase("_cast")
	m["conducted"] = true
	var hit_any := false
	for f in arena.fighters:
		if not is_instance_valid(f) or not f.active() or f == user or not in_water(f):
			continue
		if _flat(f.position - pond.pos).length() >= pond.r:
			continue
		if _flat(f.position - at).length() < 0.6:
			continue  # o próprio alvo do golpe
		hit_any = true
		f.popup("Choque na água!", Dex.type_color("electric"), 0.9, 0.8)
		arena.moves.hit(user, f, m, _flat(f.position - at).normalized(), CONDUCT)
	if hit_any and arena.is_inside_tree():
		PixelFx.pop(arena, "electric", pond.pos + Vector3(0, 0.2, 0), pond.r * 1.6, 0.5)


func freeze(pond: Dictionary) -> void:
	var was := float(pond.ice_t) > 0.0
	pond.ice_t = FREEZE_SECS
	if not was:
		_set_water_look(pond)
		arena.say("O lago congelou!")


func _steam(pond: Dictionary, at: Vector3) -> void:
	if float(pond.ice_t) > 0.0:
		pond.ice_t = 0.0  # fogo derrete o gelo
		_set_water_look(pond)
		arena.say("O gelo do lago derreteu!")
	if arena.is_inside_tree():
		PixelFx.pop(arena, "wind", _flat(at) + Vector3(0, 0.5, 0), 1.8, 0.6)


## Um projétil parou no relevo ou num objeto em `p`: o objeto/relevo leva o golpe.
func on_shot_blocked(user: BattleFighter, mv: Dictionary, p: Vector3) -> void:
	if arena.field:
		arena.field.on_move_landed(user, mv, _flat(p), 0.3)
	if arena.is_inside_tree():
		PixelFx.pop(arena, "dust", p, 0.9, 0.3)


## Projétil em `p` (local) bateu no relevo? Caixas e pedras do campo também param o tiro.
func blocks_shot(p: Vector3) -> bool:
	if p.y < height_at(p) - 0.05:
		return true
	if arena.field:
		for o in arena.field.objects:
			if _flat(p - o.pos).length() < BattleField.OBJ_R and p.y < 0.9:
				return true
	return false


## Linha de tiro de `a` até `b` (locais) tapada por pico, morro ou caixa/pedra (raios param nela).
## Devolve a distância até o bloqueio ou INF.
func shot_block(a: Vector3, b: Vector3) -> float:
	var from := a + Vector3(0, 0.5, 0)
	var to := b + Vector3(0, 0.5, 0)
	var dist := _flat(to - from).length()
	var n := maxi(2, int(dist / 0.3))
	for i in range(1, n):
		var p := from.lerp(to, float(i) / n)
		if blocks_shot(p):
			return _flat(p - from).length()
	return INF


func has_cover() -> bool:
	if not obstacles.is_empty():
		return true
	return arena.field != null and not arena.field.objects.is_empty()


func tick(dt: float) -> void:
	_water_t += dt
	for o in obstacles:
		o.cd = maxf(float(o.cd) - dt, 0.0)
		if o.kind == "pond":
			if float(o.ice_t) > 0.0:
				o.ice_t = float(o.ice_t) - dt
				if o.ice_t <= 0.0:
					o.ice_t = 0.0
					_set_water_look(o)
			elif o.get("mat") is StandardMaterial3D:
				o.mat.uv1_offset = Vector3(_water_t * 0.04, _water_t * 0.025, 0.0)
	for f in arena.fighters:
		if is_instance_valid(f) and not f.active():
			_fall_v.erase(f.get_instance_id())


# --- IA ---


## Ponto no alto para atirar: o topo de morro/pico mais perto (que o lutador alcança) de onde o alvo
## fica ao alcance `reach`. INF se não há (ou já está lá).
func high_spot(f: BattleFighter, target: BattleFighter, reach: float) -> Vector3:
	if not is_instance_valid(target):
		return Vector3.INF
	var best := Vector3.INF
	var best_d := 7.0
	for o in obstacles:
		if o.kind == "pond" or blocks(f, o) or o.hp <= 1:
			continue
		if _flat(target.position - o.pos).length() > reach * 0.9:
			continue
		if _flat(target.position - o.pos).length() < o.r + 0.8:
			continue  # o alvo está em cima / colado nele
		var d := _flat(f.position - o.pos).length()
		if d < best_d:
			best_d = d
			best = o.pos
	return best


## Esconderijo: ponto atrás de um pico/caixa/pedra (do lado oposto a `from`), perto do lutador.
func cover_spot(f: BattleFighter, from: Vector3, max_d := 7.0) -> Vector3:
	var cands: Array = []
	for o in obstacles:
		if o.kind == "peak" or (o.kind == "hill" and blocks(f, o)):
			cands.append({"pos": o.pos, "r": o.r * 0.8})
	if arena.field:
		for o in arena.field.objects:
			cands.append({"pos": o.pos, "r": BattleField.OBJ_R})
	var best := Vector3.INF
	var best_d := max_d
	for c in cands:
		var away := _flat(c.pos - from)
		if away.length() < 0.5:
			continue
		var spot: Vector3 = c.pos + away.normalized() * (float(c.r) + 0.9)
		if not arena.rect.grow(-0.8).has_point(Vector2(spot.x, spot.z)):
			continue
		var d := _flat(spot - f.position).length()
		if d < best_d:
			best_d = d
			best = spot
	return best


## Desvia a direção desejada da IA de picos que ela não escala e (quem não é de Água) do lago.
func steer(f: BattleFighter, want: Vector3) -> Vector3:
	if obstacles.is_empty() or want.length() < 0.05:
		return want
	var dir := want.normalized()
	var out := want
	for o in obstacles:
		var avoid := blocks(f, o)
		if o.kind == "pond":
			avoid = (
				not swimmer(f)
				and float(o.ice_t) <= 0.0
				and _grounded(f)
				and pond_at(f.position).is_empty()
			)
		if not avoid:
			continue
		var to := _flat(o.pos - f.position)
		var ahead := to.dot(dir)
		if ahead <= 0.0 or ahead > o.r + 1.6:
			continue
		var side := to - dir * ahead
		var clear: float = o.r * (0.8 if o.kind == "peak" else 1.0) + 0.5
		if side.length() >= clear:
			continue
		var tangent := Vector3(-dir.z, 0.0, dir.x)
		if side.dot(tangent) > 0.0:
			tangent = -tangent
		out += tangent * (1.0 - side.length() / clear) * 1.4 * want.length()
	return out.normalized() * want.length() if out.length() > 0.001 else want


## O alvo está em cima de morro/pico (golpe de Terra/Pedra/Lutador derruba).
func topple_target(target: BattleFighter) -> bool:
	return is_instance_valid(target) and not obstacle_under(target).is_empty() and _grounded(target)


# --- Visual ---


func _build_node(o: Dictionary) -> void:
	var root := Node3D.new()
	root.name = "Terrain_%s" % o.kind
	root.position = o.pos
	match String(o.kind):
		"hill":
			root.add_child(_frustum(o.r, o.top, o.h, tex("earth"), 10, 1.0))
			var cap := _disc(o.top + 0.02, tex("grass"), 1.2)
			cap.position.y = o.h + 0.01
			root.add_child(cap)
			for i in 5:
				var a := TAU * i / 5.0 + 0.4
				var tuft := _box(Vector3(0.18, 0.12, 0.18), tex("grass"))
				tuft.position = Vector3(cos(a), 0, sin(a)) * o.top * 0.7 + Vector3(0, o.h + 0.06, 0)
				root.add_child(tuft)
		"peak":
			root.add_child(_frustum(o.r, o.top, o.h, tex("stone"), 7, 0.9))
			var cap := _frustum(o.top + 0.05, o.top * 0.6, 0.18, tex("stone_light"), 7, 1.5)
			cap.position.y = o.h - 0.02
			root.add_child(cap)
			for i in 3:
				var a := TAU * i / 3.0 + 1.1
				var b := _rock_mesh(0.35, tex("stone"))
				b.position = Vector3(cos(a), 0, sin(a)) * o.r * 0.9 + Vector3(0, 0.15, 0)
				root.add_child(b)
		"pond":
			var sand := _disc(o.r + 0.3, tex("sand"), 1.2)
			sand.position.y = 0.012
			root.add_child(sand)
			var water := _disc(o.r, tex("water"), 0.9)
			water.position.y = 0.03
			var mat: StandardMaterial3D = water.material_override
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color = Color(1, 1, 1, 0.9)
			o.mat = mat
			o.water = water
			root.add_child(water)
	o.node = root
	arena.add_child(root)


func _set_water_look(pond: Dictionary) -> void:
	if not (pond.get("mat") is StandardMaterial3D):
		return
	pond.mat.albedo_texture = tex("ice" if float(pond.ice_t) > 0.0 else "water")


static func _mat(t: Texture2D, scale: float, triplanar := true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = t
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.roughness = 1.0
	if triplanar:
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE * scale
	return m


func _frustum(
	r: float, top: float, h: float, t: Texture2D, segs: int, scale: float
) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.bottom_radius = r
	cm.top_radius = top
	cm.height = h
	cm.radial_segments = segs
	cm.rings = 1
	mi.mesh = cm
	mi.position.y = h * 0.5
	mi.material_override = _mat(t, scale)
	return mi


func _disc(r: float, t: Texture2D, scale: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.bottom_radius = r
	cm.top_radius = r
	cm.height = 0.02
	cm.radial_segments = 20
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = _mat(t, scale)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _box(sz: Vector3, t: Texture2D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = sz
	mi.mesh = b
	mi.material_override = _mat(t, 1.0)
	return mi


## Pedra low-poly (esfera achatada de poucos lados).
static func _rock_mesh(r: float, t: Texture2D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 1.4
	s.radial_segments = 7
	s.rings = 3
	mi.mesh = s
	mi.material_override = _mat(t, 1.6)
	return mi


func _crumbs(o: Dictionary, n: int) -> void:
	if not arena.field or not arena.is_inside_tree():
		return
	var t := tex("stone" if o.kind == "peak" else "earth")
	for i in n:
		var mi := _box(Vector3.ONE * arena.rng.randf_range(0.12, 0.22), t)
		mi.position = o.pos + Vector3(0, o.h * 0.7, 0)
		arena.add_child(mi)
		var v := Vector3(
			arena.rng.randf_range(-2.5, 2.5),
			arena.rng.randf_range(2, 4.5),
			arena.rng.randf_range(-2.5, 2.5)
		)
		arena.field.shards.append({"node": mi, "vel": v, "t": 0.8})


# --- Texturas de pixel art (32 x 32, geradas uma vez; caixa e pedra com a paleta da arte delas) ---


static func tex(kind: String) -> Texture2D:
	if _tex.has(kind):
		return _tex[kind]
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind)
	var pal: Array = _palette(kind)
	for y in 32:
		for x in 32:
			img.set_pixel(x, y, pal[_shade(kind, x, y, rng)])
	var t := ImageTexture.create_from_image(img)
	_tex[kind] = t
	return t


## Paleta (escura -> clara). Caixa e pedra saem das artes objects/crate.png e rock.png quando existem.
static func _palette(kind: String) -> Array:
	match kind:
		"grass":
			return [Color("2f6b2a"), Color("3f8a34"), Color("58a843"), Color("7cc25a")]
		"earth":
			return [Color("4f3220"), Color("6b452b"), Color("87603b"), Color("a27a4e")]
		"water":
			return [Color("1f4f9a"), Color("2d6bc2"), Color("4a8fe0"), Color("a8d4ff")]
		"ice":
			return [Color("8cc4e8"), Color("b4dcf4"), Color("d6eefa"), Color("ffffff")]
		"sand":
			return [Color("b49563"), Color("c8aa74"), Color("dcc28c"), Color("eedaa6")]
		"crate":
			return _art_palette(
				"objects/crate.png",
				[Color("5a3a1e"), Color("7a5230"), Color("9a6c40"), Color("c09060")]
			)
		"stone":
			return _art_palette(
				"objects/rock.png",
				[Color("4a4a50"), Color("66666e"), Color("85858c"), Color("a6a6ac")]
			)
		"stone_light":
			var p := _palette("stone")
			return [p[1], p[2], p[3], p[3].lightened(0.2)]
	return [Color.BLACK, Color.DIM_GRAY, Color.GRAY, Color.WHITE]


static func _art_palette(file: String, fallback: Array) -> Array:
	var path := PixelFx.DIR + file
	if not ResourceLoader.exists(path):
		return fallback
	var t = load(path)
	if not (t is Texture2D):
		return fallback
	var img: Image = (t as Texture2D).get_image()
	if img == null:
		return fallback
	if img.is_compressed():
		img.decompress()
	var cols: Array = []
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.9:
				cols.append(c)
	if cols.size() < 8:
		return fallback
	cols.sort_custom(func(a: Color, b: Color) -> bool: return a.get_luminance() < b.get_luminance())
	# Quatro tons pelos quantis (sem os extremos: contorno preto e brilho).
	var out: Array = []
	for q in [0.15, 0.4, 0.65, 0.88]:
		out.append(cols[int(q * (cols.size() - 1))])
	return out


static func _shade(kind: String, x: int, y: int, rng: RandomNumberGenerator) -> int:
	var n := rng.randf()
	match kind:
		"grass":
			if n < 0.08:
				return 3
			if (x * 7 + y * 3) % 11 == 0:
				return 0
			return 1 if n < 0.55 else 2
		"earth":
			var band := (y / 5) % 3
			if n < 0.06:
				return 3
			if y % 5 == 0 and n < 0.6:
				return 0
			return clampi(band, 1, 2) if n < 0.85 else 0
		"stone", "stone_light":
			if (x + y * 2) % 13 == 0 and n < 0.7:
				return 0
			if n < 0.1:
				return 3
			return 1 if n < 0.5 else 2
		"crate":
			if x < 2 or x > 29 or y < 2 or y > 29:
				return 0
			if abs(x - y) < 2 or abs(x + y - 31) < 2:
				return 1
			if y % 8 == 0:
				return 0
			if (x == 4 or x == 27) and y % 8 == 4:
				return 3
			return 2 if n < 0.8 else 1
		"water", "ice":
			if int(x + sin(y * 0.6) * 3.0) % 9 == 0 and n < 0.8:
				return 3
			return 1 if n < 0.5 else (2 if n < 0.85 else 0)
		"sand":
			return 2 if n < 0.6 else (1 if n < 0.9 else 3)
	return 1


## Caixa e pedra do campo (BattleField) como objetos 3D com textura.
static func crate_node() -> Node3D:
	var mi := _box(Vector3(0.85, 0.85, 0.85), tex("crate"))
	mi.material_override.uv1_triplanar = false
	var root := Node3D.new()
	mi.position.y = 0.425
	root.add_child(mi)
	return root


static func rock_node() -> Node3D:
	var root := Node3D.new()
	var a := _rock_mesh(0.55, tex("stone"))
	a.position.y = 0.3
	a.rotation.y = 0.4
	root.add_child(a)
	var b := _rock_mesh(0.28, tex("stone_light"))
	b.position = Vector3(0.35, 0.18, 0.25)
	root.add_child(b)
	return root

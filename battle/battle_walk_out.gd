class_name BattleWalkOut
extends Node
## Luta no mundo (campanha, quadra solta em volta do jogador): assim que a batalha começa o
## jogador e o treinador do mundo saem andando da quadra e ficam OUT..OUT + RING m fora da linha de
## fundo do seu lado (Caio, 2026-10-27: o treinador ficava no meio da luta). O ponto é o mais perto do ideal
## (fundo do lado, TRAINER_SIDE m para a esquerda) com chão no mesmo nível, sem parede, água, porta
## nem gente, e caminho livre até ele (tile a tile na grade). Sem ponto bom o corpo fica onde está.
## Quadra fixa (laboratório, ginásio) e treino não usam: lá a arena já põe cada um no lugar.

const OUT := 0.8  ## mesma folga do treino (BattleArena.TRAINER_OUT)
const RING := 3.0  ## até onde, além de OUT, se procura um ponto bom
const SPEED := 4.0
const MAX_RISE := 0.6
const BODY_R := 0.35
const WATER_LAYER := 16  ## MapBuilder.WATER_LAYER
const NPC_LAYER := 8  ## WorldNpc.LAYER

var arena
var _tweens: Array[Tween] = []


## Põe os corpos do mundo como treinadores da luta (o adversário em vez do boneco) e os manda andar.
static func run(a, o: Dictionary) -> void:
	if a.fixed or a.training or not a.is_inside_tree():
		return
	var p := a.get_tree().get_first_node_in_group(OverworldPlayer.GROUP) as Node3D
	if p == null:
		return
	var bodies := {0: p}
	if a.kind == "trainer":
		var t: Node3D = a._trainer_body(o)
		if t and t.global_position.distance_to(p.global_position) < a.rect.size.length():
			bodies[1] = t
	var w := BattleWalkOut.new()
	w.name = "WalkOut"
	w.arena = a
	a.add_child(w)
	var taken: Array = []
	for side in bodies:
		a._stands[side] = bodies[side]
		var to = w.spot(side, bodies[side], bodies.values(), taken)
		if to is Vector3:
			taken.append(to)
			w.walk(bodies[side], to)


func _exit_tree() -> void:
	# A luta acabou antes de chegar: o mundo (volta para casa do treinador) assume o corpo.
	for tw in _tweens:
		if tw.is_valid():
			tw.kill()
	_tweens.clear()


## Melhor ponto (global) fora da quadra do lado `side` para `n`, ou null.
func spot(side: int, n: Node3D, walkers: Array, taken: Array) -> Variant:
	var dir: Vector3 = -arena.axis if side == 0 else arena.axis
	var lat: Vector3 = arena._lateral()
	var r: Rect2 = arena.rect
	var depth := absf(dir.x) * r.size.x * 0.5 + absf(dir.z) * r.size.y * 0.5
	var c: Vector3 = arena.to_global(Vector3(r.get_center().x, 0, r.get_center().y))
	var ideal: Vector3 = c + dir * (depth + OUT) - lat * BattleArena.TRAINER_SIDE
	var inner := r.grow(OUT - 0.01)
	var outer := r.grow(OUT + RING)
	var cands: Array = []
	# Pontos inteiros (centro dos tiles na grade) no anel em volta da quadra.
	var g0: Vector3 = arena.to_global(Vector3(outer.position.x, 0, outer.position.y))
	var g1: Vector3 = arena.to_global(Vector3(outer.end.x, 0, outer.end.y))
	for x in range(ceili(g0.x), floori(g1.x) + 1):
		for z in range(ceili(g0.z), floori(g1.z) + 1):
			var l: Vector3 = arena.to_local(Vector3(x, 0, z))
			if inner.has_point(Vector2(l.x, l.z)):
				continue
			cands.append(Vector3(x, n.global_position.y, z))
	cands.sort_custom(
		func(a: Vector3, b: Vector3) -> bool:
			return _cost(a, ideal, dir, c) < _cost(b, ideal, dir, c)
	)
	for q in cands:
		if taken.any(func(t: Vector3) -> bool: return Vector2(t.x - q.x, t.z - q.z).length() < 1.5):
			continue
		var ok = _ok(n, q, walkers)
		if ok is Vector3:
			return ok
	return null


## Distância ao ideal, com castigo para quem cai do lado do adversário (atravessaria a luta).
static func _cost(q: Vector3, ideal: Vector3, dir: Vector3, c: Vector3) -> float:
	var d := Vector2(q.x - ideal.x, q.z - ideal.z).length()
	if (q - c).dot(dir) < 0.0:
		d += 20.0
	return d


## O ponto serve (devolve com a altura certa) ou null.
func _ok(n: Node3D, q: Vector3, walkers: Array) -> Variant:
	var g := GridMotion.grid_for(n)
	if g:
		var cell := TileGrid.cell_of(q)
		if not GridMotion.spot_free(g, cell, n) or g.has_flag(cell, TileGrid.WATER):
			return null
		var h := g.height(cell)
		if absf(h - n.global_position.y) > MAX_RISE:
			return null
		for step in GridMotion.axis_path(TileGrid.cell_of(n.global_position), cell):
			if (
				not g.has(step)
				or g.blocked(step)
				or g.has_flag(step, TileGrid.WATER | TileGrid.DOOR)
			):
				return null
		return Vector3(cell.x, h, cell.y)
	var space := n.get_world_3d().direct_space_state
	var ex: Array[RID] = []
	for w in walkers:
		if w is CollisionObject3D:
			ex.append((w as CollisionObject3D).get_rid())
	var down := PhysicsRayQueryParameters3D.create(
		q + Vector3.UP * 1.5, q + Vector3.DOWN * 2.0, Overworld.WALL_LAYER | WATER_LAYER
	)
	down.exclude = ex
	var hit := space.intersect_ray(down)
	if hit.is_empty():
		return null
	var col = hit.get("collider")
	if col is CollisionObject3D and (col as CollisionObject3D).collision_layer & WATER_LAYER:
		return null
	var at: Vector3 = hit.position
	if absf(at.y - n.global_position.y) > MAX_RISE:
		return null
	var s := SphereShape3D.new()
	s.radius = BODY_R
	var probe := PhysicsShapeQueryParameters3D.new()
	probe.shape = s
	probe.collision_mask = Overworld.WALL_LAYER | NPC_LAYER
	probe.exclude = ex
	probe.transform = Transform3D(Basis(), at + Vector3(0, 0.8, 0))
	if not space.intersect_shape(probe, 1).is_empty():
		return null
	var line := PhysicsRayQueryParameters3D.create(
		n.global_position + Vector3.UP * 0.8, at + Vector3.UP * 0.8, Overworld.WALL_LAYER
	)
	line.exclude = ex
	if not space.intersect_ray(line).is_empty():
		return null
	return at


## Anda até `to` (tile a tile na grade, reto fora dela) e vira para a quadra ao chegar.
func walk(n: Node3D, to: Vector3) -> void:
	var pts: Array[Vector3] = [n.global_position]
	var g := GridMotion.grid_for(n)
	if g:
		var y := n.global_position.y
		var a := TileGrid.cell_of(n.global_position)
		var own := GridMotion.center(g, a, y)
		if Vector2(own.x - pts[0].x, own.z - pts[0].z).length() > 0.02:
			pts.append(own)
		for c in GridMotion.axis_path(a, TileGrid.cell_of(to)):
			pts.append(GridMotion.center(g, c, y))
	else:
		pts.append(to)
	var total := 0.0
	for i in range(1, pts.size()):
		total += pts[i - 1].distance_to(pts[i])
	if total < 0.05:
		return
	var tw := n.create_tween()
	tw.tween_method(func(s: float) -> void: _along(n, pts, s), 0.0, total, total / SPEED)
	tw.tween_callback(_face_court.bind(n))
	_tweens.append(tw)


func _along(n: Node3D, pts: Array[Vector3], s: float) -> void:
	if not is_instance_valid(n):
		return
	var acc := 0.0
	for i in range(1, pts.size()):
		var seg := pts[i - 1].distance_to(pts[i])
		if s <= acc + seg or i == pts.size() - 1:
			var p := pts[i - 1].lerp(pts[i], clampf((s - acc) / maxf(seg, 0.0001), 0.0, 1.0))
			_face(n, p + (pts[i] - pts[i - 1]))
			n.global_position = p
			if n is CharacterBody3D:
				(n as CharacterBody3D).velocity = Vector3.ZERO
			return
		acc += seg


func _face_court(n: Node3D) -> void:
	if is_instance_valid(n) and is_instance_valid(arena):
		var r: Rect2 = arena.rect
		_face(n, arena.to_global(Vector3(r.get_center().x, 0, r.get_center().y)))


static func _face(n: Node3D, at: Vector3) -> void:
	at.y = n.global_position.y
	if at.distance_to(n.global_position) < 0.01:
		return
	if n.has_method("face_toward"):
		n.face_toward(at)
	elif n.has_method("face"):
		n.face(at)

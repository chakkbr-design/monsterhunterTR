class_name StoryNpc
extends WorldNpc
## Personagem da história (Oak, rival, Mamãe, balconista) criado pelo Story.
## As falas vêm do Story conforme as flags; anda com walk_to (atravessa obstáculos; tile a tile nas
## zonas de grade).

const WALK_SPEED := 3.5

@export var role := ""  ## "oak" | "rival" | "mom" | "clerk"


func _enter_tree() -> void:
	super._enter_tree()
	add_to_group("story_npc")


func interact(p: OverworldPlayer) -> void:
	face(p.global_position)
	var s := get_node_or_null("/root/Story")
	if s:
		await s.talk(self)
	else:
		await say(lines)


func walk_to(pos: Vector3, speed := WALK_SPEED) -> void:
	await StoryNpc.move_node(self, pos, speed)


## Move qualquer Node3D até `pos` (mesmo y se pos.y for NAN). Nas zonas de grade (docs/VOXEL.md §6)
## anda tile a tile, em eixos (o jogador por grid_walk; last_axis: 0 = termina em x, 1 = em z), com os
## passos animados; fora delas, em linha reta.
static func move_node(n: Node3D, pos: Vector3, speed: float, last_axis := -1) -> void:
	if is_nan(pos.y):
		pos.y = n.global_position.y
	if GridMotion.grid_for(n):
		if n is OverworldPlayer:
			await (n as OverworldPlayer).grid_walk(pos, speed, last_axis)
		else:
			await GridMotion.walk_node(n, pos, speed, last_axis)
		return
	await tween_node(n, pos, speed)


## Linha reta até `pos` (atravessa obstáculos), virado para lá.
static func tween_node(n: Node3D, pos: Vector3, speed: float) -> void:
	var d := n.global_position.distance_to(pos)
	if d < 0.05 or not n.is_inside_tree():
		return
	if n.has_method("face"):
		n.face(pos)
	elif n.has_method("face_toward"):
		n.face_toward(pos)
	var tw := n.create_tween()
	tw.tween_property(n, "global_position", pos, d / maxf(speed, 0.1))
	await tw.finished

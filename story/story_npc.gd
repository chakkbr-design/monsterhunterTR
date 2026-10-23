class_name StoryNpc
extends WorldNpc
## Personagem da história (Oak, rival, Mamãe, balconista) criado pelo Story.
## As falas vêm do Story conforme as flags; anda com walk_to (tween, atravessa obstáculos).

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


## Move qualquer Node3D até `pos` (mesmo y se pos.y for NAN) em linha reta.
static func move_node(n: Node3D, pos: Vector3, speed: float) -> void:
	if is_nan(pos.y):
		pos.y = n.global_position.y
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

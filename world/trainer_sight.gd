class_name TrainerSight
extends RefCounted
## Trainer line of sight: a corridor `length` m ahead of the trainer (its -Z), ±HALF_WIDTH m sideways.

const HALF_WIDTH := 0.9


static func in_corridor(xf: Transform3D, target: Vector3, length: float) -> bool:
	var f := -xf.basis.z
	f.y = 0.0
	f = f.normalized()
	var to := target - xf.origin
	to.y = 0.0
	var along := to.dot(f)
	if along <= 0.0 or along > length:
		return false
	return absf(to.dot(Vector3(-f.z, 0.0, f.x))) <= HALF_WIDTH

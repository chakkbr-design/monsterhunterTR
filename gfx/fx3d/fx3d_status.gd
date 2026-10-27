class_name Fx3DStatus
extends Node3D
## Alça do efeito de status em laço (queimado, envenenado...) no modo de energia: os emissores 3D
## olham `ended()` e param sozinhos. O lutador encerra com `life = age` (igual ao FxSprite).

var life := INF
var age := 0.0
var fighter: Node3D


func ended() -> bool:
	return (
		age >= life
		or not is_inside_tree()
		or not is_instance_valid(fighter)
		or not fighter.is_inside_tree()
	)


func tick(dt: float) -> bool:
	age += dt
	return not ended()

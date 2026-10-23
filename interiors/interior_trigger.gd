class_name InteriorTrigger
extends Area3D
## Walk-on trigger (exit mat, stairs): when the player steps in, RouteWorld travels to `target`
## ({zone, spawn} or {interior, spawn}). RouteWorld ignores it during a transition and right after arriving.

var target: Dictionary = {}
var extent := Vector3(1.4, 1.0, 1.0)


func _ready() -> void:
	collision_layer = 0
	collision_mask = OverworldPlayer.LAYER
	monitorable = false
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = extent
	col.shape = bs
	add_child(col)
	body_entered.connect(_on_body)


func _on_body(b: Node) -> void:
	if not b is OverworldPlayer or not (b as OverworldPlayer).can_act():
		return
	var w := Overworld.of(self)
	if w and w.has_method("travel"):
		w.travel(target, self)

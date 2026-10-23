class_name StoryTrigger
extends Area3D
## Caixa invisível que chama Story.trigger(event) quando o jogador entra,
## se todas as flags de `requires` estão ligadas e nenhuma de `blocks`.

@export var event := ""
@export var requires: PackedStringArray = []
@export var blocks: PackedStringArray = []
@export var size := Vector3(4, 3, 1)


## Monta um gatilho a partir de uma entrada `triggers` de data/maps/*.json
## ({event, pos:[x,z], size:[w,h,d], requires, blocks, y}).
static func from_entry(e: Dictionary) -> StoryTrigger:
	var t := StoryTrigger.new()
	t.event = String(e.get("event", ""))
	t.name = String(e.get("node", "Trigger_" + t.event))
	var s: Array = e.get("size", [4, 3, 1])
	t.size = Vector3(float(s[0]), float(s[1]), float(s[2]))
	t.requires = PackedStringArray(e.get("requires", []))
	t.blocks = PackedStringArray(e.get("blocks", []))
	var p: Array = e.get("pos", [0, 0])
	t.position = Vector3(float(p[0]), float(e.get("y", 0.0)), float(p[1]))
	return t


func _ready() -> void:
	collision_layer = 0
	collision_mask = OverworldPlayer.LAYER
	monitorable = false
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position.y = size.y * 0.5
	add_child(cs)
	body_entered.connect(_on_body_entered)


func ready_to_fire() -> bool:
	var g := get_node_or_null("/root/Game")
	return g != null and StoryFlags.can_fire(g.flags, Array(requires), Array(blocks))


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group(OverworldPlayer.GROUP) or not ready_to_fire():
		return
	var s := get_node_or_null("/root/Story")
	if s:
		s.trigger(event, self)

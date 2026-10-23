class_name PcTerminal
extends WorldNpc
## PC on a desk. Opens nothing yet (the Pokémon storage box is a later round).


func _ready() -> void:
	super._ready()
	if lines.size() == 1 and lines[0] == "Olá!":
		lines = PackedStringArray(["{PLAYER} ligou o PC.", "O sistema de armazenamento ainda está em manutenção."])


func _build_body() -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.8, 0.6, 0.5)
	bm.material = MapBuilder.mat(Color(0.82, 0.84, 0.88))
	mi.mesh = bm
	mi.position.y = 1.15
	add_child(mi)
	var screen := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.6, 0.4, 0.02)
	sm.material = MapBuilder.mat(Color(0.3, 0.7, 0.95))
	screen.mesh = sm
	screen.position = Vector3(0, 1.15, -0.26)
	add_child(screen)


func prompt() -> String:
	return "E: Usar"


func interact(_p: OverworldPlayer) -> void:
	if await InteriorHooks.run(self):
		return
	await say(lines)

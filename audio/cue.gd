extends RefCounted
## Chamadas de som de uma linha para outras partes, seguras sem o autoload Audio (testes headless):
##   preload("res://audio/cue.gd").sfx("hit")
##   preload("res://audio/cue.gd").ui(a)   # a = "up" "down" "left" "right" "ok" "back"

const UI := {"ok": "ui_confirm", "back": "ui_back", "up": "ui_move", "down": "ui_move", "left": "ui_move", "right": "ui_move"}


static func audio() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("Audio") if tree and tree.root else null


static func sfx(sfx_name: String, volume_db := 0.0) -> void:
	var a := audio()
	if a:
		a.sfx(sfx_name, volume_db)


static func music(track: String, fade := 0.5) -> void:
	var a := audio()
	if a:
		a.music(track, fade)


## Som de navegação para uma ação de menu.
static func ui(action: String) -> void:
	if UI.has(action):
		sfx(UI[action])

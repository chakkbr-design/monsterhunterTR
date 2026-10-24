extends SceneTree
## Fotos da quadra do treino com relevo (sem --headless):
##   godot --path . --resolution 1600x900 --script res://tests/battle/shot_terrain.gd [-- seed=7 size=2]
## Grava docs/screens/terrain_<n>.png em vários momentos de uma luta do modo de energia.

const Cfg := preload("res://ui/training/training_config.gd")
const MOMENTS := [2.5, 8.0, 15.0, 24.0, 35.0]
const OUT := "res://docs/screens/"

var seed := 7
var size := 2


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := String(a).split("=")
		if kv.size() == 2 and kv[0] == "seed":
			seed = int(kv[1])
		elif kv.size() == 2 and kv[0] == "size":
			size = int(kv[1])
	_run.call_deferred()


func _run() -> void:
	Cfg.path = "user://shot_terrain_cfg.json"
	var c := Cfg.default_config()
	var teams := [["geodude", "pidgeotto", "squirtle"], ["mankey", "pikachu", "sandshrew"]]
	for s in 2:
		c.sides[s].mons = []
		for n in teams[s]:
			c.sides[s].mons.append(Cfg.mon_entry(String(n), 50))
	c.battle_size = size
	c.seed = seed
	Cfg.current = c
	var tb: Node = load("res://ui/training/training_battle.tscn").instantiate()
	root.add_child(tb)
	var t := 0.0
	var k := 0
	while k < MOMENTS.size():
		await process_frame
		t += 1.0 / 60.0
		if t >= MOMENTS[k]:
			var img := root.get_viewport().get_texture().get_image()
			var p := OUT + "terrain_%d.png" % k
			img.save_png(p)
			print(ProjectSettings.globalize_path(p))
			k += 1
	quit(0)

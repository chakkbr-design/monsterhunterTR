extends SceneTree
## Fotos de uma luta do treino com times da bateria Gen 9 (sem --headless):
##   godot --path . --resolution 1920x1080 --script res://tests/balance/shot_battery.gd -- size=2
## Grava user://shots/battery_<size>x<size>_<n>.png em vários momentos da luta.

const Cfg := preload("res://ui/training/training_config.gd")
const Battery := preload("res://tests/balance/battery_gen9.gd")
const MOMENTS := [3.0, 6.0, 9.0, 13.0, 18.0, 25.0]

var size := 2


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := String(a).split("=")
		if kv.size() == 2 and kv[0] == "size":
			size = int(kv[1])
	_run.call_deferred()


func _run() -> void:
	Cfg.path = "user://shot_battery_cfg.json"
	var c := Cfg.default_config()
	var keys: Array = Battery.TEAMS.keys()
	for s in 2:
		c.sides[s].name = keys[s]
		c.sides[s].mons = []
		for n in Battery.TEAMS[keys[s]]:
			c.sides[s].mons.append(Cfg.mon_entry(String(n), 50))
	c.battle_size = size
	c.seed = 101
	Cfg.current = c
	var tb: Node = load("res://ui/training/training_battle.tscn").instantiate()
	root.add_child(tb)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots"))
	var t := 0.0
	var k := 0
	while k < MOMENTS.size():
		await process_frame
		t += 1.0 / 60.0
		if t >= MOMENTS[k]:
			var img := root.get_viewport().get_texture().get_image()
			var p := "user://shots/battery_%dx%d_%d.png" % [size, size, k]
			img.save_png(p)
			print(ProjectSettings.globalize_path(p))
			k += 1
	quit(0)

extends SceneTree
## Fotos do clima numa luta do treino (sem --headless):
##   godot --path . --resolution 1280x720 --script res://tests/battle/shot_weather.gd -- weather=rain
## Grava user://shots/weather_<clima>_<n>.png em alguns momentos (a neve acumula no chão com o tempo).

const Cfg := preload("res://ui/training/training_config.gd")
const MOMENTS := [2.5, 6.0, 11.0]

var weather := "rain"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := String(a).split("=")
		if kv.size() == 2 and kv[0] == "weather":
			weather = kv[1]
	_run.call_deferred()


func _run() -> void:
	Cfg.path = "user://shot_weather_cfg.json"
	var c := Cfg.default_config()
	c.battle_size = 2
	c.seed = 7
	c["weather"] = weather
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
			var p := "user://shots/weather_%s_%d.png" % [weather, k]
			img.save_png(p)
			print(ProjectSettings.globalize_path(p))
			k += 1
	quit(0)

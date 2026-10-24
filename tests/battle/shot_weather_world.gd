extends SceneTree
## Fotos do clima numa luta no mapa de verdade (sem --headless), com o chão do mundo molhado/branco:
##   godot --path . --resolution 1280x720 --script res://tests/battle/shot_weather_world.gd -- weather=hail
## Grava user://shots/weather_world_<clima>_<n>.png. Usa save de teste; nunca grava user://save.json.

const MOMENTS := [3.0, 10.0]

var weather := "hail"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := String(a).split("=")
		if kv.size() == 2 and kv[0] == "weather":
			weather = kv[1]
	_run.call_deferred()


func _run() -> void:
	var game: Node = root.get_node_or_null("Game")
	game.save_path = "user://test_save_weather_shot.json"
	game.last_save = {}
	game.spawn_request = {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	game.party = [Mon.create("Charmander", 14, rng), Mon.create("Pidgey", 12, rng)]
	var world: Node3D = load("res://world/route_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for i in 90:
		await process_frame
	var pl := world.get_tree().get_first_node_in_group("player") as Node3D
	var at := pl.global_position if pl else Vector3.ZERO
	game.request_battle(
		[Mon.create("Rattata", 12, rng)],
		{"kind": "wild", "weather": weather, "autoplay": true, "can_run": false},
		world,
		at
	)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots"))
	var t := 0.0
	var k := 0
	while k < MOMENTS.size():
		await process_frame
		t += 1.0 / 60.0
		if t >= MOMENTS[k]:
			var img := root.get_viewport().get_texture().get_image()
			var p := "user://shots/weather_world_%s_%d.png" % [weather, k]
			img.save_png(p)
			print(ProjectSettings.globalize_path(p))
			k += 1
	quit(0)

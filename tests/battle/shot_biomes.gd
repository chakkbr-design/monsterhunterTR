extends SceneTree
## Fotos dos biomas do modo de energia (sem --headless):
##   godot --path . --resolution 1280x720 --script res://tests/battle/shot_biomes.gd [-- out=DIR at=12]
## Grava <out>/biome_<cenário>.png (padrão docs/screens/) com a luta do treino `at` s depois do começo.

const Cfg := preload("res://ui/training/training_config.gd")
const LIST := ["ruinas", "montanha", "vulcao", "caverna", "pantano"]

var out := "res://docs/screens/"
var at := 2.0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := String(a).split("=")
		if kv.size() == 2 and kv[0] == "out":
			out = kv[1].trim_suffix("/") + "/"
		elif kv.size() == 2 and kv[0] == "at":
			at = float(kv[1])
	_run.call_deferred()


func _run() -> void:
	Cfg.path = "user://shot_biomes_cfg.json"
	var teams := [["charmander", "pikachu"], ["squirtle", "geodude"]]
	for sc in LIST:
		var c := Cfg.default_config()
		for s in 2:
			c.sides[s].mons = []
			for n in teams[s]:
				c.sides[s].mons.append(Cfg.mon_entry(String(n), 50))
		c.battle_size = 2
		c.seed = 7
		c.speed = 0.6
		c.scenario = sc
		Cfg.current = c
		var tb: Node = load("res://ui/training/training_battle.tscn").instantiate()
		root.add_child(tb)
		# Espera a luta andar `at` s de jogo (a tela lenta do xvfb dá passos grandes por quadro).
		var arena: Node = null
		for i in 3000:
			await process_frame
			if arena == null:
				var found := tb.find_children("*", "Node3D", true, false)
				for n in found:
					if n.has_method("switch_locked") and n.get("terrain") != null:
						arena = n
			if arena and arena.state == "fight" and float(arena.get("_state_t")) >= at:
				break
		var img := root.get_viewport().get_texture().get_image()
		var p := out + "biome_%s.png" % sc
		img.save_png(p)
		print(ProjectSettings.globalize_path(p) if p.begins_with("res://") else p)
		tb.queue_free()
		await process_frame
		await process_frame
	quit(0)

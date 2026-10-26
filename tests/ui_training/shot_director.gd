extends SceneTree
## Fotos da câmera de ação do treino (sem --headless): godot --path . --resolution 1280x720
## --script res://tests/ui_training/shot_director.gd. Grava em user://shots/director_<cena>_<n>.png
## a primeira vez de cada cena (enquadrar todos, golpe grande, desmaio, troca, soltar a bola por
## etapa e as fases da abertura do treino).

const Cfg := preload("res://ui/training/training_config.gd")
const SCENE := "res://ui/training/training_battle.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Cfg.path = "user://test_shot_director.json"
	var c := Cfg.default_config()
	var a: Array = []
	var b: Array = []
	for s in ["Charizard", "Blastoise", "Venusaur"]:
		a.append(Cfg.mon_entry(s, 50))
	for s in ["Gengar", "Machamp", "Alakazam"]:
		b.append(Cfg.mon_entry(s, 50))
	c.sides[0].mons = a
	c.sides[1].mons = b
	c.seed = 11
	c.battle_size = 2
	Cfg.current = c
	var tb: Node = load(SCENE).instantiate()
	root.add_child(tb)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots"))
	var seen := {}
	var last := ""
	var since := 0
	for i in 60 * 400:
		await process_frame
		if not is_instance_valid(tb.arena) or tb._result_box.visible:
			break
		var d = tb.arena.get("director")
		if d == null or not (String(tb.arena.state) in ["fight", "opening"]):
			continue
		var sh := String(d.shot)
		var op = tb.arena.get("opening")
		if op != null:
			# Abertura do treino: uma foto por fase (telão, arena inteira, arremessos, "Fight!") e
			# da cena "send" em cada etapa (treinador, bola, Pokémon).
			sh = "abertura_%s%s" % [op.phase, "_" + _send_step(d) if d.shot == "send" else ""]
		elif sh == "send":
			sh = "send_" + _send_step(d)
		since = 0 if sh != last else since + 1
		last = sh
		var n := int(seen.get(sh, 0))
		# Foto depois de a câmera chegar (12 quadros na cena), até 2 por cena.
		if since == 12 and n < 2:
			seen[sh] = n + 1
			var p := "user://shots/director_%s_%d.png" % [sh if sh != "" else "todos", n]
			root.get_texture().get_image().save_png(p)
			print("foto: ", ProjectSettings.globalize_path(p))
	quit()


## Etapa da cena "send": o treinador, a bola ou o Pokémon que saiu.
func _send_step(d: BattleDirector) -> String:
	var dist: float = d._send_frame()[3]
	if dist == BattleDirector.SEND_TRAINER_DIST:
		return "treinador"
	if dist == BattleDirector.SEND_BALL_DIST:
		return "bola"
	return "pokemon"

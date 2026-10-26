extends SceneTree
## Fotos do estádio voxel do treino de energia (sem --headless):
## xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --rendering-driver vulkan
##   --resolution 1600x900 --script res://tests/battle/shot_arena_stadium.gd --
##   --out=/tmp/estadio/campo [--scenario=campo] [--mood=dia|tarde|noite] [--seed=11] [--size=2]
##   [--views=inicio,meio,ko,aberta,placar,tunel,torcida,lago,gelo,mare] [--wait=420] [--speed=2]
##   [--weather=rain|storm|hail|sand|sun] [--pile=0..1]
## Abre res://ui/training/training_battle.tscn no modo de energia e grava <out>_<vista>.png (sem
## --out: user://shots/arena/estadio_<vista>.png):
## inicio = câmera de ação logo no começo da luta, meio = depois de `wait` quadros de luta,
## ko = uns quadros depois do primeiro desmaio (a torcida comemora), aberta = o estádio inteiro de
## fora (foto de apresentação), placar / tunel / torcida = de perto, sem a interface; lago = o lago
## mais perto da câmera, gelo = o mesmo lago congelado, mare = a maré cheia da praia.
## Com --weather a luta toda tem esse clima (storm = chuva com um raio forçado): raio = câmera de
## ação no clarão de um raio além da arquibancada do fundo, aberta_raio = o mesmo na vista aberta.
## --pile põe a neve acumulada (e o chão molhado) direto nesse nível, sem esperar os 9 s da luta.

const Cfg := preload("res://ui/training/training_config.gd")
const SCENE := "res://ui/training/training_battle.tscn"
const VIEWS := ["inicio", "meio", "ko", "aberta", "placar", "tunel", "torcida"]

var _args := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := String(a).trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_run.call_deferred()


func _run() -> void:
	var out := String(
		_args.get("out", ProjectSettings.globalize_path("user://shots/arena/estadio"))
	)
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	var views: PackedStringArray = String(_args.get("views", ",".join(VIEWS))).split(",")
	var t0 := Time.get_ticks_msec()
	Cfg.current = _cfg(String(_args.get("scenario", "campo")))
	var tb: Node = load(SCENE).instantiate()
	root.add_child(tb)
	print("cena montada em %d ms" % (Time.get_ticks_msec() - t0))
	var wait := int(_args.get("wait", "420"))
	var fought := 0
	var shot := {}
	var ko_at := -1
	for i in 60 * 240:
		await process_frame
		if not is_instance_valid(tb.arena) or tb._result_box.visible:
			break
		if String(tb.arena.state) != "fight":
			continue
		fought += 1
		if _args.has("pile"):
			var fx = tb.arena.get_node_or_null("WeatherFx")
			if fx and fx.get("level") != null:
				var p := float(_args.pile)
				fx.snow_pile = maxf(fx.snow_pile, p * float(fx.level.hail))
				fx.wet_ground = maxf(fx.wet_ground, p * float(fx.level.rain))
		if fought == 45 and "inicio" in views:
			_save(out, "inicio")
		if fought == wait and "meio" in views:
			_save(out, "meio")
		var down: int = int(tb._down[0]) + int(tb._down[1])
		if down > 0 and ko_at < 0:
			ko_at = fought
		if ko_at >= 0 and fought == ko_at + 40 and "ko" in views:
			_save(out, "ko")
			shot.ko = true
		var need_ko := "ko" in views and not shot.has("ko")
		if fought >= wait and not need_ko:
			break
	if "raio" in views:
		await _bolt(tb, out, "raio")
	# Vistas paradas, sem a interface.
	var hud = tb.arena.get("hud") if is_instance_valid(tb.arena) else null
	for l in [hud, tb.get("_ui")]:
		if l is CanvasLayer:
			l.visible = false
	var cam := Camera3D.new()
	cam.fov = 50.0
	cam.far = 900.0
	tb.add_child(cam)
	cam.make_current()
	var stills := {
		"aberta": [Vector3(70, 42, 92), Vector3(0, 0, -2), 46.0],
		"placar": [Vector3(4, 3.2, 4), Vector3(0, 8.5, -24), 50.0],
		"tunel": [Vector3(16, 2.6, 7), Vector3(31, 2.0, 0), 55.0],
		"torcida": [Vector3(-6, 2.4, -9), Vector3(-12, 5.0, -26), 50.0],
	}
	for v in stills:
		if not v in views:
			continue
		var s: Array = stills[v]
		cam.fov = float(s[2])
		cam.position = s[0]
		cam.look_at(s[1], Vector3.UP)
		for k in 3:
			await process_frame
		_save(out, v)
		if v == "aberta" and "aberta_raio" in views:
			await _bolt(tb, out, "aberta_raio")
	await _water(tb, cam, out, views)
	cam.queue_free()
	tb.queue_free()
	await process_frame
	await process_frame
	quit()


## Um raio além da arquibancada, na direção em que a câmera atual olha, e a foto no clarão.
func _bolt(tb: Node, out: String, view: String) -> void:
	var fx = tb.arena.get_node_or_null("WeatherFx") if is_instance_valid(tb.arena) else null
	if fx == null or fx.get("bolts") == null:
		print("sem raio: o clima não é de chuva no modo de energia")
		return
	var cam := root.get_viewport().get_camera_3d()
	var fwd := -cam.global_transform.basis.z
	fwd = Vector3(fwd.x, 0.0, fwd.z).normalized()
	fx.bolts.strike(Vector3(-8.0, 0.0, 0.0) + fwd * 60.0)
	for k in 2:
		await process_frame
	_save(out, view)
	for k in 12:
		await process_frame


## Lago mais perto do centro (de cima, de lado) e congelado; maré cheia da praia.
func _water(tb: Node, cam: Camera3D, out: String, views: PackedStringArray) -> void:
	if not is_instance_valid(tb.arena) or tb.arena.get("terrain") == null:
		return
	var t = tb.arena.terrain
	var pond := {}
	for o in t.obstacles:
		if o.kind == "pond" and (pond.is_empty() or o.pos.length() < pond.pos.length()):
			pond = o
	if not pond.is_empty() and ("lago" in views or "gelo" in views):
		var c: Vector3 = pond.pos
		cam.fov = 45.0
		cam.position = c + Vector3(1.5, 4.2, 6.5)
		cam.look_at(c, Vector3.UP)
		if "lago" in views:
			for k in 4:
				await process_frame
			_save(out, "lago")
		if "gelo" in views:
			t.freeze(pond, true)
			for k in 40:
				await process_frame
			_save(out, "gelo")
	var tide: Dictionary = t.ground.tide if t.get("ground") else {}
	if "mare" in views and not tide.is_empty():
		tide.phase = "in"
		tide.t = BattleGround.TIDE_IN * 0.5
		var side := float(tide.side)
		var perp: Vector3 = t.ground._perp()
		var mid := perp * side * float(tide.get("wide", 28.0)) * 0.25
		cam.fov = 55.0
		cam.position = mid + Vector3(0, 9, 16)
		cam.look_at(mid, Vector3.UP)
		for k in 30:
			await process_frame
		_save(out, "mare")


func _cfg(sc: String) -> Dictionary:
	Cfg.path = "user://test_shot_stadium.json"
	var c := Cfg.default_config()
	var a: Array = []
	var b: Array = []
	for s in ["Charizard", "Blastoise", "Venusaur"]:
		a.append(Cfg.mon_entry(s, 50))
	for s in ["Gengar", "Machamp", "Alakazam"]:
		b.append(Cfg.mon_entry(s, 50))
	c.sides[0].mons = a
	c.sides[1].mons = b
	c.seed = int(_args.get("seed", "11"))
	c.battle_size = int(_args.get("size", "2"))
	c.battle_mode = "energy"
	c.speed = float(_args.get("speed", "2"))
	c["scenario"] = sc
	c["time_of_day"] = String(_args.get("mood", "dia"))
	var w := String(_args.get("weather", ""))
	if w != "":
		c["weather"] = "rain" if w == "storm" else w
	return c


func _save(out: String, view: String) -> void:
	var path := "%s_%s.png" % [out, view]
	root.get_texture().get_image().save_png(path)
	print("foto: ", path)

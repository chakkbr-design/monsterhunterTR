extends SceneTree
## Fotos da quadra voxel do modo de energia (sem --headless):
## xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --rendering-driver vulkan
##   --resolution 1600x900 --script res://tests/battle/shot_arena.gd --
##   --out=/tmp/arena/campo.png [--scenario=campo|all] [--seed=11] [--size=2]
##   [--wait=240]
## Abre res://ui/training/training_battle.tscn no modo de energia com o cenário e a semente
## pedidos e grava, por cenário, a câmera de ação (<out>_<cenário>_acao.png) depois de `wait`
## quadros de luta, uma foto aberta da quadra inteira (_aberta) e uma de perto do relevo mais
## perto da câmera (_perto). Com um cenário só, a foto de ação vai no próprio --out. Cada cenário
## leva uns 2 a 3 min no Vulkan por software: "all" passa dos 10 min (rode um por vez).

const Cfg := preload("res://ui/training/training_config.gd")
const SCENE := "res://ui/training/training_battle.tscn"

var _args := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := String(a).trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_run.call_deferred()


func _run() -> void:
	var out := String(
		_args.get("out", ProjectSettings.globalize_path("user://shots/arena/arena.png"))
	)
	var which := String(_args.get("scenario", "campo"))
	var list: Array = BattleTerrain.SCENARIOS.keys() if which == "all" else [which]
	list.sort()
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	for sc in list:
		await _shoot(String(sc), out, list.size() == 1)
	quit()


func _cfg(sc: String) -> Dictionary:
	Cfg.path = "user://test_shot_arena.json"
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
	c["scenario"] = sc
	return c


func _shoot(sc: String, out: String, single: bool) -> void:
	Cfg.current = _cfg(sc)
	var tb: Node = load(SCENE).instantiate()
	root.add_child(tb)
	var wait := int(_args.get("wait", "240"))
	var fought := 0
	for i in 60 * 120:
		await process_frame
		if not is_instance_valid(tb.arena) or tb._result_box.visible:
			break
		if String(tb.arena.state) == "fight":
			fought += 1
			if fought >= wait:
				break
	var base := out.get_basename()
	_save(out if single else "%s_%s_acao.png" % [base, sc])
	# Foto aberta (a quadra inteira, de cima e da frente) e de perto, sem a interface.
	var hud = tb.arena.get("hud") if is_instance_valid(tb.arena) else null
	for l in [hud, tb.get("_ui")]:
		if l is CanvasLayer:
			l.visible = false
	var cam := Camera3D.new()
	cam.fov = 50.0
	tb.add_child(cam)
	_aim(cam, Vector3(0, 0, 1.5), deg_to_rad(52.0), 50.0)
	cam.make_current()
	await process_frame
	await process_frame
	_save("%s_%s_aberta.png" % [base, sc])
	_aim(cam, _near_thing(tb), deg_to_rad(34.0), 11.0)
	await process_frame
	await process_frame
	_save("%s_%s_perto.png" % [base, sc])
	cam.queue_free()
	tb.queue_free()
	await process_frame
	await process_frame


func _aim(cam: Camera3D, focus: Vector3, pitch: float, dist: float) -> void:
	cam.position = focus + Vector3(0, sin(pitch), cos(pitch)) * dist
	cam.look_at(focus, Vector3.UP)


## O relevo (ou bioma) mais perto da câmera, para a foto de perto.
func _near_thing(tb: Node) -> Vector3:
	if not is_instance_valid(tb.arena) or tb.arena.get("terrain") == null:
		return Vector3.ZERO
	var t = tb.arena.terrain
	var best := Vector3(0, 0, 4)
	var score := -INF
	for o in t.obstacles + t.props.items + t.biomes.solids:
		var p: Vector3 = o.pos
		var s := p.z - absf(p.x) * 0.35
		if s > score:
			score = s
			best = p
	return Vector3(best.x, 0.0, best.z)


func _save(path: String) -> void:
	root.get_texture().get_image().save_png(path)
	print("foto: ", path)

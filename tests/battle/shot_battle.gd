extends SceneTree
## Screenshots com render de verdade (NÃO headless):
##   godot --path . --script res://tests/battle/shot_battle.gd --resolution 1280x720
## Gera docs/screens/battle_original.png e docs/screens/capture.png.

const ARENA := "res://battle/battle_arena.tscn"
const DT := 1.0 / 60.0
const OUT := "res://docs/screens/"

var _world: Node3D


func _initialize() -> void:
	_main.call_deferred()


func _main() -> void:
	await process_frame
	_world = _build_world()
	await _battle_shot()
	await _capture_shot()
	quit(0)


func _build_world() -> Node3D:
	var w := Node3D.new()
	root.add_child(w)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.38, 0.6, 0.92)
	sm.sky_horizon_color = Color(0.75, 0.85, 0.95)
	sm.ground_horizon_color = Color(0.6, 0.7, 0.6)
	sky.sky_material = sm
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.9
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	w.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	w.add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 80)
	var gm := StandardMaterial3D.new()
	gm.albedo_texture = load("res://original/assets/textures/ground_grass.png")
	gm.uv1_scale = Vector3(40, 40, 1)
	gm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	pm.material = gm
	ground.mesh = pm
	w.add_child(ground)
	var tree_scn: PackedScene = load("res://original/assets/models/hgss/common/tree.scn")
	var bush_scn: PackedScene = load("res://original/assets/models/hgss/common/bush.scn")
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	for i in 26:
		var ang := float(i) / 26.0 * TAU
		var r := rng.randf_range(10.5, 15.0)
		var n: Node3D = (tree_scn if i % 3 != 0 else bush_scn).instantiate()
		n.position = Vector3(cos(ang) * r, 0, sin(ang) * r)
		w.add_child(n)
	return w


func _arena(party: Array, enemies: Array, opts: Dictionary) -> Node:
	var a: Node = load(ARENA).instantiate()
	a.manual = true
	_world.add_child(a)
	a.start(party, enemies, opts)
	return a


func _steps(a: Node, secs: float) -> void:
	for i in int(round(secs / DT)):
		a.step(DT)
		if i % 2 == 0:
			await process_frame


func _shot(name: String) -> void:
	for i in 3:
		await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(OUT + name))
	print("salvo ", OUT + name, " ", img.get_size())


func _battle_shot() -> void:
	var p := Mon.create("charmander", 22)
	p.moves = ["flamethrower", "scratch", "ember", "growl"]
	var a := _arena(
		[p], [Mon.create("pidgeotto", 24)], {"seed": 11, "battle_size": 1, "kind": "wild"}
	)
	await _steps(a, 1.5)
	a.enemy.controller = "none"
	a.player.position = Vector3(0, 0, 1.6)
	a.enemy.position = Vector3(0.6, 0, -2.0)
	await _steps(a, 0.3)
	a.moves.use(a.player, "ember", true)
	await _steps(a, 0.7)
	a.player.gcd_t = 0.0
	a.moves.use(a.player, "flamethrower", true)
	await _steps(a, 0.55)
	await _shot("battle_original.png")
	a.queue_free()
	await process_frame


func _capture_shot() -> void:
	var g = load("res://core/game.gd").new()
	g.bag = {"poke_ball": 5}
	var a := _arena(
		[Mon.create("squirtle", 12)],
		[Mon.create("pikachu", 6)],
		{"seed": 2, "battle_size": 1, "game": g}
	)
	await _steps(a, 1.5)
	a.enemy.controller = "none"
	a.enemy.position = Vector3(0.4, 0, -1.6)
	a.enemy.hp = maxi(1, a.enemy.max_hp / 5)
	await _steps(a, 0.2)
	a.throw_ball()
	await _steps(a, a.BALL_FLIGHT + a.BALL_ABSORB * 0.55)
	await _shot("capture.png")
	a.queue_free()
	g.free()
	await process_frame

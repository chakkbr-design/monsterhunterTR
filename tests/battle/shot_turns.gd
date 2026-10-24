extends SceneTree
## Screenshots com render de verdade (NÃO headless):
##   godot --path . --script res://tests/battle/shot_turns.gd --resolution 1280x720
## Rodadas no 2x2: posições fixas, treinadores dos dois lados, marcador de vez, botões de modo, a bola
## saindo na troca e o raio vermelho voltando. Gera docs/screens/turns_*.png.

const ARENA := "res://battle/battle_arena.tscn"
const DT := 1.0 / 60.0
const OUT := "res://docs/screens/"

var _world: Node3D


func _initialize() -> void:
	_main.call_deferred()


func _main() -> void:
	await process_frame
	_world = _build_world()
	await _doubles_shot()
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


func _doubles_shot() -> void:
	var a := _arena(
		[Mon.create("charmander", 22), Mon.create("pikachu", 22), Mon.create("squirtle", 22)],
		[Mon.create("geodude", 22), Mon.create("pidgeotto", 22), Mon.create("rattata", 22)],
		{
			"kind": "trainer",
			"trainer_id": "brock",
			"battle_size": 2,
			"autoplay": true,
			"seed": 5,
			"no_rewards": true
		}
	)
	await _steps(a, 5.0)
	await _shot("turns_positions.png")
	a.request_switch(0, a.player, 0)
	var r: int = a.turns.round_n
	while a.turns.round_n == r:
		a.step(DT)
		await process_frame
	await _steps(a, 0.1)
	await _shot("turns_recall_beam.png")
	await _steps(a, 0.2)
	await _shot("turns_ball_throw.png")
	await _steps(a, 0.4)
	await _shot("turns_ball_open.png")
	await _steps(a, 6.0)
	await _shot("turns_later.png")
	a.queue_free()
	await process_frame

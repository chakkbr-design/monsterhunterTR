extends Node3D
## Cena de teste: monta uma party, abre uma batalha selvagem pela ponte do Game e reabre outra ao terminar.
## Enter = nova batalha agora; T = alterna batalha de treinador (Brock); A = alterna IA controlando o jogador.

const WILD := [
	["pidgey", 6], ["rattata", 6], ["caterpie", 7], ["spearow", 7], ["weedle", 6], ["pikachu", 6]
]

@onready var game: Node = get_node("/root/Game")
var _label: Label
var _trainer := false
var _autoplay := "--autoplay" in OS.get_cmdline_user_args()
var _wait := 0.0


func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.7, 0.9)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 30, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.45, 0.6, 0.35)
	pm.material = gm
	ground.mesh = pm
	add_child(ground)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 14, 16)
	add_child(cam)
	cam.look_at(Vector3.ZERO)
	cam.make_current()
	var ui := CanvasLayer.new()
	_label = Label.new()
	_label.position = Vector2(16, 120)
	_label.add_theme_font_size_override("font_size", 18)
	ui.add_child(_label)
	add_child(ui)
	if game.party.is_empty():
		game.party = [
			Mon.create("charmander", 8), Mon.create("squirtle", 8), Mon.create("bulbasaur", 8)
		]
	game.battle_finished.connect(_on_finished)
	_start()


func _start() -> void:
	_label.text = ""
	_wait = 0.0
	if _trainer:
		var tr := Dex.trainer("brock")
		var foes: Array = []
		for e in tr.get("party", [["geodude", 12], ["onix", 14]]):
			foes.append(Mon.create(String(e[0]), int(e[1])))
		game.request_battle(
			foes,
			{"kind": "trainer", "trainer_id": "brock", "can_run": false, "autoplay": _autoplay},
			self,
			Vector3.ZERO
		)
	else:
		var w: Array = WILD.pick_random()
		game.request_battle(
			[Mon.create(w[0], w[1])],
			{"kind": "wild", "can_run": true, "autoplay": _autoplay},
			self,
			Vector3.ZERO
		)


func _on_finished(result: Dictionary) -> void:
	print("[battle_test] result: ", result.get("outcome"))
	var lines := ["Result: %s" % result.get("outcome")]
	for e in result.get("exp", []):
		lines.append("%s +%d EXP (Lv %d)" % [e.mon.display_name, e.amount, e.mon.level])
	if result.get("caught_mon") is Mon:
		lines.append("Caught %s! Party: %d" % [result.caught_mon.display_name, game.party.size()])
	lines.append(
		(
			"Party: "
			+ ", ".join(
				game.party.map(func(m): return "%s %d/%d" % [m.display_name, m.hp, m.max_hp])
			)
		)
	)
	lines.append(
		(
			"Enter: next battle   T: trainer %s   A: auto %s   H: heal party"
			% ["on" if _trainer else "off", "on" if _autoplay else "off"]
		)
	)
	_label.text = "\n".join(lines)
	_wait = 4.0


func _process(delta: float) -> void:
	if game.is_busy():
		return
	if Input.is_key_pressed(KEY_H):
		game.heal_party()
	if _wait > 0.0:
		_wait -= delta
		if _wait <= 0.0 or Input.is_key_pressed(KEY_ENTER):
			_start()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and not game.is_busy():
		if event.keycode == KEY_T:
			_trainer = not _trainer
		elif event.keycode == KEY_A:
			_autoplay = not _autoplay

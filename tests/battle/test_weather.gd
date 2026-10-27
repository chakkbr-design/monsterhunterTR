extends SceneTree
## Rodar: godot --headless --fixed-fps 60 --path . --script res://tests/battle/test_weather.gd
## Clima Gen 9: habilidades que criam clima, pedras, Def x1,5 na areia/neve, precisão e carga dos
## golpes no clima, Growth, congelar no sol, Hydration/Leaf Guard/Ice Body/Slush Rush, Snowscape e o
## visual do clima (BattleWeatherFx).

const ARENA := "res://battle/battle_arena.tscn"
const DT := 1.0 / 60.0

var _fails := 0
var _count := 0


## Dono da luz no treino (o papel do ArenaStadium): guarda o que o clima pede a ele.
class FakeLight:
	extends Node
	var calls := 0
	var cloud := -1.0
	var flash := 0.0
	var max_flash := 0.0
	var max_cloud := 0.0

	func _init() -> void:
		add_to_group(BattleWeatherFx.LIGHT_GROUP)

	func weather_light(c: float, f := 0.0) -> void:
		calls += 1
		cloud = c
		flash = f
		max_flash = maxf(max_flash, f)
		max_cloud = maxf(max_cloud, c)


func _initialize() -> void:
	_setters()
	_rocks()
	_defense()
	_moves()
	_status_and_heal()
	_snowscape()
	_fx()
	_late.call_deferred()


## Partes que precisam da árvore rodando (o modo de energia acha o ambiente e o sol do estádio).
func _late() -> void:
	await process_frame
	_fx_energy()
	print("weather: %d checks, %d falhas" % [_count, _fails])
	quit(1 if _fails else 0)


func check(ok: bool, what: String) -> void:
	_count += 1
	if not ok:
		_fails += 1
		print("FALHOU: ", what)


func _run(a: Node, secs: float) -> void:
	for i in int(round(secs / DT)):
		a.step(DT)


## Arena parada: ninguém age.
func _still(mine := "pidgey", foe := "rattata", extra := {}) -> Node:
	var a: Node = load(ARENA).instantiate()
	a.manual = true
	root.add_child(a)
	var o := {"speed": 1.0, "auto_battle": false, "seed": 7}
	o.merge(extra)
	a.start([Mon.create(mine, 30)], [Mon.create(foe, 30)], o)
	_run(a, 1.3)
	a.enemy.controller = "none"
	a.player.controller = "none"
	_run(a, 1.5)
	return a


func _clear(ab: BattleAbilities) -> void:
	ab.weather = ""
	ab.weather_t = 0.0
	ab.weather_rounds = 0


func _setters() -> void:
	var a := _still()
	var ab: BattleAbilities = a.abilities
	for pair in [["drizzle", "rain"], ["sand_stream", "sand"], ["snow_warning", "hail"]]:
		_clear(ab)
		a.player.set_meta("ability_override", pair[0])
		ab.on_enter(a.player)
		_run(a, 0.3)
		check(ab.weather_now() == pair[1], "%s cria %s (%s)" % [pair[0], pair[1], ab.weather_now()])
		check(ab.weather_rounds == 5, "%s: 5 rodadas (%d)" % [pair[0], ab.weather_rounds])
		check(not Dex.ability(String(pair[0])).is_empty(), "%s em abilities.json" % pair[0])
	a.player.remove_meta("ability_override")
	a.free()


func _rocks() -> void:
	var a := _still()
	var ab: BattleAbilities = a.abilities
	a.player.trainer_item = "damp_rock"
	a.player.set_meta("ability_override", "drizzle")
	_clear(ab)
	ab.on_enter(a.player)
	_run(a, 0.3)
	check(ab.weather_rounds == 8, "Drizzle + Damp Rock: 8 rodadas (%d)" % ab.weather_rounds)
	a.player.remove_meta("ability_override")
	_clear(ab)
	a.player.trainer_item = "heat_rock"
	a.moves.effects.self_move(a.player, Dex.move("sunny_day"))
	check(
		ab.weather_now() == "sun" and ab.weather_rounds == 8,
		"Sunny Day + Heat Rock: 8 rodadas (%d)" % ab.weather_rounds
	)
	_clear(ab)
	a.player.trainer_item = "heat_rock"
	a.moves.effects.self_move(a.player, Dex.move("rain_dance"))
	check(ab.weather_rounds == 5, "pedra errada não alonga (%d)" % ab.weather_rounds)
	for id in ["heat_rock", "damp_rock", "smooth_rock", "icy_rock"]:
		check(String(Dex.item(id).get("category", "")) == "held", "%s é item segurado" % id)
	a.free()


func _defense() -> void:
	var a := _still()
	var ab: BattleAbilities = a.abilities
	a.enemy.types = ["rock"]
	var sp := Dex.move("water_gun")
	var ph := Dex.move("tackle")
	_clear(ab)
	var base_sp := ab.damage_mult(a.player, a.enemy, sp)
	var base_ph := ab.damage_mult(a.player, a.enemy, ph)
	ab.set_weather_rounds("sand")
	check(
		is_equal_approx(ab.damage_mult(a.player, a.enemy, sp), base_sp / 1.5),
		"areia: Pedra com Def. Esp. x1,5"
	)
	check(
		is_equal_approx(ab.damage_mult(a.player, a.enemy, ph), base_ph),
		"areia: Def física da Pedra igual"
	)
	_clear(ab)
	a.enemy.types = ["ice"]
	ab.set_weather_rounds("hail")
	check(
		is_equal_approx(ab.damage_mult(a.player, a.enemy, ph), base_ph / 1.5),
		"neve: Gelo com Def x1,5"
	)
	check(
		is_equal_approx(ab.damage_mult(a.player, a.enemy, sp), base_sp),
		"neve: Def. Esp. do Gelo igual"
	)
	a.free()


func _moves() -> void:
	var a := _still()
	var ab: BattleAbilities = a.abilities
	var fx: BattleMoveEffects = a.moves.effects
	var u: BattleFighter = a.player
	_clear(ab)
	check(fx.accuracy_of(u, Dex.move("thunder")) == 70.0, "Thunder 70% sem clima")
	check(fx.accuracy_of(u, Dex.move("blizzard")) == 70.0, "Blizzard 70% sem clima")
	check(fx.move_for(u, Dex.move("solar_beam")).windup == 1.1, "Solar Beam com carga sem sol")
	ab.set_weather_rounds("sun")
	check(fx.accuracy_of(u, Dex.move("thunder")) == 50.0, "Thunder 50% no sol")
	check(fx.accuracy_of(u, Dex.move("hurricane")) == 50.0, "Hurricane 50% no sol")
	check(fx.move_for(u, Dex.move("solar_beam")).windup < 0.5, "Solar Beam sem carga no sol")
	check(fx.move_for(u, Dex.move("solar_blade")).windup < 0.5, "Solar Blade sem carga no sol")
	var atk0 := int(u.stages.get("atk", 0))
	fx.self_move(u, Dex.move("growth"))
	check(int(u.stages.get("atk", 0)) == atk0 + 2, "Growth +2 no sol")
	_clear(ab)
	ab.set_weather_rounds("rain")
	check(fx.accuracy_of(u, Dex.move("thunder")) == 0.0, "Thunder não erra na chuva")
	var t: BattleFighter = a.enemy
	check(
		is_equal_approx(fx.damage_mult(u, t, Dex.move("solar_blade")), 0.5),
		"Solar Blade 0,5x na chuva"
	)
	_clear(ab)
	ab.set_weather_rounds("hail")
	check(fx.accuracy_of(u, Dex.move("blizzard")) == 0.0, "Blizzard não erra na neve")
	a.free()


func _status_and_heal() -> void:
	var a := _still()
	var ab: BattleAbilities = a.abilities
	var f: BattleFighter = a.player
	_clear(ab)
	check(not ab.blocks_status(f, "freeze"), "congela sem sol")
	ab.set_weather_rounds("sun")
	check(ab.blocks_status(f, "freeze"), "ninguém congela no sol")
	check(not ab.blocks_status(f, "burn"), "sem Leaf Guard queima no sol")
	f.set_meta("ability_override", "leaf_guard")
	check(ab.blocks_status(f, "burn"), "Leaf Guard: sem status no sol")
	_clear(ab)
	check(not ab.blocks_status(f, "burn"), "Leaf Guard: nada sem sol")
	f.set_meta("ability_override", "hydration")
	f.apply_status("burn")
	check(not ab.shed_skin(f) and f.status == "burn", "Hydration: nada sem chuva")
	ab.set_weather_rounds("rain")
	check(ab.shed_skin(f) and f.status == "", "Hydration cura o status na chuva")
	_clear(ab)
	f.set_meta("ability_override", "ice_body")
	f.hp = f.max_hp / 2
	var hp0 := f.hp
	ab.set_weather_rounds("hail")
	ab.weather_residual(f)
	check(f.hp == hp0 + maxi(1, f.max_hp / 16), "Ice Body +1/16 na neve (%d -> %d)" % [hp0, f.hp])
	f.set_meta("ability_override", "slush_rush")
	check(ab.order_speed_mult(f) == 2.0, "Slush Rush: Speed 2x na neve")
	f.set_meta("ability_override", "snow_cloak")
	f.evasion_t = 0.0
	_run(a, 0.1)
	check(f.evasion > 0.0, "Snow Cloak: esquiva na neve")
	f.remove_meta("ability_override")
	a.free()


func _snowscape() -> void:
	var mv := Dex.move("snowscape")
	check(
		String(mv.get("type", "")) == "ice" and int(mv.get("uses", 0)) == 10, "Snowscape nos golpes"
	)
	var a := _still("lapras" if not Dex.species("lapras").is_empty() else "pidgey")
	var ab: BattleAbilities = a.abilities
	_clear(ab)
	a.moves.effects.self_move(a.player, mv)
	check(ab.weather_now() == "hail" and ab.weather_rounds == 5, "Snowscape: neve por 5 rodadas")
	for i in 5:
		ab.on_round_end()
	check(ab.weather_now() == "", "Snowscape: a neve acaba depois de 5 rodadas")
	a.free()


func _fx() -> void:
	var a := _still()
	var fx := a.get_node_or_null("WeatherFx") as BattleWeatherFx
	check(fx != null, "arena tem o visual do clima")
	if fx == null:
		a.free()
		return
	var ab: BattleAbilities = a.abilities
	_clear(ab)
	fx._process(0.1)
	check(fx.get_child_count() == 0, "sem clima não monta nada")
	ab.set_weather_rounds("hail")
	for i in 30:
		fx._process(0.1)
	check(fx.current() == "hail" and fx.level.hail == 1.0, "neve entra no visual")
	check(fx.snow_pile > 0.2, "neve acumula no chão (%f)" % fx.snow_pile)
	check(fx.get_child_count() > 5, "partículas montadas")
	_clear(ab)
	ab.set_weather_rounds("rain")
	for i in 30:
		fx._process(0.1)
	check(fx.level.hail == 0.0 and fx.level.rain == 1.0, "troca de neve para chuva")
	check(fx.wet_ground > 0.5, "chão molhado na chuva")
	_clear(ab)
	for i in 120:
		fx._process(0.1)
	check(fx.level.rain == 0.0 and fx.snow_pile == 0.0, "clima some quando acaba")
	a.free()


## Modo de energia: chuva e neve do WeatherRig cobrindo quadra e arquibancada, raio de verdade e,
## sem mundo (treino), os globais do clima; a luz é do dono dela (o estádio), a quem o clima só pede
## nuvem e clarão (weather_light), e tudo volta ao fim da luta. O clima nunca mexe num sol ou num
## ambiente direto (nada brigando quadro a quadro com o estádio).
func _fx_energy() -> void:
	var we := WorldEnvironment.new()
	we.environment = Environment.new()
	we.environment.ambient_light_energy = 0.5
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.0
	root.add_child(sun)
	var lt := FakeLight.new()
	root.add_child(lt)
	var a := _still("pidgey", "rattata", {})
	var fx := a.get_node_or_null("WeatherFx") as BattleWeatherFx
	var ab: BattleAbilities = a.abilities
	_clear(ab)
	fx._process(0.1)
	check(fx.get_child_count() == 0, "energia: sem clima não monta nada")
	ab.set_weather_rounds("hail")
	for i in 30:
		fx._process(0.1)
	check(fx.rig != null, "energia usa o WeatherRig compartilhado")
	var r: Rect2 = a.rect
	var want := r.size * 0.5 + Vector2(BattleWeatherFx.STANDS_MARGIN, BattleWeatherFx.STANDS_MARGIN)
	check(fx.rig.area.is_equal_approx(want), "cobre a quadra e a arquibancada (%s)" % fx.rig.area)
	check(not fx.rig.follow and fx.rig.field != null, "rig parado sobre a quadra, com heightfield")
	check(fx.rig.snow > 0.9 and fx.rig.snow_p.emitting, "neve caindo no modo energia")
	check(float(fx.published.get("snow_cover", 0.0)) > 0.1, "treino: snow_cover sobe")
	check(fx.light_owner == lt, "treino: acha o dono da luz pelo grupo")
	check(lt.cloud > 0.5, "treino: a neve pede nuvem ao dono da luz (%.2f)" % lt.cloud)
	check(
		is_equal_approx(float(fx.published.get("cloud_cover", 0.0)), lt.cloud),
		"cloud_cover publicado = a nuvem pedida ao estádio"
	)
	check(fx._ground != null, "quadra sem voxel: o piso por cima continua")
	_clear(ab)
	ab.set_weather_rounds("rain")
	for i in 30:
		fx._process(0.1)
	check(fx.rig.rain > 0.8 and fx.rig.rain_p.emitting, "chuva do rig no modo energia")
	check(fx.rig.splash_p != null and fx.rig.rain_p.sub_emitter != NodePath(), "respingos ligados")
	check(float(fx.published.get("rain_wet", 0.0)) > 0.4, "treino: chão molhado pelo global")
	check(fx.bolts.storm > 0.9, "chuva forte traz relâmpagos")
	fx.bolts.strike()
	fx._process(1.0 / 60.0)
	check(fx.flash > 0.1, "relâmpago acende (%f)" % fx.flash)
	check(
		float(fx.published.get("lightning_flash", 0.0)) > 0.1, "treino: lightning_flash publicado"
	)
	check(lt.max_flash > 0.1, "o clarão chega ao dono da luz (%.2f)" % lt.max_flash)
	check(is_equal_approx(sun.light_energy, 1.0), "o clima não mexe no sol (é do estádio)")
	check(
		is_equal_approx(we.environment.ambient_light_energy, 0.5),
		"o clima não mexe no ambiente (é do estádio)"
	)
	a.remove_child(fx)
	check(fx.published.is_empty(), "fim da luta: globais de volta")
	check(lt.cloud == 0.0 and lt.flash == 0.0, "fim da luta: a luz do estádio fica limpa")
	check(BattleWeatherFx.global_default("rain_wet") == 0.0, "padrão do global vem do projeto")
	fx.free()
	a.free()
	# Quadra voxel (treino de energia): o próprio piso mostra chão molhado e neve, sem a placa lisa.
	var v := _still("pidgey", "rattata", {"voxel": true})
	var vfx := v.get_node_or_null("WeatherFx") as BattleWeatherFx
	_clear(v.abilities)
	v.abilities.set_weather_rounds("rain")
	for i in 20:
		vfx._process(0.1)
	check(vfx._ground == null, "quadra voxel: sem a placa lisa por cima do piso")
	check(float(vfx.published.get("rain_wet", 0.0)) > 0.4, "quadra voxel: piso molhado pelo global")
	v.free()
	we.free()
	sun.free()
	lt.free()

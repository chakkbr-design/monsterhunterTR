class_name BattleWeatherFx
extends Node3D
## Visual do clima da luta (sol, chuva, areia, neve), lido a cada frame de arena.moves.effects.weather()
## (o de battle_abilities, opts.weather ou o clima local dos testes), com entrada e saída suaves:
## - chuva: gotas caindo (GPUParticles3D), respingos no chão, chão molhado com poças e anéis, tela fria
##   e relâmpago de vez em quando;
## - neve: flocos com vento, a neve acumula no chão aos poucos e derrete quando o clima acaba;
## - sol forte: feixes de luz na quadra, raios saindo do canto da tela, poeira dourada no ar;
## - areia: grãos cruzando a quadra e ondas de areia no chão (sem nuvem nem névoa, para não tapar a luta).
## No mundo (há WorldWeather) o chão é o do mundo: o clima vai para WorldWeather.battle_cover e os
## shaders do mapa ficam molhados ou brancos. Sem mundo (treino, cena de teste) vai um piso próprio.
## Também mostra o nome do clima e as rodadas que faltam no alto da tela.
##
## Energy mode (arena.energy_on(): training and energy fights) uses the shared gfx/weather pieces
## instead of the VGC particles:
## - WeatherRig fixed over the court and the stands: the training stadium's weather_area() (the
##   whole bowl out to the parapet), else arena.rect plus STANDS_MARGIN. Velocity-aligned rain that
##   stops on the stands, roofs and pond water (collision heightfield, pond collision boxes) and
##   splashes where it lands, snowflakes that settle; amounts follow GfxQuality;
## - WeatherLightning in heavy rain: a real light flash, voxel bolts outside the stands, thunder
##   delayed by distance;
## - WeatherAudio: rain loop by intensity, wind, thunder;
## - with no world (training) it owns the weather globals (rain_amount, rain_wet, rain_puddle,
##   snow_cover, cloud_cover, lightning_flash) and asks the light owner (a node in LIGHT_GROUP,
##   the ArenaStadium) for the rest through weather_light(cloud, flash): the stadium dims its own
##   sun and lifts its ambient, so nobody else writes them. When the fight ends (_exit_tree) the
##   globals go back to the project defaults and the stadium gets weather_light(0, 0);
## - the voxel court (arena.voxel_court()) reads rain_wet, rain_puddle and snow_cover in its own
##   shader, so it gets no flat ground overlay.
## The VGC path (and its look) is unchanged.

const KINDS := ["rain", "hail", "sun", "sand"]
## Força: segundos para entrar/sair; a neve no chão acumula e derrete mais devagar.
const FADE_IN := 1.6
const FADE_OUT := 2.2
const SNOW_PILE_SECS := 9.0
const SNOW_MELT_SECS := 6.0
const WET_DRY_SECS := 5.0
## Folga em volta da quadra coberta pelas partículas e pelo piso.
const MARGIN := 6.0
const RAIN_TOP := 11.0
const LIGHTNING_GAP := Vector2(6.0, 14.0)
const SHAFTS := 6
## Neve no chão do mundo: não chega ao branco puro, para os flocos aparecerem por cima.
const WORLD_SNOW_MAX := 0.82
const NAMES := {"rain": "Chuva", "hail": "Neve", "sun": "Sol forte", "sand": "Areia"}
## Energy mode: metres of cover around arena.rect when there is no stadium to ask, and the rain
## heightfield.
const STANDS_MARGIN := 12.0
const ENERGY_FIELD_RES := GPUParticlesCollisionHeightField3D.RESOLUTION_1024
## Energy mode over the training stadium's bowl (WeatherRig options): rain drops per square metre
## in the air (the bowl is big, so a little sparser than the overworld), the most drops and flakes
## on the best tier, a higher snow cloud (over the 8 m stands), a slower heightfield refresh
## (nothing moves there but the fighters), smaller splashes gone past the field (the action camera
## is 30-50 m away) and streaks that stay visible far out (the wide view is over 100 m away),
## stretched into faint lines there so the far rain under the floodlights is a haze, not white dots.
const BOWL := {
	"rain_density": 5.2,
	"amount_max": 32000,
	"snow_h": 11.0,
	"refresh": 0.6,
	"splash_scale": 0.75,
	"splash_far": 75.0,
	"rain_far": 160.0,
	"far_stretch": 6.0,
}
## Energy mode in training (no world): the globals this node owns, and the group of the node that
## owns the light (the stadium: weather_light(cloud, flash), weather_area()).
const GLOBALS := [
	"rain_amount", "rain_wet", "rain_puddle", "snow_cover", "cloud_cover", "lightning_flash"
]
const LIGHT_GROUP := "battle_weather_light"
const LABEL_COLORS := {
	"rain": Color(0.7, 0.85, 1.0),
	"hail": Color(0.9, 0.97, 1.0),
	"sun": Color(1.0, 0.85, 0.45),
	"sand": Color(0.95, 0.8, 0.55),
}

var arena: Node
## Força atual de cada clima (0..1) e o que ficou no chão.
var level := {"rain": 0.0, "hail": 0.0, "sun": 0.0, "sand": 0.0}
var snow_pile := 0.0
var wet_ground := 0.0
var flash := 0.0

var _rng := RandomNumberGenerator.new()
var _half := Vector2(10.0, 7.0)
var _center := Vector3.ZERO
var _rain: GPUParticles3D
var _splash: GPUParticles3D
var _snow: GPUParticles3D
var _sand_grains: GPUParticles3D
var _motes: GPUParticles3D
var _shafts: Array[MeshInstance3D] = []
var _ground: MeshInstance3D
var _ground_mat: ShaderMaterial
var _screen: ColorRect
var _glow: ColorRect
var _label: Label
var _layer: CanvasLayer
var _bolt_t := 8.0
var _bolt_seq: Array = []
var _world: Node
var _built := false
## Energy mode (see the header).
var energy := false
var rig: WeatherRig
var bolts: WeatherLightning
var audio: WeatherAudio
var published := {}  ## training: last value written to each weather global
var light_owner: Node  ## training: the stadium (LIGHT_GROUP), null without one
var _t := 0.0


func _init(a: Node = null) -> void:
	arena = a
	name = "WeatherFx"


## Monta tudo no primeiro clima da luta (a quadra já está no lugar; luta sem clima não custa nada).
func _build() -> void:
	_built = true
	_rng.randomize()
	var r = arena.get("rect") if arena else null
	if r is Rect2:
		_half = r.size * 0.5
		_center = Vector3(r.get_center().x, 0.0, r.get_center().y)
	_world = get_tree().get_first_node_in_group("weather") if is_inside_tree() else null
	energy = arena != null and arena.has_method("energy_on") and bool(arena.energy_on())
	if energy:
		_build_energy()
	else:
		_build_rain()
		_build_snow()
	_build_sand()
	_build_sun()
	if _world == null and not _voxel_court():
		_build_ground()
	_build_screen()
	_bolt_t = _rng.randf_range(LIGHTNING_GAP.x, LIGHTNING_GAP.y)


## Voxel court (training in energy mode): its floor shader shows the wet, the puddles and the snow
## from the globals, so the flat overlay plane would only cut through its relief.
func _voxel_court() -> bool:
	return (
		energy and arena != null and arena.has_method("voxel_court") and bool(arena.voxel_court())
	)


## A shader global's default from the project ([shader_globals]); null if it has none. (Reading the
## live value back, RenderingServer.global_shader_parameter_get, only works in the editor.)
static func global_default(n: String) -> Variant:
	var s = ProjectSettings.get_setting("shader_globals/" + n)
	return s.get("value") if s is Dictionary else null


func _exit_tree() -> void:
	if _built:
		_set_world_cover(Color(0, 0, 0, 0))
	_restore_training()


## Clima que vale agora ("" = nenhum); "snow" vira "hail" (a neve da Gen 9).
func current() -> String:
	if arena == null:
		return ""
	var w := ""
	var mv = arena.get("moves")
	if mv and mv.get("effects"):
		w = String(mv.effects.weather())
	elif arena.get("abilities"):
		w = String(arena.abilities.weather_now())
	return "hail" if w == "snow" else w


func _process(dt: float) -> void:
	var w := current()
	if not _built:
		if w == "":
			return
		_build()
	for k in KINDS:
		var up := 1.0 / FADE_IN if k == w else -1.0 / FADE_OUT
		level[k] = clampf(float(level[k]) + up * dt, 0.0, 1.0)
	var rain: float = level.rain
	var snow: float = level.hail
	var sun: float = level.sun
	var sand: float = level.sand
	snow_pile = move_toward(
		snow_pile,
		1.0 if w == "hail" else 0.0,
		dt / (SNOW_PILE_SECS if w == "hail" else SNOW_MELT_SECS)
	)
	wet_ground = move_toward(
		wet_ground, rain, dt / (FADE_IN if rain > wet_ground else WET_DRY_SECS)
	)
	if energy:
		_update_energy(dt, rain, snow)
	else:
		_lightning(dt, rain)
		_emit(_rain, rain)
		_emit(_splash, rain * 0.9)
		_emit(_snow, snow)
	_emit(_sand_grains, sand)
	_emit(_motes, sun)
	_update_shafts(sun)
	if _ground_mat:
		_ground_mat.set_shader_parameter("wet", wet_ground)
		_ground_mat.set_shader_parameter("snow", snow_pile)
		_ground_mat.set_shader_parameter("sand", sand)
		_ground.visible = wet_ground > 0.001 or snow_pile > 0.001 or sand > 0.001
	_set_world_cover(
		Color(wet_ground, snow_pile * WORLD_SNOW_MAX, sand * 0.5, maxf(rain, snow) * 0.7)
	)
	var sm := _screen.material as ShaderMaterial
	sm.set_shader_parameter("rain", rain)
	sm.set_shader_parameter("snow", snow)
	sm.set_shader_parameter("sand", sand)
	sm.set_shader_parameter("sun", sun)
	_screen.visible = rain + snow + sand + sun > 0.001
	var gm := _glow.material as ShaderMaterial
	gm.set_shader_parameter("sun", sun)
	var screen_flash := flash * (0.1 if energy else 1.0)  # energy: the real light does the work
	gm.set_shader_parameter("flash", screen_flash)
	_glow.visible = sun > 0.001 or screen_flash > 0.001
	_update_label(w)


func _emit(p: GPUParticles3D, k: float) -> void:
	p.amount_ratio = clampf(k, 0.0, 1.0)
	p.emitting = k > 0.01


## Relâmpago na chuva forte: clarão duplo a cada LIGHTNING_GAP s.
func _lightning(dt: float, rain: float) -> void:
	flash = maxf(flash - dt * 4.0, 0.0)
	for i in range(_bolt_seq.size() - 1, -1, -1):
		_bolt_seq[i] -= dt
		if _bolt_seq[i] <= 0.0:
			flash = 1.0
			_bolt_seq.remove_at(i)
	if rain < 0.6:
		return
	_bolt_t -= dt
	if _bolt_t <= 0.0:
		_bolt_t = _rng.randf_range(LIGHTNING_GAP.x, LIGHTNING_GAP.y)
		_bolt_seq = [0.0, _rng.randf_range(0.12, 0.22)]


func _set_world_cover(c: Color) -> void:
	if is_instance_valid(_world) and "battle_cover" in _world:
		_world.battle_cover = c


func _update_label(w: String) -> void:
	if w == "":
		_label.modulate.a = move_toward(_label.modulate.a, 0.0, 0.05)
		return
	var n := String(NAMES.get(w, w))
	var ab = arena.get("abilities")
	var left := int(ab.weather_rounds) if ab and "weather_rounds" in ab else 0
	_label.text = n + (" · %d" % left if left > 0 else "")
	_label.add_theme_color_override("font_color", LABEL_COLORS.get(w, Color.WHITE))
	_label.modulate.a = move_toward(_label.modulate.a, 1.0, 0.08)


# --- Montagem ---


func _particles(amount: int, life: float, box: Vector3, at: Vector3) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.local_coords = false
	p.emitting = false
	p.amount = amount
	p.amount_ratio = 0.0
	p.lifetime = life
	p.preprocess = life
	p.position = _center + at
	p.visibility_aabb = AABB(Vector3(-40, -20, -40), Vector3(80, 40, 80))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = box
	p.process_material = pm
	add_child(p)
	return p


func _mat(tex: Texture2D, col: Color, billboard: int, add := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = billboard
	m.billboard_keep_scale = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if add:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.albedo_color = col
	m.albedo_texture = tex
	return m


func _area(thick: float) -> Vector3:
	return Vector3(_half.x + _margin(), thick, _half.y + _margin())


## Cover around the court: the stands in energy mode, the VGC margin otherwise.
func _margin() -> float:
	return STANDS_MARGIN if energy else MARGIN


func _build_rain() -> void:
	var box := _area(0.3)
	_rain = _particles(2600, 0.5, box, Vector3(0, RAIN_TOP, 0))
	var pm := _rain.process_material as ParticleProcessMaterial
	pm.direction = Vector3(0.12, -1.0, 0.06)
	pm.spread = 3.0
	pm.initial_velocity_min = 21.0
	pm.initial_velocity_max = 25.0
	pm.gravity = Vector3(0, -6.0, 0)
	pm.scale_min = 0.7
	pm.scale_max = 1.2
	var q := QuadMesh.new()
	q.size = Vector2(0.025, 0.8)
	q.material = _mat(
		_gradient_tex(), Color(0.8, 0.88, 1.0, 0.55), BaseMaterial3D.BILLBOARD_FIXED_Y
	)
	_rain.draw_pass_1 = q
	_splash = _particles(420, 0.4, Vector3(_half.x + 0.5, 0.02, _half.y + 0.5), Vector3(0, 0.07, 0))
	var sp := _splash.process_material as ParticleProcessMaterial
	sp.direction = Vector3(0, 1, 0)
	sp.spread = 5.0
	sp.initial_velocity_min = 0.0
	sp.initial_velocity_max = 0.05
	sp.gravity = Vector3.ZERO
	sp.scale_curve = _curve_tex([Vector2(0, 0.3), Vector2(1, 1.4)])
	sp.alpha_curve = _curve_tex([Vector2(0, 0), Vector2(0.15, 1), Vector2(1, 0)])
	var pl := PlaneMesh.new()
	pl.size = Vector2(0.18, 0.18)
	pl.material = _mat(_ring_tex(), Color(0.82, 0.9, 1.0, 0.6), BaseMaterial3D.BILLBOARD_DISABLED)
	_splash.draw_pass_1 = pl


func _build_snow() -> void:
	_snow = _particles(1500, 7.0, _area(0.5), Vector3(0, 8.0, 0))
	var pm := _snow.process_material as ParticleProcessMaterial
	pm.direction = Vector3(0.25, -1.0, 0.1)
	pm.spread = 20.0
	pm.initial_velocity_min = 0.9
	pm.initial_velocity_max = 1.6
	pm.gravity = Vector3(0, -0.25, 0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.8
	pm.turbulence_noise_scale = 3.0
	pm.turbulence_influence_min = 0.05
	pm.turbulence_influence_max = 0.15
	pm.scale_min = 0.45
	pm.scale_max = 1.3
	pm.alpha_curve = _curve_tex([Vector2(0, 0), Vector2(0.08, 1), Vector2(0.9, 1), Vector2(1, 0)])
	var q := QuadMesh.new()
	q.size = Vector2(0.16, 0.16)
	q.material = _mat(_flake_tex(), Color(1, 1, 1, 0.95), BaseMaterial3D.BILLBOARD_PARTICLES)
	_snow.draw_pass_1 = q


func _build_sand() -> void:
	var box := Vector3(1.5, 1.3, _half.y + _margin())
	var at := Vector3(-_half.x - _margin() - 1.0, 1.3, 0)
	_sand_grains = _particles(1800, 2.4, box, at)
	var pm := _sand_grains.process_material as ParticleProcessMaterial
	pm.direction = Vector3(1.0, -0.05, 0.12)
	pm.spread = 8.0
	pm.initial_velocity_min = 9.0
	pm.initial_velocity_max = 14.0
	pm.gravity = Vector3(0, -0.6, 0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.2
	pm.turbulence_influence_min = 0.05
	pm.turbulence_influence_max = 0.12
	pm.scale_min = 0.5
	pm.scale_max = 1.4
	pm.color_initial_ramp = _color_ramp(Color(0.72, 0.56, 0.34), Color(0.95, 0.83, 0.6))
	var q := QuadMesh.new()
	q.size = Vector2(0.2, 0.025)
	q.material = _mat(_gradient_tex(true), Color(1, 1, 1, 0.8), BaseMaterial3D.BILLBOARD_ENABLED)
	_sand_grains.draw_pass_1 = q


func _build_sun() -> void:
	_motes = _particles(180, 5.0, Vector3(_half.x + 2.0, 1.2, _half.y + 2.0), Vector3(0, 1.4, 0))
	var pm := _motes.process_material as ParticleProcessMaterial
	pm.direction = Vector3(0.2, 1.0, 0)
	pm.spread = 40.0
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.25
	pm.gravity = Vector3.ZERO
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.5
	pm.turbulence_influence_min = 0.02
	pm.turbulence_influence_max = 0.06
	pm.scale_min = 0.5
	pm.scale_max = 1.5
	pm.alpha_curve = _curve_tex([Vector2(0, 0), Vector2(0.3, 1), Vector2(0.7, 1), Vector2(1, 0)])
	var q := QuadMesh.new()
	q.size = Vector2(0.09, 0.09)
	q.material = _mat(
		_dot_tex(), Color(1.0, 0.9, 0.55, 0.9), BaseMaterial3D.BILLBOARD_PARTICLES, true
	)
	_motes.draw_pass_1 = q
	var sh := load("res://gfx/shaders/weather_shaft.gdshader") as Shader
	for i in SHAFTS:
		var mi := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(_rng.randf_range(1.6, 3.2), 14.0)
		qm.center_offset = Vector3(0, 7.0, 0)
		mi.mesh = qm
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("phase", _rng.randf() * TAU)
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var f := (float(i) + 0.5) / SHAFTS
		mi.position = (
			_center
			+ Vector3(
				lerpf(-_half.x, _half.x, f) + _rng.randf_range(-1.0, 1.0),
				0.0,
				_rng.randf_range(-_half.y, _half.y) * 0.6
			)
		)
		mi.visible = false
		add_child(mi)
		_shafts.append(mi)


func _update_shafts(k: float) -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	for mi in _shafts:
		mi.visible = k > 0.001
		if not mi.visible:
			continue
		(mi.material_override as ShaderMaterial).set_shader_parameter("strength", k)
		if cam:
			# de frente para a câmera (giro só em Y) e inclinado como a luz do canto da tela
			var to := cam.global_position - mi.global_position
			var yaw := atan2(to.x, to.z)
			mi.global_rotation = Vector3(0, yaw, 0)
			mi.rotate_object_local(Vector3.FORWARD, 0.4)


func _build_ground() -> void:
	_ground = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	var gm := 1.0 if energy else MARGIN  # energy: the court only, the stands read the globals
	pm.size = (_half + Vector2(gm, gm)) * 2.0
	pm.subdivide_width = 0
	_ground.mesh = pm
	_ground_mat = ShaderMaterial.new()
	_ground_mat.shader = load("res://gfx/shaders/weather_ground.gdshader")
	_ground.material_override = _ground_mat
	_ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ground.position = _center + Vector3(0, 0.06, 0)
	_ground.visible = false
	add_child(_ground)


func _build_screen() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 1  # por cima do 3D, por baixo do HUD (5)
	add_child(_layer)
	_screen = _full_rect("res://gfx/shaders/weather_screen.gdshader")
	_glow = _full_rect("res://gfx/shaders/weather_glow.gdshader")
	_label = Label.new()
	_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_label.offset_top = 6.0
	_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_constant_override("outline_size", 6)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_label.modulate.a = 0.0
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_label)


func _full_rect(shader: String) -> ColorRect:
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = load(shader)
	r.material = m
	r.visible = false
	_layer.add_child(r)
	return r


# --- Energy mode ---


func _build_energy() -> void:
	var c := global_transform * _center if is_inside_tree() else _center
	var area := _half + Vector2(STANDS_MARGIN, STANDS_MARGIN)
	var opts := {
		"name": "WeatherRig",
		"follow": false,
		"mist": false,
		"resolution": ENERGY_FIELD_RES,
	}
	if _world == null and is_inside_tree():
		light_owner = get_tree().get_first_node_in_group(LIGHT_GROUP)
	if light_owner and light_owner.has_method("weather_area"):
		# The stadium's whole bowl: rain and snow over the field and every stand, to the parapet.
		var bowl: Rect2 = light_owner.weather_area()
		area = bowl.size * 0.5
		c = Vector3(bowl.get_center().x, c.y, bowl.get_center().y)
		opts.merge(BOWL)
	opts.area = area
	opts.center = c
	rig = WeatherRig.make(opts)
	add_child(rig)
	bolts = WeatherLightning.new()
	bolts.name = "Lightning"
	bolts.driven = true
	bolts.gap = LIGHTNING_GAP
	bolts.focus = c
	bolts.ground_y = c.y
	var reach := maxf(area.x, area.y)
	bolts.near_range = Vector2(reach + 4.0, reach + 22.0)  # seen bolts land past the stands
	bolts.far_range = Vector2(reach + 30.0, reach + 120.0)
	bolts.in_view_chance = 0.35
	add_child(bolts)
	bolts.thunder.connect(_on_thunder)
	audio = WeatherAudio.new()
	audio.name = "WeatherAudio"
	add_child(audio)
	add_to_group(GfxQuality.GROUP)


## Graphics tier changed: the rig follows the new particle budget.
func apply_quality() -> void:
	if rig:
		rig.set_budget(GfxQuality.particles())


func _update_energy(dt: float, rain: float, snow: float) -> void:
	_t += dt
	var gust := 0.5 + 0.5 * sin(_t * 0.73) * sin(_t * 1.31 + 1.0)
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	rig.rain = rain * 0.85
	rig.snow = snow
	rig.wind = (
		Vector2(1.0, 0.35).normalized() * (0.6 + 2.4 * rain + 0.8 * snow) * (0.7 + 0.6 * gust)
	)
	rig.update(rig.center, cam, dt)
	bolts.storm = smoothstep(0.6, 1.0, rain)
	if cam:
		bolts.view_dir = -cam.global_transform.basis.z
	bolts.tick(dt)
	flash = bolts.flash
	audio.rain = rain
	audio.wind = 0.35 * rain + 0.25 * snow
	audio.gust = gust
	if _world == null:
		_drive_training(rain, snow)


func _on_thunder(distance: float, power: float) -> void:
	if audio:
		audio.thunder(distance, power)


## Training: the court and stands get wet or white through the globals; the light owner (the
## stadium) dims its sun and lifts its ambient for the clouds and the lightning.
func _drive_training(rain: float, snow: float) -> void:
	var dry := 1.0 - 0.85 * snow_pile
	var cloud := maxf(rain * 0.9, snow * 0.75)
	_set_global("rain_amount", rain)
	_set_global("rain_wet", wet_ground * dry)
	_set_global("rain_puddle", smoothstep(0.5, 1.0, wet_ground) * 0.6 * (1.0 - snow_pile))
	_set_global("snow_cover", snow_pile * WORLD_SNOW_MAX)
	_set_global("cloud_cover", cloud)
	_set_global("lightning_flash", flash)
	if is_instance_valid(light_owner):
		light_owner.weather_light(cloud, flash)


func _set_global(n: String, v: float) -> void:
	if is_equal_approx(float(published.get(n, -1.0)), v):
		return
	published[n] = v
	RenderingServer.global_shader_parameter_set(n, v)


## The fight is over: the weather globals back to the project defaults, the stadium's light clear.
func _restore_training() -> void:
	for g in published:
		var v = global_default(g)
		RenderingServer.global_shader_parameter_set(g, v if v != null else 0.0)
	published.clear()
	if is_instance_valid(light_owner):
		light_owner.weather_light(0.0, 0.0)
	light_owner = null


# --- Texturas procedurais ---


static func _curve_tex(pts: Array) -> CurveTexture:
	return WeatherKit.curve_tex(pts)


static func _color_ramp(a: Color, b: Color) -> GradientTexture1D:
	return WeatherKit.color_ramp(a, b)


## Gota/grão: claro no meio do comprimento, some nas pontas (vertical, ou horizontal com `wide`).
static func _gradient_tex(wide := false) -> ImageTexture:
	return WeatherKit.gradient_tex(wide)


## Ponto macio (floco, poeira); `core` > 0 deixa o miolo mais duro.
static func _dot_tex(core := 0.35) -> ImageTexture:
	return WeatherKit.dot_tex(core)


## Floco: miolo branco com uma borda azul-acinzentada, para aparecer até por cima da neve.
static func _flake_tex() -> ImageTexture:
	return WeatherKit.flake_tex()


static func _ring_tex() -> ImageTexture:
	return WeatherKit.ring_tex(24, Vector2(0.5, 0.72), Vector2(0.86, 1.02))

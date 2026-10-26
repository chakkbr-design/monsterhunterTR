extends SceneTree
## Headless: godot --headless --fixed-fps 60 --path . --script res://tests/world/test_sky.gd
## Continuous time of day (world/sky/): the sun and moon arcs, colour keys without jumps around
## the clock, the shader globals, one persistent Environment across zones and rooms, the old API
## (clock label, periods, forced_period, night_mult, refresh, groups), the NightLights shadow
## budget, the graphics tiers (and old saves with quality 0..1) and the F9 sky panel.

var _fails := 0


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	print(("ok   " if cond else "FAIL ") + what)
	if not cond:
		_fails += 1


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	_cycle()
	_continuity()
	await _world()
	await _tiers()
	_settings()
	print("[sky] %d failed" % _fails)
	quit(1 if _fails > 0 else 0)


static func _m(hm: String) -> float:
	return SkyCycle.parse_hm(hm)


func _cycle() -> void:
	var c := SkyCycle.shared()
	check(absf(c.sun_angles(_m("06:00")).x) < 0.5, "sunrise at 06:00 (%.2f°)" % c.sun_angles(360).x)
	check(absf(c.sun_angles(_m("18:30")).x) < 0.5, "sunset at 18:30")
	var noon := c.sun_angles(_m("12:15"))
	check(
		noon.x > 45.0 and noon.x <= 62.0,
		"noon sun high, still casting readable shadows (%.1f°)" % noon.x
	)
	check(c.sun_angles(_m("00:15")).x < -30.0, "sun well below at midnight")
	var az7 := c.sun_angles(_m("07:00")).y
	var az18 := c.sun_angles(_m("17:45")).y
	check(az7 > 95.0 and az7 < 140.0, "morning sun in the east-south-east (%.0f°)" % az7)
	check(
		noon.y > 170.0 and noon.y < 215.0,
		"noon sun behind the north-facing camera (%.0f°)" % noon.y
	)
	check(az18 > 225.0 and az18 < 262.0, "evening sun in the west-south-west (%.0f°)" % az18)
	check(
		c.sun_visibility(_m("05:00")) == 0.0 and c.sun_visibility(_m("20:00")) == 0.0,
		"no sun at night"
	)
	check(c.sun_visibility(_m("12:00")) == 1.0, "full sun at noon")
	check(c.moon_visibility(_m("00:30")) > 0.5, "moon up after midnight")
	check(c.moon_visibility(_m("12:00")) == 0.0, "no moon at noon")
	var overlap := 0.0
	for m in 1440:
		overlap = maxf(overlap, minf(c.sun_visibility(m), c.moon_visibility(m)))
	check(overlap == 0.0, "sun and moon never light the scene together")
	check(SkyCycle.to_dir(90.0, 0.0).is_equal_approx(Vector3.UP), "elevation 90 = straight up")
	check(SkyCycle.to_dir(0.0, 180.0).is_equal_approx(Vector3(0, 0, 1)), "azimuth 180 = south (+Z)")
	var k := c.sample(_m("12:30"))
	check(
		(
			k.sky_weight == 0.0
			and k.ambient_weight == 0.0
			and k.exposure == 1.0
			and k.post_weight == 0.0
		),
		"12:30 is the identity (the zone's own look)"
	)
	check(
		c.sample(_m("22:00")).lamps == 1.0 and c.sample(_m("12:00")).lamps == 0.0,
		"lamps on at night only"
	)
	check(c.sample(_m("21:00")).windows > 0.8, "windows lit in the evening")
	check(
		c.sample(_m("03:00")).windows < c.sample(_m("21:00")).windows, "fewer windows late at night"
	)
	check(c.period_minute("night") == _m("22:30") and c.period_minute("x") < 0.0, "period hours")
	check(SkyCycle.format_hm(_m("05:30")) == "05:30", "format_hm")


## Every key field and both arcs move by small steps minute to minute, midnight included.
func _continuity() -> void:
	var c := SkyCycle.shared()
	var worst := 0.0
	var worst_f := ""
	var prev := c.sample(1439.0)
	for m in 1440:
		var s := c.sample(float(m))
		for f in s:
			var d := 0.0
			if s[f] is Color:
				var a: Color = s[f]
				var b: Color = prev[f]
				d = maxf(maxf(absf(a.r - b.r), absf(a.g - b.g)), absf(a.b - b.b))
			else:
				d = absf(float(s[f]) - float(prev[f]))
			if d > worst:
				worst = d
				worst_f = "%s at %s" % [f, SkyCycle.format_hm(m)]
		prev = s
	check(worst < 0.06, "keys change by < 0.06 per game minute (worst %.3f: %s)" % [worst, worst_f])
	var jump := 0.0
	var pa := c.sun_angles(-1.0)
	var pm := c.moon_angles(-1.0)
	for m in 1440:
		var a := c.sun_angles(float(m))
		var b := c.moon_angles(float(m))
		jump = maxf(jump, maxf(absf(a.x - pa.x), absf(b.x - pm.x)))
		jump = maxf(jump, maxf(absf(angle_difference(deg_to_rad(a.y), deg_to_rad(pa.y))), 0.0))
		pa = a
		pm = b
	check(jump < 0.5, "sun and moon move < 0.5° per game minute (%.3f)" % jump)
	check(c.sample(0.0).hash() == c.sample(1440.0).hash(), "midnight wraps")


func _world() -> void:
	GfxQuality.forced = GfxQuality.HIGH  # the checks below expect Alto's GI, whatever the saved tier
	var w := Node3D.new()
	w.name = "World"
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = Environment.new()
	w.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	w.add_child(sun)
	var post := WorldPostFx.new()
	post.name = "PostFX"
	w.add_child(post)
	root.add_child(w)
	var game := root.get_node_or_null("Game")
	if game:
		game.flags.erase(WorldTimeOfDay.CLOCK_FLAG)
		game.play_time = 0.0
	var tod := WorldTimeOfDay.new()
	tod.name = "TimeOfDay"
	w.add_child(tod)
	await frames(2)
	check(tod.clock_label() == "SEG 9:00", "clock starts MON 9:00 (%s)" % tod.clock_label())
	check(tod.get_node_or_null("Moon") is DirectionalLight3D, "moon light made")
	var env := we.environment
	check(env != null and env == tod.env, "TimeOfDay owns one live Environment")
	check(env.sky != null and env.sky.sky_material is ShaderMaterial, "custom sky shader")
	# Persistent environment across looks and rooms.
	tod.apply_location({}, false)
	check(we.environment == env, "same Environment after an HGSS zone")
	check(env.tonemap_mode == Environment.TONE_MAPPER_FILMIC, "HGSS look keeps its Filmic tonemap")
	tod.set_minute(_m("12:30"))
	check(
		(
			float((env.sky.sky_material as ShaderMaterial).get_shader_parameter("ambient_neutral"))
			== 0.0
		),
		"HGSS look at 12:30 keeps its sky light as authored"
	)
	tod.apply_location({"env": "voxel_env.tres"}, false)
	check(we.environment == env, "same Environment after the voxel look")
	check(env.tonemap_mode == Environment.TONE_MAPPER_AGX, "voxel look: AgX")
	check(env.sdfgi_min_cell_size == 0.25, "SDFGI cells match the 0.25 m voxels")
	check(tod._look_t < 1.0, "two outdoor looks blend")
	await frames(120)
	check(tod._look_t >= 1.0, "blend done")
	check(env.sdfgi_enabled and env.sdfgi_energy > 0.9, "voxel look: GI on (Alto)")
	# Crossing into an HGSS zone and back: the bounce light fades instead of popping.
	tod.apply_location({}, false)
	check(env.sdfgi_enabled, "GI keeps running while it fades out")
	await frames(45)
	check(
		env.sdfgi_energy > 0.05 and env.sdfgi_energy < 0.95,
		"GI half way out (%.2f)" % env.sdfgi_energy
	)
	await frames(90)
	check(not env.sdfgi_enabled and env.ssil_enabled, "HGSS zone: no GI, SSIL back")
	tod.apply_location({"env": "voxel_env.tres"}, false)
	check(env.sdfgi_enabled and env.sdfgi_energy < 0.05, "GI fades in from zero")
	await frames(120)
	check(env.sdfgi_energy > 0.9, "GI fully back")
	var sky := env.sky
	tod.apply_location({}, true)
	check(we.environment == env and env.sky == sky, "same Environment and Sky indoors")
	check(env.background_mode == Environment.BG_COLOR, "interior look copied (colour background)")
	check(not env.sdfgi_enabled and not env.volumetric_fog_enabled, "no GI cascades or fog indoors")
	check(tod.state.minute == WorldTimeOfDay.INDOOR_MINUTE, "rooms keep the 12:30 look")
	tod.apply_location({"env": "voxel_env.tres"}, false)
	# Noon.
	tod.set_minute(_m("12:00"))
	var moon := tod.get_node("Moon") as DirectionalLight3D
	check(tod.period == "midday", "period midday at 12:00 (%s)" % tod.period)
	check(tod.state.sun_elevation > 50.0 and sun.light_energy > 1.0, "noon sun up and bright")
	check(sun.shadow_enabled and not moon.shadow_enabled, "only the sun casts shadows by day")
	check(moon.light_energy == 0.0, "no moonlight at noon")
	var fill := tod.get_node("NightFill") as DirectionalLight3D
	check(fill.light_energy == 0.0 and not fill.visible, "no night fill by day")
	check(tod.global_value("night_lamps") == 0.0, "night_lamps 0 at noon")
	var sd: Vector3 = tod.global_value("sun_dir_world")
	check(
		sd != null and sd.y > 0.75 and is_equal_approx(sd.length(), 1.0), "sun_dir_world up at noon"
	)
	check(tod.global_value("sun_amount") > 0.9, "sun_amount 1 at noon")
	check(tod.global_value("sky_top_color") is Color, "sky_top_color written")
	var sm := env.sky.sky_material as ShaderMaterial
	check(
		float(sm.get_shader_parameter("ambient_neutral")) > 0.4,
		"voxel look neutralises the sky light (no blue stone in shadow)"
	)
	var rs = RenderingServer.global_shader_parameter_get("night_lamps")
	check(rs == null or float(rs) == 0.0, "RenderingServer global matches")
	# Night.
	tod.set_minute(_m("22:00"))
	check(tod.period == "night", "period night at 22:00")
	check(sun.light_energy == 0.0 and not sun.shadow_enabled, "no sun at night")
	check(moon.light_energy > 0.05 and moon.shadow_enabled, "moonlight with its own shadow")
	check(tod.global_value("night_lamps") == 1.0, "night_lamps 1 at night")
	check(tod.global_value("night_windows") > 0.8, "night_windows lit")
	check(tod.state.exposure > 1.05, "night exposure lifted so the town stays readable")
	check((tod.global_value("sun_dir_world") as Vector3).y > 0.0, "key light is the moon at night")
	check(tod.night_mult().lamps == 1.0, "night_mult()")
	tod.set_minute(_m("18:50"))
	check(
		fill.visible and fill.light_energy > 0.15 and not fill.shadow_enabled,
		(
			"twilight without the moon: the night fill keeps sprites readable (%.2f)"
			% fill.light_energy
		)
	)
	check(
		fill.global_transform.basis.z.z > 0.3, "the fill shines from behind the north-facing camera"
	)
	tod.set_minute(_m("00:30"))
	check(
		fill.light_energy < 0.12 and moon.light_energy > 0.25,
		"a bright moon takes over from the fill (%.2f)" % fill.light_energy
	)
	# Old API.
	for e in [
		["08:00", "morning"], ["16:00", "afternoon"], ["18:00", "sunset"], ["03:00", "night"]
	]:
		tod.set_minute(_m(e[0]))
		check(tod.period == e[1], "period %s at %s (%s)" % [e[1], e[0], tod.period])
	WorldTimeOfDay.forced_period = "night"
	tod.refresh()
	await frames(2)
	check(tod.period == "night" and tod.state.minute == _m("22:30"), "forced_period shows its hour")
	WorldTimeOfDay.forced_period = ""
	WorldTimeOfDay.forced_minutes = _m("05:30")
	await frames(2)
	check(tod.clock_label().ends_with("5:30") and tod.state.minute == _m("05:30"), "pinned hour")
	WorldTimeOfDay.forced_minutes = -1.0
	# Light energies never jump around the clock (2-minute steps).
	var pe := -1.0
	var pexp := -1.0
	var worst := 0.0
	var worst_x := 0.0
	for m in range(0, 1442, 2):
		tod.set_minute(float(m))
		var e := sun.light_energy + moon.light_energy
		if pe >= 0.0:
			worst = maxf(worst, absf(e - pe))
			worst_x = maxf(worst_x, absf(float(tod.state.exposure) - pexp))
		pe = e
		pexp = float(tod.state.exposure)
	check(worst < 0.4, "sun + moon energy step < 0.4 per 2 min (%.3f)" % worst)
	# The key light colour the water reads slides from the sun's to the moon's (no jump at dusk).
	tod.set_minute(_m("17:00"))
	var pc: Color = tod.global_value("sun_color_world")
	var worst_c := 0.0
	for m in range(_m("17:00"), _m("21:00"), 1):
		tod.set_minute(float(m))
		var c: Color = tod.global_value("sun_color_world")
		worst_c = maxf(worst_c, maxf(absf(c.r - pc.r), maxf(absf(c.g - pc.g), absf(c.b - pc.b))))
		pc = c
	check(worst_c < 0.08, "sun_color_world step < 0.08 per minute at dusk (%.3f)" % worst_c)
	check(worst_x < 0.05, "exposure step < 0.05 per 2 min (%.3f)" % worst_x)
	await _lamps(tod, w)
	await _panel(tod)
	w.queue_free()
	await frames(2)
	GfxQuality.forced = -1


func _lamps(tod: WorldTimeOfDay, w: Node3D) -> void:
	var lamps: Array = []
	for i in 8:
		var l := OmniLight3D.new()
		l.light_energy = 6.0
		l.position = Vector3(i * 2.0, 2.5, 0.0)
		w.add_child(l)
		var nl := NightLights.new()
		nl.light = l
		w.add_child(nl)
		lamps.append(nl)
	var wm := StandardMaterial3D.new()
	var nw := NightLights.new()
	nw.window_mats = [wm]
	w.add_child(nw)
	tod.set_minute(_m("12:00"))
	check(
		not lamps[0].light.visible and wm.emission_energy_multiplier == 0.0,
		"lamps and windows off by day"
	)
	tod.set_minute(_m("22:00"))
	var e: float = lamps[0].light.light_energy
	check(
		lamps[0].light.visible and e > 5.5 and e < 6.5,
		"lamp on at night, gentle flicker (%.2f)" % e
	)
	check(wm.emission_energy_multiplier > 0.8, "window glow at night")
	check(lamps[0].light.distance_fade_enabled, "lamps fade with distance")
	for i in 3:
		NightLights.update_budget(Vector3.ZERO, 4, 0.5)
	NightLights.update_budget(Vector3.ZERO, 4, 2.0)
	check(NightLights.shadowed_count() == 4, "4 lamp shadows (%d)" % NightLights.shadowed_count())
	check(
		(
			lamps[0].light.shadow_enabled
			and lamps[3].light.shadow_enabled
			and not lamps[6].light.shadow_enabled
		),
		"the nearest lamps cast them"
	)
	NightLights.update_budget(Vector3(14, 0, 0), 4, 0.4)
	check(
		lamps[0].light.shadow_enabled and lamps[0].light.shadow_opacity < 1.0,
		"a lamp leaving the budget fades its shadow (%.2f)" % lamps[0].light.shadow_opacity
	)
	NightLights.update_budget(Vector3(14, 0, 0), 4, 2.0)
	check(
		not lamps[0].light.shadow_enabled and lamps[7].light.shadow_enabled,
		"the budget follows the focus"
	)
	tod.set_minute(_m("12:00"))
	NightLights.update_budget(Vector3(14, 0, 0), 4, 0.4)
	NightLights.update_budget(Vector3(14, 0, 0), 4, 2.0)
	check(NightLights.shadowed_count() == 0, "no lamp shadows by day")
	for n in lamps + [nw]:
		if n.light:
			n.light.queue_free()
		n.queue_free()
	await frames(2)
	check(NightLights.lamps_all.is_empty(), "freed lamps leave the budget")


func _panel(tod: WorldTimeOfDay) -> void:
	var p := SkyDebugPanel.new()
	root.add_child(p)
	await frames(1)
	check(not p.visible, "sky panel hidden by default")
	var ev := InputEventKey.new()
	ev.keycode = KEY_F9
	ev.physical_keycode = KEY_F9
	ev.pressed = true
	Input.parse_input_event(ev)
	await frames(2)
	check(p.visible, "F9 opens the sky panel")
	var keyboard := 0
	for c in p.find_children("*", "Control", true, false):
		if (c is BaseButton or c is Range) and c.focus_mode != Control.FOCUS_NONE:
			keyboard += 1
	check(keyboard == 0, "panel controls never take keyboard focus")
	p._on_hour(_m("19:15"))
	check(absf(tod.minutes - _m("19:15")) < 0.01, "hour slider moves the clock")
	check(
		(
			is_equal_approx(SkyDebugPanel.slider_to_speed(0.0), 0.5)
			and is_equal_approx(SkyDebugPanel.slider_to_speed(1.0), 120.0)
		),
		"speed 0,5 to 120 game min/s"
	)
	p._on_speed(1.0)
	check(is_equal_approx(tod.speed(), 120.0), "speed slider sets the clock speed")
	p._on_normal_speed()
	check(is_equal_approx(tod.speed(), 20.0 / 60.0), "normal speed = time.json")
	p._on_weather(2)
	check(WorldWeather.forced == "rain", "weather picker forces rain")
	p._on_weather(0)
	check(WorldWeather.forced == "", "weather back to automatic")
	p.queue_free()
	await frames(1)


func _tiers() -> void:
	check(GfxQuality.parse("ultra") == 3 and GfxQuality.parse("Médio") == 1, "tier names parse")
	check(GfxQuality.parse("medio") == 1 and GfxQuality.parse("0") == 0, "tier numbers parse")
	var e := Environment.new()
	e.ssao_enabled = true
	e.ssil_enabled = true
	e.sdfgi_enabled = true
	e.ssr_enabled = true
	e.volumetric_fog_enabled = true
	GfxQuality.apply_env(e, GfxQuality.LOW)
	check(
		not e.sdfgi_enabled and not e.ssr_enabled and not e.volumetric_fog_enabled,
		"Baixo: no GI, SSR, fog"
	)
	GfxQuality.apply_env(e, GfxQuality.MEDIUM)
	check(not e.sdfgi_enabled and e.ssil_enabled, "Médio: SSIL instead of SDFGI")
	GfxQuality.apply_env(e, GfxQuality.HIGH)
	check(e.sdfgi_enabled and not e.ssil_enabled and e.ssr_enabled, "Alto: SDFGI (no SSIL) and SSR")
	GfxQuality.apply_env(e, GfxQuality.HIGH, {"sdfgi": false})
	check(not e.sdfgi_enabled and e.ssil_enabled, "a look without GI keeps SSIL")
	check(
		(
			GfxQuality.lamp_shadows(GfxQuality.LOW) == 0
			and GfxQuality.lamp_shadows(GfxQuality.ULTRA) >= 4
		),
		"lamp shadow budget per tier"
	)
	check(
		GfxQuality.spec(GfxQuality.ULTRA).scale_mode == Viewport.SCALING_3D_MODE_FSR2,
		"Ultra uses FSR 2.2"
	)
	var msaa := 0
	for t in GfxQuality.NAMES.size():
		msaa += int(GfxQuality.spec(t).msaa != Viewport.MSAA_DISABLED)
	check(msaa == 0, "no tier uses MSAA (it empties the water's depth and screen reads)")
	check(GfxQuality.spec(GfxQuality.HIGH).screen_aa == Viewport.SCREEN_SPACE_AA_SMAA, "Alto: SMAA")
	var sun := DirectionalLight3D.new()
	GfxQuality.apply_sun(sun, GfxQuality.HIGH)
	check(sun.directional_shadow_max_distance <= 60.0, "sun shadows only as far as the camera sees")
	sun.free()
	# A stage outside the overworld (training) follows the tier through GfxQuality.track.
	var we := WorldEnvironment.new()
	we.environment = Environment.new()
	we.environment.ssr_enabled = true
	we.environment.ssao_enabled = true
	root.add_child(we)
	GfxQuality.forced = GfxQuality.LOW
	GfxQuality.track(we)
	await frames(1)
	check(not we.environment.ssr_enabled and we.environment.ssao_enabled, "tracked stage: Baixo")
	GfxQuality.forced = GfxQuality.HIGH
	call_group(GfxQuality.GROUP, "apply_quality")
	check(we.environment.ssr_enabled, "tracked stage: back to Alto when the tier changes")
	GfxQuality.forced = -1
	we.queue_free()
	await frames(1)


func _settings() -> void:
	var S = load("res://ui/front/settings.gd")
	var p := "user://test_sky_settings.cfg"
	var cf := ConfigFile.new()
	cf.set_value("options", "quality", 0)
	cf.save(p)
	check(int(S.load_cfg(p).quality) == 0, "old save quality 0 = Baixo")
	cf.set_value("options", "quality", 1)
	cf.save(p)
	check(int(S.load_cfg(p).quality) == 2, "old save quality 1 = Alto")
	check(int(S.DEFAULTS.quality) == 2 and S.QUALITY_NAMES.size() == 4, "default Alto of 4 tiers")
	S.save_cfg({"quality": 3}, p)
	var back: Dictionary = S.load_cfg(p)
	cf = ConfigFile.new()
	cf.load(p)
	check(int(back.quality) == 3, "Ultra saved and loaded")
	check(int(cf.get_value("options", "quality", -1)) == 1, "old readers still find quality 1")
	var d := {"quality": 3}
	S.change(d, "quality", 1)
	check(int(d.quality) == 0, "quality choice wraps over 4 tiers")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

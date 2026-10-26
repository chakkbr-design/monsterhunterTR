extends SceneTree
## Headless: godot --headless --fixed-fps 60 --path . --script res://tests/world/test_weather_world.gd
## World weather (world/sky/weather.gd, weather_schedule.gd, gfx/weather/): the day's schedule is
## the same for the same day and covers it, every type shows up at any hour (mist only in the
## morning), spells blend without jumps (also across midnight), the ground wets and dries, puddles
## outlast the wet, snow settles and melts (wetting the ground), the node's shader globals and the
## HGSS weather texel, indoors reads dry while the outside keeps its state, the storm couples to
## the wind, the sky (TimeOfDay) and the lightning (flash, thunder), the F9 panel's list and the
## ground-mist switch.

const SETTINGS_TEST := "user://test_weather_settings.cfg"

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
	_schedule()
	_continuity()
	_physics()
	await _node()
	print("[weather_world] %d failed" % _fails)
	quit(1 if _fails > 0 else 0)


func _schedule() -> void:
	var a := WeatherSchedule.new()
	var b := WeatherSchedule.new()
	var same := true
	var differ := 0
	var seen := {}
	var rain_hours: Array = []
	var gaps_ok := true
	var mist_ok := true
	var repeats := 0
	for d in 80:
		var sa := a.segments(d)
		var sb := b.segments(d)
		if JSON.stringify(sa) != JSON.stringify(sb):
			same = false
		if d > 0 and JSON.stringify(sa) != JSON.stringify(a.segments(d - 1)):
			differ += 1
		var t := 0.0
		var last := ""
		for s in sa:
			seen[s.type] = true
			if absf(float(s.start) - t) > 0.001 or float(s.end) <= float(s.start):
				gaps_ok = false
			t = float(s.end)
			if s.type == last:
				repeats += 1
			last = s.type
			if s.type in ["rain", "storm", "snow"]:
				rain_hours.append(float(s.start) / 60.0)
			if s.type == "mist" and (float(s.start) < 240.0 or float(s.end) > 540.0):
				mist_ok = false
		if absf(t - 1440.0) > 0.001:
			gaps_ok = false
	# A fresh schedule that sees the days in another order (cache) gives the same weather.
	var c := WeatherSchedule.new()
	c.segments(41)
	c.segments(3)
	check(
		JSON.stringify(c.segments(42)) == JSON.stringify(a.segments(42)),
		"a day's weather never depends on the cache"
	)
	check(same, "the same game day always has the same weather")
	check(differ > 60, "days differ from each other (%d of 79)" % differ)
	check(gaps_ok, "spells cover each day from 00:00 to 24:00 without gaps")
	check(repeats == 0, "a spell never repeats the type before it")
	check(mist_ok, "mist spells stay inside the morning window")
	for id in ["clear", "cloudy", "overcast", "rain", "storm", "snow", "mist"]:
		check(seen.has(id), "type '%s' happens within 80 days" % id)
	rain_hours.sort()
	check(
		not rain_hours.is_empty() and rain_hours[0] < 5.0 and rain_hours[-1] > 19.0,
		(
			"rain, storms and snow can start at any hour (%.1f h .. %.1f h)"
			% [rain_hours[0], rain_hours[-1]]
		)
	)
	var names := a.names()
	check(names.size() == 7 and names[0][1] == "Limpo", "seven types with Portuguese names")
	var f := a.target(3 * 1440.0 + 600.0, "storm")
	check(
		f.type == "storm" and f.rain == 1.0 and f.storm == 1.0, "a forced type wins over the plan"
	)
	check((f.lightning as Array).size() == 2, "storms carry their lightning gap")


func _continuity() -> void:
	var s := WeatherSchedule.new()
	var worst := 0.0
	var prev := s.target(5 * 1440.0)
	for m in range(1, 1440 * 3):
		var t := s.target(5 * 1440.0 + m)
		for k in WeatherSchedule.CHANNELS:
			worst = maxf(worst, absf(float(t[k]) - float(prev[k])))
		prev = t
	check(worst < 0.06, "spells blend without jumps, across midnight too (max %.3f/min)" % worst)


func _physics() -> void:
	var s := WeatherSchedule.new()
	var st := WeatherSchedule.empty_state()
	var rain := s.channels_of("rain")
	var clear := s.channels_of("clear")
	for i in 30:
		s.step(st, rain, 1.0)
	check(st.wet > 0.95, "ground soaked after half an hour of rain (%.2f)" % st.wet)
	check(st.puddle_level > 0.2, "puddles filling (%.2f)" % st.puddle_level)
	for i in 30:
		s.step(st, rain, 1.0)
	var pud := float(st.puddle_level)
	var dry_min := float(s.cfg.dry_hours) * 60.0
	for i in int(dry_min * 0.5):
		s.step(st, clear, 1.0)
	check(st.wet > 0.2 and st.wet < 0.8, "half way through drying (%.2f)" % st.wet)
	for i in int(dry_min * 0.6) + 15:  # (+ the rain easing off for a few minutes)
		s.step(st, clear, 1.0)
	check(st.wet == 0.0, "dry after dry_hours")
	check(
		st.puddle_level > 0.0 and st.puddle_level < pud,
		"puddles outlast the wet (%.2f)" % st.puddle_level
	)
	var sunny := WeatherSchedule.empty_state()
	var shade := WeatherSchedule.empty_state()
	sunny.wet = 1.0
	shade.wet = 1.0
	for i in 30:
		s.step(sunny, clear, 1.0, 1.0)
		s.step(shade, clear, 1.0, 0.0)
	check(sunny.wet < shade.wet, "the sun dries faster")
	var sn := WeatherSchedule.empty_state()
	var snow := s.channels_of("snow")
	for i in 70:
		s.step(sn, snow, 1.0)
	check(sn.snow_cover > 0.9, "snow settles (%.2f)" % sn.snow_cover)
	var melt := sn.duplicate()
	var melt_rain := sn.duplicate()
	var melt_min := float(s.cfg.snow_melt_hours) * 60.0
	for i in int(melt_min * 0.4):
		s.step(melt, clear, 1.0)
		s.step(melt_rain, rain, 1.0)
	check(melt.snow_cover > 0.2 and melt.snow_cover < 0.9, "snow melting (%.2f)" % melt.snow_cover)
	check(melt.wet > 0.1, "melting snow wets the ground (%.2f)" % melt.wet)
	check(melt_rain.snow_cover < melt.snow_cover, "rain melts snow faster")
	for i in int(melt_min * 0.8):
		s.step(melt, clear, 1.0)
	check(melt.snow_cover == 0.0, "snow gone after snow_melt_hours")
	var settled := s.settled(2 * 1440.0 + 600.0, "rain")
	check(settled.wet > 0.95 and settled.puddle_level > 0.3, "settled rain: wet ground and puddles")
	var after := WeatherSchedule.empty_state()
	after.wet = 0.8
	check(s.mist_of(after) > 0.2, "mist rises after the rain")
	after.rain = 0.6
	check(s.mist_of(after) < 0.01, "no ground mist while it pours")
	check(s.morning(6.5 * 60.0) > 0.9 and s.morning(14.0 * 60.0) == 0.0, "mist only in the morning")


func _node() -> void:
	GfxQuality.forced = GfxQuality.HIGH
	WorldWeather.forced = "rain"
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
	var wind := WorldWind.new()
	wind.name = "Wind"
	w.add_child(wind)
	root.add_child(w)
	var tod := WorldTimeOfDay.new()
	tod.name = "TimeOfDay"
	w.add_child(tod)
	var wx := WorldWeather.new()
	wx.name = "Weather"
	w.add_child(wx)
	tod.apply_location({"env": "voxel_env.tres"}, false)
	tod.set_minute(12.0 * 60.0)
	wx.snap()
	await frames(3)
	check(wx.type == "rain" and wx.wet > 0.9, "forced rain (%s, %.2f)" % [wx.type, wx.wet])
	check(
		wx.published("rain_amount") > 0.5,
		"rain_amount published (%.2f)" % wx.published("rain_amount")
	)
	check(wx.published("rain_wet") > 0.9, "rain_wet global set (%.2f)" % wx.published("rain_wet"))
	check(wx.published("rain_puddle") > 0.3, "puddles published")
	check(
		wx.published("cloud_cover") > 0.8, "rain clouds over (%.2f)" % wx.published("cloud_cover")
	)
	var tex := WorldFx.weather_image.get_pixel(0, 0)
	check(tex.r > 0.7 and tex.a > 0.8, "HGSS weather texel wet and cloudy (%s)" % tex)
	check(wx.rig.rain_p.emitting and wx.rig.rain_p.amount_ratio > 0.5, "rain particles falling")
	check(wx.rig.rain_p.sub_emitter != NodePath(""), "drops leave splashes where they land")
	check(wx.rig.field != null, "rain collision heightfield")
	check(
		wx.rig.field.heightfield_mask & WeatherKit.LAYER == 0,
		"the heightfield never captures the weather layer itself"
	)
	check(tod.state.cloud > 0.8 and tod.state.sun_energy < 0.8, "clouds dim the sun")
	var cover: Dictionary = wx.camera_cover()
	check(cover.wet > 0.9, "camera cover: rain (pollen and fireflies hide)")
	# Indoors: dry globals, the state outside is kept, the rain muffled.
	tod.apply_location({}, true)
	await frames(2)
	check(wx.indoor and wx.published("rain_amount") == 0.0, "no rain indoors")
	check(
		wx.published("rain_wet") == 0.0 and wx.published("cloud_cover") == 0.0, "interiors read dry"
	)
	check(not wx.rig.visible and not wx.rig.rain_p.emitting, "no particles indoors")
	check(wx.state.wet > 0.9, "the street stays wet outside")
	check(wx.audio.indoor, "rain heard through the roof")
	tod.apply_location({"env": "voxel_env.tres"}, false)
	await frames(2)
	check(wx.published("rain_wet") > 0.9, "wet again outside")
	# Snow through the F9 fade: settles, hides the wet, flakes fall.
	WorldWeather.forced = "snow"
	await frames(int(WorldWeather.FORCE_FADE * 60.0) + 10)
	check(wx.type == "snow", "panel: snow")
	check(wx.published("snow_cover") > 0.8, "snow lying (%.2f)" % wx.published("snow_cover"))
	check(
		absf(wx.snow_cover() - wx.published("snow_cover")) < 0.01,
		"snow_cover() reads what the global says (%.3f)" % wx.snow_cover()
	)
	check(wx.published("rain_wet") < 0.3, "snow hides the wet ground")
	check(wx.rig.snow_p.emitting and not wx.rig.rain_p.emitting, "flakes instead of drops")
	check(WorldFx.weather_image.get_pixel(0, 0).g > 0.8, "HGSS texel snowy")
	tod.apply_location({}, true)
	await frames(2)
	check(wx.snow_cover() == 0.0 and wx.published("snow_cover") == 0.0, "no snow indoors")
	tod.apply_location({"env": "voxel_env.tres"}, false)
	await frames(2)
	# Storm: wind, gloom, lightning with thunder.
	WorldWeather.forced = "storm"
	wx.snap()
	await frames(4)
	check(wind.storm > 1.0, "storm wind (%.2f)" % wind.storm)
	check(wx.gloom > 0.5 and tod.state.gloom > 0.5, "storm darkness reaches the sky")
	check(wx.lightning.storm > 0.5, "lightning armed in the storm")
	var amb0: float = tod.state.ambient_energy
	var thunders := wx.audio.thunders
	wx.lightning.strike(wx.lightning.focus + Vector3(0, 0, -40))
	await frames(1)
	check(wx.flash > 0.3, "lightning flash (%.2f)" % wx.flash)
	check(wx.published("lightning_flash") > 0.3, "lightning_flash global")
	check(
		wx.lightning.light.visible and wx.lightning.light.light_energy > 1.0, "a real light flashes"
	)
	check(tod.state.ambient_energy > amb0 * 1.5, "the ambient spikes with the flash")
	check(wx.lightning.bolt.multimesh.instance_count > 40, "a voxel bolt")
	await frames(30)
	check(wx.audio.thunders > thunders, "thunder arrives after the flash (40 m: ~0.12 s)")
	await frames(60)
	check(wx.flash < 0.01 and wx.published("lightning_flash") < 0.01, "flash over")
	# Mist: morning only, switchable.
	WorldWeather.forced = "mist"
	tod.set_minute(6.5 * 60.0)
	wx.snap()
	await frames(2)
	check(wx.mist > 0.5 and wx.rig.mist_sheets[0].visible, "morning mist (%.2f)" % wx.mist)
	WorldWeather.set_mist_option(false, SETTINGS_TEST)
	await frames(2)
	check(wx.mist == 0.0 and not wx.rig.mist_sheets[0].visible, "ground mist switched off")
	WorldWeather.set_mist_option(true, SETTINGS_TEST)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_TEST))
	# Battle weather merges on top of a clear day.
	WorldWeather.forced = "clear"
	wx.snap()
	wx.battle_cover = Color(1.0, 0.0, 0.0, 0.7)
	await frames(2)
	check(
		wx.published("rain_wet") > 0.9 and wx.published("cloud_cover") > 0.6,
		"battle rain wets the map"
	)
	wx.battle_cover = Color(0.0, 1.0, 0.0, 0.7)
	await frames(2)
	check(wx.snow_cover() > 0.9, "battle snow lies on the map (snow_cover())")
	wx.battle_cover = Color(0, 0, 0, 0)
	await frames(2)
	check(wx.published("rain_wet") < 0.05, "and dries back when the battle ends")
	check(wx.snow_cover() == 0.0, "and the battle snow goes with it")
	# F9 panel list.
	var choices := wx.debug_choices()
	check(
		choices.size() == 8 and choices[0][0] == "" and choices[4][0] == "rain",
		"panel lists automatic + 7 types"
	)
	var p := SkyDebugPanel.new()
	root.add_child(p)
	await frames(1)
	p._sync_all()
	p._on_weather(5)
	check(WorldWeather.forced == "storm", "panel picks the storm")
	p._process(1.0)
	check(
		p._weather_text().begins_with("Tempestade") or wx.type != "storm",
		"panel readout names the weather"
	)
	# Automatic again: follows the schedule.
	p._on_weather(0)
	await frames(int(WorldWeather.FORCE_FADE * 60.0) + 5)
	var want := wx.schedule.target(wx._now())
	check(
		absf(wx.cloud - float(want.cloud)) < 0.2,
		"automatic follows the plan (cloud %.2f vs %.2f)" % [wx.cloud, want.cloud]
	)
	p.queue_free()
	w.queue_free()
	WorldWeather.forced = ""
	await frames(2)

class_name SkyDebugPanel
extends CanvasLayer
## F9 in the overworld: a small panel to test the sky at any hour and weather (hidden by default).
##   - hour slider (moves the game clock, or the pinned hour of --hour=);
##   - clock speed from 0,5 to 120 game minutes per real second, "Normal" (data/time.json) and
##     pause;
##   - weather (WorldWeather.forced; the weather lists its own choices with debug_choices(): every
##     type of data/weather.json), a lightning strike button and the ground-mist switch (saved);
##   - graphics tier for this session only (the saved option stays in Opções);
##   - a readout of the sun, moon, exposure, lamps, windows and lamp shadows.
## It never takes keyboard focus (every control is FOCUS_NONE, mouse only) and only F9 is
## consumed, so walking and menus keep working while it is open.

const TOGGLE_KEY := KEY_F9
const SPEED_MIN := 0.5
const SPEED_MAX := 120.0
const FALLBACK_WEATHER := [["", "Auto"], ["clear", "Clear"], ["rain", "Rain"]]

var _panel: PanelContainer
var _hour: HSlider
var _hour_label: Label
var _speed: HSlider
var _speed_label: Label
var _pause: CheckBox
var _weather: OptionButton
var _weather_ids: Array = []
var _mist: CheckBox
var _weather_info: Label
var _tier: OptionButton
var _info: Label
var _info_t := 0.0


func _ready() -> void:
	layer = 95
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if (
		k
		and k.pressed
		and not k.echo
		and (k.keycode == TOGGLE_KEY or k.physical_keycode == TOGGLE_KEY)
	):
		visible = not visible
		if visible:
			_sync_all()
		get_viewport().set_input_as_handled()


func _tod() -> WorldTimeOfDay:
	return get_tree().get_first_node_in_group(WorldTimeOfDay.GROUP) as WorldTimeOfDay


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.position = Vector2(16, 120)
	_panel.custom_minimum_size = Vector2(380, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.1, 0.86)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(12)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_panel.add_child(box)
	var title := Label.new()
	title.text = "Sky and weather (F9)"
	title.add_theme_font_size_override("font_size", 18)
	box.add_child(title)
	_hour_label = _label(box)
	_hour = _slider(box, 0.0, 1439.0, 1.0)
	_hour.value_changed.connect(_on_hour)
	_speed_label = _label(box)
	_speed = _slider(box, 0.0, 1.0, 0.001)
	_speed.value_changed.connect(_on_speed)
	var row := HBoxContainer.new()
	box.add_child(row)
	_pause = CheckBox.new()
	_pause.text = "Pause"
	_pause.focus_mode = Control.FOCUS_NONE
	_pause.toggled.connect(func(on: bool): WorldTimeOfDay.paused = on)
	row.add_child(_pause)
	var normal := Button.new()
	normal.text = "Normal speed"
	normal.focus_mode = Control.FOCUS_NONE
	normal.pressed.connect(_on_normal_speed)
	row.add_child(normal)
	var wl := _label(box)
	wl.text = "Weather"
	_weather = OptionButton.new()
	_weather.focus_mode = Control.FOCUS_NONE
	_weather.item_selected.connect(_on_weather)
	box.add_child(_weather)
	var wrow := HBoxContainer.new()
	box.add_child(wrow)
	_mist = CheckBox.new()
	_mist.text = "Ground mist"
	_mist.focus_mode = Control.FOCUS_NONE
	_mist.toggled.connect(func(on: bool): WorldWeather.set_mist_option(on))
	wrow.add_child(_mist)
	var bolt := Button.new()
	bolt.text = "Lightning"
	bolt.focus_mode = Control.FOCUS_NONE
	bolt.pressed.connect(_on_strike)
	wrow.add_child(bolt)
	_weather_info = _label(box)
	_weather_info.add_theme_font_size_override("font_size", 13)
	_weather_info.add_theme_color_override("font_color", Color(0.78, 0.86, 0.95))
	var tl := _label(box)
	tl.text = "Graphics (this session only)"
	_tier = OptionButton.new()
	_tier.focus_mode = Control.FOCUS_NONE
	for n in GfxQuality.NAMES:
		_tier.add_item(n)
	_tier.item_selected.connect(_on_tier)
	box.add_child(_tier)
	_info = _label(box)
	_info.add_theme_font_size_override("font_size", 13)
	_info.add_theme_color_override("font_color", Color(0.78, 0.82, 0.9))


func _label(parent: Node) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 15)
	parent.add_child(l)
	return l


func _slider(parent: Node, lo: float, hi: float, step: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.focus_mode = Control.FOCUS_NONE
	s.custom_minimum_size = Vector2(340, 20)
	parent.add_child(s)
	return s


## Weather choices: the weather node's own list when it has one, else automatic / clear / rain.
func _weather_choices() -> Array:
	var w := get_tree().get_first_node_in_group("weather")
	if w and w.has_method("debug_choices"):
		return w.debug_choices()
	return FALLBACK_WEATHER


func _sync_all() -> void:
	_weather.clear()
	_weather_ids = []
	for c in _weather_choices():
		_weather_ids.append(String(c[0]))
		_weather.add_item(String(c[1]))
	var i := _weather_ids.find(WorldWeather.forced)
	_weather.select(maxi(i, 0))
	_tier.select(GfxQuality.tier())
	WorldWeather.load_mist_option()
	_mist.set_pressed_no_signal(WorldWeather.mist_enabled)
	_pause.set_pressed_no_signal(WorldTimeOfDay.paused)
	_sync_speed()
	_process(0.0)


static func speed_to_slider(mps: float) -> float:
	return clampf(log(mps / SPEED_MIN) / log(SPEED_MAX / SPEED_MIN), 0.0, 1.0)


static func slider_to_speed(v: float) -> float:
	return SPEED_MIN * pow(SPEED_MAX / SPEED_MIN, clampf(v, 0.0, 1.0))


func _sync_speed() -> void:
	var tod := _tod()
	var mps := tod.speed() if tod else 1.0 / 3.0
	_speed.set_value_no_signal(speed_to_slider(maxf(mps, SPEED_MIN)))
	_speed_label.text = (
		"Speed: %s game min/s%s"
		% [String.num(mps, 2), " (normal)" if WorldTimeOfDay.minutes_per_sec < 0.0 else ""]
	)


func _on_hour(v: float) -> void:
	var tod := _tod()
	if tod:
		tod.set_minute(v)


func _on_speed(v: float) -> void:
	var mps := slider_to_speed(v)
	WorldTimeOfDay.minutes_per_sec = snappedf(mps, 0.05 if mps < 5.0 else 1.0)
	_sync_speed()


func _on_normal_speed() -> void:
	WorldTimeOfDay.minutes_per_sec = -1.0
	_sync_speed()


func _on_weather(i: int) -> void:
	if i >= 0 and i < _weather_ids.size():
		WorldWeather.forced = _weather_ids[i]


## A lightning strike now, in view of the camera (tests the flash, the bolt and the thunder).
func _on_strike() -> void:
	var w := get_tree().get_first_node_in_group("weather")
	var l = w.get("lightning") if w else null
	if l is WeatherLightning:
		var f: Vector3 = l.focus
		var d: Vector3 = l.view_dir
		l.strike(f + Vector3(d.x, 0.0, d.z).normalized() * 11.0)


func _on_tier(i: int) -> void:
	GfxQuality.set_tier(i)
	GfxQuality.apply_all(get_viewport())
	get_tree().call_group(GfxQuality.GROUP, "apply_quality")


func _process(delta: float) -> void:
	if not visible:
		return
	var tod := _tod()
	if tod == null:
		return
	_hour_label.text = "Time: %s  (%s)" % [SkyCycle.format_hm(tod.look_minute()), tod.period]
	_hour.set_value_no_signal(tod.look_minute())
	_info_t -= delta
	if _info_t > 0.0:
		return
	_info_t = 0.25
	var s: Dictionary = tod.state
	if s.is_empty():
		return
	_info.text = (
		(
			"Sun %.0f° az %.0f° · energy %.2f\nMoon %.0f° · energy %.2f · fill %.2f\n"
			+ "Exposure %.2f · ambient %.2f · clouds %.2f\n"
			+ "Lamps %.2f · windows %.2f · lamp shadows %d"
		)
		% [
			s.sun_elevation,
			s.sun_azimuth,
			s.sun_energy,
			s.moon_elevation,
			s.moon_energy,
			s.get("fill_energy", 0.0),
			s.exposure,
			s.ambient_energy,
			s.cloud,
			s.lamps,
			s.windows,
			NightLights.shadowed_count(),
		]
	)
	_weather_info.text = _weather_text()


## "Chuva · chuva 0,62 · chão 0,95 · poças 0,40 · neve 0,00 · nuvens 0,92 · névoa 0,00".
func _weather_text() -> String:
	var w := get_tree().get_first_node_in_group("weather") as WorldWeather
	if w == null or w.state.is_empty():
		return ""
	var names := {}
	for c in w.debug_choices():
		names[c[0]] = c[1]
	var st := w.state
	return (
		(
			"%s · rain %.2f · ground %.2f · puddles %.2f\nsnow %.2f (on ground %.2f) · clouds %.2f"
			+ " · mist %.2f · wind %.2f"
		)
		% [
			String(names.get(w.type, w.type)),
			st.rain,
			st.wet,
			st.puddle_level,
			st.snow,
			st.snow_cover,
			w.cloud,
			w.mist,
			st.wind,
		]
	)

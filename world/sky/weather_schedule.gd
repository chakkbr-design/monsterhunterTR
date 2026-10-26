class_name WeatherSchedule
extends RefCounted
## The world weather's plan and ground physics as pure functions (data/weather.json), so a test can
## check them without a scene:
## - segments(day): the day's spells [{type, start, end}] (minutes of that day, covering 0..1440),
##   seeded by the day number only, so the same game day always has the same weather. A spell
##   never repeats the type before it; a type with a "window" (mist) only starts inside it and its
##   spell ends with the window.
## - target(total): the channels {cloud, rain, snow, puddle, mist, gloom, wind, storm} wanted at a
##   game minute. Two spells blend over transition_minutes centred on their boundary (also across
##   midnight), so the target is continuous.
## - step(state, target, minutes, sun): advances the smoothed state by game minutes: the falling
##   channels ease toward the target; the ground gets wet in the rain and dries after it (faster in
##   sun and wind), puddles fill and dry slower, snow settles while it snows and melts after it
##   (faster in rain and sun; the ground under melting snow is slushy wet and dries after it).
## - settled(total, forced): the state after hours of weather up to `total` (start of a session,
##   a clock jump, a forced type), so the ground is already wet after a morning of rain.

const DATA := "res://data/weather.json"
const CHANNELS := ["cloud", "rain", "snow", "puddle", "mist", "gloom", "wind", "storm"]
const STATE_KEYS := ["wet", "puddle_level", "snow_cover"]
const EASE_MIN := 4.0  ## game minutes the falling channels lag behind the target
const MIN_SPELL := 45.0  ## game minutes: shorter tails are merged into the spell before
const SETTLE_HOURS := 8.0
const SETTLE_STEP := 5.0
const CACHE_DAYS := 6

static var _shared: WeatherSchedule

var cfg: Dictionary = {}
var types: Dictionary = {}  ## id -> type dictionary
var ids: Array = []  ## type ids in file order
var _cache := {}  ## day -> {"segments": Array, "dew": bool}


static func shared() -> WeatherSchedule:
	if _shared == null:
		_shared = WeatherSchedule.new()
	return _shared


func _init(data := {}) -> void:
	if data.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string(DATA))
		data = d if d is Dictionary else {}
	cfg = data
	types = cfg.get("types", {})
	ids = types.keys()
	if not types.has("clear"):
		types["clear"] = {"name": "Clear", "weight": 1.0, "cloud": 0.04}
		ids.push_front("clear")


## [[id, name], ...] in file order (the F9 sky panel's list).
func names() -> Array:
	var out := []
	for id in ids:
		out.append([id, String(types[id].get("name", id))])
	return out


func has_type(id: String) -> bool:
	return types.has(id)


static func hm(s: String) -> float:
	var p := s.split(":")
	return int(p[0]) * 60.0 + (int(p[1]) if p.size() > 1 else 0)


func _hours(key: String, def: float) -> float:
	return float(cfg.get(key, def)) * 60.0


## The day's spells and whether its morning is dewy (light mist on a clear morning).
func day_info(day: int) -> Dictionary:
	if _cache.has(day):
		return _cache[day]
	var rng := RandomNumberGenerator.new()
	rng.seed = day * 7919 + 13
	var seg: Dictionary = cfg.get("segment_hours", {})
	var lo := float(seg.get("min", 1.5)) * 60.0
	var hi := float(seg.get("max", 5.0)) * 60.0
	var out: Array = []
	var t := 0.0
	var last := ""  # days are independent (a day's weather never depends on what was cached)
	while t < 1440.0:
		var id := _pick(rng, t, last)
		var hrs = types[id].get("hours", [lo / 60.0, hi / 60.0])
		var end := t + rng.randf_range(float(hrs[0]), float(hrs[1])) * 60.0
		var win = types[id].get("window")
		if win is Array:
			end = minf(end, hm(String(win[1])))
		end = minf(maxf(end, t + MIN_SPELL), 1440.0)
		if 1440.0 - end < MIN_SPELL:
			end = 1440.0
		out.append({"type": id, "start": t, "end": end})
		t = end
		last = id
	var mist: Dictionary = cfg.get("mist", {})
	var info := {"segments": out, "dew": rng.randf() < float(mist.get("dew_chance", 0.0))}
	if _cache.size() >= CACHE_DAYS:
		_cache.erase(_cache.keys()[0])
	_cache[day] = info
	return info


func segments(day: int) -> Array:
	return day_info(day).segments


func _pick(rng: RandomNumberGenerator, t: float, last: String) -> String:
	if String(cfg.get("mode", "cycle")) == "off":
		return "clear"
	var total := 0.0
	var w := {}
	for id in ids:
		var ty: Dictionary = types[id]
		var k := float(ty.get("weight", 0.0))
		var win = ty.get("window")
		if win is Array and (t < hm(String(win[0])) or t > hm(String(win[1])) - MIN_SPELL):
			k = 0.0
		if id == last:
			k = 0.0
		w[id] = k
		total += k
	if total <= 0.0:
		return "clear"
	var r := rng.randf() * total
	for id in ids:
		r -= float(w[id])
		if r <= 0.0 and float(w[id]) > 0.0:
			return id
	return "clear"


## 0..1 envelope of the morning mist window (rises over an hour, fades over the last 90 minutes).
func morning(m: float) -> float:
	var win: Array = cfg.get("mist", {}).get("morning", ["04:30", "09:30"])
	var a := hm(String(win[0]))
	var b := hm(String(win[1]))
	return smoothstep(a, a + 60.0, m) * (1.0 - smoothstep(b - 90.0, b, m))


## Channels of one type (missing ones are 0). `m` = minute of the day (mist envelope); `dew` adds a
## light morning mist to clear and cloudy spells.
func channels_of(id: String, m := -1.0, dew := false) -> Dictionary:
	var ty: Dictionary = types.get(id, types.clear)
	var c := {}
	for k in CHANNELS:
		c[k] = float(ty.get(k, 0.0))
	c.storm = 1.0 if ty.get("lightning") is Array else 0.0
	if m >= 0.0:
		var env := morning(m)
		c.mist *= env
		if dew and id in ["clear", "cloudy"]:
			c.mist = maxf(c.mist, float(cfg.get("mist", {}).get("dew", 0.0)) * env)
	return c


static func blend(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var c := {}
	for k in a:
		c[k] = lerpf(float(a[k]), float(b.get(k, a[k])), t)
	return c


func _spell(day: int, i: int) -> Dictionary:
	var segs := segments(day)
	if i < 0:
		var p := segments(day - 1)
		var s: Dictionary = p[-1].duplicate()
		s.start -= 1440.0
		s.end -= 1440.0
		s["day"] = day - 1
		return s
	if i >= segs.size():
		var s: Dictionary = segments(day + 1)[0].duplicate()
		s.start += 1440.0
		s.end += 1440.0
		s["day"] = day + 1
		return s
	var s: Dictionary = segs[i].duplicate()
	s["day"] = day
	return s


## Wanted channels at game minute `total` (minutes since the week began) plus "type" (the spell
## that dominates there) and "lightning" ([min, max] s between strikes, or empty).
func target(total: float, forced := "") -> Dictionary:
	var day := floori(total / 1440.0)
	var m := total - day * 1440.0
	if forced != "" and types.has(forced):
		var f := channels_of(forced, -1.0)
		f["type"] = forced
		f["lightning"] = types[forced].get("lightning", [])
		return f
	var segs := segments(day)
	var i := 0
	while i < segs.size() - 1 and m >= float(segs[i].end):
		i += 1
	var cur := _spell(day, i)
	var h := float(cfg.get("transition_minutes", 40.0)) * 0.5
	var dew_c := bool(day_info(day).dew)
	var c := channels_of(String(cur.type), m, dew_c)
	var other := {}
	var w := 0.0
	if m - float(cur.start) < h:
		other = _spell(day, i - 1)
		w = 1.0 - smoothstep(0.0, 1.0, (m - float(cur.start) + h) / (2.0 * h))
	elif float(cur.end) - m < h:
		other = _spell(day, i + 1)
		w = smoothstep(0.0, 1.0, (m - float(cur.end) + h) / (2.0 * h))
	var id := String(cur.type)
	if w > 0.0:
		var od := int(other.day)
		var o := channels_of(String(other.type), m, bool(day_info(od).dew))
		c = blend(c, o, w)
		if w > 0.5:
			id = String(other.type)
	c["type"] = id
	c["lightning"] = types[id].get("lightning", [])
	return c


## Smoothed state with every key at rest (clear sky, dry ground).
static func empty_state() -> Dictionary:
	var s := {}
	for k in CHANNELS:
		s[k] = 0.0
	for k in STATE_KEYS:
		s[k] = 0.0
	return s


## Advances `s` (empty_state() keys) by `dtm` game minutes toward the target `t`. `sun` 0..1 is the
## direct sun on the ground (drying and melting go faster in it).
func step(s: Dictionary, t: Dictionary, dtm: float, sun := 0.0) -> void:
	if dtm <= 0.0:
		return
	var k := 1.0 - exp(-dtm / EASE_MIN)
	for ch in CHANNELS:
		s[ch] = lerpf(float(s[ch]), float(t.get(ch, 0.0)), k)
	var rain := float(s.rain)
	var wind := float(s.wind)
	var wet := float(s.wet)
	if rain > 0.03:
		wet += dtm / _hours("wet_hours", 0.2) * (0.35 + rain)
	else:
		wet -= dtm / _hours("dry_hours", 1.2) * (1.0 + 0.8 * sun + 0.3 * wind)
	var pud := float(s.puddle_level)
	if rain > 0.2 and wet > 0.6:
		# Puddles only fill while it rains (up to the spell's level) and only dry after it.
		pud = move_toward(pud, maxf(pud, float(s.puddle)), dtm / _hours("puddle_hours", 0.5))
	else:
		pud -= dtm / _hours("puddle_dry_hours", 2.0) * (1.0 + 0.6 * sun)
	var cover := float(s.snow_cover)
	var snow := float(s.snow)
	if snow > 0.05:
		cover = move_toward(
			cover, minf(1.0, snow * 1.15), dtm / _hours("snow_accum_hours", 0.75) * (0.3 + snow)
		)
	elif cover > 0.0:
		var melt := dtm / _hours("snow_melt_hours", 2.0) * (1.0 + 2.0 * rain + 1.5 * sun)
		cover -= minf(melt, cover)
		wet = maxf(wet, 0.9 * minf(1.0, cover * 4.0))  # slush: wet under melting snow
	s.wet = clampf(wet, 0.0, 1.0)
	s.puddle_level = clampf(pud, 0.0, 1.0)
	s.snow_cover = clampf(cover, 0.0, 1.0)


## The state at game minute `total` after SETTLE_HOURS of weather (from a dry ground), so a session,
## a clock jump or a forced type starts with the ground the past hours left.
func settled(total: float, forced := "", sun := 0.0) -> Dictionary:
	var s := empty_state()
	var n := int(SETTLE_HOURS * 60.0 / SETTLE_STEP)
	for i in n:
		var at := total - (n - 1 - i) * SETTLE_STEP
		step(s, target(at, forced), SETTLE_STEP, sun)
	return s


## Ground mist (0..1, before the "mist" option) from a state: the spell's own mist, plus a while
## after the rain while the ground is still wet.
func mist_of(s: Dictionary) -> float:
	var after := float(cfg.get("mist", {}).get("after_rain", 0.0))
	var post := (
		after
		* smoothstep(0.15, 0.7, float(s.wet))
		* (1.0 - smoothstep(0.02, 0.15, float(s.rain)))
		* (1.0 - float(s.snow_cover))
	)
	return clampf(maxf(float(s.mist), post), 0.0, 1.0)

class_name SkyCycle
extends RefCounted
## The continuous day of data/time_of_day.json, as pure functions of the game minute (0..1440):
## - sun and moon arcs: elevation / azimuth in degrees (azimuth from north = -Z, clockwise; the
##   overworld camera looks north, so the sun crosses behind it from the east at sunrise to the
##   south-west at sunset and lights the south facades the camera sees). Below the horizon the arc
##   keeps going (negative elevation) so nothing jumps.
## - visibility of each body (0 below fade_low, 1 above fade_high degrees): the sun and the moon
##   are separate lights that never overlap (the moon rises after sunset, sets before sunrise), so
##   switching a light's shadow on or off always happens at zero energy.
## - colour keys: every field interpolated linearly between the two keys around the minute,
##   wrapping at midnight. Colours are lerped in sRGB, which reads smoother for sky gradients.
## WorldTimeOfDay applies a sample; tests and the sky panel read it directly.

const DATA := "res://data/time_of_day.json"
const DAY := 1440.0

static var _shared: SkyCycle

var sun := {}
var moon := {}
var periods := {}  ## period id -> minute
var times := PackedFloat32Array()  ## key minutes, sorted
var fields: Array = []  ## field names present in every key
var values: Array = []  ## values[i][field] (Color or float)


## The cycle of data/time_of_day.json (parsed once).
static func shared() -> SkyCycle:
	if _shared == null:
		_shared = SkyCycle.new()
		var d = JSON.parse_string(FileAccess.get_file_as_string(DATA))
		_shared.setup(d if d is Dictionary else {})
	return _shared


## Minutes of "HH:MM" (or a number of minutes).
static func parse_hm(v) -> float:
	if v is float or v is int:
		return float(v)
	var hm := String(v).split(":")
	if hm.is_empty() or not hm[0].strip_edges().is_valid_int():
		return -1.0
	return int(hm[0]) * 60.0 + (float(hm[1]) if hm.size() > 1 else 0.0)


## "HH:MM" of a minute of the day.
static func format_hm(m: float) -> String:
	var t := fposmod(m, DAY)
	return "%02d:%02d" % [int(t / 60.0), int(t) % 60]


func setup(d: Dictionary) -> void:
	sun = _body(d.get("sun", {}), "06:00", "18:30", 60.0, 100.0, 250.0, 18.0)
	sun.fade_low = float(d.get("sun", {}).get("fade_low", -2.0))
	sun.fade_high = float(d.get("sun", {}).get("fade_high", 6.0))
	var md: Dictionary = d.get("moon", {})
	moon = _body(md, "19:00", "05:30", 50.0, 105.0, 255.0, 12.0)
	moon.fade_low = float(md.get("fade_low", 0.0))
	moon.fade_high = float(md.get("fade_high", 14.0))
	moon.energy = float(md.get("energy", 0.34))
	moon.color = Color(String(md.get("color", "#c4cee6")))
	periods = {}
	var pd: Dictionary = d.get("periods", {})
	for k in pd:
		periods[String(k)] = parse_hm(pd[k])
	var keys: Array = d.get("keys", [])
	keys = keys.filter(func(k): return k is Dictionary and k.has("at"))
	keys.sort_custom(func(a, b): return parse_hm(a.at) < parse_hm(b.at))
	times = PackedFloat32Array()
	values = []
	fields = []
	if keys.is_empty():
		return
	for f in keys[0]:
		if f == "at" or String(f).begins_with("_"):
			continue
		if keys.all(func(k): return k.has(f)):
			fields.append(String(f))
	for k in keys:
		times.append(parse_hm(k.at))
		var v := {}
		for f in fields:
			v[f] = Color(String(k[f])) if k[f] is String else float(k[f])
		values.append(v)


func _body(
	d: Dictionary, rise: String, sets: String, el: float, az_r: float, az_s: float, bulge: float
) -> Dictionary:
	var r := parse_hm(d.get("rise", rise))
	var s := parse_hm(d.get("set", sets))
	return {
		"rise": r,
		"len": fposmod(s - r, DAY) if fposmod(s - r, DAY) > 0.0 else DAY * 0.5,
		"max_elevation": float(d.get("max_elevation", el)),
		"night_depth": float(d.get("night_depth", 40.0)),
		"azimuth_rise": float(d.get("azimuth_rise", az_r)),
		"azimuth_set": float(d.get("azimuth_set", az_s)),
		"azimuth_bulge": float(d.get("azimuth_bulge", bulge)),
	}


## (elevation, azimuth) in degrees of a body at minute m.
static func arc(b: Dictionary, m: float) -> Vector2:
	var t := fposmod(m - float(b.rise), DAY)
	var l := float(b.len)
	if t <= l:
		var s := t / l
		var el := float(b.max_elevation) * sin(PI * s)
		var az := (
			lerpf(float(b.azimuth_rise), float(b.azimuth_set), s)
			+ float(b.azimuth_bulge) * sin(PI * s)
		)
		return Vector2(el, fposmod(az, 360.0))
	var n := (t - l) / (DAY - l)
	var az_n := lerpf(float(b.azimuth_set), float(b.azimuth_rise) + 360.0, n)
	return Vector2(-float(b.night_depth) * sin(PI * n), fposmod(az_n, 360.0))


func sun_angles(m: float) -> Vector2:
	return arc(sun, m)


func moon_angles(m: float) -> Vector2:
	return arc(moon, m)


## 0..1 how much of a body's light reaches the ground at elevation `el`.
static func visibility(b: Dictionary, el: float) -> float:
	return smoothstep(float(b.fade_low), float(b.fade_high), el)


func sun_visibility(m: float) -> float:
	return visibility(sun, sun_angles(m).x)


func moon_visibility(m: float) -> float:
	return visibility(moon, moon_angles(m).x)


## Unit vector from the ground toward a body at (elevation, azimuth) degrees.
static func to_dir(el_deg: float, az_deg: float) -> Vector3:
	var el := deg_to_rad(el_deg)
	var az := deg_to_rad(az_deg)
	return Vector3(sin(az) * cos(el), sin(el), -cos(az) * cos(el))


## Every key field at minute m (Color or float), interpolated between the keys around it.
func sample(m: float) -> Dictionary:
	var out := {}
	var n := times.size()
	if n == 0:
		return out
	var t := fposmod(m, DAY)
	var i := n - 1
	for k in n:
		if times[k] <= t:
			i = k
	var j := (i + 1) % n
	var t0 := times[i]
	var t1 := times[j]
	var span := fposmod(t1 - t0, DAY)
	if span <= 0.0:
		span = DAY
	var f := clampf(fposmod(t - t0, DAY) / span, 0.0, 1.0)
	var a: Dictionary = values[i]
	var b: Dictionary = values[j]
	for k in fields:
		var av = a[k]
		out[k] = (av as Color).lerp(b[k], f) if av is Color else lerpf(av, b[k], f)
	return out


## Minute a forced period shows (-1 if unknown).
func period_minute(id: String) -> float:
	return float(periods.get(id, -1.0))

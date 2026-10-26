class_name WorldWind
extends Node
## Port of the original wind.gd: a base breeze plus a gust every 6-12 s, published as the shader
## globals wind_dir / wind_strength / wind_gust / wind_time (foliage, grass, props, clouds).
## WorldWeather sets `storm` (0 calm .. ~1.5 storm): the breeze strengthens, gusts come more often
## and blow harder (wind_gust goes past 1 in a storm), and the rain slants with them.

const GROUP := "wind"
const BASE_DIR := Vector2(1.0, -0.35)
const GUST_MIN := 6.0
const GUST_MAX := 12.0
const RISE := 1.0
const HOLD := 1.5
const DECAY := 2.0

var wind_time := 0.0
var dir := BASE_DIR.normalized()
var strength := 1.0
var storm := 0.0  ## WorldWeather: extra wind of the weather
var _since := 0.0
var _period := 8.0
var _gust_t := -1.0
var _gust := 0.0


func _ready() -> void:
	add_to_group(GROUP)
	WorldFx.ensure_globals()
	RenderingServer.global_shader_parameter_set("wind_dir", dir)
	RenderingServer.global_shader_parameter_set("wind_strength", strength)
	_period = randf_range(GUST_MIN, GUST_MAX)


func gust() -> float:
	return _gust


## Seconds until the next gust: 6-12 s calm, about a third of that in a full storm.
func _next_period() -> float:
	return randf_range(GUST_MIN, GUST_MAX) / (1.0 + 1.4 * clampf(storm, 0.0, 2.0))


func _process(delta: float) -> void:
	wind_time += delta
	_since += delta
	if _gust_t < 0.0 and _since >= _period:
		_gust_t = 0.0
		_since = 0.0
		_period = _next_period()
	_gust = 0.0
	if _gust_t >= 0.0:
		_gust_t += delta
		if _gust_t < RISE:
			_gust = _gust_t / RISE
		elif _gust_t < RISE + HOLD:
			_gust = 1.0
		elif _gust_t < RISE + HOLD + DECAY:
			_gust = 1.0 - (_gust_t - RISE - HOLD) / DECAY
		else:
			_gust_t = -1.0
	_gust *= 1.0 + 0.45 * clampf(storm, 0.0, 2.0)
	var st := 1.0 + 0.9 * clampf(storm, 0.0, 2.0)
	if absf(st - strength) > 0.001:
		strength = move_toward(strength, st, delta * 0.5)
		RenderingServer.global_shader_parameter_set("wind_strength", strength)
	RenderingServer.global_shader_parameter_set("wind_gust", _gust)
	RenderingServer.global_shader_parameter_set("wind_time", wind_time)

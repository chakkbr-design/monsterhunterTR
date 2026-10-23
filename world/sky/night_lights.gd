class_name NightLights
extends Node3D
## Port of the original night_lights.gd: a lamp's OmniLight and/or a building's window materials,
## scaled by WorldTimeOfDay's lamps / windows multipliers (0 by day, 1 at night).

const WINDOW_ENERGY := 1.0
const WINDOW_DARK := Color(0.16, 0.08, 0.02)

var light: OmniLight3D
var window_mats: Array = []

var _light_base := 0.0
var _lamps := 0.0
var _windows := 0.0


func _ready() -> void:
	add_to_group("night_lights")
	if light:
		_light_base = light.light_energy
	var tod := get_tree().get_first_node_in_group(WorldTimeOfDay.GROUP)
	if tod:
		var m: Dictionary = tod.night_mult()
		_lamps = float(m.lamps)
		_windows = float(m.windows)
	_apply()


func set_period_mult(lamps: float, windows: float) -> void:
	_lamps = lamps
	_windows = windows
	_apply()


func _apply() -> void:
	if light and is_instance_valid(light):
		light.light_energy = _light_base * _lamps
		light.visible = _lamps > 0.001
	for m in window_mats:
		m.emission_energy_multiplier = WINDOW_ENERGY * _windows
		m.albedo_color = Color.WHITE.lerp(WINDOW_DARK, _windows)

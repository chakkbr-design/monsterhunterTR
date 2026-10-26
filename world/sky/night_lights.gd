class_name NightLights
extends Node3D
## Port of the original night_lights.gd: a lamp's OmniLight and/or a building's window materials,
## scaled by WorldTimeOfDay's lamps / windows multipliers (0 by day, 1 at night, smooth ramps at
## dusk and dawn). Voxel zones use it the same way as the HGSS props (light = the lamp's
## OmniLight3D, window_mats = materials with emission_energy_multiplier / albedo_color).
## On top of the original:
##   - shadow budget: only the few lamps nearest the camera focus cast shadows (the count comes
##     from the graphics tier); a lamp entering or leaving the budget fades its shadow_opacity over
##     SHADOW_FADE seconds, so nothing pops. WorldTimeOfDay calls update_budget() every frame;
##   - distance fade on every lamp (light and shadow), so far lamps cost nothing;
##   - a gentle flicker (`flicker`, 0 = steady; a few percent of the energy at 1);
##   - an optional halo: a soft fog ellipsoid around the bulb, drawn only when the tier runs
##     volumetric fog and the look asks for halos (WorldTimeOfDay sets the shared density).

const WINDOW_ENERGY := 1.0
const WINDOW_DARK := Color(0.16, 0.08, 0.02)
const FADE_BEGIN := 34.0  ## m from the camera where a lamp starts to fade out
const FADE_LENGTH := 12.0
const SHADOW_FADE_BEGIN := 22.0
const SHADOW_FADE := 1.2  ## s to fade a shadow in or out of the budget
const SHADOW_RADIUS := 24.0  ## lamps farther than this from the focus never get a shadow
const SORT_EVERY := 0.3
const FLICKER_DEPTH := 0.09  ## energy swing at flicker = 1
const HALO_SIZE := Vector3(3.4, 2.8, 3.4)
const HALO_DENSITY := 0.07

static var lamps_all: Array = []  ## every NightLights in the tree that has a light
static var halo_material: FogMaterial
static var halos_on := false  ## WorldTimeOfDay: tier runs volumetric fog and the look wants halos
static var _sort_t := 0.0

var light: OmniLight3D
var window_mats: Array = []
var flicker := 0.25  ## 0..1
var halo := true

var _light_base := 0.0
var _lamps := 0.0
var _windows := 0.0
var _shadow := 0.0
var _shadow_want := false
var _phase := 0.0
var _t := 0.0
var _fog: FogVolume


func _enter_tree() -> void:
	if light and not lamps_all.has(self):
		lamps_all.append(self)


func _exit_tree() -> void:
	lamps_all.erase(self)


func _ready() -> void:
	add_to_group("night_lights")
	if light:
		if not lamps_all.has(self):
			lamps_all.append(self)
		_light_base = light.light_energy
		light.shadow_enabled = false
		light.distance_fade_enabled = true
		light.distance_fade_begin = FADE_BEGIN
		light.distance_fade_length = FADE_LENGTH
		light.distance_fade_shadow = SHADOW_FADE_BEGIN
		var p := light.global_position if light.is_inside_tree() else light.position
		_phase = fposmod(p.x * 12.9898 + p.z * 78.233, TAU)
	var tod := get_tree().get_first_node_in_group(WorldTimeOfDay.GROUP)
	if tod:
		var m: Dictionary = tod.night_mult()
		_lamps = float(m.lamps)
		_windows = float(m.windows)
	_apply()


func set_period_mult(lamps: float, windows: float) -> void:
	if is_equal_approx(lamps, _lamps) and is_equal_approx(windows, _windows):
		return
	_lamps = lamps
	_windows = windows
	_apply()


func _apply() -> void:
	if light and is_instance_valid(light):
		light.light_energy = _light_base * _lamps * _flicker_gain()
		light.visible = _lamps > 0.001
		_update_halo()
		set_process(flicker > 0.0 and _lamps > 0.001)
	else:
		set_process(false)
	for m in window_mats:
		m.emission_energy_multiplier = WINDOW_ENERGY * _windows
		m.albedo_color = Color.WHITE.lerp(WINDOW_DARK, _windows)


func _flicker_gain() -> float:
	if flicker <= 0.0:
		return 1.0
	var n := (
		sin(_t * 7.3 + _phase) * 0.45
		+ sin(_t * 13.7 + _phase * 2.0) * 0.3
		+ sin(_t * 2.3 + _phase * 0.5) * 0.25
	)
	return 1.0 + n * FLICKER_DEPTH * flicker


func _process(delta: float) -> void:
	_t += delta
	if light and is_instance_valid(light) and light.visible:
		light.light_energy = _light_base * _lamps * _flicker_gain()


func _update_halo() -> void:
	var want := halo and halos_on and _lamps > 0.001 and light.is_inside_tree()
	if want and _fog == null:
		_fog = FogVolume.new()
		_fog.name = "Halo"
		_fog.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
		_fog.size = HALO_SIZE
		_fog.material = shared_halo_material()
		light.add_child(_fog)
	if _fog:
		_fog.visible = want


## Fog material every halo shares; WorldTimeOfDay sets its density (lamps x weather).
static func shared_halo_material() -> FogMaterial:
	if halo_material == null:
		halo_material = FogMaterial.new()
		halo_material.density = 0.0
		halo_material.albedo = Color(1.0, 0.93, 0.82)
		halo_material.edge_fade = 0.9
		halo_material.height_falloff = 0.0
	return halo_material


## Density of every lamp halo (0 hides them in practice).
static func set_halo_density(d: float) -> void:
	shared_halo_material().density = HALO_DENSITY * maxf(d, 0.0)


## Re-checks halos after the tier or the look changed.
static func refresh_halos() -> void:
	for n in lamps_all:
		if is_instance_valid(n) and n.light and is_instance_valid(n.light):
			n._update_halo()


## Gives shadows to the `count` lit lamps nearest `focus` (within SHADOW_RADIUS) and fades the
## others out. Sorting runs every SORT_EVERY s; the fades every call.
static func update_budget(focus: Vector3, count: int, delta: float) -> void:
	_sort_t -= delta
	if _sort_t <= 0.0:
		_sort_t = SORT_EVERY
		var lit: Array = []
		for n in lamps_all:
			if not is_instance_valid(n) or not is_instance_valid(n.light):
				continue
			n._shadow_want = false
			if count > 0 and n._lamps > 0.001 and n.light.is_inside_tree():
				var d: float = n.light.global_position.distance_squared_to(focus)
				if d < SHADOW_RADIUS * SHADOW_RADIUS:
					lit.append([d, n])
		lit.sort_custom(func(a, b): return a[0] < b[0])
		for i in mini(count, lit.size()):
			lit[i][1]._shadow_want = true
	var step := delta / SHADOW_FADE
	for n in lamps_all:
		if not is_instance_valid(n) or not is_instance_valid(n.light):
			continue
		var target := 1.0 if n._shadow_want else 0.0
		if n._shadow == target and n.light.shadow_enabled == (target > 0.0):
			continue
		n._shadow = move_toward(n._shadow, target, step)
		n.light.shadow_enabled = n._shadow > 0.001
		n.light.shadow_opacity = n._shadow


## Lamps currently casting a shadow (tests, the sky panel).
static func shadowed_count() -> int:
	var c := 0
	for n in lamps_all:
		if is_instance_valid(n) and is_instance_valid(n.light) and n.light.shadow_enabled:
			c += 1
	return c

class_name WeatherLightning
extends Node3D
## Storm lightning shared by the overworld (WorldWeather) and the training stadium (BattleWeatherFx):
## - a real light flash: its own bluish DirectionalLight3D coming from the strike's side, pulsing
##   2-4 times in half a second (a return stroke and its restrikes), with `flash` (0..1) for the
##   owner to publish as the lightning_flash global (sky, water, rain streaks) and to spike the
##   ambient light (drive_env, or WorldTimeOfDay reading the weather's flash);
## - now and then a voxel bolt: a jagged path from the cloud base to the ground (midpoint
##   displacement plus a branch or two) drawn as 0.3 m emissive cubes, with a glow at the foot.
##   Most strikes are far away (flash and thunder only); some land where the camera can see them;
## - thunder: the `thunder` signal fires distance / 343 s after the flash (the owner plays it).
## Strikes come every `gap` seconds scaled by `storm` (0 = none); strike() forces one.

signal thunder(distance: float, power: float)

const COLOR := Color(0.78, 0.84, 1.0)
const LIGHT_ENERGY := 3.0
const BOLT_TOP := 46.0
const VOX := 0.3
const SPEED_OF_SOUND := 343.0
const PULSE_DECAY := 0.07  ## s
const BOLT_SECS := 0.5
const AMBIENT_SPIKE := 2.5  ## drive_env: ambient energy x (1 + this x flash)

var gap := Vector2(6.0, 16.0)
var storm := 0.0
var focus := Vector3.ZERO
var view_dir := Vector3(0.0, 0.0, -1.0)  ## camera forward on the ground
var in_view_chance := 0.22
var near_range := Vector2(3.0, 9.0)  ## in-view strikes: metres ahead of the focus (top-down camera)
var far_range := Vector2(45.0, 130.0)
var ground_y := 0.0
var drive_env: Environment = null
var flash := 0.0
var driven := false  ## the owner calls tick() itself
var last_strike := Vector3.INF
var strikes := 0

var light: DirectionalLight3D
var bolt: MultiMeshInstance3D
var glow: OmniLight3D

var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _next := 4.0
var _pulses: Array = []  ## [start, peak]
var _pending: Array = []  ## [seconds left, distance, power]
var _bolt_t := 0.0
var _bolt_mat: StandardMaterial3D
var _amb_base := -1.0
var _amb_set := -1.0


func _ready() -> void:
	_rng.randomize()
	_next = _rng.randf_range(gap.x * 0.4, gap.y * 0.6)
	light = DirectionalLight3D.new()
	light.name = "LightningFlash"
	light.light_color = COLOR
	light.light_energy = 0.0
	light.light_specular = 0.6
	light.light_volumetric_fog_energy = 0.0
	light.shadow_enabled = false
	light.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	light.visible = false
	add_child(light)
	bolt = MultiMeshInstance3D.new()
	bolt.name = "Bolt"
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	_bolt_mat = StandardMaterial3D.new()  # (unshaded would drop the emission: lit + emissive)
	_bolt_mat.albedo_color = Color(0.2, 0.22, 0.3)
	_bolt_mat.roughness = 1.0
	_bolt_mat.emission_enabled = true
	_bolt_mat.emission = Color(0.72, 0.82, 1.0)
	_bolt_mat.emission_energy_multiplier = 8.0
	box.material = _bolt_mat
	mm.mesh = box
	bolt.multimesh = mm
	bolt.layers = WeatherKit.LAYER
	bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bolt.visible = false
	add_child(bolt)
	glow = OmniLight3D.new()
	glow.name = "StrikeGlow"
	glow.light_color = COLOR
	glow.omni_range = 26.0
	glow.omni_attenuation = 1.2
	glow.light_energy = 0.0
	glow.shadow_enabled = false
	glow.light_volumetric_fog_energy = 0.0
	glow.visible = false
	add_child(glow)


func _exit_tree() -> void:
	_restore_env()


func _process(delta: float) -> void:
	if not driven:
		tick(delta)


## Advances the strikes, the flash and the pending thunder (the owner calls it when `driven`, so
## the flash it publishes is this frame's).
func tick(delta: float) -> void:
	_t += delta
	if storm > 0.05:
		_next -= delta * clampf(storm, 0.0, 1.0)
		if _next <= 0.0:
			_next = _rng.randf_range(gap.x, gap.y)
			strike()
	var f := 0.0
	for i in range(_pulses.size() - 1, -1, -1):
		var dt := _t - float(_pulses[i][0])
		if dt < 0.0:
			continue
		if dt > 1.2:
			_pulses.remove_at(i)
			continue
		f = maxf(f, float(_pulses[i][1]) * exp(-dt / PULSE_DECAY))
	flash = clampf(f, 0.0, 1.0)
	light.light_energy = LIGHT_ENERGY * flash
	light.visible = flash > 0.005
	_bolt_t -= delta
	bolt.visible = _bolt_t > 0.0 and flash > 0.06
	if bolt.visible:
		_bolt_mat.emission_energy_multiplier = 2.0 + 10.0 * flash
	glow.light_energy = 9.0 * flash if _bolt_t > 0.0 else 0.0
	glow.visible = glow.light_energy > 0.02
	for i in range(_pending.size() - 1, -1, -1):
		_pending[i][0] -= delta
		if float(_pending[i][0]) <= 0.0:
			thunder.emit(float(_pending[i][1]), float(_pending[i][2]))
			_pending.remove_at(i)
	_drive_env()


## A strike now. `at` (optional) is the ground point; by default a far one, or one in view.
func strike(at := Vector3.INF) -> void:
	strikes += 1
	var seen := at != Vector3.INF
	if not seen:
		var fwd := Vector3(view_dir.x, 0.0, view_dir.z)
		fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3(0, 0, -1)
		if _rng.randf() < in_view_chance:
			seen = true
			var side := fwd.cross(Vector3.UP)
			at = (
				focus
				+ fwd * _rng.randf_range(near_range.x, near_range.y)
				+ side * _rng.randf_range(-near_range.y * 0.6, near_range.y * 0.6)
			)
		else:
			var ang := _rng.randf() * TAU
			at = (
				focus
				+ Vector3(cos(ang), 0.0, sin(ang)) * _rng.randf_range(far_range.x, far_range.y)
			)
	at.y = ground_y
	last_strike = at
	var dist := Vector2(at.x - focus.x, at.z - focus.z).length()
	var peak := clampf(1.15 - dist / 220.0, 0.45, 1.0)
	_pulses.append([_t, peak])
	var n := _rng.randi_range(1, 3)
	var t := _t
	for i in n:
		t += _rng.randf_range(0.06, 0.16)
		_pulses.append([t, peak * _rng.randf_range(0.5, 0.95)])
	var to_light := Vector3(at.x - focus.x, 0.0, at.z - focus.z)
	to_light = to_light.normalized() if to_light.length() > 0.1 else Vector3(0, 0, -1)
	to_light = (to_light + Vector3.UP * 1.6).normalized()
	light.global_transform.basis = Basis.looking_at(-to_light, Vector3.UP)
	if seen or dist < 160.0:
		_make_bolt(at)
	glow.global_position = at + Vector3(0, 1.5, 0)
	_pending.append([dist / SPEED_OF_SOUND, dist, clampf(1.0 - dist / 200.0, 0.15, 1.0)])


## Jagged voxel bolt from the cloud base down to `at`.
func _make_bolt(at: Vector3) -> void:
	var top := at + Vector3(_rng.randf_range(-8, 8), BOLT_TOP, _rng.randf_range(-8, 8))
	var main := _jag(top, at, 7, 0.22)
	var cells := {}
	_voxelize(main, 1.0, cells)
	for b in _rng.randi_range(1, 2):
		var i := _rng.randi_range(int(main.size() * 0.2), int(main.size() * 0.6))
		var from: Vector3 = main[i]
		var away := Vector3(_rng.randf_range(-1, 1), 0.0, _rng.randf_range(-1, 1)).normalized()
		var to := from + away * _rng.randf_range(6.0, 14.0) + Vector3.DOWN * _rng.randf_range(6, 14)
		_voxelize(_jag(from, to, 5, 0.3), 0.7, cells)
	var mm := bolt.multimesh
	mm.instance_count = cells.size()
	var k := 0
	for c: Vector3i in cells:
		var s: float = cells[c]
		mm.set_instance_transform(
			k, Transform3D(Basis.from_scale(Vector3.ONE * VOX * s), Vector3(c) * VOX)
		)
		k += 1
	bolt.global_transform = Transform3D.IDENTITY
	_bolt_t = BOLT_SECS


## Midpoint displacement: `levels` halvings, each midpoint pushed sideways by `rough` x length.
func _jag(a: Vector3, b: Vector3, levels: int, rough: float) -> Array:
	var pts: Array = [a, b]
	for l in levels:
		var nxt: Array = [pts[0]]
		for i in pts.size() - 1:
			var p: Vector3 = pts[i]
			var q: Vector3 = pts[i + 1]
			var len := p.distance_to(q)
			var m := (p + q) * 0.5
			m += (
				Vector3(
					_rng.randf_range(-1, 1), _rng.randf_range(-0.3, 0.3), _rng.randf_range(-1, 1)
				)
				* len
				* rough
			)
			nxt.append(m)
			nxt.append(q)
		pts = nxt
	return pts


static func _voxelize(pts: Array, size: float, cells: Dictionary) -> void:
	for i in pts.size() - 1:
		var p: Vector3 = pts[i]
		var q: Vector3 = pts[i + 1]
		var n := maxi(1, int(ceil(p.distance_to(q) / (VOX * 0.5))))
		for s in n + 1:
			var v := p.lerp(q, float(s) / n) / VOX
			var c := Vector3i(roundi(v.x), roundi(v.y), roundi(v.z))
			cells[c] = maxf(float(cells.get(c, 0.0)), size)


## Battle stages: the ambient light spikes with the flash (in the world WorldTimeOfDay does it).
func _drive_env() -> void:
	if drive_env == null:
		return
	if _amb_set >= 0.0 and not is_equal_approx(drive_env.ambient_light_energy, _amb_set):
		_amb_base = drive_env.ambient_light_energy  # someone else changed it: new base
	if _amb_base < 0.0:
		_amb_base = drive_env.ambient_light_energy
	_amb_set = _amb_base * (1.0 + AMBIENT_SPIKE * flash)
	drive_env.ambient_light_energy = _amb_set


func _restore_env() -> void:
	if drive_env and _amb_base >= 0.0 and is_equal_approx(drive_env.ambient_light_energy, _amb_set):
		drive_env.ambient_light_energy = _amb_base
	_amb_base = -1.0
	_amb_set = -1.0

class_name OverworldCamera
extends Node3D
## Port of the original camera_rig.gd: fixed-pitch orbit that follows the player with exponential
## smoothing, with the original overworld.tscn rig values (pitch 32°, 12 m, FOV 35°, far 220, DOF band
## 6 m; the script defaults 38° / 16 m are overridden there; interiors: RouteWorld._camera_mode),
## tilt-shift depth of field around the focus (camera_attrs.tres),
## per-zone look (camera_distance / camera_yaw / camera_pitch / camera_pitch_near over a rect /
## camera_far), and buildings / terraces that fade to see-through while they hide the player.
## Publishes main_cam_pos for the HGSS billboard shader. No manual turn (the original reads no input:
## the yaw only comes from the zone).

const GROUP := "ow_camera"
const FADE_RADIUS := 18.0
const EAVES_REACH := 1.0  ## m the player may stand inside a fader's rect and still be hidden by it
const EYE_CLEAR := 1.0  ## m around a fading part's box within which the eye counts as inside it
## Transparency of a building around the eye: it vanishes (its stacked faces at building_alpha hid
## the player, and even at 5 % its lit windows floated in the night).
const EYE_ALPHA := 1.0
const ATTRS := "res://world/look/camera_attrs.tres"

@export_range(15.0, 75.0) var pitch_deg := 32.0
@export var distance := 12.0
@export var follow_sharpness := 6.0
@export var yaw_sharpness := 8.0
@export var fov := 35.0
@export var dof_band := 6.0
@export var building_alpha := 0.25

var camera: Camera3D
var _yaw := 0.0
var _yaw_target := 0.0
var _dist := 12.0
var _zone_dist := 0.0
var _zone_yaw := 0.0
var _zone_pitch := 0.0
var _zone_pitch_near := 0.0
var _near_rect := Rect2()
var _yaw_off := 0.0
var _pitch_off := 0.0
var _far := 220.0
var _fading := {}


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	WorldFx.ensure_globals()
	camera = Camera3D.new()
	camera.fov = fov
	camera.far = _far
	if ResourceLoader.exists(ATTRS):
		camera.attributes = (load(ATTRS) as CameraAttributes).duplicate()
	add_child(camera)
	camera.make_current()
	_yaw = rotation.y
	_yaw_target = _yaw
	_dist = distance
	var t := Overworld.player_of(self)
	if t:
		global_position = t.global_position
	_apply()


## Current yaw in radians (the player rotates its input by this), zone yaw included.
func yaw() -> float:
	return _yaw + deg_to_rad(_yaw_off)


## Zone `look` (map/world JSON): camera_distance, camera_yaw, camera_pitch, camera_pitch_near +
## camera_pitch_range [x, z, w, h], camera_far. {} = defaults (interiors).
func set_zone_look(look: Dictionary) -> void:
	_zone_dist = maxf(float(look.get("camera_distance", 0.0)), 0.0)
	_zone_yaw = float(look.get("camera_yaw", 0.0))
	_zone_pitch = float(look.get("camera_pitch", 0.0))
	_zone_pitch_near = float(look.get("camera_pitch_near", 0.0))
	var rc: Array = look.get("camera_pitch_range", [])
	_near_rect = (
		Rect2(float(rc[0]), float(rc[1]), float(rc[2]), float(rc[3])) if rc.size() == 4 else Rect2()
	)
	var far := float(look.get("camera_far", 0.0))
	if camera:
		camera.far = far if far > 0.0 else _far


## Lens: field of view (deg) and default far plane (m). RouteWorld switches the original's outdoor
## (35° / 220 m, overworld.tscn) and interior (30° / 120 m, *_interiors.tscn) lenses.
func set_lens(fov_deg: float, far_m: float) -> void:
	fov = fov_deg
	_far = far_m
	if camera:
		camera.fov = fov_deg
		camera.far = far_m


func _base_dist() -> float:
	return _zone_dist if _zone_dist > 0.0 else distance


func _pitch_near_blend(p: Vector3) -> float:
	if _near_rect.size.x <= 0.0 or p.z < _near_rect.position.y or p.z > _near_rect.end.y:
		return 0.0
	return clampf((p.x - _near_rect.position.x) / _near_rect.size.x, 0.0, 1.0)


func _process(delta: float) -> void:
	var t := Overworld.player_of(self)
	_yaw = lerpf(_yaw, _yaw_target, 1.0 - exp(-yaw_sharpness * delta))
	if t:
		global_position = global_position.lerp(
			t.visual_position(), 1.0 - exp(-follow_sharpness * delta)
		)
	_dist = lerpf(_dist, _base_dist(), 1.0 - exp(-3.0 * delta))
	_yaw_off = lerpf(_yaw_off, _zone_yaw, 1.0 - exp(-1.1 * delta))
	var pt := _zone_pitch
	if t and _near_rect.size.x > 0.0:
		pt = lerpf(_zone_pitch, _zone_pitch_near, _pitch_near_blend(t.global_position))
	_pitch_off = lerpf(_pitch_off, pt, 1.0 - exp(-1.1 * delta))
	_apply()
	_fade_buildings(delta, t)


## Snap (teleports): no smoothing for one frame.
func snap() -> void:
	var t := Overworld.player_of(self)
	if t:
		global_position = t.global_position
	_dist = _base_dist()
	_yaw_off = _zone_yaw
	_pitch_off = _zone_pitch
	_apply()


func _apply() -> void:
	var p := deg_to_rad(pitch_deg + _pitch_off)
	rotation.y = _yaw + deg_to_rad(_yaw_off)
	camera.position = Vector3(0.0, sin(p) * _dist, cos(p) * _dist)
	camera.rotation = Vector3(-p, 0.0, 0.0)
	if camera.is_inside_tree():
		RenderingServer.global_shader_parameter_set("main_cam_pos", camera.global_position)
	var attr := camera.attributes as CameraAttributesPractical
	if attr:
		attr.dof_blur_far_distance = _dist + dof_band
		attr.dof_blur_near_distance = maxf(_dist - dof_band, 0.5)


# --- see-through buildings (original _fade_buildings) ---------------------------------------------


func _cam_axes() -> Array:
	var b := global_transform.basis
	return [Vector3(b.z.x, 0.0, b.z.z).normalized(), Vector3(b.x.x, 0.0, b.x.z).normalized()]


static func _cam_span(r: Rect2, f: Vector3, d: Vector3, s: Vector3) -> PackedFloat32Array:
	var c := Vector2(r.position.x + r.size.x * 0.5 - f.x, r.position.y + r.size.y * 0.5 - f.z)
	var hx := r.size.x * 0.5
	var hz := r.size.y * 0.5
	var ac := c.x * d.x + c.y * d.z
	var ar := absf(hx * d.x) + absf(hz * d.z)
	var sc := c.x * s.x + c.y * s.z
	var sr := absf(hx * s.x) + absf(hz * s.z)
	return PackedFloat32Array([ac - ar, ac + ar, sc - sr, sc + sr])


func _fade_target(n: Node3D, f: Vector3) -> float:
	var ax := _cam_axes()
	var r: Rect2 = n.get_meta("rect")
	var height: float = n.get_meta("height", 5.0)
	var tan_p := tan(deg_to_rad(pitch_deg + _pitch_off))
	var sp := _cam_span(r, f, ax[0], ax[1])
	# Hidden: the rect lies between the player and the eye (its centre on the camera side) and is
	# tall enough to cover them. The player may stand up to EAVES_REACH inside its far edge: right
	# behind a house the grown rect (eaves) already reaches under their feet.
	var hidden: bool = (
		sp[0] > -EAVES_REACH
		and sp[0] + sp[1] > 0.0
		and sp[0] < height / tan_p
		and sp[2] < 0.0
		and sp[3] > 0.0
	)
	return 1.0 - building_alpha if hidden else 0.0


func _fade_buildings(delta: float, target: Node3D) -> void:
	var f := global_position
	for n in WorldProps.faders_near(f, FADE_RADIUS):
		_fading[n] = true
	var eye := camera.global_position
	var at: Vector3 = target.visual_position() if target else f
	for n in _fading.keys():
		if not is_instance_valid(n) or not n.has_meta("rect"):
			_fading.erase(n)
			continue
		var want := _fade_target(n, f)
		var cur: float = n.get_meta("fade", 0.0)
		if is_equal_approx(cur, want):
			if want == 0.0:
				_fading.erase(n)
			continue
		var nv := move_toward(cur, want, delta * 4.0)
		n.set_meta("fade", nv)
		_set_fade(n, nv, eye, at)


func _set_fade(n: Node3D, nv: float, eye: Vector3, at: Vector3) -> void:
	var geoms: Array = n.get_meta("geoms", [])
	# The eye sits in (or right by) the building, e.g. a two-storey roof right in front of the lens:
	# its stacked faces at building_alpha read as an opaque wall, so its parts vanish instead.
	var inside := false
	if nv > 0.0:
		for g in geoms:
			if is_instance_valid(g) and _eye_in(g as GeometryInstance3D, eye):
				inside = true
				break
	var deep := minf(nv / maxf(1.0 - building_alpha, 0.01), 1.0) * EYE_ALPHA
	for g in geoms:
		if not is_instance_valid(g):
			continue
		var gi := g as GeometryInstance3D
		var a := nv
		if nv > 0.0:  # only the parts actually between the eye and the player (or around the eye)
			var inv := gi.global_transform.affine_inverse()
			if _eye_in(gi, eye):
				a = deep
			elif gi.get_aabb().intersects_segment(inv * eye, inv * (at + Vector3.UP)) == null:
				a = 0.0
			elif inside:
				a = deep
		gi.transparency = a
		if a > 0.0:
			if not gi.has_meta("fade_shadow"):
				gi.set_meta("fade_shadow", gi.cast_shadow)
			gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif gi.has_meta("fade_shadow"):
			gi.cast_shadow = gi.get_meta("fade_shadow")
			gi.remove_meta("fade_shadow")


## True when the eye is inside the part's box grown by EYE_CLEAR (empty boxes never count).
static func _eye_in(gi: GeometryInstance3D, eye: Vector3) -> bool:
	var bb := gi.get_aabb()
	if bb.size.length_squared() < 0.0001:
		return false
	return bb.grow(EYE_CLEAR).has_point(gi.global_transform.affine_inverse() * eye)

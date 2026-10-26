class_name FountainFx
extends Node3D
## Animated water for a fountain or a cascade (docs/VOXEL.md, "Water"): jets, falling sheets between
## tiers, splashes and droplets where the water lands, soft mist, the basin surfaces (agitated where
## the water lands, through WaterSurface ripple sources) and a gentle underwater light at night.
## The voxel generator builds the stone; this node only adds the moving water. All positions are
## local to this node.
##   setup({"jets": [{"pos": Vector3 (nozzle), "height": m (apex above the nozzle),
##                    "count": n (1 = one jet, > 1 = a crown of n arcs around pos),
##                    "radius": m (crown nozzle ring), "reach": m (crown landing distance,
##                    + outwards / - inwards), "dir": Vector3 (single tilted jet), "spread": deg}],
##          "basins": [{"pos": Vector3 (surface centre), "size": Vector2, "kind": "fountain",
##                      "shape": "ellipse" | "rect", "depth": m}],
##          "sheets": [{"from": Vector3 (lip), "to": Vector3 (where it lands), "width": m}],
##          "curtains": [{"centre": Vector3 (lip centre), "radius": m, "drop": m, "flare": m,
##                        "from_deg": 0, "to_deg": 360}]  (round overflow of a tier),
##          "surfaces": [MeshInstance3D] (other WaterSurface nodes fed with ripples, e.g. the pond
##                      under a cascade),
##          "light": Color (optional underwater glow at night), "mist": true})
## Jets: GPU particles with streak quads aligned to the velocity; they die on the basin surfaces
## (GPUParticlesCollisionBox3D) and spawn splash droplets there (sub-emitter). Night: the node joins
## the "night_lights" group, so TimeOfDay's set_period_mult(lamps, windows) dims the underwater
## light like the lamps (the same multiplier it publishes as the night_lamps global); set_night()
## drives it directly (battle / tests).

const GRAVITY := 9.8
const RATE := 90.0  ## jet particles per second per stream
const LIGHT_ENERGY := 1.6

var spec := {}
var basins: Array[MeshInstance3D] = []
var light: OmniLight3D
var night := 0.0

var _jets: Array[GPUParticles3D] = []
var _mist: GPUParticles3D
var _feeds := {}  # surface (MeshInstance3D) -> Array of sources in this node's space
var _drop_mat: ShaderMaterial
var _splash_mat: ShaderMaterial


func _ready() -> void:
	add_to_group("night_lights")
	_feed_ripples()
	var tod := get_tree().get_first_node_in_group("time_of_day")
	if tod and tod.has_method("night_mult"):
		set_night(float(tod.night_mult().get("lamps", night)))


func setup(s: Dictionary) -> void:
	spec = s
	for c in get_children():
		remove_child(c)
		c.queue_free()
	basins.clear()
	_jets.clear()
	_feeds.clear()
	_mist = null
	light = null
	_drop_mat = _drop_material(false, Color(0.86, 0.95, 1.0, 0.75))
	_splash_mat = _drop_material(true, Color(0.9, 0.97, 1.0, 0.8))
	for b in s.get("basins", []):
		_basin(b)
	var splash := _splash_system()
	var landings: Array[Vector3] = []
	for j in s.get("jets", []):
		landings.append_array(_jet(j, splash))
	var lines: Array[Vector3] = []
	for sh in s.get("sheets", []):
		lines.append_array(_sheet(sh))
	for cu in s.get("curtains", []):
		lines.append_array(_curtain(cu))
	if not lines.is_empty():
		_sheet_splash(lines)
	if bool(s.get("mist", true)) and not (landings.is_empty() and lines.is_empty()):
		var pts := landings.duplicate()
		pts.append_array(lines)
		_mist_system(pts)
	if s.has("light") and not basins.is_empty():
		_underwater_light(s.light)
	if is_inside_tree():
		_feed_ripples()


## TimeOfDay pushes its lamp multiplier to the "night_lights" group.
func set_period_mult(lamps: float, _windows: float) -> void:
	set_night(lamps)


func set_night(v: float) -> void:
	night = clampf(v, 0.0, 1.0)
	if light:
		light.light_energy = LIGHT_ENERGY * night
		light.visible = night > 0.01


# ---------------------------------------------------------------- basins


func _basin(b: Dictionary) -> void:
	var size: Vector2 = b.get("size", Vector2.ONE)
	var o := {
		"kind": str(b.get("kind", "fountain")),
		"depth": float(b.get("depth", 0.4)),
		"shape": str(b.get("shape", "ellipse")),
	}
	for k in ["tint", "pixel", "life", "params", "seed"]:
		if b.has(k):
			o[k] = b[k]
	var w := WaterSurface.make(size, o)
	w.name = "Basin%d" % basins.size()
	w.position = b.get("pos", Vector3.ZERO)
	add_child(w)
	basins.append(w)
	# Jet drops die on the surface (and spawn splashes there).
	var col := GPUParticlesCollisionBox3D.new()
	col.name = "Catch%d" % (basins.size() - 1)
	col.size = Vector3(size.x, 0.3, size.y)
	col.position = w.position - Vector3(0, 0.15, 0)
	add_child(col)


## The basin a falling point lands in: highest surface below `p` whose outline contains it.
func _basin_at(p: Vector3) -> MeshInstance3D:
	var best: MeshInstance3D = null
	for w in basins:
		if w.position.y > p.y + 0.05:
			continue
		var size: Vector2 = (w.mesh as PlaneMesh).size
		var d := Vector2(p.x - w.position.x, p.z - w.position.z)
		var inside := absf(d.x) <= size.x * 0.5 and absf(d.y) <= size.y * 0.5
		if inside and (best == null or w.position.y > best.position.y):
			best = w
	return best


## Lowest landing height for lifetimes (the lowest basin, or 1 m below the start).
func _floor_y(from: Vector3) -> float:
	var y := from.y - 1.0
	for w in basins:
		y = minf(y, w.position.y)
	return y - 0.1


func _add_feed(target: MeshInstance3D, p: Vector3, radius: float, strength: float) -> void:
	if target == null:
		return
	if not _feeds.has(target):
		_feeds[target] = []
	_feeds[target].append({"pos": p, "radius": radius, "strength": strength})


func _landing_feed(p: Vector3, radius: float, strength: float) -> void:
	var b := _basin_at(p)
	if b:
		_add_feed(b, p, radius, strength)
		return
	for s in spec.get("surfaces", []):
		if s is MeshInstance3D and is_instance_valid(s):
			_add_feed(s, p, radius, strength)
			return


func _feed_ripples() -> void:
	for target in _feeds:
		if not is_instance_valid(target):
			continue
		var w: MeshInstance3D = target
		var src: Array = _feeds[target]
		# Too many spots: keep an even subset.
		var keep := []
		var step := maxf(float(src.size()) / WaterSurface.MAX_RIPPLES, 1.0)
		var i := 0.0
		while int(i) < src.size() and keep.size() < WaterSurface.MAX_RIPPLES:
			keep.append(src[int(i)])
			i += step
		var out := []
		for d in keep:
			var p: Vector3 = d.pos
			var lp := p - w.position
			if w.get_parent() != self:
				if not (w.is_inside_tree() and is_inside_tree()):
					continue
				lp = w.to_local(to_global(p))
			out.append({"pos": lp, "radius": d.radius, "strength": d.strength})
		WaterSurface.set_ripples(w, out)


# ---------------------------------------------------------------- jets


func _jet(j: Dictionary, splash: GPUParticles3D) -> Array[Vector3]:
	var pos: Vector3 = j.get("pos", Vector3.ZERO)
	var h := maxf(float(j.get("height", 0.8)), 0.05)
	var n := maxi(int(j.get("count", 1)), 1)
	var vy := sqrt(2.0 * GRAVITY * h)
	var starts: Array[Vector3] = []
	var vels: Array[Vector3] = []
	if n == 1:
		var d: Vector3 = j.get("dir", Vector3.UP)
		d = d.normalized() if d.length() > 0.001 else Vector3.UP
		d.y = maxf(d.y, 0.05)
		starts.append(pos)
		vels.append(d.normalized() * (vy / d.normalized().y))
	else:
		var r := float(j.get("radius", 0.0))
		var reach := float(j.get("reach", h * 0.8))
		var vh := reach / (2.0 * vy / GRAVITY)
		var ph := float(j.get("phase", 0.0))
		for i in n:
			var a := TAU * float(i) / float(n) + ph
			var out := Vector3(cos(a), 0.0, sin(a))
			starts.append(pos + out * r)
			vels.append(out * vh + Vector3.UP * vy)
	var speed := vels[0].length()
	var lo := _floor_y(pos)
	var life := 0.05
	var landings: Array[Vector3] = []
	var box := AABB(pos, Vector3.ZERO)
	for i in starts.size():
		var s := starts[i]
		var v := vels[i]
		var tl := (v.y + sqrt(v.y * v.y + 2.0 * GRAVITY * maxf(s.y - lo, 0.0))) / GRAVITY
		life = maxf(life, tl + 0.05)
		box = box.expand(s + Vector3(v.x, 0, v.z) * tl + Vector3(0, lo - s.y, 0))
		box = box.expand(s + Vector3(0, v.y * v.y / (2.0 * GRAVITY), 0))
		# Where it lands on the surface below (for ripples / mist).
		var b := _basin_at(s + Vector3(0, h, 0))
		var yb := b.position.y if b else lo
		var t2 := (v.y + sqrt(v.y * v.y + 2.0 * GRAVITY * maxf(s.y - yb, 0.0))) / GRAVITY
		var land := s + Vector3(v.x, 0, v.z) * t2
		land.y = yb
		landings.append(land)
		var spread_r := 0.06 + speed * sin(deg_to_rad(float(j.get("spread", 3.5)))) * t2
		_landing_feed(land, clampf(spread_r, 0.08, 0.45), 1.0 if n == 1 else 0.75)
	var gp := GPUParticles3D.new()
	gp.name = "Jet%d" % _jets.size()
	gp.amount = clampi(int(ceil(RATE * float(starts.size()) * life)), 16, 1500)
	gp.lifetime = life
	gp.preprocess = life
	gp.fixed_fps = 60
	gp.local_coords = false
	gp.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	gp.collision_base_size = 0.02
	gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gp.visibility_aabb = box.grow(0.6)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_DIRECTED_POINTS
	var pimg := Image.create(starts.size(), 1, false, Image.FORMAT_RGBF)
	var nimg := Image.create(starts.size(), 1, false, Image.FORMAT_RGBF)
	for i in starts.size():
		var sp := starts[i]
		var nv := vels[i].normalized()
		pimg.set_pixel(i, 0, Color(sp.x, sp.y, sp.z))
		nimg.set_pixel(i, 0, Color(nv.x, nv.y, nv.z))
	pm.emission_point_texture = ImageTexture.create_from_image(pimg)
	pm.emission_normal_texture = ImageTexture.create_from_image(nimg)
	pm.emission_point_count = starts.size()
	pm.direction = Vector3(0, 0, 1)
	pm.spread = float(j.get("spread", 3.5))
	pm.initial_velocity_min = speed * 0.96
	pm.initial_velocity_max = speed * 1.0
	pm.gravity = Vector3(0, -GRAVITY, 0)
	pm.scale_min = 0.7
	pm.scale_max = 1.25
	pm.color_ramp = _ramp([0.0, 0.06, 0.8, 1.0], [0.0, 1.0, 0.85, 0.0])
	pm.collision_mode = ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT
	pm.sub_emitter_mode = ParticleProcessMaterial.SUB_EMITTER_AT_COLLISION
	pm.sub_emitter_amount_at_collision = 1
	gp.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.045, 0.2)
	q.material = _drop_mat
	gp.draw_pass_1 = q
	add_child(gp)
	gp.position = Vector3.ZERO
	gp.sub_emitter = gp.get_path_to(splash)
	_jets.append(gp)
	if n == 1 and h > 0.25:
		_core(pos, vels[0], h)
	return landings


## The glassy rising column of a single jet (the particles alone look like rain).
func _core(pos: Vector3, v: Vector3, h: float) -> void:
	# Rising part only: up to 3/4 of the apex height (half the time to the apex).
	var t_max := 0.5 * v.y / GRAVITY
	var pts := PackedVector3Array()
	for i in 9:
		var t := float(i) / 8.0 * t_max
		pts.append(pos + v * t + Vector3(0, -0.5 * GRAVITY * t * t, 0))
	var mi := MeshInstance3D.new()
	mi.name = "JetCore"
	mi.mesh = _tube(pts, 0.022, 0.012)
	var clen := h * 0.75
	var m := _sheet_material(clen, 0.15, 0.02, v.length() * 0.5, Color(0.8, 0.94, 1.0), 0.5)
	m.set_shader_parameter("pixel", 0.0)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# ---------------------------------------------------------------- sheets


func _sheet(sh: Dictionary) -> Array[Vector3]:
	var a: Vector3 = sh.get("from", Vector3.ZERO)
	var b: Vector3 = sh.get("to", a + Vector3(0, -1, 0.2))
	var w := maxf(float(sh.get("width", 0.4)), 0.02)
	var hd := Vector3(b.x - a.x, 0, b.z - a.z)
	var side := (hd.cross(Vector3.UP).normalized() if hd.length() > 0.001 else Vector3.RIGHT) * w
	var segs := 14
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	var length := 0.0
	var prev := a
	for i in segs + 1:
		var s := float(i) / segs
		var p := a + hd * s + Vector3(0, (b.y - a.y) * s * s, 0)
		length += p.distance_to(prev)
		prev = p
		var tg := (hd + Vector3(0, 2.0 * (b.y - a.y) * s, 0)).normalized()
		var nrm := tg.cross(side).normalized()
		verts.append_array([p - side * 0.5, p + side * 0.5])
		uvs.append_array([Vector2(0, s), Vector2(1, s)])
		norms.append_array([nrm, nrm])
		if i > 0:
			var k := i * 2
			idx.append_array([k - 2, k - 1, k, k - 1, k + 1, k])
	var mi := MeshInstance3D.new()
	mi.name = "Sheet"
	mi.mesh = _arrays_mesh(verts, norms, uvs, idx)
	mi.material_override = _sheet_material(
		length, w, a.y - b.y, float(sh.get("speed", 0.45)), Color(0.72, 0.9, 1.0), 0.62
	)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var out: Array[Vector3] = []
	var nland := maxi(int(ceil(w / 0.3)), 1)
	for i in nland:
		var p := b + side * ((float(i) + 0.5) / nland - 0.5)
		out.append(p)
		_landing_feed(p, clampf(w / nland * 0.6, 0.1, 0.3), 1.0)
	return out


func _curtain(cu: Dictionary) -> Array[Vector3]:
	var c: Vector3 = cu.get("centre", Vector3.ZERO)
	var r := maxf(float(cu.get("radius", 0.5)), 0.05)
	var drop := maxf(float(cu.get("drop", 0.5)), 0.05)
	var flare := float(cu.get("flare", 0.15))
	var a0 := deg_to_rad(float(cu.get("from_deg", 0.0)))
	var a1 := deg_to_rad(float(cu.get("to_deg", 360.0)))
	var arc := (a1 - a0) * (r + flare * 0.5)
	var na := maxi(int(ceil(arc / 0.12)), 6)
	var segs := 10
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	var length := Vector2(flare, drop).length() * 1.15
	for i in na + 1:
		var a := lerpf(a0, a1, float(i) / na)
		var o := Vector3(cos(a), 0, sin(a))
		for k in segs + 1:
			var s := float(k) / segs
			var p := c + o * (r + flare * s) + Vector3(0, -drop * s * s, 0)
			var tg := (o * flare + Vector3(0, -2.0 * drop * s, 0)).normalized()
			var nrm := tg.cross(Vector3(-o.z, 0, o.x)).normalized()
			verts.append(p)
			norms.append(nrm)
			uvs.append(Vector2(float(i) / na, s))
			if i > 0 and k > 0:
				var q := i * (segs + 1) + k
				var pq := q - (segs + 1)
				idx.append_array([pq - 1, q - 1, q, pq - 1, q, pq])
	var mi := MeshInstance3D.new()
	mi.name = "Curtain"
	mi.mesh = _arrays_mesh(verts, norms, uvs, idx)
	mi.material_override = _sheet_material(
		length, arc, drop, float(cu.get("speed", 0.35)), Color(0.74, 0.92, 1.0), 0.36
	)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var out: Array[Vector3] = []
	var nland := clampi(int(ceil(arc / 0.45)), 3, 8)
	for i in nland:
		var a := lerpf(a0, a1, (float(i) + 0.5) / nland)
		var p := c + Vector3(cos(a), 0, sin(a)) * (r + flare) + Vector3(0, -drop, 0)
		out.append(p)
		_landing_feed(p, 0.16, 0.8)
	return out


func _sheet_material(
	length: float, width: float, drop: float, speed: float, col: Color, opacity: float
) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://gfx/water/water_sheet.gdshader")
	m.set_shader_parameter("length_m", maxf(length, 0.05))
	m.set_shader_parameter("width_m", maxf(width, 0.02))
	m.set_shader_parameter("drop_m", maxf(drop, 0.02))
	m.set_shader_parameter("lip_speed", speed)
	m.set_shader_parameter("color", col)
	m.set_shader_parameter("opacity", opacity)
	m.set_shader_parameter("seed", float(get_child_count()) * 7.3)
	return m


# ---------------------------------------------------------------- splashes, mist, light


func _splash_system() -> GPUParticles3D:
	var sp := GPUParticles3D.new()
	sp.name = "Splash"
	sp.amount = 320
	sp.lifetime = 0.55
	sp.fixed_fps = 60
	sp.local_coords = false
	sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sp.visibility_aabb = AABB(Vector3(-4, -2, -4), Vector3(8, 6, 8))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 50.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 1.5
	pm.gravity = Vector3(0, -GRAVITY, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	pm.color_ramp = _ramp([0.0, 0.1, 0.7, 1.0], [0.0, 1.0, 0.8, 0.0])
	sp.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.04, 0.04)
	q.material = _splash_mat
	sp.draw_pass_1 = q
	add_child(sp)
	return sp


## Droplets bouncing where the sheets land (constant, along the landing lines).
func _sheet_splash(points: Array[Vector3]) -> void:
	var sp := GPUParticles3D.new()
	sp.name = "SheetSplash"
	sp.amount = clampi(points.size() * 24, 24, 400)
	sp.lifetime = 0.5
	sp.preprocess = 0.5
	sp.fixed_fps = 60
	sp.local_coords = false
	sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sp.visibility_aabb = _bounds(points).grow(1.0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINTS
	pm.emission_point_texture = _points_texture(points)
	pm.emission_point_count = points.size()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 45.0
	pm.initial_velocity_min = 0.4
	pm.initial_velocity_max = 1.2
	pm.gravity = Vector3(0, -GRAVITY, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.1
	pm.emission_shape_scale = Vector3(1, 1, 1)
	pm.color_ramp = _ramp([0.0, 0.1, 0.7, 1.0], [0.0, 1.0, 0.8, 0.0])
	sp.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.04, 0.04)
	q.material = _splash_mat
	sp.draw_pass_1 = q
	add_child(sp)


func _mist_system(points: Array) -> void:
	var pts: Array[Vector3] = []
	for p in points:
		pts.append(p)
	var gp := GPUParticles3D.new()
	gp.name = "Mist"
	gp.amount = clampi(pts.size() * 3, 8, 48)
	gp.lifetime = 3.5
	gp.preprocess = 3.5
	gp.local_coords = false
	gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gp.visibility_aabb = _bounds(pts).grow(2.0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINTS
	pm.emission_point_texture = _points_texture(pts)
	pm.emission_point_count = pts.size()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 80.0
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.25
	pm.gravity = Vector3(0.03, 0.04, -0.01)
	pm.damping_min = 0.1
	pm.damping_max = 0.3
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.5))
	sc.add_point(Vector2(1, 1.4))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.color_ramp = _ramp([0.0, 0.25, 0.7, 1.0], [0.0, 1.0, 0.6, 0.0])
	gp.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.7, 0.7)
	var m := _drop_material(true, Color(0.9, 0.95, 1.0, 0.13))
	m.set_shader_parameter("soft", true)
	q.material = m
	gp.draw_pass_1 = q
	add_child(gp)
	_mist = gp


func _underwater_light(c: Color) -> void:
	var low: MeshInstance3D = basins[0]
	for w in basins:
		if w.position.y < low.position.y:
			low = w
	var size: Vector2 = (low.mesh as PlaneMesh).size
	light = OmniLight3D.new()
	light.name = "UnderLight"
	light.light_color = c
	light.omni_range = maxf(size.x, size.y) * 0.85 + 0.6
	light.omni_attenuation = 1.2
	light.light_specular = 0.25
	light.shadow_enabled = false
	light.position = low.position - Vector3(0, 0.2, 0)
	add_child(light)
	set_night(night)


# ---------------------------------------------------------------- helpers


func _drop_material(bb: bool, col: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://gfx/water/water_drop.gdshader")
	m.set_shader_parameter("billboard", bb)
	m.set_shader_parameter("color", col)
	return m


static func _ramp(offsets: Array, alphas: Array) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	var cols := PackedColorArray()
	for a in alphas:
		cols.append(Color(1, 1, 1, a))
	g.colors = cols
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


static func _points_texture(points: Array[Vector3]) -> ImageTexture:
	var img := Image.create(maxi(points.size(), 1), 1, false, Image.FORMAT_RGBF)
	for i in points.size():
		img.set_pixel(i, 0, Color(points[i].x, points[i].y, points[i].z))
	return ImageTexture.create_from_image(img)


static func _bounds(points: Array[Vector3]) -> AABB:
	if points.is_empty():
		return AABB(Vector3(-1, -1, -1), Vector3(2, 2, 2))
	var b := AABB(points[0], Vector3.ZERO)
	for p in points:
		b = b.expand(p)
	return b


static func _arrays_mesh(
	verts: PackedVector3Array,
	norms: PackedVector3Array,
	uvs: PackedVector2Array,
	idx: PackedInt32Array
) -> ArrayMesh:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


## A thin tube along `pts` (radius r0 at the start, r1 at the end), UV.x around, UV.y along.
static func _tube(pts: PackedVector3Array, r0: float, r1: float) -> ArrayMesh:
	var sides := 6
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	for i in pts.size():
		var tg := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var ax := tg.cross(Vector3.FORWARD if absf(tg.z) < 0.9 else Vector3.RIGHT).normalized()
		var ay := tg.cross(ax).normalized()
		var s := float(i) / (pts.size() - 1)
		var r := lerpf(r0, r1, s)
		for k in sides + 1:
			var a := TAU * float(k) / sides
			var n := ax * cos(a) + ay * sin(a)
			verts.append(pts[i] + n * r)
			norms.append(n)
			uvs.append(Vector2(float(k) / sides, s))
			if i > 0 and k > 0:
				var q := i * (sides + 1) + k
				var pq := q - (sides + 1)
				idx.append_array([pq - 1, q - 1, q, pq - 1, q, pq])
	return _arrays_mesh(verts, norms, uvs, idx)

extends SceneTree
## Headless: godot --headless --path . --script res://tests/gfx/test_water.gd
## Water (docs/VOXEL.md, "Water"): the three water shaders load and read the weather / sky globals,
## WaterSurface.make / material defaults and per-kind presets, option mapping, ripple sources,
## freeze and set_param, scale safety (scaling the node never touches a uniform; the shader reads
## the scale from MODEL_MATRIX), FountainFx node building (basins, catch boxes, jets with splash
## sub-emitters, sheets, curtains, mist, underwater light), ripples fed to its basins and to an
## outside surface, night light through the "night_lights" group and TimeOfDay, re-setup, and a
## few frames with everything in the tree.

const SHADERS := [
	"res://gfx/water/water.gdshader",
	"res://gfx/water/water_sheet.gdshader",
	"res://gfx/water/water_drop.gdshader",
]
const GLOBALS := [
	"sun_dir_world",
	"sun_color_world",
	"sun_amount",
	"sky_top_color",
	"sky_horizon_color",
	"rain_amount",
	"snow_cover",
	"lightning_flash",
	"wind_dir",
	"wind_gust",
]

var _fails := 0


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	print(("ok   " if cond else "FAIL ") + what)
	if not cond:
		_fails += 1


## A uniform of a surface, or the shader default when the material leaves it unset.
func _p(w: Object, param: String) -> Variant:
	var m := WaterSurface.material_of(w)
	var v: Variant = m.get_shader_parameter(param)
	if v == null:
		v = RenderingServer.shader_get_parameter_default(m.shader.get_rid(), param)
	return v


func _same(a: Variant, b: Variant) -> bool:
	if a == null or b == null:
		return a == b
	if a is float or b is float:
		return is_equal_approx(float(a), float(b))
	if a is Color and b is Color:
		return (a as Color).is_equal_approx(b)
	if a is Vector3 and b is Vector3:
		return (a as Vector3).is_equal_approx(b)
	return a == b


func _named(parent: Node, prefix: String) -> Array:
	var out := []
	for c in parent.get_children():
		if str(c.name).begins_with(prefix):
			out.append(c)
	return out


func _of_class(parent: Node, cls: String) -> Array:
	var out := []
	for c in parent.get_children():
		if c.is_class(cls):
			out.append(c)
	return out


func _run() -> void:
	_shaders()
	_surface()
	_options()
	_ripples()
	_scale()
	await _fountain()
	print("FALHAS: %d" % _fails)
	quit(1 if _fails else 0)


func _shaders() -> void:
	for path in SHADERS:
		var sh: Shader = load(path)
		check(sh != null and sh.get_mode() == Shader.MODE_SPATIAL, "shader loads: " + path)
	var code := WaterSurface.shader().code
	check(code.contains("hint_screen_texture"), "water refracts the screen copy")
	check(code.contains("hint_depth_texture"), "water reads the depth (foam, absorption, SSR)")
	for gname in GLOBALS:
		check(
			code.contains("global uniform") and code.contains(gname), "water reads global " + gname
		)
	# Every preset key is a real uniform.
	var names := {}
	for u in WaterSurface.shader().get_shader_uniform_list():
		names[u.name] = true
	var missing := []
	for kind in WaterSurface.PRESETS:
		for k in WaterSurface.PRESETS[kind]:
			if not names.has(k):
				missing.append("%s.%s" % [kind, k])
	check(missing.is_empty(), "preset keys are uniforms %s" % [missing])
	for k in ["ripple_src", "ripple_count", "freeze", "size", "shape", "pixel", "debug_view"]:
		check(names.has(k), "uniform " + k)


func _surface() -> void:
	var w := WaterSurface.make(Vector2(3, 2))
	check(w is MeshInstance3D and w.mesh is PlaneMesh, "make: a plane mesh")
	check((w.mesh as PlaneMesh).size == Vector2(3, 2), "make: size in metres on x/z")
	var m := WaterSurface.material_of(w)
	check(m != null and m.shader == WaterSurface.shader(), "make: water material")
	check(
		m.render_priority == WaterSurface.RENDER_PRIORITY, "water draws before other transparents"
	)
	check(_p(w, "kind") == 0 and w.get_meta("water_kind") == "pond", "default kind pond")
	check(_p(w, "size") == Vector2(3, 2), "size uniform is the local size")
	check(_same(_p(w, "depth_hint"), 1.0), "default depth 1 m")
	check(_same(_p(w, "pixel"), VoxelMat.DETAIL), "voxel pixel grid on by default")
	check(_p(w, "shape") == 0, "default shape rect")
	check(w.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "no shadow casting")
	if ResourceLoader.exists(WaterSurface.LEAF):
		check(_p(w, "leaf_tex") != null, "Pixel Lab leaf texture bound")
	var w2 := WaterSurface.make(Vector2(3, 2))
	check(_same(_p(w, "seed"), _p(w2, "seed")), "seed is deterministic")
	w.free()
	w2.free()
	for i in WaterSurface.KINDS.size():
		var kind: String = WaterSurface.KINDS[i]
		var wk := WaterSurface.make(Vector2(2, 2), {"kind": kind})
		var ok: bool = _p(wk, "kind") == i and wk.get_meta("water_kind") == kind
		var preset: Dictionary = WaterSurface.PRESETS[kind]
		for k in preset:
			ok = ok and _same(_p(wk, k), preset[k])
		check(ok, "kind %s: index and preset" % kind)
		wk.free()
	var pud := WaterSurface.make(Vector2(1, 1), {"kind": "puddle"})
	check(_same(_p(pud, "depth_hint"), 0.05), "puddles default to 5 cm")
	pud.free()
	var bad := WaterSurface.make(Vector2(1, 1), {"kind": "lava"})
	check(_p(bad, "kind") == 0 and bad.get_meta("water_kind") == "pond", "unknown kind -> pond")
	bad.free()


func _options() -> void:
	var tint := Color(0.1, 0.2, 0.3)
	var m := (
		WaterSurface
		. material(
			{
				"kind": "stream",
				"flow": Vector2(0, 0.7),
				"depth": 0.35,
				"tint": tint,
				"shape": "ellipse",
				"pixel": false,
				"life": false,
				"freeze": 2.0,
				"ssr_steps": 8,
				"seed": 3.5,
				"params": {"wave_amp": 0.5, "fish_count": 2},
			}
		)
	)
	check(m.get_shader_parameter("flow") == Vector2(0, 0.7), "flow")
	check(_same(m.get_shader_parameter("depth_hint"), 0.35), "depth -> depth_hint")
	check(_same(m.get_shader_parameter("deep_color"), tint), "tint -> deep_color")
	check(m.get_shader_parameter("shape") == 1, "ellipse shape")
	check(_same(m.get_shader_parameter("pixel"), 0.0), "pixel false -> smooth")
	check(
		(
			_same(m.get_shader_parameter("leaf_density"), 0.0)
			and _same(m.get_shader_parameter("petal_density"), 0.0)
		),
		"life false clears leaves and petals"
	)
	check(m.get_shader_parameter("fish_count") == 2, "params override life (applied last)")
	check(_same(m.get_shader_parameter("wave_amp"), 0.5), "params override the preset")
	check(_same(m.get_shader_parameter("freeze"), 1.0), "freeze clamped to 1")
	check(m.get_shader_parameter("ssr_steps") == 8, "ssr_steps")
	check(_same(m.get_shader_parameter("seed"), 3.5), "seed")
	var m2 := WaterSurface.material({"pixel": 0.125, "fish": 9, "shape": "disc", "leaves": 0.3})
	check(_same(m2.get_shader_parameter("pixel"), 0.125), "pixel grid in metres")
	check(m2.get_shader_parameter("fish_count") == 4, "fish clamped to 4")
	check(m2.get_shader_parameter("shape") == 1, "disc = ellipse")
	check(_same(m2.get_shader_parameter("leaf_density"), 0.3), "leaves density")
	check(WaterSurface.material_of(m2) == m2, "material_of(material)")
	var n := Node3D.new()
	check(WaterSurface.material_of(n) == null, "material_of(non-geometry) = null")
	n.free()


func _ripples() -> void:
	var w := WaterSurface.make(Vector2(4, 4))
	(
		WaterSurface
		. set_ripples(
			w,
			[
				{"pos": Vector3(0.5, 0, -0.25), "radius": 0.3, "strength": 1.5},
				Vector4(1, 2, 3, 4),
				{"pos": Vector2(0.1, 0.2)},
			]
		)
	)
	var src: PackedVector4Array = _p(w, "ripple_src")
	check(_p(w, "ripple_count") == 3, "3 ripple sources")
	check(src.size() == WaterSurface.MAX_RIPPLES, "ripple array padded to MAX_RIPPLES")
	check(src[0].is_equal_approx(Vector4(0.5, -0.25, 0.3, 1.5)), "Vector3 pos -> local x/z")
	check(src[1] == Vector4(1, 2, 3, 4), "Vector4 source as is")
	check(
		src[2].is_equal_approx(Vector4(0.1, 0.2, 0.2, 1.0)), "Vector2 pos, default radius/strength"
	)
	var many := []
	for i in 20:
		many.append(Vector4(i, 0, 0.2, 1))
	WaterSurface.set_ripples(w, many)
	check(_p(w, "ripple_count") == WaterSurface.MAX_RIPPLES, "ripples capped")
	WaterSurface.set_ripples(w, [])
	check(_p(w, "ripple_count") == 0, "empty array clears ripples")
	var m := WaterSurface.material({"ripples": [Vector4(0, 0, 0.1, 1)]})
	check(m.get_shader_parameter("ripple_count") == 1, "ripples option")
	WaterSurface.set_freeze(w, -1.0)
	check(_same(_p(w, "freeze"), 0.0), "set_freeze clamps")
	WaterSurface.set_freeze(w, 0.4)
	check(_same(_p(w, "freeze"), 0.4), "set_freeze")
	WaterSurface.set_param(w, "debug_view", 2)
	check(_p(w, "debug_view") == 2, "set_param")
	w.free()


## A battle pond grows / shrinks with node.scale: no uniform may depend on it (the shader reads
## the scale from MODEL_MATRIX and draws its patterns in world metres).
func _scale() -> void:
	var w := WaterSurface.make(Vector2(3.6, 3.6), {"kind": "pond", "shape": "ellipse"})
	var before := {}
	for u in WaterSurface.shader().get_shader_uniform_list():
		before[u.name] = _p(w, u.name)
	w.scale = Vector3(0.8, 1, 0.8)
	w.scale = Vector3(1.3, 1, 1.3)
	var same := true
	for k in before:
		same = same and _same(before[k], _p(w, k))
	check(same, "scaling the node changes no uniform")
	var code := WaterSurface.shader().code
	check(
		code.contains("MODEL_MATRIX[0].xyz") and code.contains("inverse(mat3(MODEL_MATRIX))"),
		"shader reads the node scale"
	)
	w.free()


func _fountain() -> void:
	var root := Node3D.new()
	get_root().add_child(root)
	var pond := WaterSurface.make(Vector2(6, 6))
	pond.position = Vector3(1, -0.12, 5)
	root.add_child(pond)
	var fx := FountainFx.new()
	fx.position = Vector3(1, 0, 0)
	root.add_child(fx)
	check(fx.is_in_group("night_lights"), "FountainFx joins night_lights")
	(
		fx
		. setup(
			{
				"basins":
				[
					{"pos": Vector3(0, 0.38, 0), "size": Vector2(3.25, 3.25), "depth": 0.6},
					{"pos": Vector3(0, 1.4, 0), "size": Vector2(1.75, 1.75), "depth": 0.4},
				],
				"jets":
				[
					{"pos": Vector3(0, 1.5, 0), "height": 0.75, "count": 1},
					{
						"pos": Vector3(0, 0.55, 0),
						"height": 0.42,
						"count": 6,
						"radius": 1.6,
						"reach": -0.9
					},
				],
				"sheets":
				[{"from": Vector3(0, 1.3, 1.0), "to": Vector3(0, 0.38, 1.34), "width": 0.42}],
				"curtains": [{"centre": Vector3(0, 1.5, 0), "radius": 0.55, "drop": 0.84}],
				"light": Color(0.6, 0.9, 1.0),
				"mist": true,
			}
		)
	)
	check(fx.basins.size() == 2, "two basins")
	var basins_ok := true
	for b in fx.basins:
		basins_ok = (
			basins_ok and b.get_parent() == fx and _p(b, "kind") == 1 and _p(b, "shape") == 1
		)
	check(basins_ok, "basins: fountain water, ellipse by default")
	check(_of_class(fx, "GPUParticlesCollisionBox3D").size() == 2, "a catch box per basin")
	var jets := _named(fx, "Jet").filter(func(n: Node) -> bool: return n is GPUParticles3D)
	check(jets.size() == 2, "a particle system per jet (%d)" % jets.size())
	var jets_ok := true
	for j: GPUParticles3D in jets:
		var pm := j.process_material as ParticleProcessMaterial
		jets_ok = (
			jets_ok
			and j.amount >= 16
			and j.amount <= 1500
			and j.transform_align == GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
			and pm != null
			and pm.collision_mode == ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT
			and pm.sub_emitter_mode == ParticleProcessMaterial.SUB_EMITTER_AT_COLLISION
			and not j.sub_emitter.is_empty()
			and j.get_node_or_null(j.sub_emitter) is GPUParticles3D
		)
	check(jets_ok, "jets: streaks along velocity, die on the water, splash sub-emitter")
	check(fx.get_node_or_null("Splash") is GPUParticles3D, "splash droplets")
	check(fx.get_node_or_null("SheetSplash") is GPUParticles3D, "splash under sheets")
	check(fx.get_node_or_null("Mist") is GPUParticles3D, "mist")
	check(not _named(fx, "JetCore").is_empty(), "glassy core for the tall single jet")
	check(not _named(fx, "Sheet").is_empty(), "falling sheet mesh")
	check(not _named(fx, "Curtain").is_empty(), "curtain mesh")
	check(fx.light != null and fx.get_node_or_null("UnderLight") == fx.light, "underwater light")
	check(int(_p(fx.basins[0], "ripple_count")) > 0, "landings feed the lower basin")
	# Night light.
	fx.set_night(1.0)
	check(
		fx.light.visible and is_equal_approx(fx.light.light_energy, FountainFx.LIGHT_ENERGY),
		"night on"
	)
	fx.get_tree().call_group("night_lights", "set_period_mult", 0.0, 0.0)
	check(not fx.light.visible and fx.night == 0.0, "night_lights group dims the light")
	# A cascade feeding an outside surface (the pond below it).
	var cascade := FountainFx.new()
	cascade.position = Vector3(1, 0.38, 0.5)
	root.add_child(cascade)
	(
		cascade
		. setup(
			{
				"sheets":
				[{"from": Vector3(0, 0, 1.5), "to": Vector3(0, -0.5, 1.95), "width": 1.3}],
				"surfaces": [pond],
			}
		)
	)
	var pc := int(_p(pond, "ripple_count"))
	var src: PackedVector4Array = _p(pond, "ripple_src")
	var inside := pc > 0
	for i in pc:
		inside = inside and absf(src[i].x) <= 3.0 and absf(src[i].y) <= 3.0
	check(inside, "cascade feeds the pond in its local space (%d sources)" % pc)
	# TimeOfDay already in the tree: a new fountain picks up its lamp multiplier on _ready.
	var gs := GDScript.new()
	gs.source_code = ('extends Node\nfunc night_mult() -> Dictionary:\n\treturn {"lamps": 0.7, "windows": 0.5}\n')
	gs.reload()
	var tod := Node.new()
	tod.set_script(gs)
	tod.add_to_group("time_of_day")
	root.add_child(tod)
	var fx2 := FountainFx.new()
	fx2.setup({"basins": [{"size": Vector2(1, 1)}], "light": Color.CYAN})
	root.add_child(fx2)
	check(
		is_equal_approx(fx2.night, 0.7) and fx2.light.visible, "reads TimeOfDay night_mult on ready"
	)
	# A few frames with everything in the tree (shaders, particles, collisions).
	var cam := Camera3D.new()
	cam.position = Vector3(1, 6, 9)
	root.add_child(cam)
	cam.look_at(Vector3(1, 0, 1))
	for i in 5:
		await process_frame
	# Re-setup replaces the old nodes.
	fx.setup({"basins": [{"pos": Vector3(0, 0.38, 0), "size": Vector2(2, 2)}]})
	await process_frame
	check(fx.basins.size() == 1 and fx.light == null, "re-setup: one basin, no light")
	check(
		_named(fx, "Jet").is_empty() and _of_class(fx, "GPUParticles3D").is_empty(),
		"re-setup clears jets"
	)
	# Jets alone (no basin) still build.
	var fx3 := FountainFx.new()
	root.add_child(fx3)
	fx3.setup({"jets": [{"pos": Vector3.ZERO, "height": 0.5}]})
	check(_of_class(fx3, "GPUParticles3D").size() >= 2, "jets without basins (jet + splash)")
	for i in 3:
		await process_frame
	root.queue_free()
	await process_frame

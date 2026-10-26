class_name WaterSurface
extends RefCounted
## Water surfaces shared by the overworld (ponds, fountain basins, streams) and the battle arenas
## (docs/VOXEL.md, "Water"). The surface is a flat quad at local y = 0 over a voxel bed carved below
## it (VoxelMat.BED); gfx/water/water.gdshader reads the depth and screen textures for refraction,
## Beer-Lambert absorption, shore foam (it follows the voxel steps of the bed), caustics on the bed,
## a screen-space reflection with the sky globals as fallback, and the weather globals (rain rings,
## wind ripples, lightning, frost with snow). Life: fish gliding under the surface (now and then one
## breaks it with rings), floating leaves and petals, sun sparkles.
## API (stable):
##   make(size, opts) -> MeshInstance3D   size = metres along x/z, centred on the node origin
##   material(opts) -> ShaderMaterial     (make() uses it; one material per surface)
##   opts: kind ("pond" | "fountain" | "stream" | "sea" | "puddle"), flow (Vector2 world m/s,
##     streams), depth (m, typical bed depth, tunes absorption), tint (Color, deep water colour),
##     shape ("rect" | "ellipse": the ellipse inscribed in `size`, stepped on the 0.25 m voxel
##     columns), pixel (true / false or a grid in metres: the 1/16 m "voxel pixel" look, default
##     on), life (false = no fish / leaves / petals), fish (int 0..4), leaves, petals (0..1 density
##     per 1.7 m cell), freeze (0..1), seed (float), ssr_steps (int, 0 = sky reflection only),
##     ripples (see set_ripples), params ({uniform: value} overrides, applied last).
##   set_ripples(surface, sources)   agitation spots: [{pos: Vector3 local, radius: m, strength}]
##   set_freeze(surface, amount)     ice from the shallows (0) to the whole surface (1)
##   set_param(surface, name, value) any water.gdshader uniform
## Scaling: ripples, foam, caustics, sparkles, leaves and the voxel-pixel grid live in world metres,
## so `node.scale = Vector3(k, 1, k)` (a battle pond growing in rain or drying in sun) grows or
## shrinks the water without stretching any pattern; only the ellipse outline, the fish paths and
## the ripple-source positions follow the node. Keep the bed carved for the largest size: where the
## scaled surface no longer covers it, the dry bed shows. Never overlap two surfaces (both read the
## same screen copy); one surface per pond. The water draws before other transparent objects
## (render_priority RENDER_PRIORITY) and writes depth, so splashes and particles above it blend on
## top and anything below it is hidden.

const KINDS := ["pond", "fountain", "stream", "sea", "puddle"]
const MAX_RIPPLES := 12
const RENDER_PRIORITY := -1
const LEAF := "res://assets/pixellab/fx/leaf.png"

## Per-kind uniform values (water.gdshader); opts and opts.params override them.
const PRESETS := {
	"pond":
	{
		"fish_count": 3,
		"leaf_density": 0.07,
		"petal_density": 0.05,
		"wave_amp": 1.0,
		"chop": 1.0,
		"foam_width": 0.2,
		"caustic_strength": 1.4,
	},
	"fountain":
	{
		"deep_color": Color(0.03, 0.33, 0.38),
		"absorb": Vector3(1.05, 0.3, 0.26),
		"wave_amp": 1.15,
		"wave_scale": 1.6,
		"chop": 1.7,
		"foam_width": 0.1,
		"caustic_strength": 1.8,
		"caustic_scale": 2.8,
		"petal_density": 0.05,
		"fish_jump": 0.0,
	},
	"stream":
	{
		"wave_amp": 1.3,
		"wave_scale": 1.2,
		"foam_width": 0.16,
		"refract_strength": 0.4,
		"leaf_density": 0.06,
		"caustic_strength": 1.8,
		"fish_jump": 0.0,
	},
	"sea":
	{
		"deep_color": Color(0.02, 0.14, 0.28),
		"absorb": Vector3(0.9, 0.22, 0.13),
		"swell": 1.0,
		"wave_amp": 1.4,
		"wave_scale": 0.6,
		"foam_width": 0.32,
		"caustic_scale": 1.3,
		"reflect_strength": 1.2,
	},
	"puddle":
	{
		"deep_color": Color(0.16, 0.15, 0.13),
		"absorb": Vector3(0.6, 0.5, 0.45),
		"body_light": 0.25,
		"wave_amp": 0.25,
		"chop": 0.6,
		"refract_strength": 0.08,
		"reflect_strength": 1.6,
		"foam_amount": 0.0,
		"caustic_strength": 0.0,
		"murk_blur": 0.0,
		"fish_jump": 0.0,
	},
}

static var _shader: Shader
static var _leaf: Texture2D


static func shader() -> Shader:
	if _shader == null:
		_shader = load("res://gfx/water/water.gdshader")
	return _shader


static func leaf_texture() -> Texture2D:
	if _leaf == null and ResourceLoader.exists(LEAF):
		_leaf = load(LEAF)
	return _leaf


static func material(opts := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader()
	m.render_priority = RENDER_PRIORITY
	var kind := str(opts.get("kind", "pond"))
	if not kind in KINDS:
		push_warning("WaterSurface: tipo de água desconhecido '%s', usando pond" % kind)
		kind = "pond"
	m.set_shader_parameter("kind", KINDS.find(kind))
	var preset: Dictionary = PRESETS[kind]
	for k in preset:
		m.set_shader_parameter(k, preset[k])
	var depth := float(opts.get("depth", 0.05 if kind == "puddle" else 1.0))
	m.set_shader_parameter("depth_hint", depth)
	var flow: Vector2 = opts.get("flow", Vector2.ZERO)
	m.set_shader_parameter("flow", flow)
	if opts.has("tint"):
		m.set_shader_parameter("deep_color", opts.tint)
	var shp := str(opts.get("shape", "rect"))
	m.set_shader_parameter("shape", 1 if shp in ["ellipse", "disc", "circle"] else 0)
	var px: Variant = opts.get("pixel", true)
	var grid := (VoxelMat.DETAIL if px else 0.0) if typeof(px) == TYPE_BOOL else float(px)
	m.set_shader_parameter("pixel", grid)
	if not bool(opts.get("life", true)):
		for k in ["fish_count", "leaf_density", "petal_density"]:
			m.set_shader_parameter(k, 0)
	if opts.has("fish"):
		m.set_shader_parameter("fish_count", clampi(int(opts.fish), 0, 4))
	if opts.has("leaves"):
		m.set_shader_parameter("leaf_density", float(opts.leaves))
	if opts.has("petals"):
		m.set_shader_parameter("petal_density", float(opts.petals))
	if opts.has("freeze"):
		m.set_shader_parameter("freeze", clampf(float(opts.freeze), 0.0, 1.0))
	if opts.has("ssr_steps"):
		m.set_shader_parameter("ssr_steps", int(opts.ssr_steps))
	m.set_shader_parameter("seed", float(opts.get("seed", 0.0)))
	var leaf := leaf_texture()
	if leaf:
		m.set_shader_parameter("leaf_tex", leaf)
	if opts.has("ripples"):
		_ripples_on(m, opts.ripples)
	var params: Dictionary = opts.get("params", {})
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m


static func make(size: Vector2, opts := {}) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "WaterSurface"
	var pm := PlaneMesh.new()
	pm.size = size
	mi.mesh = pm
	var o := opts.duplicate()
	if not o.has("seed"):
		o.seed = float(absi(hash([size, str(opts.get("kind", "pond"))])) % 997) * 0.37
	var m := material(o)
	m.set_shader_parameter("size", size)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mi.set_meta("water_kind", KINDS[int(m.get_shader_parameter("kind"))])
	return mi


## Material of a surface made by make() (or the material itself).
static func material_of(target: Object) -> ShaderMaterial:
	if target is ShaderMaterial:
		return target
	if target is GeometryInstance3D:
		return (target as GeometryInstance3D).material_override as ShaderMaterial
	return null


static func set_param(target: Object, param: String, value: Variant) -> void:
	var m := material_of(target)
	if m:
		m.set_shader_parameter(param, value)


## Ice from the shallows (small amounts) to the whole surface (1).
static func set_freeze(target: Object, amount: float) -> void:
	set_param(target, "freeze", clampf(amount, 0.0, 1.0))


## Agitation spots in the surface's local space (jets landing, a cascade, a Pokémon splashing):
## each source is {pos: Vector3 | Vector2 (local x/z), radius: m (turbulent core), strength: 0..2}
## or a Vector4(x, z, radius, strength). At most MAX_RIPPLES; an empty array clears them.
static func set_ripples(target: Object, sources: Array) -> void:
	var m := material_of(target)
	if m:
		_ripples_on(m, sources)


static func _ripples_on(m: ShaderMaterial, sources: Array) -> void:
	var arr := PackedVector4Array()
	for s in sources:
		if arr.size() >= MAX_RIPPLES:
			break
		if s is Vector4:
			arr.append(s)
			continue
		var d: Dictionary = s
		var p = d.get("pos", Vector3.ZERO)
		var xz := Vector2(p.x, p.z) if p is Vector3 else Vector2(p)
		arr.append(Vector4(xz.x, xz.y, float(d.get("radius", 0.2)), float(d.get("strength", 1.0))))
	var n := arr.size()
	arr.resize(MAX_RIPPLES)
	m.set_shader_parameter("ripple_src", arr)
	m.set_shader_parameter("ripple_count", n)

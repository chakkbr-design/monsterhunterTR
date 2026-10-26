class_name WaterSurface
extends RefCounted
## Water surfaces shared by the overworld (ponds, fountain basins, streams) and the battle arenas
## (docs/VOXEL.md, "Water"). The surface is a flat quad at local y = 0 over a voxel bed carved below
## it; gfx/water/water.gdshader reads the depth and screen textures for refraction, absorption,
## shore foam and caustics, and the weather globals for rain rings.
## API (stable, the water work replaces the internals):
##   make(size, opts) -> MeshInstance3D   size = metres along x/z, centred on the node origin
##   opts: kind ("pond" | "fountain" | "stream" | "sea" | "puddle"), flow (Vector2 m/s for
##   streams), depth (m, typical bed depth, tunes absorption), tint (Color, optional)

const KINDS := ["pond", "fountain", "stream", "sea", "puddle"]

static var _shader: Shader


static func shader() -> Shader:
	if _shader == null:
		_shader = load("res://gfx/water/water.gdshader")
	return _shader


static func material(opts := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader()
	var flow: Vector2 = opts.get("flow", Vector2.ZERO)
	m.set_shader_parameter("flow", flow)
	m.set_shader_parameter("depth_hint", float(opts.get("depth", 1.0)))
	if opts.has("tint"):
		m.set_shader_parameter("tint", opts.tint)
	return m


static func make(size: Vector2, opts := {}) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "WaterSurface"
	var pm := PlaneMesh.new()
	pm.size = size
	mi.mesh = pm
	mi.material_override = material(opts)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("water_kind", str(opts.get("kind", "pond")))
	return mi

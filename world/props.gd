class_name WorldProps
extends RefCounted
## Port of the original scripts/world/props.gd: instances the extracted HGSS / Kenney models
## (res://original/assets/models/*.scn) with the original's material treatment: HGSS foliage cards
## become camera-facing billboards (hgss_foliage shader), lamp glow cards are additive, HGSS window
## texels glow at night (NightLights), Kenney props get the pixel "stylize" shader and palettes.
## Visual only: callers keep their own collision (MapBuilder keeps the placeholder colliders).

const NATURE_PALETTE := {
	"leafsGreen": Color(0.33, 0.62, 0.27),
	"leafsDark": Color(0.2, 0.45, 0.2),
	"leafsFall": Color(0.85, 0.55, 0.25),
	"grass": Color(0.45, 0.72, 0.3),
	"woodBark": Color(0.45, 0.31, 0.22),
	"woodBarkDark": Color(0.35, 0.24, 0.17),
	"wood": Color(0.82, 0.62, 0.42),
	"woodDark": Color(0.62, 0.45, 0.31),
	"dirt": Color(0.6, 0.47, 0.33),
	"stone": Color(0.62, 0.63, 0.66),
	"stoneDark": Color(0.45, 0.46, 0.5),
}
const GLOW_ALPHA := 0.35
const WINDOW_COLOR := Color(1.0, 0.5, 0.15)
const WINDOW_MIN_COVER := 0.6
const CELL := 8.0

static var _scenes := {}
static var _mats := {}
static var _masks := {}
static var _cells := {}


static func path_of(id: String) -> String:
	return (
		WorldFx.MODELS
		+ (id if id.begins_with("hgss/") or id.begins_with("kenney/") else "kenney/" + id)
		+ ".scn"
	)


static func exists(id: String) -> bool:
	return ResourceLoader.exists(path_of(id))


static func scene(id: String) -> PackedScene:
	var p := path_of(id)
	if not _scenes.has(p):
		_scenes[p] = load(p) if ResourceLoader.exists(p) else null
	return _scenes[p]


static func meshes(n: Node) -> Array:
	var out: Array = []
	var stack: Array = [n]
	while not stack.is_empty():
		var c = stack.pop_back()
		if c is MeshInstance3D:
			out.append(c)
		stack.append_array(c.get_children())
	return out


## World AABB of every mesh under n (n must be in the tree, or pass local=true for n-relative).
static func bounds(n: Node3D, local := false) -> AABB:
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in meshes(n):
		var xf: Transform3D
		if local:
			xf = Transform3D()
			var p: Node = mi
			while p != n and p != null:
				xf = (p as Node3D).transform * xf
				p = p.get_parent()
		else:
			xf = mi.global_transform
		var b: AABB = xf * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


# --- faders (camera_rig fades buildings / terraces that hide the player) -------------------------


static func register_fader(n: Node3D, rect: Rect2) -> void:
	var a := Vector2i(floori(rect.position.x / CELL), floori(rect.position.y / CELL))
	var b := Vector2i(floori(rect.end.x / CELL), floori(rect.end.y / CELL))
	for cx in range(a.x, b.x + 1):
		for cz in range(a.y, b.y + 1):
			var k := Vector2i(cx, cz)
			if not _cells.has(k):
				_cells[k] = []
			_cells[k].append(n)


static func faders_near(p: Vector3, radius: float) -> Array:
	var out := {}
	var a := Vector2i(floori((p.x - radius) / CELL), floori((p.z - radius) / CELL))
	var b := Vector2i(floori((p.x + radius) / CELL), floori((p.z + radius) / CELL))
	for cx in range(a.x, b.x + 1):
		for cz in range(a.y, b.y + 1):
			var arr: Array = _cells.get(Vector2i(cx, cz), [])
			for i in range(arr.size() - 1, -1, -1):
				if not is_instance_valid(arr[i]):
					arr.remove_at(i)
				else:
					out[arr[i]] = true
	return out.keys()


# --- materials -----------------------------------------------------------------------------------


static func hgss_material(
	m: Material, billboard := false, tint := Color.WHITE, windows := false, sway := 0.04
) -> Material:
	var sm := m as StandardMaterial3D
	if sm == null:
		return m
	var key := "hgss|%d|%s|%s|%s|%s" % [sm.get_instance_id(), billboard, tint, windows, sway]
	if _mats.has(key):
		return _mats[key]
	var res: Material
	var nm := String(sm.resource_name).to_lower()
	if nm.contains("_sl3"):  # lamp glow card
		var gm := WorldFx.shader_mat(
			"hgss_lamp_glow", {"glow_tex": sm.albedo_texture, "glow_alpha": GLOW_ALPHA}
		)
		gm.resource_name = sm.resource_name
		res = gm
	elif billboard and not nm.contains("_un"):
		res = WorldFx.shader_mat(
			"hgss_foliage", {"albedo_tex": sm.albedo_texture, "tint": tint, "sway": sway}
		)
	else:
		var out := sm.duplicate() as StandardMaterial3D
		out.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		out.albedo_color = tint
		if windows and not nm.contains("door") and not nm.contains("_dr0"):
			var mask := _window_mask(sm.albedo_texture)
			if mask:
				out.emission_enabled = true
				out.emission_texture = mask
				out.emission = WINDOW_COLOR
				out.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
				out.emission_energy_multiplier = 0.0
				out.set_meta("window_glow", true)
		res = out
	_mats[key] = res
	return res


static func kenney_material(m: Material, palette := {}, stylize := true) -> Material:
	var sm := m as StandardMaterial3D
	if sm == null:
		return m
	var key := "k|%d|%s|%s" % [sm.get_instance_id(), str(palette), stylize]
	if _mats.has(key):
		return _mats[key]
	var nm := String(sm.resource_name)
	var out := sm
	if palette.get(nm) is Material:
		_mats[key] = palette[nm]
		return palette[nm]
	if palette.has(nm) or NATURE_PALETTE.has(nm):
		out = sm.duplicate()
		out.albedo_color = palette.get(nm, NATURE_PALETTE.get(nm))
		out.roughness = 0.9
	var res: Material = out
	if stylize:
		var s := WorldFx.shader_mat(
			"prop_stylize", {"albedo": out.albedo_color, "is_foliage": nm.begins_with("leafs")}
		)
		s.resource_name = nm
		if out.albedo_texture:
			s.set_shader_parameter("use_tex", true)
			s.set_shader_parameter("albedo_tex", out.albedo_texture)
		res = s
	_mats[key] = res
	return res


static func _window_mask(tex: Texture2D) -> ImageTexture:
	if tex == null:
		return null
	if _masks.has(tex):
		return _masks[tex]
	var img := tex.get_image()
	if img == null or img.is_empty():
		_masks[tex] = null
		return null
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var seed := false
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			if (
				c.a >= 0.5
				and c.b - c.r >= 0.078
				and c.b - c.g >= 0.059
				and maxf(c.r, maxf(c.g, c.b)) >= 0.55
			):
				seed = true
				break
		if seed:
			break
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	out.fill(Color.BLACK)
	var lit := 0
	var tot := 0
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			if c.a < 0.5:
				continue
			tot += 1
			var mx := maxf(c.r, maxf(c.g, c.b))
			var mn := minf(c.r, minf(c.g, c.b))
			var blue := c.b - c.r >= 0.078 and c.b - c.g >= 0.059 and mx >= 0.55
			var white := seed and mx >= 0.9 and mx - mn <= 0.078
			if blue or white:
				out.set_pixel(x, y, Color.WHITE)
				lit += 1
	if tot == 0 or float(lit) / float(tot) < WINDOW_MIN_COVER:
		_masks[tex] = null
		return null
	var it := ImageTexture.create_from_image(out)
	_masks[tex] = it
	return it


# --- placement -----------------------------------------------------------------------------------


## Instances model `id` under parent at pos. opts: scale, rot (deg), billboard, tint, sway, windows,
## palette, stylize, shadow (bool), vis_range, light (lamp OmniLight), fade ("building").
static func place(parent: Node, id: String, pos: Vector3, opts := {}) -> Node3D:
	var ps := scene(id)
	if ps == null:
		return null
	var inst: Node3D = ps.instantiate()
	inst.name = id.get_file().validate_node_name()
	parent.add_child(inst)
	inst.scale = Vector3.ONE * float(opts.get("scale", 1.0))
	inst.rotation_degrees.y = float(opts.get("rot", 0.0))
	inst.global_position = pos
	var hgss := id.begins_with("hgss/")
	var geoms: Array = []
	var window_mats: Array = []
	for mi: MeshInstance3D in meshes(inst):
		for i in mi.mesh.get_surface_count():
			var m := mi.get_active_material(i)
			var r: Material
			if hgss:
				r = hgss_material(
					m,
					bool(opts.get("billboard", false)),
					opts.get("tint", Color.WHITE),
					bool(opts.get("windows", false)),
					float(opts.get("sway", 0.04))
				)
			else:
				r = kenney_material(m, opts.get("palette", {}), bool(opts.get("stylize", true)))
			if r != m:
				mi.set_surface_override_material(i, r)
			if r != null and r.has_meta("window_glow"):
				window_mats.append(r)
		if not bool(opts.get("shadow", true)):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var vr := float(opts.get("vis_range", 0.0))
		if vr > 0.0:
			mi.visibility_range_end = vr
			mi.visibility_range_end_margin = 4.0
			mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		geoms.append(mi)
	inst.set_meta("geoms", geoms)
	if String(opts.get("fade", "")) == "building":
		var bb := bounds(inst)
		var rect := Rect2(bb.position.x, bb.position.z, bb.size.x, bb.size.z)
		inst.add_to_group("fade_building")
		inst.set_meta("rect", rect)
		inst.set_meta("height", bb.size.y)
		register_fader(inst, rect)
	if bool(opts.get("light", false)):
		lantern_light(parent, inst)
	if not window_mats.is_empty():
		var nw := NightLights.new()
		nw.window_mats = window_mats
		inst.add_child(nw)
	return inst


static func lantern_light(parent: Node, inst: Node3D) -> void:
	var bb := bounds(inst)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.78, 0.5)
	light.light_energy = 6.0
	light.omni_range = 6.0
	light.omni_attenuation = 0.8
	light.shadow_enabled = false
	parent.add_child(light)
	light.global_position = Vector3(
		bb.get_center().x, bb.position.y + bb.size.y * 0.88, bb.get_center().z
	)
	var nl := NightLights.new()
	nl.light = light
	parent.add_child(nl)


## One mesh (all surfaces, materials already converted) of a model, for MultiMesh batching.
## Returns [Mesh, Transform3D of the mesh inside the model] or [] when missing.
static func batch_mesh(id: String, opts := {}) -> Array:
	var key := "batch|%s|%s" % [id, str(opts)]
	if _mats.has(key):
		return _mats[key]
	var ps := scene(id)
	if ps == null:
		return []
	var src: Node3D = ps.instantiate()
	var ms := meshes(src)
	if ms.is_empty():
		src.free()
		return []
	var mi: MeshInstance3D = ms[0]
	var xf := Transform3D()
	var p: Node = mi
	while p != src and p != null:
		xf = (p as Node3D).transform * xf
		p = p.get_parent()
	var mesh: Mesh = mi.mesh.duplicate()
	for s in mesh.get_surface_count():
		var m := mi.get_active_material(s)
		var r: Material
		if id.begins_with("hgss/"):
			r = hgss_material(
				m,
				bool(opts.get("billboard", false)),
				opts.get("tint", Color.WHITE),
				false,
				float(opts.get("sway", 0.04))
			)
		else:
			r = kenney_material(m, opts.get("palette", {}), bool(opts.get("stylize", true)))
		mesh.surface_set_material(s, r)
	src.free()
	_mats[key] = [mesh, xf]
	return _mats[key]

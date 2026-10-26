class_name EdgeAA
extends CompositorEffect
## Anti-aliasing of the 3D geometry that leaves the pixel art alone (GfxQuality, docs/VOXEL.md §3).
## SMAA / FXAA / FSR 2 smear every texel staircase of the sprites, and MSAA empties the water's
## depth and screen reads, so neither fits. This runs once per frame on the opaque image (before the
## transparent pass, so the water, particles and glass on top stay as drawn):
##   1. a copy of the colour, squeezed into 0..1 (c / (1 + max(c)), reversed afterwards: blending
##      HDR values directly lets a bright lamp or sky pixel swallow its edge);
##   2. FXAA 3.11 (quality) only on pixels next to a geometric edge, found in the depth buffer (a
##      silhouette: the second difference of the depth, which is zero across any flat face) or in the
##      normals (a crease between two faces). A flat face's colour pattern (voxel colours, the HGSS
##      textures) is never an edge, and neither is anything inside a sprite;
##   3. sprites are masked out with their 3x3 neighbourhood, so even their outline stays exactly as
##      drawn. A sprite is a fragment with roughness 1.0 in the normal-roughness buffer (Sprite3D's
##      material); voxel materials stay below it (VoxelMat.TABLE tops out at 0.97), so their faces
##      are never masked. Any other roughness-1.0 material is simply left as drawn.
## Forward+ only (a compositor effect); with no RenderingDevice (headless) it does nothing.
## `debug` paints the mask instead: red = sprite (left alone), green = anti-aliased edge.

## Encoded roughness of a 1.0-roughness fragment in the normal-roughness buffer: Forward+ stores
## roughness x 127/255, mirrored to 1 - that for dynamic-GI instances (so 127 or 128 of 255).
const SPRITE_ROUGHNESS := [127.0, 128.0]
## Relative second difference of the depth (reverse Z, ~1 / distance) that marks a silhouette: a
## 0.25 m step seen from 40 m away is about 0.6 %.
const DEPTH_EDGE := 0.004
## Distance between two encoded normals (0..1 per channel) that marks a crease (~12 degrees).
const NORMAL_EDGE := 0.1
const SUBPIX := 0.5
const CTX := &"edge_aa"

const PREP_SRC := """
#version 450
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
layout(rgba16f, set = 0, binding = 0) uniform restrict readonly image2D color_image;
layout(rgba16f, set = 0, binding = 1) uniform restrict writeonly image2D tmp_image;
layout(push_constant, std430) uniform Params {
	vec2 size;
	vec2 pad;
} p;

void main() {
	ivec2 pc = ivec2(gl_GlobalInvocationID.xy);
	if (pc.x >= int(p.size.x) || pc.y >= int(p.size.y)) {
		return;
	}
	vec4 c = imageLoad(color_image, pc);
	vec3 h = max(c.rgb, vec3(0.0));
	imageStore(tmp_image, pc, vec4(h / (1.0 + max(h.r, max(h.g, h.b))), c.a));
}
"""

const AA_SRC := """
#version 450
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
layout(set = 0, binding = 0) uniform sampler2D tmp_tex;
layout(set = 0, binding = 1) uniform sampler2D depth_tex;
layout(set = 0, binding = 2) uniform sampler2D normal_tex;
layout(rgba16f, set = 0, binding = 3) uniform restrict writeonly image2D color_image;
layout(push_constant, std430) uniform Params {
	vec2 size;
	float depth_edge;
	float normal_edge;
	float subpix;
	float debug;
	float rough_a;
	float rough_b;
} p;

ivec2 sz;

ivec2 cl(ivec2 c) {
	return clamp(c, ivec2(0), sz - 1);
}

float lum(vec3 c) {
	return sqrt(dot(c, vec3(0.299, 0.587, 0.114)));
}

float lt(ivec2 c) {
	return lum(texelFetch(tmp_tex, cl(c), 0).rgb);
}

float ls(vec2 uv) {
	return lum(textureLod(tmp_tex, uv, 0.0).rgb);
}

float dep(ivec2 c) {
	return texelFetch(depth_tex, cl(c), 0).r;
}

vec3 nrm(ivec2 c) {
	return texelFetch(normal_tex, cl(c), 0).rgb;
}

bool sprite_at(ivec2 c) {
	float r = texelFetch(normal_tex, cl(c), 0).a * 255.0;
	return abs(r - p.rough_a) < 0.6 || abs(r - p.rough_b) < 0.6;
}

const float STEPS[8] = float[](1.5, 2.0, 2.0, 2.0, 2.0, 4.0, 8.0, 8.0);

void main() {
	ivec2 pc = ivec2(gl_GlobalInvocationID.xy);
	sz = ivec2(p.size);
	if (pc.x >= sz.x || pc.y >= sz.y) {
		return;
	}
	bool sprite = false;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			sprite = sprite || sprite_at(pc + ivec2(x, y));
		}
	}
	float dc = dep(pc);
	float dl = dep(pc + ivec2(-1, 0));
	float dr = dep(pc + ivec2(1, 0));
	float du = dep(pc + ivec2(0, -1));
	float dd = dep(pc + ivec2(0, 1));
	float sc = max(max(dc, max(dl, dr)), max(du, dd));
	float e2 = max(abs(dl + dr - 2.0 * dc), abs(du + dd - 2.0 * dc));
	bool edge = e2 > p.depth_edge * max(sc, 1e-12);
	vec3 nc = nrm(pc);
	float nd = max(
		max(distance(nc, nrm(pc + ivec2(-1, 0))), distance(nc, nrm(pc + ivec2(1, 0)))),
		max(distance(nc, nrm(pc + ivec2(0, -1))), distance(nc, nrm(pc + ivec2(0, 1))))
	);
	edge = edge || (nd > p.normal_edge && sc > 0.0);
	vec4 m = texelFetch(tmp_tex, pc, 0);
	if (p.debug > 0.5) {
		vec3 g = m.rgb * 0.35;
		vec3 o = sprite ? vec3(0.9, 0.05, 0.05) : (edge ? vec3(0.05, 0.9, 0.05) : g);
		imageStore(color_image, pc, vec4(o / max(1.0 - max(o.r, max(o.g, o.b)), 1e-3), m.a));
		return;
	}
	if (sprite || !edge) {
		return;
	}
	// FXAA 3.11, quality preset ~25, on the squeezed copy.
	vec2 rcp = 1.0 / p.size;
	vec2 uv = (vec2(pc) + 0.5) * rcp;
	float lM = lum(m.rgb);
	float lN = lt(pc + ivec2(0, -1));
	float lS = lt(pc + ivec2(0, 1));
	float lE = lt(pc + ivec2(1, 0));
	float lW = lt(pc + ivec2(-1, 0));
	float mx = max(max(lN, lS), max(max(lE, lW), lM));
	float mn = min(min(lN, lS), min(min(lE, lW), lM));
	float range = mx - mn;
	if (range < max(0.0312, mx * 0.125)) {
		return;
	}
	float lNW = lt(pc + ivec2(-1, -1));
	float lSE = lt(pc + ivec2(1, 1));
	float lNE = lt(pc + ivec2(1, -1));
	float lSW = lt(pc + ivec2(-1, 1));
	float lNS = lN + lS;
	float lWE = lW + lE;
	float eH1 = -2.0 * lM + lNS;
	float eV1 = -2.0 * lM + lWE;
	float lNESE = lNE + lSE;
	float lNWNE = lNW + lNE;
	float eH2 = -2.0 * lE + lNESE;
	float eV2 = -2.0 * lN + lNWNE;
	float lNWSW = lNW + lSW;
	float lSWSE = lSW + lSE;
	float eH4 = abs(eH1) * 2.0 + abs(eH2);
	float eV4 = abs(eV1) * 2.0 + abs(eV2);
	float eH3 = -2.0 * lW + lNWSW;
	float eV3 = -2.0 * lS + lSWSE;
	bool horz = abs(eH3) + eH4 >= abs(eV3) + eV4;
	float subA = (lNS + lWE) * 2.0 + lNWSW + lNESE;
	if (!horz) {
		lN = lW;
		lS = lE;
	}
	float len_sign = horz ? rcp.y : rcp.x;
	float subB = subA / 12.0 - lM;
	float gN = lN - lM;
	float gS = lS - lM;
	float lNN = lN + lM;
	float lSS = lS + lM;
	bool pairN = abs(gN) >= abs(gS);
	float grad = max(abs(gN), abs(gS));
	if (pairN) {
		len_sign = -len_sign;
	}
	float subC = clamp(abs(subB) / range, 0.0, 1.0);
	vec2 posB = uv;
	vec2 off = horz ? vec2(rcp.x, 0.0) : vec2(0.0, rcp.y);
	if (horz) {
		posB.y += len_sign * 0.5;
	} else {
		posB.x += len_sign * 0.5;
	}
	vec2 posN = posB - off;
	vec2 posP = posB + off;
	float subD = -2.0 * subC + 3.0;
	float subE = subC * subC;
	if (!pairN) {
		lNN = lSS;
	}
	float gscaled = grad / 4.0;
	float lMM = lM - lNN * 0.5;
	float endN = ls(posN) - lNN * 0.5;
	float endP = ls(posP) - lNN * 0.5;
	bool doneN = abs(endN) >= gscaled;
	bool doneP = abs(endP) >= gscaled;
	for (int i = 0; i < 8 && !(doneN && doneP); i++) {
		if (!doneN) {
			posN -= off * STEPS[i];
			endN = ls(posN) - lNN * 0.5;
			doneN = abs(endN) >= gscaled;
		}
		if (!doneP) {
			posP += off * STEPS[i];
			endP = ls(posP) - lNN * 0.5;
			doneP = abs(endP) >= gscaled;
		}
	}
	float dN = horz ? uv.x - posN.x : uv.y - posN.y;
	float dP = horz ? posP.x - uv.x : posP.y - uv.y;
	bool below = lMM < 0.0;
	bool good = dN < dP ? ((endN < 0.0) != below) : ((endP < 0.0) != below);
	float off_px = good ? 0.5 - min(dN, dP) / (dN + dP) : 0.0;
	float subF = subD * subE;
	off_px = max(off_px, subF * subF * p.subpix);
	vec2 pos = uv;
	if (horz) {
		pos.y += off_px * len_sign;
	} else {
		pos.x += off_px * len_sign;
	}
	vec3 r = textureLod(tmp_tex, pos, 0.0).rgb;
	imageStore(color_image, pc, vec4(r / max(1.0 - max(r.r, max(r.g, r.b)), 1e-3), m.a));
}
"""

## Paints the mask (red sprites, green edges) instead of anti-aliasing (--edge-aa=debug).
var debug := false
## --edge-aa=off: never runs (A/B screenshots against no anti-aliasing at all).
var off := false

var _rd: RenderingDevice
var _prep: RID
var _prep_pipe: RID
var _aa: RID
var _aa_pipe: RID
var _linear: RID
var _nearest: RID
var _size := Vector2i.ZERO
var _layers := 0


func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_PRE_TRANSPARENT
	needs_normal_roughness = true
	for a in OS.get_cmdline_user_args():
		if a == "--edge-aa=debug":
			debug = true
		elif a == "--edge-aa=off":
			off = true
	RenderingServer.call_on_render_thread(_setup)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _rd:
		for r in [_prep, _aa, _linear, _nearest]:  # (freeing a shader frees its pipeline)
			if r.is_valid():
				_rd.free_rid(r)


func _setup() -> void:
	_rd = RenderingServer.get_rendering_device()
	if _rd == null:
		return
	_prep = _compile(PREP_SRC)
	_aa = _compile(AA_SRC)
	if not _prep.is_valid() or not _aa.is_valid():
		return
	_prep_pipe = _rd.compute_pipeline_create(_prep)
	_aa_pipe = _rd.compute_pipeline_create(_aa)
	var s := RDSamplerState.new()
	s.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	s.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	s.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	s.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	_linear = _rd.sampler_create(s)
	s.min_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	s.mag_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	_nearest = _rd.sampler_create(s)


func _compile(src: String) -> RID:
	var s := RDShaderSource.new()
	s.language = RenderingDevice.SHADER_LANGUAGE_GLSL
	s.source_compute = src
	var spirv := _rd.shader_compile_spirv_from_source(s)
	if spirv.compile_error_compute != "":
		push_error("EdgeAA: " + spirv.compile_error_compute)
		return RID()
	return _rd.shader_create_from_spirv(spirv)


func _render_callback(_type: int, data: RenderData) -> void:
	if off or _rd == null or not _aa_pipe.is_valid():
		return
	var rsb := data.get_render_scene_buffers() as RenderSceneBuffersRD
	if rsb == null or rsb.get_msaa_3d() != RenderingServer.VIEWPORT_MSAA_DISABLED:
		return
	if not rsb.has_texture(&"forward_clustered", &"normal_roughness"):
		return
	var size := rsb.get_internal_size()
	if size.x <= 0 or size.y <= 0:
		return
	var views := rsb.get_view_count()
	if size != _size or views != _layers or not rsb.has_texture(CTX, &"tmp"):
		if rsb.has_texture(CTX, &"tmp"):
			rsb.clear_context(CTX)
		rsb.create_texture(
			CTX,
			&"tmp",
			RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT,
			RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT,
			RenderingDevice.TEXTURE_SAMPLES_1,
			size,
			views,
			1,
			true,
			false
		)
		_size = size
		_layers = views
	var gx := ceili(size.x / 8.0)
	var gy := ceili(size.y / 8.0)
	var prep_pc := PackedFloat32Array([size.x, size.y, 0.0, 0.0]).to_byte_array()
	var aa_pc := (
		PackedFloat32Array(
			[
				size.x,
				size.y,
				DEPTH_EDGE,
				NORMAL_EDGE,
				SUBPIX,
				1.0 if debug else 0.0,
				SPRITE_ROUGHNESS[0],
				SPRITE_ROUGHNESS[1],
			]
		)
		. to_byte_array()
	)
	for v in views:
		var color := rsb.get_color_layer(v)
		var tmp := rsb.get_texture_slice(CTX, &"tmp", v, 0, 1, 1)
		var depth := rsb.get_depth_layer(v)
		var nr := rsb.get_texture_slice(&"forward_clustered", &"normal_roughness", v, 0, 1, 1)
		var set0 := UniformSetCacheRD.get_cache(_prep, 0, [_image(0, color), _image(1, tmp)])
		var list := _rd.compute_list_begin()
		_rd.compute_list_bind_compute_pipeline(list, _prep_pipe)
		_rd.compute_list_bind_uniform_set(list, set0, 0)
		_rd.compute_list_set_push_constant(list, prep_pc, prep_pc.size())
		_rd.compute_list_dispatch(list, gx, gy, 1)
		_rd.compute_list_end()
		var set1 := (
			UniformSetCacheRD
			. get_cache(
				_aa,
				0,
				[
					_sampled(0, _linear, tmp),
					_sampled(1, _nearest, depth),
					_sampled(2, _nearest, nr),
					_image(3, color),
				]
			)
		)
		list = _rd.compute_list_begin()
		_rd.compute_list_bind_compute_pipeline(list, _aa_pipe)
		_rd.compute_list_bind_uniform_set(list, set1, 0)
		_rd.compute_list_set_push_constant(list, aa_pc, aa_pc.size())
		_rd.compute_list_dispatch(list, gx, gy, 1)
		_rd.compute_list_end()


static func _image(binding: int, tex: RID) -> RDUniform:
	var u := RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	u.binding = binding
	u.add_id(tex)
	return u


static func _sampled(binding: int, sampler: RID, tex: RID) -> RDUniform:
	var u := RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	u.binding = binding
	u.add_id(sampler)
	u.add_id(tex)
	return u

class_name WorldFx
extends RefCounted
## Shared look plumbing for the overworld port (original art, res://original/assets/).
## The original declares its shader globals in project.godot [shader_globals]; here they are
## registered at runtime (ensure_globals) before any world shader is loaded, so shader() must be
## used instead of preload() for every res://world/shaders/* file.

const ART := "res://original/assets/"
const MODELS := ART + "models/"

const GLOBALS := {
	"wind_dir": [RenderingServer.GLOBAL_VAR_TYPE_VEC2, Vector2(1.0, 0.35)],
	"wind_strength": [RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 1.0],
	"wind_gust": [RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0],
	"wind_time": [RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0],
	"main_cam_pos": [RenderingServer.GLOBAL_VAR_TYPE_VEC3, Vector3.ZERO],
	"weather_origin": [RenderingServer.GLOBAL_VAR_TYPE_VEC2, Vector2(-100000.0, -100000.0)],
	"weather_px": [RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 200000.0],
	"weather_time": [RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0],
}

static var _ready_globals := false
static var _shaders := {}
static var _tex := {}
static var weather_image: Image
static var weather_texture: ImageTexture


## Registers the original's shader globals (no-op for the ones project.godot already declares).
## The weather coverage map is a single texel stretched over the whole world (weather.gd writes it).
static func ensure_globals() -> void:
	if _ready_globals:
		return
	_ready_globals = true
	for k in GLOBALS:
		if not ProjectSettings.has_setting("shader_globals/" + k):
			RenderingServer.global_shader_parameter_add(k, GLOBALS[k][0], GLOBALS[k][1])
	weather_image = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	weather_image.fill(Color(0, 0, 0, 0))
	weather_texture = ImageTexture.create_from_image(weather_image)
	if not ProjectSettings.has_setting("shader_globals/weather_map"):
		RenderingServer.global_shader_parameter_add(
			"weather_map", RenderingServer.GLOBAL_VAR_TYPE_SAMPLER2D, weather_texture
		)
	else:
		RenderingServer.global_shader_parameter_set("weather_map", weather_texture)


## Coverage (wet, snow, fog, cloud) applied everywhere.
static func set_weather(c: Color) -> void:
	ensure_globals()
	weather_image.fill(c)
	weather_texture.update(weather_image)


static func shader(name: String) -> Shader:
	ensure_globals()
	if not _shaders.has(name):
		_shaders[name] = load("res://world/shaders/%s.gdshader" % name)
	return _shaders[name]


static func shader_mat(name: String, params := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader(name)
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m


## Texture under res://original/assets/ (cached; null if missing).
static func tex(rel: String) -> Texture2D:
	if not _tex.has(rel):
		var p := ART + rel
		_tex[rel] = load(p) if ResourceLoader.exists(p) else null
	return _tex[rel]


## Map JSON look.env ("res://resources/look/x.tres") -> the converted copy in world/look/.
static func env_path(original: String) -> String:
	var p := "res://world/look/%s" % original.get_file()
	return (
		p if original != "" and ResourceLoader.exists(p) else "res://world/look/overworld_env.tres"
	)

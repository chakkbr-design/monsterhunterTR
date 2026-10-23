extends RefCounted
## Opções do jogo em user://settings.cfg: volume geral (0..100) e tela cheia.
## Uso: const Settings := preload("res://ui/front/settings.gd")

const PATH := "user://settings.cfg"
const DEFAULTS := {"volume": 80, "fullscreen": false}


static func load_cfg(path := PATH) -> Dictionary:
	var d := DEFAULTS.duplicate()
	var cf := ConfigFile.new()
	if cf.load(path) == OK:
		d.volume = clampi(int(cf.get_value("audio", "volume", d.volume)), 0, 100)
		d.fullscreen = bool(cf.get_value("video", "fullscreen", d.fullscreen))
	return d


static func save_cfg(d: Dictionary, path := PATH) -> bool:
	var cf := ConfigFile.new()
	cf.set_value("audio", "volume", int(d.get("volume", DEFAULTS.volume)))
	cf.set_value("video", "fullscreen", bool(d.get("fullscreen", DEFAULTS.fullscreen)))
	return cf.save(path) == OK


## Aplica no motor: volume no barramento Master e modo da janela (ignorado em headless).
static func apply(d: Dictionary) -> void:
	var v := clampi(int(d.get("volume", DEFAULTS.volume)), 0, 100)
	AudioServer.set_bus_volume_db(0, linear_to_db(v / 100.0) if v > 0 else -80.0)
	AudioServer.set_bus_mute(0, v == 0)
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.window_get_mode()
	var full := (
		mode == DisplayServer.WINDOW_MODE_FULLSCREEN
		or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	)
	if d.get("fullscreen", false) and not full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not d.get("fullscreen", false) and full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

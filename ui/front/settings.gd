extends RefCounted
## Opções do jogo em user://settings.cfg, como o settings.gd + options_screen.gd do original:
## velocidade do texto e da batalha, música, som, janela, gráficos e dicas de batalha.
## Uso: const Settings := preload("res://ui/front/settings.gd")
## load_cfg() devolve {text_speed 0..3, battle_speed 0..1, music 0..100, sfx 0..100, fullscreen,
## quality 0..3, weather_mist, battle_tips} (e "volume", o volume geral antigo, só para
## compatibilidade).
## Gráficos: Baixo / Médio / Alto / Ultra (GfxQuality, world/look/gfx_quality.gd), gravados em
## [video] graphics. Saves antigos só têm [options] quality 0..1 (Baixo/Alto): 0 vira Baixo e 1 vira
## Alto; o save novo continua gravando esse quality antigo (Alto e Ultra = 1) para versões velhas.
## Névoa do clima: a névoa baixa do clima do mundo (WorldWeather.mist_enabled, em
## world/sky/weather.gd), gravada em [video] weather_mist (padrão ligada), a chave do painel F9.

const PATH := "user://settings.cfg"
const TEXT_SPEEDS := ["Lento", "Médio", "Rápido", "Instantâneo"]
const TEXT_CPS := [25.0, 45.0, 90.0, 0.0]
const BATTLE_SPEED_NAMES := ["Lento", "Rápido"]
const BATTLE_SPEED_MULT := [0.6, 1.0]
const WINDOW_MODES := ["Janela", "Tela cheia"]
const QUALITY_NAMES := ["Baixo", "Médio", "Alto", "Ultra"]  ## = GfxQuality.NAMES
const QUALITY_DEFAULT := 2  ## Alto
const WEATHER_SCRIPT := "res://world/sky/weather.gd"  ## WorldWeather (névoa do clima)
const DEFAULTS := {
	"text_speed": 1,
	"battle_speed": 0,
	"music": 80,
	"sfx": 100,
	"fullscreen": false,
	"quality": QUALITY_DEFAULT,
	"weather_mist": true,
	"battle_tips": true,
	"volume": 80,
}
## Linhas da tela de Opções (título e menu de pausa), na ordem do original:
## [chave, rótulo, tipo ("choice" "volume" "toggle" "action"), nomes das escolhas].
const ROWS := [
	["text_speed", "VELOC. DO TEXTO", "choice", TEXT_SPEEDS],
	["battle_speed", "VELOC. DA BATALHA", "choice", BATTLE_SPEED_NAMES],
	["music", "MÚSICA", "volume", []],
	["sfx", "SOM", "volume", []],
	["fullscreen", "JANELA", "choice", WINDOW_MODES],
	["quality", "GRÁFICOS", "choice", QUALITY_NAMES],
	["weather_mist", "NÉVOA DO CLIMA", "toggle", []],
	["battle_tips", "DICAS DE BATALHA", "toggle", []],
	["controls", "CONTROLES", "action", []],
	["back", "VOLTAR", "action", []],
]


static func load_cfg(path := PATH) -> Dictionary:
	var d := DEFAULTS.duplicate()
	var cf := ConfigFile.new()
	if cf.load(path) == OK:
		d.text_speed = clampi(
			int(cf.get_value("options", "text_speed", d.text_speed)), 0, TEXT_SPEEDS.size() - 1
		)
		d.battle_speed = clampi(
			int(cf.get_value("options", "battle_speed", d.battle_speed)),
			0,
			BATTLE_SPEED_MULT.size() - 1
		)
		if cf.has_section_key("video", "graphics"):
			d.quality = clampi(
				int(cf.get_value("video", "graphics", d.quality)), 0, QUALITY_NAMES.size() - 1
			)
		elif cf.has_section_key("options", "quality"):
			d.quality = 0 if int(cf.get_value("options", "quality", 1)) <= 0 else QUALITY_DEFAULT
		d.weather_mist = bool(cf.get_value("video", "weather_mist", d.weather_mist))
		d.battle_tips = bool(cf.get_value("options", "battle_tips", d.battle_tips))
		d.volume = clampi(int(cf.get_value("audio", "volume", d.volume)), 0, 100)
		d.music = clampi(int(cf.get_value("audio", "music", d.music)), 0, 100)
		d.sfx = clampi(int(cf.get_value("audio", "sfx", d.sfx)), 0, 100)
		d.fullscreen = bool(cf.get_value("video", "fullscreen", d.fullscreen))
	return d


static func save_cfg(d: Dictionary, path := PATH) -> bool:
	var cf := ConfigFile.new()
	for k in ["text_speed", "battle_speed"]:
		cf.set_value("options", k, int(d.get(k, DEFAULTS[k])))
	var q := clampi(int(d.get("quality", DEFAULTS.quality)), 0, QUALITY_NAMES.size() - 1)
	cf.set_value("options", "quality", 1 if q >= QUALITY_DEFAULT else 0)  # saves antigos (Baixo/Alto)
	cf.set_value("video", "graphics", q)
	cf.set_value("video", "weather_mist", bool(d.get("weather_mist", DEFAULTS.weather_mist)))
	cf.set_value("options", "battle_tips", bool(d.get("battle_tips", DEFAULTS.battle_tips)))
	for k in ["volume", "music", "sfx"]:
		cf.set_value("audio", k, int(d.get(k, DEFAULTS[k])))
	cf.set_value("video", "fullscreen", bool(d.get("fullscreen", DEFAULTS.fullscreen)))
	return cf.save(path) == OK


## Letras por segundo do diálogo (0 = instantâneo), como Settings.text_cps do original.
static func text_cps(d: Dictionary) -> float:
	return TEXT_CPS[clampi(int(d.get("text_speed", 1)), 0, TEXT_CPS.size() - 1)]


## Multiplicador da batalha: Lento 0,6x (padrão) ou Rápido 1,0x.
static func battle_speed_value(d: Dictionary) -> float:
	return BATTLE_SPEED_MULT[clampi(int(d.get("battle_speed", 0)), 0, BATTLE_SPEED_MULT.size() - 1)]


## Valor que a linha de opção desenha (índice da escolha, 0..10 do volume ou bool).
static func row_value(d: Dictionary, key: String):
	match key:
		"music", "sfx":
			return int(d.get(key, DEFAULTS[key])) / 10
		"fullscreen":
			return 1 if bool(d.get("fullscreen", false)) else 0
		"battle_tips", "weather_mist":
			return bool(d.get(key, DEFAULTS[key]))
	return int(d.get(key, 0))


## Muda a opção `key` com ←/→ (dir -1/+1) ou E (dir 0: avança a escolha, liga/desliga).
## Devolve true se mudou (quem chama grava e aplica).
static func change(d: Dictionary, key: String, dir: int) -> bool:
	match key:
		"music", "sfx":
			if dir == 0:
				return false
			var v := clampi(int(d.get(key, DEFAULTS[key])) + 10 * dir, 0, 100)
			if v == int(d.get(key, DEFAULTS[key])):
				return false
			d[key] = v
			return true
		"fullscreen", "battle_tips", "weather_mist":
			d[key] = not bool(d.get(key, DEFAULTS[key]))
			return true
		"text_speed", "battle_speed", "quality":
			var n: int = (
				{"text_speed": TEXT_SPEEDS, "battle_speed": BATTLE_SPEED_NAMES}
				. get(key, QUALITY_NAMES)
				. size()
			)
			var cur := int(d.get(key, DEFAULTS[key]))
			var nv := posmod(cur + (dir if dir != 0 else 1), n)
			if nv == cur:
				return false
			d[key] = nv
			return true
	return false


## Aplica no motor: volumes nos barramentos Music/SFX/UI (se existirem; o Audio relê o arquivo),
## névoa do clima, modo da janela e qualidade da renderização (janela e renderização não mudam em
## headless).
static func apply(d: Dictionary) -> void:
	AudioServer.set_bus_volume_db(0, 0.0)
	AudioServer.set_bus_mute(0, false)
	for b in [["Music", "music"], ["SFX", "sfx"], ["UI", "sfx"]]:
		var i := AudioServer.get_bus_index(b[0])
		if i < 0:
			continue
		var v := clampi(int(d.get(b[1], DEFAULTS[b[1]])), 0, 100)
		AudioServer.set_bus_volume_db(i, linear_to_db(v / 100.0) if v > 0 else -80.0)
		AudioServer.set_bus_mute(i, v == 0)
	var ml := Engine.get_main_loop() as SceneTree
	var au: Node = ml.root.get_node_or_null("Audio") if ml else null
	if au:
		for m in ["apply_settings", "apply_volumes", "_apply_volume"]:
			if au.has_method(m):
				au.call(m)
				break
	set_weather_mist(bool(d.get("weather_mist", DEFAULTS.weather_mist)))
	GfxQuality.set_tier(int(d.get("quality", QUALITY_DEFAULT)))
	if DisplayServer.get_name() == "headless":
		return
	if ml:
		GfxQuality.apply_all(ml.root)
		ml.call_group(GfxQuality.GROUP, "apply_quality")
	var mode := DisplayServer.window_get_mode()
	var full := (
		mode == DisplayServer.WINDOW_MODE_FULLSCREEN
		or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	)
	if d.get("fullscreen", false) and not full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not d.get("fullscreen", false) and full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


## Liga ou desliga a névoa baixa do clima na hora: o WorldWeather lê `mist_enabled` a cada quadro.
## Não grava (quem chama já gravou com save_cfg). Sem o script do clima carregado (no título, sem
## mundo) não há o que mudar: o WorldWeather lê o [video] weather_mist quando o mundo abre.
## O script vai por caminho, porque citar a classe WorldWeather puxaria o mundo para os testes.
static func set_weather_mist(on: bool) -> void:
	if not ResourceLoader.has_cached(WEATHER_SCRIPT):
		return
	var ww: Script = load(WEATHER_SCRIPT)
	ww.set("mist_enabled", on)
	ww.set("_mist_loaded", true)

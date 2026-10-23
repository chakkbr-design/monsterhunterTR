extends SceneTree
## Rodar: godot --headless --path . --script res://tests/audio/test_audio.gd
## Efeitos e faixas geram streams não vazios com o tamanho e o loop certos; troca de música com
## battle_started/battle_finished e location_changed simulados; chamada protegida sem o autoload Audio.

const Synth := preload("res://audio/synth.gd")
const Cue := preload("res://audio/cue.gd")
const AudioScript := preload("res://audio/audio.gd")

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "FALHOU  ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _peak(w: AudioStreamWAV) -> float:
	var d := w.data
	var m := 0
	for i in range(0, d.size(), 2 * 7):
		m = maxi(m, absi(d.decode_s16(i)))
	return m / 32000.0


func _frames(w: AudioStreamWAV) -> int:
	return w.data.size() / 2


func _run() -> void:
	# --- Chamada protegida sem o autoload ---
	# Tira o autoload para provar que cue.gd não quebra sem ele.
	var auto := root.get_node_or_null("Audio")
	if auto:
		root.remove_child(auto)
		auto.free()
	check(root.get_node_or_null("/root/Audio") == null, "sem autoload Audio no teste")
	Cue.sfx("hit")
	Cue.music("route")
	Cue.ui("ok")
	check(true, "cue.gd sem Audio não quebra")

	# --- Notas e acordes ---
	check(Synth.note_midi("A4") == 69 and Synth.note_midi("C4") == 60 and Synth.note_midi("F#5") == 78 and Synth.note_midi("Bb3") == 58, "note_midi")
	check(Synth.chord("Am")[0] == 9 and Synth.chord("Am")[1] == [0, 3, 7] and Synth.chord("Bb")[0] == 10, "chord")

	# --- Efeitos ---
	for n in Synth.SFX_NAMES:
		var w := Synth.make_sfx(n)
		var ok := w != null and _frames(w) > 100 and w.loop_mode == AudioStreamWAV.LOOP_DISABLED \
			and w.format == AudioStreamWAV.FORMAT_16_BITS and w.mix_rate == Synth.RATE
		var secs := _frames(w) / float(Synth.RATE) if w else 0.0
		check(ok and secs < 3.0 and _peak(w) > 0.02, "sfx %s (%.2fs, pico %.2f)" % [n, secs, _peak(w) if w else 0.0])
	check(Synth.make_sfx("nao_existe") == null, "sfx desconhecido -> null")

	# --- Faixas ---
	var need := ["title", "town", "route", "forest", "battle_wild", "battle_trainer", "victory", "center", "lab"]
	for n in need:
		check(Synth.TRACKS.has(n), "faixa %s existe" % n)
	var t0 := Time.get_ticks_msec()
	for n in Synth.TRACKS:
		var spec: Dictionary = Synth.TRACKS[n]
		var steps := Synth.track_steps(spec)
		var pat_ok: bool = spec.bass.length() == 16 and spec.arp.length() == 16 and spec.drums.length() == 16
		var toks := Synth.melody_tokens(spec)
		var notes_ok := true
		for tk in toks:
			if tk != "." and tk != "-" and Synth.note_midi(tk) < 0:
				notes_ok = false
		check(toks.size() == steps and pat_ok and notes_ok, "faixa %s: %d passos, padrões e notas válidos" % [n, toks.size()])
		var w := Synth.render_track(n)
		var expect := int(round(Synth.track_secs(spec) * Synth.RATE))
		var ok := w != null and _frames(w) == expect and w.loop_mode == AudioStreamWAV.LOOP_FORWARD \
			and w.loop_begin == 0 and w.loop_end == _frames(w)
		check(ok and _peak(w) > 0.1, "faixa %s: %.1fs em loop, pico %.2f" % [n, Synth.track_secs(spec), _peak(w) if w else 0.0])
	print("render de todas as faixas: %d ms" % (Time.get_ticks_msec() - t0))
	check(Synth.render_track("nao_existe") == null, "faixa desconhecida -> null")

	# --- Escolha de música por lugar ---
	check(AudioScript.music_for("zone", "pallet_town") == "town", "pallet -> town")
	check(AudioScript.music_for("zone", "route_22") == "route", "route_22 -> route")
	check(AudioScript.music_for("zone", "viridian_forest") == "forest", "floresta -> forest")
	check(AudioScript.music_for("zone", "pewter_city") == "town", "pewter -> town")
	check(AudioScript.music_for("interior", "pokemon_center_viridian") == "center", "centro -> center")
	check(AudioScript.music_for("interior", "mart_viridian") == "center", "loja -> center")
	check(AudioScript.music_for("interior", "oak_lab") == "lab", "lab -> lab")
	check(AudioScript.music_for("interior", "pewter_gym") == "gym", "ginásio -> gym")
	check(AudioScript.music_for("interior", "player_house") == "town", "casa -> town")

	# --- Autoload simulado ---
	var game = load("res://core/game.gd").new()
	root.add_child(game)
	var au: Node = AudioScript.new()
	au.name = "Audio"
	au.game = game
	root.add_child(au)
	await process_frame
	check(au.has_sfx("hit") and au.sfx_stream("crit") != null, "Audio monta os efeitos no _ready")
	au.sfx("hit")
	au.sfx("nao_existe")
	Cue.sfx("crit")
	Cue.ui("down")
	check(true, "sfx pelo autoload e pelo cue")

	# Mundo falso com o sinal location_changed (como a RouteWorld).
	var world := Node.new()
	world.add_user_signal("location_changed", [{"name": "kind", "type": TYPE_STRING}, {"name": "id", "type": TYPE_STRING}])
	root.add_child(world)
	await process_frame
	world.emit_signal("location_changed", "zone", "route_1")
	check(au.current_music == "route" and au.zone_music == "route", "location_changed(zone, route_1) -> route")
	world.emit_signal("location_changed", "interior", "pokemon_center_viridian")
	check(au.current_music == "center", "entrar no centro -> center")
	world.emit_signal("location_changed", "zone", "viridian_city")
	check(au.current_music == "town", "sair para a cidade -> town")

	game._opts = {"kind": "wild"}
	game.battle_started.emit()
	check(au.in_battle and au.current_music == "battle_wild", "battle_started selvagem -> battle_wild")
	world.emit_signal("location_changed", "zone", "route_1")
	check(au.current_music == "battle_wild" and au.zone_music == "route", "mudar de lugar na batalha não troca a música")
	game.battle_finished.emit({"outcome": "win"})
	check(not au.in_battle and au.current_music == "victory", "vitória -> victory")
	au._process(Synth.track_secs(Synth.TRACKS.victory) + 0.1)
	check(au.current_music == "route", "depois da vitória volta para a música da zona")

	game._opts = {"kind": "trainer", "trainer_id": "x"}
	game.battle_started.emit()
	check(au.current_music == "battle_trainer", "battle_started treinador -> battle_trainer")
	game.battle_finished.emit({"outcome": "run"})
	check(au.current_music == "route", "fugir volta direto para a zona")
	game.battle_finished.emit({"outcome": "lose"})
	check(au.current_music == "route", "perder volta para a zona")

	au.music("lab", 0.0)
	check(au.current_music == "lab", "music() direto")
	au.stop_music(0.0)
	check(au.current_music == "", "stop_music()")

	# Fade: depois do tempo de fade a faixa velha para.
	au.music("town", 0.2)
	au._process(0.3)
	au.music("forest", 0.2)
	au._process(0.3)
	check(au.current_music == "forest" and au._cur.playing and not au._old.playing, "crossfade termina com só uma faixa tocando")

	world.queue_free()
	au.queue_free()
	game.queue_free()
	await process_frame
	print("FALHAS: %d" % fails)
	quit(1 if fails > 0 else 0)

extends SceneTree
## Exporta efeitos e faixas para docs/audio_preview/*.wav (para ouvir fora do jogo):
## godot --headless --path . --script res://tests/audio/export_preview.gd

const Synth := preload("res://audio/synth.gd")


func _initialize() -> void:
	var dir := ProjectSettings.globalize_path("res://docs/audio_preview")
	DirAccess.make_dir_recursive_absolute(dir)
	for n in Synth.TRACKS:
		Synth.render_track(n).save_to_wav(dir + "/music_%s.wav" % n)
	for n in Synth.SFX_NAMES:
		Synth.make_sfx(n).save_to_wav(dir + "/sfx_%s.wav" % n)
	print("exportado em ", dir)
	quit(0)

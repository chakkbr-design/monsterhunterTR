extends SceneTree
## Rodar: godot --headless --fixed-fps 60 --path . --script res://tests/ui_training/test_clean_hud.gd
## "No HUD" do treino (para vídeo): sem cartões, botões, log nem barra de vida na cabeça (só os
## popups de dano), a barra do treino some, e o arquivo da partida sai com a linha do tempo da vida
## (track no relógio do vídeo) que tools/video/make_vertical.py lê.

const Cfg := preload("res://ui/training/training_config.gd")
const SCENE := "res://ui/training/training_battle.tscn"
const LIMIT := 60 * 120
const MATCH := "user://test_clean_hud_match.json"

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "FALHOU  ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Cfg.path = "user://test_clean_hud_cfg.json"
	var c := Cfg.default_config()
	c.sides[0].mons = [Cfg.mon_entry("Charizard", 50)]
	c.sides[1].mons = [Cfg.mon_entry("Weedle", 50), Cfg.mon_entry("Caterpie", 50)]
	c.speed = 4.0
	c.seed = 3
	c.battle_size = 1
	c.clean_hud = true
	c.extra_opts = {"telemetry": MATCH, "telemetry_meta": {"names": ["Team A", "Team B"]}}
	Cfg.current = c
	if FileAccess.file_exists(MATCH):
		DirAccess.remove_absolute(MATCH)
	var tb: Node = load(SCENE).instantiate()
	root.add_child(tb)
	var seen_fight := false
	var hud_ok := true
	var bars_ok := true
	for i in LIMIT:
		await process_frame
		if tb._result_box.visible:
			break
		var a = tb.arena
		if not is_instance_valid(a) or String(a.state) != "fight":
			continue
		seen_fight = true
		for ch in a.hud._root.get_children():
			if ch.visible and ch != a.hud._pops:
				hud_ok = false
		for f in a.fighters:
			var bar = f.get_node_or_null("HpBar")
			if bar and bar.visible:
				bars_ok = false
	check(seen_fight, "a luta rodou")
	check(hud_ok, "só os popups do HUD aparecem")
	check(bars_ok, "nenhuma barra de vida na cabeça")
	check(not tb._top.visible, "barra do treino escondida")
	var f := FileAccess.open(MATCH, FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text()) if f else null
	check(d is Dictionary, "arquivo da partida gravado")
	if d is Dictionary:
		var tr: Array = d.get("track", [])
		check(tr.size() > 20, "linha do tempo com %d pontos" % tr.size())
		check(
			String(d.teams[0][0].name).to_lower() == "charizard" and int(d.teams[0][0].max) > 0,
			"times com nome e vida máxima"
		)
		var last: Dictionary = tr[-1]
		check(int(last.hp[1][0]) == 0 and int(last.hp[1][1]) == 0, "no fim o Time B está todo a 0")
		check(String(tr[0].st) == "opening", "relógio do vídeo começa na abertura (%s)" % tr[0].st)
		var on_seen := tr.any(func(s): return (s.on[1] as Array).any(func(i): return int(i) == 1))
		check(on_seen, "o segundo do Time B aparece em campo")
		var ev_vt: bool = (d.events as Array).all(func(e): return e.has("vt"))
		check(ev_vt, "todo evento tem vt")
	print("\n%s" % ("TUDO OK" if fails == 0 else "%d FALHA(S)" % fails))
	quit(1 if fails > 0 else 0)

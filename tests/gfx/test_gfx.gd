extends SceneTree
## Rodar: godot --headless --path . --script res://tests/gfx/test_gfx.gd
## Specs de sprite de todas as espécies, cadeias PMD e texturas do original.

const CS := preload("res://gfx/creature_sprite.gd")
const PS := preload("res://gfx/pokemon_sprites.gd")

var _fails := 0
var _count := 0


func _initialize() -> void:
	_species_specs()
	_chains()
	_move_fx()
	_sprite_node()
	_extra()
	print("gfx: %d checks, %d falhas" % [_count, _fails])
	quit(1 if _fails else 0)


func check(ok: bool, what: String) -> void:
	_count += 1
	if not ok:
		_fails += 1
		print("FALHOU: ", what)


func _species_specs() -> void:
	var with_pmd := 0
	for sp in Dex.all_species():
		var s: Dictionary = PS.spec(sp)
		check(s.get("texture") is Texture2D, "%s: textura" % sp)
		check(bool(s.get("real", false)), "%s: tem arte do original" % sp)
		check(float(s.get("pixel_size", 0.0)) > 0.0, "%s: pixel_size" % sp)
		check(int(s.hframes) * int(s.vframes) >= 1, "%s: frames" % sp)
		for k in ["icon", "front", "back", "party_icon"]:
			check(s.get(k) is Texture2D, "%s: %s" % [sp, k])
		if s.has("pmd"):
			with_pmd += 1
			for anim in s.pmd:
				var a: Dictionary = s.pmd[anim]
				check(a.texture is Texture2D, "%s/%s: textura" % [sp, anim])
				var tex: Texture2D = a.texture
				check(tex.get_width() == int(a.w) * int(a.frames), "%s/%s: largura = w*frames" % [sp, anim])
				check(tex.get_height() == int(a.h) * int(a.dirs), "%s/%s: altura = h*dirs" % [sp, anim])
				var anchors: Array = a.anchor
				check(anchors.is_empty() or anchors.size() == int(a.dirs), "%s/%s: âncoras por direção" % [sp, anim])
		# visível: altura em metros coerente com a espécie
		var vis := float(s.get("visible_m", 0.0))
		check(vis > 0.1 and vis < 12.0, "%s: visible_m %.2f" % [sp, vis])
	check(with_pmd >= 40, "espécies com PMD: %d" % with_pmd)


func _chains() -> void:
	var data: Dictionary = PS.pmd_anims()
	check(data.has("states") and data.has("kinds"), "pmd_anims.json carregado")
	for sp in Dex.all_species():
		if not PS.has_pmd(sp):
			continue
		check(PS.resolve_chain(sp, data.states.idle) != "", "%s: idle resolve" % sp)
		check(PS.resolve_chain(sp, data.states.move) != "", "%s: move resolve" % sp)
		check(PS.resolve_chain(sp, data.states.hurt) != "", "%s: hurt resolve" % sp)
		# todo golpe do kit/learnset tem uma animação (ou cai no Idle sem quebrar)
		var spd: Dictionary = Dex.species(sp)
		for entry in spd.get("learnset", []):
			var mv := Dex.move(String(entry[1]))
			if mv.is_empty():
				continue
			var chain := PS.move_chain(mv)
			check(chain is Array, "%s/%s: cadeia" % [sp, mv.id])


func _move_fx() -> void:
	var f := FileAccess.open("res://data/move_fx.json", FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text())
	check(d is Dictionary, "move_fx.json")
	var missing := []
	for id in d.get("fx", {}):
		var p := "res://original/assets/vfx/pmd/" + String(id) + ".png"
		if not ResourceLoader.exists(p):
			missing.append(p)
	for id in d.get("beams", {}):
		var dir := "res://original/assets/vfx/pmd/beams/" + String(id) + "/"
		if not DirAccess.dir_exists_absolute(dir):
			missing.append(dir)
	for id in d.get("moves", {}):
		var m: Dictionary = d.moves[id]
		for role in m:
			if m[role] is Dictionary and m[role].has("fx") and not d.fx.has(String(m[role].fx)):
				missing.append("%s.%s -> %s" % [id, role, m[role].fx])
	check(missing.is_empty(), "texturas de vfx faltando: %s" % str(missing.slice(0, 5)))


func _sprite_node() -> void:
	var root := Node3D.new()
	get_root().add_child(root)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.transform = Transform3D(Basis.looking_at(Vector3(0, -3, -6)), Vector3(0, 3, 6))
	cam.current = true
	for sp in ["Pikachu", "Bulbasaur", "Zubat", "Onix"]:
		var cs = CS.new()
		cs.manual = true
		cs.species = sp
		root.add_child(cs)
		cs.tick(0.016)
		check(cs.sprite().texture != null, "%s: nó com textura" % sp)
		check(cs.visible_height() > 0.1, "%s: altura" % sp)
		if cs.has_pmd():
			check(cs.current_anim() == "Idle", "%s: começa em Idle (%s)" % [sp, cs.current_anim()])
			cs.auto_motion = false
			cs.velocity = Vector3(3, 0, 0)
			cs.tick(0.016)
			check(cs.current_anim() == "Walk", "%s: anda (%s)" % [sp, cs.current_anim()])
			check(cs.dir8() == 2, "%s: olhando para a direita = linha 2 (%d)" % [sp, cs.dir8()])
			cs.velocity = Vector3.ZERO
			cs.tick(0.016)
			cs.tick(0.016)
			var played: String = cs.play_move({"id": "tackle", "kind": "dash"}, 0.3)
			check(played != "", "%s: anim de golpe" % sp)
			for i in 120:
				cs.tick(1.0 / 60.0)
			check(not cs.is_playing_oneshot(), "%s: one-shot termina" % sp)
			cs.hurt()
			check(cs.current_anim() == "Hurt", "%s: hurt" % sp)
			cs.faint()
			for i in 90:
				cs.tick(1.0 / 60.0)
			check(cs.fainted, "%s: desmaiado" % sp)
			cs.revive()
			cs.tick(0.016)
			check(cs.current_anim() == "Idle", "%s: volta para Idle" % sp)
		else:
			cs.auto_motion = false
			cs.velocity = Vector3(0, 0, -3)
			for i in 10:
				cs.tick(0.05)
			check(cs.sprite().frame >= 0, "%s: anima sem PMD" % sp)
	root.queue_free()


func _extra() -> void:
	check(PS.asset_path("res://assets/sprites/x.png") == "res://original/assets/sprites/x.png", "asset_path")
	check(PS.icon_fitted("Pikachu", 32) is Texture2D, "icon_fitted")
	for fnt in ["res://original/assets/fonts/Nunito.ttf", "res://original/assets/fonts/PixelifySans.ttf"]:
		check(ResourceLoader.exists(fnt), "fonte " + fnt)

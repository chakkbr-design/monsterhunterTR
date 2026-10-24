extends SceneTree
## Rodar: godot --headless --path . --script res://tests/battle/test_move_show.gd
## Espetáculo procedural dos golpes (gfx/move_show.gd): todo golpe tem look válido, as texturas
## geradas existem, cada golpe solta efeitos sem erro e os ganchos do Cavar/arremesso funcionam.

const ARENA := "res://battle/battle_arena.tscn"
const DT := 1.0 / 60.0
## Golpes que derrubam o próprio usuário (a luta acabaria no meio do teste).
const SACRIFICE := [
	"healing_wish", "memento", "explosion", "self_destruct", "final_gambit", "lunar_dance"
]
const NEW_MOVES := "res://tests/battle/gen9_new_moves.txt"

var _fails := 0
var _count := 0


func _initialize() -> void:
	_main.call_deferred()


func check(ok: bool, what: String) -> void:
	_count += 1
	if not ok:
		_fails += 1
		print("FALHOU: ", what)


func _main() -> void:
	await process_frame
	_data()
	_textures()
	await _arena_moves()
	print("move_show: %d checks, %d falhas" % [_count, _fails])
	quit(1 if _fails else 0)


func _data() -> void:
	var d: Dictionary = PmdFx.data()
	var moves: Dictionary = d.get("moves", {})
	var ids: Array = []
	var f := FileAccess.open("res://data/moves.json", FileAccess.READ)
	var mj = JSON.parse_string(f.get_as_text())
	for m in mj.get("moves", []):
		ids.append(String(m.id))
	var extra := FileAccess.get_file_as_string(NEW_MOVES).split("\n", false)
	for e in extra:
		ids.append(String(e).strip_edges())
	var bad := []
	for id in ids:
		var e = moves.get(id)
		if not (e is Dictionary and e.get("look") is Dictionary):
			bad.append(id)
	check(bad.is_empty(), "golpes sem look: %s" % str(bad.slice(0, 8)))
	var wrong := []
	for id in moves:
		var lk = moves[id].get("look")
		if not lk is Dictionary:
			continue
		for key in MoveShow.VOCAB:
			if not lk.has(key):
				continue
			var vals = lk[key]
			if vals is String:
				vals = [vals]
			var ok_list: Array = MoveShow.VOCAB[key]
			if key == "impact" or key == "status_hit":
				ok_list = ok_list + MoveShow.VOCAB.swing + MoveShow.LAND_SHAPES
			for v in vals:
				if not String(v) in ok_list:
					wrong.append("%s.%s=%s" % [id, key, v])
		for key in ["land"]:
			var vals2 = lk.get(key, [])
			if vals2 is String:
				vals2 = [vals2]
			for v in vals2:
				if not String(v) in MoveShow.LAND_SHAPES:
					wrong.append("%s.land=%s" % [id, v])
		var ic := String(lk.get("icon", ""))
		if ic != "":
			if not MoveShow.ICONS.has(ic):
				wrong.append("%s.icon=%s" % [id, ic])
		for role in moves[id]:
			var r = moves[id][role]
			if r is Dictionary and r.has("fx") and not d.fx.has(String(r.fx)):
				wrong.append("%s.%s -> %s" % [id, role, r.fx])
			elif r is String and role != "beam" and not d.fx.has(r):
				wrong.append("%s.%s -> %s" % [id, role, r])
	check(wrong.is_empty(), "nomes inválidos no look: %s" % str(wrong.slice(0, 8)))


func _textures() -> void:
	for n in [
		"dot",
		"blade",
		"glow",
		"ring",
		"ring_soft",
		"crescent",
		"arc",
		"streak",
		"rays",
		"star4",
		"cloud",
		"swirl",
		"column",
		"hex",
		"crack",
		"hole",
		"clod",
		"heart",
		"moon",
		"star5",
		"spike",
		"arrow",
		"fang",
		"claw",
		"feather",
		"petal",
		"drop",
		"note"
	]:
		var t := ProcFx.tex(n)
		check(t != null and t.get_width() > 0, "textura " + n)
	for k in MoveShow.ICONS:
		check(ProcFx.tex(String(MoveShow.ICONS[k])) != null, "ícone " + k)
	for k in MoveShow.STYLE:
		check(ProcFx.tex(String(MoveShow.STYLE[k].tex)) != null, "partícula " + k)


func _arena_moves() -> void:
	var host := Node3D.new()
	root.add_child(host)
	var a: Node = load(ARENA).instantiate()
	a.manual = true
	host.add_child(a)
	a.start(
		[Mon.create("clefairy", 15)],
		[Mon.create("onix", 100)],
		{"seed": 7, "battle_size": 1, "speed": 1.0, "field_objects": false}
	)
	await process_frame
	for i in 90:
		a.step(DT)
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	e.controller = "none"
	p.controller = "none"
	e.max_hp = 99999  # golpe 4x com crítico (Frenzy Plant no Onix) não pode nocautear o boneco
	var f := FileAccess.open("res://data/moves.json", FileAccess.READ)
	var mj = JSON.parse_string(f.get_as_text())
	var silent := []
	for m in mj.get("moves", []):
		var mv: Dictionary = Dex.move(String(m.id)).duplicate(true)
		if mv.is_empty() or mv.get("kind") == "clones" or mv.get("self_destruct", false):
			continue
		if String(mv.id) in SACRIFICE or String(mv.get("special", "")) in SACRIFICE:
			continue
		mv.accuracy = 0
		p.position = Vector3(-1.0, 0, 0)
		e.position = Vector3(1.0 if mv.kind in ["arc", "multi_arc"] else 2.5, 0, 0)
		p.hp = p.max_hp
		e.hp = e.max_hp
		e.status = ""
		p.status = ""
		var before: int = a.vfx.spawned
		var procs := 0
		a.moves.deliver(p, mv)
		for i in 75:
			a.step(DT)
			e.hp = e.max_hp
			procs = maxi(procs, a.vfx.nodes.filter(func(n): return n is ProcFx).size())
		if procs == 0 and mv.id != "splash":
			silent.append(mv.id)
		check(a.vfx.spawned > before, "%s: algum efeito" % mv.id)
		for i in 120:
			a.step(DT)
			e.hp = e.max_hp
			p.hp = p.max_hp
	check(a.state == "fight", "luta continua (%s)" % a.state)
	check(silent.size() <= 3, "golpes sem efeito procedural: %s" % str(silent))
	# ganchos da mecânica
	var n0: int = a.vfx.spawned
	a.vfx.burrow(p)
	a.vfx.dig_trail(p, p.position, e.position, 0.5)
	for i in 40:
		a.step(DT)
	a.vfx.unburrow(p)
	check(a.vfx.spawned > n0 + 20, "Cavar solta terra (%d)" % (a.vfx.spawned - n0))
	n0 = a.vfx.spawned
	a.vfx.launch(e, Vector3.RIGHT, 4.0)
	for i in 20:
		a.step(DT)
	a.vfx.crash(e, e.position, "cerca")
	a.vfx.blink(p)
	check(a.vfx.spawned > n0 + 10, "arremesso/choque/blink (%d)" % (a.vfx.spawned - n0))
	for hk in [
		["protect_shield", [p, 1.0]],
		["spotlight", [p, 1.0]],
		["screen", [p.side, "light_screen", 1.0]],
		["screen", [p.side, "tailwind", 1.0]],
		["weather", ["rain", 1.0]],
		["weather", ["sun", 1.0]],
		["weather", ["sand", 1.0]],
		["weather", ["hail", 1.0]],
		["terrain", ["grassy", 1.0]],
		["gravity", [1.0]],
		["haze", [p]],
		["toxic_spikes", [e.side, e.position, 1.5, 1.0]],
		["heal", [p]],
	]:
		n0 = a.vfx.spawned
		check(a.vfx.has_method(String(hk[0])), "gancho " + String(hk[0]))
		a.vfx.callv(String(hk[0]), hk[1])
		for i in 20:
			a.step(DT)
		check(a.vfx.spawned > n0, "gancho %s solta efeito" % hk[0])
	for i in 360:
		a.step(DT)
	var left: int = a.vfx.nodes.filter(func(n): return n is ProcFx).size()
	check(left == 0, "peças procedurais somem (%d)" % left)
	host.queue_free()
	await process_frame

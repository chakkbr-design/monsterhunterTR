class_name StaticMon
extends WorldNpc
## Pokémon estático de um mapa (`statics` de data/maps/*.json: Pidgeotto na Rota 2, Fearow na Rota 2 norte,
## Primeape na Rota 22, Raticate na Rota 1, Butterfree e Beedrill na floresta...). Luta uma vez só:
## vencer ou capturar grava flags["static_<uid>"] e ele some; fugir ou perder deixa ele lá.
## Visível: o jogador interage (E). `hidden`: fica escondido e pula na frente quando o jogador chega perto.
## A batalha vai por Overworld.battle -> Game.request_battle ({kind: "wild", can_run: true, static_uid}).

const AMBUSH_SIZE := Vector3(2.4, 3.0, 2.4)

var uid := ""
var species := "Pidgey"
var level := 5
var hidden := false
var fighting := false
var _area: Area3D
var _sprite: Node3D

## Opts extras da batalha (testes: autoplay, seed, speed).
static var battle_extra: Dictionary = {}


static func done(static_uid: String) -> bool:
	return static_uid != "" and bool(Game.flags.get("static_" + static_uid, false))


static func from_entry(e: Dictionary) -> StaticMon:
	var s := StaticMon.new()
	s.uid = String(e.get("uid", ""))
	s.species = String(e.get("species", "Pidgey"))
	s.level = int(e.get("level", 5))
	s.hidden = bool(e.get("hidden", false))
	s.name = "Static_%s" % s.uid
	s.rotation.y = MapBuilder.facing_yaw(e.get("facing", 0))
	return s


func _ready() -> void:
	var nm := String(Dex.species(Dex.canon(species)).get("name", species))
	npc_name = "%s Nv%d" % [nm, level]
	lines = PackedStringArray(["Um %s selvagem está bloqueando o caminho!" % nm])
	body_height = 1.0
	color = Color(0.85, 0.75, 0.4)
	super._ready()
	if hidden:
		_set_shown(false)
		_area = Area3D.new()
		_area.name = "Ambush"
		_area.collision_layer = 0
		_area.collision_mask = OverworldPlayer.LAYER
		_area.monitorable = false
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = AMBUSH_SIZE
		cs.shape = sh
		cs.position.y = AMBUSH_SIZE.y / 2.0
		_area.add_child(cs)
		add_child(_area)
		_area.body_entered.connect(_on_body_entered)


func _build_body() -> void:
	var cs_script := (
		load("res://gfx/creature_sprite.gd")
		if ResourceLoader.exists("res://gfx/creature_sprite.gd")
		else null
	)
	if cs_script:
		_sprite = cs_script.new()
		_sprite.set("species", species)
		_sprite.set("auto_motion", false)
		add_child(_sprite)
		return
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.material = Overworld._mat(color)
	mi.mesh = sm
	mi.position.y = 0.5
	add_child(mi)


func prompt() -> String:
	return "E: Examinar"


func _set_shown(on: bool) -> void:
	visible = on
	collision_layer = LAYER if on else 0
	if on:
		add_to_group(GROUP)
	else:
		remove_from_group(GROUP)


func interact(p: OverworldPlayer) -> void:
	face(p.global_position)
	await say(lines)
	await fight()


func _on_body_entered(b: Node) -> void:
	if (
		fighting
		or visible
		or not b is OverworldPlayer
		or not (b as OverworldPlayer).can_act()
		or Game.first_healthy() < 0
	):
		return
	var p := b as OverworldPlayer
	p.locked = true
	p.velocity = Vector3.ZERO
	p.show_alert(true)
	await get_tree().create_timer(0.6).timeout
	p.show_alert(false)
	_set_shown(true)
	face(p.global_position)
	p.face_toward(global_position)
	await say(
		PackedStringArray(["Um %s selvagem pulou na sua frente!" % npc_name.get_slice(" Nv", 0)])
	)
	p.locked = false
	await fight()


## Uma batalha selvagem com ele. Devolve o resultado ({} se não deu para lutar).
func fight() -> Dictionary:
	if fighting or done(uid):
		return {}
	var ow := Overworld.of(self)
	if ow == null or Game.first_healthy() < 0:
		return {}
	fighting = true
	var opts := {"kind": "wild", "can_run": true, "static_uid": uid}
	opts.merge(battle_extra, true)
	var r := await ow.battle([Mon.create(Dex.canon(species), level)], opts)
	fighting = false
	var outcome := String(r.get("outcome", ""))
	if outcome == "win" or outcome == "caught":
		Game.flags["static_" + uid] = true
		queue_free()
	elif hidden and is_instance_valid(self):
		_set_shown(false)  # volta a se esconder; pula de novo na próxima passagem
	return r

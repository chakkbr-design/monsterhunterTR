class_name CreatureSprite
extends Node3D
## Nó 3D billboard que mostra uma espécie com a arte do original e toca as animações PMD
## (porte do creature.gd/_pmd_* + pokemon_sprites.gd). Usado pela batalha e pelo mundo.
##
## Uso mínimo:
##   var cs := CreatureSprite.new()   # ou preload("res://gfx/creature_sprite.gd").new()
##   cs.species = "Pikachu"
##   add_child(cs)
## Por padrão a velocidade vem do deslocamento do próprio nó (auto_motion) e o sprite vira
## para onde anda (auto_face). A origem do nó é o chão (pés/sombra).
##
## Estados em laço (pmd_anims.json "states"): idle, move, fly, airborne, prepare, sleep, stagger,
## hurt, faint. Defina `state` para forçar um ("" = automático: idle/move pela velocidade).
## One-shots: play(anim), play_chain([...]), play_move(mv, segundos), hurt(), faint(), revive().

signal oneshot_finished(anim: String)

const FACING_MARGIN := 1.25
const FAINT_TIME := 0.3
const FAINT_SCALE := Vector3(1.15, 0.55, 1.15)
const FAINT_TINT := Color(0.55, 0.55, 0.55)

@export var species := "":
	set(v):
		species = v
		if is_inside_tree() or _sprite != null:
			apply_species()
@export var scale_mult := 1.0:
	set(v):
		scale_mult = v
		_apply_scale()
## Calcula a velocidade pelo deslocamento global do nó. Desligue e escreva `velocity` à mão.
@export var auto_motion := true
## Vira o sprite para a direção da velocidade quando anda.
@export var auto_face := true
@export var shaded := true
@export var cast_shadow_on := true
## Sem _process: o dono chama tick(delta) (testes headless).
@export var manual := false

var velocity := Vector3.ZERO
var facing := Vector3(0, 0, 1)
var move_speed := 3.0
var state := ""
var fainted := false
var tint := Color.WHITE:
	set(v):
		tint = v
		_apply_tint()
## Câmera usada para escolher a direção do sprite (null = câmera ativa do viewport).
var camera: Camera3D

var _sprite: Sprite3D
var _look := {}
var _anim := ""
var _t := 0.0
var _oneshot := false
var _hold := -1
var _hold_t := 0.0
var _flap_t := 0.0
var _rate_override := 0.0
var _walking := false
var _collapse_t := -1.0
var _last_pos := Vector3.ZERO
var _has_last := false
var _anim_t := 0.0
var _row := 0
var _base_scale := Vector3.ONE


func _init() -> void:
	_sprite = Sprite3D.new()
	_sprite.name = "Sprite"
	_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	add_child(_sprite, false, Node.INTERNAL_MODE_FRONT)


func _ready() -> void:
	_sprite.shaded = shaded
	_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadow_on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _look.is_empty() and species != "":
		apply_species()
	set_process(not manual)


func _process(delta: float) -> void:
	tick(delta)


## O Sprite3D interno (para modulate, material_overlay, etc.).
func sprite() -> Sprite3D:
	return _sprite


func spec() -> Dictionary:
	return _look


func has_pmd() -> bool:
	return _look.has("pmd")


func current_anim() -> String:
	return _anim


func is_playing_oneshot() -> bool:
	return _oneshot


## Altura visível (m) já com scale_mult: use para nome/barra de HP acima da cabeça.
func visible_height() -> float:
	return float(_look.get("visible_m", 1.0)) * scale_mult


func head_position(extra := 0.0) -> Vector3:
	return global_position + Vector3(0, visible_height() + extra, 0)


func footprint() -> float:
	return PokemonSprites.footprint_m(species) * scale_mult if species != "" else 1.0


func apply_species() -> void:
	if species == "":
		return
	_set_look(PokemonSprites.spec(species))


## Mostra uma textura avulsa (sem animação), ex.: cartas/NPC.
func apply_card(tex: Texture2D) -> void:
	_set_look(PokemonSprites.card(tex))


func _set_look(s: Dictionary) -> void:
	_look = s
	_anim = ""
	_oneshot = false
	_hold = -1
	_collapse_t = -1.0
	_sprite.texture = s.texture
	_sprite.hframes = int(s.hframes)
	_sprite.vframes = int(s.vframes)
	_sprite.frame = 0
	_sprite.pixel_size = float(s.pixel_size)
	_sprite.offset = Vector2(0, float(s.offset_y))
	_sprite.flip_h = false
	tint = s.get("tint", Color.WHITE)
	_apply_scale()
	if fainted:
		_enter_faint_pose()
	_refresh()


func _apply_scale() -> void:
	if _sprite == null:
		return
	_base_scale = Vector3.ONE * scale_mult
	if _collapse_t < 0.0:
		_sprite.scale = _base_scale


func _apply_tint() -> void:
	if _sprite == null:
		return
	var a := _sprite.modulate.a
	_sprite.modulate = Color(tint.r, tint.g, tint.b, a)


func set_alpha(a: float) -> void:
	_sprite.modulate.a = a


# --- direção -----------------------------------------------------------------

func face(dir: Vector3) -> void:
	dir.y = 0.0
	if dir.length_squared() > 0.0001:
		facing = dir.normalized()


func face_point(p: Vector3) -> void:
	face(p - global_position)


## Direção de frente no espaço da tela: x = direita, z = em direção à câmera.
func screen_facing() -> Vector2:
	var cam := camera
	if cam == null and is_inside_tree():
		cam = get_viewport().get_camera_3d()
	if cam == null:
		return Vector2(facing.x, facing.z)
	var b := cam.global_transform.basis
	var right := Vector3(b.x.x, 0, b.x.z).normalized()
	var back := Vector3(b.z.x, 0, b.z.z).normalized()
	return Vector2(facing.dot(right), facing.dot(back))


## Linha PMD de 8 direções (0 = baixo, 2 = direita, 4 = cima, 6 = esquerda).
func dir8() -> int:
	var f := screen_facing()
	return posmod(int(round(atan2(f.x, f.y) / (PI / 4.0))), 8)


static func facing_row(dir: Vector2, prev_row: int) -> int:
	var dx := absf(dir.x)
	var dy := absf(dir.y)
	if prev_row == 1 or prev_row == 2:
		if dy > dx * FACING_MARGIN:
			return 0 if dir.y > 0.0 else 3
		return 1 if dir.x < 0.0 else 2
	if dx > dy * FACING_MARGIN:
		return 1 if dir.x < 0.0 else 2
	return 0 if dir.y > 0.0 else 3


# --- one-shots ---------------------------------------------------------------

## Toca uma animação PMD pelo nome. Retorna false se a espécie não tiver.
func play(anim: String, oneshot := true, hold := -1, hold_t := 0.0) -> bool:
	var pmd: Dictionary = _look.get("pmd", {})
	if not pmd.has(anim):
		return false
	_play(anim, oneshot, hold, hold_t)
	return true


## Toca a primeira animação da cadeia que existir. Retorna o nome tocado ("" se nenhum).
func play_chain(chain: Array, oneshot := true) -> String:
	var name := resolve(chain)
	if name != "":
		_play(name, oneshot)
	return name


func resolve(chain: Array) -> String:
	var pmd: Dictionary = _look.get("pmd", {})
	for n in chain:
		if pmd.has(n):
			return String(n)
	return ""


## Animação de golpe pelo pmd_anims.json (moves > kinds). `secs` = duração do golpe,
## usada para segurar o RushFrame (dash) ou o HitFrame (stream/beam).
func play_move(mv: Dictionary, secs := -1.0) -> String:
	if not has_pmd():
		_bump()
		return ""
	var chains := PokemonSprites.pmd_anims()
	var id := String(mv.get("id", ""))
	var kind := String(mv.get("kind", ""))
	var flap: Dictionary = chains.get("flap", {})
	if id in flap.get("moves", []):
		var wings := resolve(flap.get("chain", []))
		if wings != "":
			_play(wings, true)
			_flap_t = maxf(secs, float(flap.get("secs", 0.7)))
			_rate_override = float(flap.get("rate", 2.0))
			return wings
	var name := resolve(PokemonSprites.move_chain(mv))
	if name == "":
		_bump()
		return ""
	var a: Dictionary = _look.pmd[name]
	var swoop: Array = chains.get("swoop", {}).get("moves", [])
	if kind == "dash" and not (id in swoop) and secs > 0.0 and int(a.rush) >= 0:
		_play(name, true, int(a.rush), secs)
	elif (kind == "stream" or kind == "beam") and secs > 0.0 and int(a.hit) >= 0:
		_play(name, true, int(a.hit), secs)
	else:
		_play(name, true)
	return name


func hurt() -> void:
	if not has_pmd():
		_bump()
		return
	if fainted:
		return
	play_chain(PokemonSprites.state_chain("hurt"), true)


func faint() -> void:
	fainted = true
	_enter_faint_pose()


func revive() -> void:
	fainted = false
	_collapse_t = -1.0
	_sprite.scale = _base_scale
	_apply_tint()
	_oneshot = false
	_anim = ""
	_refresh()


func _enter_faint_pose() -> void:
	_oneshot = false
	_hold = -1
	if has_pmd() and _look.pmd.has("Faint"):
		_play("Faint", false)
		return
	_collapse_t = 0.0
	if has_pmd() and _look.pmd.has("Hurt"):
		_play("Hurt", true)


## Pulo curto para quem não tem PMD (sem animação de ataque).
func _bump() -> void:
	var tw := create_tween() if is_inside_tree() else null
	if tw == null:
		return
	tw.tween_property(_sprite, "position:y", 0.18 * scale_mult, 0.08)
	tw.tween_property(_sprite, "position:y", 0.0, 0.12)


# --- laço ----------------------------------------------------------------------

func tick(delta: float) -> void:
	if _look.is_empty():
		if species == "":
			return
		apply_species()
	_update_motion(delta)
	if has_pmd():
		_tick_pmd(delta)
	else:
		_tick_static(delta)
	_tick_collapse(delta)


func _update_motion(delta: float) -> void:
	if auto_motion and is_inside_tree():
		var p := global_position
		if _has_last and delta > 0.0:
			velocity = (p - _last_pos) / delta
		_last_pos = p
		_has_last = true
	var flat := Vector2(velocity.x, velocity.z)
	var speed := flat.length()
	_walking = speed > (0.15 if _walking else 0.35)
	if auto_face and _walking:
		face(Vector3(velocity.x, 0, velocity.z))


## Teleporte: não conta como andar no próximo tick.
func reset_motion() -> void:
	_has_last = false
	velocity = Vector3.ZERO
	_walking = false


func _state_name() -> String:
	if fainted:
		return "faint"
	if state != "":
		return state
	return "move" if _walking else "idle"


func _state_anim() -> String:
	var name := resolve(PokemonSprites.state_chain(_state_name()))
	if name == "" and fainted and _anim != "":
		return _anim
	if name == "" and _state_name() != "idle":
		name = resolve(PokemonSprites.state_chain("idle"))
	return name if name != "" else _anim


func _play(name: String, oneshot: bool, hold := -1, hold_t := 0.0) -> void:
	if name == _anim and not oneshot and not _oneshot:
		return
	var pmd: Dictionary = _look.get("pmd", {})
	if not pmd.has(name):
		return
	_anim = name
	_t = 0.0
	_oneshot = oneshot
	_hold = hold
	_hold_t = hold_t
	_flap_t = 0.0
	_rate_override = 0.0
	var a: Dictionary = pmd[name]
	_sprite.texture = a.texture
	_sprite.hframes = int(a.frames)
	_sprite.vframes = int(a.dirs)
	_frame(0)


func _end_oneshot() -> void:
	var was := _anim
	_oneshot = false
	_hold = -1
	_hold_t = 0.0
	_flap_t = 0.0
	_rate_override = 0.0
	_play(_state_anim(), false)
	oneshot_finished.emit(was)


func _rate() -> float:
	if _rate_override > 0.0:
		return _rate_override
	if _anim == "Walk":
		return clampf(Vector2(velocity.x, velocity.z).length() / maxf(move_speed, 0.1), 0.6, 2.0)
	return float(PokemonSprites.pmd_anims().get("rates", {}).get(_anim, 1.0))


func _tick_pmd(delta: float) -> void:
	var pmd: Dictionary = _look.pmd
	if _anim == "" or not pmd.has(_anim):
		_play(_state_anim(), false)
	if not pmd.has(_anim):
		return
	var a: Dictionary = pmd[_anim]
	if _oneshot:
		if _hold >= 0:
			_hold_t -= delta
			if _hold_t <= 0.0:
				_end_oneshot()
				return
			_frame(_hold)
			return
		if _flap_t > 0.0:
			_flap_t -= delta
			if _flap_t <= 0.0:
				_end_oneshot()
				return
		elif _t >= total_time(a):
			_end_oneshot()
			return
	else:
		var want := _state_anim()
		if want != "" and want != _anim:
			_play(want, false)
			a = pmd[_anim]
	_t += delta * _rate()
	var total := total_time(a)
	var t := _t
	if fainted and not _oneshot:
		t = minf(t, total - 0.0001)
	elif t >= total:
		if _flap_t > 0.0 or not _oneshot:
			t = fmod(t, total)
			_t = t
	_frame(frame_at(a.durations, t))


func _frame(frame: int) -> void:
	var a: Dictionary = _look.pmd[_anim]
	var frames := int(a.frames)
	var dirs := int(a.dirs)
	var row := 0
	if dirs > 1:
		row = dir8() % dirs
	var f := clampi(frame, 0, frames - 1)
	_sprite.frame = row * frames + f
	_sprite.flip_h = false
	var rows: Array = a.get("anchor", [])
	if rows.is_empty():
		_sprite.offset = Vector2(0.0, float(_look.get("offset_y", 0.0)))
	else:
		var pts: Array = rows[clampi(row, 0, rows.size() - 1)]
		var p: Array = pts[clampi(f, 0, pts.size() - 1)]
		_sprite.offset = Vector2(float(a.w) / 2.0 - float(p[0]), float(p[1]) - float(a.h) / 2.0)


func _tick_static(delta: float) -> void:
	var s := _look
	var asleep := _state_name() == "sleep" or fainted
	_anim_t += delta * (7.0 if _walking else 2.0)
	var step := 0 if asleep else int(_anim_t)
	var f := screen_facing()
	if bool(s.get("static", false)):
		_sprite.frame = 0
		if absf(f.x) > 0.1:
			_sprite.flip_h = (f.x > 0.0) != (String(s.get("faces", "left")) == "right")
		return
	_row = facing_row(f, _row)
	var dir: String = ["down", "left", "right", "up"][_row]
	var rows: Dictionary = s.get("rows", PokemonSprites.DEFAULT_ROWS)
	var fpr := maxi(1, int(s.frames_per_row))
	var r := clampi(int(rows.get(dir, 0)), 0, int(s.vframes) - 1)
	_sprite.frame = r * fpr + (step % fpr)
	if fainted and _collapse_t < 0.0:
		_collapse_t = 0.0


func _tick_collapse(delta: float) -> void:
	if _collapse_t < 0.0 or _oneshot or _collapse_t >= FAINT_TIME:
		return
	_collapse_t = minf(_collapse_t + delta, FAINT_TIME)
	var k := _collapse_t / FAINT_TIME
	_sprite.scale = _base_scale * Vector3.ONE.lerp(FAINT_SCALE, k)
	var c := tint.lerp(FAINT_TINT, k)
	_sprite.modulate = Color(c.r, c.g, c.b, _sprite.modulate.a)


func _refresh() -> void:
	if has_pmd():
		_play(_state_anim(), false)
	else:
		_tick_static(0.0)


static func total_time(a: Dictionary) -> float:
	var total := 0.0
	for d in a.durations:
		total += float(d)
	return maxf(total, 1.0 / 60.0)


static func frame_at(durs: Array, t: float) -> int:
	var acc := 0.0
	for i in durs.size():
		acc += float(durs[i])
		if t < acc:
			return i
	return maxi(0, durs.size() - 1)

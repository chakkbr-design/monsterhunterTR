class_name FxSprite
extends Node3D
## Flipbook 3D determinístico (folha com `frames` colunas × `rows` linhas). Avança só em tick(dt),
## então a batalha controla o tempo (velocidade da luta, hit-stop, testes headless).
## Com `auto = true` ele mesmo chama tick no _process e se libera ao terminar (uso no mundo).

var sprite: Sprite3D
var frames := 1
var row := 0
var lo := 0
var hi := 0
var fps := 12.0
var loop := false
## Tempo de vida fixo (s). <= 0: até a animação acabar (ou para sempre, se loop).
var life := 0.0
var fade := 0.12
var velocity := Vector3.ZERO
var follow: Node3D
var follow_offset := Vector3.ZERO
var auto := false
var age := 0.0
var _mat: StandardMaterial3D
var _base_alpha := 1.0


static func create(tex: Texture2D, frame_count: int, rows_count := 1) -> FxSprite:
	var f := FxSprite.new()
	f.sprite = Sprite3D.new()
	f.sprite.name = "Sprite"
	f.sprite.texture = tex
	f.sprite.hframes = maxi(1, frame_count)
	f.sprite.vframes = maxi(1, rows_count)
	f.sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	f.sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	f.sprite.shaded = false
	f.sprite.transparent = true
	f.sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	f.frames = maxi(1, frame_count)
	f.hi = f.frames - 1
	f.add_child(f.sprite)
	return f


## Mistura aditiva (brilho) em vez de alfa.
func set_additive(on: bool) -> void:
	if not on:
		sprite.material_override = null
		_mat = null
		return
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_mat.albedo_texture = sprite.texture
	_mat.billboard_mode = sprite.billboard
	_mat.no_depth_test = sprite.no_depth_test
	_mat.vertex_color_use_as_albedo = true
	sprite.material_override = _mat


func set_tint(c: Color) -> void:
	sprite.modulate = c
	_base_alpha = c.a


func duration() -> float:
	if life > 0.0:
		return life
	return float(hi - lo + 1) / maxf(fps, 0.01)


func _ready() -> void:
	_apply_frame(0.0)
	set_process(auto)


func _process(delta: float) -> void:
	if not tick(delta):
		queue_free()


## Avança; devolve false quando terminou (quem gerencia libera o nó).
func tick(dt: float) -> bool:
	age += dt
	if velocity != Vector3.ZERO:
		position += velocity * dt
	if is_instance_valid(follow) and follow.is_inside_tree() and is_inside_tree():
		global_position = follow.global_position + follow_offset
	var total := duration()
	if not loop and life <= 0.0 and age >= total:
		return false
	if life > 0.0 and age >= life:
		return false
	_apply_frame(age)
	if fade > 0.0 and (life > 0.0 or not loop):
		var left := total - age
		var a := clampf(left / fade, 0.0, 1.0) * _base_alpha
		sprite.modulate.a = a
	return true


func _apply_frame(t: float) -> void:
	var n := hi - lo + 1
	var i := int(t * fps)
	if loop:
		i = posmod(i, n)
	else:
		i = mini(i, n - 1)
	sprite.frame = clampi(row, 0, sprite.vframes - 1) * sprite.hframes + clampi(lo + i, 0, sprite.hframes - 1)

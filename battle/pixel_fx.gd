class_name PixelFx
extends Sprite3D
## Efeito de pixel art (Pixel Lab) em Sprite3D animado por quadros. Compatível com BattleVfx.nodes:
## tick(dt) -> bool (false = acabou, o BattleVfx libera). Sempre com fallback: se o PNG não carregar,
## make() devolve null e quem chamou mantém o visual antigo.

const DIR := "res://assets/pixellab/"
## Catálogo: chave -> arquivo, quadros, colunas, fps, lado do quadro em px.
## Os "_loop" são tiras 1xN montadas de folhas 8x8 do Pixel Lab (quadros escolhidos); o resto é 1 quadro.
const FX := {
	"fire": {"file": "fx/fire_burst.png", "frames": 1, "cols": 1, "fps": 1.0, "px": 64},
	"fire_loop": {"file": "fx/fire_loop.png", "frames": 8, "cols": 8, "fps": 16.0, "px": 16},
	"flame": {"file": "fx/flame_loop.png", "frames": 8, "cols": 8, "fps": 14.0, "px": 16},
	"electric": {"file": "fx/electric_loop.png", "frames": 8, "cols": 8, "fps": 16.0, "px": 24},
	"spark": {"file": "fx/spark_loop.png", "frames": 8, "cols": 8, "fps": 16.0, "px": 16},
	"impact": {"file": "fx/impact_yellow.png", "frames": 1, "cols": 1, "fps": 1.0, "px": 32},
	"impact_red": {"file": "fx/impact_red.png", "frames": 1, "cols": 1, "fps": 1.0, "px": 32},
	"poison": {"file": "fx/poison_burst.png", "frames": 1, "cols": 1, "fps": 1.0, "px": 64},
	"arcane": {"file": "fx/arcane_burst.png", "frames": 1, "cols": 1, "fps": 1.0, "px": 64},
	"dust": {"file": "fx/dust_ring.png", "frames": 1, "cols": 1, "fps": 1.0, "px": 64},
	"stone": {"file": "fx/stone_ring.png", "frames": 1, "cols": 1, "fps": 1.0, "px": 64},
	"wind": {"file": "fx/wind_ring.png", "frames": 1, "cols": 1, "fps": 1.0, "px": 64},
	"leaf": {"file": "fx/leaf_ring.png", "frames": 1, "cols": 1, "fps": 1.0, "px": 64},
	"water": {"file": "fx/water_swirl.png", "frames": 1, "cols": 1, "fps": 1.0, "px": 64},
	"snow": {"file": "fx/snowflake.png", "frames": 1, "cols": 1, "fps": 1.0, "px": 32},
	"curse": {"file": "fx/curse_circle.png", "frames": 1, "cols": 1, "fps": 1.0, "px": 64},
	"sparkle": {"file": "fx/spark_blue.png", "frames": 1, "cols": 1, "fps": 1.0, "px": 32},
	"magic": {"file": "fx/spark_purple.png", "frames": 1, "cols": 1, "fps": 1.0, "px": 32},
	"shock": {"file": "fx/shockwave.png", "frames": 1, "cols": 1, "fps": 1.0, "px": 20},
	"bubble": {"file": "fx/bubble.png", "frames": 1, "cols": 1, "fps": 1.0, "px": 32},
	"leaf_bit": {"file": "fx/leaf.png", "frames": 1, "cols": 1, "fps": 1.0, "px": 32},
}
## Tipo Pokémon -> efeito de estouro.
const TYPE_FX := {
	"normal": "impact",
	"fire": "fire",
	"water": "water",
	"electric": "electric",
	"grass": "leaf",
	"ice": "wind",
	"fighting": "impact_red",
	"poison": "poison",
	"ground": "dust",
	"flying": "wind",
	"psychic": "arcane",
	"bug": "poison",
	"rock": "stone",
	"ghost": "curse",
	"dragon": "arcane",
	"dark": "curse",
	"steel": "impact",
	"fairy": "magic",
}

static var _cache := {}  ## caminho -> Texture2D (ou null se não carregou)

var life := 0.4  ## duração (s); em loop=true só acaba quando alguém chama stop()
var loop := false
var grow := 1.3  ## escala final em relação à inicial
var fade := 0.35  ## fração final da vida em que some
var rise := 0.0  ## sobe (m/s)
var spin := 0.0  ## gira (rad/s)
var fps := 12.0
var nframes := 1
var age := 0.0
var _base := 1.0
var _stopped := false


## Cria o sprite (sem pôr na árvore). null se o arquivo não carregar.
static func make(
	path: String, frames: int, cols: int, fps_: float, pixel_size: float, billboard := true
) -> PixelFx:
	var tex := _tex(path)
	if tex == null:
		return null
	var f := PixelFx.new()
	f.texture = tex
	f.hframes = maxi(cols, 1)
	f.vframes = maxi(ceili(float(frames) / float(maxi(cols, 1))), 1)
	f.nframes = maxi(frames, 1)
	f.fps = maxf(fps_, 0.01)
	f.pixel_size = pixel_size
	f.life = float(f.nframes) / f.fps
	f.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	f.shaded = false
	f.double_sided = true
	f.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	f.transparent = true
	f.billboard = (
		BaseMaterial3D.BILLBOARD_ENABLED if billboard else BaseMaterial3D.BILLBOARD_DISABLED
	)
	f.frame = 0
	f._base = 1.0
	return f


static func _tex(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		var r = load(path)
		if r is Texture2D:
			t = r
	_cache[path] = t
	return t


## Cria pelo catálogo FX: `size` = largura do quadro em metros. null se a chave/arquivo não existir.
static func from_key(key: String, size: float, life_ := -1.0) -> PixelFx:
	if not FX.has(key):
		return null
	var d: Dictionary = FX[key]
	var f := make(
		DIR + String(d.file), int(d.frames), int(d.cols), float(d.fps), size / float(d.px), true
	)
	if f != null and life_ > 0.0:
		f.life = life_
		f.loop = false
	return f


## Efeito de estouro para um tipo Pokémon.
static func key_for_type(type: String) -> String:
	return String(TYPE_FX.get(type, "impact"))


## Cria e registra no BattleVfx da arena um efeito em `at` (local da arena). Devolve o nó ou null
## (sem vfx, desligado, fora da árvore ou sem arte): quem chamou deve manter o visual antigo.
static func pop(arena: Node, key: String, at: Vector3, size := 1.4, life_ := 0.45) -> PixelFx:
	if arena == null or not arena.is_inside_tree():
		return null
	var vfx = arena.get("vfx")
	if vfx == null or not vfx.enabled:
		return null
	var f := from_key(key, size, life_)
	if f == null:
		return null
	arena.add_child(f)
	f.position = at
	vfx._track(f)
	return f


## Decalque deitado no chão (sem animação). null se a arte não carregar.
static func decal(file: String, diameter: float, px: int, tint := Color.WHITE) -> Sprite3D:
	var tex := _tex(DIR + file)
	if tex == null:
		return null
	var s := Sprite3D.new()
	s.texture = tex
	s.pixel_size = diameter / float(px)
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.shaded = false
	s.double_sided = true
	s.transparent = true
	s.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	s.rotation_degrees = Vector3(-90, 0, 0)
	s.modulate = tint
	return s


## Sprite parado em pé (caixa, pedra, frutinha), em billboard no eixo Y. null se não carregar.
static func prop(file: String, height_m: float, px: int) -> Sprite3D:
	var tex := _tex(DIR + file)
	if tex == null:
		return null
	var s := Sprite3D.new()
	s.texture = tex
	s.pixel_size = height_m / float(px)
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.shaded = false
	s.double_sided = true
	s.transparent = true
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.centered = true
	s.offset = Vector2(0, float(px) * 0.5)  # pés no ponto de origem
	return s


## Ícone pequeno de HUD (assets/pixellab/icons/<nome>.png) ou null.
static func icon(name: String) -> Texture2D:
	return _tex(DIR + "icons/" + name + ".png")


## Termina o efeito em laço (some em seguida).
func stop() -> void:
	_stopped = true
	loop = false
	life = minf(life, age + 0.15)


func tick(dt: float) -> bool:
	age += dt
	if nframes > 1:
		var k := int(age * fps)
		frame = k % nframes if loop else mini(k, nframes - 1)
	var t := clampf(age / maxf(life, 0.01), 0.0, 1.0)
	if loop and not _stopped:
		t = 0.0
	var pop_k := 1.0 - pow(1.0 - clampf(age / 0.12, 0.0, 1.0), 2.0)
	var s := lerpf(0.5, 1.0, pop_k) * lerpf(1.0, grow, t)
	scale = Vector3.ONE * s * _base
	position.y += rise * dt
	if spin != 0.0:
		rotate_z(spin * dt)
	var a := 1.0
	if t > 1.0 - fade:
		a = clampf((1.0 - t) / maxf(fade, 0.01), 0.0, 1.0)
	modulate.a = a
	return loop and not _stopped or age < life

class_name Fx3DParticles
extends MultiMeshInstance3D
## Partículas simuladas na CPU e desenhadas num MultiMesh (quadrados virados para a câmera no
## shader, gfx/fx3d/shaders). Coordenadas no mundo (top_level). Avançam só em tick(dt), então seguem
## a velocidade da luta, a pausa e a câmera lenta. Sem RNG da batalha (randf global, só visual).

const STRIDE := 20  # 12 da transformada + 4 da cor + 4 do custom

var cap := 64
var n := 0
var pos := PackedVector3Array()
var vel := PackedVector3Array()
var age := PackedFloat32Array()
var life := PackedFloat32Array()
var sz0 := PackedFloat32Array()
var sz1 := PackedFloat32Array()
var rot := PackedFloat32Array()
var spin := PackedFloat32Array()
var c0 := PackedColorArray()
var c1 := PackedColorArray()

var gravity := Vector3.ZERO
var drag := 0.0
var fade_in := 0.12  ## fração da vida
var fade_out := 0.45  ## fração da vida
## Atração para um ponto (ou nó) e giro em volta dele no eixo Y (carga, redemoinho).
var attract_node: Node3D
var attract_off := Vector3.ZERO
var attract_point := Vector3.ZERO
var attract_k := 0.0
var orbit_k := 0.0
var kill_near := 0.0  ## some ao chegar a esta distância do ponto de atração
var floor_y := -INF  ## para e escorrega no chão
var turb := 0.0  ## empurrão aleatório (m/s²)
## Emissão contínua: spawn.call(self) `rate` vezes por segundo durante `emit_for` s.
var spawn: Callable
var rate := 0.0
var emit_for := 0.0
var follow: Node3D  ## anda junto com o nó (as partículas vivas também, por `carry`)
var carry := 0.0  ## 0..1: quanto as partículas acompanham o movimento do nó seguido
var _follow_prev := Vector3.ZERO
var t := 0.0
var max_t := 8.0
var _acc := 0.0
var _buf := PackedFloat32Array()


static func make(mat: Material, capacity := 64) -> Fx3DParticles:
	var p := Fx3DParticles.new()
	p.cap = maxi(capacity, 1)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = Fx3D.quad()
	mm.instance_count = p.cap
	mm.visible_instance_count = 0
	p.multimesh = mm
	p.material_override = mat
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.top_level = true
	p.extra_cull_margin = 16.0
	p.ignore_occlusion_culling = true
	p._buf.resize(p.cap * STRIDE)
	return p


## Solta uma partícula (posição no mundo).
func emit(
	at: Vector3,
	v: Vector3,
	lifetime: float,
	size_a: float,
	size_b: float,
	col_a: Color,
	col_b: Color,
	r := 0.0,
	s := 0.0
) -> void:
	var i := n
	if n >= cap:
		i = randi() % cap  # cheio: troca uma qualquer
	else:
		n += 1
		if pos.size() < n:
			pos.resize(cap)
			vel.resize(cap)
			age.resize(cap)
			life.resize(cap)
			sz0.resize(cap)
			sz1.resize(cap)
			rot.resize(cap)
			spin.resize(cap)
			c0.resize(cap)
			c1.resize(cap)
	pos[i] = at
	vel[i] = v
	age[i] = 0.0
	life[i] = maxf(lifetime, 0.02)
	sz0[i] = size_a
	sz1[i] = size_b
	rot[i] = r
	spin[i] = s
	c0[i] = col_a
	c1[i] = col_b


func emitting() -> bool:
	return spawn.is_valid() and t < emit_for


func tick(dt: float) -> bool:
	t += dt
	if not is_inside_tree():
		return false
	if follow != null:
		if is_instance_valid(follow) and follow.is_inside_tree():
			var fp := follow.global_position
			if carry > 0.0 and t > dt:
				var d := (fp - _follow_prev) * carry
				for i in n:
					pos[i] += d
			_follow_prev = fp
		else:
			follow = null
			emit_for = 0.0
	if emitting() and rate > 0.0:
		_acc += dt * rate
		while _acc >= 1.0:
			_acc -= 1.0
			spawn.call(self)
	var ap := attract_point
	if attract_node != null and is_instance_valid(attract_node) and attract_node.is_inside_tree():
		ap = attract_node.global_position + attract_off
	var i := 0
	while i < n:
		age[i] += dt
		if age[i] >= life[i]:
			_kill(i)
			continue
		var v := vel[i]
		if attract_k != 0.0 or orbit_k != 0.0:
			var to := ap - pos[i]
			var dist := to.length()
			if kill_near > 0.0 and dist < kill_near:
				_kill(i)
				continue
			if dist > 0.001:
				v += to / dist * attract_k * dt
				if orbit_k != 0.0:
					v += Vector3(-to.z, 0.0, to.x).normalized() * orbit_k * dt
		v += gravity * dt
		if turb > 0.0:
			v += Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * turb * dt
		if drag > 0.0:
			v *= maxf(1.0 - drag * dt, 0.0)
		var p := pos[i] + v * dt
		if p.y < floor_y:
			p.y = floor_y
			v.y = 0.0
			v.x *= 0.8
			v.z *= 0.8
		pos[i] = p
		vel[i] = v
		rot[i] += spin[i] * dt
		i += 1
	_upload()
	return n > 0 or emitting() and t < max_t


func _kill(i: int) -> void:
	n -= 1
	if i == n:
		return
	pos[i] = pos[n]
	vel[i] = vel[n]
	age[i] = age[n]
	life[i] = life[n]
	sz0[i] = sz0[n]
	sz1[i] = sz1[n]
	rot[i] = rot[n]
	spin[i] = spin[n]
	c0[i] = c0[n]
	c1[i] = c1[n]


func _upload() -> void:
	var mm := multimesh
	for i in n:
		var k := age[i] / life[i]
		var s := lerpf(sz0[i], sz1[i], k)
		var c := c0[i].lerp(c1[i], k)
		c.a *= Fx3D.env(k, fade_in, fade_out)
		var p := pos[i]
		var v := vel[i]
		var o := i * STRIDE
		_buf[o] = s
		_buf[o + 1] = 0.0
		_buf[o + 2] = 0.0
		_buf[o + 3] = p.x
		_buf[o + 4] = 0.0
		_buf[o + 5] = s
		_buf[o + 6] = 0.0
		_buf[o + 7] = p.y
		_buf[o + 8] = 0.0
		_buf[o + 9] = 0.0
		_buf[o + 10] = s
		_buf[o + 11] = p.z
		_buf[o + 12] = c.r
		_buf[o + 13] = c.g
		_buf[o + 14] = c.b
		_buf[o + 15] = c.a
		_buf[o + 16] = v.x
		_buf[o + 17] = v.y
		_buf[o + 18] = v.z
		_buf[o + 19] = rot[i]
	mm.buffer = _buf
	mm.visible_instance_count = n

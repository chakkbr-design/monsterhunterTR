class_name Fx3DMesh
extends MeshInstance3D
## Malha de efeito com vida: anel de choque, casca de energia, feixe, funil, pedra/cristal.
## Escala de s0 até s1 (com ease), some no fim, pode girar e seguir um nó. tick(dt) -> bool.

var life := 0.5
var age := 0.0
var s0 := Vector3.ONE
var s1 := Vector3.ONE
var fade_in := 0.08
var fade_out := 0.5
var spin := Vector3.ZERO  ## rad/s em cada eixo local
var phase_speed := 1.0
var alpha := 1.0
var follow: Node3D
var follow_off := Vector3.ZERO
var vel := Vector3.ZERO
var gravity := 0.0
var floor_y := -INF
var on_floor: Callable  ## chamado uma vez quando bate no chão
var grow_ease := true
var shaded := false  ## malha sólida (pedra): sem parâmetros de instância
var _base := Basis()


static func make(mesh: Mesh, mat: Material, col := Color.WHITE) -> Fx3DMesh:
	var m := Fx3DMesh.new()
	m.mesh = mesh
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.top_level = true
	m.set_instance_shader_parameter("tint", col)
	m.set_instance_shader_parameter("fade", 0.0)
	return m


## Sólido sombreado (pedra, gelo, folha) que projeta sombra.
static func make_solid(mesh: Mesh, col: Color, emit := 0.0, metallic := 0.0) -> Fx3DMesh:
	var m := Fx3DMesh.new()
	m.mesh = mesh
	m.shaded = true
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.35 if emit > 0.0 else 0.85
	mat.metallic = metallic
	if col.a < 0.99:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emit > 0.0:
		mat.emission_enabled = true
		mat.emission = col
		mat.emission_energy_multiplier = emit
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.material_override = mat
	m.top_level = true
	return m


func place(at: Vector3, b := Basis()) -> Fx3DMesh:
	_base = b
	global_transform = Transform3D(_base.scaled(s0), at)
	return self


func tick(dt: float) -> bool:
	age += dt
	if age >= life or not is_inside_tree():
		return false
	var k := age / life
	var g := Fx3D.ease_out(k) if grow_ease else k
	if spin != Vector3.ZERO:
		_base = _base * Basis.from_euler(spin * dt)
	var at := global_position
	if follow != null:
		if is_instance_valid(follow) and follow.is_inside_tree():
			at = follow.global_position + follow_off
		else:
			follow = null
	if vel != Vector3.ZERO or gravity != 0.0:
		vel.y -= gravity * dt
		at += vel * dt
		if at.y < floor_y:
			at.y = floor_y
			vel = Vector3.ZERO
			gravity = 0.0
			if on_floor.is_valid():
				var cb := on_floor
				on_floor = Callable()
				cb.call(self)
	var sc := s0.lerp(s1, g)
	var a := alpha * Fx3D.env(k, fade_in, fade_out)
	if shaded:
		var mat := material_override as StandardMaterial3D
		if mat and mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			mat.albedo_color.a = a
		elif k > fade_in:
			sc *= maxf(a, 0.01)  # sólido opaco: encolhe no fim em vez de sumir
	else:
		set_instance_shader_parameter("fade", a)
		set_instance_shader_parameter("phase", age * phase_speed)
	global_transform = Transform3D(_base.orthonormalized().scaled(sc), at)
	return true

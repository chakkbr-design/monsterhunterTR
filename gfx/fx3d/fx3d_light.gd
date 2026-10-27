class_name Fx3DLight
extends OmniLight3D
## Luz de efeito: acende rápido, segura e apaga (com tremor opcional). No máximo MAX ao mesmo
## tempo (as que passam do limite não acendem), sem sombra.

const MAX := 12

static var alive := 0

var life := 0.4
var age := 0.0
var peak := 3.0
var attack := 0.05  ## s
var hold := 0.0  ## fração da vida antes de apagar
var flicker := 0.0
var follow: Node3D
var follow_off := Vector3.ZERO
var _counted := false


static func make(col: Color, energy: float, radius: float, secs: float) -> Fx3DLight:
	if alive >= MAX:
		return null
	var l := Fx3DLight.new()
	l.light_color = col
	l.peak = energy
	l.omni_range = radius
	l.omni_attenuation = 1.2
	l.life = maxf(secs, 0.05)
	l.light_energy = 0.0
	l.shadow_enabled = false
	l.top_level = true
	l.light_specular = 0.6
	alive += 1
	l._counted = true
	return l


func _exit_tree() -> void:
	if _counted:
		_counted = false
		alive = maxi(alive - 1, 0)


func tick(dt: float) -> bool:
	age += dt
	if age >= life or not is_inside_tree():
		return false
	if follow != null:
		if is_instance_valid(follow) and follow.is_inside_tree():
			global_position = follow.global_position + follow_off
		else:
			follow = null
	var e := 1.0
	if age < attack:
		e = age / attack
	else:
		var k := (age - attack) / maxf(life - attack, 0.01)
		if k > hold:
			e = 1.0 - (k - hold) / maxf(1.0 - hold, 0.01)
			e *= e
	if flicker > 0.0:
		e *= 1.0 - flicker * randf()
	light_energy = peak * e
	return true

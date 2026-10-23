class_name PokeBall3D
extends Node3D
## Poké Ball 3D do original (capture_fx.gd make_ball): metades, faixa, botão que brilha, tampa que abre.
## Sem tweens: quem anima escreve `spin`, `wobble`, `lid` e `glow` (a arena faz isso no seu step).

const R := 0.17
const LID_OPEN := -1.1

var pivot: Node3D
var body: Node3D
var lid_node: Node3D
var button_mat: StandardMaterial3D


static func _mat(col: Color, rough := 0.35, emissive := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic_specular = 0.7
	if emissive:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = 0.0
	return m


static func _hemi(col: Color) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = R
	sm.height = R
	sm.is_hemisphere = true
	sm.radial_segments = 32
	sm.rings = 12
	sm.material = _mat(col)
	var mi := MeshInstance3D.new()
	mi.mesh = sm
	return mi


static func _cyl(radius: float, height: float, col: Color, emissive := false) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 32
	cm.material = _mat(col, 0.5, emissive)
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	return mi


## top/accent: cores do items.json ("top", "accent") da bola.
static func create(top := Color("#e3352b"), accent: Variant = null) -> PokeBall3D:
	var ball := PokeBall3D.new()
	ball.name = "Ball"
	ball.pivot = Node3D.new()
	ball.pivot.name = "Pivot"
	ball.pivot.position = Vector3(0, -R, 0)
	ball.add_child(ball.pivot)
	ball.body = Node3D.new()
	ball.body.name = "Body"
	ball.body.position = Vector3(0, R, 0)
	ball.pivot.add_child(ball.body)
	var bottom := _hemi(Color(0.96, 0.96, 0.94))
	bottom.rotation.x = PI
	ball.body.add_child(bottom)
	ball.lid_node = Node3D.new()
	ball.lid_node.name = "Lid"
	ball.lid_node.position = Vector3(0, 0, -R)
	ball.body.add_child(ball.lid_node)
	var topm := _hemi(top)
	topm.position = Vector3(0, 0, R)
	ball.lid_node.add_child(topm)
	if accent is Color:
		var tm := TorusMesh.new()
		tm.inner_radius = R * 0.74
		tm.outer_radius = R * 0.86
		tm.rings = 32
		tm.material = _mat(accent)
		var ring := MeshInstance3D.new()
		ring.mesh = tm
		ring.position = Vector3(0, R * 0.52, R)
		ball.lid_node.add_child(ring)
	ball.body.add_child(_cyl(R * 1.015, R * 0.16, Color(0.08, 0.08, 0.09)))
	var ring_b := _cyl(R * 0.34, R * 0.2, Color(0.08, 0.08, 0.09))
	ring_b.rotation.x = PI / 2.0
	ring_b.position = Vector3(0, 0, R * 0.93)
	ball.body.add_child(ring_b)
	var button := _cyl(R * 0.22, R * 0.2, Color(0.97, 0.97, 0.97), true)
	button.rotation.x = PI / 2.0
	button.position = Vector3(0, 0, R)
	ball.body.add_child(button)
	ball.button_mat = button.mesh.material
	return ball


## Bola pelo id do items.json (campos top/accent).
static func for_item(item: Dictionary) -> PokeBall3D:
	var acc: Variant = null
	if item.get("accent") is String:
		acc = Color(String(item.accent))
	return create(Color(String(item.get("top", "#e3352b"))), acc)


func set_glow(col: Color, energy: float) -> void:
	button_mat.emission = col
	button_mat.emission_energy_multiplier = energy


## 0 = fechada, 1 = aberta.
func set_lid(open_k: float) -> void:
	lid_node.rotation.x = LID_OPEN * clampf(open_k, 0.0, 1.0)


## Balanço lateral (rad) em torno do ponto de apoio.
func set_wobble(z: float) -> void:
	pivot.rotation.z = z


func set_spin(x: float) -> void:
	body.rotation.x = x

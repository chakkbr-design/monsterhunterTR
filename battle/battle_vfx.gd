class_name BattleVfx
extends RefCounted
## Efeitos visuais da batalha com a arte do original (move_fx.json + vfx/pmd + beams + flame_jet).
## Tudo avança em tick(dt) chamado pela arena (velocidade da luta, testes headless). Não mexe em gameplay.

var arena: Node3D
var nodes: Array = []  # FxSprite / BeamFx / emissores com tick(dt) -> bool
var enabled := true
var spawned := 0  # total de efeitos criados (testes)
var show: MoveShow  # espetáculo procedural por cima do PMD (gfx/move_show.gd)
## Efeitos 3D dos golpes no modo de energia (gfx/fx3d): no lugar do PMD + MoveShow nos golpes.
var fx3d: MoveFx3D
var lights_on := true  ## luzes dos efeitos (testes podem desligar)


func _init(a: Node3D) -> void:
	arena = a
	show = MoveShow.new(self)
	fx3d = MoveFx3D.new(self)


## Os golpes usam os efeitos 3D (modo de energia, fora da bateria rápida)?
func use3d() -> bool:
	return fx3d != null and fx3d.on()


## Tremor curto da câmera (ArenaDebris.shake, h_offset).
func shake(amount: float, secs: float) -> void:
	if arena.is_inside_tree():
		ArenaDebris.shake(arena, amount, secs)


func cam() -> Camera3D:
	var c = arena.get("_cam")
	return c if c is Camera3D and c.is_inside_tree() else null


func _cam_pos(fallback: Vector3) -> Vector3:
	var c := cam()
	return c.global_position if c else fallback + Vector3(0, 4, 4)


func tick(dt: float) -> void:
	if fx3d:
		fx3d.tick(dt)
	for n in nodes.duplicate():
		if not is_instance_valid(n):
			nodes.erase(n)
			continue
		if not n.tick(dt):
			nodes.erase(n)
			if n is Node:
				n.queue_free()


func clear() -> void:
	for n in nodes:
		if is_instance_valid(n) and n is Node:
			n.queue_free()
	nodes.clear()
	if fx3d:
		fx3d.clear()


func _track(n: Object) -> Object:
	if n != null:
		nodes.append(n)
		spawned += 1
	return n


# --- Blocos ---


## Efeito PMD solto no mundo (global). Volta o FxSprite (ou null).
func pmd(fx_id: String, at: Vector3, aim: Vector3, role := {}) -> FxSprite:
	if not enabled or not arena.is_inside_tree():
		return null
	var c := cam()
	var f := PmdFx.make(fx_id, aim, role, c)
	if f == null:
		return null
	arena.add_child(f)
	f.global_position = at + PmdFx.toward_camera(at, c)
	PmdFx.orient(f, c)
	return _track(f)


## Efeito PMD preso a um nó (projétil, lutador). Em laço por padrão.
func attach(
	parent: Node3D, fx_id: String, aim: Vector3, role := {}, offset := Vector3.ZERO
) -> FxSprite:
	if not enabled or not is_instance_valid(parent) or not parent.is_inside_tree():
		return null
	var r := role.duplicate()
	if not r.has("loop"):
		r.loop = true
	var c := cam()
	var f := PmdFx.make(fx_id, aim, r, c)
	if f == null:
		return null
	parent.add_child(f)
	f.position = offset
	PmdFx.orient(f, c)
	return _track(f)


func _center(f: BattleFighter, k := 0.5) -> Vector3:
	return (
		f.to_global(Vector3(0, f.visual_height() * k, 0))
		if is_instance_valid(f) and f.is_inside_tree()
		else Vector3.ZERO
	)


# --- Golpes ---


## Ao soltar o golpe: papel "user" do move_fx.json.
func on_cast(user: BattleFighter, mv: Dictionary, dir: Vector3) -> void:
	if use3d():
		fx3d.cast(user, mv, dir)
		return
	var r := PmdFx.role(PmdFx.move_roles(String(mv.get("id", ""))), "user")
	if not r.is_empty():
		pmd(String(r.fx), _center(user), dir, r)
	show.ctx = [user]
	show.on_cast(user, mv, dir)


## Ao acertar: papel "hit" ou um impacto padrão (tingido pelo tipo nos especiais).
func on_hit(
	user: BattleFighter,
	target: BattleFighter,
	mv: Dictionary,
	dir: Vector3,
	crit := false,
	eff := 1.0
) -> void:
	if not is_instance_valid(target):
		return
	if use3d():
		fx3d.hit(user, target, mv, dir, crit, eff)
		return
	var roles := PmdFx.move_roles(String(mv.get("id", "")))
	var r := PmdFx.role(roles, "hit")
	var at := _center(target)
	if r.is_empty():
		r = {"fx": "hit_neutral"}
		if String(mv.get("category", "")) == "special":
			r.tint = Dex.type_color(String(mv.get("type", "normal"))).lightened(0.35)
			if String(mv.get("type", "")) == "electric":
				r = {"fx": "spark", "scale": 0.65}
	var sc := float(r.get("scale", 1.0))
	if crit or eff > 1.0:
		r = r.duplicate()
		r.scale = sc * 1.3
	pmd(String(r.fx), at, dir, r)
	if crit or eff > 1.0:
		pmd("hit_neutral", at, dir, {"scale": 1.6, "tint": Color(1, 0.9, 0.5)})
	show.ctx = [user, target]
	show.on_hit(user, target, mv, dir, crit, eff)


## Raio no eixo "aim" (hyper_beam, hydro_pump, solar_beam, psybeam...). Sem entrada: raio tingido pelo tipo.
func beam(user: BattleFighter, mv: Dictionary, dir: Vector3, length: float, dur: float) -> void:
	if not enabled or not is_instance_valid(user) or not arena.is_inside_tree():
		return
	if use3d():
		fx3d.beam(user, mv, dir, length, dur)
		return
	var id := BeamFx.beam_for(String(mv.get("id", "")))
	if id == "" or BeamFx.axis_of(id) != "aim":
		id = ""
	var at := _center(user, 0.5)
	var gdir := (arena.global_basis * dir).normalized()
	var b: BeamFx = null
	if id != "":
		b = BeamFx.make(id, at, gdir, length, dur, _cam_pos(at))
	else:
		b = BeamFx.make("beam", at, gdir, length, dur, _cam_pos(at))
		if b:
			var col := Dex.type_color(String(mv.get("type", "normal"))).lightened(0.25)
			for c in b.get_children():
				if c is Sprite3D and c.material_override is StandardMaterial3D:
					(c.material_override as StandardMaterial3D).albedo_color = Color(col, 0.0)
	if b:
		b.place_in(arena)
		_track(b)


## Raio do céu (thunder) no ponto. A arena chama isto quando qualquer golpe em área no alvo cai:
## além do raio (só quem tem "beam" de eixo "sky"), toca o "land" do look do golpe.
func sky_bolt(move_id: String, at: Vector3, dur := 0.6, notify := true) -> void:
	if not enabled or not arena.is_inside_tree() or use3d():
		return  # 3D: a área cai por area_land
	if notify:
		show.ctx = []
		show.landed(move_id, at)
	var id := BeamFx.beam_for(move_id)
	if id == "":
		return
	var b := BeamFx.make(id, at, Vector3.UP, BeamFx.SKY_H, dur, _cam_pos(at))
	if b:
		b.place_in(arena)
		_track(b)


## Jorro (stream): flamethrower = jato com shader; outros = partículas PMD que viajam pelo cone.
func stream(user: BattleFighter, mv: Dictionary, dir: Vector3, length: float, dur: float) -> void:
	if not enabled or not is_instance_valid(user) or not arena.is_inside_tree():
		return
	if use3d():
		fx3d.stream(user, mv, dir, length, dur)
		return
	var roles := PmdFx.move_roles(String(mv.get("id", "")))
	var s := PmdFx.role(roles, "stream")
	var col := Dex.type_color(String(mv.get("type", "normal")))
	if s.is_empty():
		s = {
			"fx": "hit_neutral",
			"every": 0.06,
			"travel": 0.4,
			"scale": 0.5,
			"spread": 0.4,
			"tint": col.lightened(0.3)
		}
	var em := StreamEmitter.new(self, user, s, dir, length, dur)
	if String(s.get("style", "")) == "jet":
		var at := _center(user, 0.45)
		var gdir := (arena.global_basis * dir).normalized()
		var jet := BeamFx.flame_jet(
			at, gdir, length, s, float(s.get("travel", 0.45)), dur, _cam_pos(at)
		)
		jet.place_in(arena)
		_track(jet)
		em.jet = jet
	_track(em)


## Ponta do chicote (vine_whip/aqua_tail): papel "tip" na ponta.
func tip(user: BattleFighter, mv: Dictionary, at_local: Vector3, dir: Vector3) -> void:
	if use3d():
		fx3d.tip(user, mv, at_local, dir)
		return
	var r := PmdFx.role(PmdFx.move_roles(String(mv.get("id", ""))), "tip")
	if r.is_empty() or not is_instance_valid(user) or not arena.is_inside_tree():
		return
	pmd(String(r.fx), arena.to_global(at_local + Vector3(0, user.visual_height() * 0.4, 0)), dir, r)


## Visual de projétil: papel "travel" (PMD em laço) ou uma orbe brilhante do tipo.
func projectile_look(p: Node3D, mv: Dictionary, dir: Vector3) -> void:
	if use3d():
		fx3d.projectile(p, mv, dir)
		return
	show.ctx = [p]
	show.projectile_trail(p, mv)
	var r := PmdFx.role(PmdFx.move_roles(String(mv.get("id", ""))), "travel")
	if not r.is_empty() and attach(p, String(r.fx), dir, r) != null:
		return
	if PmdFx.move_roles(String(mv.get("id", ""))).get("look", {}).get("orb", "") != "":
		return
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.12 if String(mv.get("category", "")) == "status" else 0.16
	sm.height = sm.radius * 2.0
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var col := Dex.type_color(String(mv.get("type", "normal"))).lightened(0.3)
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	sm.material = mat
	mi.mesh = sm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.add_child(mi)
	var halo := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = sm.radius * 1.9
	hm.height = hm.radius * 2.0
	var hmat := StandardMaterial3D.new()
	hmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	hmat.albedo_color = Color(col, 0.35)
	hm.material = hmat
	halo.mesh = hm
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.add_child(halo)


## Estágio subiu/caiu: anel/linhas coloridas do move_fx.json ("stats").
func stat_change(f: BattleFighter, key: String, up: bool) -> void:
	if use3d():
		fx3d.stat_change(f, key, up)
		return
	var st: Dictionary = PmdFx.data().get("stats", {}).get(key, {})
	var id := String(st.get("up" if up else "down", ""))
	if id != "" and is_instance_valid(f):
		pmd(id, _center(f, 0.45), Vector3.FORWARD, {"billboard": true})
	show.ctx = [f]
	show.stat_change(f, key, up)


## Efeito de status em laço preso ao lutador ("status" do move_fx.json).
func status_look(f: BattleFighter, status: String) -> FxSprite:
	var r := PmdFx.role(PmdFx.data().get("status", {}), status)
	if r.is_empty():
		return null
	r = r.duplicate()
	r.billboard = true
	var k := 1.05 if status in ["sleep", "confusion"] else 0.55
	return attach(f, String(r.fx), Vector3.FORWARD, r, Vector3(0, f.visual_height() * k, 0))


## O golpe começou a preparar (carga antes de soltar): só nos efeitos 3D.
func prepare(user: BattleFighter, mv: Dictionary, secs: float) -> void:
	if use3d():
		fx3d.prepare(user, mv, secs)


## Área no alvo começando (windup): o efeito se forma no lugar (3D) em vez do disco no chão.
func area_pre(
	user: BattleFighter, mv: Dictionary, at_local: Vector3, r: float, windup: float
) -> void:
	if use3d():
		fx3d.area_pre(user, mv, at_local, r, windup)


## Área caiu (no alvo ou em volta do usuário), `at_local` em coordenadas da arena.
func area_land(
	user: BattleFighter, mv: Dictionary, at_local: Vector3, r: float, around_user: bool
) -> void:
	if use3d():
		fx3d.area_land(user, mv, at_local, r, around_user)


## Zona que fica no chão (Fire Spin, Whirlpool...).
func zone_at(user: BattleFighter, mv: Dictionary, at_local: Vector3, r: float, dur: float) -> void:
	if use3d():
		fx3d.zone_at(user, mv, at_local, r, dur)


# --- Cavar (a mecânica chama via has_method) ---


## Rastro de terra que avança pelo chão de `from` até `to` (coordenadas locais da arena, como
## fighter.position) em `duration` s, com terra levantando.
func dig_trail(user: BattleFighter, from: Vector3, to: Vector3, duration: float) -> void:
	show.ctx = [user]
	show.dig_trail(user, from, to, duration)


## O lutador entrou no chão: buraco e terra espirrando.
func burrow(user: BattleFighter) -> void:
	show.ctx = [user]
	show.burrow(user)


## O lutador saiu do chão: estouro de terra, pedras e anel de poeira.
func unburrow(user: BattleFighter) -> void:
	show.ctx = [user]
	show.unburrow(user)


## Lutador arremessado bateu na cerca/caixa/pedra/parede (`at` local da arena): poeira e estrelinhas.
func crash(f: BattleFighter, at: Vector3, what: String) -> void:
	show.ctx = [f]
	show.crash(f, at, what)


## Arremesso forte (Whirlwind, Roar, Dragon Tail, contato 80+): rastro de vento enquanto voa.
func launch(f: BattleFighter, dir: Vector3, dist: float) -> void:
	show.ctx = [f]
	show.launch(f, dir, dist)


## Reapareceu de repente (Aerial Ace "blink"): flash e linhas onde surge.
func blink(f: BattleFighter) -> void:
	show.ctx = [f]
	show.blink(f)


# --- Campo, clima e escudos (a mecânica dos golpes chama via has_method) ---


func protect_shield(f: BattleFighter, secs: float) -> void:
	show.ctx = [f]
	show.protect_shield(f, secs)


## Follow Me / Rage Powder.
func spotlight(f: BattleFighter, secs: float) -> void:
	show.ctx = [f]
	show.spotlight(f, secs)


## light_screen, reflect, safeguard, quick_guard, tailwind sobre o lado `side`.
func screen(side: int, kind: String, secs: float) -> void:
	show.ctx = []
	show.screen(side, kind, secs)


## sun, rain, sand, hail.
func weather(kind: String, secs: float) -> void:
	show.ctx = []
	show.weather(kind, secs)


## "grassy".
func terrain(kind: String, secs: float) -> void:
	show.ctx = []
	show.terrain(kind, secs)


func gravity(secs: float) -> void:
	show.ctx = []
	show.gravity(secs)


func haze(user: BattleFighter) -> void:
	show.ctx = [user]
	show.haze(user)


## `at` local da arena.
func toxic_spikes(side: int, at: Vector3, r: float, life: float) -> void:
	show.ctx = []
	show.toxic_spikes(side, at, r, life)


func heal(f: BattleFighter) -> void:
	show.ctx = [f]
	show.heal(f)


## Fumaça ao entrar em campo / sair da bola.
func puff(at: Vector3, scale := 1.0) -> void:
	pmd("puff_white", at, Vector3.FORWARD, {"scale": scale, "billboard": true})


func sparkle(at: Vector3, scale := 1.0) -> void:
	pmd("captivate_sparkles", at, Vector3.FORWARD, {"scale": scale, "billboard": true})


## Emissor de um golpe "stream": solta partículas PMD que viajam pelo cone enquanto dura.
class StreamEmitter:
	extends RefCounted
	var vfx: BattleVfx
	var user: BattleFighter
	var role: Dictionary
	var dir := Vector3.FORWARD
	var length := 5.0
	var dur := 1.0
	var age := 0.0
	var acc := 0.0
	var n := 0
	var jet: BeamFx
	var _smoke := 0.0

	func _init(
		v: BattleVfx, u: BattleFighter, r: Dictionary, d: Vector3, l: float, du: float
	) -> void:
		vfx = v
		user = u
		role = r
		dir = d
		length = l
		dur = du

	func tick(dt: float) -> bool:
		age += dt
		if age >= dur or not is_instance_valid(user) or not user.active():
			if age < dur and is_instance_valid(jet):
				jet.life = minf(jet.life, jet.age + jet.fade)  # usuário caiu/saiu: o jato some junto
			return false
		if not vfx.arena.is_inside_tree():
			return true
		if is_instance_valid(user):
			dir = user.facing if user.facing.length() > 0.01 else dir
		var mouth: Vector3 = user.position + Vector3(0, user.visual_height() * 0.45, 0) + dir * 0.35
		if jet != null and is_instance_valid(jet) and vfx.arena.is_inside_tree():
			var at: Vector3 = vfx.arena.to_global(mouth)
			var gdir: Vector3 = (vfx.arena.global_basis * dir).normalized()
			var pos := at + gdir * length * 0.5
			jet.global_transform = Transform3D(
				BeamFx._basis(gdir, Vector3.AXIS_X, pos, vfx._cam_pos(at)), pos
			)
			var smoke := String(role.get("smoke", ""))
			if smoke != "":
				_smoke += dt
				if _smoke >= float(role.get("smoke_every", 0.08)):
					_smoke = 0.0
					var sp := vfx.pmd(
						smoke,
						at + gdir * length * randf_range(0.5, 1.0),
						gdir,
						{"scale": float(role.get("smoke_scale", 2.0)) * 0.5, "billboard": true}
					)
					if sp:
						sp.velocity = Vector3(0, float(role.get("smoke_rise", 2.0)) * 0.5, 0)
			return true
		var fx := String(role.get("fx", ""))
		if fx == "":
			return true
		acc += dt
		var every := maxf(float(role.get("every", 0.05)), 0.01)
		while acc >= every:
			acc -= every
			n += 1
			var travel := maxf(float(role.get("travel", 0.45)), 0.05)
			var spread := float(role.get("spread", 0.4))
			var d := dir.rotated(Vector3.UP, randf_range(-spread, spread) * 0.5)
			var at2: Vector3 = vfx.arena.to_global(mouth)
			var r := role.duplicate()
			r.erase("loop")
			r.life = travel
			var use_fx := fx
			var extra = role.get("extra")
			if extra is Dictionary and n % 3 == 0:
				use_fx = String(extra.get("fx", fx))
				r.scale = float(extra.get("scale", 1.0))
			var f := vfx.pmd(use_fx, at2, d, r)
			if f:
				f.loop = true
				f.velocity = (vfx.arena.global_basis * d).normalized() * (length / travel)
		return true

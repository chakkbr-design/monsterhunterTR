class_name BattleFighter
extends Node3D
## Lutador em tempo real: embrulha um Mon com HP, PP, cooldowns, estágios, status, pulo, dash e lunge.
## Toda a lógica roda em tick()/drive() chamados pela arena, então dá para simular sem tempo real.

signal fainted(f: BattleFighter)

const SPRINT_MULT := 1.6
const PLAYER_SPEED := 4.5
const AI_SPEED := 2.5 * 1.4
## Quem o jogador controla anda um pouco mais que a IA na mesma Speed.
const PLAYER_WALK_MULT := 1.15
## Voo (perfil Voador): altura de cruzeiro e mergulho para atacar.
const FLY_RISE := 2.2
const DIVE_H := 0.15
## Amizade Devotado: chance de aguentar um golpe fatal com 1 HP (uma vez por luta).
const ENDURE_FRIEND := 220
const ENDURE_CHANCE := 0.25
const JUMP_G := 23.8
const JUMP_HEIGHT_DEFAULT := 0.9
const JUMP_LAND := 0.3
const PREPARE_STUN := 0.25
const KNOCKBACK_SCALE := 0.5
const KNOCK_DECAY := 30.0
const HIT_RANGE := 1.2
const DASH_REACH_FACTOR := 0.9
## Investidas pesadas (poder DASH_TRACK_BP+) erravam metade (bateria de 2026-10-27): no primeiro
## terço da investida a direção vira até DASH_TRACK_DEG graus/s para o alvo (só quando o sorteio de
## acerto deu acerto).
const DASH_TRACK_BP := 90.0
const DASH_TRACK_DEG := 120.0
const ARC_STEP_M := 0.5
const ARC_STEP_TIME := 0.12
const LUNGE_SPEED := 10.0
const LUNGE_TIME := 0.2
const LUNGE_PREPARE := 0.15
const STRUGGLE_CD := 1.0
## Status como no oficial (Gen 9): queimadura e veneno não acabam sozinhos; o dano de
## queimadura/veneno/Toxic é de fim de turno (BattleEndTurn), uma vez por rodada.
## Sono: contador 2..4 que desce a cada tentativa de agir e acorda no zero (1 a 3 turnos dormindo, como
## o Showdown); Rest dorme 1 turno (contador 2; era 2 turnos, bateria de 2026-10-27).
const SLEEP_COUNTER := [2, 4]
const REST_COUNTER := 2
## Confusão: contador 2..5 que desce a cada tentativa de agir; no zero sai da confusão e age.
const CONFUSION_COUNTER := [2, 5]
## Congelado: 20% de descongelar a cada tentativa de agir (golpe de Fogo recebido também descongela).
const THAW_CHANCE := 0.2
## Toxic: n/16 no n-ésimo fim de turno (n até 15; zera ao sair de campo).
const TOXIC_MAX := 15
const FLINCH_TIME := 0.5
## Paralisia acaba sozinha depois de PARALYSIS_SECS s de luta em campo (pedido do Caio; no oficial é
## permanente). O que sobra fica no Mon (par_left) para a troca e a próxima luta.
const PARALYSIS_SECS := 10.0
## Clarão do efeito de fim de turno (popup + tinta curta no sprite).
const RESIDUAL_FLASH := 0.25
const STAGE_KEYS := ["atk", "def", "spa", "spd", "spe", "acc"]
const STRUGGLE := {
	"id": "struggle",
	"name": "Struggle",
	"type": "none",
	"category": "physical",
	"kind": "lunge",
	"power": 50,
	"knockback": 5
}
const STATUS_SHORT := {
	"burn": "BRN",
	"poison": "PSN",
	"toxic": "TOX",
	"paralysis": "PAR",
	"sleep": "SLP",
	"leech": "SEED",
	"freeze": "FRZ"
}

var arena: Node
var mon: Mon
var side := 0
var controller := "ai"
var ai: BattleAI
var opponent: BattleFighter
var last_hit_by: BattleFighter
var on_field := true
var trainer_item := ""
var item_used := false
## Boneco do acampamento de treino (creature.gd immortal do original): no KO o HP volta cheio.
var immortal := false
## Batalha Viva: perfil de movimento (BattleProfile), comando atual, voo e estado de ânimo.
var profile := "brawler"
var prof := {}
var command := 3  # BattleAI.FREE
var fly_h := 0.0
var fly_target := 0.0
## Altura do chão sob o lutador (BattleTerrain: morro, pico); 0 = chão da quadra.
var ground_y := 0.0
var endured := false
## Fração de dano que sobrou no ritmo baixo (damage_pace < 1), somada no próximo golpe.
var dmg_carry := 0.0
var mood_state := ""  # "" | "fury" | "panic"

var moves: Array = []
var types: Array = []
var level := 1
var stats := {}
var stages := {}
var crit_stage := 0
## Vida em dobro na batalha (Caio, 2026-10-27): o lutador tem HP_MULT vezes o HP do Mon (treino e
## campanha). O Mon guarda a mesma fração (hp_to_mon / hp_from_mon); itens e a party continuam no HP
## normal do Mon.
const HP_MULT := 2
var hp := 1
var max_hp := 1
var pp_base := 100.0
var pp_max := 100.0
## pp_base/pp_max são a barra de energia (BattleEnergy), que enche com o tempo.

var move_cd := {}
var gcd_t := 0.0
var root_t := 0.0
var stun_t := 0.0
var trap_t := 0.0
var land_t := 0.0
var impact_t := 0.0
var evasion_t := 0.0
var evasion := 0.0
## Confuso enquanto > 0 (marca; a duração é confusion_turns, contada em turnos).
var confusion_t := 0.0
var confusion_turns := 0
var status := ""
## Sono: tentativas de agir até acordar (SLEEP_COUNTER).
var sleep_turns := 0
## Segundos de paralisia que faltam (PARALYSIS_SECS).
var par_t := 0.0
## Modo de energia: segundos que o status grave ainda dura (BattleEnergy.STATUS_SECS) e imunidade
## curta ao mesmo status depois que ele passa.
var status_t := 0.0
var status_immune_t := 0.0
var last_status := ""
## Entrada protegida (BattleEnergy.ENTRY_GUARD): segundos que ainda faltam.
var entry_t := 0.0
## Fôlego (passiva do pulo de desespero): segundos com a energia enchendo mais rápido.
var breath_t := 0.0
## Modo de energia: recargas do salto de obstáculo e do voo (BattleClimb).
var jump_cd := 0.0
var fly_cd := 0.0
## Rodada (BattleTurns.round_n) em que o status / a confusão começou.
var status_round := -1
var confusion_round := -1
## Snore/Sleep Talk: age dormindo só enquanto o golpe sai (BattleMoves.use).
var sleep_act_t := 0.0
## Leech Seed (volátil, como o oficial: convive com outro status e só sai na troca ou com Rapid Spin).
var seeded := false
var leech_source: BattleFighter
var toxic_n := 0

var prepare_t := 0.0
var prepare_id := ""
var prepare_cb := Callable()

var air_t := 0.0
var air_h := 0.0
var jump_height := JUMP_HEIGHT_DEFAULT
var jump_time := 0.0

var dash_t := 0.0
var dash_dir := Vector3.ZERO
var dash_speed := 12.0
var dash_move := {}
var dash_miss: BattleFighter
var dash_hit := false
var dash_dodged := {}
var dash_track_t := 0.0

var lunge_t := 0.0
var lunge_dir := Vector3.ZERO
var lunge_done := false
var struggle_cd := 0.0

var arc_step_t := 0.0
var arc_step_dir := Vector3.ZERO
var knock := Vector3.ZERO
var impact_knock := Vector3.ZERO
var velocity := Vector3.ZERO
var facing := Vector3.FORWARD
var sprinting := false

var cast_move := {}
var cast_n := 0

## Física (BattlePhysics): movimento roteirizado do golpe (salto, sumiço, túnel) e arremesso.
## motion: "" | "leap" | "blink" | "burrow" | "tunnel". hidden: "" | "dig" | "dive" | "sky" | "blink"
## (escondido: só os golpes de BattlePhysics.REACHES_HIDDEN acertam).
var motion := ""
var motion_t := 0.0
var motion_total := 0.0
var motion_from := Vector3.ZERO
var motion_to := Vector3.ZERO
var motion_off := Vector3.ZERO
var motion_h := 0.0  ## altura do salto; no túnel, a velocidade (m/s)
var motion_y0 := 0.0
var motion_track := 0.0
var motion_target: BattleFighter
var motion_cb := Callable()
var motion_tick := Callable()
## Visual do pulo de desespero (BattlePassives): "" | "desperate"; squash_t = achatar ao pousar (s).
var leap_style := ""
var squash_t := 0.0
var hidden := ""
var launch_v := Vector3.ZERO
var launch_t := 0.0
var launch_total := 0.0
var launch_lift := 0.0
var look_h := 1.0
## Espécie do corpo em luta quando ela difere da do Mon (Transform); "" = a do Mon.
var body := ""

var look: CreatureSprite  # arte do original (gfx/creature_sprite.gd)
## Evoluindo no meio da luta (creature.gd evolving): a tela Evolution pinta o sprite, a luta fica parada.
var evolving := false
var vfx: BattleVfx
var _status_fx: Node3D  # FxSprite (PMD) ou Fx3DStatus (modo de energia)
var _status_fx_id := ""
var _status_fx_off := Vector3.ZERO
var _flash_t := 0.0
var _flash_col := Color(2.2, 2.2, 2.2)
var _ring: MeshInstance3D
var _hp_bar: BattleHpBar
var _spawn_t := 0.0

const SPAWN_GROW := 0.25  ## game.gd send_out: escala 0.05 -> 1.15 em 0.15 s, -> 1.0 em 0.1 s
const FLASH_COL := Color(2.2, 2.2, 2.2)


func setup(m: Mon, s: int, ctrl: String) -> void:
	mon = m
	side = s
	controller = ctrl
	var sp := Dex.species(m.species)
	types = m.types
	level = m.level
	moves = m.moves.slice(0, 4)
	for k in StatCalc.STATS:
		stats[k] = m.stat(k)
	for k in STAGE_KEYS:
		stages[k] = 0
	max_hp = hp_from_mon(m.max_hp)
	hp = clampi(hp_from_mon(m.hp), 0, max_hp)
	pp_base = BattleEnergy.MAX
	pp_max = BattleEnergy.MAX * BattleEnergy.START
	jump_height = float(sp.get("jump_height_override", sp.get("jump_height", JUMP_HEIGHT_DEFAULT)))
	jump_time = sqrt(8.0 * jump_height / JUMP_G) if jump_height > 0.0 else 0.0
	look_h = clampf(float(sp.get("height_m", 1.0)) * 0.9, 0.45, 1.8)
	# Status volta da troca como no oficial: Toxic (contador zerado), congelado e o sono que faltava.
	var st := m.status
	if m.battle_status == "toxic" and st == "poison":
		st = "toxic"
	elif m.battle_status == "freeze" and st == "":
		st = "freeze"
	if st in Mon.PERSIST_STATUS + ["toxic", "freeze"]:
		apply_status(st)
		if st == "sleep" and m.sleep_left > 0:
			sleep_turns = m.sleep_left
	_set_profile()
	ai = BattleAI.new(self)
	_build_visual()


func _set_profile() -> void:
	var bias := ""
	var ab = arena.get("abilities") if arena else null
	if ab and ab.has_method("profile_bias"):
		bias = String(ab.profile_bias(self))
	profile = BattleProfile.pick(mon, moves, bias)
	prof = BattleProfile.params(profile)
	fly_target = float(prof.get("fly", 0.0))
	fly_h = fly_target


func _build_visual() -> void:
	look = CreatureSprite.new()
	look.name = "Look"
	look.manual = true
	look.auto_motion = false
	look.auto_face = false
	look.species = mon.species
	add_child(look)
	look.facing = facing
	# Como o original (creature.tscn): só o Sprite3D, que projeta sombra de verdade; sem disco nem anel.
	# Na dupla vai um anel no chão (amarelo = seu lado, vermelho = adversário) para ler quem é quem.
	if arena and bool(arena.get("doubles")):
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.42
		tm.outer_radius = 0.5
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(1, 0.85, 0.3, 0.7) if side == 0 else Color(1, 0.35, 0.3, 0.7)
		tm.material = mat
		ring.mesh = tm
		ring.scale = Vector3(1, 0.05, 1)
		ring.position.y = 0.03
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.name = "SideRing"
		add_child(ring)
		_ring = ring
	_hp_bar = BattleHpBar.new(self)
	add_child(_hp_bar)
	_hp_bar.visible = not (arena and bool(arena.get("clean_hud")))  # No HUD: nem no 1º quadro
	_spawn_t = SPAWN_GROW
	refresh_label()


## Aparece saindo da bola (cresce de 0,05 a 1,15 e volta a 1,0).
func flash_spawn() -> void:
	_spawn_t = SPAWN_GROW


## Escala de tempo da luta (a mesma do dt que a arena passa), para o ritmo do sprite.
func _fight_speed() -> float:
	if arena == null or not ("fight_speed" in arena):
		return 1.0
	var k := float(arena.fight_speed)
	if "menu" in arena and String(arena.menu) != "":
		k *= 0.2  # MODAL_SLOW da arena (battle.gd:159)
	return k


## Altura visível da arte (m). Só visual: a jogabilidade continua usando look_h.
func visual_height() -> float:
	return look.visible_height() if look else look_h


## O HUD desenha nome/HP/status; o lutador não tem mais rótulo 3D.
func refresh_label() -> void:
	pass


## Visual por frame (chamado pela arena em qualquer estado, dt já escalado; hit-stop congela a pose).
func visual_step(dt: float) -> void:
	if look == null:
		return
	var vdt := 0.0 if impact_t > 0.0 else dt
	if _spawn_t > 0.0:
		_spawn_t = maxf(_spawn_t - dt, 0.0)
		var t := SPAWN_GROW - _spawn_t
		look.scale_mult = (
			lerpf(0.05, 1.15, t / 0.15) if t < 0.15 else lerpf(1.15, 1.0, (t - 0.15) / 0.1)
		)
	# Em m/s de tempo real, como o body.velocity do original (já vezes a velocidade da luta): o Walk
	# anda a |v| / 2.5 com o delta também escalado (creature.gd _pmd_rate / combatant drive_velocity).
	look.velocity = velocity * _fight_speed()
	if facing.length() > 0.01:
		look.facing = facing
	var st := ""
	if alive():
		if status == "sleep":
			st = "sleep"
		elif prepare_t > 0.0:
			st = "prepare"
		elif air_t > 0.0:
			st = "airborne"
	look.state = st
	look.squash = _leap_squash(vdt)
	look.tick(vdt)
	if _ring:
		_ring.visible = alive() and on_field
		_ring.position.y = 0.03 + ground_y - position.y  # fica no chão mesmo pulando ou voando
	if _hp_bar:
		_hp_bar.step(dt, hp, max_hp, visual_height(), on_field and not evolving)
	var tint := _tint()
	if _flash_t > 0.0:
		_flash_t -= dt
		tint = _flash_col
	if alive() and not evolving:
		look.tint = tint
	_update_status_fx()
	_place_status_fx()


## Achatar/esticar do pulo de desespero e do salto de obstáculo (BattleClimb): agacha na decolagem
## (primeiros 20% do arco), estica no ar e achata de novo ao pousar (squash_t). Só visual, lê o
## movimento sem mexer nele.
func _leap_squash(dt: float) -> Vector3:
	squash_t = maxf(squash_t - dt, 0.0)
	if motion == "leap" and leap_style in ["desperate", "climb"]:
		var s := clampf(1.0 - motion_t / maxf(motion_total, 0.001), 0.0, 1.0)
		if s < 0.2:
			var k := sin(s / 0.2 * PI)
			return Vector3(1.0 + 0.28 * k, 1.0 - 0.38 * k, 1.0)
		var air := sin(s * PI)
		return Vector3(1.0 - 0.12 * air, 1.0 + 0.2 * air, 1.0)
	if motion != "leap" and leap_style != "":
		leap_style = ""
	if squash_t > 0.0:
		var k2 := squash_t / 0.16
		return Vector3(1.0 + 0.3 * k2, 1.0 - 0.35 * k2, 1.0)
	return Vector3.ONE


func _update_status_fx() -> void:
	var want := status if alive() and on_field else ""
	if want == "" and confusion_t > 0.0 and alive():
		want = "confusion"
	if want == "" and seeded and alive() and on_field:
		want = "leech"
	if want == _status_fx_id:
		return
	if is_instance_valid(_status_fx):
		_status_fx.set("life", maxf(float(_status_fx.get("age")), 0.001))
	_status_fx = null
	_status_fx_id = want
	if want != "" and vfx:
		_status_fx = vfx.status_look(self, want)
		if _status_fx:
			_status_fx_off = _status_fx.position


## Efeito de status puxado para a câmera (como o FX_TOWARD_CAM_M do original): preso no centro do lutador,
## o quad cortava o sprite ao meio no teste de profundidade.
func _place_status_fx() -> void:
	if not is_instance_valid(_status_fx) or not is_inside_tree() or _status_fx is Fx3DStatus:
		return
	var at := to_global(_status_fx_off)
	_status_fx.global_position = at + PmdFx.toward_camera(at, vfx.cam())


## HP do Mon -> HP do lutador (HP_MULT).
static func hp_from_mon(n: int) -> int:
	return n * HP_MULT


## HP do lutador -> HP do Mon, para cima (vivo no lutador continua vivo no Mon).
static func hp_to_mon(n: int) -> int:
	return ceili(float(n) / HP_MULT)


func alive() -> bool:
	return hp > 0


## Espécie do corpo (peso, golpes que olham o peso): a do Mon, ou a copiada pelo Transform.
func body_id() -> String:
	return body if body != "" else mon.species


func active() -> bool:
	return on_field and alive()


func head_pos(extra := 0.0) -> Vector3:
	return position + Vector3(0, look_h + extra, 0)


func pos2(p: Vector3) -> Vector3:
	return Vector3(p.x, 0.0, p.z)


func flat_to(t: Node3D) -> Vector3:
	var d := t.position - position
	d.y = 0.0
	return d


# --- Stats ---


func stat(k: String) -> float:
	var v := float(stats.get(k, 10)) * StatCalc.stage_mult(int(stages.get(k, 0)))
	if k == "spe" and arena and arena.get("moves"):
		v *= arena.moves.effects.speed_mult(self)  # Tailwind
	return v


func crit_stat(k: String, attacking: bool) -> float:
	var st := int(stages.get(k, 0))
	st = maxi(st, 0) if attacking else mini(st, 0)
	return float(stats.get(k, 10)) * StatCalc.stage_mult(st)


## Dicionário no formato de Damage.compute (stats com estágios, burn à parte).
func damage_profile() -> Dictionary:
	var d := {
		"level": level,
		"types": types,
		"crit_stage": crit_stage,
		"burned": status == "burn",
		"terrain_mult": 1.0
	}
	for k in ["atk", "def", "spa", "spd"]:
		d[k] = stat(k)
	d["crit_atk"] = crit_stat("atk", true)
	d["crit_spa"] = crit_stat("spa", true)
	d["crit_def"] = crit_stat("def", false)
	d["crit_spd"] = crit_stat("spd", false)
	var ab = arena.get("abilities") if arena else null
	d["guts"] = ab != null and ab.ability_of(self) == "guts"  # Guts ignora a queimadura (oficial)
	return d


## Speed efetiva para o ritmo: paralisia corta pela metade (Gen 3 corta para 1/4 no turno).
func eff_spe() -> float:
	return stat("spe") * (0.5 if status == "paralysis" else 1.0)


func speed_factor() -> float:
	if is_instance_valid(opponent) and opponent.active():
		return StatCalc.battle_speed_factor(eff_spe(), opponent.eff_spe())
	return 1.0


## Velocidade de andar absoluta (m/s) pela Speed, chão e habilidade (paralisia é aplicada em drive).
func walk_speed() -> float:
	var v := StatCalc.walk_speed(stat("spe")) * BattleEnergy.WALK_PACE
	if controller == "player":
		v *= PLAYER_WALK_MULT
	if arena:
		if arena.get("field"):
			v *= arena.field.move_mult(self)
		if arena.get("terrain"):
			v *= arena.terrain.move_mult(self)
			v *= arena.terrain.props.move_mult(self)  # tronco caído (BattleProps)
		var ab = arena.get("abilities")
		if ab and ab.has_method("walk_mult"):
			v *= ab.walk_mult(self)
	return v


## Altura do corpo acima do chão (pulo + voo; no salto de golpe, a do salto).
func height() -> float:
	if motion == "leap":
		return maxf(position.y, air_h + fly_h)
	return air_h + fly_h


func can_act() -> bool:
	return (
		alive()
		and stun_t <= 0.0
		and impact_t <= 0.0
		and (status != "sleep" or sleep_act_t > 0.0)
		and status != "freeze"
	)


func is_airborne() -> bool:
	return air_t > 0.0 or motion == "leap"


func may_start(mv: Dictionary) -> bool:
	if motion != "" or launch_t > 0.0:
		return false
	return not is_airborne() or bool(mv.get("allowed_midair", true))


## Energia gasta pelo golpe (BattleEnergy.cost).
func pp_cost_of(mv: Dictionary) -> float:
	var c := BattleEnergy.cost(mv)
	var ab = arena.get("abilities") if arena else null
	if ab and ab.has_method("cost_mult"):
		c *= ab.cost_mult(self)  # Pressure: inimigo perto faz o golpe custar mais
	return roundf(c)


func dash_reach() -> float:
	return look_h * DASH_REACH_FACTOR


## Dash/lunge passa por baixo de um alvo alto o bastante no ar (pulo ou voo).
func passes_under(t: BattleFighter) -> bool:
	return t.height() - height() >= dash_reach()


func aim_dir() -> Vector3:
	if is_instance_valid(opponent) and opponent.active():
		var d := flat_to(opponent)
		if d.length() > 0.01:
			return d.normalized()
	return facing


# --- Recursos ---


func spend(cost: float) -> void:
	pp_max -= cost


func can_jump() -> bool:
	return (
		jump_height > 0.0
		and root_t <= 0.0
		and can_act()
		and trap_t <= 0.0
		and air_t <= 0.0
		and land_t <= 0.0
		and dash_t <= 0.0
		and lunge_t <= 0.0
		and motion == ""
		and launch_t <= 0.0
		and not (arena and arena.get("moves") and arena.moves.effects.no_jump())
	)  # Gravity


func start_jump() -> bool:
	if not can_jump():
		return false
	air_t = jump_time
	air_h = 0.0
	return true


func can_sprint(moving: bool) -> bool:
	return moving and can_act() and root_t <= 0.0 and trap_t <= 0.0


# --- Preparação (windup enraizado antes de soltar o golpe) ---


func begin_prepare(id: String, secs: float, cb: Callable) -> void:
	prepare_id = id
	prepare_t = secs
	prepare_cb = cb
	root_t = maxf(root_t, secs)


func clear_prepare() -> void:
	prepare_t = 0.0
	prepare_id = ""
	prepare_cb = Callable()


func interrupt_prepare() -> void:
	if not prepare_cb.is_valid():
		return
	var id := prepare_id
	clear_prepare()
	root_t = 0.0
	stun_t = maxf(stun_t, PREPARE_STUN)
	if id != "":
		move_cd[id] = minf(float(move_cd.get(id, 0.0)), gcd_t)
	popup("Interrupted!", Color(0.9, 0.9, 0.9), 0.8)


func start_dash(mv: Dictionary, dir: Vector3, miss: BattleFighter) -> void:
	dash_move = mv
	dash_miss = miss
	dash_dir = dir
	dash_speed = float(mv.get("speed", 12.0))
	dash_t = float(mv.get("range", 3.0)) / dash_speed
	dash_track_t = (
		dash_t / 3.0 if float(mv.get("power", 0)) >= DASH_TRACK_BP and miss == null else 0.0
	)
	dash_hit = false
	dash_dodged.clear()
	facing = dir


## Vira a investida para o alvo, no máximo DASH_TRACK_DEG graus/s.
func _track_dash(dt: float) -> void:
	if not is_instance_valid(opponent) or not opponent.active():
		return
	var to := flat_to(opponent)
	if to.length() < 0.3:
		return
	var a := dash_dir.signed_angle_to(to.normalized(), Vector3.UP)
	var lim := deg_to_rad(DASH_TRACK_DEG) * dt
	dash_dir = dash_dir.rotated(Vector3.UP, clampf(a, -lim, lim)).normalized()
	facing = dash_dir


func start_arc_step(dir: Vector3) -> void:
	if air_t > 0.0 or dash_t > 0.0 or lunge_t > 0.0:
		return
	if is_instance_valid(opponent) and flat_to(opponent).length() <= HIT_RANGE:
		return
	arc_step_dir = dir
	arc_step_t = ARC_STEP_TIME


## Sem PP: lunge com recuo de max_hp/4.
func struggle() -> bool:
	if (
		struggle_cd > 0.0
		or lunge_t > 0.0
		or gcd_t > 0.0
		or root_t > 0.0
		or not can_act()
		or not may_start(STRUGGLE)
	):
		return false
	struggle_cd = STRUGGLE_CD
	gcd_t = Dex.GLOBAL_COOLDOWN / speed_factor()
	var dir := aim_dir()
	popup("Struggle", Color(0.9, 0.9, 0.9), 1.0, 0.9)
	begin_prepare(
		"",
		LUNGE_PREPARE,
		func() -> void:
			lunge_dir = dir
			lunge_t = LUNGE_TIME
			lunge_done = false
	)
	return true


# --- Status ---


func apply_status(s: String, source: BattleFighter = null) -> bool:
	if not alive():
		return false
	if s == "flinch":
		stun_t = maxf(stun_t, FLINCH_TIME)
		return true
	if s == "confusion":
		if confusion_t > 0.0:
			return false
		confusion_t = 1.0
		confusion_turns = _roll(CONFUSION_COUNTER)
		confusion_round = round_now()
		_held_check()
		return true
	if s == "leech":
		# Leech Seed é volátil no oficial: não ocupa o lugar do status.
		if seeded:
			return false
		seeded = true
		leech_source = source
		refresh_label()
		return true
	if status != "":
		return false
	status = s
	status_round = round_now()
	if s == "sleep":
		sleep_turns = _roll(SLEEP_COUNTER)
	elif s == "paralysis":
		par_t = mon.par_left if mon.par_left > 0.0 else PARALYSIS_SECS
	status_t = float(BattleEnergy.STATUS_SECS.get(s, 0.0))
	if s == "paralysis":
		par_t = minf(par_t, status_t)
	if s in Mon.PERSIST_STATUS:
		mon.status = s
	elif s == "toxic":
		toxic_n = 0
		mon.status = "poison"  # fora da luta o Toxic vira veneno comum (Gen 5+)
	refresh_label()
	_tele("status", {"st": s, "by": _tele_id(source)})
	_held_check()
	var ab = arena.get("abilities") if arena else null
	if ab and ab.has_method("on_status"):
		ab.on_status(self, s, source)  # Synchronize
	return true


func _tele(kind: String, data: Dictionary) -> void:
	var tel = arena.get("telemetry") if arena else null
	if tel:
		data["who"] = tel.uid(self)
		tel.note(kind, data)


func _tele_id(f) -> String:
	var tel = arena.get("telemetry") if arena else null
	return tel.uid(f) if tel and is_instance_valid(f) else ""


func clear_status() -> void:
	if status != "":
		_tele("cure", {"st": status})
		last_status = status
		status_immune_t = BattleEnergy.STATUS_IMMUNE
	status_t = 0.0
	status = ""
	sleep_turns = 0
	toxic_n = 0
	par_t = 0.0
	mon.cure()
	refresh_label()


## Tira a Leech Seed (Rapid Spin; a troca já começa sem ela).
func clear_seed() -> void:
	seeded = false
	leech_source = null


func _roll(r: Array) -> int:
	var lo := int(r[0])
	var hi := int(r[1])
	if arena and arena.get("rng"):
		return arena.rng.randi_range(lo, hi)
	return randi_range(lo, hi)


## Rodada atual da luta (BattleTurns.round_n; -1 sem arena).
func round_now() -> int:
	var t = arena.get("turns") if arena else null
	return int(t.round_n) if t else -1


## Tentativa de agir (oficial: antes do golpe). Sono: o contador desce e acorda no zero (e age nesta
## vez). Congelado: 20% de descongelar. Confusão: o contador desce e sai dela no zero.
func try_act() -> void:
	if not alive():
		return
	if status == "sleep":
		sleep_turns -= 1
		if sleep_turns <= 0:
			clear_status()
			popup("Woke up!", Color(0.85, 0.9, 1.0), 0.9)
	elif status == "freeze" and _chance(THAW_CHANCE):
		clear_status()
		popup("Thawed out!", Color(0.7, 0.95, 1.0), 0.9)
	if confusion_t > 0.0:
		confusion_turns -= 1
		if confusion_turns <= 0:
			confusion_t = 0.0
			popup("Snapped out of confusion!", Color(0.9, 0.8, 1.0), 0.9)


## Fim da rodada: a rodada inteira vale como a tentativa de agir (menos a
## rodada em que o status começou). Acorda / sai da confusão quando a próxima tentativa já seria livre.
func round_count() -> void:
	if not alive():
		return
	var r := round_now()
	if status == "sleep" and r != status_round:
		sleep_turns -= 1
		if sleep_turns <= 1:
			clear_status()
			popup("Woke up!", Color(0.85, 0.9, 1.0), 0.9)
	elif status == "freeze" and r != status_round and _chance(THAW_CHANCE):
		clear_status()
		popup("Thawed out!", Color(0.7, 0.95, 1.0), 0.9)
	if confusion_t > 0.0 and r != confusion_round:
		confusion_turns -= 1
		if confusion_turns <= 1:
			confusion_t = 0.0
			popup("Snapped out of confusion!", Color(0.9, 0.8, 1.0), 0.9)


func _chance(p: float) -> bool:
	if arena and arena.get("rng"):
		return arena.rng.randf() < p
	return randf() < p


## Ritmo da luta para o dano físico de tempo real (batida no arremesso, chão queimado): o próprio
## ritmo do dano (0,6), como todo dano indireto (paced).
func dot_scale() -> float:
	if arena == null or not arena.get("moves"):
		return 1.0
	return clampf(float(arena.damage_pace), 0.0, 1.0)


## Caio, 2026-10-25: todo dano indireto (veneno, queimadura, semente, clima...) e toda
## cura em fração do HP (Recover, Leftovers, frutinha, poção...) seguem o mesmo fator do dano dos golpes
## (arena.damage_pace, 0,6), para a luta continuar proporcional. Cura cheia (Rest, Healing Wish) fica cheia;
## dreno e recuo já saem do dano feito.
func paced(n: int) -> int:
	if arena == null or n <= 0 or n >= max_hp:
		return n
	return maxi(1, int(round(float(n) * float(arena.damage_pace))))


## Dano de fim de turno (veneno, queimadura, semente, clima...): popup "-12 veneno" e clarão curto na
## cor do efeito. Magic Guard segura (devolve 0). Devolve o dano tirado.
func residual_damage(amount: int, why: String, col: Color) -> int:
	if not alive() or amount <= 0:
		return 0
	var ab = arena.get("abilities") if arena else null
	if ab and ab.has_method("no_indirect") and ab.no_indirect(self):
		return 0
	amount = mini(amount, hp)
	_tele(
		"residual",
		{"why": why, "dmg": amount, "frac": snappedf(float(amount) / maxf(max_hp, 1), 0.001)}
	)
	popup("-%d %s" % [amount, why], col, 0.85, 0.3)
	take_damage(amount, Vector3.ZERO, 0.0)
	flash(col.lerp(Color.WHITE, 0.3) * 1.6, RESIDUAL_FLASH)
	return amount


## Cura de fim de turno (Leftovers, Aqua Ring, Grassy...): popup "+5 Leftovers" e clarão verde.
## Devolve quanto curou (0 com HP cheio ou Heal Block).
func residual_heal(amount: int, why: String) -> int:
	if not alive() or amount <= 0 or hp >= max_hp:
		return 0
	var before := hp
	heal(amount)
	var got := hp - before
	if got > 0:
		popup("+%d %s" % [got, why], Color(0.5, 1.0, 0.55), 0.85, 0.3, "heal")
		flash(Color(1.0, 2.0, 1.1), RESIDUAL_FLASH)
	return got


## Clarão de cor no sprite por `secs` s.
func flash(col: Color, secs: float) -> void:
	_flash_col = col
	_flash_t = maxf(_flash_t, secs)


## Item segurado que age sozinho (frutinha no limite de HP ou contra status): BattleEndTurn.held_check.
func _held_check() -> void:
	var et = arena.get("end_turn") if arena else null
	if et and et.has_method("held_check"):
		et.held_check(self)


func heal(n: int) -> void:
	if not alive():
		return
	if arena and arena.get("moves") and arena.moves.effects.heal_blocked(self):
		return  # Psychic Noise
	hp = mini(hp + n, max_hp)
	mon.hp = hp_to_mon(hp)
	refresh_label()


# --- Dano ---


static func impact_secs(hp_pct: float, crit: bool, eff: float, ko: bool, final_hit: bool) -> float:
	if not final_hit:
		return 0.05
	if ko:
		return 0.3
	if crit or eff > 1.0:
		return 0.22
	if hp_pct < 0.05:
		return 0.0
	return lerpf(0.08, 0.15, clampf((hp_pct - 0.05) / 0.45, 0.0, 1.0))


## Aplica dano; devolve o hit-stop aplicado. dir zero = DoT/recuo (sem hit-stop nem interrupção).
func take_damage(amount: int, dir: Vector3, knockback := 4.0, opts := {}) -> float:
	if not alive():
		return 0.0
	var has_dir := (amount > 0 or opts.has("source")) and dir.length_squared() > 0.0
	if has_dir:
		interrupt_prepare()
	var hp_before := hp
	var imp := 0.0
	var src: BattleFighter = opts.get("source")
	if amount >= hp and has_dir and _endure():
		amount = hp - 1
	if has_dir and is_instance_valid(src):
		imp = impact_secs(
			float(amount) / float(maxi(max_hp, 1)),
			bool(opts.get("crit", false)),
			float(opts.get("eff", 1.0)),
			amount >= hp_before,
			bool(opts.get("final", true))
		)
		if imp > 0.0:
			impact_t = maxf(impact_t, imp)
			src.impact_t = maxf(src.impact_t, imp)
	hp = maxi(hp - amount, 0)
	mon.hp = hp_to_mon(hp)
	var k := dir * knockback * KNOCKBACK_SCALE
	if impact_t > 0.0:
		impact_knock += k
	else:
		knock = k
	# Golpe não acorda quem dorme (oficial): o sono só acaba pelo contador (try_act).
	if amount > 0:
		_flash_col = FLASH_COL
		_flash_t = maxf(imp, 0.12)
		if has_dir and look and hp > 0:
			look.hurt()
	refresh_label()
	if hp == 0:
		if immortal:
			hp = max_hp
			mon.hp = hp_to_mon(hp)
			popup("KO! (recharged)", Color(1, 0.4, 0.4))
			refresh_label()
			return imp
		_faint()
	elif amount > 0:
		_held_check()
	return imp


## Amizade alta: aguenta o golpe fatal com 1 HP (uma vez por luta), como o carinho do Gen 6.
func _endure() -> bool:
	if endured or immortal or hp <= 1 or side != 0 or arena == null:
		return false
	if int(mon.get("friend") if mon.get("friend") != null else 0) < ENDURE_FRIEND:
		return false
	if arena.rng.randf() >= ENDURE_CHANCE:
		return false
	endured = true
	popup("Hung on for you!", Color(1, 0.75, 0.85), 1.1, 0.9, "special")
	if arena.has_method("cut_in"):
		arena.cut_in("HUNG ON!", Color(1, 0.6, 0.75))
	return true


func _faint() -> void:
	end_motion()
	launch_t = 0.0
	air_t = 0.0  # desmaio no ar (pulo, voo): cai no chão em vez de ficar parado na altura
	air_h = 0.0
	fly_h = 0.0
	position.y = ground_y
	clear_prepare()
	dash_t = 0.0
	lunge_t = 0.0
	root_t = 0.0
	sprinting = false
	popup("%s fainted!" % mon.display_name, Color(1, 0.4, 0.4), 0.7, 1.2)
	if arena and arena.get("moves"):
		arena.moves.effects.note_faint(self)  # Retaliate
	preload("res://audio/cue.gd").sfx("faint")
	if look:
		look.tint = _tint()  # sem isso o clarão de um acerto anterior fica preso no sprite desmaiado
		look.faint()
	fainted.emit(self)


## style: "" = adivinhado pelo texto (damage, crit, super, weak, miss, dodge, stat_up, stat_down, status, heal, move, callout, info).
func popup(text: String, col: Color, scale_k := 1.0, extra := 0.15, style := "") -> void:
	if arena:
		arena.popup(
			position + Vector3(0, visual_height() + 0.1 + extra * 0.25, 0),
			text,
			col,
			scale_k,
			style
		)


# --- Por frame ---


## Avança timers (o status conta em turnos: BattleEndTurn). dt já escalado.
func tick(dt: float) -> void:
	if impact_t > 0.0:
		impact_t = maxf(impact_t - dt, 0.0)
		if impact_t <= 0.0 and impact_knock != Vector3.ZERO:
			knock += impact_knock
			impact_knock = Vector3.ZERO
		return
	if not alive():
		return
	stun_t = maxf(stun_t - dt, 0.0)
	root_t = maxf(root_t - dt, 0.0)
	trap_t = maxf(trap_t - dt, 0.0)
	land_t = maxf(land_t - dt, 0.0)
	evasion_t = maxf(evasion_t - dt, 0.0)
	struggle_cd = maxf(struggle_cd - dt, 0.0)
	sleep_act_t = maxf(sleep_act_t - dt, 0.0)
	entry_t = maxf(entry_t - dt, 0.0)
	breath_t = maxf(breath_t - dt, 0.0)
	jump_cd = maxf(jump_cd - dt, 0.0)
	fly_cd = maxf(fly_cd - dt, 0.0)
	status_immune_t = maxf(status_immune_t - dt, 0.0)
	if status == "paralysis":
		par_t -= dt
		if par_t <= 0.0:
			clear_status()
			popup("No longer paralyzed", Color(1, 1, 0.5), 0.8)
	if status_t > 0.0 and status != "paralysis":
		# O status grave passa sozinho (descansando, mais rápido).
		status_t -= dt * (BattleEnergy.REST_CURE if BattleEnergy.resting(self) else 1.0)
		if status_t <= 0.0:
			clear_status()
			popup("The status wore off!", Color(0.8, 1.0, 0.8), 0.8)
	for k in move_cd.keys():
		move_cd[k] = maxf(move_cd[k] - dt, 0.0)
	gcd_t = maxf(gcd_t - dt, 0.0)
	pp_max = minf(pp_max + BattleEnergy.regen(self) * dt, pp_base)
	if prepare_t > 0.0:
		prepare_t = maxf(prepare_t - dt, 0.0)
		if prepare_t <= 0.0 and prepare_cb.is_valid():
			var cb := prepare_cb
			clear_prepare()
			root_t = 0.0
			if can_act():
				cb.call()


## Move o corpo. want = direção desejada (comprimento <= 1), speed = m/s base.
func drive(dt: float, want: Vector3, speed: float) -> void:
	if impact_t > 0.0 or not alive():
		velocity = Vector3.ZERO
		return
	if status == "paralysis":
		speed *= 0.5
	if sprinting:
		speed *= SPRINT_MULT
	if not can_act() or root_t > 0.0 or status == "sleep":
		want = Vector3.ZERO
	if trap_t > 0.0:
		want = Vector3.ZERO
		dash_t = 0.0
		lunge_t = 0.0
		knock = Vector3.ZERO
	if air_t > 0.0:
		air_t = maxf(air_t - dt, 0.0)
		var jv := sqrt(2.0 * JUMP_G * jump_height)
		var t := jump_time - air_t
		air_h = maxf(jv * t - 0.5 * JUMP_G * t * t, 0.0)
		if air_t <= 0.0:
			air_h = 0.0
			land_t = JUMP_LAND
	if _scripted_step(dt):
		return
	if dash_t > 0.0:
		dash_t -= dt
		if dash_track_t > 0.0:
			dash_track_t -= dt
			_track_dash(dt)
		velocity = dash_dir * dash_speed
		_check_dash_hit()
	elif lunge_t > 0.0:
		lunge_t -= dt
		velocity = lunge_dir * LUNGE_SPEED
		_check_lunge_hit()
	elif arc_step_t > 0.0:
		arc_step_t -= dt
		var step := ARC_STEP_M / ARC_STEP_TIME
		if is_instance_valid(opponent):
			step = minf(step, (flat_to(opponent).length() - HIT_RANGE) / maxf(dt, 0.0001))
		step = maxf(step, 0.0)
		if step == 0.0:
			arc_step_t = 0.0
		velocity = arc_step_dir * step
	else:
		velocity = want * speed + knock
		if is_instance_valid(opponent) and opponent.active():
			var to_o := flat_to(opponent)
			if to_o.length() > 0.01:
				facing = to_o.normalized()
		elif want.length() > 0.1:
			facing = want.normalized()
	knock = knock.move_toward(Vector3.ZERO, KNOCK_DECAY * dt)
	position.x += velocity.x * dt
	position.z += velocity.z * dt
	var fly_want := fly_target
	if dash_t > 0.0 or lunge_t > 0.0 or arc_step_t > 0.0 or prepare_t > 0.0 or not can_act():
		fly_want = minf(fly_want, DIVE_H)
	fly_h = move_toward(fly_h, fly_want if alive() else 0.0, FLY_RISE * dt)
	position.y = ground_y + air_h + fly_h
	if facing.length() > 0.01:
		rotation.y = atan2(-facing.x, -facing.z)


func _tint() -> Color:
	var c := Color.WHITE
	match status:
		"burn":
			c = c.lerp(Color(1, 0.3, 0.1), 0.35)
		"poison", "toxic":
			c = c.lerp(Color(0.6, 0.2, 0.8), 0.35 if status == "poison" else 0.5)
		"freeze":
			c = c.lerp(Color(0.6, 0.9, 1.0), 0.55)
		"paralysis":
			c = c.lerp(Color(1, 1, 0.2), 0.35)
		"sleep":
			c = c.darkened(0.4)
	if has_meta("form_tint"):
		c *= Color(get_meta("form_tint"))  # forma sem arte (BattleAbilitiesMore.set_form)
	return c


# --- Física: movimento roteirizado e arremesso (BattlePhysics) ---


## Começa um movimento de golpe: anda de onde está até `to` em `secs` (salto com altura `h`, que no
## túnel é a velocidade). Com `target`, o destino segue o alvo até a fração `track` do tempo.
## `tick(f, s, dt)` roda a cada passo; `cb` no fim.
func start_motion(
	kind: String,
	to: Vector3,
	secs: float,
	h: float,
	target: BattleFighter,
	cb: Callable,
	track := 0.0,
	tick_cb := Callable(),
	y0 := NAN
) -> void:
	motion = kind
	motion_t = maxf(secs, 0.01)
	motion_total = motion_t
	motion_from = pos2(position)
	motion_to = pos2(to)
	motion_off = motion_to - pos2(target.position) if target else Vector3.ZERO
	motion_h = h
	motion_y0 = position.y if is_nan(y0) else y0  # sem y0: sai da altura em que está (morro, voo)
	motion_track = track
	motion_target = target
	motion_cb = cb
	motion_tick = tick_cb
	dash_t = 0.0
	lunge_t = 0.0
	arc_step_t = 0.0
	knock = Vector3.ZERO


## Interrompe o movimento (desmaio): volta o sprite e sai do esconderijo.
func end_motion() -> void:
	motion = ""
	motion_cb = Callable()
	motion_tick = Callable()
	motion_target = null
	leap_style = ""
	hidden = ""
	if look:
		look.visible = true
		look.position.y = 0.0


## Arremesso: sai a 2 x dist / secs e desacelera até parar em `secs` (percorre `dist`), subindo `lift`.
func launch(dir: Vector3, dist: float, secs: float, lift: float) -> void:
	launch_v = pos2(dir).normalized() * (2.0 * dist / maxf(secs, 0.05))
	launch_t = secs
	launch_total = secs
	launch_lift = lift
	knock = Vector3.ZERO
	impact_knock = Vector3.ZERO
	dash_t = 0.0
	lunge_t = 0.0
	arc_step_t = 0.0
	stun_t = maxf(stun_t, secs * 0.8)


## Um passo do movimento de golpe ou do arremesso; true se tomou conta do corpo neste quadro.
func _scripted_step(dt: float) -> bool:
	if motion != "":
		_motion_step(dt)
	elif launch_t > 0.0:
		_launch_step(dt)
	else:
		return false
	if facing.length() > 0.01:
		rotation.y = atan2(-facing.x, -facing.z)
	return true


func _motion_step(dt: float) -> void:
	var before := position
	motion_t -= dt
	var s := clampf(1.0 - motion_t / maxf(motion_total, 0.001), 0.0, 1.0)
	if is_instance_valid(motion_target) and motion_target.active() and s <= motion_track:
		motion_to = pos2(motion_target.position) + motion_off
	match motion:
		"leap":
			var p := motion_from.lerp(motion_to, s)
			position = Vector3(
				p.x, lerpf(motion_y0, ground_y, s) + motion_h * 4.0 * s * (1.0 - s), p.z
			)
		"tunnel":
			var to := motion_to - pos2(position)
			var stp := motion_h * dt
			if to.length() <= stp + 0.35:
				position += to
				motion_t = 0.0
			elif to.length() > 0.01:
				position += to.normalized() * stp
			position.y = 0.0
		_:
			position.y = ground_y
	var v := pos2(position - before) / maxf(dt, 0.0001)
	velocity = v
	if v.length() > 0.5:
		facing = v.normalized()
	if motion_tick.is_valid():
		motion_tick.call(self, s, dt)
	if motion_t <= 0.0:
		var cb := motion_cb
		motion = ""
		motion_cb = Callable()
		motion_tick = Callable()
		motion_target = null
		position.y = ground_y + air_h + fly_h
		if cb.is_valid():
			cb.call()


func _launch_step(dt: float) -> void:
	var k := launch_t / maxf(launch_total, 0.001)
	var v := launch_v * k
	var next := position + v * dt
	launch_t = maxf(launch_t - dt, 0.0)
	knock = Vector3.ZERO
	if arena and arena.get("moves") and arena.moves.phys.crash_check(self, next):
		velocity = Vector3.ZERO
		position.y = ground_y + air_h + fly_h
		return
	position.x = next.x
	position.z = next.z
	var s := 1.0 - launch_t / maxf(launch_total, 0.001)
	position.y = ground_y + air_h + fly_h + launch_lift * 4.0 * s * (1.0 - s)
	velocity = v


func _check_dash_hit() -> void:
	if dash_hit:
		return
	for t in arena.targets_of(self):
		if t == dash_miss or t.hidden != "" or flat_to(t).length() >= HIT_RANGE:
			continue
		if passes_under(t):
			if not dash_dodged.has(t.get_instance_id()):
				dash_dodged[t.get_instance_id()] = true
				t.popup("DODGED!", Color(0.75, 0.9, 1.0))
				if arena.has_signal("dodged"):
					arena.emit_signal("dodged", t, "under")
			continue
		dash_hit = true
		dash_t = 0.0
		arena.moves.hit(self, t, dash_move, dash_dir)
		return


func _check_lunge_hit() -> void:
	if lunge_done or not is_instance_valid(opponent) or not opponent.active():
		return
	if flat_to(opponent).length() >= HIT_RANGE:
		return
	lunge_done = true
	lunge_t = 0.0
	if passes_under(opponent):
		opponent.popup("DODGED!", Color(0.75, 0.9, 1.0))
		return
	arena.moves.hit(self, opponent, STRUGGLE, lunge_dir)
	if alive():
		take_damage(paced(maxi(1, int(max_hp / 4.0))), Vector3.ZERO, 0.0)
		popup("Recoil", Color(0.9, 0.6, 0.6), 0.8)


## Evoluiu no meio da luta (evolution.gd _complete: creature.apply_species): espécie, tipos, golpes e altura
## novos. Os stats, o nível e o HP vêm do Mon pela arena (_sync_from_mon).
func refresh_species() -> void:
	var sp := Dex.species(mon.species)
	types = mon.types
	moves = mon.moves.slice(0, 4)
	jump_height = float(sp.get("jump_height_override", sp.get("jump_height", JUMP_HEIGHT_DEFAULT)))
	jump_time = sqrt(8.0 * jump_height / JUMP_G) if jump_height > 0.0 else 0.0
	look_h = clampf(float(sp.get("height_m", 1.0)) * 0.9, 0.45, 1.8)
	_set_profile()
	if look and look.species != mon.species:
		look.species = mon.species


## Depois de um item aplicado ao Mon: copia HP e status persistente de volta para o lutador.
func sync_after_item() -> void:
	hp = clampi(hp_from_mon(mon.hp), 0, max_hp)
	if mon.status == "" and status in Mon.PERSIST_STATUS:
		clear_status()
	refresh_label()


## Zera estágios e efeitos temporários e grava HP/PP/status persistentes no Mon.
func write_back() -> void:
	BattleTransform.revert(self)
	if not alive() and mon.hp > 0:
		return  # desmaiou em campo e foi revivido por item depois: não desfaz o Revive
	mon.hp = hp_to_mon(hp)
	mon.status = "poison" if status == "toxic" else status if status in Mon.PERSIST_STATUS else ""
	mon.battle_status = status if status in ["toxic", "freeze"] else ""
	mon.par_left = par_t if status == "paralysis" else 0.0
	mon.sleep_left = sleep_turns if status == "sleep" else 0

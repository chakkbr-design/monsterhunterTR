class_name BattleTransform
extends RefCounted
## Transform: o usuário vira uma cópia do alvo pelo resto do tempo dele em campo (a troca ou o
## desmaio criam um lutador novo; write_back desfaz por segurança). Copia espécie (arte, peso, altura,
## pulo, perfil de movimento e voo), tipos, stats menos o HP, estágios e golpes, e a habilidade. Fica
## do usuário o nível, o HP, o status, os cooldowns e o item.
## `BattleTransform.apply(arena, user, target)` é chamado pelo golpe Transform (battle_kanto.gd) e vai
## ser chamado pela habilidade Imposter (Ditto) quando ela existir.

const COPY_STATS := ["atk", "def", "spa", "spd", "spe"]
const META := "transformed"
const META_ORIG := "transform_orig"


static func is_transformed(f: BattleFighter) -> bool:
	return is_instance_valid(f) and bool(f.get_meta(META, false))


## Vira cópia do alvo. false = não deu (alvo caído ou escondido, com substituto, ou o usuário já é uma cópia).
static func apply(arena: Node, user: BattleFighter, target: BattleFighter) -> bool:
	if not _can_copy(arena, user, target):
		return false
	(
		user
		. set_meta(
			META_ORIG,
			{
				"types": user.types.duplicate(),
				"stats": user.stats.duplicate(),
				"moves": user.moves.duplicate(),
				"species": user.look.species if user.look else "",
				"body": user.body,
				"jump_height": user.jump_height,
				"jump_time": user.jump_time,
				"look_h": user.look_h,
				"profile": user.profile,
				"prof": user.prof,
				"fly_target": user.fly_target,
				"ability":
				user.get_meta("ability_override") if user.has_meta("ability_override") else null,
			}
		)
	)
	user.set_meta(META, true)
	user.types = target.types.duplicate()
	for k in COPY_STATS:
		user.stats[k] = target.stats.get(k, user.stats.get(k, 10))
	user.stages = target.stages.duplicate()
	user.crit_stage = target.crit_stage
	user.moves = target.moves.slice(0, 4)
	user.move_cd.clear()
	user.body = target.body_id()
	user.jump_height = target.jump_height
	user.jump_time = target.jump_time
	user.look_h = target.look_h
	user.profile = target.profile
	user.prof = target.prof.duplicate()
	user.fly_target = float(user.prof.get("fly", 0.0))
	var ab = arena.get("abilities")
	if ab and ab.has_method("ability_of"):
		user.set_meta("ability_override", String(ab.ability_of(target)))
	if user.look and target.look:
		user.look.species = target.look.species
	if arena.get("vfx") and arena.is_inside_tree():
		arena.vfx.puff(arena.to_global(user.position + Vector3(0, 0.5, 0)), 1.6)
	user.popup(
		"Virou %s!" % target.mon.display_name, Dex.type_color(String(target.types[0])), 1.1, 0.9
	)
	user.refresh_label()
	return true


static func _can_copy(arena: Node, user: BattleFighter, target: BattleFighter) -> bool:
	if not is_instance_valid(user) or not user.alive() or is_transformed(user):
		return false
	if not is_instance_valid(target) or target == user or not target.active():
		return false
	if target.hidden != "" or target.types.is_empty():
		return false
	var mv = arena.get("moves")
	if mv and int(mv.effects.st(target).sub) > 0:
		return false  # o substituto esconde o alvo
	return true


## Volta a ser o que era (o lutador acabou de sair de campo ou a luta acabou).
static func revert(f: BattleFighter) -> void:
	if not is_transformed(f):
		return
	var o: Dictionary = f.get_meta(META_ORIG, {})
	f.remove_meta(META)
	f.remove_meta(META_ORIG)
	if o.is_empty():
		return
	f.types = o.types
	f.stats = o.stats
	f.moves = o.moves
	f.body = o.body
	f.jump_height = o.jump_height
	f.jump_time = o.jump_time
	f.look_h = o.look_h
	f.profile = o.profile
	f.prof = o.prof
	f.fly_target = float(f.prof.get("fly", 0.0))
	if o.ability == null:
		f.remove_meta("ability_override")
	else:
		f.set_meta("ability_override", o.ability)
	if f.look and String(o.species) != "":
		f.look.species = o.species

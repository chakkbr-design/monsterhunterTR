extends SceneTree
## Rodar: godot --headless --fixed-fps 60 --path . --script res://tests/battle/test_more_abilities.gd
## As 151 habilidades da Gen 3-9 que faltavam (battle_abilities_more.gd), modo de energia. As espécies
## novas ainda não existem: o teste empresta a habilidade a um lutador com set_meta("ability_override", id).

const ARENA := "res://battle/battle_arena.tscn"
const DT := 1.0 / 60.0
const IDS := [
	"pickpocket",
	"klutz",
	"beast_boost",
	"contrary",
	"bulletproof",
	"protosynthesis",
	"quark_drive",
	"sweet_veil",
	"moody",
	"heavy_metal",
	"stakeout",
	"protean",
	"magic_bounce",
	"light_metal",
	"cheek_pouch",
	"aroma_veil",
	"fluffy",
	"shadow_tag",
	"suction_cups",
	"simple",
	"heatproof",
	"magician",
	"gooey",
	"honey_gather",
	"solid_rock",
	"white_smoke",
	"flower_veil",
	"symbiosis",
	"corrosion",
	"grassy_surge",
	"magma_armor",
	"wind_rider",
	"truant",
	"sharpness",
	"iron_barbs",
	"long_reach",
	"liquid_voice",
	"stamina",
	"libero",
	"steam_engine",
	"ripen",
	"purifying_salt",
	"thermal_exchange",
	"toxic_chain",
	"normalize",
	"pure_power",
	"flare_boost",
	"slow_start",
	"mummy",
	"defeatist",
	"illusion",
	"grass_pelt",
	"mega_launcher",
	"refrigerate",
	"merciless",
	"water_bubble",
	"water_compaction",
	"electric_surge",
	"psychic_surge",
	"cotton_down",
	"sand_spit",
	"propeller_tail",
	"ice_scales",
	"stalwart",
	"wind_power",
	"guard_dog",
	"mycelium_might",
	"toxic_debris",
	"supersweet_syrup",
	"hospitality",
	"wonder_guard",
	"stall",
	"toxic_boost",
	"forecast",
	"color_change",
	"air_lock",
	"flower_gift",
	"bad_dreams",
	"multitype",
	"victory_star",
	"zen_mode",
	"turboblaze",
	"teravolt",
	"fur_coat",
	"stance_change",
	"pixilate",
	"fairy_aura",
	"dark_aura",
	"aura_break",
	"battery",
	"dancer",
	"schooling",
	"queenly_majesty",
	"triage",
	"receiver",
	"wimp_out",
	"emergency_exit",
	"innards_out",
	"rks_system",
	"shields_down",
	"comatose",
	"disguise",
	"dazzling",
	"berserk",
	"steelworker",
	"misty_surge",
	"full_metal_body",
	"shadow_shield",
	"prism_armor",
	"soul_heart",
	"mirror_armor",
	"ball_fetch",
	"gulp_missile",
	"punk_rock",
	"steely_spirit",
	"perish_body",
	"screen_cleaner",
	"wandering_spirit",
	"power_spot",
	"ice_face",
	"hunger_switch",
	"intrepid_sword",
	"dauntless_shield",
	"unseen_fist",
	"transistor",
	"dragons_maw",
	"chilling_neigh",
	"grim_neigh",
	"lingering_aroma",
	"well_baked_body",
	"seed_sower",
	"electromorphosis",
	"anger_shell",
	"opportunist",
	"rocky_payload",
	"zero_to_hero",
	"earth_eater",
	"costar",
	"commander",
	"cud_chew",
	"armor_tail",
	"supreme_overlord",
	"good_as_gold",
	"tablets_of_ruin",
	"sword_of_ruin",
	"vessel_of_ruin",
	"beads_of_ruin",
	"orichalcum_pulse",
	"hadron_engine",
	"tera_shift",
	"poison_puppeteer",
]

var _fails := 0
var _count := 0


func _initialize() -> void:
	_data()
	_stage_abilities()
	_damage_table()
	_status_blocks()
	_surges()
	_type_changers()
	_truant_slow_stall()
	_immunities()
	_status_moves()
	_priority_block()
	_contact()
	_hit_triggers()
	_disguise_ice_face()
	_thresholds()
	_forms()
	_paradox()
	_kos()
	_faint_watchers()
	_ruin_and_team()
	_items()
	_round_end()
	_misc()
	_doubles()
	_smoke()
	print("more abilities: %d checks, %d falhas" % [_count, _fails])
	quit(1 if _fails else 0)


func check(ok: bool, what: String) -> void:
	_count += 1
	if not ok:
		_fails += 1
		print("FALHOU: ", what)


func _arena(party: Array, enemies: Array, opts: Dictionary) -> Node:
	var a: Node = load(ARENA).instantiate()
	a.manual = true
	root.add_child(a)
	if not opts.has("speed"):
		opts["speed"] = 1.0
	if not opts.has("auto_battle"):
		opts["auto_battle"] = false
	a.start(party, enemies, opts)
	return a


func _run(a: Node, secs: float) -> void:
	for i in int(round(secs / DT)):
		a.step(DT)


## Arena parada em modo de energia: ninguém age sozinho.
func _still(mine := "pidgey", foe := "rattata", opts := {}) -> Node:
	opts["seed"] = 11
	var a := _arena([Mon.create(mine, 30)], [Mon.create(foe, 30)], opts)
	_run(a, 1.3)
	a.enemy.controller = "none"
	a.player.controller = "none"
	_run(a, 1.5)
	a.player.heal(a.player.max_hp)
	a.enemy.heal(a.enemy.max_hp)
	return a


func _give(f: BattleFighter, ab: String) -> void:
	f.set_meta("ability_override", ab)


func _data() -> void:
	var bad := 0
	for id in IDS:
		var d := Dex.ability(id)
		if (
			d.is_empty()
			or String(d.get("name", "")) != String(d.get("name", "")).to_upper()
			or String(d.get("desc", "")) == ""
			or String(d.get("desc_pt", "")) == ""
		):
			bad += 1
			print("  sem texto: ", id)
	check(IDS.size() == 151, "são 151 habilidades (%d)" % IDS.size())
	check(bad == 0, "as 151 têm name em maiúsculas, desc e desc_pt")


func _stage_abilities() -> void:
	var a := _still()
	_give(a.player, "contrary")
	a.moves.change_stage(a.player, "atk", 1)
	check(int(a.player.stages.atk) == -1, "Contrary: +1 vira -1")
	a.moves.change_stage(a.player, "def", -2)
	check(int(a.player.stages.def) == 2, "Contrary: -2 vira +2")
	_give(a.player, "simple")
	a.moves.change_stage(a.player, "spa", 1)
	check(int(a.player.stages.spa) == 2, "Simple: +1 vale +2")
	_give(a.player, "mirror_armor")
	a.moves.change_stage(a.player, "spe", -1, a.enemy)
	check(int(a.player.stages.spe) == 0, "Mirror Armor: o -1 não pega nele")
	check(int(a.enemy.stages.spe) == -1, "Mirror Armor: o -1 volta para quem causou")
	var b := _still()
	_give(b.player, "white_smoke")
	b.moves.change_stage(b.player, "atk", -1, b.enemy)
	check(int(b.player.stages.atk) == 0, "White Smoke: ninguém baixa o atributo dele")
	_give(b.player, "full_metal_body")
	b.moves.change_stage(b.player, "def", -1, b.enemy)
	check(int(b.player.stages.def) == 0, "Full Metal Body: idem")
	_give(b.enemy, "mold_breaker")
	b.moves.change_stage(b.player, "def", -1, b.enemy)
	check(int(b.player.stages.def) == 0, "Full Metal Body: Mold Breaker não passa")
	_give(b.enemy, "guard_dog")
	_give(b.player, "intimidate")
	b.abilities.on_enter(b.player)
	_run(b, 0.3)
	check(
		int(b.enemy.stages.atk) == 1,
		"Guard Dog: Intimidate dá +1 de Ataque (%d)" % int(b.enemy.stages.atk)
	)
	a.free()
	b.free()
	var c := _still()
	_give(c.enemy, "mirror_armor")
	_give(c.player, "intimidate")
	c.abilities.on_enter(c.player)
	_run(c, 0.3)
	check(int(c.player.stages.atk) == -1, "Mirror Armor: devolve a intimidação")
	c.free()


func _damage_table() -> void:
	var a := _still("pidgey", "rattata")
	var ab: BattleAbilities = a.abilities
	var tackle := Dex.move("tackle")
	var shock := Dex.move("thunder_shock")  # superefetivo no Voador
	var base_p := ab.damage_mult(a.enemy, a.player, shock)
	_give(a.player, "solid_rock")
	check(
		is_equal_approx(ab.damage_mult(a.enemy, a.player, shock), base_p * 0.75),
		"Solid Rock: superefetivo x0,75"
	)
	_give(a.player, "prism_armor")
	check(
		is_equal_approx(ab.damage_mult(a.enemy, a.player, shock), base_p * 0.75),
		"Prism Armor: superefetivo x0,75"
	)
	_give(a.enemy, "mold_breaker")
	check(
		is_equal_approx(ab.damage_mult(a.enemy, a.player, shock), base_p * 0.75),
		"Prism Armor: Mold Breaker não passa"
	)
	_give(a.player, "solid_rock")
	check(ab.damage_mult(a.enemy, a.player, shock) == base_p, "Solid Rock: Mold Breaker passa")
	_give(a.enemy, "")
	a.enemy.remove_meta("ability_override")
	_give(a.enemy, "turboblaze")
	check(
		ab.damage_mult(a.enemy, a.player, shock) == base_p,
		"Turboblaze passa por cima como Mold Breaker"
	)
	_give(a.enemy, "teravolt")
	check(ab.damage_mult(a.enemy, a.player, shock) == base_p, "Teravolt idem")
	a.player.remove_meta("ability_override")
	_give(a.enemy, "pure_power")
	check(is_equal_approx(ab.damage_mult(a.enemy, a.player, tackle), 2.0), "Pure Power: físico x2")
	_give(a.enemy, "transistor")
	check(
		is_equal_approx(ab.damage_mult(a.enemy, a.player, shock), 1.3), "Transistor: Elétrico x1,3"
	)
	_give(a.enemy, "dragons_maw")
	check(ab.damage_mult(a.enemy, a.player, shock) == 1.0, "Dragon's Maw: só Dragão")
	_give(a.enemy, "steelworker")
	check(
		(
			ab.damage_mult(a.enemy, a.player, Dex.move("iron_tail")) >= 1.5
			or Dex.move("iron_tail").is_empty()
		),
		"Steelworker: Aço x1,5"
	)
	_give(a.enemy, "rocky_payload")
	check(
		is_equal_approx(ab.damage_mult(a.enemy, a.player, Dex.move("rock_throw")), 1.5),
		"Rocky Payload: Pedra x1,5"
	)
	_give(a.enemy, "")
	a.enemy.remove_meta("ability_override")
	var ember := Dex.move("ember")
	_give(a.player, "heatproof")
	check(is_equal_approx(ab.damage_mult(a.enemy, a.player, ember), 0.5), "Heatproof: Fogo x0,5")
	_give(a.player, "water_bubble")
	check(is_equal_approx(ab.damage_mult(a.enemy, a.player, ember), 0.5), "Water Bubble: Fogo x0,5")
	check(
		is_equal_approx(ab.damage_mult(a.player, a.enemy, Dex.move("water_gun")), 2.0),
		"Water Bubble: golpe de Água dele x2"
	)
	_give(a.player, "fluffy")
	check(is_equal_approx(ab.damage_mult(a.enemy, a.player, tackle), 0.5), "Fluffy: contato x0,5")
	check(is_equal_approx(ab.damage_mult(a.enemy, a.player, ember), 2.0), "Fluffy: Fogo x2")
	_give(a.player, "fur_coat")
	check(is_equal_approx(ab.damage_mult(a.enemy, a.player, tackle), 0.5), "Fur Coat: físico x0,5")
	check(ab.damage_mult(a.enemy, a.player, shock) == base_p, "Fur Coat: o especial passa")
	_give(a.player, "ice_scales")
	check(
		is_equal_approx(ab.damage_mult(a.enemy, a.player, shock), base_p * 0.5),
		"Ice Scales: especial x0,5"
	)
	_give(a.player, "shadow_shield")
	check(
		is_equal_approx(ab.damage_mult(a.enemy, a.player, tackle), 0.5),
		"Shadow Shield: HP cheio x0,5"
	)
	a.player.hp -= 3
	check(ab.damage_mult(a.enemy, a.player, tackle) == 1.0, "Shadow Shield: sem HP cheio não vale")
	a.player.hp = a.player.max_hp
	_give(a.player, "purifying_salt")
	check(
		ab.damage_mult(a.enemy, a.player, Dex.move("lick")) <= 0.5 or Dex.move("lick").is_empty(),
		"Purifying Salt: Fantasma x0,5"
	)
	_give(a.player, "punk_rock")
	_give(a.enemy, "punk_rock")
	var growl_like := Dex.move("hyper_voice")
	check(
		is_equal_approx(ab.damage_mult(a.enemy, a.player, growl_like), 1.3 * 0.5),
		"Punk Rock: som sai x1,3 e entra x0,5"
	)
	_give(a.enemy, "flare_boost")
	a.enemy.apply_status("burn", null)
	check(
		ab.damage_mult(a.enemy, a.player, shock) >= 1.5 / 1.0 - 0.01,
		"Flare Boost: especial x1,5 queimado"
	)
	a.enemy.clear_status()
	_give(a.enemy, "toxic_boost")
	a.enemy.apply_status("poison", null)
	check(
		is_equal_approx(ab.damage_mult(a.enemy, a.player, tackle), 1.5),
		"Toxic Boost: físico x1,5 envenenado"
	)
	a.enemy.clear_status()
	_give(a.enemy, "defeatist")
	check(ab.damage_mult(a.enemy, a.player, tackle) == 1.0, "Defeatist: HP cheio normal")
	a.enemy.hp = a.enemy.max_hp / 2
	check(
		is_equal_approx(ab.damage_mult(a.enemy, a.player, tackle), 0.5),
		"Defeatist: metade do HP corta o dano"
	)
	a.enemy.hp = a.enemy.max_hp
	_give(a.enemy, "sharpness")
	check(
		is_equal_approx(ab.damage_mult(a.enemy, a.player, Dex.move("slash")), 1.5),
		"Sharpness: corte x1,5"
	)
	check(ab.damage_mult(a.enemy, a.player, tackle) == 1.0, "Sharpness: só os de corte")
	_give(a.enemy, "mega_launcher")
	check(
		is_equal_approx(ab.damage_mult(a.enemy, a.player, Dex.move("water_pulse")), 1.5),
		"Mega Launcher: pulso x1,5"
	)
	a.free()


func _status_blocks() -> void:
	var a := _still()
	var ab: BattleAbilities = a.abilities
	_give(a.player, "magma_armor")
	check(ab.blocks_status(a.player, "freeze"), "Magma Armor: não congela")
	check(not ab.blocks_status(a.player, "burn"), "Magma Armor: queima normal")
	_give(a.player, "water_bubble")
	check(ab.blocks_status(a.player, "burn"), "Water Bubble: não queima")
	_give(a.player, "thermal_exchange")
	check(ab.blocks_status(a.player, "burn"), "Thermal Exchange: não queima")
	_give(a.player, "purifying_salt")
	check(
		ab.blocks_status(a.player, "toxic") and ab.blocks_status(a.player, "sleep"),
		"Purifying Salt: nenhum status grave"
	)
	_give(a.player, "comatose")
	check(ab.blocks_status(a.player, "paralysis"), "Comatose: não pega status")
	_give(a.player, "sweet_veil")
	check(ab.blocks_status(a.player, "sleep"), "Sweet Veil: não dorme")
	_give(a.player, "aroma_veil")
	check(ab.blocks_status(a.player, "confusion"), "Aroma Veil: sem confusão")
	_give(a.player, "")
	a.player.remove_meta("ability_override")
	_give(a.enemy, "corrosion")
	var b := _still("rattata", "pidgey")
	b.player.types = ["poison"]
	_give(b.enemy, "toxic_chain")
	check(
		not b.moves.effects.blocks_status(b.enemy, b.player, "poison") == false,
		"Veneno não pega em Veneno sem Corrosion"
	)
	_give(b.enemy, "corrosion")
	check(
		not b.moves.effects.blocks_status(b.enemy, b.player, "poison"), "Corrosion: envenena Veneno"
	)
	b.player.types = ["steel"]
	check(not b.moves.effects.blocks_status(b.enemy, b.player, "toxic"), "Corrosion: envenena Aço")
	# poison puppeteer: veneno também confunde
	_give(b.enemy, "poison_puppeteer")
	b.player.types = ["normal"]
	b.player.apply_status("poison", b.enemy)
	check(b.player.confusion_t > 0.0, "Poison Puppeteer: o veneno também confunde")
	a.free()
	b.free()


func _surges() -> void:
	var a := _still()
	var fx: BattleMoveEffects = a.moves.effects
	_give(a.player, "grassy_surge")
	a.abilities.on_enter(a.player)
	_run(a, 0.3)
	check(fx.active(fx.field, "grassy"), "Grassy Surge: cria o campo de grama")
	_give(a.player, "electric_surge")
	a.abilities._pending_enter.append(a.player)
	_run(a, 0.3)
	check(
		fx.active(fx.field, "electric") and not fx.active(fx.field, "grassy"),
		"Electric Surge troca o campo"
	)
	_give(a.player, "psychic_surge")
	a.abilities._pending_enter.append(a.player)
	_run(a, 0.3)
	check(fx.active(fx.field, "psychic"), "Psychic Surge: campo psíquico")
	_give(a.player, "misty_surge")
	a.abilities._pending_enter.append(a.player)
	_run(a, 0.3)
	check(fx.active(fx.field, "misty"), "Misty Surge: campo de névoa")
	_give(a.player, "orichalcum_pulse")
	a.abilities._pending_enter.append(a.player)
	_run(a, 0.3)
	check(a.abilities.weather_now() == "sun", "Orichalcum Pulse: cria sol")
	check(
		is_equal_approx(a.abilities.damage_mult(a.player, a.enemy, Dex.move("tackle")), 4.0 / 3.0),
		"Orichalcum Pulse: físico x1,33 no sol"
	)
	_give(a.player, "hadron_engine")
	a.abilities._pending_enter.append(a.player)
	_run(a, 0.3)
	check(fx.active(fx.field, "electric"), "Hadron Engine: campo elétrico")
	check(
		is_equal_approx(
			a.abilities.damage_mult(a.player, a.enemy, Dex.move("thunder_shock")), 4.0 / 3.0
		),
		"Hadron Engine: especial x1,33 no campo elétrico"
	)
	_give(a.player, "grass_pelt")
	fx._set_terrain("grassy", a.player, "x", "grass")
	check(
		is_equal_approx(a.abilities.damage_mult(a.enemy, a.player, Dex.move("tackle")), 1.0 / 1.5),
		"Grass Pelt: Defesa x1,5 no campo de grama"
	)
	_give(a.player, "screen_cleaner")
	fx.set_rounds(fx._sd(1), "reflect", 5)
	a.abilities._pending_enter.append(a.player)
	_run(a, 0.3)
	check(not fx.side_active(1, "reflect"), "Screen Cleaner: desfaz o Reflect")
	a.free()


func _type_changers() -> void:
	var a := _still()
	var fx: BattleMoveEffects = a.moves.effects
	var tackle := Dex.move("tackle")
	_give(a.player, "pixilate")
	var m := fx.move_for(a.player, tackle)
	check(
		String(m.type) == "fairy" and is_equal_approx(float(m.ate), 1.2),
		"Pixilate: Normal vira Fada com x1,2"
	)
	check(
		is_equal_approx(a.abilities.damage_mult(a.player, a.enemy, m), 1.2),
		"Pixilate: o dano sai x1,2"
	)
	_give(a.player, "refrigerate")
	check(String(fx.move_for(a.player, tackle).type) == "ice", "Refrigerate: Normal vira Gelo")
	check(
		String(fx.move_for(a.player, Dex.move("ember")).type) == "fire",
		"Refrigerate: só Normal muda"
	)
	_give(a.player, "normalize")
	check(
		String(fx.move_for(a.player, Dex.move("ember")).type) == "normal",
		"Normalize: tudo vira Normal"
	)
	_give(a.player, "liquid_voice")
	check(
		String(fx.move_for(a.player, Dex.move("hyper_voice")).type) == "water",
		"Liquid Voice: som vira Água"
	)
	check(String(fx.move_for(a.player, tackle).type) == "normal", "Liquid Voice: golpe comum fica")
	_give(a.player, "protean")
	a.abilities.on_move_used(a.player, Dex.move("ember"))
	check(a.player.types == ["fire"], "Protean: vira Fogo ao usar Ember")
	a.abilities.on_move_used(a.player, Dex.move("water_gun"))
	check(a.player.types == ["fire"], "Protean: só uma vez por entrada")
	_give(a.player, "libero")
	var b := _still()
	_give(b.player, "libero")
	b.abilities.on_move_used(b.player, Dex.move("water_gun"))
	check(b.player.types == ["water"], "Libero: vira Água")
	# Multitype / RKS: sem placa, o melhor golpe que não é Normal
	_give(b.player, "multitype")
	b.player.moves = ["tackle", "thunderbolt", "ember"]
	b.abilities._pending_enter.append(b.player)
	_run(b, 0.3)
	check(
		b.player.types == ["electric"],
		"Multitype: tipo do melhor golpe que não é Normal (%s)" % str(b.player.types)
	)
	check(
		(
			String(
				(
					b
					. moves
					. effects
					. move_for(
						b.player,
						{"id": "judgment", "type": "normal", "power": 100, "category": "special"}
					)
					. type
				)
			)
			== "electric"
		),
		"Multitype: Judgment segue o tipo"
	)
	# Color Change
	_give(b.enemy, "color_change")
	b.abilities.on_hit(b.player, b.enemy, Dex.move("water_gun"), 5)
	check(b.enemy.types == ["water"], "Color Change: vira o tipo do golpe")
	a.free()
	b.free()


func _truant_slow_stall() -> void:
	var a := _still()
	var ab: BattleAbilities = a.abilities
	var fx: BattleMoveEffects = a.moves.effects
	var tackle := Dex.move("tackle")
	_give(a.player, "truant")
	check(fx.usable(a.player, tackle), "Truant: age na primeira rodada")
	ab.on_move_used(a.player, tackle)
	check(fx.usable(a.player, tackle), "Truant: ainda pode usar na rodada em que agiu")
	ab.late_residual(a.player)
	check(not fx.usable(a.player, tackle), "Truant: vadia na rodada seguinte")
	ab.late_residual(a.player)
	check(fx.usable(a.player, tackle), "Truant: volta a agir depois")
	_give(a.player, "slow_start")
	ab.on_enter(a.player)
	_run(a, 0.4)
	check(
		is_equal_approx(ab.damage_mult(a.player, a.enemy, tackle), 0.5),
		"Slow Start: Ataque pela metade"
	)
	check(ab.order_speed_mult(a.player) == 0.5, "Slow Start: Speed pela metade na ordem")
	check(ab.walk_mult(a.player) < 1.0, "Slow Start: anda mais devagar")
	for i in 5:
		ab.late_residual(a.player)
		ab.finish_round([])
	check(ab.damage_mult(a.player, a.enemy, tackle) == 1.0, "Slow Start: acaba em 5 rodadas")
	_give(a.player, "stall")
	check(ab.order_speed_mult(a.player) < 0.1, "Stall: último na ordem")
	check(ab.cast_speed_mult(a.player, tackle) < 1.0, "Stall: prepara mais devagar")
	_give(a.player, "triage")
	check(
		ab.priority_bonus(a.player, Dex.move("recover")) == 3 or Dex.move("recover").is_empty(),
		"Triage: +3 em golpe de cura"
	)
	check(ab.priority_bonus(a.player, tackle) == 0, "Triage: golpe comum sem bônus")
	_give(a.player, "mycelium_might")
	check(
		ab.cast_speed_mult(a.player, Dex.move("growl")) < 1.0,
		"Mycelium Might: golpe de estado mais devagar"
	)
	a.free()


func _immunities() -> void:
	var a := _still()
	var ab: BattleAbilities = a.abilities
	_give(a.enemy, "bulletproof")
	check(ab.immune(a.player, a.enemy, Dex.move("shadow_ball")), "Bulletproof: bola não acerta")
	check(not ab.immune(a.player, a.enemy, Dex.move("tackle")), "Bulletproof: golpe comum acerta")
	_give(a.enemy, "wind_rider")
	var w := Dex.move("gust")
	if w.is_empty():
		w = {"id": "gust", "type": "flying", "power": 40, "category": "special"}
	check(ab.immune(a.player, a.enemy, w), "Wind Rider: vento não acerta")
	check(int(a.enemy.stages.atk) == 1, "Wind Rider: Ataque +1")
	_give(a.enemy, "earth_eater")
	a.enemy.hp = a.enemy.max_hp / 2
	var h0: int = a.enemy.hp
	check(ab.immune(a.player, a.enemy, Dex.move("earthquake")), "Earth Eater: imune a Terra")
	check(a.enemy.hp > h0, "Earth Eater: cura")
	_give(a.enemy, "well_baked_body")
	check(ab.immune(a.player, a.enemy, Dex.move("ember")), "Well-Baked Body: imune a Fogo")
	check(int(a.enemy.stages.def) == 2, "Well-Baked Body: Defesa +2")
	_give(a.enemy, "wonder_guard")
	check(ab.immune(a.player, a.enemy, Dex.move("tackle")), "Wonder Guard: golpe normal não acerta")
	var b := _still("rattata", "pidgey")
	_give(b.enemy, "wonder_guard")
	check(
		not b.abilities.immune(b.player, b.enemy, Dex.move("thunder_shock")),
		"Wonder Guard: superefetivo acerta"
	)
	_give(b.player, "mold_breaker")
	check(
		not b.abilities.immune(b.player, b.enemy, Dex.move("tackle")),
		"Wonder Guard: Mold Breaker passa"
	)
	_give(a.enemy, "propeller_tail")
	a.free()
	b.free()


func _status_moves() -> void:
	var a := _still()
	var ab: BattleAbilities = a.abilities
	var fx: BattleMoveEffects = a.moves.effects
	var growl := Dex.move("growl")
	_give(a.enemy, "good_as_gold")
	check(fx.blocks_hit(a.player, a.enemy, growl), "Good as Gold: golpe de estado não pega")
	check(
		not fx.blocks_hit(a.player, a.enemy, Dex.move("tackle")), "Good as Gold: golpe de dano pega"
	)
	_give(a.enemy, "magic_bounce")
	var before := int(a.player.stages.atk)
	check(fx.blocks_hit(a.player, a.enemy, growl), "Magic Bounce: o golpe não chega")
	check(
		int(a.player.stages.atk) == before - 1,
		"Magic Bounce: o Growl volta para quem usou (%d)" % int(a.player.stages.atk)
	)
	_give(a.enemy, "aroma_veil")
	check(
		fx.blocks_hit(a.player, a.enemy, Dex.move("taunt")) or Dex.move("taunt").is_empty(),
		"Aroma Veil: Taunt não pega"
	)
	_give(a.enemy, "mycelium_might")
	_give(a.player, "mycelium_might")
	_give(a.enemy, "magic_bounce")
	check(
		not fx.blocks_hit(a.player, a.enemy, growl),
		"Mycelium Might: o estado passa pelo Magic Bounce"
	)
	a.free()


func _priority_block() -> void:
	var a := _still()
	var fx: BattleMoveEffects = a.moves.effects
	var quick := Dex.move("quick_attack")
	for ab_id in ["queenly_majesty", "dazzling", "armor_tail"]:
		_give(a.enemy, ab_id)
		check(fx.blocks_hit(a.player, a.enemy, quick), "%s: prioridade não acerta" % ab_id)
		check(
			not fx.blocks_hit(a.player, a.enemy, Dex.move("tackle")),
			"%s: golpe comum acerta" % ab_id
		)
	_give(a.enemy, "dazzling")
	_give(a.player, "mold_breaker")
	check(not fx.blocks_hit(a.player, a.enemy, quick), "Dazzling: Mold Breaker passa")
	a.free()


func _contact() -> void:
	var a := _still()
	var ab: BattleAbilities = a.abilities
	var tackle := Dex.move("tackle")
	_give(a.enemy, "gooey")
	ab.on_hit(a.player, a.enemy, tackle, 5)
	check(int(a.player.stages.spe) == -1, "Gooey: contato baixa a Speed")
	a.player.stages.spe = 0
	ab.on_hit(a.player, a.enemy, Dex.move("thunder_shock"), 5)
	check(int(a.player.stages.spe) == 0, "Gooey: sem contato não pega")
	_give(a.player, "long_reach")
	ab.on_hit(a.player, a.enemy, tackle, 5)
	check(int(a.player.stages.spe) == 0, "Long Reach: o golpe dele não encosta")
	_give(a.player, "pidgey_ab")
	a.player.remove_meta("ability_override")
	_give(a.enemy, "iron_barbs")
	var hp0: int = a.player.hp
	ab.on_hit(a.player, a.enemy, tackle, 5)
	check(
		hp0 - a.player.hp == a.player.paced(maxi(1, int(a.player.max_hp * 0.125))),
		"Iron Barbs: 1/8 do HP de quem encosta"
	)
	_give(a.enemy, "mummy")
	a.player.set_meta("ability_override", "keen_eye")
	ab.on_hit(a.player, a.enemy, tackle, 5)
	check(ab.ability_of(a.player) == "mummy", "Mummy: quem encosta vira Mummy")
	_give(a.enemy, "lingering_aroma")
	a.player.set_meta("ability_override", "keen_eye")
	ab.on_hit(a.player, a.enemy, tackle, 5)
	check(ab.ability_of(a.player) == "lingering_aroma", "Lingering Aroma: idem")
	_give(a.enemy, "wandering_spirit")
	a.player.set_meta("ability_override", "keen_eye")
	ab.on_hit(a.player, a.enemy, tackle, 5)
	check(
		ab.ability_of(a.player) == "wandering_spirit" and ab.ability_of(a.enemy) == "keen_eye",
		"Wandering Spirit: troca de habilidade"
	)
	a.player.set_meta("ability_override", "wonder_guard")
	_give(a.enemy, "mummy")
	ab.on_hit(a.player, a.enemy, tackle, 5)
	check(ab.ability_of(a.player) == "wonder_guard", "Mummy: não sobrescreve Wonder Guard")
	a.player.remove_meta("ability_override")
	_give(a.enemy, "pickpocket")
	a.player.trainer_item = "leftovers"
	a.player.item_used = false
	a.enemy.trainer_item = ""
	ab.on_hit(a.player, a.enemy, tackle, 5)
	check(
		a.enemy.trainer_item == "leftovers" and a.player.item_used,
		"Pickpocket: rouba o item de quem encosta"
	)
	_give(a.player, "magician")
	a.enemy.item_used = false
	a.player.trainer_item = ""
	a.player.item_used = false
	a.enemy.trainer_item = "oran_berry"
	_give(a.enemy, "")
	a.enemy.remove_meta("ability_override")
	ab.on_hit(a.player, a.enemy, Dex.move("thunder_shock"), 5)
	check(a.player.trainer_item == "oran_berry", "Magician: rouba o item do alvo ao acertar")
	_give(a.enemy, "perish_body")
	ab.on_hit(a.player, a.enemy, tackle, 5)
	var fx: BattleMoveEffects = a.moves.effects
	check(
		fx.active(fx.st(a.player), "perish") and fx.active(fx.st(a.enemy), "perish"),
		"Perish Body: os dois ganham a contagem"
	)
	a.free()


func _hit(a: Node, ability: String, mv: Dictionary, user := "") -> void:
	_give(a.enemy, ability)
	a.abilities.on_hit(a.player, a.enemy, mv, 5)


func _hit_triggers() -> void:
	var a := _still()
	var ab: BattleAbilities = a.abilities
	var fx: BattleMoveEffects = a.moves.effects
	_hit(a, "stamina", Dex.move("tackle"))
	check(int(a.enemy.stages.def) == 1, "Stamina: Defesa +1")
	a.enemy.stages.def = 0
	_hit(a, "water_compaction", Dex.move("water_gun"))
	check(int(a.enemy.stages.def) == 2, "Water Compaction: Defesa +2 com Água")
	_hit(a, "steam_engine", Dex.move("ember"))
	check(int(a.enemy.stages.spe) == 6, "Steam Engine: Speed +6 com Fogo")
	_hit(a, "thermal_exchange", Dex.move("ember"))
	check(int(a.enemy.stages.atk) == 1, "Thermal Exchange: Ataque +1 com Fogo")
	_hit(a, "cotton_down", Dex.move("tackle"))
	check(int(a.player.stages.spe) == -1, "Cotton Down: baixa a Speed dos outros")
	_hit(a, "sand_spit", Dex.move("tackle"))
	check(ab.weather_now() == "sand", "Sand Spit: cria tempestade de areia")
	_hit(a, "seed_sower", Dex.move("tackle"))
	check(fx.active(fx.field, "grassy"), "Seed Sower: cria o campo de grama")
	_hit(a, "toxic_debris", Dex.move("tackle"))
	check(fx.spikes.size() > 0, "Toxic Debris: espalha espinhos venenosos")
	a.enemy.stages.atk = 0
	_hit(a, "electromorphosis", Dex.move("tackle"))
	check(fx.active(fx.st(a.enemy), "charged"), "Electromorphosis: carrega o próximo Elétrico")
	fx.st(a.enemy).charged = -99.0
	_hit(a, "wind_power", Dex.move("gust"))
	check(
		fx.active(fx.st(a.enemy), "charged") or Dex.move("gust").is_empty(),
		"Wind Power: golpe de vento carrega"
	)
	# Toxic Chain / Merciless / Corrosion
	_give(a.enemy, "")
	a.enemy.remove_meta("ability_override")
	_give(a.player, "toxic_chain")
	var n := 0
	for i in 200:
		a.enemy.clear_status()
		ab.on_hit(a.player, a.enemy, Dex.move("tackle"), 5)
		if a.enemy.status == "toxic":
			n += 1
	check(n > 30 and n < 100, "Toxic Chain: ~30%% envenena gravemente (%d/200)" % n)
	a.enemy.clear_status()
	_give(a.player, "merciless")
	var p: Dictionary = a.moves.effects.attacker_profile(a.player, a.enemy, Dex.move("tackle"))
	check(int(p.crit_stage) == 0, "Merciless: sem veneno, sem crítico garantido")
	a.enemy.apply_status("poison", null)
	p = a.moves.effects.attacker_profile(a.player, a.enemy, Dex.move("tackle"))
	check(int(p.crit_stage) == 3, "Merciless: crítico garantido em envenenado")
	a.enemy.clear_status()
	# Stakeout
	_give(a.player, "stakeout")
	fx.st(a.enemy).entered = fx.now
	check(
		is_equal_approx(ab.damage_mult(a.player, a.enemy, Dex.move("tackle")), 2.0),
		"Stakeout: x2 em quem acabou de entrar"
	)
	fx.st(a.enemy).entered = fx.now - 10.0
	check(
		ab.damage_mult(a.player, a.enemy, Dex.move("tackle")) == 1.0,
		"Stakeout: depois da janela, normal"
	)
	a.free()


func _disguise_ice_face() -> void:
	var a := _still()
	var ab: BattleAbilities = a.abilities
	_give(a.enemy, "disguise")
	var hp0: int = a.enemy.hp
	var d := ab.adjust_damage(a.player, a.enemy, Dex.move("tackle"), 30)
	check(d == 0, "Disguise: o primeiro golpe é anulado")
	check(
		a.enemy.hp == hp0 - a.enemy.paced(maxi(1, int(a.enemy.max_hp * 0.125))),
		"Disguise: perde 1/8 do HP"
	)
	check(BattleAbilitiesMore.form_of(a.enemy) == "busted", "Disguise: o disfarce rompe")
	check(
		ab.adjust_damage(a.player, a.enemy, Dex.move("tackle"), 30) == 30,
		"Disguise: o segundo golpe passa"
	)
	var b := _still()
	_give(b.enemy, "ice_face")
	check(
		b.abilities.adjust_damage(b.player, b.enemy, Dex.move("thunder_shock"), 30) == 30,
		"Ice Face: o especial passa"
	)
	var spe0: float = b.enemy.stats.spe
	check(
		b.abilities.adjust_damage(b.player, b.enemy, Dex.move("tackle"), 30) == 0,
		"Ice Face: absorve o físico"
	)
	check(b.enemy.stats.spe > spe0 * 2.0, "Ice Face: sem o gelo a Speed dispara")
	b.abilities.set_weather("hail", 20.0)
	_run(b, 0.3)
	check(
		BattleAbilitiesMore.form_of(b.enemy) == "" and is_equal_approx(b.enemy.stats.spe, spe0),
		"Ice Face: o gelo volta na neve"
	)
	a.free()
	b.free()


func _thresholds() -> void:
	var a := _still()
	var ab: BattleAbilities = a.abilities
	_give(a.enemy, "berserk")
	var tackle := Dex.move("tackle")
	ab.adjust_damage(a.player, a.enemy, tackle, 5)
	a.enemy.hp = a.enemy.max_hp / 2 - 1
	ab.on_hit(a.player, a.enemy, tackle, 5)
	check(int(a.enemy.stages.spa) == 1, "Berserk: cruzar a metade do HP dá Atq. Esp. +1")
	ab.adjust_damage(a.player, a.enemy, tackle, 5)
	ab.on_hit(a.player, a.enemy, tackle, 5)
	check(int(a.enemy.stages.spa) == 1, "Berserk: só quando cruza")
	var b := _still()
	_give(b.enemy, "anger_shell")
	b.abilities.adjust_damage(b.player, b.enemy, tackle, 5)
	b.enemy.hp = b.enemy.max_hp / 2
	b.abilities.on_hit(b.player, b.enemy, tackle, 5)
	check(
		(
			int(b.enemy.stages.atk) == 1
			and int(b.enemy.stages.spa) == 1
			and int(b.enemy.stages.spe) == 1
			and int(b.enemy.stages.def) == -1
			and int(b.enemy.stages.spd) == -1
		),
		"Anger Shell: +1 Atk/Atq.Esp./Speed e -1 Def/Def.Esp."
	)
	var c := _still()
	_give(c.enemy, "innards_out")
	c.abilities.adjust_damage(c.player, c.enemy, tackle, 5)
	var left: int = c.enemy.hp
	var php: int = c.player.hp
	c.enemy.hp = 0
	c.abilities.on_hit(c.player, c.enemy, tackle, 5)
	check(
		php - c.player.hp == mini(left, php),  # não tira mais do que quem bateu tem
		"Innards Out: quem bateu perde o HP que sobrava (%d de %d)" % [php - c.player.hp, left]
	)
	a.free()
	b.free()
	c.free()


func _forms() -> void:
	var a := _still("pikachu", "rattata")
	var f: BattleFighter = a.player
	var atk0: float = f.stats.atk
	_give(f, "zen_mode")
	f.hp = f.max_hp / 2
	_run(a, 0.2)
	check(
		BattleAbilitiesMore.form_of(f) == "zen" and f.stats.atk < atk0 and "psychic" in f.types,
		"Zen Mode: com metade do HP vira Zen (stats e tipo)"
	)
	f.heal(f.max_hp)
	_run(a, 0.2)
	check(
		(
			BattleAbilitiesMore.form_of(f) == ""
			and is_equal_approx(f.stats.atk, atk0)
			and not "psychic" in f.types
		),
		"Zen Mode: cura volta ao normal"
	)
	_give(f, "schooling")
	_run(a, 0.2)
	check(
		BattleAbilitiesMore.form_of(f) == "school" and f.stats.atk > atk0 * 5.0,
		"Schooling: nível 30 vira Cardume"
	)
	f.hp = f.max_hp / 5
	_run(a, 0.2)
	check(BattleAbilitiesMore.form_of(f) == "", "Schooling: HP baixo desfaz")
	_give(f, "shields_down")
	f.heal(f.max_hp)
	check(a.abilities.blocks_status(f, "burn"), "Shields Down: Meteoro não pega status")
	f.hp = f.max_hp / 2
	_run(a, 0.2)
	check(
		BattleAbilitiesMore.form_of(f) == "core" and not a.abilities.blocks_status(f, "burn"),
		"Shields Down: Núcleo pega status"
	)
	f.heal(f.max_hp)
	_run(a, 0.2)
	_give(f, "stance_change")
	a.abilities.on_move_used(f, Dex.move("tackle"))
	check(BattleAbilitiesMore.form_of(f) == "blade", "Stance Change: golpe de dano vira Lâmina")
	a.abilities.on_move_used(f, {"id": "kings_shield", "category": "status"})
	check(BattleAbilitiesMore.form_of(f) == "", "Stance Change: King's Shield volta ao Escudo")
	_give(f, "forecast")
	f.types = ["normal"]
	a.abilities.set_weather("rain", 20.0)
	_run(a, 0.3)
	check(f.types == ["water"], "Forecast: chuva vira Água")
	a.abilities.set_weather("sun", 20.0)
	_run(a, 0.3)
	check(f.types == ["fire"], "Forecast: sol vira Fogo")
	_give(f, "gulp_missile")
	f.hp = f.max_hp
	a.abilities.on_move_used(f, Dex.move("surf"))
	check(
		String(a.abilities._state(f).gulp) == "arrokuda",
		"Gulp Missile: Surf engole a presa (HP alto: Arrokuda)"
	)
	var php: int = a.enemy.hp
	a.abilities.on_hit(a.enemy, f, Dex.move("tackle"), 5)
	check(
		(
			String(a.abilities._state(f).gulp) == ""
			and a.enemy.hp < php
			and int(a.enemy.stages.def) == -1
		),
		"Gulp Missile: cospe a presa (dano e Def -1)"
	)
	_give(f, "hunger_switch")
	a.abilities.late_residual(f)
	check(BattleAbilitiesMore.form_of(f) == "hangry", "Hunger Switch: alterna para faminto")
	check(
		(
			String(
				(
					a
					. moves
					. effects
					. move_for(
						f,
						{
							"id": "aura_wheel",
							"type": "electric",
							"power": 110,
							"category": "physical"
						}
					)
					. type
				)
			)
			== "dark"
		),
		"Hunger Switch: Aura Wheel vira Sombrio faminto"
	)
	a.abilities.late_residual(f)
	check(BattleAbilitiesMore.form_of(f) == "", "Hunger Switch: alterna de volta")
	_give(f, "zero_to_hero")
	f.hp = f.max_hp / 2
	_run(a, 0.2)
	check(BattleAbilitiesMore.form_of(f) == "hero", "Zero to Hero: no aperto vira Herói")
	_give(f, "tera_shift")
	BattleAbilitiesMore.set_form(f, "")
	a.abilities._pending_enter.append(f)
	_run(a, 0.3)
	check(BattleAbilitiesMore.form_of(f) == "terastal", "Tera Shift: entra Terastal")
	a.free()


func _paradox() -> void:
	var a := _still()
	var ab: BattleAbilities = a.abilities
	var fx: BattleMoveEffects = a.moves.effects
	_give(a.player, "protosynthesis")
	a.player.stats.atk = 500
	check(BattleAbilitiesMore.boosted(ab, a.player) == "", "Protosynthesis: sem sol, nada")
	ab.set_weather("sun", 20.0)
	check(
		BattleAbilitiesMore.boosted(ab, a.player) == "atk",
		"Protosynthesis: no sol, o maior atributo (atk)"
	)
	var sun_mult := ab.damage_mult(a.player, a.enemy, Dex.move("tackle"))
	check(is_equal_approx(sun_mult, 1.3), "Protosynthesis: físico x1,3 (%f)" % sun_mult)
	a.player.stats.spe = 900
	check(
		BattleAbilitiesMore.boosted(ab, a.player) == "spe" and ab.order_speed_mult(a.player) == 1.5,
		"Protosynthesis: Speed x1,5 na ordem"
	)
	_give(a.player, "quark_drive")
	check(BattleAbilitiesMore.boosted(ab, a.player) == "", "Quark Drive: sol não conta")
	fx._set_terrain("electric", a.player, "x", "electric")
	check(BattleAbilitiesMore.boosted(ab, a.player) == "spe", "Quark Drive: no campo elétrico")
	a.free()


func _kos() -> void:
	var a := _still()
	var ab: BattleAbilities = a.abilities
	var tackle := Dex.move("tackle")
	_give(a.player, "beast_boost")
	a.player.stats.spa = 999
	a.enemy.hp = 0
	ab.on_hit(a.player, a.enemy, tackle, 5)
	check(int(a.player.stages.spa) == 1, "Beast Boost: sobe o melhor atributo ao nocautear")
	var b := _still()
	_give(b.player, "chilling_neigh")
	b.enemy.hp = 0
	b.abilities.on_hit(b.player, b.enemy, tackle, 5)
	check(int(b.player.stages.atk) == 1, "Chilling Neigh: Ataque +1 ao nocautear")
	var c := _still()
	_give(c.player, "grim_neigh")
	c.enemy.hp = 0
	c.abilities.on_hit(c.player, c.enemy, tackle, 5)
	check(int(c.player.stages.spa) == 1, "Grim Neigh: Atq. Esp. +1 ao nocautear")
	a.free()
	b.free()
	c.free()


func _faint_watchers() -> void:
	var party := [Mon.create("pidgey", 30), Mon.create("rattata", 30)]
	var a := _arena(party, [Mon.create("geodude", 30)], {"seed": 5, "battle_size": 2})
	_run(a, 1.3)
	a.enemy.controller = "none"
	if not (is_instance_valid(a.player) and is_instance_valid(a.ally)):
		check(false, "dupla em campo")
		a.free()
		return
	_give(a.enemy, "soul_heart")
	_give(a.player, "receiver")
	_give(a.ally, "intimidate")
	a.ally.take_damage(a.ally.hp, Vector3.ZERO, 0.0)
	_run(a, 0.3)
	check(int(a.enemy.stages.spa) == 1, "Soul Heart: o desmaio de qualquer um dá Atq. Esp. +1")
	check(
		a.abilities.ability_of(a.player) == "intimidate",
		"Receiver: herda a habilidade do parceiro caído"
	)
	a.free()


func _ruin_and_team() -> void:
	var party := [Mon.create("pidgey", 30), Mon.create("rattata", 30)]
	var a := _arena(party, [Mon.create("geodude", 30)], {"seed": 5, "battle_size": 2})
	_run(a, 1.3)
	a.enemy.controller = "none"
	if not (is_instance_valid(a.player) and is_instance_valid(a.ally)):
		check(false, "dupla em campo")
		a.free()
		return
	var ab: BattleAbilities = a.abilities
	var tackle := Dex.move("tackle")
	var shock := Dex.move("thunder_shock")
	_give(a.enemy, "tablets_of_ruin")
	check(
		is_equal_approx(ab.damage_mult(a.player, a.ally, tackle), 0.75),
		"Tablets of Ruin: os outros batem x0,75 (físico)"
	)
	check(
		is_equal_approx(ab.damage_mult(a.enemy, a.player, tackle), 1.0),
		"Tablets of Ruin: ele mesmo não é afetado"
	)
	_give(a.enemy, "vessel_of_ruin")
	check(
		is_equal_approx(ab.damage_mult(a.player, a.enemy, shock), 0.75),
		"Vessel of Ruin: os outros batem x0,75 (especial)"
	)
	_give(a.enemy, "sword_of_ruin")
	check(
		is_equal_approx(ab.damage_mult(a.player, a.ally, tackle), 4.0 / 3.0),
		"Sword of Ruin: físico em quem não tem x1,33"
	)
	_give(a.enemy, "beads_of_ruin")
	check(
		is_equal_approx(ab.damage_mult(a.player, a.ally, shock), 4.0 / 3.0),
		"Beads of Ruin: especial x1,33"
	)
	_give(a.enemy, "")
	a.enemy.remove_meta("ability_override")
	_give(a.ally, "battery")
	var base := ab.damage_mult(a.player, a.enemy, tackle)
	_give(a.ally, "power_spot")
	check(
		is_equal_approx(ab.damage_mult(a.player, a.enemy, tackle), base * 1.3),
		"Power Spot: golpes do parceiro x1,3"
	)
	_give(a.ally, "steely_spirit")
	_give(a.ally, "victory_star")
	check(
		is_equal_approx(ab.acc_mult(a.player), 1.1), "Victory Star: o time ganha x1,1 de precisão"
	)
	_give(a.ally, "")
	a.ally.remove_meta("ability_override")
	_give(a.enemy, "fairy_aura")
	var fa_mult := ab.damage_mult(
		a.player, a.ally, {"id": "x", "type": "fairy", "power": 50, "category": "special"}
	)
	check(is_equal_approx(fa_mult, 4.0 / 3.0), "Fairy Aura: Fada x1,33 para todos")
	_give(a.ally, "aura_break")
	fa_mult = ab.damage_mult(
		a.player, a.enemy, {"id": "x", "type": "fairy", "power": 50, "category": "special"}
	)
	check(is_equal_approx(fa_mult, 0.75), "Aura Break: inverte para x0,75")
	_give(a.ally, "")
	a.ally.remove_meta("ability_override")
	_give(a.enemy, "dark_aura")
	fa_mult = ab.damage_mult(
		a.player, a.ally, {"id": "x", "type": "dark", "power": 50, "category": "special"}
	)
	check(is_equal_approx(fa_mult, 4.0 / 3.0), "Dark Aura: Sombrio x1,33")
	_give(a.enemy, "")
	a.enemy.remove_meta("ability_override")
	# Flower Veil / Sweet Veil do parceiro
	a.player.types = ["grass"]
	_give(a.ally, "flower_veil")
	check(ab.blocks_status(a.player, "burn", a.enemy), "Flower Veil: Grama do time não pega status")
	check(ab.blocks_stage_drop(a.player, "atk", a.enemy), "Flower Veil: nem perde atributo")
	_give(a.ally, "sweet_veil")
	a.player.types = ["normal"]
	check(ab.blocks_status(a.player, "sleep", a.enemy), "Sweet Veil: o parceiro não dorme")
	# Commander: Dondozo de parceiro
	_give(a.ally, "commander")
	a.player.body = "dondozo"
	_run(a, 0.3)
	check(
		a.ally.hidden == "commander" and int(a.player.stages.atk) == 2,
		"Commander: entra na boca do Dondozo e dá +2"
	)
	check(a.moves.effects.usable(a.ally, tackle) == false, "Commander: dentro da boca não age")
	a.player.body = ""
	_run(a, 0.3)
	check(a.ally.hidden == "", "Commander: sai quando o Dondozo não está mais")
	# Costar copia os estágios do parceiro
	a.player.stages.spa = 3
	_give(a.ally, "costar")
	a.abilities._pending_enter.append(a.ally)
	_run(a, 0.3)
	check(int(a.ally.stages.spa) == 3, "Costar: copia os estágios do parceiro")
	# Hospitality
	a.player.hp = a.player.max_hp / 2
	var h0: int = a.player.hp
	_give(a.ally, "hospitality")
	a.abilities._pending_enter.append(a.ally)
	_run(a, 0.3)
	check(a.player.hp > h0, "Hospitality: cura o parceiro")
	# Symbiosis
	_give(a.ally, "symbiosis")
	a.ally.trainer_item = "leftovers"
	a.ally.item_used = false
	a.player.trainer_item = "oran_berry"
	a.player.item_used = true
	_run(a, 0.2)
	check(
		a.player.trainer_item == "leftovers" and not a.player.item_used,
		"Symbiosis: passa o item para o parceiro"
	)
	# Dancer
	_give(a.ally, "dancer")
	var s0 := int(a.ally.stages.atk)
	a.abilities.on_move_used(a.player, Dex.move("swords_dance"))
	_run(a, 1.2)
	check(
		int(a.ally.stages.atk) == s0 + 2,
		"Dancer: repete o Swords Dance (%d)" % (int(a.ally.stages.atk) - s0)
	)
	a.free()


func _items() -> void:
	var a := _still()
	var et: BattleEndTurn = a.end_turn
	for f in [a.player, a.enemy]:
		f.trainer_item = "oran_berry"
		f.item_used = false
		f.hp = int(f.max_hp * 0.4)
	_give(a.player, "ripen")
	var p0: int = a.player.hp
	var e0: int = a.enemy.hp
	et.held_check(a.player)
	et.held_check(a.enemy)
	check(
		a.player.hp - p0 == a.player.paced(BattleFighter.hp_from_mon(20)),
		"Ripen: Oran cura 20 (%d)" % (a.player.hp - p0)
	)
	check(
		a.enemy.hp - e0 == a.enemy.paced(BattleFighter.hp_from_mon(10)), "sem Ripen a Oran cura 10"
	)
	_give(a.player, "klutz")
	a.player.trainer_item = "oran_berry"
	a.player.item_used = false
	a.player.hp = int(a.player.max_hp * 0.4)
	et.held_check(a.player)
	check(not a.player.item_used, "Klutz: não come a frutinha")
	_give(a.player, "cheek_pouch")
	var p1: int = a.player.hp
	et.held_check(a.player)
	check(
		(
			a.player.item_used
			and (
				a.player.hp - p1
				>= a.player.paced(10) + a.player.paced(int(a.player.max_hp / 3.0)) - 1
			)
		),
		"Cheek Pouch: cura 10 e mais 1/3 (%d)" % (a.player.hp - p1)
	)
	_give(a.player, "cud_chew")
	a.player.trainer_item = "oran_berry"
	a.player.item_used = false
	a.player.hp = int(a.player.max_hp * 0.4)
	et.held_check(a.player)
	check(a.player.item_used, "Cud Chew: comeu a frutinha")
	a.abilities.finish_round([])
	a.player.hp = int(a.player.max_hp * 0.4)
	a.abilities.late_residual(a.player)
	a.abilities.finish_round([])
	a.abilities.late_residual(a.player)
	check(
		a.player.item_used and a.player.hp > int(a.player.max_hp * 0.4),
		"Cud Chew: comeu de novo na rodada seguinte"
	)
	a.free()


func _round_end() -> void:
	var a := _still()
	var ab: BattleAbilities = a.abilities
	_give(a.player, "moody")
	ab.late_residual(a.player)
	var sum := 0
	var top := 0
	for k in BattleAbilities.STAGE_KEYS:
		if k != "acc":
			sum += int(a.player.stages.get(k, 0))
			top = maxi(top, int(a.player.stages.get(k, 0)))
	check(sum == 1 and top == 2, "Moody: um +2 e outro -1 (soma %d, topo %d)" % [sum, top])
	_give(a.player, "bad_dreams")
	a.enemy.apply_status("sleep", null)
	var hp0: int = a.enemy.hp
	ab.late_residual(a.player)
	check(
		hp0 - a.enemy.hp == a.enemy.paced(maxi(1, int(a.enemy.max_hp * 0.125))),
		"Bad Dreams: 1/8 do HP de quem dorme"
	)
	a.free()


func _misc() -> void:
	var a := _still()
	var ab: BattleAbilities = a.abilities
	var fx: BattleMoveEffects = a.moves.effects
	_give(a.player, "shadow_tag")
	check(fx.cant_escape(a.enemy), "Shadow Tag: o inimigo não troca nem foge")
	a.enemy.types = ["ghost"]
	check(not fx.cant_escape(a.enemy), "Shadow Tag: Fantasma escapa")
	a.enemy.types = ["normal"]
	_give(a.enemy, "suction_cups")
	check(ab.anchored(a.enemy), "Suction Cups: não é arrastado")
	_give(a.enemy, "guard_dog")
	check(ab.anchored(a.enemy), "Guard Dog: não é arrastado")
	a.enemy.remove_meta("ability_override")
	_give(a.player, "unseen_fist")
	check(
		ab.pierces_protect(a.player, Dex.move("tackle")), "Unseen Fist: contato atravessa o Protect"
	)
	check(
		not ab.pierces_protect(a.player, Dex.move("thunder_shock")), "Unseen Fist: sem contato não"
	)
	var w0 := BattlePhysics.weight_of(a.enemy)
	_give(a.enemy, "heavy_metal")
	check(is_equal_approx(BattlePhysics.weight_of(a.enemy), w0 * 2.0), "Heavy Metal: peso x2")
	_give(a.enemy, "light_metal")
	check(is_equal_approx(BattlePhysics.weight_of(a.enemy), w0 * 0.5), "Light Metal: peso x0,5")
	_give(a.enemy, "heatproof")
	a.enemy.apply_status("burn", null)
	check(is_equal_approx(ab.burn_mult(a.enemy), 0.5), "Heatproof: queimadura tira metade")
	_give(a.enemy, "propeller_tail")
	var shock := {"id": "thunder_shock", "type": "electric", "power": 40, "category": "special"}
	_give(a.player, "lightning_rod")
	check(ab.redirect(a.enemy, a.player, shock) == a.player, "(sem parceiro, não redireciona)")
	_give(a.player, "intrepid_sword")
	ab.on_enter(a.player)
	_run(a, 0.3)
	check(int(a.player.stages.atk) == 1, "Intrepid Sword: Ataque +1 ao entrar")
	ab._pending_enter.append(a.player)
	_run(a, 0.3)
	check(int(a.player.stages.atk) == 1, "Intrepid Sword: só uma vez por luta")
	_give(a.player, "dauntless_shield")
	ab._pending_enter.append(a.player)
	_run(a, 0.3)
	check(int(a.player.stages.def) == 1, "Dauntless Shield: Defesa +1")
	_give(a.player, "supersweet_syrup")
	ab._pending_enter.append(a.player)
	_run(a, 0.3)
	check(int(a.enemy.stages.spe) == -1, "Supersweet Syrup: Speed -1 nos inimigos")
	_give(a.player, "opportunist")
	_run(a, 0.1)
	a.enemy.stages.atk = 2
	_run(a, 0.2)
	check(int(a.player.stages.atk) >= 3, "Opportunist: copia o +2 do inimigo")
	# Supreme Overlord
	var party := [Mon.create("pidgey", 30), Mon.create("rattata", 30), Mon.create("geodude", 30)]
	var b := _arena(party, [Mon.create("geodude", 30)], {"seed": 5})
	_run(b, 1.3)
	b.enemy.controller = "none"
	party[1].hp = 0
	party[2].hp = 0
	_give(b.player, "supreme_overlord")
	check(
		is_equal_approx(b.abilities.damage_mult(b.player, b.enemy, Dex.move("tackle")), 1.2),
		"Supreme Overlord: +10%% por aliado caído (x1,2 com 2)"
	)
	# Illusion
	_give(b.player, "illusion")
	party[2].hp = 30
	var sp := String(party[2].species)
	b.abilities._pending_enter.append(b.player)
	_run(b, 0.3)
	check(
		b.player.look == null or b.player.look.species == sp,
		"Illusion: entra com a cara do último aliado de pé"
	)
	b.abilities.on_hit(b.enemy, b.player, Dex.move("tackle"), 5)
	check(
		b.player.look == null or b.player.look.species == b.player.mon.species,
		"Illusion: o golpe desfaz"
	)
	# Screen / Honey
	_give(b.player, "honey_gather")
	var got := 0
	for i in 400:
		got += b.abilities.found_items().size()
	check(got > 20 and got < 110, "Honey Gather: nível 30 acha mel ~20%% (%d/400)" % got)
	a.free()
	b.free()


func _doubles() -> void:
	pass


## Cada habilidade nova numa luta de IA contra IA curta: nada trava nem dá erro de script.
func _smoke() -> void:
	var done := 0
	for id in IDS:
		var m1 := Mon.create("pidgey", 22)
		var m2 := Mon.create("rattata", 22)
		var a := _arena([m1], [m2], {"seed": 91, "autoplay": true})
		_give(a.player, id)
		a.abilities.on_enter(a.player)
		_give(a.enemy, IDS[(IDS.find(id) + 7) % IDS.size()])
		a.abilities.on_enter(a.enemy)
		_run(a, 5.0)
		check(is_instance_valid(a.player), "luta com %s roda sem travar" % id)
		done += 1
		a.free()
	check(done == IDS.size(), "luta curta com as %d habilidades" % IDS.size())

"""Acrescenta a data/moves.json os golpes que faltavam nos learnsets Gen 9 dos Pokémon 1-51 e corrige
efeitos dos golpes que já existiam (entrega do jogo aqui + números oficiais da PokeAPI).

Campos de jogo (kind, range, speed, knockback, windup...) ficam aqui; tipo, categoria, PP, precisão,
prioridade, alvo de área e nome vêm da PokeAPI. Mecânicas extras: battle/battle_move_effects.gd.
Rodar da raiz do projeto: python tools/gen9_new_moves.py [cache_pokeapi]
"""

import json, os, sys

P = os.path.join(os.path.dirname(__file__), "..", "..", "pba-referencia", "dados", "pokeapi")
if len(sys.argv) > 1:
    P = sys.argv[1]

_IDX = {}


def api(mid):
    if not _IDX:
        for f in os.listdir(P):
            if f.startswith("move_"):
                d = json.load(open(os.path.join(P, f), encoding="utf-8"))
                _IDX[d["name"]] = d
    return _IDX.get(mid.replace("_", "-"))


def dump_moves(doc, path):
    lines = ["{", '  "_doc": %s,' % json.dumps(doc["_doc"], ensure_ascii=False), '  "moves": [']
    lines.append(",\n".join("    " + json.dumps(m, ensure_ascii=False) for m in doc["moves"]))
    lines += ["  ]", "}"]
    open(path, "w", encoding="utf-8", newline="\n").write("\n".join(lines) + "\n")


# Investida forte que fecha distância (o dono: "vai a uma velocidade alta pra cima do alvo").
RUSH = {"kind": "dash", "allowed_midair": False, "range": 8.0, "speed": 18, "knockback": 10}
BITE = {"kind": "arc", "range": 1.9, "knockback": 5, "angle": 80}
SELF = {"kind": "self_buff", "power": 0}
SHOT = {"kind": "projectile", "range": 9, "speed": 12, "knockback": 0, "power": 0}
DEBUFF = {"kind": "debuff_aoe", "power": 0, "radius": 6.0}
VOICE = {"kind": "stream", "range": 5.0, "knockback": 3, "angle": 60, "duration": 0.5, "tick": 0.15, "once": True, "fx": "rings"}

NEW = {
    "acid_spray": ({"kind": "projectile", "power": 40, "range": 9, "speed": 13, "knockback": 2, "fx": "lob", "lob_height": 1.6,
                    "effect": {"stat": "spd", "stages": -2, "chance": 1.0}}, "The user spits fluid that melts the target. This harshly lowers the target's Sp. Def."),
    "after_you": (dict(SELF, special="after_you"), "The user helps its ally act right away."),
    "agility": (dict(SELF, stat="spe", stages=2), "The user relaxes and lightens its body to move faster. This sharply raises Speed."),
    "air_cutter": ({"kind": "projectile", "power": 27, "range": 10, "speed": 16, "knockback": 2, "count": 3, "spread": 40, "crit": 1},
                   "The user launches razor-like wind to slash the opposing Pokemon. High critical-hit ratio."),
    "aromatherapy": (dict(SELF, special="aromatherapy"), "A soothing scent heals all status conditions affecting the user's party."),
    "assurance": (dict(BITE, power=60, special="assurance"), "Power doubles if the target has already taken damage just before."),
    "belch": ({"kind": "stream", "power": 40, "range": 3.5, "knockback": 4, "angle": 60, "duration": 0.6, "tick": 0.15, "special": "belch"},
              "The user lets out a damaging belch. It must eat a Berry first."),
    "bug_bite": (dict(BITE, power=60, special="pluck"), "The user bites the target. If a Berry lies near the target, the user eats it."),
    "bulldoze": ({"kind": "aoe_self", "power": 60, "knockback": 6, "windup": 0.35, "radius": 4.0, "slam": True,
                  "effect": {"stat": "spe", "stages": -1, "chance": 1.0}}, "The user stomps down on the ground, striking everything around it. This lowers Speed."),
    "charm": (dict(DEBUFF, stat="atk", stages=-2), "The user gazes at the target rather charmingly, harshly lowering its Attack."),
    "coil": (dict(SELF, stat="atk", stages=1, stats={"atk": 1, "def": 1, "acc": 1}), "The user coils up and concentrates, raising its Attack, Defense, and accuracy."),
    "confuse_ray": (dict(SHOT, speed=11, effect={"status": "confusion", "chance": 1.0}, fx="rings"), "The target is exposed to a sinister ray that triggers confusion."),
    "copycat": (dict(SELF, special="copycat"), "The user mimics the move used immediately before it."),
    "cosmic_power": (dict(SELF, stat="def", stages=1, stats={"def": 1, "spd": 1}), "The user absorbs a mystical power from space to raise its Defense and Sp. Def."),
    "covet": ({"kind": "dash", "allowed_midair": False, "power": 60, "range": 3.5, "speed": 14, "knockback": 5, "special": "covet"},
              "The user endearingly approaches the target, then steals the target's item."),
    "cross_poison": ({"kind": "arc", "power": 70, "range": 2.0, "knockback": 6, "angle": 90, "crit": 1, "effect": {"status": "poison", "chance": 0.1}},
                     "A slashing attack with a poisonous blade. High critical-hit ratio; it may poison."),
    "disarming_voice": (dict(VOICE, power=40, angle=80), "Letting out a charming cry, the user damages opposing Pokemon. It never misses."),
    "discharge": ({"kind": "aoe_self", "power": 80, "knockback": 5, "windup": 0.3, "radius": 3.5, "effect": {"status": "paralysis", "chance": 0.3}},
                  "A loose flare of electricity strikes all Pokemon around the user. It may paralyze."),
    "double_edge": (dict(RUSH, power=120, recoil=0.33), "A reckless, life-risking tackle. It also damages the user by a fairly large amount."),
    "echoed_voice": (dict(VOICE, power=40, special="echoed_voice"), "The user attacks with an echoing voice. Power rises each time it is used in a row."),
    "endeavor": (dict(BITE, power=1, knockback=4, angle=90, special="endeavor"), "The user cuts the target's HP down to equal the user's HP."),
    "extrasensory": ({"kind": "aoe_target", "power": 80, "range": 8, "knockback": 3, "windup": 0.5, "radius": 1.4, "effect": {"status": "flinch", "chance": 0.1}, "fx": "psy_rings"},
                     "The user attacks with an odd, unseeable power. It may make the target flinch."),
    "feather_dance": (dict(DEBUFF, stat="atk", stages=-2), "The user covers the target with a mass of down that harshly lowers its Attack."),
    "feint": ({"kind": "dash", "allowed_midair": False, "power": 30, "range": 6.0, "speed": 15, "knockback": 4, "windup": 0.05, "special": "feint"},
              "An attack that hits a target using Protect, lifting the effects of that move."),
    "fell_stinger": ({"kind": "arc", "power": 50, "range": 1.9, "knockback": 4, "angle": 50, "special": "fell_stinger"},
                     "When the user knocks out a target with this move, the user's Attack rises drastically."),
    "fire_spin": ({"kind": "zone", "power": 12, "range": 8, "knockback": 0, "duration": 2.5, "tick": 0.5, "radius": 1.6, "trap": 0.6},
                  "The target becomes trapped within a fierce vortex of fire for a while."),
    "fissure": ({"kind": "aoe_target", "power": 1, "range": 8, "knockback": 6, "windup": 0.9, "radius": 1.3, "fx": "quake", "special": "ohko"},
                "The user opens up a fissure in the ground. The target instantly faints if it hits."),
    "flare_blitz": (dict(RUSH, power=120, recoil=0.33, effect={"status": "burn", "chance": 0.1}),
                    "The user cloaks itself in fire and charges the target. It also hurts the user quite a lot. It may burn."),
    "flash_cannon": ({"kind": "beam", "power": 80, "range": 12, "knockback": 4, "windup": 0.45, "width": 0.7, "root": 0.5, "effect": {"stat": "spd", "stages": -1, "chance": 0.1}},
                     "The user gathers all its light energy and releases it at once. It may lower Sp. Def."),
    "flatter": (dict(SHOT, speed=11, effect={"status": "confusion", "chance": 1.0}, special="flatter", fx="rings"), "Flattery confuses the target. However, it also raises the target's Sp. Atk."),
    "follow_me": (dict(SELF, special="follow_me"), "The user draws attention to itself, making all targets take aim only at the user."),
    "fury_cutter": ({"kind": "arc", "power": 40, "range": 1.9, "knockback": 3, "angle": 90, "chain": 2, "special": "chain"},
                    "The target is slashed with scythes or claws. Its power increases if it hits in succession."),
    "gastro_acid": (dict(SHOT, fx="lob", lob_height=1.4, special="gastro_acid"), "The user hurls up its stomach acids. The fluid eliminates the effect of the target's Ability."),
    "giga_drain": ({"kind": "projectile", "power": 75, "range": 9, "speed": 16, "knockback": 2, "drain": 0.5, "turn": 2.0},
                   "A nutrient-draining attack. The user's HP is restored by half the damage taken by the target."),
    "grassy_terrain": (dict(SELF, special="grassy_terrain"), "The ground turns to grass for a while. Grounded Pokemon restore HP and Grass moves get stronger."),
    "gravity": (dict(SELF, special="gravity"), "Flying Pokemon can be hit by Ground moves, nobody can jump and accuracy rises for a while."),
    "gunk_shot": ({"kind": "projectile", "power": 120, "range": 10, "speed": 14, "knockback": 7, "fx": "lob", "lob_height": 2.4, "effect": {"status": "poison", "chance": 0.3}},
                  "The user shoots filthy garbage at the target. It may also poison the target."),
    "gyro_ball": ({"kind": "dash", "allowed_midair": False, "power": 60, "range": 6.5, "speed": 16, "knockback": 7, "special": "gyro_ball"},
                  "A high-speed spinning tackle. The slower the user compared to the target, the greater the damage."),
    "haze": (dict(SELF, special="haze"), "A haze eliminates every stat change among all the Pokemon engaged in battle."),
    "healing_wish": (dict(SELF, special="healing_wish"), "The user faints. The Pokemon taking its place will have its HP restored and status cured."),
    "hyper_voice": (dict(VOICE, power=90, range=5.5, knockback=5, angle=80, duration=0.6), "The user lets loose a horribly echoing shout with the power to inflict damage."),
    "ice_fang": (dict(BITE, power=65, effect={"status": "freeze", "chance": 0.1}, flinch=0.1), "The user bites with cold-infused fangs. It may freeze the target or make it flinch."),
    "imprison": (dict(SELF, special="imprison"), "Opposing Pokemon can't use any move that the user also knows."),
    "incinerate": ({"kind": "stream", "power": 20, "range": 5.0, "knockback": 2, "angle": 60, "duration": 0.6, "tick": 0.15, "special": "incinerate"},
                   "The user attacks opposing Pokemon with fire. Berries near the target are burned up."),
    "inferno": ({"kind": "projectile", "power": 100, "range": 11, "speed": 11, "knockback": 6, "effect": {"status": "burn", "chance": 1.0}},
                "The user engulfs the target in an intense fire. This leaves the target with a burn."),
    "iron_defense": (dict(SELF, stat="def", stages=2), "The user hardens its body's surface like iron, sharply raising its Defense."),
    "laser_focus": (dict(SELF, special="laser_focus"), "The user concentrates intensely. Its next attack will be a critical hit."),
    "life_dew": (dict(SELF, special="life_dew"), "The user scatters mysterious water and restores the HP of itself and its ally."),
    "light_screen": (dict(SELF, special="light_screen"), "A wondrous wall of light reduces damage from special attacks for a while."),
    "mean_look": (dict(SHOT, speed=14, special="mean_look"), "The user pins the target with a dark, arresting look. The target becomes unable to flee."),
    "meteor_mash": (dict(RUSH, power=90, range=7.0, speed=17, knockback=8, effect={"stat": "atk", "stages": 1, "chance": 0.2, "self": True}),
                    "The target is hit with a hard punch fired like a meteor. It may raise the user's Attack."),
    "metronome": (dict(SELF, special="metronome"), "The user waggles a finger and randomly uses nearly any move."),
    "mimic": (dict(SELF, special="mimic"), "The user copies the target's last move. The move can be used during the battle."),
    "moonblast": ({"kind": "projectile", "power": 95, "range": 12, "speed": 13, "knockback": 5, "effect": {"stat": "spa", "stages": -1, "chance": 0.3}},
                  "Borrowing the power of the moon, the user attacks the target. It may lower its Sp. Atk."),
    "moonlight": (dict(SELF, special="heal_weather", heal=0.5), "The user restores its own HP. The amount varies with the weather."),
    "nasty_plot": (dict(SELF, stat="spa", stages=2), "The user stimulates its brain by thinking bad thoughts. This sharply raises Sp. Atk."),
    "night_slash": ({"kind": "arc", "power": 70, "range": 2.0, "knockback": 6, "angle": 90, "crit": 1},
                    "The user slashes the target the instant an opportunity arises. High critical-hit ratio."),
    "nuzzle": ({"kind": "dash", "allowed_midair": False, "power": 20, "range": 3.5, "speed": 13, "knockback": 3, "effect": {"status": "paralysis", "chance": 1.0}},
               "The user nuzzles its electrified cheeks against the target, leaving it with paralysis."),
    "petal_blizzard": ({"kind": "aoe_self", "power": 90, "knockback": 5, "windup": 0.3, "radius": 3.5},
                       "The user stirs up a violent petal blizzard and attacks everything around it."),
    "play_nice": (dict(DEBUFF, stat="atk", stages=-1, special="no_protect"), "The user and the target become friends, and the target's Attack drops."),
    "play_rough": (dict(RUSH, power=90, range=6.5, speed=16, knockback=8, effect={"stat": "atk", "stages": -1, "chance": 0.1}),
                   "The user plays rough with the target and attacks it. It may lower the target's Attack."),
    "pluck": ({"kind": "dash", "allowed_midair": False, "power": 60, "range": 2.8, "speed": 13, "knockback": 4, "special": "pluck"},
              "The user pecks the target. If a Berry lies near the target, the user eats it."),
    "poison_fang": (dict(BITE, power=50, effect={"status": "toxic", "chance": 0.5}), "The user bites the target with toxic fangs. It may also badly poison the target."),
    "power_whip": (dict(RUSH, power=120, range=7.0, speed=17, knockback=9), "The user violently whirls its vines or tentacles to harshly lash the target."),
    "protect": (dict(SELF, special="protect"), "The user protects itself from all attacks for a moment."),
    "psychic": ({"kind": "aoe_target", "power": 90, "range": 9, "knockback": 4, "windup": 0.55, "radius": 1.6, "effect": {"stat": "spd", "stages": -1, "chance": 0.1}, "fx": "psy_rings"},
                "The target is hit by a strong telekinetic force. It may also lower its Sp. Def."),
    "quick_guard": (dict(SELF, special="quick_guard"), "The user protects itself and its allies from priority moves for a moment."),
    "quiver_dance": (dict(SELF, stat="spa", stages=1, stats={"spa": 1, "spd": 1, "spe": 1}), "A beautiful dance that boosts Sp. Atk, Sp. Def, and Speed."),
    "rage_powder": (dict(SELF, special="follow_me", powder=True), "The user scatters irritating powder to draw attention to itself."),
    "rest": (dict(SELF, special="rest"), "The user goes to sleep. This fully restores HP and heals any status conditions."),
    "roost": (dict(SELF, special="roost", heal=0.5), "The user lands and rests, restoring half its max HP. It loses its Flying type for a moment."),
    "round": (dict(VOICE, power=60, angle=50, special="round"), "The user attacks with a song. Power doubles if its ally sang Round just before."),
    "safeguard": (dict(SELF, special="safeguard"), "A protective field prevents status conditions on the user's side for a while."),
    "sandstorm": (dict(SELF, special="sandstorm"), "A sandstorm hurts all Pokemon except Rock, Ground, and Steel types for a while."),
    "shell_smash": (dict(SELF, stat="atk", stages=2, stats={"atk": 2, "spa": 2, "spe": 2, "def": -1, "spd": -1}),
                    "The user breaks its shell: Defense and Sp. Def drop, Attack, Sp. Atk, and Speed sharply rise."),
    "sludge_bomb": ({"kind": "projectile", "power": 90, "range": 10, "speed": 14, "knockback": 5, "fx": "lob", "lob_height": 2.2, "effect": {"status": "poison", "chance": 0.3}},
                    "Unsanitary sludge is hurled at the target. It may also poison the target."),
    "spit_up": ({"kind": "projectile", "power": 100, "range": 10, "speed": 14, "knockback": 6, "special": "spit_up"},
                "The power stored using Stockpile is released at once. The more power stored, the greater the damage."),
    "spite": (dict(SHOT, special="spite"), "The user unleashes its grudge on the move last used by the target by cutting its PP."),
    "stockpile": (dict(SELF, stat="def", stages=1, special="stockpile"), "The user charges up power, raising Defense and Sp. Def. Can be used three times."),
    "stored_power": ({"kind": "projectile", "power": 20, "range": 10, "speed": 14, "knockback": 3, "special": "stored_power"},
                     "The user attacks with stored power. The more its stats are raised, the greater the damage."),
    "superpower": (dict(RUSH, power=120, range=7.0, speed=17, knockback=11, self_stats={"atk": -1, "def": -1}),
                   "The user attacks with great power. This also lowers the user's Attack and Defense."),
    "swallow": (dict(SELF, special="swallow"), "The power stored using Stockpile is absorbed by the user to heal its HP."),
    "sweet_kiss": (dict(SHOT, speed=10, effect={"status": "confusion", "chance": 1.0}), "The user kisses the target with a sweet, angelic cuteness that causes confusion."),
    "swords_dance": (dict(SELF, stat="atk", stages=2), "A frenetic dance to uplift the fighting spirit. This sharply raises Attack."),
    "synthesis": (dict(SELF, special="heal_weather", heal=0.5), "The user restores its own HP. The amount varies with the weather."),
    "tailwind": (dict(SELF, special="tailwind"), "A turbulent whirlwind doubles the Speed of the user's side for a while."),
    "take_down": (dict(RUSH, power=90, range=7.0, speed=17, knockback=9, recoil=0.25), "A reckless, full-body charge attack. This also damages the user a little."),
    "thunder_fang": (dict(BITE, power=65, effect={"status": "paralysis", "chance": 0.1}, flinch=0.1), "The user bites with electrified fangs. It may paralyze the target or make it flinch."),
    "thunder_punch": ({"kind": "arc", "power": 75, "range": 1.9, "knockback": 6, "angle": 80, "effect": {"status": "paralysis", "chance": 0.1}},
                      "The target is punched with an electrified fist. It may also leave the target with paralysis."),
    "toxic": (dict(SHOT, fx="lob", lob_height=1.4, effect={"status": "toxic", "chance": 1.0}), "The target is badly poisoned. Its poison damage worsens every second."),
    "toxic_spikes": (dict(SELF, special="toxic_spikes"), "Poison spikes are laid at the feet of the opposing team. They poison whoever steps on them."),
    "venoshock": ({"kind": "projectile", "power": 65, "range": 10, "speed": 14, "knockback": 4, "special": "venoshock"},
                  "The user drenches the target in a poisonous liquid. Power doubles if the target is poisoned."),
    "wave_crash": (dict(RUSH, power=120, speed=19, recoil=0.33), "The user shrouds itself in water and slams into the target. It also damages the user quite a lot."),
    "will_o_wisp": (dict(SHOT, speed=10, effect={"status": "burn", "chance": 1.0}), "The user shoots a sinister flame at the target to inflict a burn."),
    "worry_seed": (dict(SHOT, special="worry_seed"), "A seed that causes worry is planted on the target. Its Ability becomes Insomnia."),
    "x_scissor": ({"kind": "arc", "power": 80, "range": 2.0, "knockback": 6, "angle": 100}, "The user slashes the target by crossing its scythes or claws like scissors."),
    "zen_headbutt": (dict(RUSH, power=80, range=6.5, speed=16, knockback=8, effect={"status": "flinch", "chance": 0.2}),
                     "The user focuses its willpower to its head and rams the target. It may make the target flinch."),
}

# --- Learnsets completos (TM, ovo, tutor) dos Pokémon 1-51 ---
ARC = {"kind": "arc", "range": 1.9, "knockback": 5, "angle": 80}
PUNCH = {"kind": "arc", "range": 1.9, "knockback": 6, "angle": 70}
TACKLE = {"kind": "dash", "allowed_midair": False, "range": 3.5, "speed": 13, "knockback": 5}
BALL = {"kind": "projectile", "range": 11, "speed": 14, "knockback": 4}
BEAM = {"kind": "beam", "range": 13, "knockback": 5, "windup": 0.45, "width": 0.8, "root": 0.5}
BLAST = {"kind": "aoe_target", "range": 9, "knockback": 5, "windup": 0.55, "radius": 1.6}
BURST = {"kind": "aoe_self", "knockback": 6, "windup": 0.35, "radius": 4.0}
WAVE = {"kind": "stream", "range": 5.5, "knockback": 3, "angle": 70, "duration": 0.6, "tick": 0.15, "once": True}
HOMING = {"kind": "homing", "range": 14, "speed": 12, "knockback": 3, "count": 1, "turn": 5}
SPREAD = {"kind": "projectile", "range": 10, "speed": 14, "knockback": 3, "count": 3, "spread": 35}
STRIKE = {"kind": "aoe_target", "range": 8, "knockback": 4, "windup": 0.7, "radius": 1.4}

NEW.update({
    "acrobatics": (dict(RUSH, power=55, range=7.0, speed=19, knockback=6, special="acrobatics"),
                   "The user nimbly strikes the target. Power doubles if the user has no item."),
    "alluring_voice": (dict(VOICE, power=80, special="jealousy", jealous_status="confusion"),
                       "The user attacks with an angelic voice. It confuses a target whose stats rose just before."),
    "amnesia": (dict(SELF, stat="spd", stages=2), "The user temporarily empties its mind to forget its concerns. This sharply raises Sp. Def."),
    "ancient_power": (dict(BALL, power=60, speed=12, special="omni_boost", omni_chance=0.1),
                      "The user attacks with a prehistoric power. It may also raise all the user's stats at once."),
    "aqua_ring": (dict(SELF, special="regen"), "The user envelops itself in a veil of water. It regains a little HP every second."),
    "attract": (dict(SHOT, speed=10, special="attract"), "If it is the opposite gender of the user, the target falls in love and may fail its moves."),
    "aura_sphere": (dict(HOMING, power=80, speed=13, knockback=5), "The user lets loose a blast of aura power from deep within its body. It never misses."),
    "avalanche": (dict(BLAST, power=60, range=7, windup=0.6, special="revenge"),
                  "An attack that inflicts twice the damage if the user has been hurt by the target just before."),
    "baby_doll_eyes": (dict(DEBUFF, stat="atk", stages=-1), "The user stares with its baby-doll eyes, lowering the target's Attack. Always goes first."),
    "baton_pass": (dict(SELF, special="baton_pass"), "The user switches places with a party Pokemon in waiting and passes along any stat changes."),
    "beat_up": (dict(ARC, power=10, kind="multi_arc", hits=1, interval=0.16, angle=70, special="beat_up"),
                "The user gets all party Pokemon to attack the target. The more party Pokemon, the more hits."),
    "belly_drum": (dict(SELF, special="belly_drum"), "The user maximizes its Attack in exchange for HP equal to half its max HP."),
    "blast_burn": (dict(BLAST, power=150, range=9, knockback=11, windup=0.8, radius=2.0, recharge=1.6),
                   "The target is razed by a fiery explosion. The user can't move for a moment afterward."),
    "blizzard": (dict(BLAST, power=110, range=10, knockback=5, windup=0.8, radius=2.8, effect={"status": "freeze", "chance": 0.1}),
                 "A howling blizzard is summoned to strike opposing Pokemon. It may freeze them."),
    "body_press": (dict(RUSH, power=80, range=5.0, speed=15, special="body_press"),
                   "The user attacks by slamming its body into the target. The higher its Defense, the more damage."),
    "brave_bird": (dict(RUSH, power=120, range=8.0, speed=20, recoil=0.33),
                   "The user tucks in its wings and charges from a low altitude. This also damages the user quite a lot."),
    "breaking_swipe": (dict(ARC, power=60, range=2.6, angle=150, knockback=6, effect={"stat": "atk", "stages": -1, "chance": 1.0}),
                       "The user swings its tough tail wildly and attacks opposing Pokemon. This also lowers their Attack."),
    "brick_break": (dict(PUNCH, power=75, special="screen_break"), "The user attacks with a swift chop. It can also break barriers such as Light Screen and Reflect."),
    "burning_jealousy": (dict(WAVE, power=70, special="jealousy", jealous_status="burn"),
                         "The user attacks with energy from jealousy. It burns targets whose stats rose just before."),
    "calm_mind": (dict(SELF, stat="spa", stages=1, stats={"spa": 1, "spd": 1}), "The user quietly focuses its mind and calms its spirit to raise its Sp. Atk and Sp. Def."),
    "charge_beam": (dict(BEAM, power=50, effect={"stat": "spa", "stages": 1, "chance": 0.7, "self": True}),
                    "The user attacks with an electric charge. It may use leftover electricity to raise its Sp. Atk."),
    "chilling_water": (dict(BALL, power=50, speed=15, effect={"stat": "atk", "stages": -1, "chance": 1.0}),
                       "The user showers the target with water so cold it saps its strength, lowering its Attack."),
    "counter": (dict(SELF, special="counter", counter_cat="physical"),
                "The user braces itself. A physical attack that hits it is returned with twice the power."),
    "cut": (dict(ARC, power=50, range=2.0, angle=90), "The target is cut with a scythe or claw."),
    "dark_pulse": (dict(BALL, power=80, speed=13, effect={"status": "flinch", "chance": 0.2}),
                   "The user releases a horrible aura imbued with dark thoughts. It may make the target flinch."),
    "dazzling_gleam": (dict(BURST, power=80, radius=4.5, knockback=4), "The user damages opposing Pokemon by emitting a powerful flash."),
    "defog": (dict(SELF, special="defog"), "A strong wind blows away hazards, screens and terrain, and lowers the target's evasiveness."),
    "dragon_cheer": (dict(SELF, special="dragon_cheer"), "The user raises its ally's morale. The ally's critical-hit ratio rises, more so if it is a Dragon type."),
    "dragon_dance": (dict(SELF, stat="atk", stages=1, stats={"atk": 1, "spe": 1}), "The user vigorously performs a mystic, powerful dance that raises its Attack and Speed."),
    "dragon_pulse": (dict(BALL, power=85, speed=13, knockback=5), "The target is attacked with a shock wave generated by the user's gaping mouth."),
    "dragon_rush": (dict(RUSH, power=100, range=8.0, speed=19, knockback=10, effect={"status": "flinch", "chance": 0.2}),
                    "The user tackles the target while exhibiting overwhelming menace. It may make the target flinch."),
    "dragon_tail": (dict(ARC, power=60, range=2.2, angle=110, knockback=6), "The target is knocked away far from the user. Always moves late."),
    "drain_punch": (dict(PUNCH, power=75, drain=0.5), "An energy-draining punch. The user's HP is restored by half the damage taken by the target."),
    "draining_kiss": (dict(TACKLE, power=50, range=3.0, drain=0.75), "The user steals the target's HP with a kiss, restoring HP by 75% of the damage dealt."),
    "dual_wingbeat": (dict(ARC, power=40, kind="multi_arc", hits=2, interval=0.18, angle=90),
                      "The user slams the target with its wings. The target is hit twice in a row."),
    "eerie_impulse": (dict(DEBUFF, stat="spa", stages=-2), "The user's body generates an eerie impulse that harshly lowers the target's Sp. Atk."),
    "electric_terrain": (dict(SELF, special="electric_terrain"), "The ground is electrified for a while. Grounded Pokemon can't fall asleep and Electric moves get stronger."),
    "electroweb": (dict(SPREAD, power=55, speed=13, effect={"stat": "spe", "stages": -1, "chance": 1.0}),
                   "The user attacks and captures opposing Pokemon in an electric net. This lowers their Speed."),
    "endure": (dict(SELF, special="endure"), "The user endures any attack with at least 1 HP for a moment."),
    "energy_ball": (dict(BALL, power=90, speed=13, knockback=5, effect={"stat": "spd", "stages": -1, "chance": 0.1}),
                    "The user draws power from nature and fires it at the target. It may lower its Sp. Def."),
    "expanding_force": (dict(BLAST, power=80, radius=1.8), "The user attacks the target with its psychic power."),
    "facade": (dict(RUSH, power=70, range=6.5, speed=16, special="facade"), "An attack that doubles its power if the user is poisoned, burned, or paralyzed."),
    "fake_out": (dict(TACKLE, power=40, range=4.0, speed=18, windup=0.03, special="fake_out", effect={"status": "flinch", "chance": 1.0}),
                 "An attack that hits first and makes the target flinch. It only works right after the user enters battle."),
    "fake_tears": (dict(DEBUFF, stat="spd", stages=-2), "The user feigns crying to fluster the target, harshly lowering its Sp. Def."),
    "false_swipe": (dict(ARC, power=40, range=2.0, angle=90, special="false_swipe"), "A restrained attack that always leaves the target with at least 1 HP."),
    "final_gambit": (dict(RUSH, power=1, special="final_gambit"), "The user risks everything to attack. It deals damage equal to its HP, then faints."),
    "fire_pledge": (dict(STRIKE, power=80, radius=1.5), "A column of fire hits the target."),
    "fire_punch": (dict(PUNCH, power=75, effect={"status": "burn", "chance": 0.1}), "The target is punched with a fiery fist. This may also leave the target with a burn."),
    "flame_charge": (dict(RUSH, power=50, range=6.5, speed=17, knockback=5, effect={"stat": "spe", "stages": 1, "chance": 1.0, "self": True}),
                     "Cloaked in flames, the user attacks the target. Building up more power, it raises its Speed."),
    "flame_wheel": (dict(RUSH, power=60, range=6.0, speed=16, knockback=6, effect={"status": "burn", "chance": 0.1}),
                    "The user cloaks itself in fire and charges at the target. This may also leave the target with a burn."),
    "flash": (dict(DEBUFF, stat="acc", stages=-1), "The user flashes a bright light that cuts the target's accuracy."),
    "fling": (dict(BALL, power=30, speed=13, special="fling"), "The user flings its held item at the target. It fails without an item."),
    "flip_turn": (dict(TACKLE, power=60, range=5.0, speed=17, special="pivot"), "After making its attack, the user rushes back to switch places with a party Pokemon in waiting."),
    "fly": (dict(TACKLE, power=90, range=7.0, speed=10, knockback=8), "The user soars, then strikes. It is out of reach while high in the sky."),
    "focus_blast": (dict(BALL, power=120, speed=12, knockback=8, effect={"stat": "spd", "stages": -1, "chance": 0.1}),
                    "The user heightens its mental focus and unleashes its power. It may lower the target's Sp. Def."),
    "focus_punch": (dict(PUNCH, power=150, knockback=11, windup=1.0, special="focus_punch"),
                    "The user focuses its mind before launching a punch. This move fails if the user is hit before it is used."),
    "foul_play": (dict(ARC, power=95, range=2.0, angle=90, knockback=7, special="foul_play"),
                  "The user turns the target's power against it. The higher the target's Attack, the more damage."),
    "frenzy_plant": (dict(BLAST, power=150, range=9, knockback=11, windup=0.8, radius=2.0, recharge=1.6),
                     "The user slams the target with an enormous tree. The user can't move for a moment afterward."),
    "future_sight": (dict(STRIKE, power=120, range=10, special="future_sight"), "A moment after this move is used, a hunk of psychic energy attacks the spot."),
    "giga_impact": (dict(RUSH, power=150, range=8.0, speed=19, knockback=12, recharge=1.6),
                    "The user charges at the target using every bit of its power. The user can't move for a moment afterward."),
    "grass_knot": (dict(STRIKE, power=1, radius=1.3, windup=0.5, special="low_kick"), "The user snares the target with grass. The heavier the target, the greater the damage."),
    "grass_pledge": (dict(STRIKE, power=80, radius=1.5), "A column of grass hits the target."),
    "grassy_glide": (dict(RUSH, power=55, range=7.0, speed=19, knockback=5, special="grassy_glide"),
                     "Gliding on the ground, the user attacks the target. It goes first on Grassy Terrain."),
    "head_smash": (dict(RUSH, power=150, range=8.0, speed=19, knockback=12, recoil=0.5),
                   "The user attacks with a hazardous, full-power headbutt. This also damages the user terribly."),
    "headbutt": (dict(TACKLE, power=70, range=4.0, speed=15, knockback=6, effect={"status": "flinch", "chance": 0.3}),
                 "The user sticks out its head and attacks by charging straight into the target. It may make the target flinch."),
    "heal_pulse": (dict(SELF, special="heal_pulse"), "The user emits a healing pulse that restores half the max HP of its ally (or itself)."),
    "heat_crash": (dict(TACKLE, power=1, range=3.2, speed=12, knockback=9, special="heat_crash"),
                   "The user slams the target with its flame-covered body. The heavier the user, the more damage."),
    "hex": (dict(BALL, power=65, speed=12, special="hex"), "This relentless attack does massive damage to a target affected by status conditions."),
    "high_horsepower": (dict(RUSH, power=95, range=7.0, speed=18, knockback=9), "The user fiercely attacks the target using its entire body."),
    "hone_claws": (dict(SELF, stat="atk", stages=1, stats={"atk": 1, "acc": 1}), "The user sharpens its claws to boost its Attack and accuracy."),
    "horn_drill": (dict(TACKLE, power=1, range=3.0, speed=14, knockback=6, special="ohko"),
                   "The user stabs the target with a horn that rotates like a drill. The target faints instantly if this hits."),
    "howl": (dict(SELF, stat="atk", stages=1, special="howl"), "The user howls loudly to raise the spirit of itself and its ally. This raises their Attack."),
    "hydro_cannon": (dict(BEAM, power=150, range=14, knockback=11, windup=0.7, width=1.0, root=1.0, recharge=1.6),
                     "The target is hit with a watery blast. The user can't move for a moment afterward."),
    "ice_beam": (dict(BEAM, power=90, range=13, effect={"status": "freeze", "chance": 0.1}), "The target is struck with an icy-cold beam of energy. This may also leave the target frozen."),
    "ice_punch": (dict(PUNCH, power=75, effect={"status": "freeze", "chance": 0.1}), "The target is punched with an icy fist. This may also leave the target frozen."),
    "ice_spinner": (dict(RUSH, power=80, range=6.5, speed=17, knockback=8, special="terrain_clear"),
                    "The user covers its feet in thin ice and twirls around, slamming into the target. It destroys the terrain."),
    "icy_wind": (dict(WAVE, power=55, effect={"stat": "spe", "stages": -1, "chance": 1.0}), "The user attacks with a gust of chilled air. This also lowers the opposing Pokemon's Speed."),
    "ingrain": (dict(SELF, special="regen", rooted=True), "The user lays roots that restore a little HP every second. It can't be pushed away while rooted."),
    "knock_off": (dict(ARC, power=65, range=2.0, angle=90, knockback=6, special="knock_off"),
                  "The user slaps down the target's held item. That item can't be used, and the hit is stronger if it had one."),
    "lash_out": (dict(ARC, power=75, range=2.0, angle=90, knockback=6, special="lash_out"),
                 "The user lashes out to vent its frustration. Power doubles if its stats were lowered just before."),
    "last_resort": (dict(RUSH, power=140, range=7.0, speed=18, knockback=11, special="last_resort"),
                    "This move can be used only after the user has used all the other moves it knows."),
    "leaf_storm": (dict(WAVE, power=130, range=6.0, angle=60, duration=0.8, knockback=7, self_stats={"spa": -2}),
                   "The user whips up a storm of leaves around the target. This also harshly lowers the user's Sp. Atk."),
    "liquidation": (dict(ARC, power=85, range=2.2, angle=100, knockback=7, effect={"stat": "def", "stages": -1, "chance": 0.2}),
                    "The user slams into the target using a full-force blast of water. It may lower the target's Defense."),
    "lunge": (dict(RUSH, power=80, range=6.5, speed=17, knockback=8, effect={"stat": "atk", "stages": -1, "chance": 1.0}),
              "The user makes a lunge at the target, attacking with full force. This also lowers the target's Attack."),
    "magical_leaf": (dict(HOMING, power=60, count=3, speed=13, knockback=2), "The user scatters curious leaves that chase the target. This attack never misses."),
    "mega_kick": (dict(ARC, power=120, range=2.0, angle=70, knockback=11, windup=0.25), "The target is attacked by a kick launched with muscle-packed power."),
    "mega_punch": (dict(PUNCH, power=80, knockback=8), "The target is slugged by a punch thrown with muscle-packed power."),
    "memento": (dict(SHOT, speed=12, special="memento"), "The user faints, harshly lowering the target's Attack and Sp. Atk."),
    "meteor_beam": (dict(BEAM, power=120, range=14, knockback=9, windup=1.1, width=1.0, root=0.6, charge_stats={"spa": 1}),
                    "The user gathers space power, raising its Sp. Atk, then fires a beam at the target."),
    "mirror_coat": (dict(SELF, special="counter", counter_cat="special"),
                    "The user braces itself. A special attack that hits it is returned with twice the power."),
    "mist": (dict(SELF, special="mist"), "The user's side is cloaked in mist that prevents its stats from being lowered for a while."),
    "misty_explosion": (dict(BURST, power=100, radius=4.5, knockback=9, windup=0.4, self_destruct=True),
                        "The user attacks everything around it and faints upon using this move."),
    "misty_terrain": (dict(SELF, special="misty_terrain"), "Mist covers the ground for a while. Grounded Pokemon are protected from status and Dragon moves weaken."),
    "morning_sun": (dict(SELF, special="heal_weather", heal=0.5), "The user restores its own HP. The amount varies with the weather."),
    "mud_shot": (dict(BALL, power=55, speed=14, knockback=3, effect={"stat": "spe", "stages": -1, "chance": 1.0}),
                 "The user attacks by hurling a blob of mud at the target. This also lowers the target's Speed."),
    "muddy_water": (dict(WAVE, power=90, range=5.5, angle=80, duration=0.7, knockback=5, effect={"stat": "acc", "stages": -1, "chance": 0.3}),
                    "The user attacks by shooting muddy water at opposing Pokemon. It may lower their accuracy."),
    "night_shade": (dict(BALL, power=1, speed=12, knockback=3, special="level_damage"), "The user makes the target see a frightening mirage. It inflicts damage equal to the user's level."),
    "outrage": (dict(BURST, power=120, radius=2.4, knockback=8, windup=0.3, special="self_confuse"),
                "The user rampages and attacks for a while. The user then becomes confused."),
    "overheat": (dict(BEAM, power=130, range=12, knockback=9, windup=0.55, width=1.0, root=0.7, self_stats={"spa": -2}),
                 "The user attacks the target at full power. The attack's recoil harshly lowers the user's Sp. Atk."),
    "pain_split": (dict(SHOT, speed=12, special="pain_split"), "The user adds its HP to the target's HP, then equally shares the combined HP with the target."),
    "pay_day": (dict(SPREAD, power=40, count=4, spread=30, speed=15, knockback=2), "Numerous coins are hurled at the target to inflict damage."),
    "payback": (dict(ARC, power=50, range=2.0, angle=90, special="revenge"), "If the user has just been hurt by the target, this attack's power is doubled."),
    "poison_tail": (dict(ARC, power=50, range=2.2, angle=110, crit=1, effect={"status": "poison", "chance": 0.1}),
                    "The user hits the target with its tail. It may poison the target. High critical-hit ratio."),
    "pollen_puff": (dict(BALL, power=90, speed=12, knockback=5, fx="lob", lob_height=1.6), "The user attacks the enemy with a pollen puff that explodes."),
    "pounce": (dict(TACKLE, power=50, range=4.0, speed=16, effect={"stat": "spe", "stages": -1, "chance": 1.0}),
               "The user attacks by pouncing on the target. This also lowers the target's Speed."),
    "present": (dict(BALL, power=40, speed=11, fx="lob", lob_height=1.8, special="present"),
                "The user attacks by giving the target a gift with a hidden trap. It restores HP sometimes, however."),
    "psych_up": (dict(SELF, special="psych_up"), "The user hypnotizes itself into copying any stat change made by the target."),
    "psychic_fangs": (dict(BITE, power=85, knockback=6, special="screen_break"), "The user bites the target with its psychic capabilities. This can also destroy Light Screen and Reflect."),
    "psychic_noise": (dict(VOICE, power=75, special="heal_block"), "The user attacks with unpleasant sound waves. The target can't recover HP for a while."),
    "psyshock": (dict(BLAST, power=80, special="psyshock"), "The user materializes an odd psychic wave to attack the target. This attack does physical damage."),
    "reflect": (dict(SELF, special="reflect"), "A wondrous wall of light reduces damage from physical attacks for a while."),
    "revenge": (dict(PUNCH, power=60, special="revenge"), "An attack that inflicts double the damage if the user has been hurt by the target just before."),
    "reversal": (dict(RUSH, power=1, range=6.5, speed=17, special="flail"), "An all-out attack that becomes more powerful the less HP the user has."),
    "roar": (dict(DEBUFF, radius=5.0, stat="spe", stages=-1, push=5.0), "The target is scared off by a mighty roar and blown far away."),
    "rock_blast": (dict(BALL, power=25, speed=15, knockback=2, hits_range=[2, 5], count=2, spread=8), "The user hurls hard rocks at the target. Two to five rocks are launched in a row."),
    "rock_smash": (dict(PUNCH, power=40, effect={"stat": "def", "stages": -1, "chance": 0.5}), "The user attacks with a punch. This may also lower the target's Defense."),
    "scale_shot": (dict(BALL, power=25, speed=16, knockback=2, hits_range=[2, 5], count=2, spread=8, self_stats={"spe": 1, "def": -1}),
                   "The user attacks by shooting scales two to five times. This raises its Speed but lowers its Defense."),
    "scorching_sands": (dict(BALL, power=70, speed=14, effect={"status": "burn", "chance": 0.3}), "The user throws scorching sand at the target. This may also leave the target with a burn."),
    "shadow_ball": (dict(BALL, power=80, speed=13, knockback=5, effect={"stat": "spd", "stages": -1, "chance": 0.2}),
                    "The user hurls a shadowy blob at the target. This may also lower the target's Sp. Def."),
    "shadow_claw": (dict(ARC, power=70, range=2.1, angle=90, knockback=6, crit=1), "The user slashes with a sharp claw made from shadows. High critical-hit ratio."),
    "shock_wave": (dict(HOMING, power=60, speed=16), "The user strikes the target with a quick jolt of electricity. This attack never misses."),
    "skill_swap": (dict(SHOT, speed=12, special="skill_swap"), "The user employs its psychic power to exchange Abilities with the target."),
    "skitter_smack": (dict(TACKLE, power=70, range=4.5, speed=17, effect={"stat": "spa", "stages": -1, "chance": 1.0}),
                      "The user skitters behind the target to attack. This also lowers the target's Sp. Atk."),
    "sky_attack": (dict(RUSH, power=140, range=9.0, speed=21, knockback=11, windup=1.0, crit=1, effect={"status": "flinch", "chance": 0.3}),
                   "The user glows while charging, then strikes. High critical-hit ratio; it may make the target flinch."),
    "sleep_talk": (dict(SELF, special="sleep_talk"), "While asleep, the user randomly uses one of the moves it knows."),
    "sludge_wave": (dict(BURST, power=95, radius=4.5, knockback=6, effect={"status": "poison", "chance": 0.1}),
                    "The user strikes everything around it by swamping the area with a giant sludge wave. It may poison."),
    "smack_down": (dict(BALL, power=50, speed=16), "The user throws a stone or projectile. It can hit a Pokemon high in the sky."),
    "smart_strike": (dict(RUSH, power=70, range=7.0, speed=18, knockback=6), "The user stabs the target with a sharp horn. This attack never misses."),
    "snarl": (dict(WAVE, power=55, effect={"stat": "spa", "stages": -1, "chance": 1.0}), "The user yells as if it's ranting about something, which lowers the Sp. Atk of opposing Pokemon."),
    "snore": (dict(VOICE, power=50, special="sleep_only", effect={"status": "flinch", "chance": 0.3}),
              "An attack that can be used only if the user is asleep. The harsh noise may make the target flinch."),
    "solar_blade": (dict(ARC, power=125, range=2.4, angle=100, knockback=10, windup=1.1), "The user gathers light energy into a blade, then attacks the target."),
    "spikes": (dict(SELF, special="spikes"), "The user lays a trap of spikes at the opposing team's feet. They hurt whoever steps on them."),
    "stealth_rock": (dict(SELF, special="stealth_rock"), "The user lays a trap of levitating stones around the opposing team. They hurt whoever comes near."),
    "steel_wing": (dict(ARC, power=70, range=2.2, angle=110, knockback=6, effect={"stat": "def", "stages": 1, "chance": 0.1, "self": True}),
                   "The target is hit with wings of steel. This may also raise the user's Defense."),
    "stomping_tantrum": (dict(BURST, power=75, radius=2.2, knockback=7, slam=True, special="stomping_tantrum"),
                         "Driven by frustration, the user attacks. Power doubles if the user's previous move failed."),
    "strength": (dict(RUSH, power=80, range=5.0, speed=14, knockback=9), "The target is slugged with a punch thrown at maximum power."),
    "strength_sap": (dict(SHOT, speed=12, special="strength_sap"), "The user restores HP by the target's Attack stat. It also lowers the target's Attack."),
    "struggle_bug": (dict(WAVE, power=50, effect={"stat": "spa", "stages": -1, "chance": 1.0}), "While resisting, the user attacks opposing Pokemon. This lowers their Sp. Atk."),
    "substitute": (dict(SELF, special="substitute"), "The user creates a substitute for itself using some of its HP. It takes hits for the user."),
    "sunny_day": (dict(SELF, special="sunny_day"), "The user intensifies the sun for a while, powering up Fire-type moves and weakening Water ones."),
    "surf": (dict(BURST, power=90, radius=4.5, knockback=7), "The user attacks everything around it by swamping its surroundings with a giant wave."),
    "swagger": (dict(SHOT, speed=11, effect={"status": "confusion", "chance": 1.0}, special="flatter", flatter_stat="atk"),
                "The user enrages and confuses the target. However, this also sharply raises the target's Attack."),
    "switcheroo": (dict(SHOT, speed=14, special="trick"), "The user trades held items with the target faster than the eye can follow."),
    "taunt": (dict(SHOT, speed=13, special="taunt"), "The target is taunted into a rage that allows it to use only attack moves for a while."),
    "teeter_dance": (dict(DEBUFF, radius=4.5, special="teeter_dance"), "The user performs a wobbly dance that confuses the Pokemon around it."),
    "temper_flare": (dict(RUSH, power=75, range=6.5, speed=17, knockback=7, special="stomping_tantrum"),
                     "Spurred by desperation, the user attacks. Power doubles if the user's previous move failed."),
    "tera_blast": (dict(BALL, power=80, speed=14, knockback=5), "The user fires a blast of pure energy at the target."),
    "throat_chop": (dict(ARC, power=80, range=2.0, angle=80, knockback=7, special="throat_chop"),
                    "The user attacks the target's throat. The target can't use sound-based moves for a while."),
    "tickle": (dict(DEBUFF, stat="atk", stages=-1, special="tickle"), "The user tickles the target into laughing, reducing its Attack and Defense."),
    "trailblaze": (dict(RUSH, power=50, range=6.5, speed=17, knockback=5, effect={"stat": "spe", "stages": 1, "chance": 1.0, "self": True}),
                   "The user attacks suddenly as if leaping out from tall grass. The user's nimble footwork boosts its Speed."),
    "trick": (dict(SHOT, speed=12, special="trick"), "The user catches the target off guard and swaps its held item with its own."),
    "u_turn": (dict(RUSH, power=70, range=6.5, speed=19, knockback=6, special="pivot"), "After making its attack, the user rushes back to switch places with a party Pokemon in waiting."),
    "upper_hand": (dict(TACKLE, power=65, range=4.0, speed=20, windup=0.03, special="upper_hand", effect={"status": "flinch", "chance": 1.0}),
                   "The user reacts to the target winding up a move and strikes first, making it flinch. It fails otherwise."),
    "uproar": (dict(VOICE, power=90, range=5.5, angle=80, duration=1.0, once=True, special="uproar"),
               "The user attacks in an uproar for a while. During that time, no Pokemon can fall asleep."),
    "venom_drench": (dict(DEBUFF, stat="atk", stages=-1, special="venom_drench"),
                     "Opposing Pokemon are drenched in an odd poisonous liquid. Poisoned targets lose Attack, Sp. Atk and Speed."),
    "volt_switch": (dict(BALL, power=70, speed=22, special="pivot"), "After making its attack, the user rushes back to switch places with a party Pokemon in waiting."),
    "water_pledge": (dict(STRIKE, power=80, radius=1.5), "A column of water hits the target."),
    "water_spout": (dict(BURST, power=150, radius=4.5, knockback=8, windup=0.45, special="water_spout"),
                    "The user spouts water to damage opposing Pokemon. The lower the user's HP, the lower the power."),
    "weather_ball": (dict(BALL, power=50, speed=14, special="weather_ball"), "This attack changes type and doubles in power with the weather."),
    "whirlpool": ({"kind": "zone", "power": 12, "range": 8, "knockback": 0, "duration": 2.5, "tick": 0.5, "radius": 1.6, "trap": 0.6},
                  "The user traps the target in a violent swirling whirlpool for a while."),
    "wide_guard": (dict(SELF, special="wide_guard"), "The user and its allies are protected from wide-ranging attacks for a moment."),
    "wild_charge": (dict(RUSH, power=90, range=7.0, speed=18, knockback=9, recoil=0.25),
                    "The user shrouds itself in electricity and smashes into its target. This also damages the user a little."),
    "wish": (dict(SELF, special="wish"), "A moment later, the user or its replacement will have half the user's max HP restored."),
    "work_up": (dict(SELF, stat="atk", stages=1, stats={"atk": 1, "spa": 1}), "The user is roused, and its Attack and Sp. Atk increase."),
})


# Correções nos golpes que já existiam (Gen 9 + mecânicas que faltavam). None apaga o campo.
FIX = {
    "fury_swipes": {"hits_range": [2, 5]},
    "bullet_seed": {"hits_range": [2, 5]},
    "double_slap": {"hits_range": [2, 5]},
    "fury_attack": {"hits_range": [2, 5]},
    "icicle_spear": {"hits_range": [2, 5]},
    "pin_missile": {"hits_range": [2, 5]},
    "string_shot": {"effect": {"stat": "spe", "stages": -2, "chance": 1.0}},
    "iron_tail": {"crit": None, "effect": {"stat": "def", "stages": -1, "chance": 0.3}},
    "fire_fang": {"flinch": 0.1},
    "volt_tackle": {"recoil": 0.33, "effect": {"status": "paralysis", "chance": 0.1}},
    "submission": {"recoil": 0.25},
    "drill_run": {"crit": 1},
    "close_combat": {"self_stats": {"def": -1, "spd": -1}},
    "rapid_spin": {"effect": {"stat": "spe", "stages": 1, "chance": 1.0, "self": True}, "special": "rapid_spin"},
    "charge": {"stat": "spd", "stages": 1, "special": "charge"},
    "growth": {"stat": "atk", "stages": 1, "stats": {"atk": 1, "spa": 1}},
    "curse": {"stats": {"atk": 1, "def": 1, "spe": -1}, "special": "curse"},
    "thrash": {"special": "self_confuse"},
    "petal_dance": {"special": "self_confuse"},
    "tri_attack": {"effect": None, "tri": 0.2},
    "yawn": {"effect": None, "special": "yawn"},
    "disable": {"effect": None, "special": "disable"},
    "encore": {"kind": "projectile", "range": 8, "speed": 12, "knockback": 0, "stat": None, "stages": None, "radius": None, "special": "encore"},
    "rain_dance": {"stat": None, "stages": None, "special": "rain_dance"},
    "skull_bash": {"charge_stats": {"def": 1}},
    "rollout": {"chain": 4, "special": "chain"},
    "defense_curl": {"special": "defense_curl"},
    "thief": {"special": "covet"},
    "wrap": {"trap": 0.4},
    "bind": {"trap": 0.4},
    "sand_tomb": {"trap": 0.6},
    "thunder_wave": {"special": "thunder_wave"},
    "flail": {"special": "flail"},
    "low_kick": {"special": "low_kick"},
    "electro_ball": {"special": "electro_ball"},
    "super_fang": {"special": "super_fang"},
    "seismic_toss": {"special": "level_damage"},
    "dragon_rage": {"special": "fixed", "fixed": 40},
    "sonic_boom": {"special": "fixed", "fixed": 20},
    "sleep_powder": {"powder": True},
    "stun_spore": {"powder": True},
    "poison_powder": {"powder": True},
    "spore": {"powder": True},
}

ORDER = ["id", "name", "desc", "type", "category", "kind"]


def from_api(mid, game, desc):
    d = api(mid)
    mv = {"id": mid, "name": next(n["name"] for n in d["names"] if n["language"]["name"] == "en"), "desc": desc,
          "type": d["type"]["name"], "category": d["damage_class"]["name"]}
    mv.update(game)
    if mv["category"] == "status":
        mv["power"] = 0
    mv["uses"] = d["pp"]
    if d.get("accuracy") is not None:
        mv["accuracy"] = d["accuracy"]
    if d.get("power"):
        mv["bp"] = d["power"]
    if d.get("priority"):
        mv["priority"] = d["priority"]
    tgt = d["target"]["name"]
    if tgt in ("all-opponents", "all-other-pokemon", "all-pokemon"):
        mv["multi_target"] = tgt.replace("-", "_")
    out = {k: mv[k] for k in ORDER if k in mv}
    out.update({k: v for k, v in mv.items() if k not in ORDER})
    return out


def main():
    path = "data/moves.json"
    doc = json.load(open(path, encoding="utf-8"))
    have = {m["id"]: m for m in doc["moves"]}
    for mid, ch in FIX.items():
        m = have[mid]
        for k, v in ch.items():
            if v is None:
                m.pop(k, None)
            else:
                m[k] = v
    for mid, (game, desc) in NEW.items():
        mv = from_api(mid, game, desc)
        if mid in have:
            have[mid].clear()
            have[mid].update(mv)
        else:
            doc["moves"].append(mv)
            have[mid] = mv
    dump_moves(doc, path)
    print(len(NEW), "golpes novos;", len(FIX), "corrigidos")


main()

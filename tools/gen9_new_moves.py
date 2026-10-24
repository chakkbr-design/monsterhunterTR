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

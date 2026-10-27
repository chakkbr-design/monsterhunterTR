#!/usr/bin/env python3
"""Relatório da bateria de lutas (telemetria de BattleTelemetry, um .json por luta).

Uso: python3 tools/battery_report.py DIR [DIR...] [--json saida.json] [--label nome]
Imprime um resumo e (com --json) grava os números para a página de análise.
"""
import json
import math
import os
import statistics as st
import sys
from collections import Counter, defaultdict

CORNER_WALL = 1.6
CORNER_FOE = 3.2
STALL_GAP = 25.0
# Objetos vivos do cenário (battle/battle_props.gd): eventos contados por luta e dano que vem deles.
PROP_EVENTS = (
    "tree_ignite", "tree_fall", "tree_fall_hit", "log_block", "voltorb_wake", "voltorb_boom",
    "voltorb_hit", "berry_drop", "berry_pick", "bush_burn", "bush_regrow", "crystal_reflect",
    "crystal_reflect_hit", "crystal_charge", "crystal_spark", "crystal_break", "prop_ai_shot",
    "prop_ai_berry", "boulder_push", "boulder_hit", "boulder_stop", "geyser_erupt",
    "geyser_launch", "geyser_early", "geyser_fly_hit", "hive_swarm", "swarm_sting", "swarm_fire",
    "hive_burn", "spore_cloud", "spore_status", "spore_wet",
)
PROP_DMG = (  # fora dos eventos "hit"
    "tree_fall_hit", "voltorb_hit", "crystal_spark", "boulder_hit", "swarm_sting",
)


def pct(a, b):
    return 100.0 * a / b if b else 0.0


def q(xs, p):
    if not xs:
        return 0.0
    xs = sorted(xs)
    k = (len(xs) - 1) * p
    lo, hi = math.floor(k), math.ceil(k)
    return xs[lo] + (xs[hi] - xs[lo]) * (k - lo)


def load(dirs):
    out = []
    for d in dirs:
        for fn in sorted(os.listdir(d)):
            if fn.endswith(".json"):
                try:
                    with open(os.path.join(d, fn)) as fh:
                        f = json.load(fh)
                except Exception as e:  # luta cortada no meio
                    print("ignorado", fn, e, file=sys.stderr)
                    continue
                if isinstance(f, dict) and "result" in f and "events" in f:  # pula report/anomalies
                    out.append(f)
    return out


def bp_bucket(bp):
    if bp <= 0:
        return "status"
    if bp <= 50:
        return "<=50"
    if bp <= 75:
        return "55-75"
    if bp <= 95:
        return "80-95"
    if bp <= 115:
        return "100-115"
    return "120+"


def analyse(fights):
    R = {}
    n = len(fights)
    R["fights"] = n
    oc = Counter(f["result"]["outcome"] for f in fights)
    R["outcomes"] = dict(oc)
    by_size = defaultdict(list)
    for f in fights:
        by_size[f["meta"].get("size", 1)].append(f["result"]["time"])
    R["duration"] = {
        str(k): {"mean": st.mean(v), "p10": q(v, 0.1), "p50": q(v, 0.5), "p90": q(v, 0.9), "n": len(v)}
        for k, v in sorted(by_size.items())
    }
    # Por Pokémon em campo: tempo de vida e como caiu.
    life, first_hit_ko, ko_since, hits_to_ko = [], 0, [], []
    quick_deaths = Counter()
    entries = 0
    faints = 0
    frac_by_bucket = defaultdict(list)
    ohko_full = 0
    hits_total = 0
    dmg_direct = 0.0
    dmg_combo = 0.0
    dmg_resid = 0.0
    resid_by = Counter()
    move_use = Counter()
    move_bucket_use = Counter()
    sec_use = Counter()
    cost_by_bucket = defaultdict(list)
    en_at_move = []
    why = Counter()
    ai_cast = Counter()
    status_roll = defaultdict(lambda: [0, 0, 0.0])
    status_on = Counter()
    status_kinds = Counter()
    status_move_share = [0, 0]
    tags = Counter()
    plans = Counter()
    samples_n = 0
    corner = wall = high = water = grass = rest = capped = run = stun = fly = 0
    dist = []
    stall_fights = 0
    stalls = []
    terrain = Counter()
    props = Counter()
    prop_dmg = Counter()
    prop_ai = Counter()
    berry_gain = Counter()
    misses = 0
    dodges = Counter()
    per_mon_tag_entropy = []
    weather_t = defaultdict(list)
    combos = Counter()
    passives = Counter()
    grass_hide = []
    grass_go = []
    grass_why = Counter()
    eff_hits = Counter()
    crit = 0
    moves_per_min = []
    species_win = defaultdict(lambda: [0, 0])
    for f in fights:
        meta = f["meta"]
        weather_t[meta.get("weather") or "none"].append(f["result"]["time"])
        evs = f["events"]
        hits_on = defaultdict(int)
        mon_moves = Counter()
        mon_time = defaultdict(float)
        enter_t = {}
        last_move_t = 0.0
        stalled = False
        status_since = {}
        for e in evs:
            k = e["ev"]
            if k == "enter":
                entries += 1
                enter_t[e["who"]] = e["t"]
                hits_on[e["who"]] = 0
            elif k == "move":
                move_use[e["move"]] += 1
                b = bp_bucket(e.get("bp", 0)) if e.get("cat") != "status" else "status"
                move_bucket_use[b] += 1
                cost_by_bucket[b].append(e.get("cost", 0))
                en_at_move.append(e.get("en", 0) + e.get("cost", 0))
                why[e.get("why", "")] += 1
                ai_cast[e.get("ai", "")] += 1
                mon_moves[e["who"]] += 1
                status_move_share[0 if e.get("cat") == "status" else 1] += 1
                if e["t"] - last_move_t > STALL_GAP:
                    stalled = True
                    stalls.append(e["t"] - last_move_t)
                last_move_t = e["t"]
            elif k == "hit":
                hits_total += 1
                dmg_direct += e["frac"]
                if e.get("move", "") in ("combo_area", "combo_field"):
                    dmg_combo += e["frac"]
                hits_on[e["tgt"]] += 1
                frac_by_bucket["all"].append(e["frac"])
                eff_hits[str(e["eff"])] += 1
                if e.get("crit"):
                    crit += 1
                if e["ko"]:
                    hits_to_ko.append(hits_on[e["tgt"]])
                    ko_since.append(e["since_in"])
                    if hits_on[e["tgt"]] == 1:
                        first_hit_ko += 1
                    if e["hp0"] >= e["max"]:
                        ohko_full += 1
            elif k == "residual":
                dmg_resid += e["frac"]
                resid_by[e["why"]] += e["frac"]
            elif k == "status_roll":
                r = status_roll[e["st"]]
                r[0] += 1
                r[1] += 1 if e["got"] else 0
                r[2] += e["chance"]
            elif k == "status":
                status_kinds[e["st"]] += 1
                status_since[e["who"]] = (e["st"], e["t"])
            elif k == "cure":
                if e["who"] in status_since:
                    s0, t0 = status_since.pop(e["who"])
                    status_on[s0] += e["t"] - t0
            elif k == "faint":
                faints += 1
                life.append(e["on_field"])
                for lim in (3, 5, 8, 12):
                    if e["on_field"] < lim:
                        quick_deaths[lim] += 1
                if e["who"] in status_since:
                    s0, t0 = status_since.pop(e["who"])
                    status_on[s0] += e["t"] - t0
                if e["who"] in enter_t:
                    mon_time[e["who"]] += e["t"] - enter_t.pop(e["who"])
            elif k.startswith("terrain_"):
                terrain[k[8:]] += 1
            elif k in PROP_EVENTS:
                props[k] += 1
                if k in PROP_DMG or k == "crystal_reflect_hit":
                    prop_dmg[k] += e.get("frac", 0.0)
                if k == "prop_ai_shot":
                    prop_ai[e.get("what", "?")] += 1
                if k == "berry_pick":
                    berry_gain[e.get("gain", "?")] += 1
            elif k == "miss":
                misses += 1
            elif k == "dodge":
                dodges[e["what"]] += 1
            elif k in ("combo", "duo"):
                combos[k] += 1
            elif k == "passive":
                passives[e.get("p", "?")] += 1
            elif k == "ai_grass":
                grass_hide.append(e.get("secs", 0.0))
                grass_go.append(e.get("go", 0.0))
                grass_why[e.get("why", "?")] += 1
        T = f["result"]["time"]
        for who, t0 in enter_t.items():
            mon_time[who] += T - t0
        for who, t0 in status_since.items():
            status_on[t0[0]] += T - t0[1]
        for who, c in mon_moves.items():
            if mon_time.get(who, 0) > 10:
                moves_per_min.append(60.0 * c / mon_time[who])
        if stalled:
            stall_fights += 1
        mt = defaultdict(Counter)
        for s in f["samples"]:
            for r in s["f"]:
                samples_n += 1
                tg = r.get("ai", "")
                tags[tg] += 1
                mt[r["id"]][tg] += 1
                if r.get("plan"):
                    plans[r["plan"]] += 1
                w = r.get("wall", 9)
                if w < 1.0:
                    wall += 1
                if w < CORNER_WALL and r.get("d", 99) < CORNER_FOE:
                    corner += 1
                high += 1 if r.get("high") else 0
                water += 1 if r.get("water") else 0
                grass += 1 if r.get("grass") else 0
                rest += 1 if r.get("rest") else 0
                capped += 1 if r.get("en", 0) >= 99.5 else 0
                run += 1 if r.get("run") else 0
                stun += 1 if r.get("stun") else 0
                fly += 1 if r.get("fly") else 0
                if "d" in r:
                    dist.append(r["d"])
        for who, c in mt.items():
            tot = sum(c.values())
            if tot >= 20:
                ent = -sum(v / tot * math.log2(v / tot) for v in c.values() if v)
                per_mon_tag_entropy.append(ent)
        win = 0 if f["result"]["outcome"] == "win" else (1 if f["result"]["outcome"] == "lose" else -1)
        for side in (0, 1):
            for m in f["teams"][side]:
                species_win[m["sp"]][1] += 1
                if win == side:
                    species_win[m["sp"]][0] += 1
    R["entries"] = entries
    R["faints"] = faints
    R["life_on_field"] = {"mean": st.mean(life) if life else 0, "p10": q(life, 0.1), "p25": q(life, 0.25), "p50": q(life, 0.5), "p90": q(life, 0.9)}
    R["quick_deaths_pct"] = {str(k): pct(v, faints) for k, v in sorted(quick_deaths.items())}
    R["ko_first_hit_pct"] = pct(first_hit_ko, faints)
    R["ohko_from_full_pct"] = pct(ohko_full, faints)
    R["hits_to_ko"] = {"mean": st.mean(hits_to_ko) if hits_to_ko else 0, "p50": q(hits_to_ko, 0.5)}
    R["hit_frac"] = {"mean": st.mean(frac_by_bucket["all"]) if hits_total else 0, "p50": q(frac_by_bucket["all"], 0.5), "p90": q(frac_by_bucket["all"], 0.9)}
    R["crit_pct"] = pct(crit, hits_total)
    R["eff_hits"] = dict(eff_hits)
    R["damage_share_residual_pct"] = pct(dmg_resid, dmg_direct + dmg_resid)
    R["residual_by"] = {k: round(v, 2) for k, v in resid_by.most_common()}
    R["move_bucket_use_pct"] = {k: pct(v, sum(move_bucket_use.values())) for k, v in sorted(move_bucket_use.items())}
    R["cost_by_bucket"] = {k: st.mean(v) for k, v in sorted(cost_by_bucket.items())}
    R["energy_at_move"] = {"mean": st.mean(en_at_move) if en_at_move else 0, "p50": q(en_at_move, 0.5)}
    R["moves_per_min_per_mon"] = {"mean": st.mean(moves_per_min) if moves_per_min else 0, "p50": q(moves_per_min, 0.5)}
    R["status_move_pct"] = pct(status_move_share[0], sum(status_move_share))
    R["why"] = {k: pct(v, sum(why.values())) for k, v in why.most_common()}
    R["ai_when_cast"] = {k: pct(v, sum(ai_cast.values())) for k, v in ai_cast.most_common(12)}
    R["status_rolls"] = {k: {"rolls": v[0], "landed": v[1], "land_pct": pct(v[1], v[0]), "mean_chance": v[2] / v[0] if v[0] else 0} for k, v in status_roll.items()}
    R["status_applied"] = dict(status_kinds)
    R["status_seconds"] = {k: round(v, 1) for k, v in status_on.items()}
    R["ai_tags_pct"] = {k: pct(v, samples_n) for k, v in tags.most_common()}
    R["plans_pct"] = {k: pct(v, samples_n) for k, v in plans.most_common()}
    R["pos_pct"] = {
        "corner": pct(corner, samples_n), "wall<1m": pct(wall, samples_n), "high": pct(high, samples_n),
        "water": pct(water, samples_n), "grass": pct(grass, samples_n), "resting": pct(rest, samples_n),
        "energy_capped": pct(capped, samples_n), "running": pct(run, samples_n), "stunned": pct(stun, samples_n),
        "flying": pct(fly, samples_n),
    }
    R["dist_to_target"] = {"p10": q(dist, 0.1), "p50": q(dist, 0.5), "p90": q(dist, 0.9)}
    R["tag_entropy_bits"] = {"mean": st.mean(per_mon_tag_entropy) if per_mon_tag_entropy else 0, "p10": q(per_mon_tag_entropy, 0.1)}
    R["stall_fights_pct"] = pct(stall_fights, n)
    R["terrain_events"] = dict(terrain)
    R["props_per_fight"] = {k: props[k] / n for k in PROP_EVENTS if props[k]} if n else {}
    R["prop_ai_shots"] = dict(prop_ai)
    R["berry_gain"] = dict(berry_gain)
    extra = sum(prop_dmg[k] for k in PROP_DMG)
    total = dmg_direct + dmg_resid + extra
    R["prop_damage_pct"] = {k: pct(v, total) for k, v in prop_dmg.items()}
    R["prop_damage_share_pct"] = pct(extra + prop_dmg["crystal_reflect_hit"], total)
    R["misses_per_fight"] = misses / n if n else 0
    R["dodges_per_fight"] = {k: v / n for k, v in dodges.items()}
    R["damage_share_combo_pct"] = pct(dmg_combo, dmg_direct)
    R["combos_per_fight"] = {k: v / n for k, v in combos.items()}
    R["passives"] = dict(passives)
    # Emboscada na grama (BattleTerrainAI): idas à moita, tempo escondido e por que saiu.
    R["grass_ambush"] = {
        "stints": len(grass_hide), "per_fight": len(grass_hide) / n if n else 0,
        "hide_mean": st.mean(grass_hide) if grass_hide else 0, "hide_p90": q(grass_hide, 0.9),
        "hide_max": max(grass_hide) if grass_hide else 0,
        "hid_pct": pct(sum(1 for x in grass_hide if x > 0), len(grass_hide)),
        "hide_mean_if_hid": st.mean([x for x in grass_hide if x > 0] or [0]),
        "go_mean": st.mean(grass_go) if grass_go else 0,
    }
    R["grass_leave_why"] = dict(grass_why.most_common())
    R["duration_by_weather"] = {k: st.mean(v) for k, v in weather_t.items()}
    top = sorted(((v[0] / v[1], k, v[1]) for k, v in species_win.items() if v[1] >= 10), reverse=True)
    R["species_winrate_top"] = [(k, round(100 * w, 1), c) for w, k, c in top[:8]]
    R["species_winrate_bottom"] = [(k, round(100 * w, 1), c) for w, k, c in top[-8:]]
    top_moves = move_use.most_common(15)
    R["top_moves"] = top_moves
    return R


def show(R, label=""):
    print("=" * 70)
    print("BATERIA", label, "-", R["fights"], "lutas")
    for k, v in R.items():
        if k == "fights":
            continue
        if isinstance(v, dict):
            items = ", ".join(f"{a}={b:.1f}" if isinstance(b, float) else f"{a}={b}" for a, b in v.items())
            print(f"{k}: {items}")
        elif isinstance(v, float):
            print(f"{k}: {v:.2f}")
        else:
            print(f"{k}: {v}")


def main():
    args = sys.argv[1:]
    out = None
    label = ""
    dirs = []
    i = 0
    while i < len(args):
        if args[i] == "--json":
            out = args[i + 1]
            i += 2
        elif args[i] == "--label":
            label = args[i + 1]
            i += 2
        else:
            dirs.append(args[i])
            i += 1
    R = analyse(load(dirs))
    show(R, label)
    if out:
        with open(out, "w") as fh:
            json.dump(R, fh, indent=1, default=str)


if __name__ == "__main__":
    main()

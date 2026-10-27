#!/usr/bin/env python3
"""Caça-bugs da bateria: lê a telemetria (um .json por luta) e os job*.log de tools/battery.sh.

Uso: python3 tools/battery_anomalies.py DIR [DIR...] [--json saida.json]

Procura:
- luta que acabou no limite de tempo (timeout);
- reagrupar que estourou o teto (BattleRegroup.MAX_SECS) ou terminou com alguém longe do ponto de entrada;
- trava ("hold"): a luta parada em "fight" sem o relógio andar (vigia do battery.gd);
- Pokémon parado: em luta, sem descanso nem atordoado, andando menos de STUCK_M em STUCK_S segundos;
- posição fora da quadra ou NaN;
- erros e avisos do Godot nos logs (agrupados pela mensagem).
"""
import json
import math
import os
import re
import sys
from collections import Counter, defaultdict

STUCK_S = 8.0
STUCK_M = 0.3


def load(d):
    for fn in sorted(os.listdir(d)):
        if fn.endswith(".json"):
            try:
                with open(os.path.join(d, fn)) as fh:
                    f = json.load(fh)
            except Exception as e:
                print("ignorado", fn, e, file=sys.stderr)
                continue
            if isinstance(f, dict) and "result" in f and "events" in f:  # pula report.json etc.
                yield fn, f


def stuck_runs(samples):
    """Trechos em que um lutador quase não sai do lugar por STUCK_S s (fora de descanso/atordoado)."""
    track = defaultdict(list)  # id -> [(t, x, z, row)]
    for s in samples:
        for r in s["f"]:
            track[r["id"]].append((s["t"], r["x"], r["z"], r))
    out = []
    for fid, pts in track.items():
        i = 0
        while i < len(pts):
            t0, x0, z0, r0 = pts[i]
            j = i
            while j + 1 < len(pts):
                t1, x1, z1, r1 = pts[j + 1]
                if t1 - pts[j][0] > 1.0:  # buraco (reagrupar/troca): corta o trecho
                    break
                if math.hypot(x1 - x0, z1 - z0) > STUCK_M or r1.get("rest") or r1.get("stun"):
                    break
                j += 1
            dur = pts[j][0] - t0
            if dur >= STUCK_S:
                mid = pts[(i + j) // 2][3]
                out.append({
                    "id": fid, "t": t0, "secs": round(dur, 2), "x": x0, "z": z0,
                    "int": mid.get("int"), "plan": mid.get("plan"), "d": mid.get("d"),
                    "wall": mid.get("wall"), "high": mid.get("high"), "water": mid.get("water"),
                    "fly": mid.get("fly"), "st": mid.get("st"), "gy": mid.get("gy"),
                })
            i = j + 1
    return out


def scan_logs(d):
    msgs = Counter()
    where = {}
    pat = re.compile(r"(SCRIPT ERROR|ERROR|WARNING|USER ERROR|USER WARNING)[: ](.*)")
    for fn in sorted(os.listdir(d)):
        if not fn.endswith(".log"):
            continue
        lines = open(os.path.join(d, fn), errors="replace").read().splitlines()
        for k, ln in enumerate(lines):
            m = pat.search(ln)
            if not m:
                continue
            nxt = lines[k + 1].strip() if k + 1 < len(lines) else ""
            key = (m.group(1) + ": " + m.group(2).strip())[:220]
            msgs[key] += 1
            where.setdefault(key, nxt[:200])
    return [{"msg": k, "n": n, "at": where[k]} for k, n in msgs.most_common()]


def main():
    args = sys.argv[1:]
    jout = None
    if "--json" in args:
        k = args.index("--json")
        jout = args[k + 1]
        del args[k:k + 2]
    rep = {"fights": 0, "timeouts": [], "regroup_bad": [], "holds": [], "stuck": [],
           "out_of_bounds": [], "logs": []}
    regroup_secs = []
    for d in args:
        for fn, f in load(d):
            rep["fights"] += 1
            seed = f.get("meta", {}).get("seed", fn)
            size = f.get("meta", {}).get("size")
            scen = f.get("meta", {}).get("scenario") or f.get("meta", {}).get("scene", "")
            if f["result"]["outcome"] == "timeout":
                rep["timeouts"].append({"seed": seed, "size": size, "time": f["result"]["time"]})
            for e in f["events"]:
                if e["ev"] == "regroup_end":
                    regroup_secs.append(e["secs"])
                    if e.get("timeout") or e.get("far"):
                        rep["regroup_bad"].append({"seed": seed, "size": size, "scen": scen, **e})
                elif e["ev"] == "hold":
                    rep["holds"].append({"seed": seed, "size": size, **e})
            for s in stuck_runs(f.get("samples", [])):
                rep["stuck"].append({"seed": seed, "size": size, "scen": scen, **s})
            for s in f.get("samples", []):
                for r in s["f"]:
                    bad = any(isinstance(r.get(k), float) and math.isnan(r[k]) for k in ("x", "z"))
                    if bad or r.get("wall", 1) < 0:
                        rep["out_of_bounds"].append({"seed": seed, "t": s["t"], **r})
        rep["logs"] += scan_logs(d)
    rs = sorted(regroup_secs)
    rep["regroup"] = {
        "n": len(rs),
        "median": rs[len(rs) // 2] if rs else 0,
        "p90": rs[int(len(rs) * 0.9)] if rs else 0,
        "max": rs[-1] if rs else 0,
    }
    print("lutas:", rep["fights"])
    print("timeouts:", len(rep["timeouts"]))
    print("reagrupar: %(n)d, mediana %(median)s s, p90 %(p90)s s, máx %(max)s s" % rep["regroup"])
    print("reagrupar ruim (teto ou longe):", len(rep["regroup_bad"]))
    print("travas (hold):", len(rep["holds"]))
    print("parados %ss+:" % STUCK_S, len(rep["stuck"]))
    for s in sorted(rep["stuck"], key=lambda s: -s["secs"])[:15]:
        print("  ", s)
    print("fora da quadra/NaN:", len(rep["out_of_bounds"]))
    print("mensagens do Godot:", sum(m["n"] for m in rep["logs"]))
    for m in rep["logs"][:25]:
        print("  %5d  %s  | %s" % (m["n"], m["msg"], m["at"]))
    if jout:
        with open(jout, "w") as fh:
            json.dump(rep, fh, indent=1)


if __name__ == "__main__":
    main()

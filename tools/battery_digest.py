#!/usr/bin/env python3
"""Resumo compacto da bateria para o relatório de balanceamento (um JSON pequeno, sem as amostras).

Uso: python3 tools/battery_digest.py DIR [DIR...] --json saida.json

Por espécie, golpe, habilidade, tipo e categoria: uso, vitória do time, dano causado (fração do HP do
alvo), nocautes, vida em campo; mais os golpes mais e menos eficientes por energia.
"""
import json
import os
import sys
from collections import defaultdict


def fights(dirs):
    for d in dirs:
        for fn in sorted(os.listdir(d)):
            if not fn.endswith(".json"):
                continue
            try:
                with open(os.path.join(d, fn)) as fh:
                    f = json.load(fh)
            except Exception:
                continue
            if isinstance(f, dict) and "result" in f and "events" in f:
                yield f


def row():
    return defaultdict(float)


def main():
    args = sys.argv[1:]
    out = "digest.json"
    if "--json" in args:
        k = args.index("--json")
        out = args[k + 1]
        del args[k:k + 2]
    sp, mv, ab, ty = (defaultdict(row) for _ in range(4))
    size_n = defaultdict(int)
    n = 0
    for f in fights(args):
        n += 1
        size = int(f.get("meta", {}).get("size", 1) or 1)
        size_n[size] += 1
        outc = f["result"]["outcome"]
        won = {0: outc == "win", 1: outc == "lose"}
        teams = f["teams"]
        info = {}
        for side in (0, 1):
            for i, m in enumerate(teams[side]):
                uid = "%d:%d:%s" % (side, i, m["sp"])
                info[uid] = m
                w = 1.0 if won[side] else 0.0
                for key, tab in ((m["sp"], sp), (m.get("ability", ""), ab)):
                    tab[key]["n"] += 1
                    tab[key]["win"] += w
                for t in m.get("types", []):
                    ty[t]["n"] += 1
                    ty[t]["win"] += w
                for mid in m.get("moves", []):
                    mv[mid]["picked"] += 1
                    mv[mid]["win"] += w
                if m.get("fainted"):
                    sp[m["sp"]]["fainted"] += 1
        entered = {}
        for e in f["events"]:
            k = e["ev"]
            if k == "enter":
                entered[e["who"]] = e["t"]
                s = e["who"].split(":", 2)[2]
                sp[s]["entries"] += 1
            elif k == "move":
                m = mv[e["move"]]
                m["uses"] += 1
                m["cost"] += float(e.get("cost", 0) or 0)
                m["bp"] = e.get("bp", 0)
                m["type"] = e.get("type", "")
                m["cat"] = e.get("cat", "")
                m["kind"] = e.get("kind", "")
                s = e["who"].split(":", 2)[2]
                sp[s]["moves"] += 1
            elif k == "hit":
                m = mv[e["move"]]
                m["hits"] += 1
                m["dmg"] += float(e.get("frac", 0))
                m["ko"] += 1 if e.get("ko") else 0
                m["crit"] += 1 if e.get("crit") else 0
                if e.get("who"):
                    s = e["who"].split(":", 2)[2]
                    sp[s]["dmg"] += float(e.get("frac", 0))
                    sp[s]["ko"] += 1 if e.get("ko") else 0
                if e.get("tgt"):
                    s = e["tgt"].split(":", 2)[2]
                    sp[s]["taken"] += float(e.get("frac", 0))
            elif k == "faint":
                s = e["who"].split(":", 2)[2]
                sp[s]["life"] += float(e.get("on_field", 0))
                sp[s]["faints_ev"] += 1

    def fin(tab, extra=None):
        res = {}
        for key, r in tab.items():
            d = {k: round(v, 3) if isinstance(v, float) else v for k, v in r.items()}
            nn = r.get("n") or r.get("picked") or 0
            if nn:
                d["winrate"] = round(100.0 * r["win"] / nn, 1)
            if extra:
                extra(d, r)
            res[key] = d
        return res

    def sp_extra(d, r):
        if r.get("entries"):
            d["dmg_per_entry"] = round(r["dmg"] / r["entries"], 3)
            d["ko_per_entry"] = round(r["ko"] / r["entries"], 3)
        if r.get("faints_ev"):
            d["life_mean"] = round(r["life"] / r["faints_ev"], 1)

    def mv_extra(d, r):
        if r.get("uses"):
            d["dmg_per_use"] = round(r["dmg"] / r["uses"], 4)
            d["hit_rate"] = round(r.get("hits", 0) / r["uses"], 3)
            c = r["cost"] / r["uses"]
            d["cost_mean"] = round(c, 1)
            if c > 0:
                d["dmg_per_energy"] = round(r["dmg"] / r["cost"], 5)

    res = {
        "fights": n,
        "by_size": dict(size_n),
        "species": fin(sp, sp_extra),
        "moves": fin(mv, mv_extra),
        "abilities": fin(ab),
        "types": fin(ty),
    }
    with open(out, "w") as fh:
        json.dump(res, fh)
    print("lutas %d, espécies %d, golpes %d -> %s" % (n, len(sp), len(mv), out))


if __name__ == "__main__":
    main()

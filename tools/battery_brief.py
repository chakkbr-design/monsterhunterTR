#!/usr/bin/env python3
"""Resumo curto (texto) de um ou mais digest.json (tools/battery_digest.py), para colar numa conversa.

Uso: python3 tools/battery_brief.py digest1.json [digest2.json...]
Junta os digests e imprime: tipos, categorias de golpe, espécies e habilidades nos extremos de vitória,
golpes mais e menos eficientes por energia e os mais usados.
"""
import json
import sys
from collections import defaultdict

ADD = ("n", "win", "picked", "uses", "hits", "dmg", "ko", "cost", "entries", "fainted", "life",
       "faints_ev", "taken", "moves", "crit")


def merge(paths):
    out = {"fights": 0}
    for p in paths:
        d = json.load(open(p))
        out["fights"] += d["fights"]
        for tab in ("species", "moves", "abilities", "types"):
            dst = out.setdefault(tab, defaultdict(lambda: defaultdict(float)))
            for k, r in d[tab].items():
                for f, v in r.items():
                    if f in ADD:
                        dst[k][f] += v
                    elif f in ("bp", "type", "cat", "kind"):
                        dst[k][f] = v
    return out


def wr(r, key="n"):
    return 100.0 * r["win"] / r[key] if r.get(key) else 0.0


def main():
    d = merge(sys.argv[1:])
    print("LUTAS", d["fights"])
    print("\nTIPOS (vitória do time com o tipo, n)")
    for k, r in sorted(d["types"].items(), key=lambda kv: -wr(kv[1])):
        print("  %-9s %5.1f%% n=%d" % (k, wr(r), r["n"]))
    cats = defaultdict(lambda: defaultdict(float))
    for k, r in d["moves"].items():
        c = "%s/%s" % (r.get("cat", "?"), r.get("kind", "?"))
        for f in ("uses", "hits", "dmg", "ko", "cost"):
            cats[c][f] += r.get(f, 0)
    print("\nCATEGORIA/ENTREGA: usos, dano por uso (fração HP), dano por 100 energia, KOs")
    for c, r in sorted(cats.items(), key=lambda kv: -kv[1]["uses"]):
        if r["uses"] >= 50:
            print("  %-22s %6d  %.3f  %.3f  %d" % (c, r["uses"], r["dmg"] / r["uses"],
                                                  100 * r["dmg"] / r["cost"] if r["cost"] else 0,
                                                  r["ko"]))
    sp = [(k, r) for k, r in d["species"].items() if r.get("n", 0) >= 8]
    sp.sort(key=lambda kv: -wr(kv[1]))
    print("\nESPÉCIES n>=8: vitória, n, dano/entrada, KO/entrada")

    def sp_line(k, r):
        e = r.get("entries") or 1
        return "  %-14s %5.1f%% n=%d dmg/e=%.2f ko/e=%.2f" % (k, wr(r), r["n"], r["dmg"] / e,
                                                             r["ko"] / e)
    print(" topo:")
    for k, r in sp[:25]:
        print(sp_line(k, r))
    print(" fundo:")
    for k, r in sp[-25:]:
        print(sp_line(k, r))
    sp2 = [(k, r) for k, r in d["species"].items() if r.get("entries", 0) >= 8]
    sp2.sort(key=lambda kv: -(kv[1]["dmg"] / kv[1]["entries"]))
    print(" mais dano por entrada (entries>=8):")
    for k, r in sp2[:15]:
        print(sp_line(k, r))
    mv = [(k, r) for k, r in d["moves"].items() if r.get("uses", 0) >= 25 and r.get("cost", 0) > 0]
    for k, r in mv:
        r["dpe"] = 100 * r["dmg"] / r["cost"]
        r["dpu"] = r["dmg"] / r["uses"]
    print("\nGOLPES usos>=25: bp, tipo, cat/entrega, usos, acerto, dano/uso, dano/100 energia, "
          "custo médio, KOs, vitória de quem tem")

    def mv_line(k, r):
        return "  %-16s %3d %-8s %-14s %5d %4.0f%% %.3f %.3f %4.1f %3d %4.1f%%" % (
            k, r.get("bp", 0), r.get("type", ""), "%s/%s" % (r.get("cat", ""), r.get("kind", "")),
            r["uses"], 100 * r.get("hits", 0) / r["uses"], r["dpu"], r["dpe"], r["cost"] / r["uses"],
            r.get("ko", 0), wr(r, "picked"))
    mv.sort(key=lambda kv: -kv[1]["dpe"])
    print(" topo dano/energia:")
    for k, r in mv[:30]:
        print(mv_line(k, r))
    print(" fundo dano/energia (só golpes de dano bp>0):")
    for k, r in [x for x in mv if x[1].get("bp", 0) > 0][-30:]:
        print(mv_line(k, r))
    mv.sort(key=lambda kv: -kv[1]["uses"])
    print(" mais usados:")
    for k, r in mv[:25]:
        print(mv_line(k, r))
    ab = [(k, r) for k, r in d["abilities"].items() if r.get("n", 0) >= 12 and k]
    ab.sort(key=lambda kv: -wr(kv[1]))
    print("\nHABILIDADES n>=12: topo / fundo")
    for k, r in ab[:15] + [("...", {"win": 0, "n": 1})] + ab[-15:]:
        print("  %-18s %5.1f%% n=%d" % (k, wr(r), r["n"]))


if __name__ == "__main__":
    main()

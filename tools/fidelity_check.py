"""Revisão de fidelidade dos dados contra uma segunda fonte (Pokémon Showdown), independente da PokeAPI que gerou
data/species.json e data/moves.json.

Confere, por espécie: tipos, stats base, habilidades (normais + oculta) e o learnset (nível + TM + ovo + tutor +
evolução) da mesma geração do learnset_version; por golpe: tipo, categoria, poder oficial (bp), precisão, PP e
prioridade. Golpes adaptados de propósito (poder por acerto etc.) não entram: só os campos oficiais.

Com --fix também corrige data/species.json pelos learnsets do Showdown (a PokeAPI tem buracos: Ninetales sem os
golpes de nível 1, Deoxys/Uxie sem os TMs do DLC, golpes da forma de Hisui no Typhlosion...): o golpe que existe no
jogo e falta entra com o nível do Showdown (L0 = golpe de evolução), ou como TM/tutor/ovo; o que sobra (nem na
geração nem herdado da forma básica) sai. Rodar depois de tools/gen9_species.py.

Uso, da raiz do projeto (os JSON de https://play.pokemonshowdown.com/data/ numa pasta):
    python tools/fidelity_check.py <pasta_showdown> [saida.md] [--fix]
"""

import json
import os
import re
import sys

FIX = "--fix" in sys.argv
ARGS = [a for a in sys.argv[1:] if a != "--fix"]
SD = ARGS[0]
OUT = ARGS[1] if len(ARGS) > 1 else None
GEN = {"scarlet-violet": "9", "sword-shield": "8", "brilliant-diamond-shining-pearl": "8",
       "ultra-sun-ultra-moon": "7", "sun-moon": "7", "omega-ruby-alpha-sapphire": "6", "x-y": "6",
       "black-2-white-2": "5"}
# Golpes que o Showdown guarda com outro id ou que a PokeAPI separa diferente.
ALIAS = {"vise_grip": "visegrip", "vice_grip": "visegrip"}


def sid(s):
    s = re.sub(r"[^a-z0-9]", "", s.lower())
    return "visegrip" if s == "vicegrip" else s


def fix_species(e, g, codes_of, lack, extra, by_sid):
    """Põe os golpes que faltam (pelo código do Showdown) e tira os que sobram. Devolve quantos mudou."""
    n = 0
    for m in lack:
        mid = by_sid[m]
        codes = [c for c in codes_of[m] if c[0] == g]
        lv = [int(c[2:]) for c in codes if c[1] == "L"]
        if lv:
            if lv[0] == 0:
                e.setdefault("evo_moves", []).append(mid)
            else:
                e["learnset"].append([lv[0], mid])
                e["learnset"].sort(key=lambda x: x[0])
        else:
            kind = next((k for c, k in (("M", "tm"), ("T", "tutor"), ("E", "egg")) if any(x[1] == c for x in codes)), "tm")
            e.setdefault(kind, []).append(mid)
            e[kind].sort()
        n += 1
    if extra:
        drop = set(extra)
        e["learnset"] = [x for x in e["learnset"] if sid(x[1]) not in drop]
        for f in ("evo_moves", "tm", "egg", "tutor"):
            if f in e:
                e[f] = [m for m in e[f] if sid(m) not in drop]
        e["moves"] = [m for m in e.get("moves", []) if sid(m) not in drop]
        n += len(drop)
    return n


def gen_moves(learn, key, g):
    """Golpes da geração g (nível, TM, ovo, tutor) da espécie no learnsets.json do Showdown."""
    ls = learn.get(key, {}).get("learnset", {})
    return {mid for mid, codes in ls.items() if any(c[0] == g and c[1] in "LMET" for c in codes)}


def main():
    dex = json.load(open(os.path.join(SD, "pokedex.json"), encoding="utf-8"))
    learn = json.load(open(os.path.join(SD, "learnsets.json"), encoding="utf-8"))
    sdm = json.load(open(os.path.join(SD, "moves.json"), encoding="utf-8"))
    species = json.load(open("data/species.json", encoding="utf-8"))
    moves = {m["id"]: m for m in json.load(open("data/moves.json", encoding="utf-8"))["moves"]}
    by_sid = {sid(k) if k not in ALIAS else ALIAS[k]: k for k in moves}
    base = {v["num"]: k for k, v in dex.items() if "forme" not in v and v.get("num", 0) > 0}
    out = []
    n_sp = n_bad = n_fix = 0
    missing_moves = {}
    for name, e in species.items():
        if name == "_doc":
            continue
        n_sp += 1
        key = base.get(e["dex_no"])
        if key is None:
            out.append("- %s: sem entrada no Showdown" % name)
            continue
        d = dex[key]
        bad = []
        if [t.lower() for t in d["types"]] != e["types"]:
            bad.append("tipos %s, Showdown %s" % (e["types"], d["types"]))
        if d["baseStats"] != e["base"]:
            bad.append("stats %s, Showdown %s" % (e["base"], d["baseStats"]))
        ab_sd = {sid(a) for a in d["abilities"].values()}
        ab_me = {sid(a) for a in e.get("abilities", [])}
        if ab_sd != ab_me:
            bad.append("habilidades %s, Showdown %s" % (sorted(ab_me), sorted(ab_sd)))
        hid_sd = sid(d["abilities"].get("H", ""))
        if hid_sd and sid(e.get("hidden_ability", "")) != hid_sd:
            bad.append("oculta %s, Showdown %s" % (e.get("hidden_ability"), d["abilities"]["H"]))
        g = GEN.get(e.get("learnset_version", ""), "9")
        want = gen_moves(learn, key, g)
        # Desde a Gen 8 o ovo da forma básica vale para as evoluções (a PokeAPI repete; o Showdown herda do prevo).
        ok = set(want)
        pre = d.get("prevo")
        while pre:
            ok |= gen_moves(learn, sid(pre), g)
            pre = dex.get(sid(pre), {}).get("prevo")
        have = {sid(m) for _, m in e.get("learnset", [])} | {sid(m) for m in e.get("evo_moves", [])}
        for f in ("tm", "egg", "tutor"):
            have |= {sid(m) for m in e.get(f, [])}
        lack = sorted(m for m in want - have if m in by_sid)
        extra = sorted(have - ok)
        for m in want - have:
            if m not in by_sid:
                missing_moves.setdefault(m, []).append(name)
        if FIX and want and (lack or extra):
            n_fix += fix_species(e, g, learn[key]["learnset"], lack, extra, by_sid)
            continue
        if lack:
            bad.append("faltam golpes que existem no jogo: %s" % ", ".join(lack))
        if extra and want:
            bad.append("golpes a mais (não estão na Gen %s do Showdown): %s" % (g, ", ".join(extra)))
        if bad:
            n_bad += 1
            out.append("- **%s** (#%d, %s): %s" % (name, e["dex_no"], e.get("learnset_version"), "; ".join(bad)))
    mv_bad = []
    for mid, m in moves.items():
        d = sdm.get(sid(mid)) or sdm.get(ALIAS.get(mid, ""))
        if d is None:
            mv_bad.append("- %s: sem entrada no Showdown" % mid)
            continue
        bad = []
        if d["type"].lower() != m.get("type"):
            bad.append("tipo %s/%s" % (m.get("type"), d["type"]))
        if d["category"].lower() != m.get("category"):
            bad.append("categoria %s/%s" % (m.get("category"), d["category"]))
        bp = d.get("basePower", 0)
        if bp and m.get("category") != "status" and m.get("bp", m.get("power")) != bp:
            bad.append("poder %s/%s" % (m.get("bp", m.get("power")), bp))
        acc = d.get("accuracy")
        mine = m.get("accuracy", True)
        if acc is True and "accuracy" in m:
            bad.append("precisão %s/nunca erra" % m["accuracy"])
        elif acc is not True and mine != acc:
            bad.append("precisão %s/%s" % (mine, acc))
        if d.get("pp") and m.get("uses") != d["pp"]:
            bad.append("PP %s/%s" % (m.get("uses"), d["pp"]))
        if d.get("priority", 0) != m.get("priority", 0):
            bad.append("prioridade %s/%s" % (m.get("priority", 0), d.get("priority", 0)))
        if bad:
            mv_bad.append("- %s: %s" % (mid, "; ".join(bad)))
    rep = ["# Revisão de fidelidade (jogo x Showdown)", "",
           "Gerado por `tools/fidelity_check.py`. Espécies: %d, com diferença: %d. Golpes: %d, com diferença: %d."
           % (n_sp, n_bad, len(moves), len(mv_bad)), "", "## Espécies", ""] + (out or ["Nenhuma diferença."])
    rep += ["", "## Golpes (campos oficiais: jogo/Showdown)", ""] + (mv_bad or ["Nenhuma diferença."])
    rep += ["", "## Golpes dos learnsets que ainda não existem no jogo (%d)" % len(missing_moves), ""]
    rep += ["- %s: %s" % (m, ", ".join(w[:6]) + (" ..." if len(w) > 6 else "")) for m, w in sorted(missing_moves.items())]
    if FIX:
        json.dump(species, open("data/species.json", "w", encoding="utf-8", newline="\n"), ensure_ascii=False, indent=2)
        open("data/species.json", "a", encoding="utf-8").write("\n")
        print("corrigidos %d golpes em data/species.json" % n_fix)
    txt = "\n".join(rep) + "\n"
    if OUT:
        open(OUT, "w", encoding="utf-8", newline="\n").write(txt)
    print("espécies com diferença: %d de %d; golpes com diferença: %d; golpes que faltam: %d"
          % (n_bad, n_sp, len(mv_bad), len(missing_moves)))


main()
